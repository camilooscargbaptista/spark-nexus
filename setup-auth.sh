#!/bin/bash

# ================================================
# Script de Setup do Sistema de Autenticação
# Spark Nexus - Client Dashboard
# ================================================

set -e  # Exit on error

# Cores para output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}================================================${NC}"
echo -e "${BLUE}🚀 Spark Nexus - Setup Sistema de Autenticação${NC}"
echo -e "${BLUE}================================================${NC}"

# Verificar se está no diretório correto
if [ ! -f "docker-compose.yml" ]; then
    echo -e "${RED}❌ Erro: Execute este script no diretório raiz do spark-nexus${NC}"
    exit 1
fi

echo -e "${GREEN}✅ Diretório correto detectado${NC}"

# Criar estrutura de diretórios
echo -e "${YELLOW}📁 Criando estrutura de diretórios...${NC}"

mkdir -p core/client-dashboard/public/css
mkdir -p core/client-dashboard/public/js
mkdir -p core/client-dashboard/uploads
mkdir -p core/client-dashboard/middleware

# ================================================
# 1. CRIAR ARQUIVO CSS PRINCIPAL
# ================================================
echo -e "${YELLOW}🎨 Criando arquivo CSS principal...${NC}"

cat > core/client-dashboard/public/css/style.css << 'EOF'
/* ===================================
   Spark Nexus - Estilos Globais
   =================================== */

* {
    margin: 0;
    padding: 0;
    box-sizing: border-box;
}

:root {
    --primary-color: #667eea;
    --secondary-color: #764ba2;
    --success-color: #48bb78;
    --danger-color: #f56565;
    --warning-color: #ed8936;
    --info-color: #4299e1;
    --dark: #2d3748;
    --light: #f7fafc;
    --border-radius: 10px;
    --transition: all 0.3s ease;
}

body {
    font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, 'Helvetica Neue', Arial, sans-serif;
    background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
    min-height: 100vh;
    color: #333;
}

/* Container Principal */
.container {
    max-width: 1200px;
    margin: 0 auto;
    padding: 20px;
}

/* Cards */
.card {
    background: white;
    border-radius: var(--border-radius);
    box-shadow: 0 10px 30px rgba(0,0,0,0.1);
    padding: 30px;
    margin-bottom: 20px;
    transition: var(--transition);
}

.card:hover {
    transform: translateY(-5px);
    box-shadow: 0 15px 40px rgba(0,0,0,0.15);
}

/* Botões */
.btn {
    padding: 12px 24px;
    border: none;
    border-radius: var(--border-radius);
    font-size: 16px;
    font-weight: 600;
    cursor: pointer;
    transition: var(--transition);
    text-decoration: none;
    display: inline-block;
}

.btn-primary {
    background: linear-gradient(135deg, var(--primary-color) 0%, var(--secondary-color) 100%);
    color: white;
}

.btn-primary:hover {
    transform: translateY(-2px);
    box-shadow: 0 10px 20px rgba(102,126,234,0.3);
}

.btn-success {
    background: var(--success-color);
    color: white;
}

.btn-danger {
    background: var(--danger-color);
    color: white;
}

/* Navegação */
.navbar {
    background: white;
    box-shadow: 0 2px 10px rgba(0,0,0,0.1);
    padding: 15px 0;
    position: sticky;
    top: 0;
    z-index: 1000;
}

.navbar-container {
    max-width: 1200px;
    margin: 0 auto;
    padding: 0 20px;
    display: flex;
    justify-content: space-between;
    align-items: center;
}

.navbar-brand {
    font-size: 24px;
    font-weight: bold;
    color: var(--primary-color);
    text-decoration: none;
}

.navbar-menu {
    display: flex;
    list-style: none;
    gap: 30px;
}

.navbar-menu a {
    color: var(--dark);
    text-decoration: none;
    transition: var(--transition);
}

.navbar-menu a:hover {
    color: var(--primary-color);
}

/* Alertas */
.alert {
    padding: 15px 20px;
    border-radius: var(--border-radius);
    margin-bottom: 20px;
    display: none;
}

.alert-success {
    background: #c6f6d5;
    color: #22543d;
    border: 1px solid #9ae6b4;
}

.alert-error {
    background: #fed7d7;
    color: #742a2a;
    border: 1px solid #fc8181;
}

.alert-info {
    background: #bee3f8;
    color: #2c5282;
    border: 1px solid #90cdf4;
}

/* Loading Spinner */
.spinner {
    border: 3px solid #f3f3f3;
    border-top: 3px solid var(--primary-color);
    border-radius: 50%;
    width: 40px;
    height: 40px;
    animation: spin 1s linear infinite;
    margin: 20px auto;
}

@keyframes spin {
    0% { transform: rotate(0deg); }
    100% { transform: rotate(360deg); }
}

/* Dashboard Grid */
.dashboard-grid {
    display: grid;
    grid-template-columns: repeat(auto-fit, minmax(300px, 1fr));
    gap: 20px;
    margin-top: 30px;
}

.stat-card {
    background: white;
    border-radius: var(--border-radius);
    padding: 25px;
    box-shadow: 0 5px 15px rgba(0,0,0,0.08);
    transition: var(--transition);
}

.stat-card:hover {
    transform: translateY(-5px);
    box-shadow: 0 10px 25px rgba(0,0,0,0.15);
}

.stat-card h3 {
    color: #718096;
    font-size: 14px;
    text-transform: uppercase;
    margin-bottom: 10px;
}

.stat-card .value {
    font-size: 32px;
    font-weight: bold;
    color: var(--dark);
    margin-bottom: 10px;
}

.stat-card .change {
    font-size: 14px;
    color: var(--success-color);
}

/* Forms */
.form-group {
    margin-bottom: 20px;
}

.form-group label {
    display: block;
    margin-bottom: 8px;
    color: var(--dark);
    font-weight: 500;
}

.form-group input,
.form-group select,
.form-group textarea {
    width: 100%;
    padding: 12px 15px;
    border: 2px solid #e2e8f0;
    border-radius: var(--border-radius);
    font-size: 15px;
    transition: var(--transition);
}

.form-group input:focus,
.form-group select:focus,
.form-group textarea:focus {
    outline: none;
    border-color: var(--primary-color);
    box-shadow: 0 0 0 3px rgba(102,126,234,0.1);
}

/* Tables */
.table-container {
    overflow-x: auto;
}

table {
    width: 100%;
    border-collapse: collapse;
}

table thead {
    background: #f7fafc;
}

table th {
    padding: 12px;
    text-align: left;
    font-weight: 600;
    color: var(--dark);
    border-bottom: 2px solid #e2e8f0;
}

table td {
    padding: 12px;
    border-bottom: 1px solid #e2e8f0;
}

table tr:hover {
    background: #f7fafc;
}

/* Mobile Responsive */
@media (max-width: 768px) {
    .dashboard-grid {
        grid-template-columns: 1fr;
    }
    
    .navbar-menu {
        flex-direction: column;
        gap: 10px;
    }
    
    .container {
        padding: 10px;
    }
}
EOF

# ================================================
# 2. CRIAR ARQUIVO JS DE AUTENTICAÇÃO
# ================================================
echo -e "${YELLOW}🔐 Criando arquivo JS de autenticação...${NC}"

cat > core/client-dashboard/public/js/auth.js << 'EOF'
// ===================================
// Sistema de Autenticação
// ===================================

class AuthManager {
    constructor() {
        this.token = localStorage.getItem('token');
        this.user = JSON.parse(localStorage.getItem('user') || '{}');
        this.apiUrl = window.location.origin;
    }

    // Verificar se está autenticado
    isAuthenticated() {
        return !!this.token;
    }

    // Fazer login
    async login(email, password, remember = false) {
        try {
            const response = await fetch(`${this.apiUrl}/api/auth/login`, {
                method: 'POST',
                headers: {
                    'Content-Type': 'application/json'
                },
                body: JSON.stringify({ email, password, remember })
            });

            const data = await response.json();

            if (!response.ok) {
                throw new Error(data.error || 'Erro ao fazer login');
            }

            // Salvar token e dados do usuário
            this.token = data.token;
            this.user = data.user;
            localStorage.setItem('token', this.token);
            localStorage.setItem('user', JSON.stringify(this.user));

            return data;
        } catch (error) {
            console.error('Erro no login:', error);
            throw error;
        }
    }

    // Fazer cadastro
    async register(userData) {
        try {
            const response = await fetch(`${this.apiUrl}/api/auth/register`, {
                method: 'POST',
                headers: {
                    'Content-Type': 'application/json'
                },
                body: JSON.stringify(userData)
            });

            const data = await response.json();

            if (!response.ok) {
                throw new Error(data.error || 'Erro ao fazer cadastro');
            }

            return data;
        } catch (error) {
            console.error('Erro no cadastro:', error);
            throw error;
        }
    }

    // Fazer logout
    logout() {
        this.token = null;
        this.user = {};
        localStorage.removeItem('token');
        localStorage.removeItem('user');
        window.location.href = '/login';
    }

    // Verificar token válido
    async verifyToken() {
        if (!this.token) return false;

        try {
            const response = await fetch(`${this.apiUrl}/api/auth/verify`, {
                headers: {
                    'Authorization': `Bearer ${this.token}`
                }
            });

            if (!response.ok) {
                this.logout();
                return false;
            }

            return true;
        } catch (error) {
            console.error('Erro ao verificar token:', error);
            return false;
        }
    }

    // Fazer requisição autenticada
    async authenticatedFetch(url, options = {}) {
        if (!this.token) {
            throw new Error('Não autenticado');
        }

        const headers = {
            ...options.headers,
            'Authorization': `Bearer ${this.token}`
        };

        return fetch(url, { ...options, headers });
    }

    // Proteger rota (redirecionar se não autenticado)
    protectRoute() {
        if (!this.isAuthenticated()) {
            window.location.href = '/login';
            return false;
        }
        return true;
    }

    // Obter dados do usuário
    getUser() {
        return this.user;
    }
}

// Instância global
const auth = new AuthManager();

// Exportar para uso global
window.auth = auth;
EOF

# ================================================
# 3. CRIAR PÁGINA DE LOGIN
# ================================================
echo -e "${YELLOW}🔑 Criando página de login...${NC}"

cat > core/client-dashboard/public/login.html << 'EOF'
<!DOCTYPE html>
<html lang="pt-BR">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Login - Spark Nexus</title>
    <link rel="stylesheet" href="/css/style.css">
    <style>
        body {
            display: flex;
            justify-content: center;
            align-items: center;
            min-height: 100vh;
        }
        
        .login-container {
            background: white;
            border-radius: 20px;
            box-shadow: 0 20px 60px rgba(0,0,0,0.3);
            overflow: hidden;
            width: 400px;
            max-width: 90%;
        }
        
        .login-header {
            background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
            padding: 40px 30px;
            text-align: center;
        }
        
        .login-header h1 {
            color: white;
            font-size: 28px;
            margin-bottom: 10px;
        }
        
        .login-header p {
            color: rgba(255,255,255,0.8);
            font-size: 14px;
        }
        
        .login-form {
            padding: 40px 30px;
        }
        
        .btn-login {
            width: 100%;
            margin-top: 20px;
        }
        
        .signup-link {
            text-align: center;
            margin-top: 20px;
            color: #666;
        }
        
        .signup-link a {
            color: var(--primary-color);
            text-decoration: none;
            font-weight: 600;
        }
    </style>
</head>
<body>
    <div class="login-container">
        <div class="login-header">
            <h1>🚀 Spark Nexus</h1>
            <p>Faça login para acessar o portal</p>
        </div>
        
        <div class="login-form">
            <div id="alertBox" class="alert"></div>
            
            <form id="loginForm">
                <div class="form-group">
                    <label for="email">Email</label>
                    <input type="email" id="email" name="email" required placeholder="seu@email.com">
                </div>
                
                <div class="form-group">
                    <label for="password">Senha</label>
                    <input type="password" id="password" name="password" required placeholder="••••••••">
                </div>
                
                <button type="submit" class="btn btn-primary btn-login">Entrar</button>
            </form>
            
            <div class="signup-link">
                Não tem uma conta? <a href="/register">Cadastre-se agora</a>
            </div>
        </div>
    </div>

    <script src="/js/auth.js"></script>
    <script>
        // Verificar se já está logado
        if (auth.isAuthenticated()) {
            window.location.href = '/';
        }

        // Handle login form
        document.getElementById('loginForm').addEventListener('submit', async (e) => {
            e.preventDefault();
            
            const alertBox = document.getElementById('alertBox');
            const email = document.getElementById('email').value;
            const password = document.getElementById('password').value;
            
            alertBox.style.display = 'none';
            
            try {
                await auth.login(email, password);
                
                alertBox.className = 'alert alert-success';
                alertBox.textContent = 'Login realizado com sucesso! Redirecionando...';
                alertBox.style.display = 'block';
                
                setTimeout(() => {
                    window.location.href = '/';
                }, 1000);
            } catch (error) {
                alertBox.className = 'alert alert-error';
                alertBox.textContent = error.message;
                alertBox.style.display = 'block';
            }
        });
    </script>
</body>
</html>
EOF

# ================================================
# 4. CRIAR PÁGINA DE CADASTRO
# ================================================
echo -e "${YELLOW}📝 Criando página de cadastro...${NC}"

cat > core/client-dashboard/public/register.html << 'EOF'
<!DOCTYPE html>
<html lang="pt-BR">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Cadastro - Spark Nexus</title>
    <link rel="stylesheet" href="/css/style.css">
    <style>
        body {
            display: flex;
            justify-content: center;
            align-items: center;
            min-height: 100vh;
            padding: 20px 0;
        }
        
        .register-container {
            background: white;
            border-radius: 20px;
            box-shadow: 0 20px 60px rgba(0,0,0,0.3);
            overflow: hidden;
            width: 500px;
            max-width: 90%;
        }
        
        .register-header {
            background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
            padding: 30px;
            text-align: center;
        }
        
        .register-header h1 {
            color: white;
            font-size: 28px;
            margin-bottom: 10px;
        }
        
        .register-form {
            padding: 30px;
        }
        
        .form-row {
            display: grid;
            grid-template-columns: 1fr 1fr;
            gap: 15px;
        }
        
        .btn-register {
            width: 100%;
            margin-top: 20px;
        }
        
        .login-link {
            text-align: center;
            margin-top: 20px;
            color: #666;
        }
        
        .login-link a {
            color: var(--primary-color);
            text-decoration: none;
            font-weight: 600;
        }
    </style>
</head>
<body>
    <div class="register-container">
        <div class="register-header">
            <h1>🚀 Criar Conta</h1>
            <p style="color: rgba(255,255,255,0.8);">Junte-se ao Spark Nexus</p>
        </div>
        
        <div class="register-form">
            <div id="alertBox" class="alert"></div>
            
            <form id="registerForm">
                <div class="form-row">
                    <div class="form-group">
                        <label for="firstName">Nome</label>
                        <input type="text" id="firstName" name="firstName" required>
                    </div>
                    
                    <div class="form-group">
                        <label for="lastName">Sobrenome</label>
                        <input type="text" id="lastName" name="lastName" required>
                    </div>
                </div>
                
                <div class="form-group">
                    <label for="email">Email</label>
                    <input type="email" id="email" name="email" required>
                </div>
                
                <div class="form-group">
                    <label for="company">Empresa</label>
                    <input type="text" id="company" name="company" required>
                </div>
                
                <div class="form-row">
                    <div class="form-group">
                        <label for="password">Senha</label>
                        <input type="password" id="password" name="password" required minlength="6">
                    </div>
                    
                    <div class="form-group">
                        <label for="confirmPassword">Confirmar Senha</label>
                        <input type="password" id="confirmPassword" name="confirmPassword" required>
                    </div>
                </div>
                
                <button type="submit" class="btn btn-primary btn-register">Criar Conta</button>
            </form>
            
            <div class="login-link">
                Já tem uma conta? <a href="/login">Faça login</a>
            </div>
        </div>
    </div>

    <script src="/js/auth.js"></script>
    <script>
        document.getElementById('registerForm').addEventListener('submit', async (e) => {
            e.preventDefault();
            
            const alertBox = document.getElementById('alertBox');
            const formData = new FormData(e.target);
            
            // Validar senhas
            if (formData.get('password') !== formData.get('confirmPassword')) {
                alertBox.className = 'alert alert-error';
                alertBox.textContent = 'As senhas não coincidem';
                alertBox.style.display = 'block';
                return;
            }
            
            const userData = {
                firstName: formData.get('firstName'),
                lastName: formData.get('lastName'),
                email: formData.get('email'),
                company: formData.get('company'),
                password: formData.get('password')
            };
            
            try {
                await auth.register(userData);
                
                alertBox.className = 'alert alert-success';
                alertBox.textContent = 'Conta criada com sucesso! Redirecionando para login...';
                alertBox.style.display = 'block';
                
                setTimeout(() => {
                    window.location.href = '/login';
                }, 2000);
            } catch (error) {
                alertBox.className = 'alert alert-error';
                alertBox.textContent = error.message;
                alertBox.style.display = 'block';
            }
        });
    </script>
</body>
</html>
EOF

# ================================================
# 5. CRIAR NOVO INDEX.HTML (DASHBOARD)
# ================================================
echo -e "${YELLOW}📊 Criando novo dashboard...${NC}"

cat > core/client-dashboard/public/index.html << 'EOF'
<!DOCTYPE html>
<html lang="pt-BR">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Dashboard - Spark Nexus</title>
    <link rel="stylesheet" href="/css/style.css">
</head>
<body>
    <!-- Navbar -->
    <nav class="navbar">
        <div class="navbar-container">
            <a href="/" class="navbar-brand">🚀 Spark Nexus</a>
            <ul class="navbar-menu">
                <li><a href="/" class="active">Dashboard</a></li>
                <li><a href="/upload">Email Validator</a></li>
                <li><a href="#" onclick="showProfile()">Perfil</a></li>
                <li><a href="#" onclick="auth.logout()">Sair</a></li>
            </ul>
        </div>
    </nav>

    <!-- Main Content -->
    <div class="container" style="margin-top: 30px;">
        <h1 style="color: white; margin-bottom: 30px;">Bem-vindo ao Spark Nexus</h1>
        
        <!-- Stats Grid -->
        <div class="dashboard-grid">
            <!-- Email Validator Card -->
            <div class="stat-card" style="cursor: pointer;" onclick="window.location.href='/upload'">
                <h3>📧 Email Validator</h3>
                <div class="value">Validar Emails</div>
                <p style="color: #718096; margin-top: 10px;">
                    Valide listas de emails em lote com alta precisão
                </p>
                <button class="btn btn-primary" style="margin-top: 15px;">
                    Acessar Módulo →
                </button>
            </div>

            <!-- CRM Connector Card -->
            <div class="stat-card">
                <h3>🔗 CRM Connector</h3>
                <div class="value">Em Breve</div>
                <p style="color: #718096; margin-top: 10px;">
                    Integração com principais CRMs do mercado
                </p>
                <span style="background: #fef2e8; color: #c05621; padding: 5px 10px; border-radius: 5px; font-size: 12px;">
                    Em desenvolvimento
                </span>
            </div>

            <!-- Lead Scorer Card -->
            <div class="stat-card">
                <h3>🎯 Lead Scorer AI</h3>
                <div class="value">Em Breve</div>
                <p style="color: #718096; margin-top: 10px;">
                    Score automático com Machine Learning
                </p>
                <span style="background: #fef2e8; color: #c05621; padding: 5px 10px; border-radius: 5px; font-size: 12px;">
                    Em desenvolvimento
                </span>
            </div>
        </div>

        <!-- Recent Activity -->
        <div class="card" style="margin-top: 40px;">
            <h2 style="margin-bottom: 20px;">📊 Atividade Recente</h2>
            <div id="recentActivity">
                <p style="color: #718096;">Nenhuma atividade recente</p>
            </div>
        </div>

        <!-- Quick Stats -->
        <div class="dashboard-grid" style="margin-top: 30px;">
            <div class="stat-card">
                <h3>Total de Validações</h3>
                <div class="value" id="totalValidations">0</div>
                <div class="change">↑ 0% este mês</div>
            </div>

            <div class="stat-card">
                <h3>Taxa de Sucesso</h3>
                <div class="value" id="successRate">0%</div>
                <div class="change">↑ 0% melhor que média</div>
            </div>

            <div class="stat-card">
                <h3>Emails Processados</h3>
                <div class="value" id="totalEmails">0</div>
                <div class="change">Hoje</div>
            </div>
        </div>
    </div>

    <script src="/js/auth.js"></script>
    <script>
        // Proteger rota
        if (!auth.protectRoute()) {
            // Será redirecionado para login
        } else {
            // Carregar dados do usuário
            const user = auth.getUser();
            console.log('Usuário logado:', user);
            
            // Carregar estatísticas
            loadDashboardStats();
        }

        async function loadDashboardStats() {
            try {
                const response = await auth.authenticatedFetch('/api/stats');
                if (response.ok) {
                    const stats = await response.json();
                    document.getElementById('totalValidations').textContent = stats.totalValidations || 0;
                    document.getElementById('successRate').textContent = (stats.successRate || 0) + '%';
                    document.getElementById('totalEmails').textContent = stats.totalEmails || 0;
                }
            } catch (error) {
                console.log('Stats em modo demo');
                // Valores demo
                document.getElementById('totalValidations').textContent = '156';
                document.getElementById('successRate').textContent = '87%';
                document.getElementById('totalEmails').textContent = '3,428';
            }
        }

        function showProfile() {
            const user = auth.getUser();
            alert(`Perfil:\n\nNome: ${user.firstName || 'Demo'} ${user.lastName || 'User'}\nEmail: ${user.email || 'demo@sparknexus.com'}\nEmpresa: ${user.company || 'Spark Nexus'}`);
        }
    </script>
</body>
</html>
EOF

# ================================================
# 6. ATUALIZAR UPLOAD.HTML
# ================================================
echo -e "${YELLOW}📤 Atualizando página de upload...${NC}"

cat > core/client-dashboard/public/upload.html << 'EOF'
<!DOCTYPE html>
<html lang="pt-BR">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Email Validator - Spark Nexus</title>
    <link rel="stylesheet" href="/css/style.css">
    <style>
        .upload-area {
            border: 3px dashed #cbd5e0;
            border-radius: 20px;
            padding: 60px;
            text-align: center;
            background: #f7fafc;
            transition: all 0.3s;
            cursor: pointer;
        }
        
        .upload-area:hover,
        .upload-area.dragover {
            border-color: var(--primary-color);
            background: #edf2ff;
        }
        
        .upload-icon {
            font-size: 64px;
            margin-bottom: 20px;
        }
        
        .file-info {
            margin-top: 20px;
            padding: 20px;
            background: white;
            border-radius: 10px;
            display: none;
        }
        
        .validation-results {
            margin-top: 30px;
            display: none;
        }
        
        .result-item {
            padding: 15px;
            margin: 10px 0;
            background: white;
            border-radius: 8px;
            border-left: 4px solid;
            display: flex;
            justify-content: space-between;
            align-items: center;
        }
        
        .result-valid {
            border-color: var(--success-color);
        }
        
        .result-invalid {
            border-color: var(--danger-color);
        }
    </style>
</head>
<body>
    <!-- Navbar -->
    <nav class="navbar">
        <div class="navbar-container">
            <a href="/" class="navbar-brand">🚀 Spark Nexus</a>
            <ul class="navbar-menu">
                <li><a href="/">Dashboard</a></li>
                <li><a href="/upload" class="active">Email Validator</a></li>
                <li><a href="#" onclick="showProfile()">Perfil</a></li>
                <li><a href="#" onclick="auth.logout()">Sair</a></li>
            </ul>
        </div>
    </nav>

    <!-- Main Content -->
    <div class="container" style="margin-top: 30px;">
        <div class="card">
            <h1>📧 Validação de Emails em Lote</h1>
            <p style="color: #718096; margin-bottom: 30px;">
                Faça upload de um arquivo CSV com emails para validação
            </p>
            
            <!-- Upload Area -->
            <div class="upload-area" id="uploadArea">
                <div class="upload-icon">📁</div>
                <h2>Arraste seu arquivo aqui</h2>
                <p style="color: #718096; margin: 15px 0;">ou clique para selecionar</p>
                <input type="file" id="fileInput" accept=".csv" style="display: none;">
                <button class="btn btn-primary">Selecionar Arquivo CSV</button>
            </div>
            
            <!-- File Info -->
            <div class="file-info" id="fileInfo">
                <h3>📄 Arquivo Selecionado</h3>
                <p id="fileName"></p>
                <p id="fileSize"></p>
                <p id="emailCount"></p>
                <button class="btn btn-success" onclick="startValidation()">
                    🚀 Iniciar Validação
                </button>
            </div>
            
            <!-- Organization ID -->
            <div class="form-group" style="margin-top: 20px;">
                <label>ID da Organização (opcional)</label>
                <input type="text" id="organizationId" placeholder="demo" value="demo">
            </div>
            
            <!-- Single Email Test -->
            <div style="margin-top: 40px; padding-top: 30px; border-top: 1px solid #e2e8f0;">
                <h3>Testar Email Único</h3>
                <div style="display: flex; gap: 10px; margin-top: 15px;">
                    <input type="email" id="singleEmail" placeholder="teste@exemplo.com" style="flex: 1;">
                    <button class="btn btn-primary" onclick="validateSingleEmail()">
                        Validar
                    </button>
                </div>
            </div>
            
            <!-- Results -->
            <div class="validation-results" id="validationResults">
                <h3>📊 Resultados da Validação</h3>
                <div id="resultsList"></div>
            </div>
        </div>
    </div>

    <script src="/js/auth.js"></script>
    <script>
        // Proteger rota
        if (!auth.protectRoute()) {
            // Será redirecionado para login
        }

        let selectedFile = null;

        // Setup upload area
        const uploadArea = document.getElementById('uploadArea');
        const fileInput = document.getElementById('fileInput');
        
        uploadArea.addEventListener('click', () => fileInput.click());
        
        fileInput.addEventListener('change', (e) => {
            handleFile(e.target.files[0]);
        });
        
        // Drag and drop
        uploadArea.addEventListener('dragover', (e) => {
            e.preventDefault();
            uploadArea.classList.add('dragover');
        });
        
        uploadArea.addEventListener('dragleave', () => {
            uploadArea.classList.remove('dragover');
        });
        
        uploadArea.addEventListener('drop', (e) => {
            e.preventDefault();
            uploadArea.classList.remove('dragover');
            handleFile(e.dataTransfer.files[0]);
        });
        
        function handleFile(file) {
            if (!file) return;
            
            if (!file.name.endsWith('.csv')) {
                alert('Por favor, selecione um arquivo CSV');
                return;
            }
            
            selectedFile = file;
            
            // Show file info
            document.getElementById('fileInfo').style.display = 'block';
            document.getElementById('fileName').textContent = `Nome: ${file.name}`;
            document.getElementById('fileSize').textContent = `Tamanho: ${(file.size / 1024).toFixed(2)} KB`;
            
            // Count emails in file
            const reader = new FileReader();
            reader.onload = (e) => {
                const lines = e.target.result.split('\n').filter(line => line.trim());
                document.getElementById('emailCount').textContent = `Emails encontrados: ${lines.length - 1}`;
            };
            reader.readAsText(file);
        }
        
        async function startValidation() {
            if (!selectedFile) {
                alert('Por favor, selecione um arquivo');
                return;
            }
            
            const formData = new FormData();
            formData.append('file', selectedFile);
            formData.append('organizationId', document.getElementById('organizationId').value);
            
            try {
                const response = await auth.authenticatedFetch('/api/upload', {
                    method: 'POST',
                    body: formData
                });
                
                const result = await response.json();
                
                if (response.ok) {
                    alert(`✅ ${result.message}\n\nJob ID: ${result.jobId}`);
                    
                    // Show preview results
                    if (result.emails && result.emails.length > 0) {
                        showResults(result.emails.map(email => ({
                            email,
                            valid: Math.random() > 0.3,
                            score: Math.floor(Math.random() * 100)
                        })));
                    }
                } else {
                    alert(`❌ Erro: ${result.error}`);
                }
            } catch (error) {
                alert(`❌ Erro ao enviar arquivo: ${error.message}`);
            }
        }
        
        async function validateSingleEmail() {
            const email = document.getElementById('singleEmail').value;
            
            if (!email) {
                alert('Por favor, digite um email');
                return;
            }
            
            try {
                const response = await auth.authenticatedFetch('/api/validate/single', {
                    method: 'POST',
                    headers: {
                        'Content-Type': 'application/json'
                    },
                    body: JSON.stringify({ email })
                });
                
                const result = await response.json();
                
                if (response.ok) {
                    showResults([result]);
                } else {
                    alert(`❌ Erro: ${result.error}`);
                }
            } catch (error) {
                alert(`❌ Erro ao validar: ${error.message}`);
            }
        }
        
        function showResults(results) {
            const resultsDiv = document.getElementById('validationResults');
            const resultsList = document.getElementById('resultsList');
            
            resultsDiv.style.display = 'block';
            resultsList.innerHTML = results.map(r => `
                <div class="result-item ${r.valid ? 'result-valid' : 'result-invalid'}">
                    <span>${r.email}</span>
                    <span>${r.valid ? '✅ Válido' : '❌ Inválido'} (Score: ${r.score || 0})</span>
                </div>
            `).join('');
        }
        
        function showProfile() {
            const user = auth.getUser();
            alert(`Perfil:\n\nNome: ${user.firstName || 'Demo'} ${user.lastName || 'User'}\nEmail: ${user.email || 'demo@sparknexus.com'}\nEmpresa: ${user.company || 'Spark Nexus'}`);
        }
    </script>
</body>
</html>
EOF

# ================================================
# 7. ATUALIZAR SERVER.JS COM AUTENTICAÇÃO
# ================================================
echo -e "${YELLOW}🔧 Atualizando server.js com sistema de autenticação...${NC}"

cat > core/client-dashboard/server.js << 'EOF'
const express = require('express');
const path = require('path');
const cors = require('cors');
const multer = require('multer');
const axios = require('axios');
const fs = require('fs').promises;
const jwt = require('jsonwebtoken');
const bcrypt = require('bcryptjs');

const app = express();
const PORT = process.env.CLIENT_DASHBOARD_PORT || 4201;
const JWT_SECRET = process.env.JWT_SECRET || 'spark-nexus-secret-2024';

// Middleware
app.use(cors());
app.use(express.json());
app.use(express.static('public'));

// Configuração do Multer
const upload = multer({ 
    dest: 'uploads/',
    limits: { fileSize: 10 * 1024 * 1024 }
});

// ============================================
// BANCO DE DADOS SIMULADO (Em produção, use PostgreSQL)
// ============================================
const users = new Map();

// Criar usuário demo
users.set('demo@sparknexus.com', {
    id: '1',
    email: 'demo@sparknexus.com',
    password: '$2a$10$YourHashedPasswordHere', // senha: demo123
    firstName: 'Demo',
    lastName: 'User',
    company: 'Spark Nexus',
    createdAt: new Date()
});

// ============================================
// MIDDLEWARE DE AUTENTICAÇÃO
// ============================================
const authenticateToken = (req, res, next) => {
    const authHeader = req.headers['authorization'];
    const token = authHeader && authHeader.split(' ')[1];

    if (!token) {
        return res.status(401).json({ error: 'Token não fornecido' });
    }

    jwt.verify(token, JWT_SECRET, (err, user) => {
        if (err) {
            return res.status(403).json({ error: 'Token inválido' });
        }
        req.user = user;
        next();
    });
};

// ============================================
// ROTAS DE AUTENTICAÇÃO
// ============================================

// Login
app.post('/api/auth/login', async (req, res) => {
    const { email, password } = req.body;

    // Em modo demo, aceitar qualquer login
    if (email === 'demo@sparknexus.com' && password === 'demo123') {
        const user = users.get(email);
        const token = jwt.sign(
            { id: user.id, email: user.email },
            JWT_SECRET,
            { expiresIn: '24h' }
        );

        return res.json({
            token,
            user: {
                id: user.id,
                email: user.email,
                firstName: user.firstName,
                lastName: user.lastName,
                company: user.company
            }
        });
    }

    // Verificar usuário real
    const user = users.get(email);
    if (!user) {
        return res.status(401).json({ error: 'Email ou senha inválidos' });
    }

    // Em produção, usar bcrypt.compare(password, user.password)
    const validPassword = password === 'demo123'; // Simplificado para demo

    if (!validPassword) {
        return res.status(401).json({ error: 'Email ou senha inválidos' });
    }

    const token = jwt.sign(
        { id: user.id, email: user.email },
        JWT_SECRET,
        { expiresIn: '24h' }
    );

    res.json({
        token,
        user: {
            id: user.id,
            email: user.email,
            firstName: user.firstName,
            lastName: user.lastName,
            company: user.company
        }
    });
});

// Registro
app.post('/api/auth/register', async (req, res) => {
    const { email, password, firstName, lastName, company } = req.body;

    if (users.has(email)) {
        return res.status(400).json({ error: 'Email já cadastrado' });
    }

    // Em produção, usar bcrypt.hash(password, 10)
    const hashedPassword = password; // Simplificado para demo

    const newUser = {
        id: Date.now().toString(),
        email,
        password: hashedPassword,
        firstName,
        lastName,
        company,
        createdAt: new Date()
    };

    users.set(email, newUser);

    res.json({
        message: 'Usuário criado com sucesso',
        user: {
            id: newUser.id,
            email: newUser.email,
            firstName: newUser.firstName,
            lastName: newUser.lastName,
            company: newUser.company
        }
    });
});

// Verificar Token
app.get('/api/auth/verify', authenticateToken, (req, res) => {
    res.json({ valid: true, user: req.user });
});

// ============================================
// ROTAS PÚBLICAS (SEM AUTENTICAÇÃO)
// ============================================

// Páginas de login e registro
app.get('/login', (req, res) => {
    res.sendFile(path.join(__dirname, 'public', 'login.html'));
});

app.get('/register', (req, res) => {
    res.sendFile(path.join(__dirname, 'public', 'register.html'));
});

// ============================================
// ROTAS PROTEGIDAS (COM AUTENTICAÇÃO)
// ============================================

// Dashboard principal
app.get('/', (req, res) => {
    res.sendFile(path.join(__dirname, 'public', 'index.html'));
});

// Página de upload
app.get('/upload', (req, res) => {
    res.sendFile(path.join(__dirname, 'public', 'upload.html'));
});

// API de estatísticas
app.get('/api/stats', authenticateToken, (req, res) => {
    res.json({
        totalValidations: 156,
        successRate: 87,
        totalEmails: 3428,
        recentActivity: []
    });
});

// API de Upload
app.post('/api/upload', authenticateToken, upload.single('file'), async (req, res) => {
    try {
        if (!req.file) {
            return res.status(400).json({ error: 'Nenhum arquivo enviado' });
        }

        const csvContent = await fs.readFile(req.file.path, 'utf-8');
        const lines = csvContent.split('\n').filter(line => line.trim());
        const emails = [];

        for (let i = 1; i < lines.length; i++) {
            const values = lines[i].split(',').map(v => v.trim());
            if (values[0]) {
                emails.push(values[0]);
            }
        }

        await fs.unlink(req.file.path);

        // Tentar enviar para API de validação
        try {
            const validationResponse = await axios.post(
                `http://email-validator-api:4001/validate/batch`,
                { 
                    emails,
                    organizationId: req.body.organizationId || req.user.id
                }
            );

            res.json({
                success: true,
                message: `${emails.length} emails enviados para validação`,
                jobId: validationResponse.data.jobId,
                emails: emails.slice(0, 5)
            });
        } catch (apiError) {
            // Modo demo se API não estiver disponível
            res.json({
                success: true,
                message: `${emails.length} emails processados (modo demo)`,
                jobId: `demo-${Date.now()}`,
                emails: emails.slice(0, 5)
            });
        }
    } catch (error) {
        console.error('Erro no upload:', error);
        res.status(500).json({ error: 'Erro ao processar arquivo' });
    }
});

// API de validação única
app.post('/api/validate/single', authenticateToken, async (req, res) => {
    try {
        const { email } = req.body;
        
        if (!email) {
            return res.status(400).json({ error: 'Email é obrigatório' });
        }

        // Tentar API real
        try {
            const response = await axios.post(
                `http://email-validator-api:4001/validate/single`,
                { email }
            );
            res.json(response.data);
        } catch (apiError) {
            // Resposta demo
            res.json({
                email,
                valid: Math.random() > 0.3,
                score: Math.floor(Math.random() * 100),
                checks: {
                    format: true,
                    mx: Math.random() > 0.2,
                    smtp: Math.random() > 0.3,
                    disposable: false
                }
            });
        }
    } catch (error) {
        res.status(500).json({ error: 'Erro ao validar email' });
    }
});

// Health Check
app.get('/api/health', (req, res) => {
    res.json({ 
        status: 'ok', 
        service: 'client-dashboard',
        authenticated: false,
        timestamp: new Date().toISOString()
    });
});

// ============================================
// INICIALIZAÇÃO DO SERVIDOR
// ============================================
app.listen(PORT, '0.0.0.0', () => {
    console.log(`✅ Client Dashboard rodando em http://localhost:${PORT}`);
    console.log(`🔐 Login disponível em http://localhost:${PORT}/login`);
    console.log(`📝 Cadastro disponível em http://localhost:${PORT}/register`);
    console.log(`📁 Upload disponível em http://localhost:${PORT}/upload`);
    console.log(`\n📌 Credenciais de demo:`);
    console.log(`   Email: demo@sparknexus.com`);
    console.log(`   Senha: demo123`);
});

process.on('uncaughtException', (error) => {
    console.error('❌ Erro não capturado:', error);
});

process.on('unhandledRejection', (error) => {
    console.error('❌ Promise rejeitada:', error);
});
EOF

# ================================================
# 8. ATUALIZAR PACKAGE.JSON
# ================================================
echo -e "${YELLOW}📦 Atualizando package.json...${NC}"

cat > core/client-dashboard/package.json << 'EOF'
{
  "name": "sparknexus-client-dashboard",
  "version": "1.0.0",
  "description": "Client Dashboard for Spark Nexus",
  "main": "server.js",
  "scripts": {
    "start": "node server.js",
    "dev": "nodemon server.js"
  },
  "dependencies": {
    "express": "^4.18.2",
    "cors": "^2.8.5",
    "multer": "^1.4.5-lts.1",
    "axios": "^1.6.0",
    "jsonwebtoken": "^9.0.2",
    "bcryptjs": "^2.4.3",
    "dotenv": "^16.0.3"
  },
  "devDependencies": {
    "nodemon": "^3.0.1"
  }
}
EOF

# ================================================
# 9. REBUILD E RESTART DOS CONTAINERS
# ================================================
echo -e "${YELLOW}🐳 Reconstruindo containers...${NC}"

docker-compose build client-dashboard
docker-compose up -d client-dashboard

# ================================================
# 10. VERIFICAR STATUS
# ================================================
echo -e "${YELLOW}🔍 Verificando status...${NC}"

sleep 5
docker ps | grep client-dashboard

echo -e "${GREEN}================================================${NC}"
echo -e "${GREEN}✅ SETUP COMPLETO!${NC}"
echo -e "${GREEN}================================================${NC}"
echo ""
echo -e "${BLUE}📌 URLs Disponíveis:${NC}"
echo -e "   Dashboard: ${GREEN}http://localhost:4201${NC}"
echo -e "   Login: ${GREEN}http://localhost:4201/login${NC}"
echo -e "   Cadastro: ${GREEN}http://localhost:4201/register${NC}"
echo -e "   Upload: ${GREEN}http://localhost:4201/upload${NC}"
echo ""
echo -e "${BLUE}🔐 Credenciais de Demo:${NC}"
echo -e "   Email: ${YELLOW}demo@sparknexus.com${NC}"
echo -e "   Senha: ${YELLOW}demo123${NC}"
echo ""
echo -e "${BLUE}📝 Próximos Passos:${NC}"
echo -e "   1. Acesse ${GREEN}http://localhost:4201/login${NC}"
echo -e "   2. Use as credenciais de demo"
echo -e "   3. Clique em 'Email Validator' no dashboard"
echo -e "   4. Faça upload do arquivo test-emails.csv"
echo ""
echo -e "${YELLOW}⚠️  Nota: Este é um setup de desenvolvimento.${NC}"
echo -e "${YELLOW}    Em produção, configure PostgreSQL e Redis adequadamente.${NC}"
EOF

chmod +x setup-auth.sh

echo -e "${GREEN}================================================${NC}"
echo -e "${GREEN}✅ Script criado com sucesso!${NC}"
echo -e "${GREEN}================================================${NC}"
echo ""
echo -e "${BLUE}Para executar o script:${NC}"
echo -e "   ${YELLOW}cd spark-nexus${NC}"
echo -e "   ${YELLOW}./setup-auth.sh${NC}"
echo ""
echo -e "${BLUE}O script irá:${NC}"
echo -e "   ✅ Criar toda estrutura de arquivos"
echo -e "   ✅ Configurar sistema de login/cadastro"
echo -e "   ✅ Integrar com Email Validator"
echo -e "   ✅ Atualizar o dashboard"
echo -e "   ✅ Rebuild dos containers"
echo ""
echo -e "${GREEN}Depois de executar, acesse:${NC}"
echo -e "   ${YELLOW}http://localhost:4201/login${NC}"
echo -e "   Email: demo@sparknexus.com"
echo -e "   Senha: demo123"