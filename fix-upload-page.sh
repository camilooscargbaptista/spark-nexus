#!/bin/bash

echo "🔧 Corrigindo página de upload..."

# Verificar se o arquivo upload.html existe
if [ ! -f "core/client-dashboard/public/upload.html" ]; then
    echo "Criando upload.html..."
    
    # Copiar do script anterior ou criar novo
    cp core/client-dashboard/public/index.html core/client-dashboard/public/upload.html 2>/dev/null || \
    curl -s https://raw.githubusercontent.com/your-repo/upload.html > core/client-dashboard/public/upload.html 2>/dev/null || \
    echo "<h1>Upload Page</h1>" > core/client-dashboard/public/upload.html
fi

# Verificar o server.js
echo "Verificando server.js..."
if ! grep -q "/upload" core/client-dashboard/server.js; then
    echo "Adicionando rota /upload..."
    cat >> core/client-dashboard/server.js << 'EOFSERVER'

// Servir página de upload
app.get('/upload', (req, res) => {
  res.sendFile(path.join(__dirname, 'public', 'upload.html'));
});
EOFSERVER
fi

# Reiniciar o dashboard
echo "Reiniciando Client Dashboard..."
docker restart sparknexus-client-dashboard

echo "✅ Corrigido!"
