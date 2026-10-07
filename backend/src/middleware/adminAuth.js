const jwt = require('jsonwebtoken');
const bcrypt = require('bcryptjs');
const config = require('../config');

const COOKIE_NAME = 'admin_token';

function isAdminConfigured() {
  return Boolean(config.admin.passwordHash) && config.admin.jwtSecret.length >= 32;
}

async function verifyPassword(plain) {
  if (!isAdminConfigured() || typeof plain !== 'string' || plain.length > 200) return false;
  try {
    return await bcrypt.compare(plain, config.admin.passwordHash);
  } catch {
    return false;
  }
}

function issueSession(res) {
  const token = jwt.sign({ role: 'admin' }, config.admin.jwtSecret, {
    algorithm: 'HS256',
    expiresIn: `${config.admin.sessionHours}h`
  });
  res.cookie(COOKIE_NAME, token, {
    httpOnly: true,
    secure: config.isProd,
    sameSite: 'strict',
    path: '/',
    maxAge: config.admin.sessionHours * 3600 * 1000
  });
}

function clearSession(res) {
  res.clearCookie(COOKIE_NAME, {
    httpOnly: true,
    secure: config.isProd,
    sameSite: 'strict',
    path: '/'
  });
}

function readSession(req) {
  const token = req.cookies && req.cookies[COOKIE_NAME];
  if (!token || !isAdminConfigured()) return null;
  try {
    // algorithms ro'yxati aniq: 'none' va boshqa algoritmlar rad etiladi
    const payload = jwt.verify(token, config.admin.jwtSecret, { algorithms: ['HS256'] });
    return payload && payload.role === 'admin' ? payload : null;
  } catch {
    return null;
  }
}

// Deny by default: sessiya bo'lmasa har doim 401
function requireAdmin(req, res, next) {
  res.set('Cache-Control', 'no-store');
  if (!readSession(req)) {
    return res.status(401).json({ success: false, error: 'Avtorizatsiya talab qilinadi' });
  }

  // CSRF qatlami (sameSite=strict ustiga): o'zgartiruvchi so'rovlarda maxsus sarlavha shart
  if (!['GET', 'HEAD', 'OPTIONS'].includes(req.method)) {
    if (req.get('X-Requested-With') !== 'masjid-admin') {
      return res.status(403).json({ success: false, error: 'Taqiqlangan so\'rov' });
    }
  }
  next();
}

module.exports = {
  isAdminConfigured,
  verifyPassword,
  issueSession,
  clearSession,
  readSession,
  requireAdmin
};
