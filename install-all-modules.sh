#!/bin/bash

# ================================================
# SPARK NEXUS - CLEAN AND INSTALL
# Limpa containers antigos e instala dependências
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

# ================================================
# HEADER
# ================================================
clear
echo -e "${CYAN}╔══════════════════════════════════════════════════════════════╗${NC}"
echo -e "${CYAN}║        🧹 CLEAN AND INSTALL DEPENDENCIES                    ║${NC}"
echo -e "${CYAN}║           Limpeza completa e instalação                     ║${NC}"
echo -e "${CYAN}╚══════════════════════════════════════════════════════════════╝${NC}"
echo ""

# ================================================
# PASSO 1: LIMPAR CONTAINERS ANTIGOS
# ================================================
echo -e "${YELLOW}[1/8] Limpando containers antigos...${NC}"

# Parar e remover containers antigos
docker stop temp-installer 2>/dev/null || true
docker rm temp-installer 2>/dev/null || true
docker stop temp-fix-container 2>/dev/null || true
docker rm temp-fix-container 2>/dev/null || true
docker-compose stop client-dashboard 2>/dev/null || true
docker rm -f sparknexus-client 2>/dev/null || true

echo -e "${GREEN}✅ Containers antigos removidos${NC}"

# ================================================
# PASSO 2: CRIAR NOVO CONTAINER TEMPORÁRIO
# ================================================
echo -e "\n${YELLOW}[2/8] Criando novo container temporário...${NC}"

CONTAINER_NAME="installer-$(date +%s)"
docker run -d \
  --name "$CONTAINER_NAME" \
  -v sparknexus_client_data:/app \
  -w /app \
  node:18-alpine \
  sleep 3600

sleep 2
echo -e "${GREEN}✅ Container $CONTAINER_NAME criado${NC}"

# ================================================
# PASSO 3: LIMPAR ARQUIVOS ANTIGOS
# ================================================
echo -e "\n${YELLOW}[3/8] Limpando arquivos antigos...${NC}"

docker exec "$CONTAINER_NAME" sh -c '
echo "🧹 Removendo node_modules e package-lock.json antigos..."
rm -rf node_modules package-lock.json 2>/dev/null || true
echo "✅ Limpeza concluída"
'

# ================================================
# PASSO 4: CRIAR PACKAGE.JSON MÍNIMO
# ================================================
echo -e "\n${YELLOW}[4/8] Criando package.json essencial...${NC}"

docker exec "$CONTAINER_NAME" sh -c 'cat > package.json << '\''EOF'\''
{
  "name": "spark-nexus-client",
  "version": "1.0.0",
  "main": "server.js",
  "dependencies": {
    "express": "^4.18.2",
    "cors": "^2.8.5",
    "dotenv": "^16.3.1",
    "axios": "^1.6.0",
    "bcryptjs": "^2.4.3",
    "jsonwebtoken": "^9.0.2",
    "multer": "^1.4.5-lts.1",
    "csv-parse": "^5.5.0",
    "csv-parser": "^3.0.0",
    "exceljs": "^4.4.0",
    "xlsx": "^0.18.5",
    "psl": "^1.9.0",
    "levenshtein": "^1.0.5",
    "email-validator": "^2.0.4",
    "validator": "^13.11.0",
    "ioredis": "^5.3.0",
    "node-cache": "^5.1.2"
  }
}
EOF
echo "✅ package.json criado"
'

# ================================================
# PASSO 5: INSTALAR DEPENDÊNCIAS ESSENCIAIS
# ================================================
echo -e "\n${YELLOW}[5/8] Instalando dependências essenciais...${NC}"
echo -e "${CYAN}Isso pode levar 2-3 minutos...${NC}"

docker exec "$CONTAINER_NAME" sh -c '
echo "📦 Instalando com npm..."
npm install --loglevel=error

echo ""
echo "📊 Resultado da instalação:"
if [ -d node_modules ]; then
    MODULE_COUNT=$(ls -1 node_modules 2>/dev/null | wc -l)
    echo "✅ $MODULE_COUNT módulos instalados"
    echo "📁 Tamanho: $(du -sh node_modules 2>/dev/null | cut -f1)"
else
    echo "❌ Falha na instalação"
fi
'

# ================================================
# PASSO 6: INSTALAR MÓDULOS ADICIONAIS FALTANTES
# ================================================
echo -e "\n${YELLOW}[6/8] Instalando módulos adicionais se necessário...${NC}"

docker exec "$CONTAINER_NAME" sh -c '
echo "📦 Verificando e instalando módulos adicionais..."

# Lista de módulos que podem estar faltando
EXTRA_MODULES="morgan helmet compression express-rate-limit uuid lodash moment"

for module in $EXTRA_MODULES; do
    if [ ! -d "node_modules/$module" ]; then
        echo "  Installing $module..."
        npm install $module --loglevel=error 2>/dev/null || true
    fi
done

echo "✅ Módulos adicionais verificados"
'

# ================================================
# PASSO 7: VERIFICAR INSTALAÇÃO
# ================================================
echo -e "\n${YELLOW}[7/8] Verificando instalação...${NC}"

docker exec "$CONTAINER_NAME" sh -c '
echo "🔍 Módulos críticos instalados:"
echo ""

# Verificar módulos principais
for mod in express exceljs psl levenshtein email-validator validator axios; do
    if [ -d "node_modules/$mod" ]; then
        echo "  ✅ $mod"
    else
        echo "  ❌ $mod - FALTANDO!"
    fi
done

echo ""
echo "🧪 Teste de carregamento:"
node -e "
['\''express'\'', '\''exceljs'\'', '\''psl'\'', '\''levenshtein'\''].forEach(m => {
    try {
        require(m);
        console.log('\''  ✅ '\'' + m + '\'': OK'\'');
    } catch(e) {
        console.log('\''  ❌ '\'' + m + '\'': ERRO'\'');
    }
});
"
'

# ================================================
# PASSO 8: LIMPAR E REINICIAR
# ================================================
echo -e "\n${YELLOW}[8/8] Finalizando e reiniciando sistema...${NC}"

# Remover container temporário
docker stop "$CONTAINER_NAME" >/dev/null 2>&1
docker rm "$CONTAINER_NAME" >/dev/null 2>&1
echo -e "${GREEN}✅ Container temporário removido${NC}"

# Reiniciar client-dashboard
echo -e "${CYAN}🔄 Iniciando client-dashboard...${NC}"
docker-compose up -d client-dashboard

# Aguardar
echo -e "${YELLOW}⏳ Aguardando inicialização (15 segundos)...${NC}"
sleep 15

# ================================================
# VERIFICAÇÃO FINAL
# ================================================
echo -e "\n${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${CYAN}📊 STATUS FINAL${NC}"
echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"

# Verificar se está rodando
if docker ps | grep -q "sparknexus-client"; then
    echo -e "${GREEN}✅ Container client-dashboard RODANDO${NC}"
    
    # Verificar erros
    ERRORS=$(docker-compose logs --tail=30 client-dashboard 2>&1 | grep "Cannot find module" | head -3)
    if [ -z "$ERRORS" ]; then
        echo -e "${GREEN}✅ Sem erros de módulos!${NC}"
    else
        echo -e "${YELLOW}⚠️  Módulos ainda faltando:${NC}"
        echo "$ERRORS" | grep -oP "'\K[^']+(?=')" | sort -u
        echo ""
        echo -e "${YELLOW}Execute este comando para instalar módulos faltantes:${NC}"
        echo -e "${CYAN}docker exec sparknexus-client npm install [nome-do-modulo]${NC}"
    fi
    
    # Testar API
    echo -e "\n${CYAN}🧪 Testando API...${NC}"
    RESPONSE=$(curl -s -o /dev/null -w "%{http_code}" http://localhost:4201/health 2>/dev/null || echo "000")
    
    if [ "$RESPONSE" = "200" ]; then
        echo -e "${GREEN}✅ API FUNCIONANDO! (HTTP 200)${NC}"
        echo -e "\n${GREEN}🎉 SISTEMA OPERACIONAL!${NC}"
        echo -e "${GREEN}Acesse: http://localhost:4201${NC}"
    else
        echo -e "${YELLOW}⚠️  API retornou: HTTP $RESPONSE${NC}"
        echo -e "${YELLOW}Aguarde mais alguns segundos ou verifique os logs${NC}"
    fi
else
    echo -e "${RED}❌ Container NÃO está rodando${NC}"
    echo -e "${RED}Verifique os logs: docker-compose logs client-dashboard${NC}"
fi

echo -e "\n${CYAN}🔧 Comandos úteis:${NC}"
echo -e "  Logs: ${YELLOW}docker-compose logs -f client-dashboard${NC}"
echo -e "  Instalar módulo: ${YELLOW}docker exec sparknexus-client npm install [módulo]${NC}"
echo -e "  Reiniciar: ${YELLOW}docker-compose restart client-dashboard${NC}"

echo -e "\n${GREEN}✅ Processo concluído!${NC}\n"

exit 0