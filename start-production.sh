#!/bin/bash

# ================================================
# SPARK NEXUS - SCRIPT DE PRODUÇÃO
# Script robusto para inicialização completa
# Falha se qualquer etapa crítica falhar
# ================================================

set -e  # Parar em caso de erro
set -u  # Parar se usar variável não definida
set -o pipefail  # Parar se comando em pipe falhar

# ================================================
# CONFIGURAÇÕES
# ================================================
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

# Timeout para aguardar serviços
POSTGRES_TIMEOUT=60
REDIS_TIMEOUT=30
SERVICE_STARTUP_TIMEOUT=30

# Cores para output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
MAGENTA='\033[0;35m'
NC='\033[0m'

# Log file
LOG_FILE="spark-nexus-startup-$(date +%Y%m%d-%H%M%S).log"

# ================================================
# FUNÇÕES AUXILIARES
# ================================================

# Função para log
log() {
    echo -e "$1" | tee -a "$LOG_FILE"
}

# Função para log de erro
log_error() {
    echo -e "${RED}$1${NC}" | tee -a "$LOG_FILE"
}

# Função para log de sucesso
log_success() {
    echo -e "${GREEN}$1${NC}" | tee -a "$LOG_FILE"
}

# Função para log de warning
log_warning() {
    echo -e "${YELLOW}$1${NC}" | tee -a "$LOG_FILE"
}

# Função para log de info
log_info() {
    echo -e "${CYAN}$1${NC}" | tee -a "$LOG_FILE"
}

# Função de cleanup em caso de erro
cleanup_on_error() {
    log_error "\n❌ ERRO: Falha na inicialização do sistema"
    log_error "Verifique o log: $LOG_FILE"
    log_warning "Parando containers..."
    docker-compose down 2>/dev/null || true
    exit 1
}

# Trap para capturar erros
trap cleanup_on_error ERR

# Função para verificar pré-requisitos
check_prerequisites() {
    log_info "\n[1/12] Verificando pré-requisitos..."
    
    # Verificar Docker
    if ! command -v docker &> /dev/null; then
        log_error "Docker não está instalado"
        exit 1
    fi
    
    if ! docker info &> /dev/null; then
        log_error "Docker não está rodando"
        exit 1
    fi
    log_success "✅ Docker OK"
    
    # Verificar docker-compose
    if ! command -v docker-compose &> /dev/null; then
        log_error "docker-compose não está instalado"
        exit 1
    fi
    log_success "✅ docker-compose OK"
    
    # Verificar arquivo docker-compose.yml
    if [ ! -f "docker-compose.yml" ]; then
        log_error "docker-compose.yml não encontrado"
        exit 1
    fi
    log_success "✅ docker-compose.yml encontrado"
    
    # Verificar espaço em disco (mínimo 2GB)
    available_space=$(df -BG . | awk 'NR==2 {print $4}' | sed 's/G//')
    if [ "$available_space" -lt 2 ]; then
        log_error "Espaço em disco insuficiente (mínimo 2GB)"
        exit 1
    fi
    log_success "✅ Espaço em disco OK (${available_space}GB disponível)"
}

# Função para preparar ambiente
prepare_environment() {
    log_info "\n[2/12] Preparando ambiente..."
    
    # Criar diretórios necessários
    mkdir -p logs uploads reports backups
    
    # Backup do .env se existir
    if [ -f ".env" ]; then
        cp .env "backups/.env.backup.$(date +%Y%m%d-%H%M%S)"
        log_info "Backup do .env criado"
    else
        # Criar .env básico se não existir
        create_env_file
    fi
    
    # Limpar e corrigir docker-compose.yml
    fix_docker_compose
    
    log_success "✅ Ambiente preparado"
}

# Função para criar arquivo .env
create_env_file() {
    log_info "Criando arquivo .env..."
    cat > .env << 'EOENV'
# Database
DB_HOST=postgres
DB_PORT=5432
DB_NAME=sparknexus
DB_USER=sparknexus
DB_PASSWORD=SparkNexus2024

# Redis
REDIS_HOST=redis
REDIS_PORT=6379
REDIS_PASSWORD=

# RabbitMQ
RABBITMQ_HOST=rabbitmq
RABBITMQ_PORT=5672
RABBITMQ_USER=guest
RABBITMQ_PASS=guest

# JWT
JWT_SECRET=spark-nexus-jwt-secret-$(openssl rand -hex 32)

# Email Configuration
SMTP_HOST=smtp.titan.email
SMTP_PORT=587
SMTP_SECURE=tls
SMTP_USER=contato@sparknexus.com.br
SMTP_PASS=CONFIGURE_ME
SMTP_FROM=contato@sparknexus.com.br
EMAIL_FROM_NAME=Spark Nexus

# Twilio (SMS) - Optional
TWILIO_ACCOUNT_SID=CONFIGURE_ME
TWILIO_AUTH_TOKEN=CONFIGURE_ME
TWILIO_PHONE_NUMBER=CONFIGURE_ME

# Application
NODE_ENV=production
CLIENT_DASHBOARD_PORT=4201
EMAIL_VALIDATOR_PORT=4200
ADMIN_DASHBOARD_PORT=4202
AUTH_SERVICE_PORT=4203

# URLs
APP_URL=http://localhost:4201
API_URL=http://localhost:4200
EOENV
    log_success "✅ Arquivo .env criado"
}

# Função para corrigir docker-compose.yml
fix_docker_compose() {
    log_info "Corrigindo docker-compose.yml..."
    
    # Remover version obsoleto
    sed -i.bak '/^version:/d' docker-compose.yml 2>/dev/null || true
    
    # Corrigir imagem do Kong
    sed -i.bak 's/kong:.*-alpine/kong:3.4/g' docker-compose.yml 2>/dev/null || true
    
    # Remover arquivos de backup
    rm -f docker-compose.yml.bak
}

# Função para parar containers existentes
stop_existing_containers() {
    log_info "\n[3/12] Parando containers existentes..."
    
    # Parar todos os containers do projeto
    docker-compose down --remove-orphans --timeout 30 || true
    
    # Verificar se algum container sparknexus ainda está rodando
    if docker ps | grep -q sparknexus; then
        log_warning "Forçando parada de containers remanescentes..."
        docker ps | grep sparknexus | awk '{print $1}' | xargs -r docker stop --time 10
        docker ps -a | grep sparknexus | awk '{print $1}' | xargs -r docker rm -f
    fi
    
    log_success "✅ Containers parados"
}

# Função para iniciar PostgreSQL
start_postgres() {
    log_info "\n[4/12] Iniciando PostgreSQL..."
    
    docker-compose up -d postgres
    
    # Aguardar PostgreSQL ficar pronto
    local count=0
    while [ $count -lt $POSTGRES_TIMEOUT ]; do
        if docker exec sparknexus-postgres pg_isready -U sparknexus &>/dev/null; then
            log_success "✅ PostgreSQL iniciado e pronto"
            return 0
        fi
        sleep 1
        count=$((count + 1))
        if [ $((count % 10)) -eq 0 ]; then
            log_info "Aguardando PostgreSQL... ($count/$POSTGRES_TIMEOUT)"
        fi
    done
    
    log_error "PostgreSQL não iniciou no tempo esperado"
    exit 1
}

# Função para configurar database
setup_database() {
    log_info "\n[5/12] Configurando banco de dados..."
    
    # Verificar se database existe
    if docker exec sparknexus-postgres psql -U sparknexus -lqt | cut -d \| -f 1 | grep -qw sparknexus; then
        log_info "Database sparknexus já existe"
    else
        log_info "Criando database sparknexus..."
        docker exec sparknexus-postgres createdb -U sparknexus sparknexus
        log_success "✅ Database criado"
    fi
    
    # Aplicar schema
    log_info "Aplicando schema do banco..."
    docker exec sparknexus-postgres psql -U sparknexus -d sparknexus < <(cat << 'EOSQL'
-- Criar schemas
CREATE SCHEMA IF NOT EXISTS auth;
CREATE SCHEMA IF NOT EXISTS tenant;
CREATE SCHEMA IF NOT EXISTS modules;

-- Tabelas auth
CREATE TABLE IF NOT EXISTS auth.users (
    id SERIAL PRIMARY KEY,
    email VARCHAR(255) UNIQUE NOT NULL,
    password_hash VARCHAR(255),
    first_name VARCHAR(100),
    last_name VARCHAR(100),
    cpf_cnpj VARCHAR(20),
    phone VARCHAR(20),
    company VARCHAR(255),
    email_verified BOOLEAN DEFAULT false,
    phone_verified BOOLEAN DEFAULT false,
    email_verification_token VARCHAR(20),
    phone_verification_token VARCHAR(20),
    email_token_expires TIMESTAMP,
    phone_token_expires TIMESTAMP,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE IF NOT EXISTS auth.sessions (
    id SERIAL PRIMARY KEY,
    user_id INTEGER REFERENCES auth.users(id) ON DELETE CASCADE,
    token VARCHAR(500) UNIQUE NOT NULL,
    ip_address VARCHAR(45),
    user_agent TEXT,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    expires_at TIMESTAMP
);

CREATE TABLE IF NOT EXISTS auth.login_attempts (
    id SERIAL PRIMARY KEY,
    email VARCHAR(255),
    ip_address VARCHAR(45),
    success BOOLEAN DEFAULT false,
    attempted_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Tabelas tenant
CREATE TABLE IF NOT EXISTS tenant.organizations (
    id SERIAL PRIMARY KEY,
    name VARCHAR(255) NOT NULL,
    slug VARCHAR(100) UNIQUE NOT NULL,
    plan VARCHAR(50) DEFAULT 'free',
    max_validations INTEGER DEFAULT 1000,
    validations_used INTEGER DEFAULT 0,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE IF NOT EXISTS tenant.organization_members (
    id SERIAL PRIMARY KEY,
    organization_id INTEGER REFERENCES tenant.organizations(id) ON DELETE CASCADE,
    user_id INTEGER REFERENCES auth.users(id) ON DELETE CASCADE,
    role VARCHAR(50) DEFAULT 'member',
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    UNIQUE(organization_id, user_id)
);

-- Índices
CREATE INDEX IF NOT EXISTS idx_users_email ON auth.users(email);
CREATE INDEX IF NOT EXISTS idx_sessions_token ON auth.sessions(token);
CREATE INDEX IF NOT EXISTS idx_sessions_expires ON auth.sessions(expires_at);

-- Inserir usuários de teste apenas se não existirem
INSERT INTO auth.users (email, password_hash, first_name, last_name, cpf_cnpj, phone, company, email_verified, phone_verified)
VALUES 
    ('demo@sparknexus.com', '$2a$10$YrJpDFBBIrXzKDFYtFkKPuWR8vhLXGNxVxLxvKnHz2vz3fA6UyXJq', 'Demo', 'User', '11144477735', '11987654321', 'Demo Company', true, true),
    ('girardelibaptista@gmail.com', '$2a$10$YrJpDFBBIrXzKDFYtFkKPuWR8vhLXGNxVxLxvKnHz2vz3fA6UyXJq', 'Camilo', 'Baptista', '01487829645', '11961411709', 'Camilo Oscar Girardelli Baptista', true, true),
    ('contato@sparknexus.com.br', '$2a$10$YrJpDFBBIrXzKDFYtFkKPuWR8vhLXGNxVxLxvKnHz2vz3fA6UyXJq', 'Contato', 'Spark Nexus', '12345678000190', '11999999999', 'Spark Nexus LTDA', true, true)
ON CONFLICT (email) DO NOTHING;

-- Criar organizações
INSERT INTO tenant.organizations (name, slug, plan)
VALUES 
    ('Demo Organization', 'demo-org', 'free'),
    ('Spark Nexus', 'spark-nexus', 'premium'),
    ('Camilo Baptista', 'camilo-baptista', 'free')
ON CONFLICT (slug) DO NOTHING;
EOSQL
)
    
    log_success "✅ Banco de dados configurado"
}

# Função para iniciar Redis
start_redis() {
    log_info "\n[6/12] Iniciando Redis..."
    
    docker-compose up -d redis
    
    # Aguardar Redis ficar pronto
    local count=0
    while [ $count -lt $REDIS_TIMEOUT ]; do
        if docker exec sparknexus-redis redis-cli ping &>/dev/null; then
            log_success "✅ Redis iniciado e pronto"
            return 0
        fi
        sleep 1
        count=$((count + 1))
    done
    
    log_error "Redis não iniciou no tempo esperado"
    exit 1
}

# Função para iniciar RabbitMQ
start_rabbitmq() {
    log_info "\n[7/12] Iniciando RabbitMQ..."
    
    docker-compose up -d rabbitmq
    
    # Aguardar um pouco para RabbitMQ iniciar
    sleep 10
    
    log_success "✅ RabbitMQ iniciado"
}

# Função para iniciar serviços de autenticação
start_auth_services() {
    log_info "\n[8/12] Iniciando serviços de autenticação..."
    
    # Listar serviços disponíveis
    local services=$(docker-compose config --services 2>/dev/null)
    
    # Iniciar auth-service se existir
    if echo "$services" | grep -q "auth-service"; then
        docker-compose up -d auth-service
        log_success "✅ auth-service iniciado"
    elif echo "$services" | grep -q "^auth$"; then
        docker-compose up -d auth
        log_success "✅ auth iniciado"
    else
        log_warning "⚠️ Nenhum serviço de autenticação encontrado"
    fi
}

# Função para iniciar aplicações principais
start_main_applications() {
    log_info "\n[9/12] Iniciando aplicações principais..."
    
    local services=$(docker-compose config --services 2>/dev/null)
    local started_services=""
    
    # Lista de serviços principais na ordem de prioridade
    local main_services=(
        "email-validator-api"
        "email-validator-worker"
        "client-dashboard"
        "admin-dashboard"
        "tenant-service"
        "billing-service"
    )
    
    for service in "${main_services[@]}"; do
        if echo "$services" | grep -q "^$service$"; then
            log_info "Iniciando $service..."
            if docker-compose up -d "$service" 2>/dev/null; then
                started_services="$started_services $service"
                log_success "✅ $service iniciado"
            else
                log_warning "⚠️ Não foi possível iniciar $service"
            fi
        fi
    done
    
    if [ -z "$started_services" ]; then
        log_error "Nenhuma aplicação principal foi iniciada"
        exit 1
    fi
}

# Função para iniciar serviços administrativos
start_admin_services() {
    log_info "\n[10/12] Iniciando ferramentas administrativas..."
    
    local services=$(docker-compose config --services 2>/dev/null)
    
    # Lista de serviços administrativos
    local admin_services=(
        "adminer"
        "redis-commander"
        "n8n"
    )
    
    for service in "${admin_services[@]}"; do
        if echo "$services" | grep -q "^$service$"; then
            log_info "Iniciando $service..."
            if docker-compose up -d "$service" 2>/dev/null; then
                log_success "✅ $service iniciado"
            else
                log_warning "⚠️ $service não pôde ser iniciado (não crítico)"
            fi
        fi
    done
}

# Função para aguardar serviços ficarem prontos
wait_for_services() {
    log_info "\n[11/12] Aguardando serviços ficarem prontos..."
    
    local count=0
    while [ $count -lt $SERVICE_STARTUP_TIMEOUT ]; do
        # Verificar se client-dashboard está respondendo
        if curl -s -o /dev/null -w "%{http_code}" http://localhost:4201 2>/dev/null | grep -q "200\|301\|302"; then
            log_success "✅ Client Dashboard respondendo"
            break
        fi
        sleep 2
        count=$((count + 2))
        if [ $((count % 10)) -eq 0 ]; then
            log_info "Aguardando serviços... ($count/$SERVICE_STARTUP_TIMEOUT)"
        fi
    done
    
    # Aguardar mais um pouco para todos os serviços estabilizarem
    sleep 5
}

# Função para verificar status final
verify_final_status() {
    log_info "\n[12/12] Verificando status final..."
    
    local all_ok=true
    
    # Verificar containers críticos
    local critical_containers=(
        "sparknexus-postgres"
        "sparknexus-redis"
    )
    
    for container in "${critical_containers[@]}"; do
        if docker ps | grep -q "$container"; then
            log_success "✅ $container rodando"
        else
            log_error "❌ $container NÃO está rodando"
            all_ok=false
        fi
    done
    
    # Verificar se há containers reiniciando
    local restarting=$(docker ps --filter "name=sparknexus" | grep -c "Restarting" || true)
    if [ "$restarting" -gt 0 ]; then
        log_warning "⚠️ Há $restarting container(s) reiniciando"
        all_ok=false
    fi
    
    if [ "$all_ok" = false ]; then
        log_error "\n❌ Sistema iniciado com problemas"
        log_warning "Verifique os logs com: docker-compose logs"
        exit 1
    fi
    
    log_success "\n✅ Sistema iniciado com sucesso!"
}

# Função para exibir informações finais
show_final_info() {
    clear
    cat << 'EOF'
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
     🚀 SPARK NEXUS - SISTEMA INICIADO COM SUCESSO
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
EOF
    
    echo -e "\n${CYAN}📊 Status dos Containers:${NC}"
    docker ps --format "table {{.Names}}\t{{.Status}}" | grep sparknexus || echo "Nenhum container encontrado"
    
    echo -e "\n${CYAN}🌐 URLs de Acesso:${NC}"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo -e "${GREEN}📤 Upload:${NC}           http://localhost:4201/upload"
    echo -e "${GREEN}📊 Dashboard:${NC}        http://localhost:4201"
    echo -e "${GREEN}🔐 Login:${NC}            http://localhost:4201/login"
    echo -e "${GREEN}📧 API:${NC}              http://localhost:4200"
    echo -e "${GREEN}🐘 PostgreSQL:${NC}       http://localhost:8080"
    echo -e "${GREEN}🔴 Redis:${NC}            http://localhost:8081"
    
    echo -e "\n${CYAN}👤 Credenciais:${NC}"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "Email: girardelibaptista@gmail.com"
    echo "Senha: Demo@123456"
    
    echo -e "\n${CYAN}📝 Comandos Úteis:${NC}"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "Logs:     docker-compose logs -f [serviço]"
    echo "Status:   docker ps | grep sparknexus"
    echo "Parar:    docker-compose down"
    echo "Reiniciar: ./start-production.sh"
    
    echo -e "\n${GREEN}✅ Sistema pronto para uso!${NC}"
    echo "Log salvo em: $LOG_FILE"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
}

# ================================================
# EXECUÇÃO PRINCIPAL
# ================================================

main() {
    # Criar arquivo de log
    echo "Spark Nexus - Log de Inicialização - $(date)" > "$LOG_FILE"
    
    log_info "Iniciando Spark Nexus..."
    log_info "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    
    # Executar etapas
    check_prerequisites
    prepare_environment
    stop_existing_containers
    start_postgres
    setup_database
    start_redis
    start_rabbitmq
    start_auth_services
    start_main_applications
    start_admin_services
    wait_for_services
    verify_final_status
    
    # Exibir informações finais
    show_final_info
    
    # Criar arquivo de flag de sucesso
    touch .startup_success
    
    exit 0
}

# Executar função principal
main "$@"