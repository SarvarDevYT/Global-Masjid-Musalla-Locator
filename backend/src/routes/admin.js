const express = require('express');
const rateLimit = require('express-rate-limit');
const { dbManager } = require('../db/database');
const overpassService = require('../services/overpassService');
const {
  isAdminConfigured,
  verifyPassword,
  issueSession,
  clearSession,
  readSession,
  requireAdmin
} = require('../middleware/adminAuth');
const {
  idParamSchema,
  moderationSchema,
  adminLoginSchema,
  adminMosquesQuerySchema,
  adminReportsQuerySchema,
  adminReportUpdateSchema,
  adminSyncSchema,
  validate
} = require('../middleware/validation');

const router = express.Router();

// Brute-force himoyasi: 15 daqiqada 5 ta muvaffaqiyatsiz urinish
const loginLimiter = rateLimit({
  windowMs: 15 * 60 * 1000,
  max: 5,
  skipSuccessfulRequests: true,
  standardHeaders: true,
  legacyHeaders: false,
  message: { success: false, error: 'Juda ko\'p urinish. Keyinroq qayta urinib ko\'ring.' }
});

router.post('/login', loginLimiter, validate(adminLoginSchema, 'body'), async (req, res) => {
  res.set('Cache-Control', 'no-store');

  if (!isAdminConfigured()) {
    console.warn('[security] Admin login attempted but ADMIN_PASSWORD_HASH / JWT_SECRET not configured');
    return res.status(503).json({ success: false, error: 'Admin panel sozlanmagan' });
  }

  const ok = await verifyPassword(req.validated.password);
  if (!ok) {
    console.warn(`[security] Failed admin login from ${req.ip}`);
    return res.status(401).json({ success: false, error: 'Parol noto\'g\'ri' });
  }

  issueSession(res);
  console.info(`[security] Admin login from ${req.ip}`);
  res.json({ success: true });
});

router.get('/me', (req, res) => {
  res.set('Cache-Control', 'no-store');
  res.json({ success: true, authenticated: Boolean(readSession(req)) });
});

router.post('/logout', requireAdmin, (req, res) => {
  clearSession(res);
  console.info(`[security] Admin logout from ${req.ip}`);
  res.json({ success: true });
});

// ---------- Quyidagi barcha route'lar faqat admin uchun (deny by default) ----------
router.use(requireAdmin);

router.get('/stats', async (req, res, next) => {
  try {
    res.json({ success: true, data: await dbManager.getStats() });
  } catch (err) {
    next(err);
  }
});

router.get('/mosques', validate(adminMosquesQuerySchema, 'query'), async (req, res, next) => {
  try {
    const { status, q, limit, offset } = req.validated;
    const data = await dbManager.listMosques({ status, q, limit, offset });
    res.json({ success: true, count: data.length, data });
  } catch (err) {
    next(err);
  }
});

router.patch(
  '/mosques/:id/status',
  validate(idParamSchema, 'params'),
  validate(moderationSchema, 'body'),
  async (req, res, next) => {
    try {
      const { id, status } = req.validated;
      const updated = await dbManager.moderate(id, status);
      if (!updated) {
        return res.status(404).json({ success: false, error: 'Joy topilmadi' });
      }
      console.info(`[audit] Admin set mosque ${id} -> ${status}`);
      res.json({ success: true, data: { id: updated.id, status: updated.status } });
    } catch (err) {
      next(err);
    }
  }
);

router.get('/reports', validate(adminReportsQuerySchema, 'query'), async (req, res, next) => {
  try {
    const { status, limit, offset } = req.validated;
    const data = await dbManager.listReports({ status, limit, offset });
    res.json({ success: true, count: data.length, data });
  } catch (err) {
    next(err);
  }
});

router.patch(
  '/reports/:id',
  validate(idParamSchema, 'params'),
  validate(adminReportUpdateSchema, 'body'),
  async (req, res, next) => {
    try {
      const { id, status } = req.validated;
      const updated = await dbManager.updateReportStatus(id, status);
      if (!updated) {
        return res.status(404).json({ success: false, error: 'Shikoyat topilmadi' });
      }
      console.info(`[audit] Admin set report ${id} -> ${status}`);
      res.json({ success: true, data: updated });
    } catch (err) {
      next(err);
    }
  }
);

// OpenStreetMap (Overpass) dan hudud bo'yicha import
router.post('/sync/overpass', validate(adminSyncSchema, 'body'), async (req, res, next) => {
  try {
    const { lat, lng, radius } = req.validated;
    const fetched = await overpassService.fetchNearby(lat, lng, radius);
    const inserted = await dbManager.upsertOsmMosques(fetched);
    console.info(`[audit] Admin OSM import at [${lat}, ${lng}] r=${radius}: ${inserted}/${fetched.length}`);
    res.json({ success: true, totalFetched: fetched.length, newlyInserted: inserted });
  } catch (err) {
    next(err);
  }
});

module.exports = router;
