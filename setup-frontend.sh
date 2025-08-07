#!/bin/bash

# ============================================
# SETUP FRONTEND - Configurar Dashboards
# ============================================

echo "🎨 Configurando Frontend Dashboards..."
echo ""

# Cores
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
RED='\033[0;31m'
NC='\033[0m'

# ============================================
# PARTE 1: ADMIN DASHBOARD
# ============================================

echo -e "${BLUE}📊 Configurando Admin Dashboard...${NC}"

# Criar estrutura do Admin Dashboard
mkdir -p core/admin-dashboard/src

# Criar package.json
cat > core/admin-dashboard/package.json << 'EOF'
{
  "name": "sparknexus-admin-dashboard",
  "version": "1.0.0",
  "description": "Admin Dashboard for Spark Nexus Platform",
  "scripts": {
    "start": "node server.js",
    "dev": "nodemon server.js"
  },
  "dependencies": {
    "express": "^4.18.2",
    "axios": "^1.6.0",
    "cors": "^2.8.5"
  },
  "devDependencies": {
    "nodemon": "^3.0.0"
  }
}
EOF

# Criar servidor Express simples
cat > core/admin-dashboard/server.js << 'EOF'
const express = require('express');
const cors = require('cors');
const path = require('path');

const app = express();
const PORT = process.env.PORT || 4200;

app.use(cors());
app.use(express.json());
app.use(express.static('public'));

// Servir o dashboard HTML
app.get('/', (req, res) => {
  res.sendFile(path.join(__dirname, 'public', 'index.html'));
});

// API proxy endpoints
app.get('/api/health', async (req, res) => {
  res.json({ 
    status: 'healthy', 
    service: 'admin-dashboard',
    apiGateway: process.env.API_GATEWAY_URL || 'http://localhost:8000'
  });
});

app.listen(PORT, () => {
  console.log(`✅ Admin Dashboard running on http://localhost:${PORT}`);
});
EOF

# Criar interface HTML básica
mkdir -p core/admin-dashboard/public
cat > core/admin-dashboard/public/index.html << 'EOF'
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Spark Nexus - Admin Dashboard</title>
    <style>
        * { margin: 0; padding: 0; box-sizing: border-box; }
        body { 
            font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, Oxygen, Ubuntu, sans-serif;
            background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
            min-height: 100vh;
        }
        .container {
            max-width: 1200px;
            margin: 0 auto;
            padding: 2rem;
        }
        .header {
            background: white;
            border-radius: 10px;
            padding: 2rem;
            margin-bottom: 2rem;
            box-shadow: 0 10px 30px rgba(0,0,0,0.1);
        }
        .header h1 {
            color: #333;
            margin-bottom: 0.5rem;
        }
        .header p {
            color: #666;
        }
        .dashboard {
            display: grid;
            grid-template-columns: repeat(auto-fit, minmax(300px, 1fr));
            gap: 1.5rem;
        }
        .card {
            background: white;
            border-radius: 10px;
            padding: 1.5rem;
            box-shadow: 0 5px 15px rgba(0,0,0,0.1);
            transition: transform 0.3s;
        }
        .card:hover {
            transform: translateY(-5px);
        }
        .card h3 {
            color: #333;
            margin-bottom: 1rem;
            display: flex;
            align-items: center;
            gap: 0.5rem;
        }
        .status {
            display: inline-block;
            padding: 0.25rem 0.75rem;
            border-radius: 20px;
            font-size: 0.875rem;
            font-weight: 600;
        }
        .status.online {
            background: #10b981;
            color: white;
        }
        .status.offline {
            background: #ef4444;
            color: white;
        }
        .services-list {
            list-style: none;
            margin-top: 1rem;
        }
        .services-list li {
            padding: 0.75rem;
            background: #f9fafb;
            margin-bottom: 0.5rem;
            border-radius: 5px;
            display: flex;
            justify-content: space-between;
            align-items: center;
        }
        .btn {
            background: #667eea;
            color: white;
            border: none;
            padding: 0.5rem 1rem;
            border-radius: 5px;
            cursor: pointer;
            transition: background 0.3s;
        }
        .btn:hover {
            background: #5a67d8;
        }
        .stats {
            display: grid;
            grid-template-columns: repeat(2, 1fr);
            gap: 1rem;
            margin-top: 1rem;
        }
        .stat {
            text-align: center;
            padding: 1rem;
            background: #f9fafb;
            border-radius: 5px;
        }
        .stat-value {
            font-size: 2rem;
            font-weight: bold;
            color: #667eea;
        }
        .stat-label {
            color: #666;
            font-size: 0.875rem;
        }
    </style>
</head>
<body>
    <div class="container">
        <div class="header">
            <h1>🚀 Spark Nexus Platform</h1>
            <p>Admin Dashboard - Sistema Multi-tenant Modular</p>
        </div>
        
        <div class="dashboard">
            <!-- Services Status -->
            <div class="card">
                <h3>⚡ Status dos Serviços</h3>
                <ul class="services-list" id="services-status">
                    <li>Auth Service <span class="status" id="auth-status">Checking...</span></li>
                    <li>Billing Service <span class="status" id="billing-status">Checking...</span></li>
                    <li>Tenant Service <span class="status" id="tenant-status">Checking...</span></li>
                    <li>Email Validator <span class="status" id="email-status">Checking...</span></li>
                    <li>API Gateway <span class="status" id="gateway-status">Checking...</span></li>
                </ul>
            </div>

            <!-- Platform Stats -->
            <div class="card">
                <h3>📊 Estatísticas</h3>
                <div class="stats">
                    <div class="stat">
                        <div class="stat-value" id="total-orgs">0</div>
                        <div class="stat-label">Organizações</div>
                    </div>
                    <div class="stat">
                        <div class="stat-value" id="total-users">0</div>
                        <div class="stat-label">Usuários</div>
                    </div>
                    <div class="stat">
                        <div class="stat-value" id="active-modules">5</div>
                        <div class="stat-label">Módulos Ativos</div>
                    </div>
                    <div class="stat">
                        <div class="stat-value" id="api-calls">0</div>
                        <div class="stat-label">API Calls (24h)</div>
                    </div>
                </div>
            </div>

            <!-- Quick Actions -->
            <div class="card">
                <h3>🎯 Ações Rápidas</h3>
                <div style="display: flex; flex-direction: column; gap: 1rem;">
                    <button class="btn" onclick="window.open('http://localhost:5678', '_blank')">
                        📝 Abrir N8N Workflows
                    </button>
                    <button class="btn" onclick="window.open('http://localhost:15672', '_blank')">
                        📬 RabbitMQ Management
                    </button>
                    <button class="btn" onclick="testServices()">
                        🔄 Recarregar Status
                    </button>
                </div>
            </div>

            <!-- Available Modules -->
            <div class="card">
                <h3>📦 Módulos Disponíveis</h3>
                <ul class="services-list">
                    <li>📧 Email Validator Pro <span class="status online">Active</span></li>
                    <li>🔗 CRM Connector <span class="status offline">Inactive</span></li>
                    <li>📈 Lead Scorer AI <span class="status offline">Inactive</span></li>
                    <li>💾 Data Enrichment <span class="status offline">Inactive</span></li>
                    <li>📤 Campaign Manager <span class="status offline">Inactive</span></li>
                </ul>
            </div>
        </div>
    </div>

    <script>
        // Check service status
        async function checkServiceStatus(url, elementId) {
            try {
                const response = await fetch(url);
                const element = document.getElementById(elementId);
                if (response.ok) {
                    element.textContent = 'Online';
                    element.className = 'status online';
                } else {
                    element.textContent = 'Offline';
                    element.className = 'status offline';
                }
            } catch (error) {
                const element = document.getElementById(elementId);
                element.textContent = 'Offline';
                element.className = 'status offline';
            }
        }

        // Test all services
        async function testServices() {
            checkServiceStatus('http://localhost:3001/health', 'auth-status');
            checkServiceStatus('http://localhost:3002/health', 'billing-status');
            checkServiceStatus('http://localhost:3003/health', 'tenant-status');
            checkServiceStatus('http://localhost:4001/health', 'email-status');
            checkServiceStatus('http://localhost:8000', 'gateway-status');
            
            // Update stats (mock data for now)
            document.getElementById('total-orgs').textContent = Math.floor(Math.random() * 100) + 10;
            document.getElementById('total-users').textContent = Math.floor(Math.random() * 500) + 100;
            document.getElementById('api-calls').textContent = Math.floor(Math.random() * 10000) + 1000;
        }

        // Test services on load
        window.onload = () => {
            testServices();
            // Refresh every 30 seconds
            setInterval(testServices, 30000);
        };
    </script>
</body>
</html>
EOF

# Criar Dockerfile para Admin Dashboard
cat > core/admin-dashboard/Dockerfile << 'EOF'
FROM node:18-alpine

WORKDIR /app

COPY package*.json ./
RUN npm install

COPY . .

EXPOSE 4200

CMD ["npm", "start"]
EOF

echo -e "${GREEN}✅ Admin Dashboard configurado${NC}"

# ============================================
# PARTE 2: CLIENT DASHBOARD
# ============================================

echo -e "${BLUE}📱 Configurando Client Dashboard...${NC}"

# Criar estrutura do Client Dashboard
mkdir -p core/client-dashboard/src

# Criar package.json
cat > core/client-dashboard/package.json << 'EOF'
{
  "name": "sparknexus-client-dashboard",
  "version": "1.0.0",
  "description": "Client Dashboard for Spark Nexus Platform",
  "scripts": {
    "start": "node server.js",
    "dev": "nodemon server.js"
  },
  "dependencies": {
    "express": "^4.18.2",
    "axios": "^1.6.0",
    "cors": "^2.8.5"
  },
  "devDependencies": {
    "nodemon": "^3.0.0"
  }
}
EOF

# Criar servidor Express
cat > core/client-dashboard/server.js << 'EOF'
const express = require('express');
const cors = require('cors');
const path = require('path');

const app = express();
const PORT = process.env.PORT || 4201;

app.use(cors());
app.use(express.json());
app.use(express.static('public'));

// Servir o dashboard HTML
app.get('/', (req, res) => {
  res.sendFile(path.join(__dirname, 'public', 'index.html'));
});

// Health check
app.get('/api/health', (req, res) => {
  res.json({ 
    status: 'healthy', 
    service: 'client-dashboard',
    apiGateway: process.env.API_GATEWAY_URL || 'http://localhost:8000'
  });
});

app.listen(PORT, () => {
  console.log(`✅ Client Dashboard running on http://localhost:${PORT}`);
});
EOF

# Criar interface HTML do Client Dashboard
mkdir -p core/client-dashboard/public
cat > core/client-dashboard/public/index.html << 'EOF'
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Spark Nexus - Client Portal</title>
    <style>
        * { margin: 0; padding: 0; box-sizing: border-box; }
        body { 
            font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, Oxygen, Ubuntu, sans-serif;
            background: linear-gradient(135deg, #0093E9 0%, #80D0C7 100%);
            min-height: 100vh;
        }
        .container {
            max-width: 1200px;
            margin: 0 auto;
            padding: 2rem;
        }
        .header {
            background: white;
            border-radius: 10px;
            padding: 2rem;
            margin-bottom: 2rem;
            box-shadow: 0 10px 30px rgba(0,0,0,0.1);
        }
        .header h1 {
            color: #333;
            margin-bottom: 0.5rem;
        }
        .header p {
            color: #666;
        }
        .dashboard {
            display: grid;
            grid-template-columns: repeat(auto-fit, minmax(300px, 1fr));
            gap: 1.5rem;
        }
        .card {
            background: white;
            border-radius: 10px;
            padding: 1.5rem;
            box-shadow: 0 5px 15px rgba(0,0,0,0.1);
            transition: transform 0.3s;
        }
        .card:hover {
            transform: translateY(-5px);
        }
        .card h3 {
            color: #333;
            margin-bottom: 1rem;
        }
        .module-card {
            background: linear-gradient(135deg, #f5f7fa 0%, #c3cfe2 100%);
            padding: 2rem;
            text-align: center;
            cursor: pointer;
        }
        .module-card:hover {
            background: linear-gradient(135deg, #c3cfe2 0%, #f5f7fa 100%);
        }
        .module-icon {
            font-size: 3rem;
            margin-bottom: 1rem;
        }
        .module-title {
            font-size: 1.25rem;
            font-weight: 600;
            color: #333;
            margin-bottom: 0.5rem;
        }
        .module-desc {
            color: #666;
            font-size: 0.875rem;
        }
        .usage-bar {
            width: 100%;
            height: 10px;
            background: #e5e7eb;
            border-radius: 5px;
            overflow: hidden;
            margin: 1rem 0;
        }
        .usage-fill {
            height: 100%;
            background: linear-gradient(90deg, #0093E9 0%, #80D0C7 100%);
            transition: width 0.3s;
        }
        .btn {
            background: #0093E9;
            color: white;
            border: none;
            padding: 0.75rem 1.5rem;
            border-radius: 5px;
            cursor: pointer;
            font-size: 1rem;
            transition: background 0.3s;
        }
        .btn:hover {
            background: #0077c7;
        }
        .stats-grid {
            display: grid;
            grid-template-columns: repeat(3, 1fr);
            gap: 1rem;
            margin-top: 1rem;
        }
        .stat-item {
            text-align: center;
        }
        .stat-value {
            font-size: 1.5rem;
            font-weight: bold;
            color: #0093E9;
        }
        .stat-label {
            color: #666;
            font-size: 0.875rem;
        }
    </style>
</head>
<body>
    <div class="container">
        <div class="header">
            <h1>🚀 Spark Nexus - Portal do Cliente</h1>
            <p>Bem-vindo ao seu painel de controle</p>
        </div>
        
        <div class="dashboard">
            <!-- Email Validator Module -->
            <div class="card module-card" onclick="openModule('email-validator')">
                <div class="module-icon">📧</div>
                <div class="module-title">Email Validator Pro</div>
                <div class="module-desc">Validação e enriquecimento de emails com IA</div>
                <div class="usage-bar">
                    <div class="usage-fill" style="width: 35%"></div>
                </div>
                <small>350 / 1000 validações este mês</small>
            </div>

            <!-- CRM Connector Module -->
            <div class="card module-card" onclick="openModule('crm-connector')">
                <div class="module-icon">🔗</div>
                <div class="module-title">CRM Connector</div>
                <div class="module-desc">Integração com principais CRMs</div>
                <div class="usage-bar">
                    <div class="usage-fill" style="width: 100%"></div>
                </div>
                <small>Ativo - Uso ilimitado</small>
            </div>

            <!-- Lead Scorer Module -->
            <div class="card module-card" onclick="openModule('lead-scorer')">
                <div class="module-icon">📈</div>
                <div class="module-title">Lead Scorer AI</div>
                <div class="module-desc">Score automático com Machine Learning</div>
                <div class="usage-bar">
                    <div class="usage-fill" style="width: 60%"></div>
                </div>
                <small>3000 / 5000 scores este mês</small>
            </div>

            <!-- Account Overview -->
            <div class="card">
                <h3>📊 Visão Geral da Conta</h3>
                <div class="stats-grid">
                    <div class="stat-item">
                        <div class="stat-value">Growth</div>
                        <div class="stat-label">Plano Atual</div>
                    </div>
                    <div class="stat-item">
                        <div class="stat-value">3</div>
                        <div class="stat-label">Módulos Ativos</div>
                    </div>
                    <div class="stat-item">
                        <div class="stat-value">8,432</div>
                        <div class="stat-label">API Calls</div>
                    </div>
                </div>
                <br>
                <button class="btn" style="width: 100%">Upgrade para Scale</button>
            </div>

            <!-- Recent Activity -->
            <div class="card">
                <h3>🕐 Atividade Recente</h3>
                <ul style="list-style: none; padding: 0;">
                    <li style="padding: 0.75rem 0; border-bottom: 1px solid #e5e7eb;">
                        <strong>Email Validation</strong><br>
                        <small>250 emails validados - há 2 horas</small>
                    </li>
                    <li style="padding: 0.75rem 0; border-bottom: 1px solid #e5e7eb;">
                        <strong>Lead Scoring</strong><br>
                        <small>500 leads analisados - há 5 horas</small>
                    </li>
                    <li style="padding: 0.75rem 0;">
                        <strong>CRM Sync</strong><br>
                        <small>Sincronização completa - há 1 dia</small>
                    </li>
                </ul>
            </div>

            <!-- Quick Actions -->
            <div class="card">
                <h3>⚡ Ações Rápidas</h3>
                <div style="display: flex; flex-direction: column; gap: 1rem;">
                    <button class="btn" onclick="testEmailValidator()">
                        Testar Email Validator
                    </button>
                    <button class="btn" onclick="viewApiDocs()">
                        Ver Documentação API
                    </button>
                    <button class="btn" onclick="downloadReport()">
                        Baixar Relatório
                    </button>
                </div>
            </div>
        </div>
    </div>

    <script>
        function openModule(moduleId) {
            alert(`Abrindo módulo: ${moduleId}`);
            // Aqui você redirecionaria para a página específica do módulo
        }

        async function testEmailValidator() {
            try {
                const response = await fetch('http://localhost:4001/validate', {
                    method: 'POST',
                    headers: { 'Content-Type': 'application/json' },
                    body: JSON.stringify({
                        emails: ['test@example.com'],
                        organizationId: 'demo'
                    })
                });
                const data = await response.json();
                alert('Email Validator funcionando!\n' + JSON.stringify(data, null, 2));
            } catch (error) {
                alert('Erro ao testar: ' + error.message);
            }
        }

        function viewApiDocs() {
            window.open('http://localhost:8001', '_blank');
        }

        function downloadReport() {
            alert('Gerando relatório...');
        }

        // Update stats periodically
        setInterval(() => {
            // Update usage bars with random values for demo
            document.querySelectorAll('.usage-fill').forEach(bar => {
                const current = parseFloat(bar.style.width);
                const change = (Math.random() - 0.5) * 5;
                const newWidth = Math.max(0, Math.min(100, current + change));
                bar.style.width = newWidth + '%';
            });
        }, 5000);
    </script>
</body>
</html>
EOF

# Criar Dockerfile para Client Dashboard
cat > core/client-dashboard/Dockerfile << 'EOF'
FROM node:18-alpine

WORKDIR /app

COPY package*.json ./
RUN npm install

COPY . .

EXPOSE 4201

CMD ["npm", "start"]
EOF

echo -e "${GREEN}✅ Client Dashboard configurado${NC}"

# ============================================
# PARTE 3: INSTALAR DEPENDÊNCIAS
# ============================================

echo -e "${BLUE}📦 Instalando dependências...${NC}"

# Admin Dashboard
cd core/admin-dashboard
npm install
cd ../..

# Client Dashboard
cd core/client-dashboard
npm install
cd ../..

# ============================================
# PARTE 4: ADICIONAR AO DOCKER COMPOSE
# ============================================

echo -e "${BLUE}🐳 Adicionando dashboards ao Docker Compose...${NC}"

# Verificar se já existe no docker-compose.fixed.yml
if ! grep -q "admin-dashboard:" docker-compose.fixed.yml; then
    echo -e "${YELLOW}Adicionando configuração dos dashboards...${NC}"
    
    # Adicionar antes do volumes section
    sed -i '/^volumes:/i\
  # ===========================================\
  # FRONTEND DASHBOARDS\
  # ===========================================\
\
  admin-dashboard:\
    build:\
      context: ./core/admin-dashboard\
      dockerfile: Dockerfile\
    image: sparknexus/admin-dashboard:latest\
    container_name: sparknexus-admin\
    restart: unless-stopped\
    environment:\
      - PORT=4200\
      - API_GATEWAY_URL=http://kong:8000\
    ports:\
      - "4200:4200"\
    networks:\
      - sparknexus-network\
    depends_on:\
      - auth-service\
      - billing-service\
\
  client-dashboard:\
    build:\
      context: ./core/client-dashboard\
      dockerfile: Dockerfile\
    image: sparknexus/client-dashboard:latest\
    container_name: sparknexus-client\
    restart: unless-stopped\
    environment:\
      - PORT=4201\
      - API_GATEWAY_URL=http://kong:8000\
    ports:\
      - "4201:4201"\
    networks:\
      - sparknexus-network\
    depends_on:\
      - auth-service\
      - email-validator\
' docker-compose.fixed.yml
fi

echo -e "${GREEN}✅ Dashboards adicionados ao Docker Compose${NC}"

# ============================================
# PARTE 5: BUILD E START
# ============================================

echo -e "${BLUE}🚀 Construindo e iniciando dashboards...${NC}"

# Build das imagens
docker-compose -f docker-compose.fixed.yml build admin-dashboard client-dashboard

# Iniciar os dashboards
docker-compose -f docker-compose.fixed.yml up -d admin-dashboard client-dashboard

# ============================================
# VERIFICAR STATUS
# ============================================

echo -e "${BLUE}🔍 Verificando status...${NC}"

sleep 5

# Testar se estão rodando
echo ""
echo "Status dos Dashboards:"

response=$(curl -s -o /dev/null -w "%{http_code}" http://localhost:4200 2>/dev/null)
if [ "$response" = "200" ] || [ "$response" = "304" ]; then
    echo -e "Admin Dashboard: ${GREEN}✅ Online${NC} - http://localhost:4200"
else
    echo -e "Admin Dashboard: ${RED}❌ Offline${NC}"
fi

response=$(curl -s -o /dev/null -w "%{http_code}" http://localhost:4201 2>/dev/null)
if [ "$response" = "200" ] || [ "$response" = "304" ]; then
    echo -e "Client Dashboard: ${GREEN}✅ Online${NC} - http://localhost:4201"
else
    echo -e "Client Dashboard: ${RED}❌ Offline${NC}"
fi

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo -e "${GREEN}✅ FRONTEND CONFIGURADO!${NC}"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "🌐 Acesse os dashboards:"
echo "  - Admin Dashboard: http://localhost:4200"
echo "  - Client Dashboard: http://localhost:4201"
echo ""
echo "Para ver logs:"
echo "  docker-compose -f docker-compose.fixed.yml logs -f admin-dashboard"
echo "  docker-compose -f docker-compose.fixed.yml logs -f client-dashboard"
echo ""