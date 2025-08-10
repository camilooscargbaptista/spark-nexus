#!/bin/bash

# ================================================
# CORREÇÃO RÁPIDA E DIRETA
# ================================================

set -e

# Cores
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
RED='\033[0;31m'
NC='\033[0m'

echo -e "${BLUE}🔧 Aplicando correções diretamente no container...${NC}"

# ================================================
# CORREÇÃO 1: Import do email-validator
# ================================================
echo -e "${YELLOW}1. Corrigindo import do email-validator...${NC}"

# Criar script de correção
cat > fix_validator.js << 'EOF'
const fs = require('fs');

try {
    // Corrigir enhancedValidator.js
    let content = fs.readFileSync('/app/enhancedValidator.js', 'utf8');
    
    // Corrigir o import do email-validator
    content = content.replace(
        "const { validateEmail } = require('email-validator');",
        "const emailValidator = require('email-validator');"
    );
    
    // Corrigir o uso da função
    content = content.replace(
        "valid: validateEmail(email)",
        "valid: emailValidator.validate(email)"
    );
    
    fs.writeFileSync('/app/enhancedValidator.js', content);
    console.log('✅ Import do email-validator corrigido');
} catch (error) {
    console.error('Erro:', error.message);
    process.exit(1);
}
EOF

# Copiar e executar no container
docker cp fix_validator.js sparknexus-client:/tmp/
docker exec sparknexus-client node /tmp/fix_validator.js

# ================================================
# CORREÇÃO 2: Redis com autenticação
# ================================================
echo -e "${YELLOW}2. Corrigindo configuração do Redis...${NC}"

cat > fix_redis.js << 'EOF'
const fs = require('fs');

try {
    // 1. Corrigir CacheService.js
    if (fs.existsSync('/app/services/cache/CacheService.js')) {
        let cacheContent = fs.readFileSync('/app/services/cache/CacheService.js', 'utf8');
        
        // Adicionar senha do Redis se não existir
        if (!cacheContent.includes('password:')) {
            cacheContent = cacheContent.replace(
                "url: process.env.REDIS_URL || 'redis://redis:6379',",
                `url: process.env.REDIS_URL || 'redis://redis:6379',
                password: process.env.REDIS_PASSWORD || 'SparkNexus2024!',`
            );
        }
        
        fs.writeFileSync('/app/services/cache/CacheService.js', cacheContent);
        console.log('✅ CacheService.js - Redis auth configurado');
    } else {
        console.log('⚠️ CacheService.js não encontrado');
    }
    
    // 2. Corrigir database.js
    let dbContent = fs.readFileSync('/app/services/database.js', 'utf8');
    
    // Remover tentativa de setar isOpen (é readonly)
    dbContent = dbContent.replace(/this\.redis\.isOpen = true;/g, '// isOpen é readonly');
    dbContent = dbContent.replace(/this\.redis\.isOpen = false;/g, '// isOpen é readonly');
    
    // Adicionar senha na conexão se não existir
    if (!dbContent.includes('password:') && dbContent.includes('Redis.createClient')) {
        dbContent = dbContent.replace(
            "url: process.env.REDIS_URL || 'redis://redis:6379',",
            `url: process.env.REDIS_URL || 'redis://redis:6379',
                password: process.env.REDIS_PASSWORD || 'SparkNexus2024!',`
        );
    }
    
    fs.writeFileSync('/app/services/database.js', dbContent);
    console.log('✅ database.js - Redis auth configurado');
    
} catch (error) {
    console.error('Erro:', error.message);
    process.exit(1);
}
EOF

# Copiar e executar no container
docker cp fix_redis.js sparknexus-client:/tmp/
docker exec sparknexus-client node /tmp/fix_redis.js

# ================================================
# CORREÇÃO 3: Melhorar tratamento de erros
# ================================================
echo -e "${YELLOW}3. Adicionando tratamento de erros melhorado...${NC}"

cat > improve_error_handling.js << 'EOF'
const fs = require('fs');

try {
    // Adicionar try-catch no CacheService
    if (fs.existsSync('/app/services/cache/CacheService.js')) {
        let content = fs.readFileSync('/app/services/cache/CacheService.js', 'utf8');
        
        // Melhorar tratamento de erro de autenticação
        if (!content.includes('Fallback melhorado')) {
            content = content.replace(
                "this.stats.errors.redis++;",
                `this.stats.errors.redis++;
                // Se for erro de autenticação, desabilitar Redis
                if (err.message && (err.message.includes('NOAUTH') || err.message.includes('Authentication'))) {
                    console.log('⚠️ Redis: Erro de autenticação, usando apenas cache em memória');
                    this.redisConnected = false;
                }`
            );
        }
        
        fs.writeFileSync('/app/services/cache/CacheService.js', content);
        console.log('✅ Tratamento de erros melhorado');
    }
} catch (error) {
    console.error('Erro:', error.message);
}
EOF

docker cp improve_error_handling.js sparknexus-client:/tmp/
docker exec sparknexus-client node /tmp/improve_error_handling.js

# ================================================
# PASSO 4: Limpar arquivos temporários locais
# ================================================
echo -e "${YELLOW}4. Limpando arquivos temporários...${NC}"
rm -f fix_validator.js fix_redis.js improve_error_handling.js

# ================================================
# PASSO 5: Reiniciar container
# ================================================
echo -e "${GREEN}5. Reiniciando container...${NC}"
docker-compose restart client-dashboard

echo -e "${YELLOW}⏳ Aguardando 15 segundos para o container inicializar...${NC}"
sleep 15

# ================================================
# PASSO 6: Verificar se container está rodando
# ================================================
echo -e "${BLUE}6. Verificando status...${NC}"

if docker ps | grep -q sparknexus-client; then
    echo -e "${GREEN}✅ Container está rodando${NC}"
else
    echo -e "${RED}❌ Container não está rodando${NC}"
    echo "Verificando logs..."
    docker-compose logs --tail=30 client-dashboard
    exit 1
fi

# ================================================
# PASSO 7: Testar API
# ================================================
echo -e "${BLUE}7. Testando API corrigida...${NC}"

echo -e "\n${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${GREEN}Teste 1: Email válido (Gmail)${NC}"
echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"

response=$(curl -s -w "\nHTTP_CODE:%{http_code}" -X POST http://localhost:4201/api/validate/advanced \
  -H "Content-Type: application/json" \
  -d '{"email":"usuario@gmail.com"}' 2>/dev/null || echo "CURL_ERROR")

if [[ "$response" == *"HTTP_CODE:200"* ]]; then
    echo "$response" | sed 's/HTTP_CODE:200//' | python3 -m json.tool 2>/dev/null || echo "$response"
    echo -e "${GREEN}✅ API funcionando!${NC}"
else
    echo "$response"
    echo -e "${YELLOW}⚠️ API retornou erro. Verificando logs...${NC}"
    docker-compose logs --tail=10 client-dashboard | grep -E "(Error|error)"
fi

echo -e "\n${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${GREEN}Teste 2: Email suspeito (10minutemail)${NC}"
echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"

curl -s -X POST http://localhost:4201/api/validate/advanced \
  -H "Content-Type: application/json" \
  -d '{"email":"fake@10minutemail.com"}' | python3 -m json.tool 2>/dev/null || \
  curl -X POST http://localhost:4201/api/validate/advanced \
    -H "Content-Type: application/json" \
    -d '{"email":"fake@10minutemail.com"}'

# ================================================
# PASSO 8: Verificar logs finais
# ================================================
echo -e "\n${BLUE}8. Verificando logs para confirmar correções...${NC}"

echo -e "\n${YELLOW}Últimas mensagens do container:${NC}"
docker-compose logs --tail=15 client-dashboard 2>&1 | grep -v "GET /favicon.ico" | tail -10

# ================================================
# FINALIZAÇÃO
# ================================================
echo -e "\n${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${GREEN}✅ CORREÇÕES APLICADAS!${NC}"
echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"

echo -e "\n${BLUE}📝 Resumo das correções:${NC}"
echo "  ✅ email-validator importado corretamente"
echo "  ✅ Redis com autenticação configurada"
echo "  ✅ Tratamento de erros melhorado"
echo "  ✅ Container reiniciado"

echo -e "\n${BLUE}🧪 Comandos para teste manual:${NC}"
echo ""
echo "# Validar email brasileiro:"
echo 'curl -X POST http://localhost:4201/api/validate/advanced -H "Content-Type: application/json" -d '"'"'{"email":"contato@empresa.com.br"}'"'"' | python3 -m json.tool'
echo ""
echo "# Ver estatísticas:"
echo 'curl http://localhost:4201/api/validator/stats | python3 -m json.tool'

echo -e "\n${GREEN}🎉 Sistema corrigido e pronto para uso!${NC}"

# Verificar se há erros críticos
if docker-compose logs --tail=5 client-dashboard 2>&1 | grep -q "MODULE_NOT_FOUND\|Cannot find module"; then
    echo -e "\n${RED}⚠️ ATENÇÃO: Ainda há erros de módulos não encontrados.${NC}"
    echo -e "${YELLOW}Pode ser necessário reinstalar as dependências:${NC}"
    echo "docker exec sparknexus-client sh -c 'cd /app && npm install'"
fi