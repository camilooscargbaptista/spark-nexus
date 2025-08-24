/**
 * Header Universal do SparkNexus
 * Componente reutilizável para todas as telas do sistema
 */

class SparkNexusHeader {
    constructor(options = {}) {
        this.currentPage = options.currentPage || '';
        this.breadcrumb = options.breadcrumb || [];
        this.showWelcomeHeader = options.showWelcomeHeader !== false; // true por padrão
        this.welcomeTitle = options.welcomeTitle || '';
        this.welcomeSubtitle = options.welcomeSubtitle || '';
    }

    /**
     * Renderiza o HTML do header completo
     */
    render() {
        const navbar = this.renderNavbar();
        const breadcrumb = this.renderBreadcrumb();
        const welcomeHeader = this.showWelcomeHeader ? this.renderWelcomeHeader() : '';

        return `
            ${navbar}
            <div class="container" style="margin-top: 30px;">
                ${breadcrumb}
                ${welcomeHeader}
            </div>
        `;
    }

    /**
     * Renderiza a navbar
     */
    renderNavbar() {
        return `
            <!-- Navbar -->
            <nav class="navbar">
                <div class="navbar-container">
                    <a href="/" class="navbar-brand">
                        <i class="fas fa-bolt"></i>
                        SparkNexus
                    </a>
                    <ul class="navbar-menu">
                        <li><a href="/" title="Dashboard" ${this.currentPage === 'dashboard' ? 'class="active"' : ''}><i class="fas fa-home"></i> Dashboard</a></li>
                        <li><a href="/upload" title="Validação de Emails" ${this.currentPage === 'validation' ? 'class="active"' : ''}><i class="fas fa-envelope-open-text"></i> Validação</a></li>
                        <li><a href="/validation-history" title="Histórico" ${this.currentPage === 'history' ? 'class="active"' : ''}><i class="fas fa-history"></i> Histórico</a></li>
                        <li><a href="/checkout" title="Planos" ${this.currentPage === 'checkout' ? 'class="active"' : ''}><i class="fas fa-credit-card"></i> Planos</a></li>
                        <li><a href="/profile" title="Perfil"  ${this.currentPage === 'profile' ? 'class="active"' : ''}><i class="fas fa-user-circle"></i> Perfil</a></li>
                    </ul>
                </div>
            </nav>
        `;
    }

    /**
     * Renderiza o breadcrumb se fornecido
     */
    renderBreadcrumb() {
        if (!this.breadcrumb || this.breadcrumb.length === 0) {
            return '';
        }

        const items = this.breadcrumb.map((item, index) => {
            const isLast = index === this.breadcrumb.length - 1;
            const icon = item.icon ? `<i class="${item.icon}"></i> ` : '';

            if (isLast) {
                return `
                    <li class="breadcrumb-item active" aria-current="page">
                        ${icon}${item.text}
                    </li>
                `;
            } else {
                return `
                    <li class="breadcrumb-item">
                        <a href="${item.href}">
                            ${icon}${item.text}
                        </a>
                    </li>
                `;
            }
        }).join('');

        return `
            <!-- Breadcrumb -->
            <nav aria-label="breadcrumb">
                <ol class="breadcrumb custom-breadcrumb">
                    ${items}
                </ol>
            </nav>
        `;
    }

    /**
     * Renderiza o welcome header
     */
    renderWelcomeHeader() {
        return `
            <!-- Welcome Header -->
            <div class="welcome-header">
                <div class="welcome-text">
                    <h1 id="welcomeMessage">${this.welcomeTitle || 'Bem-vindo ao SparkNexus! 👋'}</h1>
                    <p id="userInfo">${this.welcomeSubtitle || 'Carregando informações do usuário...'}</p>
                </div>
            </div>
        `;
    }

    /**
     * Injeta o header no início do body
     */
    inject() {
        const headerHTML = this.render();
        document.body.insertAdjacentHTML('afterbegin', headerHTML);

        // Carregar informações do usuário se showWelcomeHeader for true
        if (this.showWelcomeHeader) {
            this.loadUserInfo();
        }
    }

    /**
     * Carrega informações do usuário
     */
    async loadUserInfo() {
        try {
            const response = await auth.authenticatedFetch('/api/user/profile');
            if (response.ok) {
                const data = await response.json();
                const user = data.user;
                const firstName = user.first_name || user.firstName || user.email.split('@')[0];

                // Atualizar welcome header
                const welcomeMessage = document.getElementById('welcomeMessage');
                const userInfo = document.getElementById('userInfo');

                if (welcomeMessage && !this.welcomeTitle) {
                    welcomeMessage.textContent = `Olá, ${firstName}! 👋`;
                }

                if (userInfo && !this.welcomeSubtitle) {
                    userInfo.textContent = `${user.email} • ${user.company || 'SparkNexus'}`;
                }
            }
        } catch (error) {
            console.error('Erro ao carregar perfil:', error);
        }
    }
}

/**
 * Sistema de Modais Profissionais
 */
class SparkNexusModal {
    constructor() {
        this.isOpen = false;
        this.currentModal = null;
    }

    /**
     * Cria e exibe um modal
     */
    show(options = {}) {
        const {
            title = 'SparkNexus',
            message = '',
            type = 'info', // info, success, warning, error, confirm
            confirmText = 'OK',
            cancelText = 'Cancelar',
            showCancel = false,
            onConfirm = null,
            onCancel = null,
            size = 'medium' // small, medium, large
        } = options;

        // Remover modal existente se houver
        this.close();

        // Criar overlay
        const overlay = document.createElement('div');
        overlay.className = 'spark-modal-overlay';
        overlay.innerHTML = `
            <div class="spark-modal ${size}">
                <div class="spark-modal-header">
                    <div class="spark-modal-title">
                        <i class="fas ${this.getIcon(type)}"></i>
                        ${title}
                    </div>
                    <button class="spark-modal-close" type="button">
                        <i class="fas fa-times"></i>
                    </button>
                </div>
                <div class="spark-modal-body ${type}">
                    ${message}
                </div>
                <div class="spark-modal-footer">
                    ${showCancel ? `<button class="spark-btn spark-btn-secondary spark-modal-cancel">${cancelText}</button>` : ''}
                    <button class="spark-btn spark-btn-primary spark-modal-confirm">${confirmText}</button>
                </div>
            </div>
        `;

        // Adicionar ao DOM
        document.body.appendChild(overlay);
        this.currentModal = overlay;
        this.isOpen = true;

        // Event listeners
        overlay.querySelector('.spark-modal-close').addEventListener('click', () => {
            this.close();
            if (onCancel) onCancel();
        });

        overlay.querySelector('.spark-modal-confirm').addEventListener('click', () => {
            this.close();
            if (onConfirm) onConfirm();
        });

        if (showCancel) {
            overlay.querySelector('.spark-modal-cancel').addEventListener('click', () => {
                this.close();
                if (onCancel) onCancel();
            });
        }

        // Fechar ao clicar fora
        overlay.addEventListener('click', (e) => {
            if (e.target === overlay) {
                this.close();
                if (onCancel) onCancel();
            }
        });

        // Animação de entrada
        requestAnimationFrame(() => {
            overlay.classList.add('show');
        });

        return this;
    }

    /**
     * Fecha o modal atual
     */
    close() {
        if (this.currentModal) {
            this.currentModal.classList.remove('show');
            setTimeout(() => {
                if (this.currentModal && this.currentModal.parentNode) {
                    this.currentModal.parentNode.removeChild(this.currentModal);
                }
                this.currentModal = null;
                this.isOpen = false;
            }, 300);
        }
    }

    /**
     * Retorna o ícone baseado no tipo
     */
    getIcon(type) {
        const icons = {
            info: 'fa-info-circle',
            success: 'fa-check-circle',
            warning: 'fa-exclamation-triangle',
            error: 'fa-times-circle',
            confirm: 'fa-question-circle'
        };
        return icons[type] || icons.info;
    }

    /**
     * Métodos de conveniência
     */
    alert(message, title = 'Aviso') {
        return this.show({
            title,
            message,
            type: 'info'
        });
    }

    success(message, title = 'Sucesso') {
        return this.show({
            title,
            message,
            type: 'success'
        });
    }

    error(message, title = 'Erro') {
        return this.show({
            title,
            message,
            type: 'error'
        });
    }

    warning(message, title = 'Atenção') {
        return this.show({
            title,
            message,
            type: 'warning'
        });
    }

    confirm(message, title = 'Confirmação') {
        return new Promise((resolve) => {
            this.show({
                title,
                message,
                type: 'confirm',
                showCancel: true,
                confirmText: 'OK',
                cancelText: 'Cancelar',
                onConfirm: () => resolve(true),
                onCancel: () => resolve(false)
            });
        });
    }
}

// Instância global
window.SparkModal = new SparkNexusModal();

/**
 * Função utilitária para mostrar perfil
 */
function showProfile() {
    SparkModal.alert('Função de perfil em desenvolvimento', 'Perfil');
}

/**
 * CSS necessário para o header (será injetado automaticamente)
 */
const HEADER_CSS = `
<style>
    .navbar {
        background: rgba(255, 255, 255, 0.95);
        backdrop-filter: blur(20px);
        box-shadow: 0 4px 6px -1px rgb(0 0 0 / 0.1), 0 2px 4px -2px rgb(0 0 0 / 0.1);
        padding: 1rem 0;
        position: sticky;
        top: 0;
        z-index: 1000;
        border-bottom: 1px solid rgba(255, 255, 255, 0.2);
    }

    .navbar-container {
        max-width: 1200px;
        margin: 0 auto;
        padding: 0 1.5rem;
        display: flex;
        justify-content: center;
        align-items: center;
        gap: 3rem;
    }

    .navbar-brand {
        font-size: 1.5rem;
        font-weight: 800;
        color: var(--primary-600, #2563eb);
        text-decoration: none;
        display: flex;
        align-items: center;
        gap: 0.5rem;
    }

    .navbar-brand i {
        font-size: 1.25rem;
    }

    .navbar-menu {
        display: flex;
        list-style: none;
        gap: 2rem;
        margin: 0;
        padding: 0;
    }

    .navbar-menu a {
        color: var(--gray-700, #374151);
        text-decoration: none;
        transition: all 0.2s ease;
        font-weight: 500;
        display: flex;
        align-items: center;
        gap: 0.5rem;
        padding: 0.5rem 1rem;
        border-radius: 0.5rem;
        font-size: 0.9rem;
    }

    .navbar-menu a:hover,
    .navbar-menu a.active {
        color: var(--primary-600, #2563eb);
        background: rgba(37, 99, 235, 0.1);
    }

    .custom-breadcrumb {
        background: rgba(255, 255, 255, 0.95);
        backdrop-filter: blur(20px);
        border-radius: var(--radius-lg, 0.75rem);
        padding: 1rem 1.5rem;
        margin-bottom: 1.5rem;
        box-shadow: var(--shadow-md, 0 4px 6px -1px rgb(0 0 0 / 0.1));
        border: 1px solid rgba(255, 255, 255, 0.2);
        display: flex;
        list-style: none;
        margin: 0 0 1.5rem 0;
    }

    .breadcrumb-item {
        display: flex;
        align-items: center;
    }

    .breadcrumb-item:not(:last-child)::after {
        content: "/";
        margin: 0 0.75rem;
        color: var(--gray-400, #9ca3af);
        font-weight: normal;
    }

    .breadcrumb-item a {
        color: var(--primary-600, #2563eb);
        text-decoration: none;
        font-weight: 500;
        display: flex;
        align-items: center;
        gap: 0.5rem;
    }

    .breadcrumb-item a:hover {
        color: var(--primary-700, #1d4ed8);
    }

    .breadcrumb-item.active {
        color: var(--gray-600, #4b5563);
        display: flex;
        align-items: center;
        gap: 0.5rem;
    }

    .welcome-header {
        background: rgba(255, 255, 255, 0.95);
        backdrop-filter: blur(20px);
        border-radius: var(--radius-xl, 1rem);
        padding: 2rem;
        margin-bottom: 2rem;
        display: flex;
        justify-content: space-between;
        align-items: center;
        box-shadow: var(--shadow-xl, 0 20px 25px -5px rgb(0 0 0 / 0.1));
        border: 1px solid rgba(255, 255, 255, 0.2);
    }

    .welcome-text h1 {
        margin: 0;
        font-size: 2rem;
        font-weight: 700;
        color: var(--gray-900, #111827);
    }

    .welcome-text p {
        margin: 0.5rem 0 0 0;
        color: var(--gray-600, #4b5563);
        font-size: 1rem;
    }

    @media (max-width: 768px) {
        .navbar-container {
            flex-direction: column;
            gap: 1rem;
        }
        
        .navbar-menu {
            gap: 1rem;
            flex-wrap: wrap;
            justify-content: center;
        }

        .navbar-menu a {
            padding: 0.25rem 0.5rem;
            font-size: 0.8rem;
        }

        .navbar-brand {
            font-size: 1.25rem;
        }

        .welcome-header {
            padding: 1.5rem;
        }

        .welcome-text h1 {
            font-size: 1.5rem;
        }
    }

    /* Modais Profissionais */
    .spark-modal-overlay {
        position: fixed;
        top: 0;
        left: 0;
        right: 0;
        bottom: 0;
        background: rgba(0, 0, 0, 0.6);
        backdrop-filter: blur(4px);
        display: flex;
        align-items: center;
        justify-content: center;
        z-index: 9999;
        opacity: 0;
        transition: all 0.3s ease;
        padding: 1rem;
    }

    .spark-modal-overlay.show {
        opacity: 1;
    }

    .spark-modal {
        background: white;
        border-radius: var(--radius-xl, 1rem);
        box-shadow: 0 25px 50px -12px rgba(0, 0, 0, 0.25);
        max-width: 90vw;
        max-height: 90vh;
        overflow: hidden;
        transform: scale(0.95);
        transition: all 0.3s ease;
        border: 1px solid rgba(255, 255, 255, 0.2);
    }

    .spark-modal-overlay.show .spark-modal {
        transform: scale(1);
    }

    .spark-modal.small { width: 400px; }
    .spark-modal.medium { width: 500px; }
    .spark-modal.large { width: 700px; }

    .spark-modal-header {
        padding: 1.5rem;
        border-bottom: 1px solid var(--gray-200, #e5e7eb);
        display: flex;
        align-items: center;
        justify-content: space-between;
        background: var(--gray-50, #f9fafb);
    }

    .spark-modal-title {
        font-size: 1.25rem;
        font-weight: 600;
        color: var(--gray-900, #111827);
        display: flex;
        align-items: center;
        gap: 0.75rem;
    }

    .spark-modal-title i {
        font-size: 1.5rem;
    }

    .spark-modal-title i.fa-info-circle { color: var(--primary-500, #3b82f6); }
    .spark-modal-title i.fa-check-circle { color: var(--success-500, #10b981); }
    .spark-modal-title i.fa-exclamation-triangle { color: var(--warning-500, #f59e0b); }
    .spark-modal-title i.fa-times-circle { color: var(--error-500, #ef4444); }
    .spark-modal-title i.fa-question-circle { color: var(--primary-500, #3b82f6); }

    .spark-modal-close {
        background: none;
        border: none;
        color: var(--gray-400, #9ca3af);
        cursor: pointer;
        padding: 0.5rem;
        border-radius: var(--radius-md, 0.5rem);
        transition: all 0.2s ease;
        display: flex;
        align-items: center;
        justify-content: center;
        width: 2rem;
        height: 2rem;
    }

    .spark-modal-close:hover {
        background: var(--gray-100, #f3f4f6);
        color: var(--gray-600, #4b5563);
    }

    .spark-modal-body {
        padding: 1.5rem;
        color: var(--gray-700, #374151);
        line-height: 1.6;
        font-size: 1rem;
    }

    .spark-modal-body.info {
        border-left: 4px solid var(--primary-500, #3b82f6);
        background: var(--primary-50, #eff6ff);
    }

    .spark-modal-body.success {
        border-left: 4px solid var(--success-500, #10b981);
        background: var(--success-50, #ecfdf5);
    }

    .spark-modal-body.warning {
        border-left: 4px solid var(--warning-500, #f59e0b);
        background: var(--warning-50, #fffbeb);
    }

    .spark-modal-body.error {
        border-left: 4px solid var(--error-500, #ef4444);
        background: var(--error-50, #fef2f2);
    }

    .spark-modal-body.confirm {
        border-left: 4px solid var(--primary-500, #3b82f6);
        background: var(--primary-50, #eff6ff);
    }

    .spark-modal-footer {
        padding: 1.5rem;
        border-top: 1px solid var(--gray-200, #e5e7eb);
        display: flex;
        gap: 1rem;
        justify-content: flex-end;
        background: var(--gray-50, #f9fafb);
    }

    .spark-btn {
        display: inline-flex;
        align-items: center;
        justify-content: center;
        gap: 0.5rem;
        padding: 0.75rem 1.5rem;
        border: none;
        border-radius: var(--radius-md, 0.5rem);
        font-size: 0.875rem;
        font-weight: 600;
        cursor: pointer;
        transition: all 0.2s ease;
        text-decoration: none;
        font-family: inherit;
        min-width: 80px;
    }

    .spark-btn-primary {
        background: linear-gradient(135deg, var(--primary-500, #3b82f6) 0%, var(--primary-600, #2563eb) 100%);
        color: white;
        box-shadow: 0 1px 2px 0 rgb(0 0 0 / 0.05);
    }

    .spark-btn-primary:hover {
        transform: translateY(-1px);
        box-shadow: 0 4px 6px -1px rgb(0 0 0 / 0.1);
    }

    .spark-btn-secondary {
        background: white;
        color: var(--gray-700, #374151);
        border: 1px solid var(--gray-300, #d1d5db);
    }

    .spark-btn-secondary:hover {
        background: var(--gray-50, #f9fafb);
        border-color: var(--gray-400, #9ca3af);
    }

    @media (max-width: 768px) {
        .spark-modal {
            margin: 1rem;
            width: calc(100vw - 2rem) !important;
            max-width: none;
        }

        .spark-modal-footer {
            flex-direction: column-reverse;
        }

        .spark-btn {
            width: 100%;
        }
    }
</style>
`;

/**
 * Injeta o CSS necessário
 */
function injectHeaderCSS() {
    if (!document.querySelector('#spark-nexus-header-css')) {
        const style = document.createElement('div');
        style.id = 'spark-nexus-header-css';
        style.innerHTML = HEADER_CSS;
        document.head.appendChild(style);
    }
}

// Auto-injetar CSS quando o script for carregado
if (typeof document !== 'undefined') {
    injectHeaderCSS();
}

// Exportar para uso global
window.SparkNexusHeader = SparkNexusHeader;
