const { Pool } = require('pg');
const config = require('../config');
const { SEED_MOSQUES } = require('./seeds');

// Haversine distance formula in meters
function calculateHaversineDistance(lat1, lon1, lat2, lon2) {
  const R = 6371000; // Earth's radius in meters
  const dLat = (lat2 - lat1) * (Math.PI / 180);
  const dLon = (lon2 - lon1) * (Math.PI / 180);
  const a =
    Math.sin(dLat / 2) * Math.sin(dLat / 2) +
    Math.cos(lat1 * (Math.PI / 180)) *
      Math.cos(lat2 * (Math.PI / 180)) *
      Math.sin(dLon / 2) *
      Math.sin(dLon / 2);
  const c = 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1 - a));
  return Math.round(R * c);
}

class DatabaseManager {
  constructor() {
    this.isPostgresConnected = false;
    this.pool = null;
    this.memoryMosques = SEED_MOSQUES.map(m => ({
      id: m.id || `osm-${m.osm_id}`,
      ...m
    }));
    this.memoryReports = [];
  }

  async initialize() {
    try {
      if (config.db.connectionString || (config.db.host && config.db.database)) {
        this.pool = new Pool({
          connectionString: config.db.pooledConnectionString,
          host: config.db.host,
          port: config.db.port,
          database: config.db.database,
          user: config.db.user,
          password: config.db.password,
          ssl: config.db.ssl,
          // Serverless: har bir instansiya uchun kichik pool (Neon pooler bilan)
          max: config.isProd ? 3 : 10,
          idleTimeoutMillis: 10000,
          connectionTimeoutMillis: 5000
        });

        // Test connection
        const client = await this.pool.connect();
        await client.query('SELECT 1');
        client.release();
        this.isPostgresConnected = true;
        console.log('✓ PostgreSQL connected with PostGIS support');
        await this._initPostgresTables();
      }
    } catch (err) {
      this.isPostgresConnected = false;
      console.log('ℹ PostgreSQL not reachable. Running on high-speed In-Memory Spatial Store with seed data.');
    }
  }

  async _initPostgresTables() {
    if (!this.isPostgresConnected) return;
    try {
      await this.pool.query('CREATE EXTENSION IF NOT EXISTS postgis;');
      await this.pool.query(`
        CREATE TABLE IF NOT EXISTS mosques (
          id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
          osm_id BIGINT UNIQUE,
          name VARCHAR(255) NOT NULL,
          alt_name VARCHAR(255),
          address TEXT,
          city VARCHAR(100),
          country VARCHAR(100),
          type VARCHAR(50) NOT NULL DEFAULT 'masjid',
          location GEOGRAPHY(Point, 4326) NOT NULL,
          has_wudu_men BOOLEAN DEFAULT true,
          has_wudu_women BOOLEAN DEFAULT false,
          has_women_prayer_area BOOLEAN DEFAULT false,
          has_juma BOOLEAN DEFAULT true,
          has_wheelchair_access BOOLEAN DEFAULT false,
          has_parking BOOLEAN DEFAULT false,
          photo_url TEXT,
          status VARCHAR(20) DEFAULT 'approved',
          verified_count INT DEFAULT 0,
          created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
          updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
        );
        CREATE INDEX IF NOT EXISTS idx_mosques_location ON mosques USING GIST (location);
      `);
      // Seed if empty
      const countRes = await this.pool.query('SELECT COUNT(*) FROM mosques');
      if (parseInt(countRes.rows[0].count, 10) === 0) {
        for (const m of SEED_MOSQUES) {
          await this.pool.query(
            `INSERT INTO mosques (
              id, osm_id, name, alt_name, address, city, country, type,
              location, has_wudu_men, has_wudu_women, has_women_prayer_area,
              has_juma, has_wheelchair_access, has_parking, photo_url, status, verified_count
            ) VALUES (
              gen_random_uuid(), $1, $2, $3, $4, $5, $6, $7,
              ST_SetSRID(ST_MakePoint($8, $9), 4326),
              $10, $11, $12, $13, $14, $15, $16, $17, $18
            ) ON CONFLICT (osm_id) DO NOTHING`,
            [
              m.osm_id, m.name, m.alt_name, m.address, m.city, m.country, m.type,
              m.lng, m.lat,
              m.has_wudu_men, m.has_wudu_women, m.has_women_prayer_area,
              m.has_juma, m.has_wheelchair_access, m.has_parking,
              m.photo_url, m.status || 'approved', m.verified_count || 1
            ]
          );
        }
      }
    } catch (err) {
      console.error('Postgres init error:', err.message);
    }
  }

  async findNearby({ lat, lng, radiusMeters = 10000, type, amenities = {}, q, status = 'approved', limit = 50, offset = 0 }) {
    if (this.isPostgresConnected) {
      return this._postgresFindNearby({ lat, lng, radiusMeters, type, amenities, q, status, limit, offset });
    }
    return this._memoryFindNearby({ lat, lng, radiusMeters, type, amenities, q, status, limit, offset });
  }

  async _postgresFindNearby({ lat, lng, radiusMeters, type, amenities, q, status, limit, offset }) {
    const params = [lng, lat, radiusMeters];
    let query = `
      SELECT 
        id, osm_id, name, alt_name, address, city, country, type,
        ST_Y(location::geometry) as lat,
        ST_X(location::geometry) as lng,
        has_wudu_men, has_wudu_women, has_women_prayer_area,
        has_juma, has_wheelchair_access, has_parking, photo_url, status, verified_count,
        ROUND(ST_Distance(location, ST_SetSRID(ST_MakePoint($1, $2), 4326)::geography)) AS distance_meters
      FROM mosques
      WHERE ST_DWithin(location, ST_SetSRID(ST_MakePoint($1, $2), 4326)::geography, $3)
        AND status = $4
    `;
    params.push(status);

    if (type) {
      params.push(type);
      query += ` AND type = $${params.length}`;
    }
    if (amenities.has_wudu_women) {
      query += ` AND has_wudu_women = true`;
    }
    if (amenities.has_women_prayer_area) {
      query += ` AND has_women_prayer_area = true`;
    }
    if (amenities.has_juma) {
      query += ` AND has_juma = true`;
    }
    if (amenities.has_wheelchair_access) {
      query += ` AND has_wheelchair_access = true`;
    }
    if (amenities.has_parking) {
      query += ` AND has_parking = true`;
    }
    if (q) {
      params.push(`%${q}%`);
      query += ` AND (name ILIKE $${params.length} OR alt_name ILIKE $${params.length} OR address ILIKE $${params.length})`;
    }

    query += ` ORDER BY distance_meters ASC LIMIT $${params.length + 1} OFFSET $${params.length + 2}`;
    params.push(limit, offset);

    const res = await this.pool.query(query, params);
    return res.rows.map(r => ({
      ...r,
      lat: parseFloat(r.lat),
      lng: parseFloat(r.lng),
      distance_meters: parseInt(r.distance_meters, 10)
    }));
  }

  async _memoryFindNearby({ lat, lng, radiusMeters, type, amenities, q, status, limit, offset }) {
    let results = this.memoryMosques.filter(m => {
      if (status && m.status !== status) return false;
      if (type && m.type !== type) return false;
      if (amenities.has_wudu_women && !m.has_wudu_women) return false;
      if (amenities.has_women_prayer_area && !m.has_women_prayer_area) return false;
      if (amenities.has_juma && !m.has_juma) return false;
      if (amenities.has_wheelchair_access && !m.has_wheelchair_access) return false;
      if (amenities.has_parking && !m.has_parking) return false;
      if (q) {
        const queryLower = q.toLowerCase();
        const matchName = m.name?.toLowerCase().includes(queryLower);
        const matchAlt = m.alt_name?.toLowerCase().includes(queryLower);
        const matchAddress = m.address?.toLowerCase().includes(queryLower);
        if (!matchName && !matchAlt && !matchAddress) return false;
      }
      return true;
    });

    results = results.map(m => {
      const distance_meters = calculateHaversineDistance(lat, lng, m.lat, m.lng);
      return {
        ...m,
        distance_meters
      };
    });

    // Filter within radius
    results = results.filter(m => m.distance_meters <= radiusMeters);

    // Ascending sort by distance
    results.sort((a, b) => a.distance_meters - b.distance_meters);

    return results.slice(offset, offset + limit);
  }

  // onlyApproved: ommaviy API faqat tasdiqlangan joylarni qaytaradi (pending/rejected yashirin)
  async getById(id, { onlyApproved = false } = {}) {
    if (this.isPostgresConnected) {
      const res = await this.pool.query(
        `SELECT id, osm_id, name, alt_name, address, city, country, type,
                ST_Y(location::geometry) as lat, ST_X(location::geometry) as lng,
                has_wudu_men, has_wudu_women, has_women_prayer_area,
                has_juma, has_wheelchair_access, has_parking, photo_url, status, verified_count
         FROM mosques WHERE id = $1`,
        [id]
      );
      if (res.rows.length === 0) return null;
      const r = res.rows[0];
      if (onlyApproved && r.status !== 'approved') return null;
      return { ...r, lat: parseFloat(r.lat), lng: parseFloat(r.lng) };
    }

    const found = this.memoryMosques.find(m => m.id === id) || null;
    if (found && onlyApproved && found.status !== 'approved') return null;
    return found;
  }

  async addContribution(data) {
    const newRecord = {
      id: crypto.randomUUID(),
      osm_id: null,
      name: data.name,
      alt_name: data.alt_name || null,
      address: data.address || '',
      city: data.city || '',
      country: data.country || '',
      type: data.type || 'masjid',
      lat: data.lat,
      lng: data.lng,
      has_wudu_men: !!data.has_wudu_men,
      has_wudu_women: !!data.has_wudu_women,
      has_women_prayer_area: !!data.has_women_prayer_area,
      has_juma: !!data.has_juma,
      has_wheelchair_access: !!data.has_wheelchair_access,
      has_parking: !!data.has_parking,
      photo_url: data.photo_url || null,
      status: 'pending', // Pending moderation
      verified_count: 0,
      created_at: new Date().toISOString()
    };

    if (this.isPostgresConnected) {
      await this.pool.query(
        `INSERT INTO mosques (
          id, name, alt_name, address, city, country, type,
          location, has_wudu_men, has_wudu_women, has_women_prayer_area,
          has_juma, has_wheelchair_access, has_parking, photo_url, status, verified_count
        ) VALUES (
          $1, $2, $3, $4, $5, $6, $7,
          ST_SetSRID(ST_MakePoint($8, $9), 4326),
          $10, $11, $12, $13, $14, $15, $16, $17, $18
        )`,
        [
          newRecord.id, newRecord.name, newRecord.alt_name, newRecord.address,
          newRecord.city, newRecord.country, newRecord.type,
          newRecord.lng, newRecord.lat,
          newRecord.has_wudu_men, newRecord.has_wudu_women, newRecord.has_women_prayer_area,
          newRecord.has_juma, newRecord.has_wheelchair_access, newRecord.has_parking,
          newRecord.photo_url, newRecord.status, newRecord.verified_count
        ]
      );
    } else {
      this.memoryMosques.push(newRecord);
    }

    return newRecord;
  }

  async moderate(id, status) {
    if (!['approved', 'rejected'].includes(status)) {
      throw new Error('Invalid moderation status');
    }

    if (this.isPostgresConnected) {
      const res = await this.pool.query(
        `UPDATE mosques SET status = $1, updated_at = NOW() WHERE id = $2 RETURNING *`,
        [status, id]
      );
      return res.rows[0] || null;
    }

    const item = this.memoryMosques.find(m => m.id === id);
    if (item) {
      item.status = status;
      item.updated_at = new Date().toISOString();
      return item;
    }
    return null;
  }

  async addReport(mosqueId, reason, details) {
    const report = {
      id: crypto.randomUUID(),
      mosque_id: mosqueId,
      reason,
      details: details || '',
      status: 'open',
      created_at: new Date().toISOString()
    };

    if (this.isPostgresConnected) {
      await this.pool.query(
        `INSERT INTO mosque_reports (id, mosque_id, reason, details, status) VALUES ($1, $2, $3, $4, $5)`,
        [report.id, report.mosque_id, report.reason, report.details, report.status]
      );
    } else {
      this.memoryReports.push(report);
    }

    return report;
  }

  async upsertOsmMosques(mosques) {
    let inserted = 0;

    if (this.isPostgresConnected) {
      for (const m of mosques) {
        const res = await this.pool.query(
          `INSERT INTO mosques (
            osm_id, name, alt_name, address, city, country, type, location,
            has_wudu_men, has_wudu_women, has_women_prayer_area, has_juma,
            has_wheelchair_access, has_parking, photo_url, status, verified_count
          ) VALUES (
            $1, $2, $3, $4, $5, $6, $7, ST_SetSRID(ST_MakePoint($8, $9), 4326),
            $10, $11, $12, $13, $14, $15, $16, 'approved', $17
          ) ON CONFLICT (osm_id) DO NOTHING`,
          [
            m.osm_id, String(m.name).slice(0, 255), m.alt_name ? String(m.alt_name).slice(0, 255) : null,
            m.address, m.city ? String(m.city).slice(0, 100) : null,
            m.country ? String(m.country).slice(0, 100) : null, m.type,
            m.lng, m.lat,
            m.has_wudu_men, m.has_wudu_women, m.has_women_prayer_area, m.has_juma,
            m.has_wheelchair_access, m.has_parking, m.photo_url || null, m.verified_count || 0
          ]
        );
        inserted += res.rowCount;
      }
      return inserted;
    }

    for (const m of mosques) {
      const existing = this.memoryMosques.find(item => item.osm_id && item.osm_id === m.osm_id);
      if (!existing) {
        this.memoryMosques.push(m);
        inserted++;
      }
    }
    return inserted;
  }

  // ---------- Admin panel metodlari (barchasi parametrlangan so'rovlar) ----------

  _escapeLike(value) {
    return String(value).replace(/[\\%_]/g, '\\$&');
  }

  async listMosques({ status, q, limit = 50, offset = 0 }) {
    if (this.isPostgresConnected) {
      const params = [];
      let where = 'WHERE 1=1';
      if (status) {
        params.push(status);
        where += ` AND status = $${params.length}`;
      }
      if (q) {
        params.push(`%${this._escapeLike(q)}%`);
        const n = params.length;
        where += ` AND (name ILIKE $${n} OR address ILIKE $${n} OR city ILIKE $${n})`;
      }
      params.push(limit, offset);
      const res = await this.pool.query(
        `SELECT id, name, alt_name, address, city, country, type,
                ST_Y(location::geometry) AS lat, ST_X(location::geometry) AS lng,
                has_wudu_men, has_wudu_women, has_women_prayer_area, has_juma,
                has_wheelchair_access, has_parking, photo_url, status, verified_count, created_at
         FROM mosques ${where}
         ORDER BY created_at DESC
         LIMIT $${params.length - 1} OFFSET $${params.length}`,
        params
      );
      return res.rows.map(r => ({ ...r, lat: parseFloat(r.lat), lng: parseFloat(r.lng) }));
    }

    const qLower = q ? q.toLowerCase() : null;
    return this.memoryMosques
      .filter(m => (!status || m.status === status) &&
        (!qLower || [m.name, m.address, m.city].some(v => (v || '').toLowerCase().includes(qLower))))
      .slice(offset, offset + limit);
  }

  async getStats() {
    if (this.isPostgresConnected) {
      const byStatus = await this.pool.query(
        'SELECT status, COUNT(*)::int AS count FROM mosques GROUP BY status'
      );
      const reports = await this.pool.query(
        "SELECT COUNT(*)::int AS count FROM mosque_reports WHERE status = 'open'"
      );
      const stats = { total: 0, approved: 0, pending: 0, rejected: 0, openReports: reports.rows[0].count };
      for (const row of byStatus.rows) {
        stats[row.status] = row.count;
        stats.total += row.count;
      }
      return stats;
    }

    const stats = { total: this.memoryMosques.length, approved: 0, pending: 0, rejected: 0, openReports: 0 };
    for (const m of this.memoryMosques) stats[m.status] = (stats[m.status] || 0) + 1;
    stats.openReports = this.memoryReports.filter(r => r.status === 'open').length;
    return stats;
  }

  async listReports({ status, limit = 50, offset = 0 }) {
    if (this.isPostgresConnected) {
      const res = await this.pool.query(
        `SELECT r.id, r.mosque_id, r.reason, r.details, r.status, r.created_at, m.name AS mosque_name
         FROM mosque_reports r
         JOIN mosques m ON m.id = r.mosque_id
         WHERE ($1::text IS NULL OR r.status = $1)
         ORDER BY r.created_at DESC
         LIMIT $2 OFFSET $3`,
        [status || null, limit, offset]
      );
      return res.rows;
    }

    return this.memoryReports
      .filter(r => !status || r.status === status)
      .slice(offset, offset + limit)
      .map(r => {
        const m = this.memoryMosques.find(item => item.id === r.mosque_id);
        return { ...r, mosque_name: m ? m.name : null };
      });
  }

  async updateReportStatus(id, status) {
    if (!['reviewed', 'resolved', 'open'].includes(status)) {
      throw new Error('Invalid report status');
    }
    if (this.isPostgresConnected) {
      const res = await this.pool.query(
        'UPDATE mosque_reports SET status = $1 WHERE id = $2 RETURNING id, status',
        [status, id]
      );
      return res.rows[0] || null;
    }
    const item = this.memoryReports.find(r => r.id === id);
    if (item) {
      item.status = status;
      return item;
    }
    return null;
  }
}

const dbManager = new DatabaseManager();

module.exports = {
  dbManager,
  calculateHaversineDistance
};
