require('dotenv').config();

const express = require('express');
const path = require('path');
const helmet = require('helmet');
const compression = require('compression');
const rateLimit = require('express-rate-limit');
const cors = require('cors');

const app = express();
const PORT = process.env.PORT || 3000;
const isProduction = process.env.NODE_ENV === 'production';

// Security middleware
app.use(helmet({
    contentSecurityPolicy: {
        directives: {
            defaultSrc: ["'self'"],
            scriptSrc: ["'self'", "'unsafe-inline'", 'cdnjs.cloudflare.com', 'unpkg.com'],
            styleSrc: ["'self'", "'unsafe-inline'", 'cdnjs.cloudflare.com'],
            imgSrc: ["'self'", 'data:', 'blob:'],
            connectSrc: ["'self'", 'api.groq.com', 'api.perplexity.ai', 'generativelanguage.googleapis.com']
        }
    }
}));

// Rate limiting
const apiLimiter = rateLimit({
    windowMs: parseInt(process.env.RATE_LIMIT_WINDOW_MS) || 900000, // 15 minutes
    max: parseInt(process.env.RATE_LIMIT_MAX_REQUESTS) || 100
});

// Middleware
app.use(compression());
app.use(cors());
app.use(express.json());

// Serve static files from dist in production
app.use(express.static(isProduction ? path.join(__dirname, 'dist') : __dirname));

// API keys middleware with rate limiting
app.get('/api/keys', apiLimiter, (req, res) => {
    // Basic API key validation
    if (!process.env.GROQ_API_KEY && !process.env.PERPLEXITY_API_KEY && !process.env.GEMINI_API_KEY) {
        return res.status(500).json({ error: 'API keys not configured' });
    }

    try {
        res.json({
            groq: process.env.GROQ_API_KEY || '',
            perplexity: process.env.PERPLEXITY_API_KEY || '',
            gemini: process.env.GEMINI_API_KEY || ''
        });
    } catch (error) {
        console.error('Error providing API keys:', error);
        res.status(500).json({ error: 'Internal server error' });
    }
});

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