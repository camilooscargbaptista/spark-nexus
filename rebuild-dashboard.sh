#!/bin/bash

echo "🔧 Rebuild completo do Client Dashboard..."

# 1. Parar e remover container
docker stop sparknexus-client-dashboard
docker rm sparknexus-client-dashboard

# 2. Remover imagem antiga
docker rmi sparknexus/client-dashboard:latest

# 3. Verificar que server.js está correto
echo "Verificando server.js..."
if ! grep -q "app.get('/upload'" core/client-dashboard/server.js || grep -q "app.listen.*app.get('/upload'" core/client-dashboard/server.js; then
    echo "Corrigindo server.js..."
    cat > core/client-dashboard/server.js << 'EOFSERVER'
const express = require('express');
const cors = require('cors');
const path = require('path');

const app = express();
const PORT = process.env.PORT || 4201;

app.use(cors());
app.use(express.json());
app.use(express.static('public'));

// Rotas ANTES do listen
app.get('/', (req, res) => {
  console.log('GET /');
  res.sendFile(path.join(__dirname, 'public', 'index.html'));
});

app.get('/upload', (req, res) => {
  console.log('GET /upload');
  res.sendFile(path.join(__dirname, 'public', 'upload.html'));
});

app.get('/api/health', (req, res) => {
  res.json({ status: 'healthy' });
});

// LISTEN NO FINAL
app.listen(PORT, () => {
  console.log(`Client Dashboard on ${PORT}`);
  console.log('Routes: /, /upload, /api/health');
});
EOFSERVER
fi

# 4. Build nova imagem
docker-compose build --no-cache client-dashboard

# 5. Iniciar container
docker-compose up -d client-dashboard

# 6. Aguardar
sleep 5

# 7. Testar
echo "Testando..."
curl -I http://localhost:4201/upload

echo "✅ Feito!"