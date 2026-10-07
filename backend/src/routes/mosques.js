const express = require('express');
const { dbManager } = require('../db/database');
const {
  nearbyQuerySchema,
  contributeSchema,
  reportSchema,
  moderationSchema,
  validate
} = require('../middleware/validation');

const router = express.Router();

/**
 * GET /api/v1/mosques/nearby
 * Returns mosques sorted by distance from given lat, lng
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

    const amenities = {
      has_wudu_women,
      has_women_prayer_area,
      has_juma,
      has_wheelchair_access,
      has_parking
    };

    const mosques = await dbManager.findNearby({
      lat,
      lng,
      radiusMeters: radius,
      type,
      amenities,
      q,
      status: 'approved',
      limit,
      offset
    });

    res.json({
      success: true,
      count: mosques.length,
      data: mosques
    });
  } catch (err) {
    next(err);
  }
});

/**
 * GET /api/v1/mosques/pending
 * Retrieve mosques awaiting moderation
 */
router.get('/pending', async (req, res, next) => {
  try {
    // Arbitrary center, search with 40,000 km radius to fetch all pending worldwide
    const pending = await dbManager.findNearby({
      lat: 0,
      lng: 0,
      radiusMeters: 40000000,
      status: 'pending',
      limit: 100
    });

    res.json({
      success: true,
      count: pending.length,
      data: pending
    });
  } catch (err) {
    next(err);
  }
});

/**
 * GET /api/v1/mosques/:id
 * Retrieve a single mosque by ID
 */
router.get('/:id', async (req, res, next) => {
  try {
    const mosque = await dbManager.getById(req.params.id);
    if (!mosque) {
      return res.status(404).json({
        success: false,
        error: 'Mosque not found'
      });
    }

    res.json({
      success: true,
      data: mosque
    });
  } catch (err) {
    next(err);
  }
});

/**
 * POST /api/v1/mosques/contribute
 * User submits a new mosque for community moderation
 */
router.post('/contribute', validate(contributeSchema, 'body'), async (req, res, next) => {
  try {
    const newMosque = await dbManager.addContribution(req.validated);

    res.status(201).json({
      success: true,
      message: 'Mosque submitted successfully and is pending moderation',
      data: newMosque
    });
  } catch (err) {
    next(err);
  }
});

/**
 * PATCH /api/v1/mosques/:id/moderate
 * Admin/Community moderator approves or rejects a pending mosque
 */
router.patch('/:id/moderate', validate(moderationSchema, 'body'), async (req, res, next) => {
  try {
    const updated = await dbManager.moderate(req.params.id, req.validated.status);
    if (!updated) {
      return res.status(404).json({
        success: false,
        error: 'Mosque not found'
      });
    }

    res.json({
      success: true,
      message: `Mosque status updated to ${req.validated.status}`,
      data: updated
    });
  } catch (err) {
    next(err);
  }
});

/**
 * POST /api/v1/mosques/:id/report
 * User reports an inaccuracy or closed mosque
 */
router.post('/:id/report', validate(reportSchema, 'body'), async (req, res, next) => {
  try {
    const mosque = await dbManager.getById(req.params.id);
    if (!mosque) {
      return res.status(404).json({
        success: false,
        error: 'Mosque not found'
      });
    }

    const report = await dbManager.addReport(
      req.params.id,
      req.validated.reason,
      req.validated.details
    );

    res.status(201).json({
      success: true,
      message: 'Report submitted successfully. Thank you for keeping data accurate.',
      data: report
    });
  } catch (err) {
    next(err);
  }
});

module.exports = router;
