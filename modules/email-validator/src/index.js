const express = require('express');
const cors = require('cors');
const multer = require('multer');
const path = require('path');
const fs = require('fs').promises;

const app = express();
const PORT = process.env.PORT || 4001;

// Configurar CORS
app.use(cors({
  origin: '*',
  methods: ['GET', 'POST', 'PUT', 'DELETE', 'OPTIONS'],
  allowedHeaders: ['Content-Type', 'Authorization', 'X-API-Key']
}));

app.use(express.json());
app.use(express.urlencoded({ extended: true }));

// ============================================
// CONFIGURAR MULTER PARA UPLOAD
// ============================================

const storage = multer.diskStorage({
  destination: async (req, file, cb) => {
    const uploadDir = path.join(__dirname, '../uploads');
    try {
      await fs.mkdir(uploadDir, { recursive: true });
    } catch (error) {
      console.error('Error creating upload dir:', error);
    }
    cb(null, uploadDir);
  },
  filename: (req, file, cb) => {
    const uniqueName = `${Date.now()}-${Math.round(Math.random() * 1E9)}${path.extname(file.originalname)}`;
    cb(null, uniqueName);
  }
});

const upload = multer({ 
  storage: storage,
  limits: { fileSize: 10 * 1024 * 1024 }, // 10MB
  fileFilter: (req, file, cb) => {
    const allowedTypes = ['.csv', '.xlsx', '.xls', '.txt'];
    const ext = path.extname(file.originalname).toLowerCase();
    if (allowedTypes.includes(ext)) {
      cb(null, true);
    } else {
      cb(new Error('Invalid file type. Only CSV, Excel and TXT files are allowed.'));
    }
  }
});

// Importar serviços
const emailService = require('./services/email-service');
const queueService = require('./services/queue-service');
const reportService = require('./services/report-service');

// ============================================
// ROTAS
// ============================================

// Health check
app.get('/health', (req, res) => {
  console.log('Health check requested');
  res.json({ 
    status: 'healthy',
    service: 'email-validator',
    version: '2.0.0',
    endpoints: [
      'GET /health',
      'POST /validate',
      'POST /upload-and-validate',
      'GET /job/:jobId',
      'GET /download/:jobId'
    ]
  });
});

// Rota principal de validação (API)
app.post('/validate', async (req, res) => {
  console.log('POST /validate - Request received');
  try {
    const { emails, organizationId = 'demo' } = req.body;
    
    if (!emails || !Array.isArray(emails)) {
      return res.status(400).json({ error: 'emails array is required' });
    }
    
    console.log(`Validating ${emails.length} emails for org: ${organizationId}`);
    
    // Validação simples para teste
    const results = await emailService.validateEmails(emails);
    
    res.json({
      success: true,
      results,
      usage: {
        used: Math.floor(Math.random() * 500) + 100,
        limit: 1000,
        remaining: Math.floor(Math.random() * 500) + 400
      }
    });
  } catch (error) {
    console.error('Validation error:', error);
    res.status(500).json({ error: error.message });
  }
});

// ============================================
// ROTA PRINCIPAL DE UPLOAD - ESTA É A QUE FALTAVA!
// ============================================

app.post('/upload-and-validate', upload.single('file'), async (req, res) => {
  console.log('POST /upload-and-validate - Upload received');
  
  try {
    // Verificar se arquivo foi enviado
    if (!req.file) {
      console.log('No file uploaded');
      return res.status(400).json({ error: 'No file uploaded' });
    }
    
    const { email, organizationId = 'demo' } = req.body;
    
    console.log(`File: ${req.file.originalname}`);
    console.log(`Email: ${email}`);
    console.log(`Organization: ${organizationId}`);
    
    // Extrair emails do arquivo
    const emails = await emailService.extractEmailsFromFile(req.file.path, req.file.mimetype);
    
    if (emails.length === 0) {
      return res.status(400).json({ error: 'No valid emails found in file' });
    }
    
    console.log(`Found ${emails.length} emails in file`);
    
    // Criar job na fila
    const jobId = `job_${Date.now()}_${Math.random().toString(36).substr(2, 9)}`;
    
    // Por enquanto, processar de forma síncrona para teste
    const results = await emailService.validateEmails(emails.slice(0, 100)); // Limitar a 100 para teste
    
    // Simular resposta de job criado
    res.json({
      success: true,
      message: 'File uploaded and validation started',
      jobId: jobId,
      emailCount: emails.length,
      estimatedTime: `${Math.ceil(emails.length / 100)} minutes`,
      resultWillBeSentTo: email || 'Not specified',
      preview: {
        firstEmails: emails.slice(0, 5),
        results: results.slice(0, 3)
      }
    });
    
    // Limpar arquivo após processar
    try {
      await fs.unlink(req.file.path);
    } catch (error) {
      console.error('Error deleting uploaded file:', error);
    }
    
  } catch (error) {
    console.error('Upload error:', error);
    res.status(500).json({ 
      error: error.message || 'Upload and validation failed',
      details: error.stack
    });
  }
});

// Verificar status do job
app.get('/job/:jobId', async (req, res) => {
  console.log(`GET /job/${req.params.jobId}`);
  
  // Mock response por enquanto
  res.json({
    jobId: req.params.jobId,
    status: 'completed',
    progress: 100,
    results: {
      total: 10,
      valid: 7,
      invalid: 3
    }
  });
});

// Download do relatório
app.get('/download/:jobId', async (req, res) => {
  console.log(`GET /download/${req.params.jobId}`);
  
  // Mock response
  res.json({
    message: 'Report generation not yet implemented',
    jobId: req.params.jobId
  });
});

// Rota 404
app.use((req, res) => {
  console.log(`404 - Route not found: ${req.method} ${req.url}`);
  res.status(404).json({ 
    error: 'Route not found',
    path: req.url,
    method: req.method
  });
});

// Error handler
app.use((error, req, res, next) => {
  console.error('Server error:', error);
  
  if (error instanceof multer.MulterError) {
    if (error.code === 'FILE_TOO_LARGE') {
      return res.status(400).json({ error: 'File too large. Maximum size is 10MB.' });
    }
    return res.status(400).json({ error: error.message });
  }
  
  res.status(500).json({ 
    error: error.message || 'Internal server error'
  });
});

// ============================================
// INICIAR SERVIDOR
// ============================================

app.listen(PORT, '0.0.0.0', () => {
  console.log('='.repeat(50));
  console.log(`✅ Email Validator API running on port ${PORT}`);
  console.log('='.repeat(50));
  console.log('Available endpoints:');
  console.log('  GET  /health');
  console.log('  POST /validate');
  console.log('  POST /upload-and-validate (multipart/form-data)');
  console.log('  GET  /job/:jobId');
  console.log('  GET  /download/:jobId');
  console.log('='.repeat(50));
});
