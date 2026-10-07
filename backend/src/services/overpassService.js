const config = require('../config');

class OverpassService {
  constructor() {
    this.apiUrl = config.overpassApiUrl;
  }

  /**
   * Fetch Muslim places of worship within a radius around lat, lng
   * @param {number} lat 
   * @param {number} lng 
   * @param {number} radiusMeters 
   */
  async fetchNearby(lat, lng, radiusMeters = 5000) {
    // Validate lat, lng, radius
    if (isNaN(lat) || isNaN(lng) || isNaN(radiusMeters)) {
      throw new Error('Invalid coordinates or radius');
    }

    const safeRadius = Math.min(Math.max(radiusMeters, 500), 25000); // Between 500m and 25km

    // Overpass QL Query
    const query = `
      [out:json][timeout:25];
      (
        node["amenity"="place_of_worship"]["religion"="muslim"](around:${safeRadius},${lat},${lng});
        way["amenity"="place_of_worship"]["religion"="muslim"](around:${safeRadius},${lat},${lng});
        relation["amenity"="place_of_worship"]["religion"="muslim"](around:${safeRadius},${lat},${lng});
      );
      out center tags;
    `;

    const controller = new AbortController();
    const timeout = setTimeout(() => controller.abort(), 20000);

    try {
      const response = await fetch(this.apiUrl, {
        method: 'POST',
        headers: {
          'Content-Type': 'application/x-www-form-urlencoded',
          'User-Agent': 'GlobalMasjidLocator/1.0'
        },
        body: `data=${encodeURIComponent(query)}`,
        signal: controller.signal
      });

      clearTimeout(timeout);

      if (!response.ok) {
        throw new Error(`Overpass API responded with HTTP ${response.status}`);
      }

      const data = await response.json();
      return this._mapElements(data.elements || []);
    } catch (err) {
      clearTimeout(timeout);
      console.warn(`Overpass fetch warning: ${err.message}`);
      return [];
    }
  }

  _mapElements(elements) {
    return elements.map(el => {
      const lat = el.lat || (el.center && el.center.lat);
      const lng = el.lon || (el.center && el.center.lon);
      const tags = el.tags || {};

      const name = tags.name || tags['name:en'] || tags['name:uz'] || tags['name:ru'] || 'Masjid / Musalla';
      const altName = tags.alt_name || tags['name:ar'] || tags['name:en'] || null;

      const street = tags['addr:street'] || '';
      const housenumber = tags['addr:housenumber'] || '';
      const city = tags['addr:city'] || '';
      const country = tags['addr:country'] || '';
      const address = [street, housenumber, city, country].filter(Boolean).join(', ') || tags.address || '';

      const isMusalla = tags.building === 'room' || tags.description?.toLowerCase().includes('musalla') || tags.name?.toLowerCase().includes('musalla') || tags.name?.toLowerCase().includes('namozxona');

      const hasWheelchair = tags.wheelchair === 'yes' || tags.wheelchair === 'limited';
      const hasWomen = tags['female'] === 'yes' || tags['women'] === 'yes' || tags['female:prayer_room'] === 'yes';
      const hasWudu = tags['wudu'] === 'yes' || tags['toilets:wheelchair'] === 'yes' || true;

      return {
        id: crypto.randomUUID(),
        osm_id: el.id,
        name,
        alt_name: altName,
        address,
        city,
        country,
        type: isMusalla ? 'musalla' : 'masjid',
        lat,
        lng,
        has_wudu_men: hasWudu,
        has_wudu_women: hasWomen,
        has_women_prayer_area: hasWomen,
        has_juma: !isMusalla,
        has_wheelchair_access: hasWheelchair,
        has_parking: tags.parking === 'yes',
        photo_url: tags.image || tags['wikimedia_commons'] ? null : null,
        status: 'approved',
        verified_count: 5
      };
    }).filter(item => item.lat && item.lng);
  }
}

module.exports = new OverpassService();
