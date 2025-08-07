const express = require('express');
const app = express();
app.use(express.json());

// Health check
app.get('/health', (req, res) => {
  res.json({ status: 'healthy', service: 'auth-service' });
});

// Login endpoint placeholder
app.post('/auth/login', async (req, res) => {
  const { email, password, organizationSlug } = req.body;
  
  // TODO: Implement actual authentication
  res.json({
    token: 'mock-jwt-token',
    user: {
      id: '123',
      email: email,
      organizationSlug: organizationSlug
    }
  });
});

const PORT = process.env.PORT || 3001;
app.listen(PORT, () => {
  console.log(`Auth Service running on port ${PORT}`);
});
