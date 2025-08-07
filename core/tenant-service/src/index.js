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
