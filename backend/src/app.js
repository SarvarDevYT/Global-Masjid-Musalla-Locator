const express = require('express');
const helmet = require('helmet');
const cors = require('cors');
const rateLimit = require('express-rate-limit');
const config = require('./config');
const mosquesRouter = require('./routes/mosques');
const syncRouter = require('./routes/sync');
const uploadRouter = require('./routes/upload');
const path = require('path');
const { notFoundHandler, errorHandler } = require('./middleware/errorHandler');
const { dbManager } = require('./db/database');

const app = express();

// Security HTTP headers
app.use(helmet());

// CORS Configuration
app.use(cors({
  origin: config.corsOrigin === '*' ? '*' : config.corsOrigin.split(','),
  methods: ['GET', 'POST', 'PATCH', 'DELETE'],
  allowedHeaders: ['Content-Type', 'Authorization']
}));

// Serve static uploads locally if fallback is active
app.use('/uploads', express.static(path.join(__dirname, '../uploads')));

// Rate limiting (300 requests per 15 minutes by default)
const limiter = rateLimit({
  windowMs: config.rateLimitWindowMs,
  max: config.rateLimitMax,
  standardHeaders: true,
  legacyHeaders: false,
  message: {
    success: false,
    error: 'Too many requests, please try again later.'
  }
});
app.use(limiter);

// Parse JSON bodies (max 1mb)
app.use(express.json({ limit: '1mb' }));

// Health Check
app.get(`${config.apiPrefix}/health`, (req, res) => {
  res.json({
    success: true,
    status: 'healthy',
    timestamp: new Date().toISOString(),
    postgresConnected: dbManager.isPostgresConnected,
    version: '1.0.0'
  });
});

// Main API Routes
app.use(`${config.apiPrefix}/mosques`, mosquesRouter);
app.use(`${config.apiPrefix}/sync`, syncRouter);
app.use(`${config.apiPrefix}/upload`, uploadRouter);

// 404 & Global Error Handling
app.use(notFoundHandler);
app.use(errorHandler);

module.exports = app;
