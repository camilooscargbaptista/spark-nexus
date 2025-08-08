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
