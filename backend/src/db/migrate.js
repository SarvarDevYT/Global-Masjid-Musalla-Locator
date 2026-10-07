const { Pool } = require('pg');
const fs = require('fs');
const path = require('path');
const config = require('../config');
const { SEED_MOSQUES } = require('./seeds');

async function runMigration() {
  console.log('🔄 Connecting to Neon PostgreSQL...');
  
  const pool = new Pool({
    connectionString: config.db.connectionString,
    ssl: { rejectUnauthorized: false }
  });

  try {
    const client = await pool.connect();
    console.log('✅ Connected successfully to Neon DB!');

    console.log('📦 Applying PostGIS schema...');
    const schemaSql = fs.readFileSync(path.join(__dirname, 'schema.sql'), 'utf8');
    await client.query(schemaSql);
    console.log('✅ Schema and PostGIS extensions applied successfully.');

    console.log('🌱 Seeding initial mosques...');
    let seededCount = 0;
    for (const m of SEED_MOSQUES) {
      const res = await client.query(
        `INSERT INTO mosques (
          id, osm_id, name, alt_name, address, city, country, type,
          location, has_wudu_men, has_wudu_women, has_women_prayer_area,
          has_juma, has_wheelchair_access, has_parking, photo_url, status, verified_count
        ) VALUES (
          $1, $2, $3, $4, $5, $6, $7, $8,
          ST_SetSRID(ST_MakePoint($9, $10), 4326),
          $11, $12, $13, $14, $15, $16, $17, $18, $19
        ) ON CONFLICT (id) DO NOTHING RETURNING id`,
        [
          m.id, m.osm_id, m.name, m.alt_name, m.address, m.city, m.country, m.type,
          m.lng, m.lat,
          m.has_wudu_men, m.has_wudu_women, m.has_women_prayer_area,
          m.has_juma, m.has_wheelchair_access, m.has_parking,
          m.photo_url, m.status, m.verified_count
        ]
      );
      if (res.rowCount > 0) seededCount++;
    }

    console.log(`✅ Seeding completed! ${seededCount} mosques inserted into Neon DB.`);
    client.release();
    await pool.end();
    process.exit(0);
  } catch (err) {
    console.error('❌ Migration failed:', err.message);
    if (err.message.includes('password') || err.message.includes('connection')) {
      console.error('👉 Iltimos, backend/.env faylidagi DATABASE_URL to\'g\'ri kiritilganini tekshiring.');
    }
    await pool.end();
    process.exit(1);
  }
}

runMigration();
