#!/bin/bash

# ============================================
# FIX SERVER ROUTES - Corrigir rotas do server.js
# ============================================

echo "🔧 Corrigindo rotas do server.js..."
echo ""

# Cores
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
RED='\033[0;31m'
NC='\033[0m'

# ============================================
# PARTE 1: BACKUP
# ============================================

echo -e "${BLUE}1️⃣ Fazendo backup do server.js atual...${NC}"

cp core/client-dashboard/server.js core/client-dashboard/server.js.backup-$(date +%Y%m%d-%H%M%S)
echo -e "${GREEN}✅ Backup criado${NC}"

# ============================================
# PARTE 2: CRIAR SERVER.JS CORRETO
# ============================================

echo -e "${BLUE}2️⃣ Criando server.js com rotas na ordem correta...${NC}"

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

// ============================================
// ROTAS - IMPORTANTE: ANTES DO app.listen()
// ============================================

// Rota principal
app.get('/', (req, res) => {
  console.log('Main page requested');
  res.sendFile(path.join(__dirname, 'public', 'index.html'));
});

// ROTA DE UPLOAD - CORRIGIDA
app.get('/upload', (req, res) => {
  console.log('Upload page requested');
  const uploadPath = path.join(__dirname, 'public', 'upload.html');
  console.log('Serving file:', uploadPath);
  res.sendFile(uploadPath);
});

// Proxy para Email Validator
app.post('/api/validate-email', async (req, res) => {
  try {
    console.log('Validating emails via proxy...');
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
    timestamp: new Date().toISOString(),
    routes: [
      'GET /',
      'GET /upload',
      'POST /api/validate-email',
      'GET /api/health'
    ]
  });
});

// Listar todas as rotas (para debug)
app.get('/api/routes', (req, res) => {
  const routes = [];
  app._router.stack.forEach(middleware => {
    if (middleware.route) {
      routes.push({
        path: middleware.route.path,
        methods: Object.keys(middleware.route.methods)
      });
    }
  });
  res.json(routes);
});

// 404 handler - DEVE SER A ÚLTIMA ROTA
app.use((req, res) => {
  console.log('404 - Route not found:', req.url);
  res.status(404).send(`
    <h1>404 - Page not found</h1>
    <p>The requested URL ${req.url} was not found.</p>
    <p>Available routes:</p>
    <ul>
      <li><a href="/">Home</a></li>
      <li><a href="/upload">Upload Page</a></li>
      <li><a href="/api/health">API Health</a></li>
    </ul>
  `);
});

// ============================================
// INICIAR SERVIDOR - SEMPRE NO FINAL
// ============================================

app.listen(PORT, '0.0.0.0', () => {
  console.log(`✅ Client Dashboard running on http://localhost:${PORT}`);
  console.log(`   📊 Main page: http://localhost:${PORT}/`);
  console.log(`   📤 Upload page: http://localhost:${PORT}/upload`);
  console.log(`   🔍 Health check: http://localhost:${PORT}/api/health`);
  console.log(`   📋 Routes list: http://localhost:${PORT}/api/routes`);
});
EOF

echo -e "${GREEN}✅ server.js criado corretamente${NC}"

# ============================================
# PARTE 3: VERIFICAR ARQUIVO UPLOAD.HTML
# ============================================

echo -e "${BLUE}3️⃣ Verificando upload.html...${NC}"

if [ -f "core/client-dashboard/public/upload.html" ]; then
    echo -e "${GREEN}✅ upload.html existe${NC}"
    echo "   Tamanho: $(wc -c < core/client-dashboard/public/upload.html) bytes"
else
    echo -e "${RED}❌ upload.html não encontrado! Criando...${NC}"
    
    cat > core/client-dashboard/public/upload.html << 'EOFHTML'
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Upload de Emails - Spark Nexus</title>
    <style>
        * { margin: 0; padding: 0; box-sizing: border-box; }
        body { 
            font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif;
            background: linear-gradient(135deg, #0093E9 0%, #80D0C7 100%);
            min-height: 100vh;
            padding: 2rem;
        }
        .container {
            max-width: 800px;
            margin: 0 auto;
        }
        .upload-card {
            background: white;
            border-radius: 20px;
            padding: 3rem;
            box-shadow: 0 20px 60px rgba(0,0,0,0.1);
        }
        h1 {
            color: #333;
            margin-bottom: 1rem;
            text-align: center;
        }
        .upload-area {
            border: 3px dashed #0093E9;
            border-radius: 10px;
            padding: 3rem;
            text-align: center;
            transition: all 0.3s;
            cursor: pointer;
            margin: 2rem 0;
        }
        .upload-area:hover {
            background: #f0f8ff;
            border-color: #0077c7;
        }
        .upload-icon {
            font-size: 4rem;
            margin-bottom: 1rem;
        }
        .file-input {
            display: none;
        }
        .form-group {
            margin: 1.5rem 0;
        }
        label {
            display: block;
            color: #555;
            margin-bottom: 0.5rem;
            font-weight: 600;
        }
        input[type="email"], input[type="text"] {
            width: 100%;
            padding: 1rem;
            border: 2px solid #e0e0e0;
            border-radius: 8px;
            font-size: 1rem;
        }
        .btn {
            background: linear-gradient(135deg, #0093E9 0%, #0077c7 100%);
            color: white;
            border: none;
            padding: 1rem 2rem;
            border-radius: 8px;
            font-size: 1.1rem;
            cursor: pointer;
            width: 100%;
        }
        .btn:hover {
            transform: translateY(-2px);
        }
        .btn:disabled {
            opacity: 0.5;
            cursor: not-allowed;
        }
        .result-box {
            background: #e8f5e9;
            border: 2px solid #4caf50;
            border-radius: 8px;
            padding: 1.5rem;
            margin: 1rem 0;
            display: none;
        }
        .error-box {
            background: #ffebee;
            border: 2px solid #f44336;
            border-radius: 8px;
            padding: 1.5rem;
            margin: 1rem 0;
            display: none;
        }
    </style>
</head>
<body>
    <div class="container">
        <div class="upload-card">
            <h1>📧 Validação de Emails em Lote</h1>
            <p style="text-align: center; color: #666; margin-bottom: 2rem;">
                Faça upload de um arquivo CSV ou Excel com emails para validação
            </p>

            <form id="uploadForm">
                <div class="upload-area" id="uploadArea">
                    <div class="upload-icon">📁</div>
                    <p style="font-size: 1.2rem; color: #333;">
                        Clique para selecionar um arquivo
                    </p>
                    <p style="color: #666;">CSV, Excel ou TXT</p>
                    <input type="file" id="fileInput" class="file-input" accept=".csv,.xlsx,.xls,.txt">
                </div>

                <div class="form-group">
                    <label for="email">Seu email para receber o relatório:</label>
                    <input type="email" id="email" name="email" required 
                           placeholder="seu-email@empresa.com" value="teste@example.com">
                </div>

                <button type="submit" class="btn" id="submitBtn">
                    🚀 Iniciar Validação
                </button>
            </form>

            <div class="result-box" id="resultBox">
                <h3>✅ Upload Concluído!</h3>
                <p id="resultMessage"></p>
            </div>

            <div class="error-box" id="errorBox">
                <h3>❌ Erro</h3>
                <p id="errorMessage"></p>
            </div>
        </div>
    </div>

    <script>
        const uploadArea = document.getElementById('uploadArea');
        const fileInput = document.getElementById('fileInput');
        const uploadForm = document.getElementById('uploadForm');
        const resultBox = document.getElementById('resultBox');
        const resultMessage = document.getElementById('resultMessage');
        const errorBox = document.getElementById('errorBox');
        const errorMessage = document.getElementById('errorMessage');
        const submitBtn = document.getElementById('submitBtn');

        uploadArea.addEventListener('click', () => {
            fileInput.click();
        });

        fileInput.addEventListener('change', (e) => {
            if (e.target.files.length > 0) {
                const file = e.target.files[0];
                uploadArea.innerHTML = `
                    <div class="upload-icon">📄</div>
                    <p style="font-size: 1.2rem; color: #333;">
                        ${file.name}
                    </p>
                    <p style="color: #666;">Tamanho: ${(file.size / 1024).toFixed(2)} KB</p>
                `;
            }
        });

        uploadForm.addEventListener('submit', async (e) => {
            e.preventDefault();
            
            resultBox.style.display = 'none';
            errorBox.style.display = 'none';
            
            if (!fileInput.files || fileInput.files.length === 0) {
                errorMessage.textContent = 'Por favor, selecione um arquivo.';
                errorBox.style.display = 'block';
                return;
            }

            submitBtn.disabled = true;
            submitBtn.textContent = '⏳ Enviando...';

            const formData = new FormData();
            formData.append('file', fileInput.files[0]);
            formData.append('email', document.getElementById('email').value);
            formData.append('organizationId', 'demo');

            try {
                const response = await fetch('http://localhost:4001/upload-and-validate', {
                    method: 'POST',
                    body: formData
                });

                const data = await response.json();

                if (response.ok) {
                    resultMessage.innerHTML = `
                        <strong>Job ID:</strong> ${data.jobId || 'N/A'}<br>
                        <strong>Emails encontrados:</strong> ${data.emailCount || 'N/A'}<br>
                        <strong>Tempo estimado:</strong> ${data.estimatedTime || 'Alguns minutos'}<br>
                        <strong>Relatório será enviado para:</strong> ${data.resultWillBeSentTo || document.getElementById('email').value}
                    `;
                    resultBox.style.display = 'block';
                    uploadForm.reset();
                    uploadArea.innerHTML = `
                        <div class="upload-icon">📁</div>
                        <p style="font-size: 1.2rem; color: #333;">
                            Clique para selecionar um arquivo
                        </p>
                        <p style="color: #666;">CSV, Excel ou TXT</p>
                    `;
                } else {
                    errorMessage.textContent = data.error || 'Erro no upload';
                    errorBox.style.display = 'block';
                }
            } catch (error) {
                errorMessage.textContent = 'Erro de conexão: ' + error.message;
                errorBox.style.display = 'block';
            } finally {
                submitBtn.disabled = false;
                submitBtn.textContent = '🚀 Iniciar Validação';
            }
        });
    </script>
</body>
</html>
EOFHTML
    
    echo -e "${GREEN}✅ upload.html criado${NC}"
fi

# ============================================
# PARTE 4: REBUILD E RESTART
# ============================================

echo -e "${BLUE}4️⃣ Reconstruindo e reiniciando Client Dashboard...${NC}"

# Rebuild
docker-compose build client-dashboard

# Restart
docker-compose restart client-dashboard

echo -e "${GREEN}✅ Client Dashboard reiniciado${NC}"

# ============================================
# PARTE 5: AGUARDAR E TESTAR
# ============================================

echo -e "${BLUE}5️⃣ Aguardando serviço iniciar...${NC}"

sleep 5

# Testar rotas
echo -e "${BLUE}6️⃣ Testando rotas...${NC}"

# Teste 1: Health check
echo -n "Health check: "
response=$(curl -s -o /dev/null -w "%{http_code}" http://localhost:4201/api/health 2>/dev/null)
if [ "$response" = "200" ]; then
    echo -e "${GREEN}✅ OK${NC}"
else
    echo -e "${RED}❌ Falhou (HTTP $response)${NC}"
fi

# Teste 2: Página principal
echo -n "Página principal: "
response=$(curl -s -o /dev/null -w "%{http_code}" http://localhost:4201/ 2>/dev/null)
if [ "$response" = "200" ]; then
    echo -e "${GREEN}✅ OK${NC}"
else
    echo -e "${RED}❌ Falhou (HTTP $response)${NC}"
fi

# Teste 3: Página de upload
echo -n "Página de upload: "
response=$(curl -s -o /dev/null -w "%{http_code}" http://localhost:4201/upload 2>/dev/null)
if [ "$response" = "200" ]; then
    echo -e "${GREEN}✅ OK${NC}"
else
    echo -e "${RED}❌ Falhou (HTTP $response)${NC}"
fi

# ============================================
# PARTE 6: MOSTRAR LOGS
# ============================================

echo ""
echo -e "${BLUE}7️⃣ Últimas linhas do log:${NC}"
docker logs sparknexus-client-dashboard --tail 10

# ============================================
# RESUMO FINAL
# ============================================

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo -e "${GREEN}✅ SERVER.JS CORRIGIDO!${NC}"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "📋 O que foi corrigido:"
echo "  ✅ Rotas movidas para ANTES do app.listen()"
echo "  ✅ Logs adicionados para debug"
echo "  ✅ Handler 404 adicionado"
echo "  ✅ upload.html verificado/criado"
echo ""
echo "🌐 Acesse agora:"
echo "  ${CYAN}http://localhost:4201/upload${NC}"
echo ""
echo "🔍 Para debug:"
echo "  docker logs -f sparknexus-client-dashboard"
echo ""
echo "📋 Ver todas as rotas:"
echo "  curl http://localhost:4201/api/routes | python3 -m json.tool"
echo ""