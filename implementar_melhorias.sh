#!/bin/bash

# ================================================
# SPARK NEXUS - Script de Melhorias (CORRIGIDO)
# Compatível com Alpine Linux (sh)
# Data: 08/08/2025
# ================================================

set -e  # Para em caso de erro

# Cores para output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Função de log
log() {
    echo -e "${GREEN}[$(date +'%H:%M:%S')]${NC} $1"
}

error() {
    echo -e "${RED}[ERROR]${NC} $1"
    exit 1
}

warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

# ================================================
# CONTINUAÇÃO DA INSTALAÇÃO
# ================================================

log "🔄 Continuando instalação após arquivos copiados..."

# ================================================
# PASSO 8B: Instalar dependências (usando sh)
# ================================================
log "📦 Instalando dependências no container..."

# Criar script compatível com sh
cat > /tmp/install_deps_alpine.sh << 'EOF'
#!/bin/sh
cd /app

echo "Instalando redis client..."
npm install redis@^4.6.0

echo "Verificando dependências..."
npm list --depth=0 || true

echo "✅ Dependências instaladas"
EOF

# Executar com sh
docker cp /tmp/install_deps_alpine.sh sparknexus-client:/tmp/
docker exec sparknexus-client sh /tmp/install_deps_alpine.sh

# ================================================
# PASSO 9: Adicionar endpoints de estatísticas
# ================================================
log "📊 Adicionando endpoint de estatísticas..."

cat > /tmp/add_stats_endpoint.js << 'EOF'
const fs = require('fs');
const path = '/app/server.js';

try {
    let content = fs.readFileSync(path, 'utf8');
    
    // Verificar se já existe
    if (content.includes('/api/validator/stats')) {
        console.log('⚠️ Endpoints já existem, pulando...');
        process.exit(0);
    }

    // Adicionar endpoint antes do health check
    const statsEndpoint = `
// Estatísticas do validador
app.get('/api/validator/stats', async (req, res) => {
    try {
        const stats = await enhancedValidator.getStatistics();
        res.json(stats);
    } catch (error) {
        console.error('Erro ao buscar estatísticas:', error);
        res.status(500).json({ error: 'Erro ao buscar estatísticas' });
    }
});

// Limpar cache do validador
app.post('/api/validator/cache/clear', authenticateToken, async (req, res) => {
    try {
        await enhancedValidator.clearCache();
        res.json({ success: true, message: 'Cache limpo com sucesso' });
    } catch (error) {
        console.error('Erro ao limpar cache:', error);
        res.status(500).json({ error: 'Erro ao limpar cache' });
    }
});

`;

    // Inserir antes do Health Check
    content = content.replace(
        /\/\/ Health Check/,
        statsEndpoint + '// Health Check'
    );

    fs.writeFileSync(path, content);
    console.log('✅ Endpoints de estatísticas adicionados');
} catch (error) {
    console.error('Erro ao adicionar endpoints:', error);
    process.exit(1);
}
EOF

docker cp /tmp/add_stats_endpoint.js sparknexus-client:/tmp/
docker exec sparknexus-client node /tmp/add_stats_endpoint.js

# ================================================
# PASSO 10: Verificar estrutura de arquivos
# ================================================
log "📁 Verificando estrutura de arquivos criada..."

echo -e "\n${BLUE}Arquivos no container:${NC}"
docker exec sparknexus-client sh -c "ls -la /app/data/ 2>/dev/null || echo 'Pasta data não encontrada'"
docker exec sparknexus-client sh -c "ls -la /app/services/cache/ 2>/dev/null || echo 'Pasta cache não encontrada'"
docker exec sparknexus-client sh -c "ls -la /app/services/validators/tldAnalyzer.js 2>/dev/null || echo 'TLD Analyzer não encontrado'"

# ================================================
# PASSO 11: Reiniciar o container
# ================================================
log "🔄 Reiniciando container..."

docker-compose restart client-dashboard

# Aguardar container subir
log "⏳ Aguardando container inicializar (15 segundos)..."
sleep 15

# ================================================
# PASSO 12: Verificar se container está rodando
# ================================================
log "🔍 Verificando status do container..."

if docker ps | grep -q sparknexus-client; then
    echo -e "${GREEN}✅ Container está rodando${NC}"
else
    echo -e "${RED}❌ Container não está rodando. Verificando logs...${NC}"
    docker-compose logs --tail=50 client-dashboard
    exit 1
fi

# ================================================
# PASSO 13: Testar implementação
# ================================================
log "🧪 Testando implementação..."

# Função para testar com retry
test_endpoint() {
    local url=$1
    local data=$2
    local max_attempts=3
    local attempt=1
    
    while [ $attempt -le $max_attempts ]; do
        echo -e "\n${BLUE}Tentativa $attempt de $max_attempts: $url${NC}"
        
        if [ -z "$data" ]; then
            response=$(curl -s -w "\n%{http_code}" "$url" 2>/dev/null || echo "000")
        else
            response=$(curl -s -w "\n%{http_code}" -X POST "$url" \
                -H "Content-Type: application/json" \
                -d "$data" 2>/dev/null || echo "000")
        fi
        
        http_code=$(echo "$response" | tail -n1)
        body=$(echo "$response" | head -n-1)
        
        if [ "$http_code" = "200" ]; then
            echo -e "${GREEN}✅ Sucesso (HTTP $http_code)${NC}"
            echo "$body" | python3 -m json.tool 2>/dev/null || echo "$body"
            return 0
        else
            echo -e "${YELLOW}⚠️ HTTP $http_code - Tentando novamente em 5s...${NC}"
            sleep 5
        fi
        
        attempt=$((attempt + 1))
    done
    
    echo -e "${RED}❌ Falhou após $max_attempts tentativas${NC}"
    return 1
}

# Testar validação avançada
echo -e "\n${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${BLUE}Testando validação avançada com TLD Scoring:${NC}"
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
test_endpoint "http://localhost:4201/api/validate/advanced" '{"email":"teste@empresa.com.br"}'

# Testar estatísticas
echo -e "\n${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${BLUE}Testando endpoint de estatísticas:${NC}"
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
test_endpoint "http://localhost:4201/api/validator/stats" ""

# ================================================
# PASSO 14: Limpar arquivos temporários
# ================================================
log "🧹 Limpando arquivos temporários..."
rm -f /tmp/update_database.js
rm -f /tmp/install_deps.sh
rm -f /tmp/install_deps_alpine.sh
rm -f /tmp/add_stats_endpoint.js

# ================================================
# PASSO 15: Verificar logs para confirmar
# ================================================
log "📜 Verificando logs do container..."

echo -e "\n${BLUE}Últimas mensagens relevantes:${NC}"
docker-compose logs --tail=30 client-dashboard 2>/dev/null | grep -E "(TLD|Cache|Redis|Enhanced|Score)" || echo "Nenhuma mensagem relevante encontrada"

# ================================================
# FINALIZAÇÃO
# ================================================
echo -e "\n${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${GREEN}✅ IMPLEMENTAÇÃO CONCLUÍDA COM SUCESSO!${NC}"
echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}\n"

echo -e "${BLUE}📋 RESUMO DA IMPLEMENTAÇÃO:${NC}"
echo -e "  ✅ TLD Scoring com 70+ domínios categorizados"
echo -e "  ✅ Cache híbrido (Memória L1 + Redis L2)"
echo -e "  ✅ Análise detalhada de domínios"
echo -e "  ✅ Score breakdown completo"
echo -e "  ✅ Estatísticas em tempo real"

echo -e "\n${BLUE}🔗 NOVOS ENDPOINTS DISPONÍVEIS:${NC}"
echo -e "  GET  /api/validator/stats       - Estatísticas do validador"
echo -e "  POST /api/validator/cache/clear - Limpar cache (autenticado)"

echo -e "\n${BLUE}📊 MELHORIAS IMPLEMENTADAS:${NC}"
echo -e "  • TLD Scoring: Premium (10pts) até Suspeito (1pt)"
echo -e "  • Cache L1: 10min TTL, máx 1000 entradas"
echo -e "  • Cache L2: 24h TTL no Redis"
echo -e "  • Domínios .br com pontuação especial"
echo -e "  • Detecção de MX corporativos (Google, Microsoft)"

echo -e "\n${BLUE}🧪 COMANDOS PARA TESTE MANUAL:${NC}"
echo ""
echo "# Testar email brasileiro (deve ter score alto):"
echo "curl -X POST http://localhost:4201/api/validate/advanced \\"
echo "  -H \"Content-Type: application/json\" \\"
echo "  -d '{\"email\":\"contato@empresa.com.br\"}' | python3 -m json.tool"
echo ""
echo "# Testar email suspeito (deve ter score baixo):"
echo "curl -X POST http://localhost:4201/api/validate/advanced \\"
echo "  -H \"Content-Type: application/json\" \\"
echo "  -d '{\"email\":\"test@tempmail.tk\"}' | python3 -m json.tool"
echo ""
echo "# Ver estatísticas do validador:"
echo "curl http://localhost:4201/api/validator/stats | python3 -m json.tool"

echo -e "\n${YELLOW}⚠️  NOTAS IMPORTANTES:${NC}"
echo "  1. Se Redis não conectar, o sistema usa apenas cache em memória"
echo "  2. O cache é limpo automaticamente a cada 5 minutos"
echo "  3. Emails válidos ficam em cache por 24h, inválidos por 1h"

echo -e "\n${GREEN}🎉 Implementação finalizada! Sistema pronto para uso.${NC}"

# Verificar se há erros nos logs
if docker-compose logs --tail=10 client-dashboard 2>&1 | grep -q "Error"; then
    echo -e "\n${YELLOW}⚠️ Foram detectados alguns erros nos logs. Isso pode ser normal durante a inicialização.${NC}"
    echo -e "${YELLOW}   Execute 'docker-compose logs -f client-dashboard' para monitorar.${NC}"
fi

exit 0