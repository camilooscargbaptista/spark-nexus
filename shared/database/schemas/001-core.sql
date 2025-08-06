-- Spark Nexus Core Database Schema
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- Organizations (Tenants)
CREATE TABLE organizations (
    id UUID DEFAULT uuid_generate_v4() PRIMARY KEY,
    slug VARCHAR(100) UNIQUE NOT NULL,
    name VARCHAR(255) NOT NULL,
    domain VARCHAR(255),
    logo_url VARCHAR(500),
    settings JSONB DEFAULT '{}',
    status VARCHAR(50) DEFAULT 'active',
    trial_ends_at TIMESTAMP,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Users
CREATE TABLE users (
    id UUID DEFAULT uuid_generate_v4() PRIMARY KEY,
    organization_id UUID REFERENCES organizations(id) ON DELETE CASCADE,
    email VARCHAR(255) UNIQUE NOT NULL,
    password_hash VARCHAR(255) NOT NULL,
    first_name VARCHAR(100),
    last_name VARCHAR(100),
    role VARCHAR(50) DEFAULT 'member',
    is_active BOOLEAN DEFAULT true,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Modules Available
CREATE TABLE modules (
    id VARCHAR(50) PRIMARY KEY,
    name VARCHAR(100) NOT NULL,
    description TEXT,
    base_price DECIMAL(10,2),
    pricing_model VARCHAR(50) DEFAULT 'usage',
    is_active BOOLEAN DEFAULT true,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Organization Modules (Which modules each org has)
CREATE TABLE organization_modules (
    id UUID DEFAULT uuid_generate_v4() PRIMARY KEY,
    organization_id UUID REFERENCES organizations(id) ON DELETE CASCADE,
    module_id VARCHAR(50) REFERENCES modules(id),
    status VARCHAR(50) DEFAULT 'active',
    settings JSONB DEFAULT '{}',
    usage_limits JSONB DEFAULT '{}',
    usage_current JSONB DEFAULT '{}',
    activated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    UNIQUE(organization_id, module_id)
);

-- API Keys
CREATE TABLE api_keys (
    id UUID DEFAULT uuid_generate_v4() PRIMARY KEY,
    organization_id UUID REFERENCES organizations(id) ON DELETE CASCADE,
    module_id VARCHAR(50),
    key_hash VARCHAR(255) UNIQUE NOT NULL,
    key_preview VARCHAR(20),
    name VARCHAR(100),
    rate_limit INTEGER DEFAULT 1000,
    is_active BOOLEAN DEFAULT true,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Insert default modules
INSERT INTO modules (id, name, description, base_price, pricing_model) VALUES
('email-validator', 'Email Validator Pro', 'Validate and enrich emails with AI', 49.00, 'usage'),
('crm-connector', 'CRM Connector', 'Connect with major CRMs', 29.00, 'flat'),
('lead-scorer', 'Lead Scorer AI', 'AI-powered lead scoring', 79.00, 'usage');

-- Insert test organization and user
INSERT INTO organizations (slug, name, status) VALUES
('demo-company', 'Demo Company', 'active');

INSERT INTO users (organization_id, email, password_hash, first_name, last_name, role)
SELECT id, 'admin@demo.com', '$2b$10$YKx5D7tGc.x5D7tGc.x5D7tGc', 'Admin', 'User', 'owner'
FROM organizations WHERE slug = 'demo-company';

-- Create indexes
CREATE INDEX idx_organizations_slug ON organizations(slug);
CREATE INDEX idx_users_email ON users(email);
CREATE INDEX idx_api_keys_hash ON api_keys(key_hash);