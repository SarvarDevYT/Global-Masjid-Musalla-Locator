const { z } = require('zod');

const UUID_RE = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;
const boolFlag = z.preprocess(v => v === 'true' || v === true, z.boolean());

const idParamSchema = z.object({
  id: z.string().regex(UUID_RE, 'Noto\'g\'ri identifikator')
});

const nearbyQuerySchema = z.object({
  lat: z.coerce.number().min(-90).max(90),
  lng: z.coerce.number().min(-180).max(180),
  radius: z.coerce.number().positive().max(2000000).default(25000), // Default 25km, max 2000km to cover all Uzbekistan
  type: z.enum(['masjid', 'musalla']).optional(),
  q: z.string().trim().max(100).optional(),
  has_wudu_women: boolFlag.optional(),
  has_women_prayer_area: boolFlag.optional(),
  has_juma: boolFlag.optional(),
  has_wheelchair_access: boolFlag.optional(),
  has_parking: boolFlag.optional(),
  limit: z.coerce.number().int().positive().max(3000).default(50),
  offset: z.coerce.number().int().nonnegative().default(0)
});

const bboxQuerySchema = z.object({
  min_lat: z.coerce.number().min(-90).max(90),
  max_lat: z.coerce.number().min(-90).max(90),
  min_lng: z.coerce.number().min(-180).max(180),
  max_lng: z.coerce.number().min(-180).max(180),
  type: z.enum(['masjid', 'musalla']).optional(),
  limit: z.coerce.number().int().positive().max(3000).default(1500)
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
  // Faqat https: javascript:/data: kabi sxemalar rad etiladi
  photo_url: z.string().url().max(1000)
    .refine(u => u.startsWith('https://'), 'Faqat https havolalar ruxsat etiladi')
    .optional().nullable()
});

const reportSchema = z.object({
  reason: z.string().trim().min(3).max(100),
  details: z.string().trim().max(1000).optional()
});

const moderationSchema = z.object({
  status: z.enum(['approved', 'rejected'])
});

// ---------- Admin ----------
const adminLoginSchema = z.object({
  password: z.string().min(1).max(200)
});

const adminMosquesQuerySchema = z.object({
  status: z.enum(['pending', 'approved', 'rejected']).optional(),
  q: z.string().trim().max(100).optional(),
  limit: z.coerce.number().int().positive().max(100).default(50),
  offset: z.coerce.number().int().nonnegative().default(0)
});

const adminReportsQuerySchema = z.object({
  status: z.enum(['open', 'reviewed', 'resolved']).optional(),
  limit: z.coerce.number().int().positive().max(100).default(50),
  offset: z.coerce.number().int().nonnegative().default(0)
});

const adminReportUpdateSchema = z.object({
  status: z.enum(['open', 'reviewed', 'resolved'])
});

const adminSyncSchema = z.object({
  lat: z.coerce.number().min(-90).max(90),
  lng: z.coerce.number().min(-180).max(180),
  radius: z.coerce.number().positive().max(25000).default(5000) // bir martada maks. 25 km
});

const validate = (schema, source = 'query') => (req, res, next) => {
  try {
    const parsed = schema.parse(req[source]);
    // Bir route'da params + body bo'lsa, natijalar qo'shiladi
    req.validated = { ...(req.validated || {}), ...parsed };
    next();
  } catch (err) {
    return res.status(400).json({
      success: false,
      error: 'Validation failed',
      details: err.errors ? err.errors.map(e => ({ field: e.path.join('.'), message: e.message })) : 'Invalid input'
    });
  }
};

module.exports = {
  idParamSchema,
  nearbyQuerySchema,
  bboxQuerySchema,
  contributeSchema,
  reportSchema,
  moderationSchema,
  adminLoginSchema,
  adminMosquesQuerySchema,
  adminReportsQuerySchema,
  adminReportUpdateSchema,
  adminSyncSchema,
  scanSyncSchema: adminSyncSchema,
  validate
};
