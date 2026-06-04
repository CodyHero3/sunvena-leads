-- Sunvena Leads Database Schema
-- PostgreSQL

CREATE TABLE IF NOT EXISTS leads (
    id SERIAL PRIMARY KEY,
    source VARCHAR(100) NOT NULL,  -- 'facebook', 'twitter', 'zillow', 'county_clerk', etc.
    source_url TEXT,
    source_id VARCHAR(255) UNIQUE,  -- Platform-specific ID for deduplication
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    status VARCHAR(50) DEFAULT 'new',  -- new, contacted, interested, booked, skip, invalid, do_not_call
    lead_score INT DEFAULT 0,  -- 1-100 based on qualification
    lead_quality VARCHAR(20),  -- high, medium, low
    primary_intent VARCHAR(100),  -- 'roof_replacement', 'ac_replacement', 'solar', 'emergency'
    notes TEXT
);

CREATE TABLE IF NOT EXISTS contacts (
    id SERIAL PRIMARY KEY,
    lead_id INT NOT NULL REFERENCES leads(id) ON DELETE CASCADE,
    first_name VARCHAR(100),
    last_name VARCHAR(100),
    full_name VARCHAR(255),
    phone_number VARCHAR(20) UNIQUE,
    email VARCHAR(100) UNIQUE,
    address VARCHAR(255),
    city VARCHAR(100),
    state VARCHAR(2),
    zip_code VARCHAR(10),
    social_media_handles JSONB,  -- {facebook: 'url', twitter: 'handle', tiktok: 'username'}
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE IF NOT EXISTS properties (
    id SERIAL PRIMARY KEY,
    lead_id INT NOT NULL REFERENCES leads(id) ON DELETE CASCADE,
    address VARCHAR(255),
    city VARCHAR(100),
    state VARCHAR(2),
    zip_code VARCHAR(10),
    county VARCHAR(100),
    latitude DECIMAL(10, 8),
    longitude DECIMAL(11, 8),
    property_type VARCHAR(50),  -- 'single_family', 'multi_family', 'commercial'
    year_built INT,
    square_feet INT,
    roof_age INT,  -- Estimated years since replacement
    roof_type VARCHAR(50),  -- 'asphalt', 'metal', 'tile', 'flat'
    ac_age INT,  -- Estimated years since replacement
    ac_type VARCHAR(50),  -- 'central', 'window', 'heat_pump'
    solar_potential INT,  -- 1-100 score
    has_pool BOOLEAN DEFAULT false,
    has_rv_space BOOLEAN DEFAULT false,
    has_jacuzzi BOOLEAN DEFAULT false,
    estimated_electricity_bill INT,  -- Monthly in dollars
    last_permit_date DATE,
    last_permit_type VARCHAR(100),  -- 'roof', 'hvac', 'solar', 'electrical'
    weather_damage_history TEXT,  -- Storm damage, hail, etc.
    property_value INT,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE IF NOT EXISTS call_logs (
    id SERIAL PRIMARY KEY,
    lead_id INT NOT NULL REFERENCES leads(id) ON DELETE CASCADE,
    call_type VARCHAR(50),  -- 'voice_agent', 'manual', 'sms'
    call_timestamp TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    duration_seconds INT,
    call_status VARCHAR(50),  -- 'completed', 'no_answer', 'voicemail', 'failed', 'rejected', 'do_not_call'
    transcript TEXT,  -- AI voice call transcript
    result VARCHAR(255),  -- 'interested', 'not_interested', 'call_back_later', 'scheduled', 'wrong_number'
    notes TEXT,
    agent_notes TEXT
);

CREATE TABLE IF NOT EXISTS appointments (
    id SERIAL PRIMARY KEY,
    lead_id INT NOT NULL REFERENCES leads(id) ON DELETE CASCADE,
    google_event_id VARCHAR(255) UNIQUE,
    appointment_time TIMESTAMP NOT NULL,
    duration_minutes INT DEFAULT 30,
    title VARCHAR(255),
    description TEXT,
    sunvena_representative VARCHAR(100),
    status VARCHAR(50) DEFAULT 'scheduled',  -- 'scheduled', 'confirmed', 'completed', 'cancelled', 'no_show'
    appointment_type VARCHAR(50),  -- 'consultation', 'site_visit', 'estimate'
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE IF NOT EXISTS scraping_jobs (
    id SERIAL PRIMARY KEY,
    source VARCHAR(100) NOT NULL,
    status VARCHAR(50) DEFAULT 'pending',  -- 'pending', 'running', 'completed', 'failed'
    started_at TIMESTAMP,
    completed_at TIMESTAMP,
    leads_found INT DEFAULT 0,
    leads_new INT DEFAULT 0,
    leads_duplicates INT DEFAULT 0,
    error_message TEXT,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE IF NOT EXISTS lead_duplicates (
    id SERIAL PRIMARY KEY,
    lead_id INT NOT NULL REFERENCES leads(id) ON DELETE CASCADE,
    duplicate_of_lead_id INT REFERENCES leads(id),
    phone_number VARCHAR(20),
    email VARCHAR(100),
    similarity_score DECIMAL(3, 2),  -- 0.0-1.0
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE IF NOT EXISTS source_data (
    id SERIAL PRIMARY KEY,
    lead_id INT NOT NULL REFERENCES leads(id) ON DELETE CASCADE,
    source VARCHAR(100),
    source_url TEXT,
    raw_data JSONB,  -- Store raw scraped data
    extraction_metadata JSONB,  -- How data was extracted
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE IF NOT EXISTS lead_interactions (
    id SERIAL PRIMARY KEY,
    lead_id INT NOT NULL REFERENCES leads(id) ON DELETE CASCADE,
    interaction_type VARCHAR(50),  -- 'call', 'sms', 'email', 'appointment', 'social_message'
    interaction_timestamp TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    details TEXT,
    outcome VARCHAR(100)
);

-- Indexes for performance
CREATE INDEX idx_leads_status ON leads(status);
CREATE INDEX idx_leads_source ON leads(source);
CREATE INDEX idx_leads_score ON leads(lead_score DESC);
CREATE INDEX idx_leads_created_at ON leads(created_at DESC);
CREATE INDEX idx_contacts_phone ON contacts(phone_number);
CREATE INDEX idx_contacts_email ON contacts(email);
CREATE INDEX idx_contacts_lead_id ON contacts(lead_id);
CREATE INDEX idx_properties_city ON properties(city);
CREATE INDEX idx_properties_zip ON properties(zip_code);
CREATE INDEX idx_call_logs_lead_id ON call_logs(lead_id);
CREATE INDEX idx_call_logs_timestamp ON call_logs(call_timestamp DESC);
CREATE INDEX idx_appointments_lead_id ON appointments(lead_id);
CREATE INDEX idx_appointments_time ON appointments(appointment_time);
CREATE INDEX idx_source_data_lead_id ON source_data(lead_id);
