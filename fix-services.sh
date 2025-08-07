#!/bin/bash

# ============================================
# FIX SERVICES - Corrigir serviços que falharam
# ============================================

echo "🔧 Corrigindo serviços que falharam no build..."

# Cores
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
RED='\033[0;31m'
NC='\033[0m'

# ============================================
# PARTE 1: Gerar package-lock.json para cada serviço
# ============================================

echo -e "${BLUE}📦 Gerando package-lock.json para os serviços...${NC}"

# Função para criar package-lock.json
fix_service() {
    local service_path=$1
    local service_name=$2
    
    echo -e "${YELLOW}Corrigindo $service_name...${NC}"
    
    if [ -d "$service_path" ]; then
        cd "$service_path"
        
        # Se não existe package-lock.json, criar
        if [ ! -f "package-lock.json" ]; then
            echo "Gerando package-lock.json..."
            npm install
        fi
        
        cd - > /dev/null
        echo -e "${GREEN}✅ $service_name corrigido${NC}"
    else
        echo -e "${RED}❌ Pasta $service_path não encontrada${NC}"
    fi
}

# Corrigir cada serviço
fix_service "core/auth-service" "Auth Service"
fix_service "core/billing-service" "Billing Service"
fix_service "core/tenant-service" "Tenant Service"

# ============================================
# PARTE 2: Atualizar Dockerfiles para usar npm install
# ============================================

echo -e "${BLUE}🐳 Atualizando Dockerfiles...${NC}"

# Função para atualizar Dockerfile
update_dockerfile() {
    local dockerfile_path=$1
    local service_name=$2
    
    echo -e "${YELLOW}Atualizando Dockerfile de $service_name...${NC}"
    
    if [ -f "$dockerfile_path" ]; then
        # Backup
        cp "$dockerfile_path" "${dockerfile_path}.backup"
        
        # Criar novo Dockerfile
        cat > "$dockerfile_path" << 'EOF'
FROM node:18-alpine

WORKDIR /app

# Copiar arquivos de dependências
COPY package*.json ./

# Instalar dependências (usando npm install ao invés de npm ci)
RUN npm install --production

# Copiar código fonte
COPY . .

# Expor porta
EXPOSE 3001

# Comando para iniciar
CMD ["node", "src/index.js"]
EOF
        
        # Ajustar porta baseado no serviço
        if [[ "$service_name" == "Billing Service" ]]; then
            sed -i '' 's/EXPOSE 3001/EXPOSE 3002/' "$dockerfile_path"
        elif [[ "$service_name" == "Tenant Service" ]]; then
            sed -i '' 's/EXPOSE 3001/EXPOSE 3003/' "$dockerfile_path"
        fi
        
        echo -e "${GREEN}✅ Dockerfile atualizado${NC}"
    fi
}

# Atualizar Dockerfiles
update_dockerfile "core/auth-service/Dockerfile" "Auth Service"
update_dockerfile "core/billing-service/Dockerfile" "Billing Service"
update_dockerfile "core/tenant-service/Dockerfile" "Tenant Service"

# ============================================
# PARTE 3: Garantir que index.js existe
# ============================================

echo -e "${BLUE}📝 Garantindo que index.js existe...${NC}"

# Auth Service
if [ ! -f "core/auth-service/src/index.js" ]; then
    mkdir -p core/auth-service/src
    cat > core/auth-service/src/index.js << 'EOF'
const express = require('express');
const app = express();
app.use(express.json());

const PORT = process.env.PORT || 3001;

// Health check
app.get('/health', (req, res) => {
  res.json({ 
    status: 'healthy', 
    service: 'auth-service',
    timestamp: new Date().toISOString()
  });
});

// Mock login endpoint
app.post('/auth/login', (req, res) => {
  const { email, password } = req.body;
  res.json({
    success: true,
    token: 'mock-jwt-token-' + Date.now(),
    user: { email }
  });
});

app.listen(PORT, () => {
  console.log(`✅ Auth Service running on port ${PORT}`);
});
EOF
fi

# Billing Service
if [ ! -f "core/billing-service/src/index.js" ]; then
    mkdir -p core/billing-service/src
    cat > core/billing-service/src/index.js << 'EOF'
const express = require('express');
const app = express();
app.use(express.json());

const PORT = process.env.PORT || 3002;

// Health check
app.get('/health', (req, res) => {
  res.json({ 
    status: 'healthy', 
    service: 'billing-service',
    timestamp: new Date().toISOString()
  });
});

// Mock checkout endpoint
app.post('/billing/checkout', (req, res) => {
  res.json({
    success: true,
    checkoutUrl: 'https://checkout.stripe.com/mock',
    sessionId: 'cs_mock_' + Date.now()
  });
});

app.listen(PORT, () => {
  console.log(`✅ Billing Service running on port ${PORT}`);
});
EOF
fi

# Tenant Service
if [ ! -f "core/tenant-service/src/index.js" ]; then
    mkdir -p core/tenant-service/src
    cat > core/tenant-service/src/index.js << 'EOF'
const express = require('express');
const app = express();
app.use(express.json());

const PORT = process.env.PORT || 3003;

// Health check
app.get('/health', (req, res) => {
  res.json({ 
    status: 'healthy', 
    service: 'tenant-service',
    timestamp: new Date().toISOString()
  });
});

// Mock tenant info endpoint
app.get('/tenant/:id', (req, res) => {
  res.json({
    id: req.params.id,
    name: 'Demo Organization',
    plan: 'growth',
    modules: ['email-validator', 'crm-connector']
  });
});

app.listen(PORT, () => {
  console.log(`✅ Tenant Service running on port ${PORT}`);
});
EOF
fi

# ============================================
# PARTE 4: Rebuild e restart dos serviços
# ============================================

echo -e "${BLUE}🔄 Reconstruindo serviços...${NC}"

# Rebuild dos serviços que falharam
docker-compose -f docker-compose.fixed.yml build auth-service billing-service tenant-service

# Iniciar os serviços
docker-compose -f docker-compose.fixed.yml up -d auth-service billing-service tenant-service

# ============================================
# PARTE 5: Verificar status
# ============================================

echo -e "${BLUE}🔍 Verificando status dos serviços...${NC}"

sleep 5

# Função para testar endpoint
test_service() {
    local service_name=$1
    local url=$2
    
    echo -n "Testando $service_name... "
    
    response=$(curl -s -o /dev/null -w "%{http_code}" $url 2>/dev/null)
    
    if [ "$response" = "200" ]; then
        echo -e "${GREEN}✅ OK${NC}"
        return 0
    else
        echo -e "${RED}❌ Falhou (HTTP $response)${NC}"
        return 1
    fi
}

echo ""
echo "Status dos serviços:"
test_service "Auth Service" "http://localhost:3001/health"
test_service "Billing Service" "http://localhost:3002/health"
test_service "Tenant Service" "http://localhost:3003/health"
test_service "Email Validator" "http://localhost:4001/health"
test_service "N8N" "http://localhost:5678"
test_service "RabbitMQ" "http://localhost:15672"

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo -e "${GREEN}✅ CORREÇÕES APLICADAS!${NC}"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "Para ver logs de um serviço específico:"
echo "  docker-compose -f docker-compose.fixed.yml logs -f auth-service"
echo ""
echo "Para reiniciar tudo:"
echo "  docker-compose -f docker-compose.fixed.yml down"
echo "  ./start-safe.sh"
echo ""