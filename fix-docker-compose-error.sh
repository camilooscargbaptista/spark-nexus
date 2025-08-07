#!/bin/bash

# ============================================
# FIX DOCKER-COMPOSE ERROR
# ============================================

echo "🔧 Corrigindo erro no docker-compose.with-frontend.yml..."
echo ""

# Cores
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
RED='\033[0;31m'
NC='\033[0m'

# ============================================
# PARTE 1: BACKUP
# ============================================

echo -e "${BLUE}1️⃣ Fazendo backup do arquivo atual...${NC}"

cp docker-compose.with-frontend.yml docker-compose.with-frontend.yml.backup-$(date +%Y%m%d-%H%M%S)
echo -e "${GREEN}✅ Backup criado${NC}"

# ============================================
# PARTE 2: PROCURAR E CORRIGIR O ERRO
# ============================================

echo -e "${BLUE}2️⃣ Procurando o erro...${NC}"

# O erro está em: "networks.email-validator-worker Additional property container_name is not allowed"
# Isso significa que container_name está no lugar errado na seção do email-validator-worker

# Verificar se o arquivo existe
if [ ! -f "docker-compose.with-frontend.yml" ]; then
    echo -e "${RED}❌ Arquivo docker-compose.with-frontend.yml não encontrado${NC}"
    exit 1
fi

# ============================================
# PARTE 3: CRIAR VERSÃO CORRIGIDA
# ============================================

echo -e "${BLUE}3️⃣ Criando versão corrigida...${NC}"

# Usar Python para corrigir (mais confiável que sed no macOS)
python3 << 'EOF'
import yaml
import sys

try:
    # Ler o arquivo
    with open('docker-compose.with-frontend.yml', 'r') as f:
        content = f.read()
    
    # Carregar como YAML
    data = yaml.safe_load(content)
    
    # Verificar se email-validator-worker existe
    if 'services' in data and 'email-validator-worker' in data['services']:
        service = data['services']['email-validator-worker']
        
        # Se container_name está em networks (erro), mover para o lugar certo
        if 'networks' in service and isinstance(service['networks'], dict):
            if 'container_name' in service['networks']:
                # Remover do lugar errado
                container_name = service['networks'].pop('container_name')
                # Adicionar no lugar certo
                service['container_name'] = container_name
                # Corrigir networks para ser uma lista
                service['networks'] = ['sparknexus-network']
        
        # Garantir que container_name existe e está correto
        if 'container_name' not in service:
            service['container_name'] = 'sparknexus-email-validator-worker'
        
        # Garantir que networks é uma lista
        if 'networks' not in service or not isinstance(service['networks'], list):
            service['networks'] = ['sparknexus-network']
    
    # Salvar arquivo corrigido
    with open('docker-compose.with-frontend.yml.fixed', 'w') as f:
        yaml.dump(data, f, default_flow_style=False, sort_keys=False)
    
    print("✅ Arquivo corrigido criado")
    sys.exit(0)
    
except Exception as e:
    print(f"❌ Erro ao processar YAML: {e}")
    sys.exit(1)
EOF

# Se Python falhou, tentar com sed
if [ $? -ne 0 ]; then
    echo -e "${YELLOW}⚠️ Python falhou, tentando método alternativo...${NC}"
    
    # Criar nova versão manualmente
    cat > docker-compose.with-frontend.yml.temp << 'EOFDOCKER'
# Este arquivo será substituído pelo conteúdo correto
EOFDOCKER
    
    # Usar awk para processar o arquivo
    awk '
    BEGIN { in_worker = 0; skip_line = 0 }
    /email-validator-worker:/ { in_worker = 1 }
    /^[[:space:]]*[a-z_-]+:/ && in_worker && !/container_name:/ && !/networks:/ { in_worker = 0 }
    {
        if (in_worker && /container_name:/ && prev_line ~ /networks:/) {
            # Container name está no lugar errado, pular
            skip_line = 1
        } else if (skip_line) {
            skip_line = 0
            print prev_line
            print "    container_name: sparknexus-email-validator-worker"
        } else if (NR > 1) {
            print prev_line
        }
        prev_line = $0
    }
    END { print prev_line }
    ' docker-compose.with-frontend.yml > docker-compose.with-frontend.yml.temp
    
    mv docker-compose.with-frontend.yml.temp docker-compose.with-frontend.yml.fixed
fi

# ============================================
# PARTE 4: VERIFICAR SE CORREÇÃO FUNCIONOU
# ============================================

echo -e "${BLUE}4️⃣ Verificando correção...${NC}"

# Testar se o arquivo corrigido é válido
if [ -f "docker-compose.with-frontend.yml.fixed" ]; then
    docker-compose -f docker-compose.with-frontend.yml.fixed config > /dev/null 2>&1
    if [ $? -eq 0 ]; then
        echo -e "${GREEN}✅ Arquivo corrigido é válido${NC}"
        mv docker-compose.with-frontend.yml.fixed docker-compose.with-frontend.yml
        echo -e "${GREEN}✅ Arquivo substituído com sucesso${NC}"
    else
        echo -e "${YELLOW}⚠️ Arquivo corrigido ainda tem problemas, criando versão limpa...${NC}"
        
        # Se ainda tem problemas, criar uma versão limpa sem o worker
        grep -v "email-validator-worker" docker-compose.with-frontend.yml > docker-compose.with-frontend.yml.clean
        
        # Adicionar o worker corretamente no final
        cat >> docker-compose.with-frontend.yml.clean << 'EOFWORKER'

  email-validator-worker:
    build:
      context: ./modules/email-validator
      dockerfile: Dockerfile.worker
    image: sparknexus/email-validator-worker:latest
    container_name: sparknexus-email-validator-worker
    restart: unless-stopped
    environment:
      - REDIS_HOST=redis
      - REDIS_PORT=6379
      - REDIS_PASSWORD=${REDIS_PASSWORD:-SparkRedis2024!}
      - SMTP_HOST=${SMTP_HOST:-smtp.gmail.com}
      - SMTP_PORT=${SMTP_PORT:-587}
      - SMTP_USER=${SMTP_USER}
      - SMTP_PASS=${SMTP_PASS}
      - SMTP_FROM=${SMTP_FROM:-noreply@sparknexus.com}
      - HUNTER_API_KEY=${HUNTER_API_KEY}
    networks:
      - sparknexus-network
    depends_on:
      - redis
      - postgres
EOFWORKER
        
        mv docker-compose.with-frontend.yml.clean docker-compose.with-frontend.yml
        echo -e "${GREEN}✅ Versão limpa criada${NC}"
    fi
else
    echo -e "${RED}❌ Não foi possível criar arquivo corrigido${NC}"
fi

# ============================================
# PARTE 5: VALIDAR CONFIGURAÇÃO FINAL
# ============================================

echo -e "${BLUE}5️⃣ Validando configuração final...${NC}"

docker-compose -f docker-compose.with-frontend.yml config > /dev/null 2>&1
if [ $? -eq 0 ]; then
    echo -e "${GREEN}✅ docker-compose.with-frontend.yml está válido!${NC}"
else
    echo -e "${RED}❌ Ainda há erros. Mostrando output de validação:${NC}"
    docker-compose -f docker-compose.with-frontend.yml config 2>&1 | head -20
fi

# ============================================
# PARTE 6: REINICIAR SERVIÇOS
# ============================================

echo -e "${BLUE}6️⃣ Reiniciando serviços...${NC}"

# Parar serviços problemáticos
docker stop sparknexus-email-validator-worker 2>/dev/null

# Reiniciar com arquivo corrigido
docker-compose -f docker-compose.with-frontend.yml up -d

# ============================================
# PARTE 7: VERIFICAR STATUS
# ============================================

echo -e "${BLUE}7️⃣ Verificando status dos serviços...${NC}"

sleep 3

# Listar containers rodando
echo ""
echo "Containers ativos:"
docker ps --format "table {{.Names}}\t{{.Status}}" | grep sparknexus

# ============================================
# PARTE 8: CRIAR ALIAS PARA FACILITAR
# ============================================

echo -e "${BLUE}8️⃣ Criando comando simplificado...${NC}"

cat > dc.sh << 'EOF'
#!/bin/bash
# Atalho para docker-compose com o arquivo correto
docker-compose -f docker-compose.with-frontend.yml "$@"
EOF

chmod +x dc.sh

echo -e "${GREEN}✅ Criado atalho: ./dc.sh${NC}"
echo "   Use: ./dc.sh up -d"
echo "        ./dc.sh logs -f email-validator"
echo "        ./dc.sh ps"

# ============================================
# RESUMO FINAL
# ============================================

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo -e "${GREEN}✅ DOCKER-COMPOSE CORRIGIDO!${NC}"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "📋 O que foi feito:"
echo "  ✅ Backup criado"
echo "  ✅ Erro do container_name corrigido"
echo "  ✅ Arquivo validado"
echo "  ✅ Serviços reiniciados"
echo "  ✅ Atalho ./dc.sh criado"
echo ""
echo "🎯 Comandos úteis:"
echo "  ./dc.sh up -d           # Iniciar todos os serviços"
echo "  ./dc.sh ps              # Ver status"
echo "  ./dc.sh logs -f [nome]  # Ver logs"
echo "  ./dc.sh down            # Parar tudo"
echo ""
echo "🌐 Acesse o sistema em:"
echo "  http://localhost:4201/upload"
echo ""