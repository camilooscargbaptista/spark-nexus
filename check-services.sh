#!/bin/bash

# ================================================
# Script de Verificação e Inicialização
# Spark Nexus - Check & Start
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
echo -e "${MAGENTA}🔍 VERIFICANDO SERVIÇOS DISPONÍVEIS${NC}"
echo -e "${MAGENTA}================================================${NC}"

# ================================================
# 1. VERIFICAR SERVIÇOS NO DOCKER-COMPOSE
# ================================================
echo -e "\n${BLUE}[1/5] Listando Serviços Configurados${NC}"
echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"

echo -e "${CYAN}Serviços disponíveis no docker-compose.yml:${NC}"
docker-compose config --services

# Salvar lista de serviços
SERVICES=$(docker-compose config --services)

# ================================================
# 2. VERIFICAR CONTAINERS ÓRFÃOS
# ================================================
echo -e "\n${BLUE}[2/5] Verificando Containers Órfãos${NC}"
echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"

# Listar containers órfãos
ORPHANS=$(docker ps -a --filter "name=sparknexus" --format "{{.Names}}")
if [ ! -z "$ORPHANS" ]; then
    echo -e "${YELLOW}Containers encontrados:${NC}"
    for container in $ORPHANS; do
        STATUS=$(docker inspect -f '{{.State.Status}}' $container 2>/dev/null || echo "unknown")
        echo "  • $container (status: $STATUS)"
    done
    
    echo -e "\n${YELLOW}Limpando containers órfãos...${NC}"
    docker-compose down --remove-orphans
else
    echo -e "${GREEN}✅ Nenhum container órfão${NC}"
fi

# ================================================
# 3. INICIAR SERVIÇOS ESSENCIAIS
# ================================================
echo -e "\n${BLUE}[3/5] Iniciando Serviços Essenciais${NC}"
echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"

# PostgreSQL e Redis
if echo "$SERVICES" | grep -q "postgres"; then
    echo "Iniciando PostgreSQL..."
    docker-compose up -d postgres
else
    echo -e "${YELLOW}⚠️ PostgreSQL não encontrado no docker-compose${NC}"
fi

if echo "$SERVICES" | grep -q "redis"; then
    echo "Iniciando Redis..."
    docker-compose up -d redis
else
    echo -e "${YELLOW}⚠️ Redis não encontrado no docker-compose${NC}"
fi

echo -e "${YELLOW}⏳ Aguardando serviços essenciais (15 segundos)...${NC}"
sleep 15

# ================================================
# 4. INICIAR SERVIÇOS DA APLICAÇÃO
# ================================================
echo -e "\n${BLUE}[4/5] Iniciando Aplicações Disponíveis${NC}"
echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"

# Lista de possíveis serviços da aplicação
POSSIBLE_SERVICES=(
    "client-dashboard"
    "auth"
    "admin-dashboard"
    "email-validator"
    "email-validator-worker"
    "api"
    "backend"
    "frontend"
)

for service in "${POSSIBLE_SERVICES[@]}"; do
    if echo "$SERVICES" | grep -q "^$service$"; then
        echo "Iniciando $service..."
        docker-compose up -d "$service"
    fi
done

# Verificar se o container órfão email-validator está rodando
if docker ps | grep -q "sparknexus-email-validator"; then
    echo -e "${GREEN}✅ Container sparknexus-email-validator já está rodando${NC}"
fi

echo -e "${YELLOW}⏳ Aguardando aplicações iniciarem (10 segundos)...${NC}"
sleep 10

# ================================================
# 5. STATUS FINAL
# ================================================
echo -e "\n${BLUE}[5/5] Status Final${NC}"
echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"

echo -e "${CYAN}📊 Containers Rodando:${NC}"
docker ps --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}" | grep sparknexus || echo "Verificando..."

# Testar endpoints
echo -e "\n${CYAN}🔍 Testando Endpoints:${NC}"

test_endpoint() {
    local url=$1
    local name=$2
    
    echo -n "  $name: "
    
    response=$(curl -s -o /dev/null -w "%{http_code}" "$url" 2>/dev/null || echo "000")
    
    if [ "$response" = "200" ] || [ "$response" = "301" ] || [ "$response" = "302" ]; then
        echo -e "${GREEN}✅ Online (HTTP $response)${NC}"
        return 0
    elif [ "$response" = "000" ]; then
        echo -e "${RED}❌ Não responde${NC}"
        return 1
    else
        echo -e "${YELLOW}⚠️ HTTP $response${NC}"
        return 1
    fi
}

# Testar portas comuns
test_endpoint "http://localhost:4200" "Porta 4200"
test_endpoint "http://localhost:4201" "Porta 4201"
test_endpoint "http://localhost:3000" "Porta 3000"
test_endpoint "http://localhost:3001" "Porta 3001"
test_endpoint "http://localhost:8080" "Porta 8080"

# ================================================
# CRIAR ARQUIVO DE TESTE
# ================================================
echo -e "\n${CYAN}📄 Criando Arquivo de Teste:${NC}"

if [ ! -f "test-emails.csv" ]; then
    cat > test-emails.csv << 'EOF'
email,name,company
contato@sparknexus.com.br,Contato Principal,Spark Nexus
teste@gmail.com,Teste Gmail,Test Company
invalid-email,Email Invalido,Test Company
admin@example.com,Admin User,Example Corp
info@google.com,Google Info,Google
support@microsoft.com,MS Support,Microsoft
hello@world.com,Hello World,World Inc
test@test.com,Test User,Test Inc
noreply@github.com,GitHub,GitHub Inc
contact@amazon.com,Amazon Contact,Amazon
EOF
    echo -e "${GREEN}✅ Arquivo test-emails.csv criado${NC}"
else
    echo -e "${GREEN}✅ Arquivo test-emails.csv já existe${NC}"
fi

# ================================================
# INSTRUÇÕES ESPECÍFICAS
# ================================================
echo ""
echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${GREEN}✅ SERVIÇOS INICIADOS!${NC}"
echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"

# Verificar qual porta está respondendo
WORKING_PORT=""
if curl -s -o /dev/null -w "%{http_code}" "http://localhost:4201" 2>/dev/null | grep -q "200\|301\|302"; then
    WORKING_PORT="4201"
elif curl -s -o /dev/null -w "%{http_code}" "http://localhost:4200" 2>/dev/null | grep -q "200\|301\|302"; then
    WORKING_PORT="4200"
elif curl -s -o /dev/null -w "%{http_code}" "http://localhost:3000" 2>/dev/null | grep -q "200\|301\|302"; then
    WORKING_PORT="3000"
fi

if [ ! -z "$WORKING_PORT" ]; then
    echo -e "\n${CYAN}🎯 SISTEMA DISPONÍVEL EM:${NC}"
    echo -e "  ${GREEN}http://localhost:$WORKING_PORT${NC}"
    echo -e "  ${GREEN}http://localhost:$WORKING_PORT/upload${NC}"
    
    # Abrir no navegador (macOS)
    if [[ "$OSTYPE" == "darwin"* ]]; then
        echo -e "\n${YELLOW}Abrindo navegador...${NC}"
        sleep 2
        open "http://localhost:$WORKING_PORT/upload" 2>/dev/null || open "http://localhost:$WORKING_PORT"
    fi
else
    echo -e "\n${YELLOW}⚠️ Nenhuma aplicação web encontrada nas portas padrão${NC}"
    echo "Verifique os logs para mais informações:"
    echo -e "  ${YELLOW}docker-compose logs${NC}"
fi

echo -e "\n${CYAN}🔍 COMANDOS ÚTEIS:${NC}"
echo "• Ver todos os logs: docker-compose logs -f"
echo "• Ver containers: docker ps"
echo "• Parar tudo: docker-compose down"
echo "• Reiniciar: docker-compose restart"

echo -e "\n${CYAN}📝 PARA VERIFICAR O DOCKER-COMPOSE:${NC}"
echo "cat docker-compose.yml | grep 'container_name\\|image\\|ports'"