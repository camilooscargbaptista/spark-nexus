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
