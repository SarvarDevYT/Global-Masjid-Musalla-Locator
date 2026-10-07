const https = require('https');
const { Pool } = require('pg');
require('dotenv').config({ path: require('path').resolve(__dirname, '../../.env') });

const connectionString = process.env.DATABASE_URL_POOLED || process.env.DATABASE_URL;

console.log('Using DB connection string...');

async function fetchUzbekistanMosques() {
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
    'https://overpass-api.de/api/interpreter',
    'https://lz4.overpass-api.de/api/interpreter',
    'https://overpass.kumi.systems/api/interpreter'
  ];

  for (const endpoint of endpoints) {
    console.log(`Trying Overpass endpoint: ${endpoint}...`);
    try {
      const elements = await queryEndpoint(endpoint, query);
      if (elements && elements.length > 0) {
        console.log(`Found ${elements.length} mosques/musallas in Uzbekistan!`);
        return elements;
      }
    } catch (err) {
      console.warn(`Failed on ${endpoint}: ${err.message}`);
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
        'User-Agent': 'GlobalMasjidLocator/1.0 (UzbekistanScan)'
      },
      timeout: 120000
    };

    const req = https.request(options, (res) => {
      let data = '';
      res.on('data', chunk => data += chunk);
      res.on('end', () => {
        if (res.statusCode !== 200) {
          return reject(new Error(`HTTP ${res.statusCode}: ${data.slice(0, 150)}`));
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

async function main() {
  const elements = await fetchUzbekistanMosques();
  console.log(`Successfully received ${elements.length} elements from OpenStreetMap.`);
}

main().catch(console.error);
