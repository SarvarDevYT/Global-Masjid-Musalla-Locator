const { Pool } = require('pg');
require('dotenv').config({ path: require('path').resolve(__dirname, '../../.env') });

const pool = new Pool({
  connectionString: process.env.DATABASE_URL_POOLED || process.env.DATABASE_URL,
  ssl: { rejectUnauthorized: false }
});

async function testQuery(cityName, lat, lng) {
  const res = await pool.query(`
    SELECT name, type, ROUND(ST_Distance(location, ST_SetSRID(ST_MakePoint($1, $2), 4326)::geography)) as dist_m
    FROM mosques
    WHERE ST_DWithin(location, ST_SetSRID(ST_MakePoint($1, $2), 4326)::geography, 10000)
    ORDER BY dist_m ASC
    LIMIT 5
  `, [lng, lat]);

  console.log(`\n=== Nearby in ${cityName} (${lat}, ${lng}) ===`);
  if (res.rows.length === 0) {
    console.log('No mosques within 10km');
  } else {
    res.rows.forEach((r, i) => {
      const km = (r.dist_m / 1000).toFixed(2);
      console.log(` ${i + 1}. ${r.name} [${r.type}] — ${km} km away (${r.dist_m} m)`);
    });
  }
}

async function main() {
  await testQuery('Toshkent', 41.3111, 69.2405);
  await testQuery('Samarqand', 39.6542, 66.9597);
  await testQuery('Buxoro', 39.7747, 64.4286);
  await testQuery('Andijon', 40.7821, 72.3442);
  await testQuery('Namangan', 40.9983, 71.6726);
  await testQuery('Farg\'ona', 40.3842, 71.7843);
  await testQuery('Urganch (Xorazm)', 41.5562, 60.6317);
  await testQuery('Nukus (Qoraqalpog\'iston)', 42.4619, 59.6166);
  await testQuery('Qarshi (Qashqadaryo)', 38.8606, 65.7891);
  await testQuery('Termiz (Surxondaryo)', 37.2242, 67.2783);
  await pool.end();
}

main().catch(console.error);
