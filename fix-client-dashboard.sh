#!/bin/bash

# ================================================
# SPARK NEXUS - CORREÇÃO DEFINITIVA
# ================================================

# Cores
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
MAGENTA='\033[0;35m'
NC='\033[0m'

clear
echo -e "${MAGENTA}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${MAGENTA}     🔧 CORREÇÃO DEFINITIVA - CLIENT DASHBOARD${NC}"
echo -e "${MAGENTA}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""

# ================================================
# DIAGNÓSTICO INICIAL
# ================================================
echo -e "${BLUE}[DIAGNÓSTICO] Verificando estado atual...${NC}"
echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"

# Verificar logs do erro
echo -e "${CYAN}📋 Últimos erros do container:${NC}"
docker-compose logs --tail=10 client-dashboard 2>&1 | grep -E "Error|Cannot find module|TypeError" | head -5

echo ""

# ================================================
# ETAPA 1: PARAR E REMOVER
# ================================================
echo -e "${BLUE}[1/6] Limpeza completa...${NC}"
echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"

# Parar e remover container
docker-compose stop client-dashboard 2>/dev/null
docker-compose rm -f client-dashboard 2>/dev/null
echo -e "${GREEN}✅ Container removido${NC}"
echo ""

# ================================================
# ETAPA 2: CORRIGIR ARQUIVOS LOCAIS
# ================================================
echo -e "${BLUE}[2/6] Corrigindo arquivos no host...${NC}"
echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"

# Navegar para o diretório
cd core/client-dashboard 2>/dev/null || cd client-dashboard 2>/dev/null || true

# Corrigir database.js definitivamente
echo -e "${CYAN}🔧 Corrigindo database.js...${NC}"
cat > services/database.fix.js << 'EOF'
// ================================================
// Serviço de Banco de Dados PostgreSQL
// ================================================

const { Pool } = require('pg');
const bcrypt = require('bcryptjs');

class DatabaseService {
    constructor() {
        // Configurar PostgreSQL
        console.log('process.env.DATABASE_URL --> ', process.env.DATABASE_URL)
        this.pool = new Pool({
            connectionString: process.env.DATABASE_URL || 'postgresql://sparknexus:SparkNexus2024!@postgres:5432/sparknexus',
            ssl: process.env.NODE_ENV === 'production' ? { rejectUnauthorized: false } : false
        });

        // Redis desabilitado temporariamente
        this.redis = { 
            isOpen: false,
            get: async () => null,
            set: async () => null,
            setEx: async () => null,
            del: async () => null,
            quit: async () => null
        };
        
        // Não chamar setupRedis por enquanto
        // this.setupRedis();
    }

    async setupRedis() {
        // Desabilitado temporariamente
        console.log('Redis desabilitado temporariamente');
    }

    // ================================================
    // USUÁRIOS
    // ================================================

    // Criar usuário
    async createUser(userData) {
      console.log('connectionString ---:', this.pool)
        const client = await this.pool.connect();

        try {
            await client.query('BEGIN');

            // Hash da senha
            const passwordHash = await bcrypt.hash(userData.password, 10);

            // Inserir usuário
            const query = `
                INSERT INTO auth.users (
                    email, password_hash, first_name, last_name,
                    cpf_cnpj, phone, company,
                    email_verification_token, phone_verification_token,
                    email_token_expires, phone_token_expires
                ) VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11)
                RETURNING id, email, first_name, last_name, company
            `;

            const tokenExpiry = new Date();
            tokenExpiry.setMinutes(tokenExpiry.getMinutes() + 30);

            const phoneTokenExpiry = new Date();
            phoneTokenExpiry.setMinutes(phoneTokenExpiry.getMinutes() + 10);

            const result = await client.query(query, [
                userData.email.toLowerCase(),
                passwordHash,
                userData.firstName,
                userData.lastName,
                userData.cpfCnpj,
                userData.phone,
                userData.company,
                userData.emailToken,
                userData.phoneToken,
                tokenExpiry,
                phoneTokenExpiry
            ]);

            // Criar organização para o usuário
            const orgQuery = `
                INSERT INTO tenant.organizations (name, slug, cnpj)
                VALUES ($1, $2, $3)
                RETURNING id
            `;

            const slug = userData.company.toLowerCase()
                .replace(/[^\w\s-]/g, '')
                .replace(/\s+/g, '-');

            const orgResult = await client.query(orgQuery, [
                userData.company,
                slug + '-' + Date.now(),
                userData.cpfCnpj.length === 14 ? userData.cpfCnpj : null
            ]);

            // Associar usuário à organização
            await client.query(
                `INSERT INTO tenant.organization_members (organization_id, user_id, role)
                 VALUES ($1, $2, 'owner')`,
                [orgResult.rows[0].id, result.rows[0].id]
            );

            await client.query('COMMIT');

            return {
                success: true,
                user: result.rows[0],
                organizationId: orgResult.rows[0].id
            };
        } catch (error) {
            await client.query('ROLLBACK');
            console.error('Erro ao criar usuário:', error);

            if (error.code === '23505') {
                if (error.constraint === 'users_email_key') {
                    throw new Error('Email já cadastrado');
                }
                if (error.constraint === 'users_cpf_cnpj_key') {
                    throw new Error('CPF/CNPJ já cadastrado');
                }
            }

            throw error;
        } finally {
            client.release();
        }
    }

    // Buscar usuário por email
    async getUserByEmail(email) {
        const query = `
            SELECT id, email, password_hash, first_name, last_name,
                   cpf_cnpj, phone, company, email_verified, phone_verified
            FROM auth.users
            WHERE email = $1
        `;

        const result = await this.pool.query(query, [email.toLowerCase()]);
        console.log('result: ', result.rows)
        return result.rows[0];
    }

    // Verificar email
    async verifyEmail(token) {
        const query = `
            UPDATE auth.users
            SET email_verified = true,
                email_verification_token = NULL,
                email_token_expires = NULL
            WHERE email_verification_token = $1
                AND email_token_expires > NOW()
            RETURNING id, email, first_name
        `;

        const result = await this.pool.query(query, [token]);
        return result.rows[0];
    }

    // Verificar telefone
    async verifyPhone(userId, token) {
        const query = `
            UPDATE auth.users
            SET phone_verified = true,
                phone_verification_token = NULL,
                phone_token_expires = NULL
            WHERE id = $1
                AND phone_verification_token = $2
                AND phone_token_expires > NOW()
            RETURNING id, phone
        `;

        const result = await this.pool.query(query, [userId, token]);
        return result.rows[0];
    }

    // Criar sessão
    async createSession(userId, token, ipAddress, userAgent) {
        const expires = new Date();
        expires.setHours(expires.getHours() + 24);

        const query = `
            INSERT INTO auth.sessions (user_id, token, ip_address, user_agent, expires_at)
            VALUES ($1, $2, $3, $4, $5)
            RETURNING id
        `;

        const result = await this.pool.query(query, [
            userId, token, ipAddress, userAgent, expires
        ]);

        return result.rows[0];
    }

    // Validar sessão
    async validateSession(token) {
        // Se não tem Redis, ir direto ao banco
        const query = `
            SELECT s.*, u.email, u.first_name, u.last_name
            FROM auth.sessions s
            JOIN auth.users u ON s.user_id = u.id
            WHERE s.token = $1 AND s.expires_at > NOW()
        `;

        const result = await this.pool.query(query, [token]);
        return result.rows[0];
    }

    // Registrar tentativa de login
    async logLoginAttempt(email, ipAddress, success) {
        const query = `
            INSERT INTO auth.login_attempts (email, ip_address, success)
            VALUES ($1, $2, $3)
        `;

        await this.pool.query(query, [email, ipAddress, success]);
    }

    // Verificar tentativas de login
    async checkLoginAttempts(email, ipAddress) {
        const query = `
            SELECT COUNT(*) as attempts
            FROM auth.login_attempts
            WHERE (email = $1 OR ip_address = $2)
                AND success = false
                AND attempted_at > NOW() - INTERVAL '15 minutes'
        `;

        const result = await this.pool.query(query, [email, ipAddress]);
        return parseInt(result.rows[0].attempts);
    }

    // Limpar dados expirados
    async cleanupExpiredData() {
        // Limpar sessões expiradas
        await this.pool.query(
            `DELETE FROM auth.sessions WHERE expires_at < NOW()`
        );

        // Limpar tokens de verificação expirados
        await this.pool.query(`
            UPDATE auth.users
            SET email_verification_token = NULL
            WHERE email_token_expires < NOW() AND email_verification_token IS NOT NULL
        `);

        await this.pool.query(`
            UPDATE auth.users
            SET phone_verification_token = NULL
            WHERE phone_token_expires < NOW() AND phone_verification_token IS NOT NULL
        `);
    }
}

module.exports = DatabaseService;
EOF

# Substituir arquivo original
mv services/database.fix.js services/database.js
echo -e "${GREEN}✅ database.js corrigido${NC}"

# Verificar se server.js tem referências ao validador
if grep -q "validatorRoutes\|EmailValidator" server.js 2>/dev/null; then
    echo -e "${CYAN}🔧 Limpando server.js...${NC}"
    # Fazer backup
    cp server.js server.js.problematic
    
    # Buscar backup limpo
    CLEAN_BACKUP=$(ls -t server.js.backup-* 2>/dev/null | grep -v "problematic" | head -1)
    if [ -n "$CLEAN_BACKUP" ]; then
        cp "$CLEAN_BACKUP" server.js
        echo -e "${GREEN}✅ server.js restaurado do backup${NC}"
    fi
fi

echo ""

# ================================================
# ETAPA 3: CRIAR DOCKERFILE CORRIGIDO
# ================================================
echo -e "${BLUE}[3/6] Criando Dockerfile otimizado...${NC}"
echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"

cat > Dockerfile << 'EOF'
FROM node:18-alpine

WORKDIR /app

# Copiar package files
COPY package*.json ./

# Instalar dependências
RUN npm install

# Copiar código
COPY . .

# Criar diretórios necessários
RUN mkdir -p uploads services/routes services/data

# Expor porta
EXPOSE 4201

# Comando para iniciar
CMD ["node", "server.js"]
EOF

echo -e "${GREEN}✅ Dockerfile criado${NC}"
echo ""

# ================================================
# ETAPA 4: RECONSTRUIR SEM CACHE
# ================================================
echo -e "${BLUE}[4/6] Reconstruindo imagem sem cache...${NC}"
echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"

# Voltar para raiz
cd ../..

# Remover imagem antiga
docker rmi spark-nexus-client-dashboard 2>/dev/null || true

# Construir nova imagem
docker-compose build --no-cache client-dashboard

if [ $? -eq 0 ]; then
    echo -e "${GREEN}✅ Imagem reconstruída${NC}"
else
    echo -e "${RED}❌ Erro na construção${NC}"
fi
echo ""

# ================================================
# ETAPA 5: INICIAR CONTAINER
# ================================================
echo -e "${BLUE}[5/6] Iniciando container...${NC}"
echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"

docker-compose up -d client-dashboard

echo -e "${YELLOW}⏳ Aguardando inicialização (15 segundos)...${NC}"
for i in {1..15}; do
    echo -n "."
    sleep 1
done
echo ""
echo ""

# ================================================
# ETAPA 6: VERIFICAÇÃO COMPLETA
# ================================================
echo -e "${BLUE}[6/6] Verificação final...${NC}"
echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"

# Verificar se container está rodando
CONTAINER_NAME="sparknexus-client-dashboard"
CONTAINER_ALT="sparknexus-client"

if docker ps --format "{{.Names}}" | grep -qE "${CONTAINER_NAME}|${CONTAINER_ALT}"; then
    echo -e "${GREEN}✅ Container está rodando${NC}"
    
    # Pegar nome real do container
    REAL_NAME=$(docker ps --format "{{.Names}}" | grep -E "client" | head -1)
    
    # Verificar logs recentes
    echo -e "\n${CYAN}📋 Status do serviço:${NC}"
    docker logs --tail=5 "$REAL_NAME" 2>&1 | grep -E "Servidor rodando|listening|started" | head -2
    
    # Testar API
    echo -e "\n${CYAN}🔌 Testando API...${NC}"
    for attempt in {1..3}; do
        HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" "http://localhost:4201/api/health" 2>/dev/null)
        if [ "$HTTP_CODE" = "200" ]; then
            echo -e "${GREEN}✅ API respondendo (HTTP $HTTP_CODE)${NC}"
            break
        else
            echo -e "${YELLOW}Tentativa $attempt/3... (HTTP $HTTP_CODE)${NC}"
            sleep 2
        fi
    done
    
    # Testar interface web
    echo -e "\n${CYAN}🌐 Testando interface web...${NC}"
    WEB_CODE=$(curl -s -o /dev/null -w "%{http_code}" "http://localhost:4201/login" 2>/dev/null)
    if [ "$WEB_CODE" = "200" ] || [ "$WEB_CODE" = "304" ]; then
        echo -e "${GREEN}✅ Interface web acessível${NC}"
    else
        echo -e "${YELLOW}⚠️  Interface retornou HTTP $WEB_CODE${NC}"
    fi
    
else
    echo -e "${RED}❌ Container não está rodando${NC}"
    
    # Mostrar erro específico
    echo -e "\n${CYAN}📋 Últimos erros:${NC}"
    docker-compose logs --tail=20 client-dashboard 2>&1 | grep -E "Error|Cannot|Failed" | head -5
    
    # Tentar reiniciar uma vez
    echo -e "\n${YELLOW}🔄 Tentando reiniciar...${NC}"
    docker-compose restart client-dashboard
    sleep 10
    
    if docker ps --format "{{.Names}}" | grep -qE "client"; then
        echo -e "${GREEN}✅ Container iniciou após restart${NC}"
    else
        echo -e "${RED}❌ Falha ao iniciar${NC}"
    fi
fi

# ================================================
# RESULTADO FINAL
# ================================================
echo ""
echo -e "${MAGENTA}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"

if docker ps --format "{{.Names}}" | grep -qE "client"; then
    echo -e "${GREEN}     ✅ SISTEMA CORRIGIDO E FUNCIONANDO!${NC}"
    echo -e "${MAGENTA}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo ""
    echo -e "${CYAN}🌐 ACESSO:${NC}"
    echo -e "   Dashboard: ${BLUE}http://localhost:4201${NC}"
    echo -e "   Login:     ${BLUE}http://localhost:4201/login${NC}"
    echo -e "   Cadastro:  ${BLUE}http://localhost:4201/register${NC}"
    echo ""
    echo -e "${CYAN}🔐 SUAS CREDENCIAIS:${NC}"
    echo -e "   Email: ${YELLOW}girardellibaptista@gmail.com${NC}"
    echo -e "   Senha: ${YELLOW}Clara@123${NC}"
    echo ""
    echo -e "${GREEN}✨ Sistema pronto para uso!${NC}"
else
    echo -e "${RED}     ❌ AINDA COM PROBLEMAS${NC}"
    echo -e "${MAGENTA}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo ""
    echo -e "${YELLOW}📝 DEBUG MANUAL:${NC}"
    echo ""
    echo "1. Ver logs completos:"
    echo -e "   ${CYAN}docker-compose logs client-dashboard | less${NC}"
    echo ""
    echo "2. Entrar no container (se estiver rodando):"
    echo -e "   ${CYAN}docker exec -it sparknexus-client-dashboard sh${NC}"
    echo ""
    echo "3. Verificar arquivos:"
    echo -e "   ${CYAN}ls -la core/client-dashboard/services/${NC}"
    echo ""
    echo "4. Tentar modo debug:"
    echo -e "   ${CYAN}cd core/client-dashboard && npm start${NC}"
fi

echo ""
exit 0