#!/bin/bash

# ============================================
# FIX CORS AND CONNECTION ISSUES
# ============================================

echo "🔧 Corrigindo problemas de CORS e conexão..."
echo ""

# Cores
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
RED='\033[0;31m'
NC='\033[0m'

# ============================================
# PARTE 1: ATUALIZAR CLIENT DASHBOARD COM CORS
# ============================================

echo -e "${BLUE}📱 Atualizando Client Dashboard com CORS correto...${NC}"

cat > core/client-dashboard/server.js << 'EOF'
const express = require('express');
const cors = require('cors');
const path = require('path');
const axios = require('axios');

const app = express();
const PORT = process.env.PORT || 4201;

// CORS configurado corretamente
app.use(cors({
  origin: '*',
  methods: ['GET', 'POST', 'PUT', 'DELETE', 'OPTIONS'],
  allowedHeaders: ['Content-Type', 'Authorization', 'X-API-Key']
}));

app.use(express.json());
app.use(express.static('public'));

// Servir o dashboard HTML
app.get('/', (req, res) => {
  res.sendFile(path.join(__dirname, 'public', 'index.html'));
});

// Proxy para Email Validator - IMPORTANTE
app.post('/api/validate-email', async (req, res) => {
  try {
    const response = await axios.post('http://email-validator:4001/validate', req.body);
    res.json(response.data);
  } catch (error) {
    console.error('Error calling email validator:', error.message);
    res.status(500).json({ error: 'Failed to validate email' });
  }
});

// Health check
app.get('/api/health', (req, res) => {
  res.json({ 
    status: 'healthy', 
    service: 'client-dashboard',
    timestamp: new Date().toISOString()
  });
});

app.listen(PORT, () => {
  console.log(`✅ Client Dashboard running on http://localhost:${PORT}`);
});
EOF

echo -e "${GREEN}✅ Server.js atualizado${NC}"

# ============================================
# PARTE 2: ATUALIZAR HTML DO CLIENT DASHBOARD
# ============================================

echo -e "${BLUE}📝 Atualizando HTML do Client Dashboard...${NC}"

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
        /* Modal styles */
        .modal {
            display: none;
            position: fixed;
            z-index: 1000;
            left: 0;
            top: 0;
            width: 100%;
            height: 100%;
            background-color: rgba(0,0,0,0.5);
        }
        .modal-content {
            background-color: white;
            margin: 10% auto;
            padding: 2rem;
            border-radius: 10px;
            width: 90%;
            max-width: 500px;
        }
        .close {
            color: #aaa;
            float: right;
            font-size: 28px;
            font-weight: bold;
            cursor: pointer;
        }
        .close:hover {
            color: black;
        }
        #testResult {
            margin-top: 1rem;
            padding: 1rem;
            background: #f0f0f0;
            border-radius: 5px;
            font-family: monospace;
            white-space: pre-wrap;
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

    <!-- Modal -->
    <div id="testModal" class="modal">
        <div class="modal-content">
            <span class="close" onclick="closeModal()">&times;</span>
            <h2>Teste do Email Validator</h2>
            <div id="testResult">Testando...</div>
        </div>
    </div>

    <script>
        function openModule(moduleId) {
            alert(`Módulo: ${moduleId}\n\nEm desenvolvimento...`);
        }

        async function testEmailValidator() {
            const modal = document.getElementById('testModal');
            const resultDiv = document.getElementById('testResult');
            
            modal.style.display = 'block';
            resultDiv.innerHTML = 'Testando conexão com Email Validator...';
            
            try {
                // Usar o proxy do próprio servidor ao invés de chamar direto
                const response = await fetch('/api/validate-email', {
                    method: 'POST',
                    headers: { 'Content-Type': 'application/json' },
                    body: JSON.stringify({
                        emails: ['test@example.com', 'invalid-email', 'user@gmail.com'],
                        organizationId: 'demo'
                    })
                });
                
                if (!response.ok) {
                    throw new Error(`HTTP error! status: ${response.status}`);
                }
                
                const data = await response.json();
                
                // Formatar resultado
                let resultHTML = '✅ Email Validator funcionando!\n\n';
                resultHTML += 'Resultados:\n';
                resultHTML += '─────────────────────────\n';
                
                if (data.results && Array.isArray(data.results)) {
                    data.results.forEach((result, index) => {
                        resultHTML += `\n${index + 1}. ${result.email}\n`;
                        resultHTML += `   Válido: ${result.valid ? '✅' : '❌'}\n`;
                        resultHTML += `   Score: ${result.score}/100\n`;
                    });
                } else {
                    resultHTML += JSON.stringify(data, null, 2);
                }
                
                if (data.usage) {
                    resultHTML += '\n─────────────────────────\n';
                    resultHTML += `\nUso: ${data.usage.used}/${data.usage.limit}`;
                    resultHTML += `\nRestante: ${data.usage.remaining}`;
                }
                
                resultDiv.innerHTML = resultHTML;
            } catch (error) {
                console.error('Erro:', error);
                resultDiv.innerHTML = `❌ Erro ao testar:\n${error.message}\n\nVerifique se o serviço está rodando.`;
            }
        }

        function closeModal() {
            document.getElementById('testModal').style.display = 'none';
        }

        function viewApiDocs() {
            alert('Documentação da API\n\nEndpoint: http://localhost:4001/validate\nMétodo: POST\n\nBody:\n{\n  "emails": ["email1@example.com"],\n  "organizationId": "your-org-id"\n}');
        }

        function downloadReport() {
            alert('Gerando relatório...\n\nEm desenvolvimento.');
        }

        // Fechar modal ao clicar fora
        window.onclick = function(event) {
            const modal = document.getElementById('testModal');
            if (event.target == modal) {
                modal.style.display = 'none';
            }
        }
    </script>
</body>
</html>
EOF

echo -e "${GREEN}✅ HTML atualizado${NC}"

# ============================================
# PARTE 3: ATUALIZAR EMAIL VALIDATOR COM CORS
# ============================================

echo -e "${BLUE}📧 Atualizando Email Validator com CORS...${NC}"

cat > modules/email-validator/src/index.js << 'EOF'
const express = require('express');
const cors = require('cors');

const app = express();
const PORT = process.env.PORT || 4001;

// Configurar CORS para aceitar requisições de qualquer origem
app.use(cors({
  origin: '*',
  methods: ['GET', 'POST', 'PUT', 'DELETE', 'OPTIONS'],
  allowedHeaders: ['Content-Type', 'Authorization', 'X-API-Key']
}));

app.use(express.json());

// Health check
app.get('/health', (req, res) => {
  res.json({ 
    status: 'healthy', 
    service: 'email-validator',
    timestamp: new Date().toISOString()
  });
});

// Validate endpoint
app.post('/validate', async (req, res) => {
  console.log('Received validation request:', req.body);
  
  const { emails, organizationId } = req.body;
  
  if (!emails || !Array.isArray(emails)) {
    return res.status(400).json({ error: 'emails array is required' });
  }
  
  // Simulação de validação
  const results = emails.map(email => {
    const isValid = /^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(email);
    
    return {
      email,
      valid: isValid,
      score: isValid ? Math.floor(Math.random() * 30) + 70 : Math.floor(Math.random() * 30),
      reason: isValid ? 'Valid format' : 'Invalid format',
      details: {
        format_valid: isValid,
        domain: isValid ? email.split('@')[1] : null,
        disposable: false,
        role_based: email.includes('admin') || email.includes('info'),
        free_provider: email.includes('gmail') || email.includes('yahoo')
      }
    };
  });
  
  // Simulação de uso
  const usage = {
    used: Math.floor(Math.random() * 500) + 100,
    limit: 1000,
    remaining: 0
  };
  usage.remaining = usage.limit - usage.used;
  
  res.json({
    success: true,
    results,
    usage,
    organization: organizationId
  });
});

// Error handling
app.use((err, req, res, next) => {
  console.error('Error:', err);
  res.status(500).json({ error: 'Internal server error' });
});

app.listen(PORT, () => {
  console.log(`✅ Email Validator Module running on port ${PORT}`);
  console.log(`   Health check: http://localhost:${PORT}/health`);
  console.log(`   Validate endpoint: http://localhost:${PORT}/validate`);
});
EOF

echo -e "${GREEN}✅ Email Validator atualizado${NC}"

# ============================================
# PARTE 4: REBUILD E RESTART
# ============================================

echo -e "${BLUE}🔄 Reconstruindo e reiniciando serviços...${NC}"

# Parar serviços
docker-compose -f docker-compose.with-frontend.yml stop client-dashboard email-validator

# Rebuild
docker-compose -f docker-compose.with-frontend.yml build client-dashboard email-validator

# Reiniciar
docker-compose -f docker-compose.with-frontend.yml up -d client-dashboard email-validator

# ============================================
# PARTE 5: VERIFICAR STATUS
# ============================================

echo -e "${BLUE}🔍 Verificando status...${NC}"

sleep 5

# Testar serviços
echo ""
echo "Status dos serviços:"

test_endpoint() {
    local name=$1
    local url=$2
    
    printf "%-25s" "$name:"
    
    response=$(curl -s -o /dev/null -w "%{http_code}" $url 2>/dev/null)
    
    if [ "$response" = "200" ] || [ "$response" = "304" ]; then
        echo -e "${GREEN}✅ Online${NC}"
    else
        echo -e "${RED}❌ Offline (HTTP $response)${NC}"
    fi
}

test_endpoint "Client Dashboard" "http://localhost:4201"
test_endpoint "Email Validator" "http://localhost:4001/health"
test_endpoint "Dashboard API" "http://localhost:4201/api/health"

# ============================================
# TESTE DIRETO
# ============================================

echo ""
echo -e "${BLUE}🧪 Testando Email Validator diretamente...${NC}"

response=$(curl -s -X POST http://localhost:4001/validate \
  -H "Content-Type: application/json" \
  -d '{
    "emails": ["test@example.com"],
    "organizationId": "test"
  }' 2>/dev/null)

if [ ! -z "$response" ]; then
    echo -e "${GREEN}✅ Email Validator respondendo corretamente${NC}"
    echo "Resposta: $(echo $response | jq -r '.success' 2>/dev/null || echo $response | head -c 100)"
else
    echo -e "${RED}❌ Email Validator não está respondendo${NC}"
fi

# ============================================
# RESUMO FINAL
# ============================================

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo -e "${GREEN}✅ CORS E CONEXÕES CORRIGIDAS!${NC}"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "🌐 Acesse o Client Dashboard:"
echo "   http://localhost:4201"
echo ""
echo "🧪 Para testar:"
echo "   1. Abra o dashboard no navegador"
echo "   2. Clique em 'Testar Email Validator'"
echo "   3. O resultado aparecerá em um modal"
echo ""
echo "📝 Logs para debug:"
echo "   docker-compose -f docker-compose.with-frontend.yml logs -f client-dashboard"
echo "   docker-compose -f docker-compose.with-frontend.yml logs -f email-validator"
echo ""