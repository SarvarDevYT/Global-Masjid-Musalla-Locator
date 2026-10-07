const test = require('node:test');
const assert = require('node:assert');
const { calculateHaversineDistance, dbManager } = require('../src/db/database');

test('Haversine distance calculation is accurate', () => {
  // Tashkent Hazrati Imom (41.3381, 69.2415) to Minor Mosque (41.3283, 69.2817) ~3.5km
  const dist = calculateHaversineDistance(41.3381, 69.2415, 41.3283, 69.2817);
  assert.ok(dist > 3000 && dist < 4200, `Expected distance around 3500m, got ${dist}`);
});

test('Nearby mosques are returned and sorted in ascending order of distance', async () => {
  // Search near Tashkent center (41.3110, 69.2405) with 15km radius
  const results = await dbManager.findNearby({
    lat: 41.3110,
    lng: 69.2405,
    radiusMeters: 15000,
    status: 'approved'
  });

  assert.ok(results.length >= 3, `Expected at least 3 mosques in Tashkent, got ${results.length}`);
  
  // Verify ascending order
  for (let i = 0; i < results.length - 1; i++) {
    assert.ok(
      results[i].distance_meters <= results[i + 1].distance_meters,
      `Results not sorted by distance: ${results[i].distance_meters} > ${results[i + 1].distance_meters}`
    );
  }
});

test('Filter by amenities works correctly', async () => {
  const womenPrayerResults = await dbManager.findNearby({
    lat: 41.3110,
    lng: 69.2405,
    radiusMeters: 20000,
    amenities: { has_women_prayer_area: true }
  });

  for (const item of womenPrayerResults) {
    assert.strictEqual(item.has_women_prayer_area, true);
  }
});

test('Crowdsourcing contribution saves with pending status', async () => {
  const newMosque = await dbManager.addContribution({
    name: 'Yangi Chilonzor Namozxonasi',
    address: 'Chilonzor 9-mavze, Toshkent',
    city: 'Toshkent',
    country: "O'zbekiston",
    type: 'musalla',
    lat: 41.2750,
    lng: 69.2010,
    has_wudu_men: true,
    has_wudu_women: true,
    has_women_prayer_area: true,
    has_juma: false,
    has_wheelchair_access: true,
    has_parking: true
  });

  assert.strictEqual(newMosque.status, 'pending');
  assert.strictEqual(newMosque.name, 'Yangi Chilonzor Namozxonasi');

  // Verify it appears in pending query
  const pending = await dbManager.findNearby({
    lat: 0,
    lng: 0,
    radiusMeters: 40000000,
    status: 'pending'
  });

  const found = pending.find(p => p.id === newMosque.id);
  assert.ok(found, 'Pending mosque should be retrieved in pending query');
});
