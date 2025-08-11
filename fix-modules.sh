#!/bin/bash

# ================================================
# SPARK NEXUS - FIX MISSING MODULES
# Instala os módulos psl e levenshtein definitivamente
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
echo -e "${CYAN}║         🔧 FIX MISSING MODULES - PSL & LEVENSHTEIN          ║${NC}"
echo -e "${CYAN}║              Instalação definitiva dos módulos              ║${NC}"
echo -e "${CYAN}╚══════════════════════════════════════════════════════════════╝${NC}"
echo ""

# ================================================
# PASSO 1: PARAR O CONTAINER EM LOOP
# ================================================
echo -e "${YELLOW}[1/5] Parando container client-dashboard...${NC}"
docker-compose stop client-dashboard
docker rm -f sparknexus-client 2>/dev/null || true
echo -e "${GREEN}✅ Container parado${NC}"

# ================================================
# PASSO 2: CRIAR CONTAINER TEMPORÁRIO COM VOLUME
# ================================================
echo -e "\n${YELLOW}[2/5] Criando container temporário para instalação...${NC}"

# Usar o mesmo volume do client-dashboard
docker run -d \
  --name temp-installer \
  -v sparknexus_client_data:/app \
  -w /app \
  node:18-alpine \
  sleep 3600

sleep 2
echo -e "${GREEN}✅ Container temporário criado${NC}"

# ================================================
# PASSO 3: INSTALAR DEPENDÊNCIAS FALTANTES
# ================================================
echo -e "\n${YELLOW}[3/5] Instalando módulos faltantes...${NC}"

# Criar script de instalação dentro do container
docker exec temp-installer sh -c '
echo "================================================"
echo "Iniciando instalação de dependências..."
echo "================================================"

# Verificar se package.json existe
if [ ! -f package.json ]; then
    echo "❌ package.json não encontrado. Criando um básico..."
    echo "{\"name\":\"client-dashboard\",\"version\":\"1.0.0\",\"dependencies\":{}}" > package.json
fi

# Limpar cache do npm
echo "🧹 Limpando cache do npm..."
npm cache clean --force 2>/dev/null || true

# Instalar psl
echo ""
echo "📦 Instalando psl..."
npm install psl@^1.9.0 --save
if [ -d "node_modules/psl" ]; then
    echo "✅ psl instalado com sucesso!"
else
    echo "❌ Falha ao instalar psl - tentando novamente..."
    npm install psl --save --force
fi

# Instalar levenshtein
echo ""
echo "📦 Instalando levenshtein..."
npm install levenshtein@^1.0.5 --save
if [ -d "node_modules/levenshtein" ]; then
    echo "✅ levenshtein instalado com sucesso!"
else
    echo "❌ Falha ao instalar levenshtein - tentando novamente..."
    npm install levenshtein --save --force
fi

# Instalar outras dependências que podem estar faltando
echo ""
echo "📦 Instalando outras dependências necessárias..."
npm install --save \
    email-validator@^2.0.4 \
    validator@^13.11.0 \
    ioredis@^5.3.0 \
    axios@^1.6.0 \
    node-cache@^5.1.2 \
    2>/dev/null || true

echo ""
echo "================================================"
echo "Verificando instalação..."
echo "================================================"

# Verificar se os módulos foram instalados
echo ""
if [ -d "node_modules/psl" ]; then
    echo "✅ PSL: $(ls -la node_modules/psl/package.json | awk '"'"'{print $5}'"'"') bytes"
else
    echo "❌ PSL não está instalado!"
fi

if [ -d "node_modules/levenshtein" ]; then
    echo "✅ LEVENSHTEIN: $(ls -la node_modules/levenshtein/package.json | awk '"'"'{print $5}'"'"') bytes"
else
    echo "❌ LEVENSHTEIN não está instalado!"
fi

# Contar total de módulos
TOTAL_MODULES=$(ls -1 node_modules 2>/dev/null | wc -l)
echo ""
echo "📊 Total de módulos instalados: $TOTAL_MODULES"

# Verificar se os requires funcionam
echo ""
echo "🧪 Testando requires..."
node -e "try { require('"'"'psl'"'"'); console.log('"'"'✅ psl carrega corretamente'"'"'); } catch(e) { console.log('"'"'❌ Erro ao carregar psl:'"'"', e.message); }"
node -e "try { require('"'"'levenshtein'"'"'); console.log('"'"'✅ levenshtein carrega corretamente'"'"'); } catch(e) { console.log('"'"'❌ Erro ao carregar levenshtein:'"'"', e.message); }"
'

echo -e "${GREEN}✅ Módulos instalados${NC}"

# ================================================
# PASSO 4: VERIFICAR INSTALAÇÃO
# ================================================
echo -e "\n${YELLOW}[4/5] Verificando instalação final...${NC}"

docker exec temp-installer sh -c '
echo "📋 Listando módulos críticos instalados:"
ls -la node_modules/ | grep -E "psl|levenshtein|validator|email" | head -20

echo ""
echo "📄 Conteúdo do package.json:"
cat package.json | grep -A 20 "dependencies" | head -25
'

# ================================================
# PASSO 5: LIMPAR E REINICIAR
# ================================================
echo -e "\n${YELLOW}[5/5] Limpando e reiniciando serviço...${NC}"

# Parar e remover container temporário
docker stop temp-installer >/dev/null 2>&1
docker rm temp-installer >/dev/null 2>&1
echo -e "${GREEN}✅ Container temporário removido${NC}"

# Reiniciar o client-dashboard
echo -e "${CYAN}🔄 Reiniciando client-dashboard...${NC}"
docker-compose up -d client-dashboard

# Aguardar inicialização
echo -e "${YELLOW}⏳ Aguardando serviço inicializar (15 segundos)...${NC}"
for i in {1..15}; do
    echo -n "."
    sleep 1
done
echo ""

# ================================================
# VERIFICAÇÃO FINAL
# ================================================
echo -e "\n${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${CYAN}📊 VERIFICAÇÃO FINAL${NC}"
echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"

# Verificar se o container está rodando
if docker ps | grep -q "sparknexus-client"; then
    echo -e "${GREEN}✅ Container client-dashboard está RODANDO!${NC}"
    
    # Verificar se há erros nos logs
    echo -e "\n${CYAN}📋 Últimas linhas do log:${NC}"
    docker-compose logs --tail=5 client-dashboard 2>&1 | grep -v "node_modules" || true
    
    # Verificar se ainda há erro de módulo
    if docker-compose logs --tail=20 client-dashboard 2>&1 | grep -q "Cannot find module"; then
        echo -e "\n${RED}⚠️  ATENÇÃO: Ainda há erros de módulo. Verificando...${NC}"
        docker-compose logs --tail=20 client-dashboard 2>&1 | grep "Cannot find module" | head -5
    else
        echo -e "\n${GREEN}✅ Nenhum erro de módulo detectado!${NC}"
    fi
    
    # Testar endpoint
    echo -e "\n${CYAN}🧪 Testando API...${NC}"
    sleep 3
    RESPONSE=$(curl -s -o /dev/null -w "%{http_code}" http://localhost:4201/health 2>/dev/null || echo "000")
    
    if [ "$RESPONSE" = "200" ]; then
        echo -e "${GREEN}✅ API respondendo corretamente! (HTTP $RESPONSE)${NC}"
    elif [ "$RESPONSE" = "000" ]; then
        echo -e "${YELLOW}⚠️  API ainda não está pronta. Aguarde mais alguns segundos...${NC}"
    else
        echo -e "${YELLOW}⚠️  API retornou código HTTP $RESPONSE${NC}"
    fi
else
    echo -e "${RED}❌ Container não está rodando. Verificando logs...${NC}"
    docker-compose logs --tail=30 client-dashboard
fi

# ================================================
# INSTRUÇÕES FINAIS
# ================================================
echo -e "\n${MAGENTA}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${MAGENTA}     🔧 INSTALAÇÃO DE MÓDULOS CONCLUÍDA!${NC}"
echo -e "${MAGENTA}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"

echo -e "\n${CYAN}📝 PRÓXIMOS PASSOS:${NC}"
echo -e "  1. Verifique os logs: ${YELLOW}docker-compose logs -f client-dashboard${NC}"
echo -e "  2. Se ainda houver erros, execute novamente este script"
echo -e "  3. Teste a API: ${YELLOW}curl http://localhost:4201/health${NC}"

echo -e "\n${CYAN}🔍 COMANDOS ÚTEIS:${NC}"
echo -e "  Ver logs em tempo real: ${YELLOW}docker-compose logs -f client-dashboard${NC}"
echo -e "  Reiniciar serviço: ${YELLOW}docker-compose restart client-dashboard${NC}"
echo -e "  Verificar módulos: ${YELLOW}docker exec sparknexus-client ls -la node_modules/ | grep -E 'psl|leven'${NC}"

echo -e "\n${GREEN}✅ Script concluído!${NC}\n"

exit 0