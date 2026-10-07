const express = require('express');
const { dbManager } = require('../db/database');
const overpassService = require('../services/overpassService');
const {
  idParamSchema,
  nearbyQuerySchema,
  contributeSchema,
  reportSchema,
  validate
} = require('../middleware/validation');

const router = express.Router();

/**
 * GET /api/v1/mosques/nearby
 * Faqat tasdiqlangan (approved) joylar, masofa bo'yicha o'sish tartibida
 */
router.get('/nearby', validate(nearbyQuerySchema, 'query'), async (req, res, next) => {
  try {
    const {
      lat,
      lng,
      radius,
      type,
      q,
      has_wudu_women,
      has_women_prayer_area,
      has_juma,
      has_wheelchair_access,
      has_parking,
      limit,
      offset
    } = req.validated;

    let mosques = await dbManager.findNearby({
      lat,
      lng,
      radiusMeters: radius,
      type,
      amenities: {
        has_wudu_women,
        has_women_prayer_area,
        has_juma,
        has_wheelchair_access,
        has_parking
      },
      q,
      status: 'approved',
      limit,
      offset
    });

    // If database returned 0 mosques in radius, fallback to live Overpass API
    if (mosques.length === 0 && !q) {
      try {
        const liveElements = await overpassService.fetchNearby(lat, lng, radius);
        if (liveElements && liveElements.length > 0) {
          mosques = liveElements.slice(0, limit);
        }
      } catch (_) {}
    }

    res.json({ success: true, count: mosques.length, data: mosques });
  } catch (err) {
    next(err);
  }
});

/**
 * POST /api/v1/mosques/contribute
 * Foydalanuvchi yangi joy taklif qiladi (har doim status: pending)
 */
router.post('/contribute', validate(contributeSchema, 'body'), async (req, res, next) => {
  try {
    const created = await dbManager.addContribution(req.validated);

    res.status(201).json({
      success: true,
      message: 'Mosque submitted successfully and is pending moderation',
      data: { id: created.id, status: created.status }
    });
  } catch (err) {
    next(err);
  }
});

/**
 * GET /api/v1/mosques/:id
 * Ommaviy: faqat tasdiqlangan joy
 */
router.get('/:id', validate(idParamSchema, 'params'), async (req, res, next) => {
  try {
    const mosque = await dbManager.getById(req.validated.id, { onlyApproved: true });
    if (!mosque) {
      return res.status(404).json({ success: false, error: 'Mosque not found' });
    }
    res.json({ success: true, data: mosque });
  } catch (err) {
    next(err);
  }
});

/**
 * POST /api/v1/mosques/:id/report
 * Yopilgan / ko'chirilgan / noto'g'ri ma'lumot haqida shikoyat
 */
router.post(
  '/:id/report',
  validate(idParamSchema, 'params'),
  validate(reportSchema, 'body'),
  async (req, res, next) => {
    try {
      const { id, reason, details } = req.validated;

      const mosque = await dbManager.getById(id, { onlyApproved: true });
      if (!mosque) {
        return res.status(404).json({ success: false, error: 'Mosque not found' });
      }

      const report = await dbManager.addReport(id, reason, details);

      res.status(201).json({
        success: true,
        message: 'Report submitted successfully. Thank you for keeping data accurate.',
        data: { id: report.id }
      });
    } catch (err) {
      next(err);
    }
  }
);

module.exports = router;
