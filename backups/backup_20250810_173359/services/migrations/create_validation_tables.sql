-- ================================================
-- Migração: Criar tabelas de validação de email
-- ================================================

-- Criar schema se não existir
CREATE SCHEMA IF NOT EXISTS validation;

-- Tabela principal de validações
CREATE TABLE IF NOT EXISTS validation.email_validations (
    id SERIAL PRIMARY KEY,
    email VARCHAR(254) NOT NULL,
    valid BOOLEAN NOT NULL,
    score INTEGER CHECK (score >= 0 AND score <= 100),
    risk VARCHAR(20),
    checks JSONB,
    processing_time INTEGER,
    user_id INTEGER REFERENCES auth.users(id),
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    UNIQUE(email)
);

-- Índices para performance
CREATE INDEX IF NOT EXISTS idx_email_validations_email ON validation.email_validations(email);
CREATE INDEX IF NOT EXISTS idx_email_validations_user_id ON validation.email_validations(user_id);
CREATE INDEX IF NOT EXISTS idx_email_validations_created_at ON validation.email_validations(created_at);

-- Tabela de cache de domínios
CREATE TABLE IF NOT EXISTS validation.domain_cache (
    domain VARCHAR(253) PRIMARY KEY,
    mx_records JSONB,
    is_disposable BOOLEAN,
    reputation_score INTEGER,
    last_checked TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Tabela de domínios disposable customizados
CREATE TABLE IF NOT EXISTS validation.custom_disposable_domains (
    domain VARCHAR(253) PRIMARY KEY,
    added_by INTEGER REFERENCES auth.users(id),
    reason TEXT,
    added_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Tabela de whitelist
CREATE TABLE IF NOT EXISTS validation.whitelist_domains (
    domain VARCHAR(253) PRIMARY KEY,
    added_by INTEGER REFERENCES auth.users(id),
    reason TEXT,
    added_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Tabela de estatísticas
CREATE TABLE IF NOT EXISTS validation.user_stats (
    user_id INTEGER PRIMARY KEY REFERENCES auth.users(id),
    total_validations INTEGER DEFAULT 0,
    valid_emails INTEGER DEFAULT 0,
    invalid_emails INTEGER DEFAULT 0,
    avg_score DECIMAL(5,2),
    last_validation TIMESTAMP WITH TIME ZONE,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Função para atualizar updated_at
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ language 'plpgsql';

-- Triggers
DROP TRIGGER IF EXISTS update_email_validations_updated_at ON validation.email_validations;
CREATE TRIGGER update_email_validations_updated_at
    BEFORE UPDATE ON validation.email_validations
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

DROP TRIGGER IF EXISTS update_user_stats_updated_at ON validation.user_stats;
CREATE TRIGGER update_user_stats_updated_at
    BEFORE UPDATE ON validation.user_stats
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

-- Função para atualizar estatísticas do usuário
CREATE OR REPLACE FUNCTION update_user_stats()
RETURNS TRIGGER AS $$
BEGIN
    INSERT INTO validation.user_stats (user_id, total_validations, valid_emails, invalid_emails, avg_score, last_validation)
    VALUES (
        NEW.user_id,
        1,
        CASE WHEN NEW.valid THEN 1 ELSE 0 END,
        CASE WHEN NOT NEW.valid THEN 1 ELSE 0 END,
        NEW.score,
        NOW()
    )
    ON CONFLICT (user_id) DO UPDATE SET
        total_validations = validation.user_stats.total_validations + 1,
        valid_emails = validation.user_stats.valid_emails + CASE WHEN NEW.valid THEN 1 ELSE 0 END,
        invalid_emails = validation.user_stats.invalid_emails + CASE WHEN NOT NEW.valid THEN 1 ELSE 0 END,
        avg_score = ((validation.user_stats.avg_score * validation.user_stats.total_validations) + NEW.score) / (validation.user_stats.total_validations + 1),
        last_validation = NOW();

    RETURN NEW;
END;
$$ language 'plpgsql';

-- Trigger para estatísticas
DROP TRIGGER IF EXISTS update_stats_on_validation ON validation.email_validations;
CREATE TRIGGER update_stats_on_validation
    AFTER INSERT ON validation.email_validations
    FOR EACH ROW
    WHEN (NEW.user_id IS NOT NULL)
    EXECUTE FUNCTION update_user_stats();

-- Adicionar dados iniciais de teste (opcional)
INSERT INTO validation.whitelist_domains (domain, reason)
VALUES ('sparknexus.com.br', 'Domínio próprio')
ON CONFLICT DO NOTHING;
