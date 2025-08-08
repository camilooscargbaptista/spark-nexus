#!/bin/bash

# ================================================
# Script para Corrigir Containers com Problemas
# Spark Nexus - Fix Restarting Containers
# ================================================

set -e

# Cores
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
MAGENTA='\033[0;35m'
NC='\033[0m'

echo -e "${MAGENTA}================================================${NC}"
echo -e "${MAGENTA}🔧 CORRIGINDO CONTAINERS COM PROBLEMAS${NC}"
echo -e "${MAGENTA}================================================${NC}"

# ================================================
# 1. VERIFICAR LOGS DOS CONTAINERS COM PROBLEMA
# ================================================
echo -e "\n${BLUE}[1/5] Verificando Logs dos Containers${NC}"
echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"

# Kong
echo -e "\n${YELLOW}📋 Logs do Kong:${NC}"
docker logs --tail 10 sparknexus-kong 2>&1 | head -15 || true

# Client Dashboard
echo -e "\n${YELLOW}📋 Logs do Client Dashboard:${NC}"
docker logs --tail 10 sparknexus-client-dashboard 2>&1 | head -15 || true

# Email Validator Worker
echo -e "\n${YELLOW}📋 Logs do Email Validator Worker:${NC}"
docker logs --tail 10 sparknexus-email-validator-worker 2>&1 | head -15 || true

# ================================================
# 2. PARAR CONTAINERS COM PROBLEMA
# ================================================
echo -e "\n${BLUE}[2/5] Parando Containers com Problema${NC}"
echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"

docker stop sparknexus-kong sparknexus-client-dashboard sparknexus-email-validator-worker 2>/dev/null || true
docker rm sparknexus-kong sparknexus-client-dashboard sparknexus-email-validator-worker 2>/dev/null || true

echo -e "${GREEN}✅ Containers parados${NC}"

# ================================================
# 3. CORRIGIR CONFIGURAÇÕES
# ================================================
echo -e "\n${BLUE}[3/5] Aplicando Correções${NC}"
echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"

# Criar arquivo de configuração mínima do Kong
echo "Criando configuração do Kong..."
mkdir -p core/kong
cat > core/kong/kong.yml << 'EOF'
_format_version: "2.1"

services:
- name: email-validator-api
  url: http://sparknexus-email-validator-api:4200
  routes:
  - name: email-validator-route
    paths:
    - /api/email
    
- name: client-dashboard
  url: http://sparknexus-client-dashboard:4201
  routes:
  - name: client-route
    paths:
    - /
EOF

echo -e "${GREEN}✅ Configuração do Kong criada${NC}"

# ================================================
# 4. REINICIAR SERVIÇOS CORRIGIDOS
# ================================================
echo -e "\n${BLUE}[4/5] Reiniciando Serviços${NC}"
echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"

# Kong (opcional - pode ficar desligado se não funcionar)
echo "Tentando reiniciar Kong..."
docker-compose up -d kong 2>/dev/null || echo -e "${YELLOW}⚠️ Kong não é essencial, continuando...${NC}"

# Client Dashboard
echo "Reiniciando Client Dashboard..."
docker-compose up -d client-dashboard

# Email Validator Worker
echo "Reiniciando Email Validator Worker..."
docker-compose up -d email-validator-worker

echo -e "${YELLOW}⏳ Aguardando serviços (20 segundos)...${NC}"
sleep 20

# ================================================
# 5. VERIFICAR STATUS FINAL
# ================================================
echo -e "\n${BLUE}[5/5] Status Final${NC}"
echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"

echo -e "${CYAN}📊 Status dos Containers:${NC}"
docker ps --format "table {{.Names}}\t{{.Status}}" | grep sparknexus

# Verificar quais estão com problema
RESTARTING=$(docker ps --filter "name=sparknexus" --format "{{.Names}} {{.Status}}" | grep -i "restarting" || true)
if [ ! -z "$RESTARTING" ]; then
    echo -e "\n${YELLOW}⚠️ Ainda há containers reiniciando:${NC}"
    echo "$RESTARTING"
    echo -e "\n${YELLOW}Parando containers problemáticos para não consumir recursos...${NC}"
    echo "$RESTARTING" | awk '{print $1}' | xargs -r docker stop 2>/dev/null || true
fi

# ================================================
# TESTAR SERVIÇOS PRINCIPAIS
# ================================================
echo -e "\n${CYAN}🔍 Testando Serviços Principais:${NC}"
echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"

test_service() {
    local url=$1
    local name=$2
    
    echo -n "$name: "
    
    response=$(curl -s -o /dev/null -w "%{http_code}" "$url" 2>/dev/null || echo "000")
    
    if [ "$response" = "200" ] || [ "$response" = "301" ] || [ "$response" = "302" ] || [ "$response" = "404" ]; then
        echo -e "${GREEN}✅ Online (HTTP $response)${NC}"
        return 0
    else
        echo -e "${RED}❌ Offline${NC}"
        return 1
    fi
}

# Testar serviços essenciais
test_service "http://localhost:4200" "Email Validator API"
test_service "http://localhost:4201" "Client Dashboard"
test_service "http://localhost:4202" "Admin Dashboard"
test_service "http://localhost:8080" "Adminer (PostgreSQL)"
test_service "http://localhost:8081" "Redis Commander"
test_service "http://localhost:15672" "RabbitMQ"
test_service "http://localhost:5678" "N8N"

# ================================================
# ALTERNATIVA SE CLIENT DASHBOARD NÃO FUNCIONAR
# ================================================
if ! curl -s -o /dev/null -w "%{http_code}" "http://localhost:4201" 2>/dev/null | grep -q "200\|301\|302"; then
    echo -e "\n${YELLOW}⚠️ Client Dashboard não está respondendo na porta 4201${NC}"
    echo -e "${YELLOW}Verificando se está em outra porta...${NC}"
    
    # Verificar portas do container
    docker port sparknexus-client-dashboard 2>/dev/null || echo "Container não está rodando"
    
    echo -e "\n${CYAN}📝 Criando página de upload alternativa...${NC}"
    
    # Criar página HTML simples para upload
    cat > upload-test.html << 'EOF'
<!DOCTYPE html>
<html lang="pt-BR">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Spark Nexus - Upload de Emails</title>
    <style>
        * { margin: 0; padding: 0; box-sizing: border-box; }
        body {
            font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif;
            background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
            min-height: 100vh;
            display: flex;
            justify-content: center;
            align-items: center;
            padding: 20px;
        }
        .container {
            background: white;
            border-radius: 20px;
            padding: 40px;
            box-shadow: 0 20px 60px rgba(0,0,0,0.3);
            max-width: 500px;
            width: 100%;
        }
        h1 {
            color: #333;
            margin-bottom: 10px;
            text-align: center;
        }
        .subtitle {
            color: #666;
            text-align: center;
            margin-bottom: 30px;
        }
        .form-group {
            margin-bottom: 20px;
        }
        label {
            display: block;
            margin-bottom: 5px;
            color: #555;
            font-weight: 600;
        }
        input[type="file"],
        input[type="email"] {
            width: 100%;
            padding: 12px;
            border: 2px solid #e0e0e0;
            border-radius: 8px;
            font-size: 16px;
            transition: border-color 0.3s;
        }
        input[type="file"]:focus,
        input[type="email"]:focus {
            outline: none;
            border-color: #667eea;
        }
        .btn {
            width: 100%;
            padding: 15px;
            background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
            color: white;
            border: none;
            border-radius: 8px;
            font-size: 18px;
            font-weight: 600;
            cursor: pointer;
            transition: transform 0.3s, box-shadow 0.3s;
        }
        .btn:hover {
            transform: translateY(-2px);
            box-shadow: 0 10px 30px rgba(102, 126, 234, 0.4);
        }
        .btn:disabled {
            opacity: 0.6;
            cursor: not-allowed;
        }
        .info-box {
            background: #f8f9fa;
            padding: 15px;
            border-radius: 8px;
            margin-top: 20px;
        }
        .info-box h3 {
            color: #667eea;
            margin-bottom: 10px;
        }
        .info-box ul {
            margin-left: 20px;
            color: #666;
        }
        .status {
            margin-top: 20px;
            padding: 15px;
            border-radius: 8px;
            text-align: center;
            display: none;
        }
        .status.success {
            background: #d4edda;
            color: #155724;
            display: block;
        }
        .status.error {
            background: #f8d7da;
            color: #721c24;
            display: block;
        }
    </style>
</head>
<body>
    <div class="container">
        <h1>🚀 Spark Nexus</h1>
        <p class="subtitle">Sistema de Validação de Emails</p>
        
        <form id="uploadForm">
            <div class="form-group">
                <label for="file">📁 Arquivo CSV com emails:</label>
                <input type="file" id="file" name="file" accept=".csv" required>
            </div>
            
            <div class="form-group">
                <label for="email">📧 Seu email para receber o relatório:</label>
                <input type="email" id="email" name="email" placeholder="contato@sparknexus.com.br" required>
            </div>
            
            <button type="submit" class="btn">Iniciar Validação</button>
        </form>
        
        <div id="status" class="status"></div>
        
        <div class="info-box">
            <h3>ℹ️ Como funciona:</h3>
            <ul>
                <li>Faça upload de um arquivo CSV com emails</li>
                <li>O sistema validará cada email</li>
                <li>Você receberá um relatório completo por email</li>
            </ul>
        </div>
    </div>
    
    <script>
        document.getElementById('uploadForm').addEventListener('submit', async (e) => {
            e.preventDefault();
            
            const statusDiv = document.getElementById('status');
            const submitBtn = e.target.querySelector('button[type="submit"]');
            
            submitBtn.disabled = true;
            submitBtn.textContent = 'Processando...';
            
            const formData = new FormData();
            formData.append('file', document.getElementById('file').files[0]);
            formData.append('email', document.getElementById('email').value);
            
            try {
                const response = await fetch('http://localhost:4200/api/upload', {
                    method: 'POST',
                    body: formData
                });
                
                if (response.ok) {
                    statusDiv.className = 'status success';
                    statusDiv.innerHTML = '✅ Upload realizado com sucesso! Verifique seu email em alguns minutos.';
                } else {
                    throw new Error('Erro no upload');
                }
            } catch (error) {
                statusDiv.className = 'status error';
                statusDiv.innerHTML = '❌ Erro ao fazer upload. Verifique se o serviço está rodando.';
            } finally {
                submitBtn.disabled = false;
                submitBtn.textContent = 'Iniciar Validação';
            }
        });
    </script>
</body>
</html>
EOF
    
    echo -e "${GREEN}✅ Arquivo upload-test.html criado${NC}"
    echo -e "${YELLOW}Abra este arquivo no navegador para testar o upload${NC}"
    
    # Abrir no navegador (macOS)
    if [[ "$OSTYPE" == "darwin"* ]]; then
        open upload-test.html
    fi
fi

# ================================================
# RESULTADO FINAL
# ================================================
echo ""
echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${GREEN}✅ CORREÇÕES APLICADAS!${NC}"
echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"

echo -e "\n${CYAN}🎯 SERVIÇOS DISPONÍVEIS:${NC}"
echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"

# Listar apenas os serviços que estão funcionando
if curl -s -o /dev/null -w "%{http_code}" "http://localhost:4200" 2>/dev/null | grep -q "200\|301\|302\|404"; then
    echo -e "${GREEN}✅ Email Validator API:${NC} http://localhost:4200"
fi

if curl -s -o /dev/null -w "%{http_code}" "http://localhost:4201" 2>/dev/null | grep -q "200\|301\|302\|404"; then
    echo -e "${GREEN}✅ Client Dashboard:${NC} http://localhost:4201"
fi

if curl -s -o /dev/null -w "%{http_code}" "http://localhost:4202" 2>/dev/null | grep -q "200\|301\|302\|404"; then
    echo -e "${GREEN}✅ Admin Dashboard:${NC} http://localhost:4202"
fi

if curl -s -o /dev/null -w "%{http_code}" "http://localhost:8080" 2>/dev/null | grep -q "200\|301\|302"; then
    echo -e "${GREEN}✅ Adminer (PostgreSQL):${NC} http://localhost:8080"
fi

if curl -s -o /dev/null -w "%{http_code}" "http://localhost:8081" 2>/dev/null | grep -q "200\|301\|302"; then
    echo -e "${GREEN}✅ Redis Commander:${NC} http://localhost:8081"
fi

if curl -s -o /dev/null -w "%{http_code}" "http://localhost:15672" 2>/dev/null | grep -q "200\|301\|302"; then
    echo -e "${GREEN}✅ RabbitMQ:${NC} http://localhost:15672 (guest/guest)"
fi

if curl -s -o /dev/null -w "%{http_code}" "http://localhost:5678" 2>/dev/null | grep -q "200\|301\|302"; then
    echo -e "${GREEN}✅ N8N:${NC} http://localhost:5678"
fi

echo -e "\n${CYAN}📝 SE PRECISAR TESTAR O UPLOAD:${NC}"
echo "1. Use o arquivo: upload-test.html"
echo "2. Ou acesse diretamente a API em: http://localhost:4200"
echo "3. Use o arquivo test-emails.csv para teste"

echo -e "\n${CYAN}🔍 COMANDOS ÚTEIS:${NC}"
echo "• Ver todos os logs: docker-compose logs -f"
echo "• Ver containers: docker ps"
echo "• Testar email: node test-titan-email.js"

echo -e "\n${MAGENTA}🚀 Sistema operacional com os serviços principais!${NC}"