#!/bin/bash

# ================================================
# SPARK NEXUS - CORREÇÃO DO ERRO DO VALIDADOR
# ================================================

# Cores
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
MAGENTA='\033[0;35m'
NC='\033[0m'

clear
echo -e "${MAGENTA}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${MAGENTA}     🔧 CORREÇÃO DO ERRO - CLIENT DASHBOARD${NC}"
echo -e "${MAGENTA}     📋 ReferenceError: EmailValidator is not defined${NC}"
echo -e "${MAGENTA}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""

# ================================================
# ETAPA 1: PARAR O CONTAINER
# ================================================
echo -e "${BLUE}[1/7] Parando container com erro...${NC}"
echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"

docker-compose stop client-dashboard 2>/dev/null
echo -e "${GREEN}✅ Container parado${NC}"
echo ""

# ================================================
# ETAPA 2: NAVEGAR PARA O DIRETÓRIO
# ================================================
echo -e "${BLUE}[2/7] Navegando para o diretório...${NC}"
echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"

if [ -d "core/client-dashboard" ]; then
    cd core/client-dashboard
    echo -e "${GREEN}✅ Em core/client-dashboard${NC}"
elif [ -d "client-dashboard" ]; then
    cd client-dashboard
    echo -e "${GREEN}✅ Em client-dashboard${NC}"
elif [ -f "server.js" ]; then
    echo -e "${GREEN}✅ Já no diretório correto${NC}"
else
    echo -e "${RED}❌ Diretório não encontrado${NC}"
    exit 1
fi
echo ""

# ================================================
# ETAPA 3: FAZER BACKUP DO ARQUIVO COM ERRO
# ================================================
echo -e "${BLUE}[3/7] Fazendo backup do arquivo com erro...${NC}"
echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"

if [ -f "server.js" ]; then
    cp server.js server.js.error-$(date +%Y%m%d-%H%M%S)
    echo -e "${GREEN}✅ Backup criado${NC}"
fi
echo ""

# ================================================
# ETAPA 4: REVERTER SERVER.JS
# ================================================
echo -e "${BLUE}[4/7] Revertendo server.js para versão limpa...${NC}"
echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"

# Buscar backup limpo (sem "error" ou "problematic" no nome)
CLEAN_BACKUP=$(ls -t server.js.backup-* 2>/dev/null | grep -v "error\|problematic\|temp" | head -1)

if [ -n "$CLEAN_BACKUP" ]; then
    echo -e "${CYAN}📋 Usando backup: $CLEAN_BACKUP${NC}"
    cp "$CLEAN_BACKUP" server.js
    echo -e "${GREEN}✅ server.js revertido${NC}"
else
    echo -e "${YELLOW}⚠️  Nenhum backup limpo encontrado${NC}"
    echo -e "${CYAN}🔧 Removendo linhas problemáticas...${NC}"
    
    # Remover linhas com EmailValidator e advancedValidator
    if [ -f "server.js" ]; then
        # Criar cópia temporária
        cp server.js server.js.temp
        
        # Remover linhas problemáticas
        grep -v "EmailValidator\|advancedValidator" server.js.temp > server.js
        rm server.js.temp
        
        echo -e "${GREEN}✅ Linhas problemáticas removidas${NC}"
    fi
fi
echo ""

# ================================================
# ETAPA 5: GARANTIR QUE NÃO HÁ IMPORTS QUEBRADOS
# ================================================
echo -e "${BLUE}[5/7] Verificando e corrigindo imports...${NC}"
echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"

# Verificar se há requires de arquivos que não existem
if grep -q "require('./services/validators')" server.js 2>/dev/null; then
    if [ ! -f "services/validators/index.js" ]; then
        echo -e "${CYAN}🔧 Criando stub para validators...${NC}"
        mkdir -p services/validators
        echo "module.exports = {};" > services/validators/index.js
    fi
fi

if grep -q "require('./services/routes/advancedValidator')" server.js 2>/dev/null; then
    if [ ! -f "services/routes/advancedValidator.js" ]; then
        echo -e "${CYAN}🔧 Criando stub para advancedValidator...${NC}"
        mkdir -p services/routes
        cat > services/routes/advancedValidator.js << 'EOF'
const express = require('express');
const router = express.Router();
const initializeValidator = () => router;
module.exports = { initializeValidator, router };
EOF
    fi
fi

echo -e "${GREEN}✅ Imports verificados${NC}"
echo ""

# ================================================
# ETAPA 6: RECONSTRUIR IMAGEM
# ================================================
echo -e "${BLUE}[6/7] Reconstruindo imagem Docker...${NC}"
echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"

# Voltar para raiz
cd ../.. 2>/dev/null || cd .. 2>/dev/null || true

# Verificar se estamos no lugar certo
if [ ! -f "docker-compose.yml" ]; then
    echo -e "${RED}❌ docker-compose.yml não encontrado${NC}"
    echo -e "${YELLOW}Por favor, execute o script da raiz do projeto${NC}"
    exit 1
fi

# Remover container antigo
docker-compose rm -f client-dashboard 2>/dev/null

# Reconstruir imagem
echo -e "${CYAN}🔨 Reconstruindo imagem...${NC}"
docker-compose build client-dashboard

if [ $? -eq 0 ]; then
    echo -e "${GREEN}✅ Imagem reconstruída${NC}"
else
    echo -e "${YELLOW}⚠️  Tentando build sem cache...${NC}"
    docker-compose build --no-cache client-dashboard
fi
echo ""

# ================================================
# ETAPA 7: INICIAR CONTAINER
# ================================================
echo -e "${BLUE}[7/7] Iniciando container corrigido...${NC}"
echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"

docker-compose up -d client-dashboard

echo -e "${YELLOW}⏳ Aguardando inicialização (10 segundos)...${NC}"
for i in {1..10}; do
    echo -n "."
    sleep 1
done
echo -e "\n"

# ================================================
# VERIFICAÇÃO FINAL
# ================================================
echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${CYAN}📊 VERIFICAÇÃO FINAL${NC}"
echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""

# Verificar se container está rodando
CONTAINER_RUNNING=false
if docker ps --format "{{.Names}}" | grep -qE "client"; then
    CONTAINER_NAME=$(docker ps --format "{{.Names}}" | grep -E "client" | head -1)
    echo -e "${GREEN}✅ Container rodando: $CONTAINER_NAME${NC}"
    CONTAINER_RUNNING=true
    
    # Verificar logs para erros
    echo -e "\n${CYAN}📋 Verificando logs...${NC}"
    ERROR_COUNT=$(docker logs --tail=20 "$CONTAINER_NAME" 2>&1 | grep -c "Error\|ReferenceError" || true)
    
    if [ "$ERROR_COUNT" -eq 0 ]; then
        echo -e "${GREEN}✅ Nenhum erro encontrado nos logs${NC}"
    else
        echo -e "${YELLOW}⚠️  Ainda há erros nos logs${NC}"
        echo -e "${CYAN}Últimos erros:${NC}"
        docker logs --tail=10 "$CONTAINER_NAME" 2>&1 | grep -E "Error|ReferenceError" | head -3
    fi
    
    # Testar API
    echo -e "\n${CYAN}🔌 Testando API...${NC}"
    HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" "http://localhost:4201/api/health" 2>/dev/null || echo "000")
    
    if [ "$HTTP_CODE" = "200" ]; then
        echo -e "${GREEN}✅ API respondendo corretamente (HTTP 200)${NC}"
    else
        echo -e "${YELLOW}⚠️  API retornou HTTP $HTTP_CODE${NC}"
    fi
    
    # Testar login page
    echo -e "\n${CYAN}🌐 Testando interface web...${NC}"
    WEB_CODE=$(curl -s -o /dev/null -w "%{http_code}" "http://localhost:4201/login" 2>/dev/null || echo "000")
    
    if [ "$WEB_CODE" = "200" ] || [ "$WEB_CODE" = "304" ]; then
        echo -e "${GREEN}✅ Interface web acessível${NC}"
    else
        echo -e "${YELLOW}⚠️  Interface retornou HTTP $WEB_CODE${NC}"
    fi
else
    echo -e "${RED}❌ Container não está rodando${NC}"
fi

# ================================================
# RESULTADO FINAL
# ================================================
echo ""
echo -e "${MAGENTA}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"

if [ "$CONTAINER_RUNNING" = true ] && [ "$ERROR_COUNT" -eq 0 ]; then
    echo -e "${GREEN}     ✅ ERRO CORRIGIDO COM SUCESSO!${NC}"
    echo -e "${MAGENTA}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo ""
    echo -e "${CYAN}🌐 SISTEMA FUNCIONANDO:${NC}"
    echo -e "   Dashboard: ${BLUE}http://localhost:4201${NC}"
    echo -e "   Login:     ${BLUE}http://localhost:4201/login${NC}"
    echo ""
    echo -e "${CYAN}🔐 SUAS CREDENCIAIS:${NC}"
    echo -e "   Email: ${YELLOW}girardellibaptista@gmail.com${NC}"
    echo -e "   Senha: ${YELLOW}Clara@123${NC}"
    echo ""
    echo -e "${GREEN}✨ Pronto para continuar com a integração do validador!${NC}"
    echo ""
    echo -e "${CYAN}📝 PRÓXIMO PASSO:${NC}"
    echo -e "   Execute o script de integração do validador avançado:"
    echo -e "   ${YELLOW}./integrate-advanced-validator.sh${NC}"
else
    echo -e "${YELLOW}     ⚠️  CORREÇÃO PARCIAL${NC}"
    echo -e "${MAGENTA}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo ""
    echo -e "${CYAN}📝 AÇÕES ADICIONAIS NECESSÁRIAS:${NC}"
    echo ""
    
    if [ "$CONTAINER_RUNNING" = false ]; then
        echo "1. Verificar logs completos:"
        echo -e "   ${YELLOW}docker-compose logs --tail=50 client-dashboard${NC}"
        echo ""
        echo "2. Tentar iniciar manualmente:"
        echo -e "   ${YELLOW}docker-compose up client-dashboard${NC}"
    else
        echo "1. Verificar erros persistentes:"
        echo -e "   ${YELLOW}docker logs --tail=50 $CONTAINER_NAME | grep Error${NC}"
        echo ""
        echo "2. Reiniciar o container:"
        echo -e "   ${YELLOW}docker-compose restart client-dashboard${NC}"
    fi
    echo ""
    echo "3. Se necessário, executar correção completa:"
    echo -e "   ${YELLOW}./fix-dashboard-complete.sh${NC}"
fi

echo ""

# ================================================
# CRIAR SCRIPT DE MONITORAMENTO
# ================================================
cat > monitor-fix.sh << 'EOMONITOR'
#!/bin/bash
echo "📊 Monitorando Client Dashboard..."
echo ""
echo "Container status:"
docker ps | grep client || echo "❌ Container não está rodando"
echo ""
echo "Últimos logs:"
docker logs --tail=5 $(docker ps --format "{{.Names}}" | grep -E "client" | head -1) 2>&1 | grep -v "GET\|POST"
echo ""
echo "API Health:"
curl -s http://localhost:4201/api/health | python3 -m json.tool 2>/dev/null || echo "❌ API não responde"
EOMONITOR
chmod +x monitor-fix.sh

echo -e "${GREEN}💡 Criado script de monitoramento: ${YELLOW}./monitor-fix.sh${NC}"
echo ""

exit 0