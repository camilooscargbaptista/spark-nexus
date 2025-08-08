#!/bin/bash

echo "🌱 Inserindo dados de teste no banco..."

# Criar usuário demo com senha já hasheada
docker exec -i sparknexus-postgres psql -U sparknexus -d sparknexus << SQL
-- Inserir usuário demo
INSERT INTO auth.users (
    email, 
    password_hash, 
    first_name, 
    last_name, 
    cpf_cnpj, 
    phone, 
    company,
    email_verified,
    phone_verified
) VALUES (
    'demo@sparknexus.com',
    '\$2a\$10\$YrJpDFBBIrXzKDFYtFkKPuWR8vhLXGNxVxLxvKnHz2vz3fA6UyXJq', -- senha: Demo@123456
    'Demo',
    'User',
    '11144477735',
    '11987654321',
    'Demo Company',
    true,
    true
) ON CONFLICT (email) DO NOTHING;

-- Criar organização demo
INSERT INTO tenant.organizations (name, slug, plan)
SELECT 'Demo Organization', 'demo-org', 'free'
WHERE NOT EXISTS (SELECT 1 FROM tenant.organizations WHERE slug = 'demo-org');

-- Associar usuário à organização
INSERT INTO tenant.organization_members (organization_id, user_id, role)
SELECT o.id, u.id, 'owner'
FROM tenant.organizations o, auth.users u
WHERE o.slug = 'demo-org' AND u.email = 'demo@sparknexus.com'
ON CONFLICT DO NOTHING;

SELECT 'Dados de teste inseridos com sucesso!' as status;
SQL

echo "✅ Seed concluído!"
echo ""
echo "Credenciais de demo:"
echo "Email: demo@sparknexus.com"
echo "Senha: Demo@123456"
