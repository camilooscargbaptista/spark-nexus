-- =============================================
-- EMAIL VALIDATOR DATABASE SCHEMA
-- =============================================

-- Tabela de Jobs de Validação
CREATE TABLE IF NOT EXISTS validation_jobs (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    job_id VARCHAR(255) UNIQUE NOT NULL,
    organization_id VARCHAR(255) NOT NULL,
    user_email VARCHAR(255) NOT NULL,
    file_name VARCHAR(255),
    upload_path VARCHAR(500),
    email_count INTEGER,
    status VARCHAR(50) DEFAULT 'pending',
    progress INTEGER DEFAULT 0,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    started_at TIMESTAMP,
    completed_at TIMESTAMP,
    report_path VARCHAR(500),
    error_message TEXT,
    CONSTRAINT valid_status CHECK (status IN ('pending', 'processing', 'completed', 'failed'))
);

-- Tabela de Resultados de Validação
CREATE TABLE IF NOT EXISTS validation_results (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    job_id VARCHAR(255) REFERENCES validation_jobs(job_id) ON DELETE CASCADE,
    email VARCHAR(255) NOT NULL,
    valid BOOLEAN DEFAULT false,
    score INTEGER DEFAULT 0,
    format_valid BOOLEAN,
    mx_records BOOLEAN,
    smtp_valid BOOLEAN,
    disposable BOOLEAN,
    role_based BOOLEAN,
    free_provider BOOLEAN,
    reason TEXT,
    checks JSONB DEFAULT '{}',
    validated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    INDEX idx_job_id (job_id),
    INDEX idx_email (email),
    INDEX idx_valid (valid)
);

-- Tabela de Estatísticas por Organização
CREATE TABLE IF NOT EXISTS organization_stats (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    organization_id VARCHAR(255) UNIQUE NOT NULL,
    total_validations INTEGER DEFAULT 0,
    valid_emails INTEGER DEFAULT 0,
    invalid_emails INTEGER DEFAULT 0,
    last_validation TIMESTAMP,
    monthly_usage INTEGER DEFAULT 0,
    usage_reset_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP + INTERVAL '30 days',
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Tabela de Cache de Validações
CREATE TABLE IF NOT EXISTS validation_cache (
    email VARCHAR(255) PRIMARY KEY,
    valid BOOLEAN,
    score INTEGER,
    checks JSONB,
    cached_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    expires_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP + INTERVAL '30 days'
);

-- Função para atualizar estatísticas
CREATE OR REPLACE FUNCTION update_organization_stats()
RETURNS TRIGGER AS $$
BEGIN
    UPDATE organization_stats
    SET 
        total_validations = total_validations + 1,
        valid_emails = valid_emails + CASE WHEN NEW.valid THEN 1 ELSE 0 END,
        invalid_emails = invalid_emails + CASE WHEN NOT NEW.valid THEN 1 ELSE 0 END,
        last_validation = NOW(),
        monthly_usage = monthly_usage + 1,
        updated_at = NOW()
    WHERE organization_id = (
        SELECT organization_id FROM validation_jobs WHERE job_id = NEW.job_id
    );
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Trigger para atualizar estatísticas
CREATE TRIGGER update_stats_on_validation
AFTER INSERT ON validation_results
FOR EACH ROW
EXECUTE FUNCTION update_organization_stats();

-- Índices para performance
CREATE INDEX idx_jobs_organization ON validation_jobs(organization_id);
CREATE INDEX idx_jobs_status ON validation_jobs(status);
CREATE INDEX idx_jobs_created ON validation_jobs(created_at DESC);
CREATE INDEX idx_results_validated ON validation_results(validated_at DESC);
CREATE INDEX idx_cache_expires ON validation_cache(expires_at);
