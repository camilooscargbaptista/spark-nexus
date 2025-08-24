-- ================================================
-- Migration: Criar histórico de validações
-- Data: 2025-08-22
-- Descrição: Tabelas para armazenar histórico de validações
-- ================================================

-- Criar schema para validações se não existir
CREATE SCHEMA IF NOT EXISTS validation;

-- Tabela principal de histórico de validações
CREATE TABLE IF NOT EXISTS validation.validation_history (
    id SERIAL PRIMARY KEY,
    organization_id INTEGER NOT NULL REFERENCES tenant.organizations(id) ON DELETE CASCADE,
    user_id INTEGER NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    
    -- Dados da validação
    batch_id VARCHAR(100) NOT NULL UNIQUE, -- ID único para identificar o lote
    validation_type VARCHAR(50) NOT NULL DEFAULT 'file_upload', -- file_upload, batch, single
    status VARCHAR(20) NOT NULL DEFAULT 'processing', -- processing, completed, failed
    
    -- Dados do processamento
    total_emails INTEGER NOT NULL DEFAULT 0,
    emails_processed INTEGER NOT NULL DEFAULT 0,
    emails_valid INTEGER NOT NULL DEFAULT 0,
    emails_invalid INTEGER NOT NULL DEFAULT 0,
    emails_corrected INTEGER NOT NULL DEFAULT 0,
    emails_duplicated INTEGER NOT NULL DEFAULT 0,
    
    -- Métricas de qualidade
    success_rate DECIMAL(5,2) DEFAULT 0, -- Percentual de sucesso (0-100)
    quality_score DECIMAL(5,2) DEFAULT 0, -- Score médio de qualidade (0-100)
    average_score DECIMAL(5,2) DEFAULT 0, -- Score médio dos emails válidos
    
    -- Dados de créditos
    credits_consumed INTEGER NOT NULL DEFAULT 0,
    
    -- Metadados
    file_name VARCHAR(255), -- Nome do arquivo original (se upload)
    file_size INTEGER, -- Tamanho do arquivo em bytes
    processing_time_seconds INTEGER, -- Tempo de processamento em segundos
    
    -- Dados de correção
    corrections_applied JSONB, -- Detalhes das correções aplicadas
    
    -- Dados de erro (se houver)
    error_message TEXT,
    error_details JSONB,
    
    -- Timestamps
    started_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT CURRENT_TIMESTAMP,
    completed_at TIMESTAMP WITH TIME ZONE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

-- Tabela de detalhes dos emails validados (opcional, para auditoria)
CREATE TABLE IF NOT EXISTS validation.validation_details (
    id SERIAL PRIMARY KEY,
    validation_history_id INTEGER NOT NULL REFERENCES validation.validation_history(id) ON DELETE CASCADE,
    
    -- Email data
    email_address VARCHAR(255) NOT NULL,
    original_email VARCHAR(255), -- Email original antes da correção
    was_corrected BOOLEAN DEFAULT FALSE,
    correction_type VARCHAR(50), -- typo_correction, domain_suggestion, etc
    
    -- Validation results
    is_valid BOOLEAN NOT NULL,
    score DECIMAL(5,2) DEFAULT 0,
    risk_level VARCHAR(20), -- low, medium, high
    
    -- Validation details
    syntax_valid BOOLEAN DEFAULT FALSE,
    domain_valid BOOLEAN DEFAULT FALSE,
    mx_valid BOOLEAN DEFAULT FALSE,
    smtp_valid BOOLEAN DEFAULT FALSE,
    disposable BOOLEAN DEFAULT FALSE,
    role_based BOOLEAN DEFAULT FALSE,
    
    -- Line info (from CSV)
    line_number INTEGER,
    is_duplicate BOOLEAN DEFAULT FALSE,
    duplicate_count INTEGER DEFAULT 1,
    
    -- Results details
    validation_results JSONB, -- JSON completo do resultado
    
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

-- Índices para performance
CREATE INDEX IF NOT EXISTS idx_validation_history_org_date 
    ON validation.validation_history(organization_id, created_at DESC);

CREATE INDEX IF NOT EXISTS idx_validation_history_user_date 
    ON validation.validation_history(user_id, created_at DESC);

CREATE INDEX IF NOT EXISTS idx_validation_history_status 
    ON validation.validation_history(status);

CREATE INDEX IF NOT EXISTS idx_validation_history_batch_id 
    ON validation.validation_history(batch_id);

CREATE INDEX IF NOT EXISTS idx_validation_details_history_id 
    ON validation.validation_details(validation_history_id);

CREATE INDEX IF NOT EXISTS idx_validation_details_email 
    ON validation.validation_details(email_address);

-- Trigger para atualizar updated_at
CREATE OR REPLACE FUNCTION validation.update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = CURRENT_TIMESTAMP;
    RETURN NEW;
END;
$$ language 'plpgsql';

CREATE TRIGGER update_validation_history_updated_at 
    BEFORE UPDATE ON validation.validation_history 
    FOR EACH ROW EXECUTE FUNCTION validation.update_updated_at_column();

-- View para estatísticas resumidas por organização
CREATE OR REPLACE VIEW validation.org_validation_stats AS
SELECT 
    vh.organization_id,
    o.name as organization_name,
    COUNT(*) as total_validations,
    SUM(vh.total_emails) as total_emails_processed,
    SUM(vh.emails_valid) as total_emails_valid,
    SUM(vh.emails_invalid) as total_emails_invalid,
    SUM(vh.emails_corrected) as total_emails_corrected,
    SUM(vh.credits_consumed) as total_credits_consumed,
    ROUND(AVG(vh.success_rate), 2) as average_success_rate,
    ROUND(AVG(vh.quality_score), 2) as average_quality_score,
    MIN(vh.created_at) as first_validation,
    MAX(vh.created_at) as last_validation
FROM validation.validation_history vh
JOIN tenant.organizations o ON vh.organization_id = o.id
WHERE vh.status = 'completed'
GROUP BY vh.organization_id, o.name;

-- View para estatísticas por usuário
CREATE OR REPLACE VIEW validation.user_validation_stats AS
SELECT 
    vh.user_id,
    u.first_name,
    u.last_name,
    u.email as user_email,
    vh.organization_id,
    COUNT(*) as total_validations,
    SUM(vh.total_emails) as total_emails_processed,
    SUM(vh.emails_valid) as total_emails_valid,
    SUM(vh.emails_invalid) as total_emails_invalid,
    SUM(vh.emails_corrected) as total_emails_corrected,
    SUM(vh.credits_consumed) as total_credits_consumed,
    ROUND(AVG(vh.success_rate), 2) as average_success_rate,
    ROUND(AVG(vh.quality_score), 2) as average_quality_score,
    MIN(vh.created_at) as first_validation,
    MAX(vh.created_at) as last_validation
FROM validation.validation_history vh
JOIN auth.users u ON vh.user_id = u.id
WHERE vh.status = 'completed'
GROUP BY vh.user_id, u.first_name, u.last_name, u.email, vh.organization_id;

-- View para histórico diário
CREATE OR REPLACE VIEW validation.daily_validation_stats AS
SELECT 
    DATE(vh.created_at) as validation_date,
    vh.organization_id,
    vh.user_id,
    COUNT(*) as validations_count,
    SUM(vh.total_emails) as total_emails,
    SUM(vh.emails_valid) as valid_emails,
    ROUND(
        CASE 
            WHEN SUM(vh.total_emails) > 0 
            THEN (SUM(vh.emails_valid)::DECIMAL / SUM(vh.total_emails)) * 100 
            ELSE 0 
        END, 2
    ) as success_percentage,
    ROUND(AVG(vh.quality_score), 2) as avg_quality,
    SUM(vh.credits_consumed) as credits_used
FROM validation.validation_history vh
WHERE vh.status = 'completed'
GROUP BY DATE(vh.created_at), vh.organization_id, vh.user_id
ORDER BY validation_date DESC;

-- Função para criar um novo registro de validação
CREATE OR REPLACE FUNCTION validation.start_validation(
    p_organization_id INTEGER,
    p_user_id INTEGER,
    p_batch_id VARCHAR(100),
    p_validation_type VARCHAR(50) DEFAULT 'file_upload',
    p_total_emails INTEGER DEFAULT 0,
    p_file_name VARCHAR(255) DEFAULT NULL,
    p_file_size INTEGER DEFAULT NULL
) RETURNS INTEGER AS $$
DECLARE
    v_validation_id INTEGER;
BEGIN
    INSERT INTO validation.validation_history (
        organization_id,
        user_id,
        batch_id,
        validation_type,
        total_emails,
        file_name,
        file_size,
        status
    ) VALUES (
        p_organization_id,
        p_user_id,
        p_batch_id,
        p_validation_type,
        p_total_emails,
        p_file_name,
        p_file_size,
        'processing'
    ) RETURNING id INTO v_validation_id;
    
    RETURN v_validation_id;
END;
$$ LANGUAGE plpgsql;

-- Função para finalizar validação
CREATE OR REPLACE FUNCTION validation.complete_validation(
    p_validation_id INTEGER,
    p_emails_processed INTEGER,
    p_emails_valid INTEGER,
    p_emails_invalid INTEGER,
    p_emails_corrected INTEGER DEFAULT 0,
    p_emails_duplicated INTEGER DEFAULT 0,
    p_success_rate DECIMAL(5,2) DEFAULT NULL,
    p_quality_score DECIMAL(5,2) DEFAULT NULL,
    p_average_score DECIMAL(5,2) DEFAULT NULL,
    p_credits_consumed INTEGER DEFAULT 0,
    p_processing_time_seconds INTEGER DEFAULT NULL,
    p_corrections_applied JSONB DEFAULT NULL,
    p_error_message TEXT DEFAULT NULL
) RETURNS BOOLEAN AS $$
BEGIN
    UPDATE validation.validation_history SET
        emails_processed = p_emails_processed,
        emails_valid = p_emails_valid,
        emails_invalid = p_emails_invalid,
        emails_corrected = p_emails_corrected,
        emails_duplicated = p_emails_duplicated,
        success_rate = COALESCE(p_success_rate, 
            CASE WHEN p_emails_processed > 0 
                 THEN (p_emails_valid::DECIMAL / p_emails_processed) * 100 
                 ELSE 0 END),
        quality_score = p_quality_score,
        average_score = p_average_score,
        credits_consumed = p_credits_consumed,
        processing_time_seconds = p_processing_time_seconds,
        corrections_applied = p_corrections_applied,
        error_message = p_error_message,
        status = CASE WHEN p_error_message IS NULL THEN 'completed' ELSE 'failed' END,
        completed_at = CURRENT_TIMESTAMP
    WHERE id = p_validation_id;
    
    RETURN FOUND;
END;
$$ LANGUAGE plpgsql;

-- Grant permissions
GRANT USAGE ON SCHEMA validation TO sparknexus;
GRANT ALL PRIVILEGES ON ALL TABLES IN SCHEMA validation TO sparknexus;
GRANT ALL PRIVILEGES ON ALL SEQUENCES IN SCHEMA validation TO sparknexus;
GRANT EXECUTE ON ALL FUNCTIONS IN SCHEMA validation TO sparknexus;

-- Comentários
COMMENT ON TABLE validation.validation_history IS 'Histórico de todas as validações de email realizadas';
COMMENT ON TABLE validation.validation_details IS 'Detalhes individuais de cada email validado (opcional para auditoria)';
COMMENT ON VIEW validation.org_validation_stats IS 'Estatísticas resumidas por organização';
COMMENT ON VIEW validation.user_validation_stats IS 'Estatísticas resumidas por usuário';
COMMENT ON VIEW validation.daily_validation_stats IS 'Estatísticas diárias de validação';