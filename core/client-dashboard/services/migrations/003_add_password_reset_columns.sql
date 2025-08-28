-- ================================================
-- MIGRATION: 003_add_password_reset_columns
-- Adiciona colunas para funcionalidade de reset de senha
-- ================================================

-- Adicionar colunas para reset de senha na tabela users
ALTER TABLE auth.users 
ADD COLUMN IF NOT EXISTS password_reset_token VARCHAR(10),
ADD COLUMN IF NOT EXISTS password_reset_expires TIMESTAMP;

-- Criar índice para melhor performance nas consultas de reset
CREATE INDEX IF NOT EXISTS idx_users_password_reset_token 
ON auth.users (password_reset_token);

CREATE INDEX IF NOT EXISTS idx_users_password_reset_expires 
ON auth.users (password_reset_expires);

-- Log da migration
INSERT INTO public.migration_log (migration_name, applied_at, description) 
VALUES ('003_add_password_reset_columns', NOW(), 'Adicionadas colunas password_reset_token e password_reset_expires na tabela auth.users')
ON CONFLICT DO NOTHING;