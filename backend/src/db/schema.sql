-- Enable PostGIS spatial extension
CREATE EXTENSION IF NOT EXISTS postgis;
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- Mosques & Musallas Master Table
CREATE TABLE IF NOT EXISTS mosques (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    osm_id BIGINT UNIQUE,
    name VARCHAR(255) NOT NULL,
    alt_name VARCHAR(255),
    address TEXT,
    city VARCHAR(100),
    country VARCHAR(100),
    type VARCHAR(50) NOT NULL DEFAULT 'masjid' CHECK (type IN ('masjid', 'musalla')),
    location GEOGRAPHY(Point, 4326) NOT NULL,
    has_wudu_men BOOLEAN DEFAULT true,
    has_wudu_women BOOLEAN DEFAULT false,
    has_women_prayer_area BOOLEAN DEFAULT false,
    has_juma BOOLEAN DEFAULT true,
    has_wheelchair_access BOOLEAN DEFAULT false,
    has_parking BOOLEAN DEFAULT false,
    photo_url TEXT,
    status VARCHAR(20) DEFAULT 'approved' CHECK (status IN ('pending', 'approved', 'rejected')),
    verified_count INT DEFAULT 0,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Geofazoviy Spatial Index (GIST) for ultra-fast spatial search
CREATE INDEX IF NOT EXISTS idx_mosques_location ON mosques USING GIST (location);
CREATE INDEX IF NOT EXISTS idx_mosques_status ON mosques (status);
CREATE INDEX IF NOT EXISTS idx_mosques_type ON mosques (type);

-- User Reports / Issues on Mosques
CREATE TABLE IF NOT EXISTS mosque_reports (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    mosque_id UUID NOT NULL REFERENCES mosques(id) ON DELETE CASCADE,
    reason VARCHAR(100) NOT NULL,
    details TEXT,
    status VARCHAR(20) DEFAULT 'open' CHECK (status IN ('open', 'reviewed', 'resolved')),
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_mosque_reports_mosque_id ON mosque_reports(mosque_id);
