const https = require('https');
const fs = require('fs');
const path = require('path');
const crypto = require('crypto');
const { Pool } = require('pg');
require('dotenv').config({ path: path.resolve(__dirname, '../../.env') });

const connectionString = process.env.DATABASE_URL_POOLED || process.env.DATABASE_URL;

console.log('--- Scanning Uzbekistan Mosques & Musallas ---');

async function fetchFromOverpass() {
  const query = `
    [out:json][timeout:180];
    area["ISO3166-1"="UZ"][admin_level=2]->.uz;
    (
      node["amenity"="place_of_worship"]["religion"="muslim"](area.uz);
      way["amenity"="place_of_worship"]["religion"="muslim"](area.uz);
      relation["amenity"="place_of_worship"]["religion"="muslim"](area.uz);
      node["building"="mosque"](area.uz);
      way["building"="mosque"](area.uz);
      node["amenity"="prayer_room"](area.uz);
      way["amenity"="prayer_room"](area.uz);
    );
    out center tags;
  `;

  const endpoints = [
    'https://lz4.overpass-api.de/api/interpreter',
    'https://overpass-api.de/api/interpreter',
    'https://overpass.kumi.systems/api/interpreter'
  ];

  for (const endpoint of endpoints) {
    console.log(`Connecting to Overpass endpoint: ${endpoint}...`);
    try {
      const elements = await queryEndpoint(endpoint, query);
      if (elements && elements.length > 0) {
        console.log(`✓ Overpass returned ${elements.length} elements!`);
        return elements;
      }
    } catch (err) {
      console.warn(`! Endpoint ${endpoint} failed: ${err.message}`);
    }
  }

  throw new Error('All Overpass endpoints failed');
}

function queryEndpoint(urlStr, query) {
  return new Promise((resolve, reject) => {
    const postData = 'data=' + encodeURIComponent(query);
    const url = new URL(urlStr);

    const options = {
      hostname: url.hostname,
      port: 443,
      path: url.pathname,
      method: 'POST',
      headers: {
        'Content-Type': 'application/x-www-form-urlencoded',
        'Content-Length': Buffer.byteLength(postData),
        'User-Agent': 'GlobalMasjidLocator/1.0 (UzbekistanIngest)'
      },
      timeout: 150000
    };

    const req = https.request(options, (res) => {
      let data = '';
      res.on('data', chunk => data += chunk);
      res.on('end', () => {
        if (res.statusCode !== 200) {
          return reject(new Error(`HTTP ${res.statusCode}: ${data.slice(0, 120)}`));
        }
        try {
          const parsed = JSON.parse(data);
          resolve(parsed.elements || []);
        } catch (e) {
          reject(e);
        }
      });
    });

    req.on('timeout', () => {
      req.destroy();
      reject(new Error('Request timed out'));
    });

    req.on('error', reject);
    req.write(postData);
    req.end();
  });
}

function normalizeElement(el) {
  const lat = el.lat || (el.center && el.center.lat);
  const lng = el.lon || (el.center && el.center.lon);
  if (!lat || !lng) return null;

  const tags = el.tags || {};

  // Extract name
  let name = tags.name || tags['name:uz'] || tags['name:uz-Cyrl'] || tags['name:ru'] || tags['name:en'];
  if (!name || name.trim() === '') {
    if (tags.amenity === 'prayer_room') {
      name = 'Namozxona';
    } else {
      name = 'Jome Masjidi';
    }
  }
  name = name.trim();

  // Extract alt_name
  const altName = tags.alt_name || tags['name:ar'] || tags['name:en'] || tags['name:ru'] || null;

  // Address parts
  const street = tags['addr:street'] || '';
  const housenumber = tags['addr:housenumber'] || '';
  const city = tags['addr:city'] || tags['addr:district'] || tags['addr:subdistrict'] || '';
  const country = tags['addr:country'] || "O'zbekiston";
  
  let address = [street, housenumber, city, country].filter(Boolean).join(', ');
  if (!address) {
    address = "O'zbekiston";
  }

  // Type classification
  const isMusalla = tags.amenity === 'prayer_room' || 
                    tags.building === 'room' || 
                    tags.description?.toLowerCase().includes('musalla') || 
                    tags.name?.toLowerCase().includes('musalla') || 
                    tags.name?.toLowerCase().includes('namozxona');

  const type = isMusalla ? 'musalla' : 'masjid';

  // Amenities
  const hasWheelchair = tags.wheelchair === 'yes' || tags.wheelchair === 'limited';
  const hasWomen = tags.female === 'yes' || tags.women === 'yes' || tags['female:prayer_room'] === 'yes';
  const hasWuduMen = true;
  const hasWuduWomen = tags['female:wudu'] === 'yes' || tags.female === 'yes';
  const hasJuma = !isMusalla;
  const hasParking = tags.parking === 'yes';

  // Photo
  const photoUrl = tags.image || (tags.wikimedia_commons ? `https://commons.wikimedia.org/wiki/Special:FilePath/${encodeURIComponent(tags.wikimedia_commons.replace('File:', ''))}` : null);

  return {
    osm_id: el.id,
    name: name.slice(0, 255),
    alt_name: altName ? altName.slice(0, 255) : null,
    address: address.slice(0, 500),
    city: city ? city.slice(0, 100) : "O'zbekiston",
    country: "O'zbekiston",
    type,
    lat,
    lng,
    has_wudu_men: hasWuduMen,
    has_wudu_women: hasWuduWomen,
    has_women_prayer_area: hasWomen,
    has_juma: hasJuma,
    has_wheelchair_access: hasWheelchair,
    has_parking: hasParking,
    photo_url: photoUrl,
    status: 'approved',
    verified_count: 5
  };
}

async function run() {
  const elements = await fetchFromOverpass();
  console.log(`Processing ${elements.length} OSM elements...`);

  const mosquesMap = new Map();
  for (const el of elements) {
    const item = normalizeElement(el);
    if (item && item.osm_id) {
      // deduplicate by osm_id
      mosquesMap.set(item.osm_id, item);
    }
  }

  const mosquesList = Array.from(mosquesMap.values());
  console.log(`✓ Cleaned and deduplicated: ${mosquesList.length} mosques and musallas.`);

  // Save to JSON for seeds and in-memory backup
  const jsonPath = path.resolve(__dirname, '../db/uzbekistan_mosques.json');
  fs.writeFileSync(jsonPath, JSON.stringify(mosquesList, null, 2), 'utf-8');
  console.log(`✓ Saved dataset to ${jsonPath} (${(fs.statSync(jsonPath).size / 1024 / 1024).toFixed(2)} MB)`);

  // Connect to Postgres
  if (!connectionString) {
    console.error('No DATABASE_URL available!');
    return;
  }

  const pool = new Pool({
    connectionString,
    ssl: { rejectUnauthorized: false }
  });

  try {
    const client = await pool.connect();
    console.log('✓ Connected to PostgreSQL Neon PostGIS!');

    // 1. Remove old fake dummy seeds
    console.log('Deleting old fake/seed mosques from database...');
    const delRes = await client.query(`
      DELETE FROM mosques 
      WHERE osm_id IS NULL 
         OR id::text LIKE '00000000-0000-%'
         OR name IN ('Al-Masjid an-Nabawi', 'Al-Masjid al-Haram', 'Tashkent City Mall Musalla', 'Aeroport Musallasi (Terminal 2)');
    `);
    console.log(`✓ Deleted ${delRes.rowCount} old seed mosques.`);

    // 2. Batch insert/upsert real mosques into PostgreSQL
    console.log(`Inserting ${mosquesList.length} real mosques into PostgreSQL...`);
    const batchSize = 100;
    let insertedCount = 0;

    for (let i = 0; i < mosquesList.length; i += batchSize) {
      const batch = mosquesList.slice(i, i + batchSize);
      
      const values = [];
      const placeholders = [];
      let paramIndex = 1;

      for (const m of batch) {
        placeholders.push(`(
          gen_random_uuid(), $${paramIndex++}, $${paramIndex++}, $${paramIndex++}, $${paramIndex++},
          $${paramIndex++}, $${paramIndex++}, $${paramIndex++},
          ST_SetSRID(ST_MakePoint($${paramIndex++}, $${paramIndex++}), 4326),
          $${paramIndex++}, $${paramIndex++}, $${paramIndex++}, $${paramIndex++},
          $${paramIndex++}, $${paramIndex++}, $${paramIndex++}, $${paramIndex++}, $${paramIndex++}
        )`);

        values.push(
          m.osm_id,
          m.name,
          m.alt_name,
          m.address,
          m.city,
          m.country,
          m.type,
          m.lng,
          m.lat,
          m.has_wudu_men,
          m.has_wudu_women,
          m.has_women_prayer_area,
          m.has_juma,
          m.has_wheelchair_access,
          m.has_parking,
          m.photo_url,
          m.status,
          m.verified_count
        );
      }

      const sql = `
        INSERT INTO mosques (
          id, osm_id, name, alt_name, address, city, country, type,
          location,
          has_wudu_men, has_wudu_women, has_women_prayer_area,
          has_juma, has_wheelchair_access, has_parking, photo_url, status, verified_count
        ) VALUES ${placeholders.join(', ')}
        ON CONFLICT (osm_id) DO UPDATE SET
          name = EXCLUDED.name,
          alt_name = EXCLUDED.alt_name,
          address = EXCLUDED.address,
          city = EXCLUDED.city,
          country = EXCLUDED.country,
          type = EXCLUDED.type,
          location = EXCLUDED.location,
          has_wudu_men = EXCLUDED.has_wudu_men,
          has_wudu_women = EXCLUDED.has_wudu_women,
          has_women_prayer_area = EXCLUDED.has_women_prayer_area,
          has_juma = EXCLUDED.has_juma,
          has_wheelchair_access = EXCLUDED.has_wheelchair_access,
          has_parking = EXCLUDED.has_parking,
          photo_url = EXCLUDED.photo_url,
          status = EXCLUDED.status,
          updated_at = NOW();
      `;

      await client.query(sql, values);
      insertedCount += batch.length;
      if (insertedCount % 500 === 0 || insertedCount === mosquesList.length) {
        console.log(`Progress: ${insertedCount} / ${mosquesList.length} mosques processed.`);
      }
    }

    const totalCountRes = await client.query('SELECT count(*) FROM mosques');
    console.log(`✓ ALL DONE! Total mosques currently in database: ${totalCountRes.rows[0].count}`);

    client.release();
  } catch (err) {
    console.error('Database insertion error:', err);
  } finally {
    await pool.end();
  }
}

run().catch(console.error);
