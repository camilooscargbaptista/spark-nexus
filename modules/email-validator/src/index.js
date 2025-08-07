const express = require('express');

const app = express();
const PORT = process.env.PORT || 4001;

// Middleware para CORS manual (sem dependência)
app.use((req, res, next) => {
  res.header('Access-Control-Allow-Origin', '*');
  res.header('Access-Control-Allow-Methods', 'GET, POST, PUT, DELETE, OPTIONS');
  res.header('Access-Control-Allow-Headers', 'Content-Type, Authorization, X-API-Key');
  
  if (req.method === 'OPTIONS') {
    return res.sendStatus(200);
  }
  
  next();
});

// Parse JSON
app.use(express.json());

// Logging middleware
app.use((req, res, next) => {
  console.log(`${new Date().toISOString()} - ${req.method} ${req.url}`);
  next();
});

// Health check
app.get('/health', (req, res) => {
  console.log('Health check requested');
  res.json({ 
    status: 'healthy', 
    service: 'email-validator',
    timestamp: new Date().toISOString(),
    port: PORT
  });
});

// Root endpoint
app.get('/', (req, res) => {
  res.json({ 
    service: 'Email Validator Module',
    version: '1.0.0',
    endpoints: ['/health', '/validate']
  });
});

// Validate endpoint
app.post('/validate', (req, res) => {
  console.log('Validation request received:', JSON.stringify(req.body));
  
  try {
    const { emails, organizationId } = req.body;
    
    if (!emails || !Array.isArray(emails)) {
      console.log('Invalid request: emails array missing');
      return res.status(400).json({ 
        error: 'emails array is required',
        received: req.body 
      });
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
          domain: isValid ? email.split('@')[1] : null
        }
      };
    });
    
    const response = {
      success: true,
      results,
      usage: {
        used: 350,
        limit: 1000,
        remaining: 650
      },
      organization: organizationId || 'demo'
    };
    
    console.log('Sending response:', JSON.stringify(response));
    res.json(response);
    
  } catch (error) {
    console.error('Error in /validate:', error);
    res.status(500).json({ 
      error: 'Internal server error',
      message: error.message 
    });
  }
});

// 404 handler
app.use((req, res) => {
  console.log('404 - Route not found:', req.url);
  res.status(404).json({ 
    error: 'Route not found',
    path: req.url 
  });
});

// Error handler
app.use((err, req, res, next) => {
  console.error('Server error:', err);
  res.status(500).json({ 
    error: 'Internal server error',
    message: err.message 
  });
});

// Start server
app.listen(PORT, '0.0.0.0', () => {
  console.log(`✅ Email Validator Module running on port ${PORT}`);
  console.log(`   Environment: ${process.env.NODE_ENV || 'development'}`);
  console.log(`   Health check: http://localhost:${PORT}/health`);
  console.log(`   Validate endpoint: http://localhost:${PORT}/validate`);
});

// Handle shutdown
process.on('SIGTERM', () => {
  console.log('SIGTERM received, shutting down gracefully');
  process.exit(0);
});

process.on('SIGINT', () => {
  console.log('SIGINT received, shutting down gracefully');
  process.exit(0);
});
