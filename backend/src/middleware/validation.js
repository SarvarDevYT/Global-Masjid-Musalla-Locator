const { z } = require('zod');

const nearbyQuerySchema = z.object({
  lat: z.coerce.number().min(-90).max(90),
  lng: z.coerce.number().min(-180).max(180),
  radius: z.coerce.number().positive().max(100000).default(10000), // Default 10km, max 100km
  type: z.enum(['masjid', 'musalla']).optional(),
  q: z.string().trim().max(100).optional(),
  has_wudu_women: z.preprocess(v => v === 'true' || v === true, z.boolean()).optional(),
  has_women_prayer_area: z.preprocess(v => v === 'true' || v === true, z.boolean()).optional(),
  has_juma: z.preprocess(v => v === 'true' || v === true, z.boolean()).optional(),
  has_wheelchair_access: z.preprocess(v => v === 'true' || v === true, z.boolean()).optional(),
  has_parking: z.preprocess(v => v === 'true' || v === true, z.boolean()).optional(),
  limit: z.coerce.number().int().positive().max(100).default(50),
  offset: z.coerce.number().int().nonnegative().default(0)
});

const contributeSchema = z.object({
  name: z.string().trim().min(3).max(255),
  alt_name: z.string().trim().max(255).optional().nullable(),
  address: z.string().trim().max(500).optional(),
  city: z.string().trim().max(100).optional(),
  country: z.string().trim().max(100).optional(),
  type: z.enum(['masjid', 'musalla']).default('masjid'),
  lat: z.number().min(-90).max(90),
  lng: z.number().min(-180).max(180),
  has_wudu_men: z.boolean().default(true),
  has_wudu_women: z.boolean().default(false),
  has_women_prayer_area: z.boolean().default(false),
  has_juma: z.boolean().default(true),
  has_wheelchair_access: z.boolean().default(false),
  has_parking: z.boolean().default(false),
  photo_url: z.string().url().max(1000).optional().nullable()
});

const reportSchema = z.object({
  reason: z.string().trim().min(3).max(100),
  details: z.string().trim().max(1000).optional()
});

const moderationSchema = z.object({
  status: z.enum(['approved', 'rejected'])
});

const validate = (schema, source = 'query') => (req, res, next) => {
  try {
    const parsed = schema.parse(req[source]);
    req.validated = parsed;
    next();
  } catch (err) {
    return res.status(400).json({
      success: false,
      error: 'Validation failed',
      details: err.errors ? err.errors.map(e => ({ field: e.path.join('.'), message: e.message })) : err.message
    });
  }
};

module.exports = {
  nearbyQuerySchema,
  contributeSchema,
  reportSchema,
  moderationSchema,
  validate
};
