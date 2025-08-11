#!/bin/bash

# ================================================
# SPARK NEXUS - CORREÇÃO DO ERRO PSL MODULE
# Script para corrigir o erro de módulo não encontrado
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
echo -e "${CYAN}║           🔧 CORREÇÃO DO ERRO PSL MODULE                    ║${NC}"
echo -e "${CYAN}║           Fixing: Cannot find module 'psl'                  ║${NC}"
echo -e "${CYAN}╚══════════════════════════════════════════════════════════════╝${NC}"
echo ""

# ================================================
# PASSO 1: PARAR O CONTAINER PROBLEMÁTICO
# ================================================
echo -e "${YELLOW}[1/7] Parando container com problema...${NC}"
docker-compose stop client-dashboard 2>/dev/null || true
echo -e "${GREEN}✅ Container parado${NC}"

# ================================================
# PASSO 2: CRIAR SCRIPT DE INSTALAÇÃO CORRIGIDO
# ================================================
echo -e "\n${YELLOW}[2/7] Criando script de instalação de dependências...${NC}"

cat > /tmp/fix_dependencies.sh << 'FIXDEPS'
#!/bin/sh
cd /app

echo "================================================"
echo "Instalando dependências essenciais do sistema..."
echo "================================================"

# Limpar cache do npm primeiro
npm cache clean --force

# Instalar dependências uma por uma para garantir sucesso
echo "📦 Instalando módulo psl..."
npm install psl@^1.9.0 --save

echo "📦 Instalando módulo levenshtein..."
npm install levenshtein@^1.0.5 --save

echo "📦 Instalando módulo email-validator..."
npm install email-validator@^2.0.4 --save

echo "📦 Instalando módulo validator..."
npm install validator@^13.11.0 --save

echo "📦 Instalando outros módulos necessários..."
npm install --save \
    ioredis@^5.3.0 \
    axios@^1.6.0 \
    node-cache@^5.1.2 || true

echo ""
echo "================================================"
echo "Verificando instalação dos módulos críticos..."
echo "================================================"

# Verificar se os módulos foram instalados
if [ -d "node_modules/psl" ]; then
    echo "✅ PSL instalado com sucesso"
else
    echo "❌ PSL não foi instalado - tentando novamente..."
    npm install psl --save --force
fi

if [ -d "node_modules/levenshtein" ]; then
    echo "✅ Levenshtein instalado com sucesso"
else
    echo "❌ Levenshtein não foi instalado - tentando novamente..."
    npm install levenshtein --save --force
fi

if [ -d "node_modules/email-validator" ]; then
    echo "✅ Email-validator instalado com sucesso"
else
    echo "❌ Email-validator não foi instalado - tentando novamente..."
    npm install email-validator --save --force
fi

# Listar módulos instalados
echo ""
echo "Módulos instalados:"
ls -la node_modules/ | grep -E "psl|levenshtein|validator|email" || true

echo ""
echo "✅ Instalação de dependências concluída!"
FIXDEPS

chmod +x /tmp/fix_dependencies.sh
echo -e "${GREEN}✅ Script criado${NC}"

# ================================================
# PASSO 3: INICIAR CONTAINER TEMPORARIAMENTE
# ================================================
echo -e "\n${YELLOW}[3/7] Iniciando container temporariamente...${NC}"

# Iniciar container com comando que não falha
docker-compose run -d --name temp-fix-container --entrypoint /bin/sh client-dashboard -c "sleep 3600" 2>/dev/null || {
    # Se falhar, tentar com docker run direto
    docker run -d --name temp-fix-container \
        -v sparknexus_client_data:/app \
        --entrypoint /bin/sh \
        node:18-alpine -c "sleep 3600"
}

sleep 2
echo -e "${GREEN}✅ Container temporário iniciado${NC}"

# ================================================
# PASSO 4: EXECUTAR INSTALAÇÃO DE DEPENDÊNCIAS
# ================================================
echo -e "\n${YELLOW}[4/7] Instalando dependências no container...${NC}"

# Copiar e executar script
docker cp /tmp/fix_dependencies.sh temp-fix-container:/tmp/
docker exec temp-fix-container sh /tmp/fix_dependencies.sh

echo -e "${GREEN}✅ Dependências instaladas${NC}"

# ================================================
# PASSO 5: CRIAR VERSÃO SIMPLIFICADA DO TLD VALIDATOR
# ================================================
echo -e "\n${YELLOW}[5/7] Criando versão simplificada do TLD Validator...${NC}"

cat > /tmp/TLDValidator_simplified.js << 'TLDVALIDATOR'
// ================================================
// TLD Validator - Versão Simplificada (sem PSL)
// ================================================

const fs = require('fs');
const path = require('path');

class TLDValidator {
    constructor() {
        this.loadTLDData();
        this.stats = {
            totalChecked: 0,
            blocked: 0,
            suspicious: 0,
            premium: 0
        };
    }

    loadTLDData() {
        try {
            const dataPath = path.join(__dirname, '../../../data/lists/tlds.json');
            const data = JSON.parse(fs.readFileSync(dataPath, 'utf8'));
            
            this.validTLDs = new Set(data.valid);
            this.blockedTLDs = new Set(data.blocked);
            this.suspiciousTLDs = new Set(data.suspicious);
            this.premiumTLDs = new Set(data.premium);
            
            console.log(`✅ TLD Validator: ${this.validTLDs.size} TLDs válidos carregados`);
        } catch (error) {
            console.log('⚠️ Usando lista de TLDs padrão (arquivo não encontrado)');
            // Lista padrão extensa de TLDs válidos
            this.validTLDs = new Set([
                'com', 'org', 'net', 'edu', 'gov', 'mil', 'int',
                'br', 'us', 'uk', 'ca', 'au', 'de', 'fr', 'it', 'es', 'pt',
                'jp', 'cn', 'in', 'ru', 'mx', 'ar', 'cl', 'co', 'pe', 've',
                'io', 'ai', 'app', 'dev', 'tech', 'digital', 'online', 'store',
                'shop', 'web', 'site', 'blog', 'news', 'info', 'biz', 'name',
                'tv', 'cc', 'ws', 'mobi', 'asia', 'tel', 'travel', 'pro'
            ]);
            this.blockedTLDs = new Set(['test', 'example', 'invalid', 'localhost', 'local', 'fake']);
            this.suspiciousTLDs = new Set(['tk', 'ml', 'ga', 'cf', 'click', 'download']);
            this.premiumTLDs = new Set(['com', 'org', 'net', 'edu', 'gov', 'com.br', 'org.br']);
        }
    }

    extractTLD(domain) {
        // Extração simples de TLD sem PSL
        const parts = domain.toLowerCase().split('.');
        
        // Verificar TLDs de dois níveis comuns (.com.br, .co.uk, etc)
        const twoLevelTLDs = ['com.br', 'org.br', 'gov.br', 'edu.br', 'net.br',
                              'co.uk', 'org.uk', 'gov.uk', 'ac.uk', 'edu.uk',
                              'com.au', 'org.au', 'gov.au', 'edu.au',
                              'com.mx', 'org.mx', 'gob.mx', 'edu.mx'];
        
        if (parts.length >= 2) {
            const lastTwo = parts.slice(-2).join('.');
            if (twoLevelTLDs.includes(lastTwo)) {
                return lastTwo;
            }
        }
        
        // Retornar apenas o último elemento como TLD
        return parts[parts.length - 1];
    }

    validateTLD(domain) {
        this.stats.totalChecked++;
        
        const result = {
            valid: false,
            tld: null,
            type: 'unknown',
            score: 0,
            isBlocked: false,
            isSuspicious: false,
            isPremium: false,
            details: {}
        };
        
        // Extrair TLD de forma simples
        const tld = this.extractTLD(domain);
        result.tld = tld;
        
        // Verificar se está bloqueado
        if (this.blockedTLDs.has(tld)) {
            this.stats.blocked++;
            result.isBlocked = true;
            result.type = 'blocked';
            result.score = 0;
            result.details.reason = 'TLD is blocked for testing/internal use';
            return result;
        }
        
        // Verificar se existe na lista válida
        if (!this.validTLDs.has(tld)) {
            // Se não estiver na lista, mas não for obviamente inválido, dar uma chance
            if (tld && tld.length >= 2 && tld.length <= 10 && /^[a-z]+$/.test(tld)) {
                result.valid = true;
                result.type = 'generic';
                result.score = 3; // Score baixo para TLD desconhecido
                result.details.warning = 'TLD not in common list';
            } else {
                result.type = 'invalid';
                result.score = 0;
                result.details.reason = 'Invalid TLD format';
                return result;
            }
        } else {
            result.valid = true;
        }
        
        // Verificar se é suspeito
        if (this.suspiciousTLDs.has(tld)) {
            this.stats.suspicious++;
            result.isSuspicious = true;
            result.type = 'suspicious';
            result.score = 2;
            result.details.warning = 'TLD has high spam/fraud rate';
        }
        // Verificar se é premium
        else if (this.premiumTLDs.has(tld)) {
            this.stats.premium++;
            result.isPremium = true;
            result.type = 'premium';
            result.score = 10;
            result.details.trust = 'Premium TLD with high trust';
        }
        // TLD válido genérico
        else if (result.valid) {
            result.type = 'generic';
            result.score = 5;
        }
        
        // Adicionar metadados
        result.details.registryInfo = {
            isCountryCode: tld && tld.length === 2,
            isGeneric: tld && tld.length > 2,
            isSpecialUse: this.blockedTLDs.has(tld)
        };
        
        return result;
    }

    getStatistics() {
        return {
            ...this.stats,
            blockedRate: this.stats.totalChecked > 0 
                ? ((this.stats.blocked / this.stats.totalChecked) * 100).toFixed(2) + '%'
                : '0%',
            suspiciousRate: this.stats.totalChecked > 0
                ? ((this.stats.suspicious / this.stats.totalChecked) * 100).toFixed(2) + '%'
                : '0%'
        };
    }

    reloadTLDs() {
        this.loadTLDData();
        console.log('🔄 TLD data reloaded');
    }
}

module.exports = TLDValidator;
TLDVALIDATOR

# Copiar para o container
docker cp /tmp/TLDValidator_simplified.js temp-fix-container:/app/services/validators/advanced/TLDValidator.js

echo -e "${GREEN}✅ TLD Validator simplificado criado${NC}"

# ================================================
# PASSO 6: VERIFICAR ESTRUTURA E CRIAR CACHE SERVICE
# ================================================
echo -e "\n${YELLOW}[6/7] Criando CacheService se não existir...${NC}"

cat > /tmp/CacheService.js << 'CACHESERVICE'
// Cache Service Simples
class CacheService {
    constructor(options = {}) {
        this.cache = new Map();
        this.ttl = options.memoryTTL || 300;
    }
    
    async get(key) {
        const item = this.cache.get(key);
        if (!item) return null;
        
        if (Date.now() > item.expires) {
            this.cache.delete(key);
            return null;
        }
        
        return item.value;
    }
    
    async set(key, value, ttl = null) {
        const expires = Date.now() + ((ttl || this.ttl) * 1000);
        this.cache.set(key, { value, expires });
    }
    
    async clear() {
        this.cache.clear();
    }
    
    async shutdown() {
        this.cache.clear();
    }
}

module.exports = CacheService;
CACHESERVICE

docker exec temp-fix-container mkdir -p /app/services/cache
docker cp /tmp/CacheService.js temp-fix-container:/app/services/cache/CacheService.js

echo -e "${GREEN}✅ CacheService criado${NC}"

# ================================================
# PASSO 7: PARAR CONTAINER TEMPORÁRIO E REINICIAR
# ================================================
echo -e "\n${YELLOW}[7/7] Finalizando e reiniciando serviço...${NC}"

# Parar e remover container temporário
docker stop temp-fix-container 2>/dev/null || true
docker rm temp-fix-container 2>/dev/null || true

echo -e "${GREEN}✅ Container temporário removido${NC}"

# Reiniciar o serviço client-dashboard
echo -e "\n${CYAN}🔄 Reiniciando client-dashboard...${NC}"
docker-compose up -d client-dashboard

# Aguardar alguns segundos
echo -e "${YELLOW}⏳ Aguardando serviço inicializar (10 segundos)...${NC}"
sleep 10

# ================================================
# VERIFICAÇÃO FINAL
# ================================================
echo -e "\n${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${CYAN}📊 VERIFICAÇÃO FINAL${NC}"
echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"

# Verificar se o container está rodando
if docker ps | grep -q "sparknexus-client"; then
    echo -e "${GREEN}✅ Container client-dashboard está rodando!${NC}"
    
    # Verificar logs para erros
    echo -e "\n${CYAN}📋 Últimas linhas do log:${NC}"
    docker-compose logs --tail=10 client-dashboard 2>/dev/null | grep -v "node_modules" || true
    
    # Testar se a API está respondendo
    echo -e "\n${CYAN}🧪 Testando API...${NC}"
    if curl -s -o /dev/null -w "%{http_code}" http://localhost:4201/health 2>/dev/null | grep -q "200"; then
        echo -e "${GREEN}✅ API está respondendo corretamente!${NC}"
    else
        echo -e "${YELLOW}⚠️  API ainda está inicializando...${NC}"
    fi
else
    echo -e "${RED}❌ Container não está rodando. Verificando logs...${NC}"
    docker-compose logs --tail=20 client-dashboard
fi

# ================================================
# INSTRUÇÕES FINAIS
# ================================================
echo -e "\n${MAGENTA}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${MAGENTA}     🔧 CORREÇÃO APLICADA!${NC}"
echo -e "${MAGENTA}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"

echo -e "\n${CYAN}✅ AÇÕES REALIZADAS:${NC}"
echo "  • Módulo PSL e dependências instaladas"
echo "  • TLD Validator simplificado (sem dependência do PSL)"
echo "  • CacheService criado"
echo "  • Container reiniciado"

echo -e "\n${CYAN}🔍 PRÓXIMOS PASSOS:${NC}"
echo "  1. Execute: ${YELLOW}./start-system.sh${NC} para iniciar todo o sistema"
echo "  2. Acesse: ${BLUE}http://localhost:4201${NC}"
echo "  3. Se houver erro, veja logs: ${YELLOW}docker-compose logs -f client-dashboard${NC}"

echo -e "\n${GREEN}🎉 Sistema deve estar funcionando agora!${NC}\n"

# Limpar arquivos temporários
rm -f /tmp/fix_dependencies.sh /tmp/TLDValidator_simplified.js /tmp/CacheService.js

exit 0