// Load environment variables based on environment
require('dotenv').config({
  path: process.env.NODE_ENV === 'production' ? '.env.production' : '.env'
});

const express = require('express');
const path = require('path');
const compression = require('compression');
const cors = require('cors');
const rateLimit = require('express-rate-limit');
const helmet = require('helmet');

const app = express();
const PORT = process.env.PORT || 8000;

// Security middlewares
app.use(helmet());
app.use(cors());

// Rate limiting
const limiter = rateLimit({
  windowMs: 15 * 60 * 1000, // 15 minutes
  max: 100 // limit each IP to 100 requests per windowMs
});
app.use('/api/', limiter);

// Compression for better performance
app.use(compression());

// Serve static files with cache control
app.use(express.static(__dirname, {
  maxAge: '1d',
  setHeaders: (res, path) => {
    if (path.endsWith('.html')) {
      res.setHeader('Cache-Control', 'no-cache');
    }
  }
}));

// API keys middleware with authentication
app.get('/api/keys', (req, res) => {
  // Implement proper authentication check here
  if (!isAuthenticated(req)) {
    return res.status(401).json({ error: 'Unauthorized' });
  }
  
  // Only provide keys in a secure way
  res.json({
    groq: process.env.GROQ_API_KEY || '',
    perplexity: process.env.PERPLEXITY_API_KEY || '',
    gemini: process.env.GEMINI_API_KEY || ''
  });
});

// Simple authentication check - Replace with your actual auth logic
function isAuthenticated(req) {
  // In production, implement proper session/token validation
  return process.env.NODE_ENV !== 'production' || req.headers['x-api-key'] === process.env.API_SECRET;
}

// Handle all routes by serving index.html
app.get('*', (req, res) => {
  res.sendFile(path.join(__dirname, 'index.html'));
});

// Start the server
app.listen(PORT, '0.0.0.0', (err) => {
  if (err) {
    console.error('Error starting server:', err);
    return;
  }
  console.log(`Server running on http://localhost:${PORT}`);
});