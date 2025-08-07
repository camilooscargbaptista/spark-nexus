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
