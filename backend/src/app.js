const express = require('express');
const helmet = require('helmet');
const cors = require('cors');
const cookieParser = require('cookie-parser');
const rateLimit = require('express-rate-limit');
const path = require('path');
const config = require('./config');
const mosquesRouter = require('./routes/mosques');
const adminRouter = require('./routes/admin');
const uploadRouter = require('./routes/upload');
const { notFoundHandler, errorHandler } = require('./middleware/errorHandler');
const { dbManager } = require('./db/database');

const app = express();

// Vercel / reverse proxy ortida haqiqiy klient IP (rate limit uchun)
app.set('trust proxy', 1);

// Security HTTP headers (CSP: inline skript yo'q, faqat o'z domenimiz + Google Fonts)
app.use(helmet({
  contentSecurityPolicy: {
    useDefaults: false,
    directives: {
      'default-src': ["'self'"],
      'script-src': ["'self'"],
      'style-src': ["'self'", 'https://fonts.googleapis.com'],
      'font-src': ['https://fonts.gstatic.com'],
      'img-src': ["'self'", 'data:', 'https:'],
      'connect-src': ["'self'"],
      'frame-ancestors': ["'none'"],
      'base-uri': ["'self'"],
      'form-action': ["'self'"],
      'object-src': ["'none'"],
      'upgrade-insecure-requests': config.isProd ? [] : null
    }
  }
}));

// CORS: ommaviy GET API uchun; cookie (credentials) yo'q, shuning uchun '*' xavfsiz
app.use(cors({
  origin: config.corsOrigin === '*' ? '*' : config.corsOrigin.split(','),
  methods: ['GET', 'POST', 'PATCH', 'DELETE'],
  allowedHeaders: ['Content-Type']
}));

// Global rate limit
app.use(rateLimit({
  windowMs: config.rateLimitWindowMs,
  max: config.rateLimitMax,
  standardHeaders: true,
  legacyHeaders: false,
  message: { success: false, error: 'Too many requests, please try again later.' }
}));

// Ommaviy yozuv endpointlari uchun qattiqroq limit (spamga qarshi)
const publicWriteLimiter = rateLimit({
  windowMs: 60 * 60 * 1000,
  max: 30,
  skip: req => req.method === 'GET',
  standardHeaders: true,
  legacyHeaders: false,
  message: { success: false, error: 'Juda ko\'p so\'rov. Keyinroq urinib ko\'ring.' }
});
app.use(`${config.apiPrefix}/mosques`, publicWriteLimiter);
app.use(`${config.apiPrefix}/upload`, publicWriteLimiter);

app.use(cookieParser());
app.use(express.json({ limit: '100kb' }));

// Lokal ishlab chiqishda landing + admin (Vercel'da ularni CDN beradi)
app.use(express.static(path.join(__dirname, '../public')));
// Lokal rasm fallback (S3 sozlanmagan bo'lsa)
app.use('/uploads', express.static(path.join(__dirname, '../uploads')));

// Landing page & Admin panel explicit routes
app.get('/admin', (req, res) => {
  res.sendFile(path.join(__dirname, '../public/admin/index.html'));
});
app.get('/', (req, res) => {
  res.sendFile(path.join(__dirname, '../public/index.html'));
});

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

// API routes
app.use(`${config.apiPrefix}/mosques`, mosquesRouter);
app.use(`${config.apiPrefix}/upload`, uploadRouter);
app.use(`${config.apiPrefix}/admin`, adminRouter);

// 404 & Global Error Handling
app.use(notFoundHandler);
app.use(errorHandler);

module.exports = app;
