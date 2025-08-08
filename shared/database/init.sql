-- ================================================
-- Spark Nexus - Database Initialization
-- ================================================

-- Criar banco para N8N se não existir
CREATE DATABASE n8n;

-- Conectar ao banco principal
\c sparknexus;

-- Habilitar extensões necessárias
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
CREATE EXTENSION IF NOT EXISTS "pgcrypto";
CREATE EXTENSION IF NOT EXISTS "pg_trgm";

-- ================================================
-- SCHEMA: auth (Autenticação)
-- ================================================
CREATE SCHEMA IF NOT EXISTS auth;

-- Tabela de usuários
CREATE TABLE IF NOT EXISTS auth.users (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    email VARCHAR(255) UNIQUE NOT NULL,
    password_hash VARCHAR(255) NOT NULL,
    first_name VARCHAR(100) NOT NULL,
    last_name VARCHAR(100) NOT NULL,
    cpf_cnpj VARCHAR(20) UNIQUE NOT NULL,
    phone VARCHAR(20) NOT NULL,
    company VARCHAR(255) NOT NULL,
    email_verified BOOLEAN DEFAULT FALSE,
    phone_verified BOOLEAN DEFAULT FALSE,
    email_verification_token VARCHAR(100),
    phone_verification_token VARCHAR(6),
    email_token_expires TIMESTAMP,
    phone_token_expires TIMESTAMP,
    is_active BOOLEAN DEFAULT TRUE,
    is_admin BOOLEAN DEFAULT FALSE,
    last_login TIMESTAMP,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Tabela de sessões
CREATE TABLE IF NOT EXISTS auth.sessions (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    token VARCHAR(500) NOT NULL,
    ip_address VARCHAR(45),
    user_agent TEXT,
    expires_at TIMESTAMP NOT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Tabela de tentativas de login
CREATE TABLE IF NOT EXISTS auth.login_attempts (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    email VARCHAR(255) NOT NULL,
    ip_address VARCHAR(45),
    success BOOLEAN DEFAULT FALSE,
    attempted_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- ================================================
-- SCHEMA: tenant (Multi-tenancy)
-- ================================================
CREATE SCHEMA IF NOT EXISTS tenant;

-- Tabela de organizações
CREATE TABLE IF NOT EXISTS tenant.organizations (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    name VARCHAR(255) NOT NULL,
    slug VARCHAR(255) UNIQUE NOT NULL,
    cnpj VARCHAR(20),
    plan VARCHAR(50) DEFAULT 'free',
    is_active BOOLEAN DEFAULT TRUE,
    settings JSONB DEFAULT '{}',
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Tabela de membros da organização
CREATE TABLE IF NOT EXISTS tenant.organization_members (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    organization_id UUID NOT NULL REFERENCES tenant.organizations(id) ON DELETE CASCADE,
    user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    role VARCHAR(50) DEFAULT 'member',
    joined_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    UNIQUE(organization_id, user_id)
);

-- ================================================
-- SCHEMA: email_validator (Módulo de validação)
-- ================================================
CREATE SCHEMA IF NOT EXISTS email_validator;

-- Tabela de jobs de validação
CREATE TABLE IF NOT EXISTS email_validator.validation_jobs (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    organization_id UUID NOT NULL REFERENCES tenant.organizations(id),
    user_id UUID NOT NULL REFERENCES auth.users(id),
    status VARCHAR(50) DEFAULT 'pending',
    total_emails INTEGER DEFAULT 0,
    processed_emails INTEGER DEFAULT 0,
    valid_emails INTEGER DEFAULT 0,
    invalid_emails INTEGER DEFAULT 0,
    file_name VARCHAR(255),
    results_file VARCHAR(255),
    started_at TIMESTAMP,
    completed_at TIMESTAMP,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Tabela de resultados de validação
CREATE TABLE IF NOT EXISTS email_validator.validation_results (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    job_id UUID NOT NULL REFERENCES email_validator.validation_jobs(id) ON DELETE CASCADE,
    email VARCHAR(255) NOT NULL,
    is_valid BOOLEAN,
    score INTEGER,
    checks JSONB,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- ================================================
-- SCHEMA: billing (Faturamento)
-- ================================================
CREATE SCHEMA IF NOT EXISTS billing;

-- Tabela de planos
CREATE TABLE IF NOT EXISTS billing.plans (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    name VARCHAR(100) NOT NULL,
    slug VARCHAR(100) UNIQUE NOT NULL,
    price DECIMAL(10,2) NOT NULL,
    credits INTEGER DEFAULT 0,
    features JSONB DEFAULT '{}',
    is_active BOOLEAN DEFAULT TRUE,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Tabela de assinaturas
CREATE TABLE IF NOT EXISTS billing.subscriptions (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    organization_id UUID NOT NULL REFERENCES tenant.organizations(id),
    plan_id UUID NOT NULL REFERENCES billing.plans(id),
    stripe_subscription_id VARCHAR(255),
    status VARCHAR(50) DEFAULT 'active',
    current_period_start TIMESTAMP,
    current_period_end TIMESTAMP,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- ================================================
-- INDEXES
-- ================================================
CREATE INDEX idx_users_email ON auth.users(email);
CREATE INDEX idx_users_cpf_cnpj ON auth.users(cpf_cnpj);
CREATE INDEX idx_users_phone ON auth.users(phone);
CREATE INDEX idx_sessions_token ON auth.sessions(token);
CREATE INDEX idx_sessions_user_id ON auth.sessions(user_id);
CREATE INDEX idx_organizations_slug ON tenant.organizations(slug);
CREATE INDEX idx_validation_jobs_org ON email_validator.validation_jobs(organization_id);
CREATE INDEX idx_validation_jobs_user ON email_validator.validation_jobs(user_id);

-- ================================================
-- DEFAULT DATA
-- ================================================

-- Inserir planos padrão
INSERT INTO billing.plans (name, slug, price, credits, features) VALUES
('Free', 'free', 0.00, 100, '{"validations_per_month": 100, "api_access": false}'),
('Starter', 'starter', 29.90, 1000, '{"validations_per_month": 1000, "api_access": true, "priority_support": false}'),
('Professional', 'professional', 99.90, 5000, '{"validations_per_month": 5000, "api_access": true, "priority_support": true}'),
('Enterprise', 'enterprise', 299.90, 999999, '{"validations_per_month": "unlimited", "api_access": true, "priority_support": true, "dedicated_account": true}')
ON CONFLICT (slug) DO NOTHING;

-- Criar organização demo
INSERT INTO tenant.organizations (name, slug, plan) VALUES
('Demo Organization', 'demo', 'free')
ON CONFLICT (slug) DO NOTHING;

-- ================================================
-- FUNCTIONS & TRIGGERS
-- ================================================

-- Função para atualizar updated_at
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = CURRENT_TIMESTAMP;
    RETURN NEW;
END;
$$ language 'plpgsql';

-- Triggers para atualizar updated_at
CREATE TRIGGER update_users_updated_at BEFORE UPDATE ON auth.users
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_organizations_updated_at BEFORE UPDATE ON tenant.organizations
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

-- Função para validar CPF
CREATE OR REPLACE FUNCTION validate_cpf(cpf VARCHAR) RETURNS BOOLEAN AS $$
DECLARE
    digits VARCHAR;
    sum1 INTEGER := 0;
    sum2 INTEGER := 0;
    i INTEGER;
BEGIN
    -- Remove caracteres não numéricos
    digits := regexp_replace(cpf, '[^0-9]', '', 'g');
    
    -- CPF deve ter 11 dígitos
    IF length(digits) != 11 THEN
        RETURN FALSE;
    END IF;
    
    -- Verifica se todos os dígitos são iguais
    IF digits ~ '^(\d)\1{10}$' THEN
        RETURN FALSE;
    END IF;
    
    -- Calcula primeiro dígito verificador
    FOR i IN 1..9 LOOP
        sum1 := sum1 + (substring(digits, i, 1)::INTEGER * (11 - i));
    END LOOP;
    
    sum1 := 11 - (sum1 % 11);
    IF sum1 >= 10 THEN sum1 := 0; END IF;
    
    -- Verifica primeiro dígito
    IF sum1 != substring(digits, 10, 1)::INTEGER THEN
        RETURN FALSE;
    END IF;
    
    -- Calcula segundo dígito verificador
    FOR i IN 1..10 LOOP
        sum2 := sum2 + (substring(digits, i, 1)::INTEGER * (12 - i));
    END LOOP;
    
    sum2 := 11 - (sum2 % 11);
    IF sum2 >= 10 THEN sum2 := 0; END IF;
    
    -- Verifica segundo dígito
    RETURN sum2 = substring(digits, 11, 1)::INTEGER;
END;
$$ LANGUAGE plpgsql;

-- Função para validar CNPJ
CREATE OR REPLACE FUNCTION validate_cnpj(cnpj VARCHAR) RETURNS BOOLEAN AS $$
DECLARE
    digits VARCHAR;
    sum INTEGER;
    digit INTEGER;
    i INTEGER;
    weight INTEGER[];
BEGIN
    -- Remove caracteres não numéricos
    digits := regexp_replace(cnpj, '[^0-9]', '', 'g');
    
    -- CNPJ deve ter 14 dígitos
    IF length(digits) != 14 THEN
        RETURN FALSE;
    END IF;
    
    -- Verifica se todos os dígitos são iguais
    IF digits ~ '^(\d)\1{13}$' THEN
        RETURN FALSE;
    END IF;
    
    -- Pesos para cálculo
    weight := ARRAY[6,5,4,3,2,9,8,7,6,5,4,3,2];
    
    -- Calcula primeiro dígito
    sum := 0;
    FOR i IN 1..12 LOOP
        sum := sum + (substring(digits, i, 1)::INTEGER * weight[i+1]);
    END LOOP;
    
    digit := 11 - (sum % 11);
    IF digit >= 10 THEN digit := 0; END IF;
    
    IF digit != substring(digits, 13, 1)::INTEGER THEN
        RETURN FALSE;
    END IF;
    
    -- Calcula segundo dígito
    sum := 0;
    FOR i IN 1..13 LOOP
        sum := sum + (substring(digits, i, 1)::INTEGER * weight[i]);
    END LOOP;
    
    digit := 11 - (sum % 11);
    IF digit >= 10 THEN digit := 0; END IF;
    
    RETURN digit = substring(digits, 14, 1)::INTEGER;
END;
$$ LANGUAGE plpgsql;

-- Constraint para validar CPF/CNPJ
ALTER TABLE auth.users ADD CONSTRAINT check_cpf_cnpj 
    CHECK (
        (length(regexp_replace(cpf_cnpj, '[^0-9]', '', 'g')) = 11 AND validate_cpf(cpf_cnpj))
        OR 
        (length(regexp_replace(cpf_cnpj, '[^0-9]', '', 'g')) = 14 AND validate_cnpj(cpf_cnpj))
    );

GRANT ALL PRIVILEGES ON ALL TABLES IN SCHEMA auth TO sparknexus;
GRANT ALL PRIVILEGES ON ALL TABLES IN SCHEMA tenant TO sparknexus;
GRANT ALL PRIVILEGES ON ALL TABLES IN SCHEMA email_validator TO sparknexus;
GRANT ALL PRIVILEGES ON ALL TABLES IN SCHEMA billing TO sparknexus;
GRANT USAGE ON ALL SCHEMAS TO sparknexus;
