const express = require('express');
const { z } = require('zod');
const overpassService = require('../services/overpassService');
const { dbManager } = require('../db/database');
const { validate } = require('../middleware/validation');

const router = express.Router();

const syncSchema = z.object({
  lat: z.coerce.number().min(-90).max(90),
  lng: z.coerce.number().min(-180).max(180),
  radius: z.coerce.number().positive().max(25000).default(5000) // max 25km per sync batch
});

/**
 * POST /api/v1/sync/overpass
 * Fetch Muslim places of worship from OpenStreetMap Overpass API and store them
 */
router.post('/overpass', validate(syncSchema, 'body'), async (req, res, next) => {
  try {
    const { lat, lng, radius } = req.validated;

    console.log(`📡 Fetching OSM Overpass data around [${lat}, ${lng}] (radius: ${radius}m)...`);
    const fetchedMosques = await overpassService.fetchNearby(lat, lng, radius);

    const insertedCount = await dbManager.upsertOsmMosques(fetchedMosques);

    res.json({
      success: true,
      message: `OpenStreetMap sync completed`,
      totalFetched: fetchedMosques.length,
      newlyInserted: insertedCount
    });
  } catch (err) {
    next(err);
  }
});

module.exports = router;
