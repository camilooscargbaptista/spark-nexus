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
      console.log('login: ', password);

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
            this.logout();
            throw new Error('Não autenticado');
        }

        const headers = {
            ...options.headers,
            'Authorization': `Bearer ${this.token}`
        };

        try {
            const response = await fetch(url, { ...options, headers });
            
            // Se token expirado ou não autorizado, fazer logout
            if (response.status === 401 || response.status === 403) {
                const data = await response.json().catch(() => ({}));
                
                // Verificar se é erro de token expirado
                if (data.error && (data.error.includes('expired') || data.error.includes('invalid'))) {
                    this.logout();
                    throw new Error('Sessão expirada. Redirecionando para login...');
                }
            }
            
            return response;
        } catch (error) {
            // Se erro de rede ou token inválido, tentar logout
            if (error.message.includes('expired') || error.message.includes('invalid')) {
                this.logout();
            }
            throw error;
        }
    }

    // Proteger rota (redirecionar se não autenticado)
    protectRoute() {
        if (!this.isAuthenticated()) {
            window.location.href = '/login';
            return false;
        }
        return true;
    }

    // Verificar autenticação automaticamente ao carregar página
    async autoCheckAuth() {
        // Páginas públicas que não precisam de autenticação
        const publicPages = ['/login', '/register', '/404'];
        const currentPath = window.location.pathname;
        
        // Se está em página pública, não verificar
        if (publicPages.some(page => currentPath.includes(page))) {
            return true;
        }

        // Se não tem token, redirecionar
        if (!this.isAuthenticated()) {
            this.logout();
            return false;
        }

        // Verificar se token ainda é válido
        const isValid = await this.verifyToken();
        if (!isValid) {
            this.logout();
            return false;
        }

        return true;
    }

    // Inicializar interceptador global para todas as requisições
    initGlobalErrorHandler() {
        // Interceptar erros globais de fetch
        const originalFetch = window.fetch;
        window.fetch = async (url, options = {}) => {
            try {
                const response = await originalFetch(url, options);
                
                // Se requisição com token e retornou 401/403
                if (options.headers && options.headers.Authorization && 
                    (response.status === 401 || response.status === 403)) {
                    
                    const data = await response.clone().json().catch(() => ({}));
                    
                    if (data.error && (data.error.includes('expired') || data.error.includes('invalid'))) {
                        this.logout();
                    }
                }
                
                return response;
            } catch (error) {
                throw error;
            }
        };
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

// Inicializar sistema de autenticação automaticamente
document.addEventListener('DOMContentLoaded', async () => {
    // Inicializar interceptador global
    auth.initGlobalErrorHandler();
    
    // Verificar autenticação automaticamente
    await auth.autoCheckAuth();
});
