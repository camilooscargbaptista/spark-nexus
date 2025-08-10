#!/bin/bash

# ================================================
# CORREÇÃO: Redis Auth e Email Validator
# ================================================

set -e

# Cores
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}🔧 Corrigindo problemas encontrados...${NC}"

# ================================================
# CORREÇÃO 1: Import do email-validator
# ================================================
echo -e "${YELLOW}1. Corrigindo import do email-validator...${NC}"

cat > /tmp/fix_validator_import.js << 'EOF'
const fs = require('fs');

// Corrigir enhancedValidator.js
let content = fs.readFileSync('/app/enhancedValidator.js', 'utf8');

// Corrigir o import do email-validator
content = content.replace(
    "const { validateEmail } = require('email-validator');",
    "const emailValidator = require('email-validator');"
);

// Corrigir o uso da função
content = content.replace(
    "return {\n            valid: validateEmail(email),",
    "return {\n            valid: emailValidator.validate(email),"
);

fs.writeFileSync('/app/enhancedValidator.js', content);
console.log('✅ Import do email-validator corrigido');
EOF

docker exec sparknexus-client node /tmp/fix_validator_import.js

# ================================================
# CORREÇÃO 2: Redis com autenticação
# ================================================
echo -e "${YELLOW}2. Corrigindo configuração do Redis...${NC}"

cat > /tmp/fix_redis_auth.js << 'EOF'
const fs = require('fs');

// 1. Corrigir CacheService.js
let cacheContent = fs.readFileSync('/app/services/cache/CacheService.js', 'utf8');

// Adicionar senha do Redis
cacheContent = cacheContent.replace(
    "url: process.env.REDIS_URL || 'redis://redis:6379',",
    `url: process.env.REDIS_URL || 'redis://default:SparkNexus2024!@redis:6379',
            password: process.env.REDIS_PASSWORD || 'SparkNexus2024!',`
);

fs.writeFileSync('/app/services/cache/CacheService.js', cacheContent);
console.log('✅ CacheService.js - Redis auth configurado');

// 2. Corrigir database.js
let dbContent = fs.readFileSync('/app/services/database.js', 'utf8');

// Remover tentativa de setar isOpen (é readonly)
dbContent = dbContent.replace(
    /this\.redis\.isOpen = true;/g,
    '// isOpen é readonly'
);

dbContent = dbContent.replace(
    /this\.redis\.isOpen = false;/g,
    '// isOpen é readonly'
);

// Adicionar senha na conexão
dbContent = dbContent.replace(
    "url: process.env.REDIS_URL || 'redis://redis:6379',",
    `url: process.env.REDIS_URL || 'redis://default:SparkNexus2024!@redis:6379',
                password: process.env.REDIS_PASSWORD || 'SparkNexus2024!',`
);

fs.writeFileSync('/app/services/database.js', dbContent);
console.log('✅ database.js - Redis auth configurado e isOpen corrigido');
EOF

docker exec sparknexus-client node /tmp/fix_redis_auth.js

# ================================================
# CORREÇÃO 3: Verificar se Redis está com senha
# ================================================
echo -e "${YELLOW}3. Verificando configuração do Redis...${NC}"

# Testar conexão Redis com senha
docker exec sparknexus-redis sh -c "redis-cli -a 'SparkNexus2024!' ping" 2>/dev/null || echo "Redis sem senha"

# ================================================
# CORREÇÃO 4: Adicionar fallback caso Redis falhe
# ================================================
echo -e "${YELLOW}4. Melhorando fallback do Redis...${NC}"

cat > /tmp/improve_redis_fallback.js << 'EOF'
const fs = require('fs');

// Melhorar o fallback no CacheService
let content = fs.readFileSync('/app/services/cache/CacheService.js', 'utf8');

// Adicionar melhor tratamento de erro
if (!content.includes('// Fallback melhorado')) {
    content = content.replace(
        'this.redis.on(\'error\', (err) => {',
        `this.redis.on('error', (err) => {
                // Fallback melhorado
                if (err.message.includes('NOAUTH') || err.message.includes('Authentication')) {
                    console.error('❌ Redis: Erro de autenticação. Usando apenas cache em memória.');
                } else {
                    console.error('Redis error:', err.message);
                }`
    );
}

fs.writeFileSync('/app/services/cache/CacheService.js', content);
console.log('✅ Fallback do Redis melhorado');
EOF

docker exec sparknexus-client node /tmp/improve_redis_fallback.js

# ================================================
# PASSO 5: Reiniciar container
# ================================================
echo -e "${GREEN}5. Reiniciando container...${NC}"
docker-compose restart client-dashboard

echo -e "${YELLOW}⏳ Aguardando 10 segundos...${NC}"
sleep 10

# ================================================
# PASSO 6: Testar correções
# ================================================
echo -e "${BLUE}6. Testando correções...${NC}"

echo -e "\n${GREEN}Teste 1: Validação de email brasileiro (.com.br)${NC}"
curl -s -X POST http://localhost:4201/api/validate/advanced \
  -H "Content-Type: application/json" \
  -d '{"email":"contato@empresa.com.br"}' | python3 -m json.tool 2>/dev/null || \
  curl -X POST http://localhost:4201/api/validate/advanced \
    -H "Content-Type: application/json" \
    -d '{"email":"contato@empresa.com.br"}'

echo -e "\n${GREEN}Teste 2: Validação de email suspeito (.tk)${NC}"
curl -s -X POST http://localhost:4201/api/validate/advanced \
  -H "Content-Type: application/json" \
  -d '{"email":"spam@tempmail.tk"}' | python3 -m json.tool 2>/dev/null || \
  curl -X POST http://localhost:4201/api/validate/advanced \
    -H "Content-Type: application/json" \
    -d '{"email":"spam@tempmail.tk"}'

echo -e "\n${GREEN}Teste 3: Estatísticas do validador${NC}"
curl -s http://localhost:4201/api/validator/stats | python3 -m json.tool 2>/dev/null || \
  curl http://localhost:4201/api/validator/stats

# ================================================
# VERIFICAR LOGS
# ================================================
echo -e "\n${BLUE}7. Verificando logs para erros...${NC}"
docker-compose logs --tail=20 client-dashboard 2>&1 | grep -E "(Error|error|Redis|conectado)" || echo "Sem erros recentes"

# ================================================
# FINALIZAÇÃO
# ================================================
echo -e "\n${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${GREEN}✅ CORREÇÕES APLICADAS!${NC}"
echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"

echo -e "\n${BLUE}📝 O que foi corrigido:${NC}"
echo "  ✅ Import do email-validator"
echo "  ✅ Autenticação do Redis"
echo "  ✅ Propriedade isOpen (readonly)"
echo "  ✅ Fallback melhorado"

echo -e "\n${BLUE}🧪 Teste manual adicional:${NC}"
echo ""
echo "# Email válido (Gmail):"
echo 'curl -X POST http://localhost:4201/api/validate/advanced -H "Content-Type: application/json" -d '"'"'{"email":"usuario@gmail.com"}'"'"''
echo ""
echo "# Email inválido:"
echo 'curl -X POST http://localhost:4201/api/validate/advanced -H "Content-Type: application/json" -d '"'"'{"email":"fake@10minutemail.com"}'"'"''

echo -e "\n${GREEN}Sistema deve estar funcionando agora! 🎉${NC}"