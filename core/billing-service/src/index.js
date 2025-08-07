const express = require('express');
const app = express();
app.use(express.json());

// Health check
app.get('/health', (req, res) => {
  res.json({ status: 'healthy', service: 'billing-service' });
});

// Create checkout placeholder
app.post('/billing/create-checkout', async (req, res) => {
  const { organizationId, planId } = req.body;
  
  // TODO: Implement Stripe checkout
  res.json({
    checkoutUrl: 'https://checkout.stripe.com/mock',
    sessionId: 'mock-session-id'
  });
});

const PORT = process.env.PORT || 3002;
app.listen(PORT, () => {
  console.log(`Billing Service running on port ${PORT}`);
});
