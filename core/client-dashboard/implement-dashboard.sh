#!/bin/bash

# Script para implementar o Dashboard completo do Spark Nexus
# Execute dentro da pasta client-dashboard

echo "🚀 Implementando Dashboard do Spark Nexus..."
echo ""

# Cores
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Verificar se está na pasta correta
if [ ! -f "angular.json" ]; then
    echo "❌ Execute este script dentro da pasta client-dashboard"
    exit 1
fi

echo -e "${BLUE}📝 Atualizando app.module.ts...${NC}"

# Atualizar app.module.ts com todos os imports necessários
cat > src/app/app-module.ts << 'EOF'
import { NgModule } from '@angular/core';
import { BrowserModule } from '@angular/platform-browser';
import { BrowserAnimationsModule } from '@angular/platform-browser/animations';
import { HttpClientModule, HTTP_INTERCEPTORS } from '@angular/common/http';
import { FormsModule, ReactiveFormsModule } from '@angular/forms';

import { AppRoutingModule } from './app-routing-module';
import { AppComponent } from './app';

// Material Module
import { MaterialModule } from './shared/material.module';

// Core Components
import { LayoutComponent } from './core/components/layout/layout';
import { SidebarComponent } from './core/components/sidebar/sidebar';
import { HeaderComponent } from './core/components/header/header';

// Feature Components
import { DashboardComponent } from './features/dashboard/dashboard';
import { ModulesComponent } from './features/modules/modules';
import { EmailValidatorComponent } from './features/email-validator/email-validator';
import { BillingComponent } from './features/billing/billing';
import { SettingsComponent } from './features/settings/settings';
import { LoginComponent } from './features/login/login';

// Interceptors
import { AuthInterceptor } from './core/interceptors/auth-interceptor';
import { ErrorInterceptor } from './core/interceptors/error-interceptor';

@NgModule({
  declarations: [
    AppComponent,
    LayoutComponent,
    SidebarComponent,
    HeaderComponent,
    DashboardComponent,
    ModulesComponent,
    EmailValidatorComponent,
    BillingComponent,
    SettingsComponent,
    LoginComponent
  ],
  imports: [
    BrowserModule,
    BrowserAnimationsModule,
    HttpClientModule,
    FormsModule,
    ReactiveFormsModule,
    AppRoutingModule,
    MaterialModule
  ],
  providers: [
    { provide: HTTP_INTERCEPTORS, useClass: AuthInterceptor, multi: true },
    { provide: HTTP_INTERCEPTORS, useClass: ErrorInterceptor, multi: true }
  ],
  bootstrap: [AppComponent]
})
export class AppModule { }
EOF

echo -e "${GREEN}✅ app.module.ts atualizado${NC}"
echo ""

echo -e "${BLUE}🛣️ Configurando rotas...${NC}"

# Configurar rotas
cat > src/app/app-routing-module.ts << 'EOF'
import { NgModule } from '@angular/core';
import { RouterModule, Routes } from '@angular/router';
import { LayoutComponent } from './core/components/layout/layout';
import { LoginComponent } from './features/login/login';
import { DashboardComponent } from './features/dashboard/dashboard';
import { ModulesComponent } from './features/modules/modules';
import { EmailValidatorComponent } from './features/email-validator/email-validator';
import { BillingComponent } from './features/billing/billing';
import { SettingsComponent } from './features/settings/settings';
import { AuthGuard } from './core/guards/auth-guard';

const routes: Routes = [
  {
    path: 'login',
    component: LoginComponent
  },
  {
    path: '',
    component: LayoutComponent,
    canActivate: [AuthGuard],
    children: [
      { path: 'dashboard', component: DashboardComponent },
      { path: 'modules', component: ModulesComponent },
      { path: 'email-validator', component: EmailValidatorComponent },
      { path: 'billing', component: BillingComponent },
      { path: 'settings', component: SettingsComponent },
      { path: '', redirectTo: 'dashboard', pathMatch: 'full' }
    ]
  },
  { path: '**', redirectTo: 'dashboard' }
];

@NgModule({
  imports: [RouterModule.forRoot(routes)],
  exports: [RouterModule]
})
export class AppRoutingModule { }
EOF

echo -e "${GREEN}✅ Rotas configuradas${NC}"
echo ""

echo -e "${BLUE}🎨 Implementando Layout Component...${NC}"

# Layout Component
cat > src/app/core/components/layout/layout.ts << 'EOF'
import { Component } from '@angular/core';

@Component({
  selector: 'app-layout',
  templateUrl: './layout.html',
  styleUrls: ['./layout.scss']
})
export class LayoutComponent {
  sidebarOpen = true;

  toggleSidebar(): void {
    this.sidebarOpen = !this.sidebarOpen;
  }
}
EOF

cat > src/app/core/components/layout/layout.html << 'EOF'
<div class="app-container">
  <app-sidebar [isOpen]="sidebarOpen"></app-sidebar>
  <div class="main-content" [class.sidebar-closed]="!sidebarOpen">
    <app-header (toggleSidebar)="toggleSidebar()"></app-header>
    <div class="content">
      <router-outlet></router-outlet>
    </div>
  </div>
</div>
EOF

cat > src/app/core/components/layout/layout.scss << 'EOF'
.app-container {
  display: flex;
  height: 100vh;
  background: #f5f7fa;
}

.main-content {
  flex: 1;
  display: flex;
  flex-direction: column;
  margin-left: 260px;
  transition: margin-left 0.3s ease;

  &.sidebar-closed {
    margin-left: 0;
  }
}

.content {
  flex: 1;
  padding: 24px;
  overflow-y: auto;
  background: #f5f7fa;
}
EOF

echo -e "${GREEN}✅ Layout implementado${NC}"
echo ""

echo -e "${BLUE}📦 Implementando Sidebar...${NC}"

# Sidebar Component
cat > src/app/core/components/sidebar/sidebar.ts << 'EOF'
import { Component, Input } from '@angular/core';
import { Router } from '@angular/router';

interface MenuItem {
  icon: string;
  label: string;
  route: string;
  badge?: number;
}

@Component({
  selector: 'app-sidebar',
  templateUrl: './sidebar.html',
  styleUrls: ['./sidebar.scss']
})
export class SidebarComponent {
  @Input() isOpen = true;

  menuItems: MenuItem[] = [
    { icon: 'dashboard', label: 'Dashboard', route: '/dashboard' },
    { icon: 'widgets', label: 'Módulos', route: '/modules', badge: 3 },
    { icon: 'email', label: 'Email Validator', route: '/email-validator' },
    { icon: 'credit_card', label: 'Faturamento', route: '/billing' },
    { icon: 'settings', label: 'Configurações', route: '/settings' }
  ];

  organization = {
    name: 'Demo Company',
    plan: 'Growth'
  };

  constructor(private router: Router) {}

  navigate(route: string): void {
    this.router.navigate([route]);
  }

  isActive(route: string): boolean {
    return this.router.url === route;
  }
}
EOF

cat > src/app/core/components/sidebar/sidebar.html << 'EOF'
<nav class="sidebar" [class.closed]="!isOpen">
  <div class="logo">
    <span class="logo-icon">🚀</span>
    <span class="logo-text">Spark Nexus</span>
  </div>

  <div class="menu">
    <div class="menu-item"
         *ngFor="let item of menuItems"
         [class.active]="isActive(item.route)"
         (click)="navigate(item.route)">
      <mat-icon class="menu-icon">{{ item.icon }}</mat-icon>
      <span class="menu-label">{{ item.label }}</span>
      <span class="menu-badge" *ngIf="item.badge">{{ item.badge }}</span>
    </div>
  </div>

  <div class="sidebar-footer">
    <div class="organization">
      <div class="org-name">{{ organization.name }}</div>
      <div class="org-plan">Plano {{ organization.plan }}</div>
    </div>
  </div>
</nav>
EOF

cat > src/app/core/components/sidebar/sidebar.scss << 'EOF'
.sidebar {
  width: 260px;
  background: linear-gradient(180deg, #1e293b 0%, #0f172a 100%);
  color: white;
  display: flex;
  flex-direction: column;
  height: 100vh;
  position: fixed;
  left: 0;
  top: 0;
  transition: transform 0.3s ease;
  box-shadow: 2px 0 10px rgba(0, 0, 0, 0.1);
  z-index: 1000;

  &.closed {
    transform: translateX(-100%);
  }
}

.logo {
  padding: 24px;
  display: flex;
  align-items: center;
  gap: 12px;
  border-bottom: 1px solid rgba(255, 255, 255, 0.1);
}

.logo-icon {
  font-size: 28px;
}

.logo-text {
  font-size: 20px;
  font-weight: 600;
  letter-spacing: -0.5px;
}

.menu {
  flex: 1;
  padding: 20px 0;
}

.menu-item {
  display: flex;
  align-items: center;
  gap: 12px;
  padding: 12px 24px;
  cursor: pointer;
  transition: all 0.3s;
  position: relative;

  &:hover {
    background: rgba(255, 255, 255, 0.05);
  }

  &.active {
    background: linear-gradient(90deg, #4f46e5 0%, #7c3aed 100%);

    &::before {
      content: '';
      position: absolute;
      left: 0;
      top: 0;
      bottom: 0;
      width: 3px;
      background: white;
    }
  }
}

.menu-icon {
  font-size: 20px !important;
  width: 24px !important;
  height: 24px !important;
}

.menu-label {
  flex: 1;
  font-size: 14px;
  font-weight: 500;
}

.menu-badge {
  background: #ef4444;
  color: white;
  padding: 2px 8px;
  border-radius: 12px;
  font-size: 11px;
  font-weight: 600;
}

.sidebar-footer {
  padding: 20px;
  border-top: 1px solid rgba(255, 255, 255, 0.1);
}

.organization {
  padding: 12px;
  background: rgba(255, 255, 255, 0.05);
  border-radius: 8px;
}

.org-name {
  font-weight: 600;
  margin-bottom: 4px;
}

.org-plan {
  font-size: 12px;
  color: #94a3b8;
}
EOF

echo -e "${GREEN}✅ Sidebar implementado${NC}"
echo ""

echo -e "${BLUE}📦 Implementando Header...${NC}"

# Header Component
cat > src/app/core/components/header/header.ts << 'EOF'
import { Component, Output, EventEmitter } from '@angular/core';

@Component({
  selector: 'app-header',
  templateUrl: './header.html',
  styleUrls: ['./header.scss']
})
export class HeaderComponent {
  @Output() toggleSidebar = new EventEmitter<void>();

  user = {
    name: 'João Silva',
    email: 'joao@demo.com',
    avatar: '👤'
  };

  onToggleSidebar(): void {
    this.toggleSidebar.emit();
  }

  logout(): void {
    // TODO: Implementar logout
    console.log('Logout');
  }
}
EOF

cat > src/app/core/components/header/header.html << 'EOF'
<mat-toolbar class="header">
  <button mat-icon-button (click)="onToggleSidebar()">
    <mat-icon>menu</mat-icon>
  </button>

  <span class="spacer"></span>

  <button mat-icon-button>
    <mat-icon>notifications</mat-icon>
  </button>

  <button mat-button [matMenuTriggerFor]="userMenu" class="user-menu">
    <span class="user-avatar">{{ user.avatar }}</span>
    <span class="user-name">{{ user.name }}</span>
    <mat-icon>arrow_drop_down</mat-icon>
  </button>

  <mat-menu #userMenu="matMenu">
    <div class="user-info">
      <div class="user-name">{{ user.name }}</div>
      <div class="user-email">{{ user.email }}</div>
    </div>
    <mat-divider></mat-divider>
    <button mat-menu-item>
      <mat-icon>person</mat-icon>
      <span>Meu Perfil</span>
    </button>
    <button mat-menu-item>
      <mat-icon>settings</mat-icon>
      <span>Configurações</span>
    </button>
    <mat-divider></mat-divider>
    <button mat-menu-item (click)="logout()">
      <mat-icon>logout</mat-icon>
      <span>Sair</span>
    </button>
  </mat-menu>
</mat-toolbar>
EOF

cat > src/app/core/components/header/header.scss << 'EOF'
.header {
  background: white;
  box-shadow: 0 2px 4px rgba(0, 0, 0, 0.05);
  height: 64px;
  z-index: 999;
}

.spacer {
  flex: 1 1 auto;
}

.user-menu {
  display: flex;
  align-items: center;
  gap: 8px;
  padding: 8px 16px;
  border-radius: 8px;

  &:hover {
    background: rgba(0, 0, 0, 0.04);
  }
}

.user-avatar {
  font-size: 24px;
}

.user-name {
  font-weight: 500;
  font-size: 14px;
}

.user-info {
  padding: 16px;

  .user-name {
    font-weight: 600;
    margin-bottom: 4px;
  }

  .user-email {
    font-size: 12px;
    color: #666;
  }
}
EOF

echo -e "${GREEN}✅ Header implementado${NC}"
echo ""

echo -e "${BLUE}📊 Implementando Dashboard Component...${NC}"

# Dashboard Component
cat > src/app/features/dashboard/dashboard.ts << 'EOF'
import { Component, OnInit } from '@angular/core';

interface StatCard {
  icon: string;
  title: string;
  value: string | number;
  change: string;
  trend: 'up' | 'down' | 'neutral';
  color: string;
}

@Component({
  selector: 'app-dashboard',
  templateUrl: './dashboard.html',
  styleUrls: ['./dashboard.scss']
})
export class DashboardComponent implements OnInit {
  stats: StatCard[] = [
    {
      icon: 'email',
      title: 'Emails Validados',
      value: '12,847',
      change: '+12% vs mês anterior',
      trend: 'up',
      color: '#4f46e5'
    },
    {
      icon: 'check_circle',
      title: 'Taxa de Válidos',
      value: '92.3%',
      change: '+2.1% vs média',
      trend: 'up',
      color: '#10b981'
    },
    {
      icon: 'trending_up',
      title: 'Score Médio',
      value: '78',
      change: 'Estável',
      trend: 'neutral',
      color: '#f59e0b'
    },
    {
      icon: 'account_balance_wallet',
      title: 'Créditos Restantes',
      value: '3,153',
      change: '25% do total',
      trend: 'neutral',
      color: '#06b6d4'
    }
  ];

  activeModules = [
    {
      id: 'email-validator',
      name: 'Email Validator Pro',
      icon: 'email',
      status: 'active',
      usage: { current: 847, limit: 1000 }
    },
    {
      id: 'crm-connector',
      name: 'CRM Connector',
      icon: 'link',
      status: 'trial',
      usage: { current: 5, limit: 10 }
    },
    {
      id: 'lead-scorer',
      name: 'Lead Scorer AI',
      icon: 'analytics',
      status: 'inactive',
      usage: null
    }
  ];

  recentActivities = [
    { icon: 'email', title: '234 emails validados', time: 'Há 5 minutos', color: '#4f46e5' },
    { icon: 'sync', title: 'Sincronização com HubSpot concluída', time: 'Há 1 hora', color: '#10b981' },
    { icon: 'description', title: 'Relatório mensal gerado', time: 'Há 3 horas', color: '#f59e0b' },
    { icon: 'payment', title: 'Pagamento processado com sucesso', time: 'Há 1 dia', color: '#06b6d4' }
  ];

  ngOnInit(): void {
    console.log('Dashboard carregado');
  }

  getUsagePercent(usage: any): number {
    if (!usage) return 0;
    return (usage.current / usage.limit) * 100;
  }
}
EOF

cat > src/app/features/dashboard/dashboard.html << 'EOF'
<div class="dashboard">
  <div class="page-header">
    <h1>Dashboard</h1>
    <p>Visão geral da sua conta</p>
  </div>

  <div class="stats-grid">
    <mat-card class="stat-card" *ngFor="let stat of stats">
      <div class="stat-icon" [style.background-color]="stat.color + '20'" [style.color]="stat.color">
        <mat-icon>{{ stat.icon }}</mat-icon>
      </div>
      <div class="stat-content">
        <div class="stat-value">{{ stat.value }}</div>
        <div class="stat-title">{{ stat.title }}</div>
        <div class="stat-change" [class.up]="stat.trend === 'up'" [class.down]="stat.trend === 'down'">
          {{ stat.change }}
        </div>
      </div>
    </mat-card>
  </div>

  <div class="content-grid">
    <div class="modules-section">
      <h2>Módulos Ativos</h2>
      <div class="modules-grid">
        <mat-card class="module-card" *ngFor="let module of activeModules">
          <div class="module-header">
            <mat-icon [style.color]="module.status === 'active' ? '#10b981' : module.status === 'trial' ? '#f59e0b' : '#94a3b8'">
              {{ module.icon }}
            </mat-icon>
            <mat-chip [class]="'status-' + module.status">
              {{ module.status === 'active' ? 'Ativo' : module.status === 'trial' ? 'Trial' : 'Inativo' }}
            </mat-chip>
          </div>
          <h3>{{ module.name }}</h3>
          <div class="module-usage" *ngIf="module.usage">
            <mat-progress-bar mode="determinate" [value]="getUsagePercent(module.usage)"></mat-progress-bar>
            <div class="usage-text">
              {{ module.usage.current }} / {{ module.usage.limit }} usado
            </div>
          </div>
          <button mat-raised-button color="primary" class="module-btn">Gerenciar</button>
        </mat-card>
      </div>
    </div>

    <div class="activity-section">
      <h2>Atividade Recente</h2>
      <mat-card class="activity-list">
        <div class="activity-item" *ngFor="let activity of recentActivities">
          <div class="activity-icon" [style.background-color]="activity.color + '20'" [style.color]="activity.color">
            <mat-icon>{{ activity.icon }}</mat-icon>
          </div>
          <div class="activity-content">
            <div class="activity-title">{{ activity.title }}</div>
            <div class="activity-time">{{ activity.time }}</div>
          </div>
        </div>
      </mat-card>
    </div>
  </div>
</div>
EOF

cat > src/app/features/dashboard/dashboard.scss << 'EOF'
.dashboard {
  max-width: 1400px;
  margin: 0 auto;
}

.page-header {
  margin-bottom: 32px;

  h1 {
    font-size: 32px;
    font-weight: 600;
    color: #1e293b;
    margin-bottom: 8px;
  }

  p {
    color: #64748b;
    font-size: 16px;
  }
}

.stats-grid {
  display: grid;
  grid-template-columns: repeat(auto-fit, minmax(250px, 1fr));
  gap: 20px;
  margin-bottom: 40px;
}

.stat-card {
  display: flex;
  gap: 16px;
  padding: 24px !important;
}

.stat-icon {
  width: 48px;
  height: 48px;
  display: flex;
  align-items: center;
  justify-content: center;
  border-radius: 12px;

  mat-icon {
    font-size: 24px;
    width: 24px;
    height: 24px;
  }
}

.stat-content {
  flex: 1;
}

.stat-value {
  font-size: 28px;
  font-weight: 600;
  color: #1e293b;
  line-height: 1;
  margin-bottom: 8px;
}

.stat-title {
  color: #64748b;
  font-size: 14px;
  margin-bottom: 8px;
}

.stat-change {
  font-size: 13px;
  color: #64748b;

  &.up { color: #10b981; }
  &.down { color: #ef4444; }
}

.content-grid {
  display: grid;
  grid-template-columns: 2fr 1fr;
  gap: 24px;

  @media (max-width: 1024px) {
    grid-template-columns: 1fr;
  }
}

.modules-section, .activity-section {
  h2 {
    font-size: 20px;
    font-weight: 600;
    color: #1e293b;
    margin-bottom: 20px;
  }
}

.modules-grid {
  display: grid;
  grid-template-columns: repeat(auto-fill, minmax(280px, 1fr));
  gap: 20px;
}

.module-card {
  padding: 24px !important;
}

.module-header {
  display: flex;
  justify-content: space-between;
  align-items: center;
  margin-bottom: 16px;

  mat-icon {
    font-size: 32px;
    width: 32px;
    height: 32px;
  }
}

.status-active {
  background: #d1fae5 !important;
  color: #065f46 !important;
}

.status-trial {
  background: #fed7aa !important;
  color: #92400e !important;
}

.status-inactive {
  background: #f3f4f6 !important;
  color: #6b7280 !important;
}

.module-card h3 {
  font-size: 18px;
  font-weight: 600;
  color: #1e293b;
  margin-bottom: 16px;
}

.module-usage {
  margin-bottom: 16px;

  mat-progress-bar {
    margin-bottom: 8px;
  }
}

.usage-text {
  font-size: 13px;
  color: #64748b;
}

.module-btn {
  width: 100%;
}

.activity-list {
  padding: 0 !important;
}

.activity-item {
  display: flex;
  gap: 16px;
  padding: 16px 24px;
  border-bottom: 1px solid #f1f5f9;

  &:last-child {
    border-bottom: none;
  }
}

.activity-icon {
  width: 40px;
  height: 40px;
  border-radius: 8px;
  display: flex;
  align-items: center;
  justify-content: center;

  mat-icon {
    font-size: 20px;
    width: 20px;
    height: 20px;
  }
}

.activity-content {
  flex: 1;
}

.activity-title {
  font-weight: 500;
  color: #1e293b;
  margin-bottom: 4px;
  font-size: 14px;
}

.activity-time {
  font-size: 12px;
  color: #64748b;
}
EOF

echo -e "${GREEN}✅ Dashboard implementado${NC}"
echo ""

echo -e "${BLUE}🔐 Implementando Auth Guard...${NC}"

# Auth Guard
cat > src/app/core/guards/auth-guard.ts << 'EOF'
import { Injectable } from '@angular/core';
import { CanActivate, Router } from '@angular/router';

@Injectable({
  providedIn: 'root'
})
export class AuthGuard implements CanActivate {
  constructor(private router: Router) {}

  canActivate(): boolean {
    // TODO: Implementar verificação real de autenticação
    const token = localStorage.getItem('token');

    if (token) {
      return true;
    }

    // Por enquanto, sempre retorna true para desenvolvimento
    return true;

    // Quando implementar auth real:
    // this.router.navigate(['/login']);
    // return false;
  }
}
EOF

echo -e "${GREEN}✅ Auth Guard implementado${NC}"
echo ""

echo -e "${BLUE}📱 Atualizando app.component...${NC}"

# App Component
cat > src/app/app.ts << 'EOF'
import { Component } from '@angular/core';

@Component({
  selector: 'app-root',
  templateUrl: './app.html',
  styleUrls: ['./app.scss']
})
export class AppComponent {
  title = 'Spark Nexus - Client Dashboard';
}
EOF

cat > src/app/app.html << 'EOF'
<router-outlet></router-outlet>
EOF

cat > src/app/app.scss << 'EOF'
// App styles (vazio por enquanto)
EOF

echo -e "${GREEN}✅ App component atualizado${NC}"
echo ""

echo -e "${BLUE}🎨 Atualizando estilos globais...${NC}"

# Estilos globais
cat > src/styles.scss << 'EOF'
@import "@angular/material/prebuilt-themes/indigo-pink.css";
@import url("https://fonts.googleapis.com/css2?family=Inter:wght@300;400;500;600;700&display=swap");
@import url("https://fonts.googleapis.com/icon?family=Material+Icons");

* {
  margin: 0;
  padding: 0;
  box-sizing: border-box;
}

body {
  font-family: 'Inter', -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, Oxygen, Ubuntu, sans-serif;
  background: #f5f7fa;
  color: #1e293b;
  -webkit-font-smoothing: antialiased;
  -moz-osx-font-smoothing: grayscale;
}

// Material overrides
.mat-mdc-card {
  border-radius: 12px !important;
  box-shadow: 0 1px 3px rgba(0, 0, 0, 0.05) !important;
  border: 1px solid rgba(0, 0, 0, 0.05);
}

.mat-mdc-button, .mat-mdc-raised-button {
  border-radius: 8px !important;
  text-transform: none !important;
  font-weight: 500 !important;
  letter-spacing: 0 !important;
}

.mat-toolbar {
  padding: 0 24px !important;
}

// Scrollbar styles
::-webkit-scrollbar {
  width: 8px;
  height: 8px;
}

::-webkit-scrollbar-track {
  background: #f1f5f9;
}

::-webkit-scrollbar-thumb {
  background: #cbd5e1;
  border-radius: 4px;

  &:hover {
    background: #94a3b8;
  }
}
EOF

echo -e "${GREEN}✅ Estilos globais atualizados${NC}"
echo ""

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo -e "${GREEN}✅ DASHBOARD IMPLEMENTADO COM SUCESSO!${NC}"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo -e "${YELLOW}📋 O que foi implementado:${NC}"
echo "  ✅ Layout com Sidebar e Header"
echo "  ✅ Dashboard com estatísticas"
echo "  ✅ Cards de módulos ativos"
echo "  ✅ Lista de atividades recentes"
echo "  ✅ Sistema de rotas"
echo "  ✅ Auth Guard"
echo "  ✅ Design moderno com Material"
echo ""
echo -e "${BLUE}🚀 Para ver o resultado:${NC}"
echo ""
echo "  npm start"
echo ""
echo -e "Acesse: ${GREEN}http://localhost:4201${NC}"
echo ""
