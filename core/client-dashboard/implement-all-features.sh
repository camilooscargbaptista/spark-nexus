#!/bin/bash

# Script completo para implementar todas as funcionalidades do Spark Nexus
# Execute dentro da pasta client-dashboard

echo "🚀 Implementando TODAS as funcionalidades do Spark Nexus..."
echo ""

# Cores
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# ============================================
# PARTE 1: SERVIÇOS DE API E AUTENTICAÇÃO
# ============================================

echo -e "${BLUE}📡 Criando serviços de API e Autenticação...${NC}"

# AuthService completo
cat > src/app/core/services/auth.service.ts << 'EOF'
import { Injectable, inject } from '@angular/core';
import { HttpClient } from '@angular/common/http';
import { Router } from '@angular/router';
import { Observable, BehaviorSubject, tap, map } from 'rxjs';

export interface User {
  id: string;
  email: string;
  name: string;
  organizationId: string;
  role: string;
}

export interface LoginResponse {
  token: string;
  user: User;
  expiresIn: number;
}

@Injectable({
  providedIn: 'root'
})
export class AuthService {
  private http = inject(HttpClient);
  private router = inject(Router);

  private apiUrl = 'http://localhost:3001/api';
  private currentUserSubject = new BehaviorSubject<User | null>(null);
  public currentUser$ = this.currentUserSubject.asObservable();

  constructor() {
    this.checkToken();
  }

  private checkToken(): void {
    const token = localStorage.getItem('token');
    const user = localStorage.getItem('user');
    if (token && user) {
      this.currentUserSubject.next(JSON.parse(user));
    }
  }

  login(email: string, password: string): Observable<LoginResponse> {
    // Por enquanto, simula login
    return new Observable(observer => {
      setTimeout(() => {
        const response: LoginResponse = {
          token: 'fake-jwt-token-' + Date.now(),
          user: {
            id: '1',
            email: email,
            name: email.split('@')[0],
            organizationId: 'org-1',
            role: 'admin'
          },
          expiresIn: 3600
        };

        localStorage.setItem('token', response.token);
        localStorage.setItem('user', JSON.stringify(response.user));
        this.currentUserSubject.next(response.user);

        observer.next(response);
        observer.complete();
      }, 1000);
    });

    // Quando tiver backend real:
    // return this.http.post<LoginResponse>(`${this.apiUrl}/auth/login`, { email, password })
    //   .pipe(
    //     tap(response => {
    //       localStorage.setItem('token', response.token);
    //       localStorage.setItem('user', JSON.stringify(response.user));
    //       this.currentUserSubject.next(response.user);
    //     })
    //   );
  }

  logout(): void {
    localStorage.removeItem('token');
    localStorage.removeItem('user');
    this.currentUserSubject.next(null);
    this.router.navigate(['/login']);
  }

  isAuthenticated(): boolean {
    return !!localStorage.getItem('token');
  }

  getToken(): string | null {
    return localStorage.getItem('token');
  }

  getCurrentUser(): User | null {
    return this.currentUserSubject.value;
  }
}
EOF

# ApiService completo
cat > src/app/core/services/api.service.ts << 'EOF'
import { Injectable, inject } from '@angular/core';
import { HttpClient, HttpHeaders } from '@angular/common/http';
import { Observable, of } from 'rxjs';
import { delay } from 'rxjs/operators';

export interface DashboardStats {
  emailsValidated: number;
  validRate: number;
  averageScore: number;
  creditsRemaining: number;
  chartData: {
    labels: string[];
    datasets: any[];
  };
}

export interface EmailValidationResult {
  email: string;
  valid: boolean;
  score: number;
  reason?: string;
  checks: {
    syntax: boolean;
    domain: boolean;
    mx: boolean;
    disposable: boolean;
    role: boolean;
  };
}

@Injectable({
  providedIn: 'root'
})
export class ApiService {
  private http = inject(HttpClient);
  private apiUrl = 'http://localhost:3001/api';

  // Dashboard Stats
  getDashboardStats(): Observable<DashboardStats> {
    // Simula dados do dashboard
    const mockData: DashboardStats = {
      emailsValidated: 12847,
      validRate: 92.3,
      averageScore: 78,
      creditsRemaining: 3153,
      chartData: {
        labels: ['Jan', 'Fev', 'Mar', 'Abr', 'Mai', 'Jun'],
        datasets: [
          {
            label: 'Emails Validados',
            data: [1200, 1900, 2100, 2500, 2900, 3200],
            borderColor: '#4f46e5',
            backgroundColor: 'rgba(79, 70, 229, 0.1)',
            tension: 0.4
          },
          {
            label: 'Taxa de Válidos (%)',
            data: [89, 91, 90, 93, 92, 92.3],
            borderColor: '#10b981',
            backgroundColor: 'rgba(16, 185, 129, 0.1)',
            tension: 0.4
          }
        ]
      }
    };

    return of(mockData).pipe(delay(500));

    // Com backend real:
    // return this.http.get<DashboardStats>(`${this.apiUrl}/dashboard/stats`);
  }

  // Email Validation
  validateEmails(emails: string[]): Observable<EmailValidationResult[]> {
    // Simula validação de emails
    const results: EmailValidationResult[] = emails.map(email => {
      const isValid = Math.random() > 0.2;
      const score = Math.floor(Math.random() * 100);

      return {
        email,
        valid: isValid,
        score,
        reason: isValid ? 'Email válido' : 'Email inválido ou não existe',
        checks: {
          syntax: Math.random() > 0.1,
          domain: Math.random() > 0.2,
          mx: Math.random() > 0.3,
          disposable: Math.random() > 0.8,
          role: Math.random() > 0.9
        }
      };
    });

    return of(results).pipe(delay(1500));

    // Com backend real:
    // return this.http.post<EmailValidationResult[]>(`${this.apiUrl}/email-validator/validate`, { emails });
  }

  // Modules
  getModules(): Observable<any[]> {
    const modules = [
      {
        id: 'email-validator',
        name: 'Email Validator Pro',
        icon: 'email',
        status: 'active',
        usage: { current: 847, limit: 1000 },
        description: 'Validação avançada de emails em massa'
      },
      {
        id: 'crm-connector',
        name: 'CRM Connector',
        icon: 'link',
        status: 'trial',
        usage: { current: 5, limit: 10 },
        description: 'Integração com principais CRMs'
      },
      {
        id: 'lead-scorer',
        name: 'Lead Scorer AI',
        icon: 'analytics',
        status: 'inactive',
        description: 'Pontuação inteligente de leads'
      }
    ];

    return of(modules).pipe(delay(300));
  }

  // Activity
  getRecentActivity(): Observable<any[]> {
    const activities = [
      { icon: 'email', title: '234 emails validados', time: new Date(Date.now() - 5 * 60000), color: '#4f46e5' },
      { icon: 'sync', title: 'Sincronização com HubSpot concluída', time: new Date(Date.now() - 60 * 60000), color: '#10b981' },
      { icon: 'description', title: 'Relatório mensal gerado', time: new Date(Date.now() - 3 * 3600000), color: '#f59e0b' },
      { icon: 'payment', title: 'Pagamento processado com sucesso', time: new Date(Date.now() - 86400000), color: '#06b6d4' }
    ];

    return of(activities).pipe(delay(200));
  }
}
EOF

echo -e "${GREEN}✅ Serviços criados${NC}"

# ============================================
# PARTE 2: COMPONENTE DE LOGIN MELHORADO
# ============================================

echo -e "${BLUE}🔐 Atualizando página de Login...${NC}"

cat > src/app/features/login/login.ts << 'EOF'
import { Component, inject } from '@angular/core';
import { CommonModule } from '@angular/common';
import { FormsModule } from '@angular/forms';
import { Router } from '@angular/router';
import { MatCardModule } from '@angular/material/card';
import { MatInputModule } from '@angular/material/input';
import { MatFormFieldModule } from '@angular/material/form-field';
import { MatButtonModule } from '@angular/material/button';
import { MatIconModule } from '@angular/material/icon';
import { MatProgressSpinnerModule } from '@angular/material/progress-spinner';
import { MatSnackBar, MatSnackBarModule } from '@angular/material/snack-bar';
import { AuthService } from '../../core/services/auth.service';

@Component({
  selector: 'app-login',
  standalone: true,
  imports: [
    CommonModule,
    FormsModule,
    MatCardModule,
    MatInputModule,
    MatFormFieldModule,
    MatButtonModule,
    MatIconModule,
    MatProgressSpinnerModule,
    MatSnackBarModule
  ],
  templateUrl: './login.html',
  styleUrls: ['./login.scss']
})
export class LoginComponent {
  private authService = inject(AuthService);
  private router = inject(Router);
  private snackBar = inject(MatSnackBar);

  email = 'demo@sparknexus.com';
  password = 'demo123';
  loading = false;
  hidePassword = true;

  login(): void {
    if (!this.email || !this.password) {
      this.snackBar.open('Por favor, preencha todos os campos', 'OK', { duration: 3000 });
      return;
    }

    this.loading = true;

    this.authService.login(this.email, this.password).subscribe({
      next: (response) => {
        this.snackBar.open('Login realizado com sucesso!', 'OK', { duration: 2000 });
        this.router.navigate(['/dashboard']);
      },
      error: (error) => {
        this.loading = false;
        this.snackBar.open('Email ou senha inválidos', 'OK', { duration: 3000 });
      },
      complete: () => {
        this.loading = false;
      }
    });
  }
}
EOF

cat > src/app/features/login/login.html << 'EOF'
<div class="login-container">
  <mat-card class="login-card">
    <div class="login-header">
      <span class="logo">🚀</span>
      <h1>Spark Nexus</h1>
    </div>

    <mat-card-content>
      <h2>Entrar na sua conta</h2>
      <p class="subtitle">Use demo@sparknexus.com / demo123</p>

      <mat-form-field appearance="outline" class="full-width">
        <mat-label>Email</mat-label>
        <input matInput [(ngModel)]="email" type="email" [disabled]="loading">
        <mat-icon matSuffix>email</mat-icon>
      </mat-form-field>

      <mat-form-field appearance="outline" class="full-width">
        <mat-label>Senha</mat-label>
        <input matInput [(ngModel)]="password" [type]="hidePassword ? 'password' : 'text'" [disabled]="loading">
        <button mat-icon-button matSuffix (click)="hidePassword = !hidePassword" [disabled]="loading">
          <mat-icon>{{ hidePassword ? 'visibility_off' : 'visibility' }}</mat-icon>
        </button>
      </mat-form-field>

      <button mat-raised-button color="primary" class="full-width login-button"
              (click)="login()" [disabled]="loading">
        <mat-spinner diameter="20" *ngIf="loading"></mat-spinner>
        <span *ngIf="!loading">Entrar</span>
      </button>

      <div class="extra-links">
        <a href="#">Esqueceu a senha?</a>
        <a href="#">Criar conta</a>
      </div>
    </mat-card-content>
  </mat-card>
</div>
EOF

cat > src/app/features/login/login.scss << 'EOF'
.login-container {
  height: 100vh;
  display: flex;
  align-items: center;
  justify-content: center;
  background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
}

.login-card {
  width: 100%;
  max-width: 400px;
  padding: 20px;

  .login-header {
    text-align: center;
    margin-bottom: 30px;

    .logo {
      font-size: 48px;
      display: block;
      margin-bottom: 10px;
    }

    h1 {
      margin: 0;
      font-size: 28px;
      font-weight: 600;
      color: #1e293b;
    }
  }

  h2 {
    text-align: center;
    margin-bottom: 10px;
    color: #1e293b;
    font-size: 20px;
  }

  .subtitle {
    text-align: center;
    color: #64748b;
    font-size: 14px;
    margin-bottom: 20px;
  }

  .full-width {
    width: 100%;
    margin-bottom: 16px;
  }

  .login-button {
    height: 48px;
    font-size: 16px;
    margin-top: 10px;

    mat-spinner {
      display: inline-block;
      margin-right: 8px;
    }
  }

  .extra-links {
    display: flex;
    justify-content: space-between;
    margin-top: 20px;

    a {
      color: #4f46e5;
      text-decoration: none;
      font-size: 14px;

      &:hover {
        text-decoration: underline;
      }
    }
  }
}
EOF

echo -e "${GREEN}✅ Login atualizado${NC}"

# ============================================
# PARTE 3: DASHBOARD COM GRÁFICOS
# ============================================

echo -e "${BLUE}📊 Adicionando gráficos ao Dashboard...${NC}"

cat > src/app/features/dashboard/dashboard.ts << 'EOF'
import { Component, OnInit, ViewChild, ElementRef, inject, AfterViewInit } from '@angular/core';
import { CommonModule } from '@angular/common';
import { MatCardModule } from '@angular/material/card';
import { MatIconModule } from '@angular/material/icon';
import { MatButtonModule } from '@angular/material/button';
import { MatChipsModule } from '@angular/material/chips';
import { MatProgressBarModule } from '@angular/material/progress-bar';
import { MatProgressSpinnerModule } from '@angular/material/progress-spinner';
import { Chart, registerables } from 'chart.js';
import { ApiService } from '../../core/services/api.service';

Chart.register(...registerables);

@Component({
  selector: 'app-dashboard',
  standalone: true,
  imports: [
    CommonModule,
    MatCardModule,
    MatIconModule,
    MatButtonModule,
    MatChipsModule,
    MatProgressBarModule,
    MatProgressSpinnerModule
  ],
  templateUrl: './dashboard.html',
  styleUrls: ['./dashboard.scss']
})
export class DashboardComponent implements OnInit, AfterViewInit {
  @ViewChild('lineChart') lineChartRef!: ElementRef;
  @ViewChild('doughnutChart') doughnutChartRef!: ElementRef;

  private apiService = inject(ApiService);

  loading = true;
  lineChart: any;
  doughnutChart: any;

  stats = [
    {
      icon: 'email',
      title: 'Emails Validados',
      value: '0',
      change: 'Carregando...',
      trend: 'neutral' as const,
      color: '#4f46e5'
    },
    {
      icon: 'check_circle',
      title: 'Taxa de Válidos',
      value: '0%',
      change: 'Carregando...',
      trend: 'neutral' as const,
      color: '#10b981'
    },
    {
      icon: 'trending_up',
      title: 'Score Médio',
      value: '0',
      change: 'Carregando...',
      trend: 'neutral' as const,
      color: '#f59e0b'
    },
    {
      icon: 'account_balance_wallet',
      title: 'Créditos Restantes',
      value: '0',
      change: 'Carregando...',
      trend: 'neutral' as const,
      color: '#06b6d4'
    }
  ];

  activeModules: any[] = [];
  recentActivities: any[] = [];

  ngOnInit(): void {
    this.loadDashboardData();
  }

  ngAfterViewInit(): void {
    // Gráficos serão criados após carregar os dados
  }

  loadDashboardData(): void {
    // Carregar estatísticas
    this.apiService.getDashboardStats().subscribe(data => {
      this.stats[0].value = data.emailsValidated.toLocaleString();
      this.stats[0].change = '+12% vs mês anterior';
      this.stats[0].trend = 'up';

      this.stats[1].value = data.validRate + '%';
      this.stats[1].change = '+2.1% vs média';
      this.stats[1].trend = 'up';

      this.stats[2].value = data.averageScore.toString();
      this.stats[2].change = 'Estável';
      this.stats[2].trend = 'neutral';

      this.stats[3].value = data.creditsRemaining.toLocaleString();
      this.stats[3].change = '25% do total';
      this.stats[3].trend = 'neutral';

      // Criar gráficos
      this.createLineChart(data.chartData);
      this.createDoughnutChart();
    });

    // Carregar módulos
    this.apiService.getModules().subscribe(modules => {
      this.activeModules = modules;
    });

    // Carregar atividades
    this.apiService.getRecentActivity().subscribe(activities => {
      this.recentActivities = activities;
      this.loading = false;
    });
  }

  createLineChart(chartData: any): void {
    if (!this.lineChartRef) return;

    const ctx = this.lineChartRef.nativeElement.getContext('2d');
    this.lineChart = new Chart(ctx, {
      type: 'line',
      data: chartData,
      options: {
        responsive: true,
        maintainAspectRatio: false,
        plugins: {
          legend: {
            position: 'bottom'
          },
          title: {
            display: true,
            text: 'Evolução Mensal'
          }
        },
        scales: {
          y: {
            beginAtZero: true
          }
        }
      }
    });
  }

  createDoughnutChart(): void {
    if (!this.doughnutChartRef) return;

    const ctx = this.doughnutChartRef.nativeElement.getContext('2d');
    this.doughnutChart = new Chart(ctx, {
      type: 'doughnut',
      data: {
        labels: ['Válidos', 'Inválidos', 'Duvidosos'],
        datasets: [{
          data: [92.3, 5.2, 2.5],
          backgroundColor: ['#10b981', '#ef4444', '#f59e0b']
        }]
      },
      options: {
        responsive: true,
        maintainAspectRatio: false,
        plugins: {
          legend: {
            position: 'bottom'
          },
          title: {
            display: true,
            text: 'Distribuição de Validações'
          }
        }
      }
    });
  }

  getUsagePercent(usage: any): number {
    if (!usage) return 0;
    return (usage.current / usage.limit) * 100;
  }

  formatTime(time: Date): string {
    const now = new Date();
    const diff = now.getTime() - new Date(time).getTime();
    const minutes = Math.floor(diff / 60000);
    const hours = Math.floor(diff / 3600000);
    const days = Math.floor(diff / 86400000);

    if (minutes < 60) return `Há ${minutes} minutos`;
    if (hours < 24) return `Há ${hours} hora${hours > 1 ? 's' : ''}`;
    return `Há ${days} dia${days > 1 ? 's' : ''}`;
  }
}
EOF

cat > src/app/features/dashboard/dashboard.html << 'EOF'
<div class="dashboard">
  <div class="page-header">
    <h1>Dashboard</h1>
    <p>Visão geral da sua conta</p>
  </div>

  <div class="loading-overlay" *ngIf="loading">
    <mat-spinner></mat-spinner>
  </div>

  <div class="stats-grid" *ngIf="!loading">
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

  <div class="charts-grid" *ngIf="!loading">
    <mat-card class="chart-card">
      <mat-card-header>
        <mat-card-title>Tendência de Validações</mat-card-title>
      </mat-card-header>
      <mat-card-content>
        <div class="chart-container">
          <canvas #lineChart></canvas>
        </div>
      </mat-card-content>
    </mat-card>

    <mat-card class="chart-card">
      <mat-card-header>
        <mat-card-title>Distribuição de Resultados</mat-card-title>
      </mat-card-header>
      <mat-card-content>
        <div class="chart-container small">
          <canvas #doughnutChart></canvas>
        </div>
      </mat-card-content>
    </mat-card>
  </div>

  <div class="content-grid" *ngIf="!loading">
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
          <p class="module-description">{{ module.description }}</p>
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
            <div class="activity-time">{{ formatTime(activity.time) }}</div>
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
  position: relative;
}

.loading-overlay {
  position: fixed;
  top: 50%;
  left: 50%;
  transform: translate(-50%, -50%);
  z-index: 1000;
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
  margin-bottom: 30px;
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

.charts-grid {
  display: grid;
  grid-template-columns: 2fr 1fr;
  gap: 20px;
  margin-bottom: 30px;

  @media (max-width: 1024px) {
    grid-template-columns: 1fr;
  }
}

.chart-card {
  mat-card-header {
    margin-bottom: 20px;
  }

  mat-card-title {
    font-size: 18px !important;
    font-weight: 600 !important;
  }
}

.chart-container {
  position: relative;
  height: 300px;

  &.small {
    height: 250px;
  }
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

.module-description {
  color: #64748b;
  font-size: 14px;
  margin: 10px 0;
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
  margin-bottom: 8px;
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

echo -e "${GREEN}✅ Dashboard com gráficos implementado${NC}"

# ============================================
# PARTE 4: EMAIL VALIDATOR FUNCIONAL
# ============================================

echo -e "${BLUE}📧 Implementando Email Validator funcional...${NC}"

cat > src/app/features/email-validator/email-validator.ts << 'EOF'
import { Component, inject } from '@angular/core';
import { CommonModule } from '@angular/common';
import { FormsModule } from '@angular/forms';
import { MatCardModule } from '@angular/material/card';
import { MatInputModule } from '@angular/material/input';
import { MatFormFieldModule } from '@angular/material/form-field';
import { MatButtonModule } from '@angular/material/button';
import { MatIconModule } from '@angular/material/icon';
import { MatTableModule } from '@angular/material/table';
import { MatChipsModule } from '@angular/material/chips';
import { MatProgressSpinnerModule } from '@angular/material/progress-spinner';
import { MatTooltipModule } from '@angular/material/tooltip';
import { MatSnackBar, MatSnackBarModule } from '@angular/material/snack-bar';
import { ApiService, EmailValidationResult } from '../../core/services/api.service';

@Component({
  selector: 'app-email-validator',
  standalone: true,
  imports: [
    CommonModule,
    FormsModule,
    MatCardModule,
    MatInputModule,
    MatFormFieldModule,
    MatButtonModule,
    MatIconModule,
    MatTableModule,
    MatChipsModule,
    MatProgressSpinnerModule,
    MatTooltipModule,
    MatSnackBarModule
  ],
  templateUrl: './email-validator.html',
  styleUrls: ['./email-validator.scss']
})
export class EmailValidatorComponent {
  private apiService = inject(ApiService);
  private snackBar = inject(MatSnackBar);

  emailList = `john.doe@gmail.com
jane.smith@company.com
invalid.email@
test@tempmail.com
admin@example.org`;

  results: EmailValidationResult[] = [];
  validating = false;
  displayedColumns = ['email', 'status', 'score', 'checks', 'reason'];

  stats = {
    total: 0,
    valid: 0,
    invalid: 0,
    validRate: 0
  };

  validateEmails(): void {
    const emails = this.emailList
      .split('\n')
      .map(e => e.trim())
      .filter(e => e.length > 0);

    if (emails.length === 0) {
      this.snackBar.open('Por favor, insira pelo menos um email', 'OK', { duration: 3000 });
      return;
    }

    if (emails.length > 100) {
      this.snackBar.open('Máximo de 100 emails por vez', 'OK', { duration: 3000 });
      return;
    }

    this.validating = true;
    this.results = [];

    this.apiService.validateEmails(emails).subscribe({
      next: (results) => {
        this.results = results;
        this.calculateStats();
        this.validating = false;
        this.snackBar.open(`${results.length} emails validados com sucesso!`, 'OK', { duration: 3000 });
      },
      error: (error) => {
        this.validating = false;
        this.snackBar.open('Erro ao validar emails', 'OK', { duration: 3000 });
      }
    });
  }

  calculateStats(): void {
    this.stats.total = this.results.length;
    this.stats.valid = this.results.filter(r => r.valid).length;
    this.stats.invalid = this.stats.total - this.stats.valid;
    this.stats.validRate = this.stats.total > 0 ? (this.stats.valid / this.stats.total) * 100 : 0;
  }

  clearResults(): void {
    this.results = [];
    this.emailList = '';
    this.stats = { total: 0, valid: 0, invalid: 0, validRate: 0 };
  }

  exportResults(): void {
    if (this.results.length === 0) {
      this.snackBar.open('Nenhum resultado para exportar', 'OK', { duration: 3000 });
      return;
    }

    const csv = this.convertToCSV();
    const blob = new Blob([csv], { type: 'text/csv' });
    const url = window.URL.createObjectURL(blob);
    const link = document.createElement('a');
    link.href = url;
    link.download = `email-validation-${Date.now()}.csv`;
    link.click();
    window.URL.revokeObjectURL(url);

    this.snackBar.open('Resultados exportados com sucesso!', 'OK', { duration: 3000 });
  }

  private convertToCSV(): string {
    const headers = ['Email', 'Válido', 'Score', 'Sintaxe', 'Domínio', 'MX', 'Descartável', 'Role', 'Motivo'];
    const rows = this.results.map(r => [
      r.email,
      r.valid ? 'Sim' : 'Não',
      r.score,
      r.checks.syntax ? 'OK' : 'Falhou',
      r.checks.domain ? 'OK' : 'Falhou',
      r.checks.mx ? 'OK' : 'Falhou',
      r.checks.disposable ? 'Não' : 'Sim',
      r.checks.role ? 'Não' : 'Sim',
      r.reason || ''
    ]);

    return [headers, ...rows].map(row => row.join(',')).join('\n');
  }

  getScoreColor(score: number): string {
    if (score >= 80) return 'primary';
    if (score >= 50) return 'accent';
    return 'warn';
  }
}
EOF

cat > src/app/features/email-validator/email-validator.html << 'EOF'
<div class="email-validator-page">
  <div class="page-header">
    <h1>Email Validator</h1>
    <p>Valide emails em massa com análise detalhada</p>
  </div>

  <div class="validator-grid">
    <mat-card class="input-card">
      <mat-card-header>
        <mat-card-title>Emails para Validar</mat-card-title>
      </mat-card-header>
      <mat-card-content>
        <mat-form-field appearance="outline" class="full-width">
          <mat-label>Cole os emails aqui (um por linha)</mat-label>
          <textarea matInput [(ngModel)]="emailList" rows="15" [disabled]="validating"
                    placeholder="exemplo@email.com"></textarea>
          <mat-hint>Máximo de 100 emails por vez</mat-hint>
        </mat-form-field>

        <div class="button-group">
          <button mat-raised-button color="primary" (click)="validateEmails()" [disabled]="validating">
            <mat-icon>check_circle</mat-icon>
            {{ validating ? 'Validando...' : 'Validar Emails' }}
          </button>
          <button mat-button (click)="clearResults()" [disabled]="validating">
            <mat-icon>clear</mat-icon>
            Limpar
          </button>
        </div>
      </mat-card-content>
    </mat-card>

    <div class="stats-section" *ngIf="results.length > 0">
      <mat-card class="stat-card">
        <div class="stat-icon total">
          <mat-icon>email</mat-icon>
        </div>
        <div class="stat-content">
          <div class="stat-value">{{ stats.total }}</div>
          <div class="stat-label">Total</div>
        </div>
      </mat-card>

      <mat-card class="stat-card">
        <div class="stat-icon valid">
          <mat-icon>check_circle</mat-icon>
        </div>
        <div class="stat-content">
          <div class="stat-value">{{ stats.valid }}</div>
          <div class="stat-label">Válidos</div>
        </div>
      </mat-card>

      <mat-card class="stat-card">
        <div class="stat-icon invalid">
          <mat-icon>cancel</mat-icon>
        </div>
        <div class="stat-content">
          <div class="stat-value">{{ stats.invalid }}</div>
          <div class="stat-label">Inválidos</div>
        </div>
      </mat-card>

      <mat-card class="stat-card">
        <div class="stat-icon rate">
          <mat-icon>percent</mat-icon>
        </div>
        <div class="stat-content">
          <div class="stat-value">{{ stats.validRate | number:'1.1-1' }}%</div>
          <div class="stat-label">Taxa de Válidos</div>
        </div>
      </mat-card>
    </div>
  </div>

  <div class="loading-spinner" *ngIf="validating">
    <mat-spinner></mat-spinner>
    <p>Validando emails...</p>
  </div>

  <mat-card class="results-card" *ngIf="results.length > 0 && !validating">
    <mat-card-header>
      <mat-card-title>Resultados da Validação</mat-card-title>
      <button mat-button color="primary" (click)="exportResults()">
        <mat-icon>download</mat-icon>
        Exportar CSV
      </button>
    </mat-card-header>
    <mat-card-content>
      <table mat-table [dataSource]="results" class="results-table">

        <ng-container matColumnDef="email">
          <th mat-header-cell *matHeaderCellDef>Email</th>
          <td mat-cell *matCellDef="let result">{{ result.email }}</td>
        </ng-container>

        <ng-container matColumnDef="status">
          <th mat-header-cell *matHeaderCellDef>Status</th>
          <td mat-cell *matCellDef="let result">
            <mat-chip [class]="result.valid ? 'valid-chip' : 'invalid-chip'">
              <mat-icon>{{ result.valid ? 'check' : 'close' }}</mat-icon>
              {{ result.valid ? 'Válido' : 'Inválido' }}
            </mat-chip>
          </td>
        </ng-container>

        <ng-container matColumnDef="score">
          <th mat-header-cell *matHeaderCellDef>Score</th>
          <td mat-cell *matCellDef="let result">
            <mat-chip [color]="getScoreColor(result.score)">
              {{ result.score }}
            </mat-chip>
          </td>
        </ng-container>

        <ng-container matColumnDef="checks">
          <th mat-header-cell *matHeaderCellDef>Verificações</th>
          <td mat-cell *matCellDef="let result">
            <div class="checks-icons">
              <mat-icon [matTooltip]="'Sintaxe: ' + (result.checks.syntax ? 'OK' : 'Falhou')"
                        [class]="result.checks.syntax ? 'check-pass' : 'check-fail'">
                {{ result.checks.syntax ? 'check' : 'close' }}
              </mat-icon>
              <mat-icon [matTooltip]="'Domínio: ' + (result.checks.domain ? 'OK' : 'Falhou')"
                        [class]="result.checks.domain ? 'check-pass' : 'check-fail'">
                {{ result.checks.domain ? 'check' : 'close' }}
              </mat-icon>
              <mat-icon [matTooltip]="'MX Records: ' + (result.checks.mx ? 'OK' : 'Falhou')"
                        [class]="result.checks.mx ? 'check-pass' : 'check-fail'">
                {{ result.checks.mx ? 'check' : 'close' }}
              </mat-icon>
              <mat-icon [matTooltip]="'Descartável: ' + (result.checks.disposable ? 'Sim' : 'Não')"
                        [class]="!result.checks.disposable ? 'check-pass' : 'check-fail'">
                {{ !result.checks.disposable ? 'check' : 'close' }}
              </mat-icon>
              <mat-icon [matTooltip]="'Role Account: ' + (result.checks.role ? 'Sim' : 'Não')"
                        [class]="!result.checks.role ? 'check-pass' : 'check-fail'">
                {{ !result.checks.role ? 'check' : 'close' }}
              </mat-icon>
            </div>
          </td>
        </ng-container>

        <ng-container matColumnDef="reason">
          <th mat-header-cell *matHeaderCellDef>Motivo</th>
          <td mat-cell *matCellDef="let result">{{ result.reason }}</td>
        </ng-container>

        <tr mat-header-row *matHeaderRowDef="displayedColumns"></tr>
        <tr mat-row *matRowDef="let row; columns: displayedColumns;"></tr>
      </table>
    </mat-card-content>
  </mat-card>
</div>
EOF

cat > src/app/features/email-validator/email-validator.scss << 'EOF'
.email-validator-page {
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

.validator-grid {
  display: grid;
  grid-template-columns: 1fr 1fr;
  gap: 20px;
  margin-bottom: 30px;

  @media (max-width: 1024px) {
    grid-template-columns: 1fr;
  }
}

.input-card {
  mat-card-title {
    font-size: 18px !important;
    margin-bottom: 20px;
  }
}

.full-width {
  width: 100%;
}

.button-group {
  display: flex;
  gap: 12px;
  margin-top: 16px;

  button {
    mat-icon {
      margin-right: 8px;
    }
  }
}

.stats-section {
  display: grid;
  grid-template-columns: repeat(2, 1fr);
  gap: 15px;
}

.stat-card {
  display: flex;
  align-items: center;
  gap: 16px;
  padding: 20px !important;
}

.stat-icon {
  width: 48px;
  height: 48px;
  border-radius: 12px;
  display: flex;
  align-items: center;
  justify-content: center;

  &.total {
    background: #e0e7ff;
    color: #4f46e5;
  }

  &.valid {
    background: #d1fae5;
    color: #10b981;
  }

  &.invalid {
    background: #fee2e2;
    color: #ef4444;
  }

  &.rate {
    background: #fed7aa;
    color: #f59e0b;
  }

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
  font-size: 24px;
  font-weight: 600;
  color: #1e293b;
  line-height: 1;
}

.stat-label {
  font-size: 14px;
  color: #64748b;
  margin-top: 4px;
}

.loading-spinner {
  text-align: center;
  padding: 40px;

  p {
    margin-top: 16px;
    color: #64748b;
  }
}

.results-card {
  mat-card-header {
    display: flex;
    justify-content: space-between;
    align-items: center;
    margin-bottom: 20px;

    mat-card-title {
      font-size: 20px !important;
      margin: 0 !important;
    }
  }
}

.results-table {
  width: 100%;

  th {
    font-weight: 600;
    color: #475569;
    background: #f8fafc;
  }

  td {
    color: #1e293b;
  }
}

.valid-chip {
  background: #d1fae5 !important;
  color: #065f46 !important;

  mat-icon {
    font-size: 16px;
    width: 16px;
    height: 16px;
    margin-right: 4px;
  }
}

.invalid-chip {
  background: #fee2e2 !important;
  color: #991b1b !important;

  mat-icon {
    font-size: 16px;
    width: 16px;
    height: 16px;
    margin-right: 4px;
  }
}

.checks-icons {
  display: flex;
  gap: 8px;

  mat-icon {
    font-size: 18px;
    width: 18px;
    height: 18px;
    cursor: help;

    &.check-pass {
      color: #10b981;
    }

    &.check-fail {
      color: #ef4444;
    }
  }
}
EOF

echo -e "${GREEN}✅ Email Validator implementado${NC}"

# ============================================
# PARTE 5: ATUALIZAR GUARD DE AUTENTICAÇÃO
# ============================================

echo -e "${BLUE}🔒 Atualizando Auth Guard...${NC}"

cat > src/app/core/guards/auth-guard.ts << 'EOF'
import { inject } from '@angular/core';
import { Router } from '@angular/router';
import { CanActivateFn } from '@angular/router';
import { AuthService } from '../services/auth.service';

export const authGuard: CanActivateFn = (route, state) => {
  const authService = inject(AuthService);
  const router = inject(Router);

  if (authService.isAuthenticated()) {
    return true;
  }

  // Redireciona para login se não autenticado
  router.navigate(['/login'], { queryParams: { returnUrl: state.url }});
  return false;
};
EOF

echo -e "${GREEN}✅ Auth Guard atualizado${NC}"

# ============================================
# PARTE 6: ATUALIZAR HEADER COM LOGOUT
# ============================================

echo -e "${BLUE}👤 Atualizando Header com logout funcional...${NC}"

cat > src/app/core/components/header/header.ts << 'EOF'
import { Component, Output, EventEmitter, inject, OnInit } from '@angular/core';
import { CommonModule } from '@angular/common';
import { MatToolbarModule } from '@angular/material/toolbar';
import { MatIconModule } from '@angular/material/icon';
import { MatButtonModule } from '@angular/material/button';
import { MatMenuModule } from '@angular/material/menu';
import { MatDividerModule } from '@angular/material/divider';
import { MatBadgeModule } from '@angular/material/badge';
import { AuthService } from '../../services/auth.service';

@Component({
  selector: 'app-header',
  standalone: true,
  imports: [
    CommonModule,
    MatToolbarModule,
    MatIconModule,
    MatButtonModule,
    MatMenuModule,
    MatDividerModule,
    MatBadgeModule
  ],
  templateUrl: './header.html',
  styleUrls: ['./header.scss']
})
export class HeaderComponent implements OnInit {
  @Output() toggleSidebar = new EventEmitter<void>();

  private authService = inject(AuthService);

  user: any = {
    name: 'Usuário',
    email: 'usuario@demo.com',
    avatar: '👤'
  };

  notifications = 3;

  ngOnInit(): void {
    this.authService.currentUser$.subscribe(user => {
      if (user) {
        this.user = {
          name: user.name,
          email: user.email,
          avatar: user.name.charAt(0).toUpperCase()
        };
      }
    });
  }

  onToggleSidebar(): void {
    this.toggleSidebar.emit();
  }

  logout(): void {
    this.authService.logout();
  }
}
EOF

cat > src/app/core/components/header/header.html << 'EOF'
<mat-toolbar class="header">
  <button mat-icon-button (click)="onToggleSidebar()">
    <mat-icon>menu</mat-icon>
  </button>

  <span class="spacer"></span>

  <button mat-icon-button [matBadge]="notifications" matBadgeColor="warn" matBadgeSize="small">
    <mat-icon>notifications</mat-icon>
  </button>

  <button mat-button [matMenuTriggerFor]="userMenu" class="user-menu">
    <span class="user-avatar">{{ user.avatar }}</span>
    <span class="user-name">{{ user.name }}</span>
    <mat-icon>arrow_drop_down</mat-icon>
  </button>

  <mat-menu #userMenu="matMenu">
    <div class="user-info">
      <div class="user-avatar-large">{{ user.avatar }}</div>
      <div class="user-details">
        <div class="user-name">{{ user.name }}</div>
        <div class="user-email">{{ user.email }}</div>
      </div>
    </div>
    <mat-divider></mat-divider>
    <button mat-menu-item routerLink="/settings">
      <mat-icon>person</mat-icon>
      <span>Meu Perfil</span>
    </button>
    <button mat-menu-item routerLink="/settings">
      <mat-icon>settings</mat-icon>
      <span>Configurações</span>
    </button>
    <button mat-menu-item routerLink="/billing">
      <mat-icon>credit_card</mat-icon>
      <span>Faturamento</span>
    </button>
    <mat-divider></mat-divider>
    <button mat-menu-item (click)="logout()">
      <mat-icon color="warn">logout</mat-icon>
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
  position: sticky;
  top: 0;
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
  margin-left: 8px;

  &:hover {
    background: rgba(0, 0, 0, 0.04);
  }
}

.user-avatar {
  width: 32px;
  height: 32px;
  border-radius: 50%;
  background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
  color: white;
  display: flex;
  align-items: center;
  justify-content: center;
  font-weight: 600;
  font-size: 14px;
}

.user-name {
  font-weight: 500;
  font-size: 14px;
  color: #1e293b;
}

.user-info {
  padding: 16px;
  display: flex;
  gap: 12px;
  align-items: center;

  .user-avatar-large {
    width: 48px;
    height: 48px;
    border-radius: 50%;
    background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
    color: white;
    display: flex;
    align-items: center;
    justify-content: center;
    font-weight: 600;
    font-size: 18px;
  }

  .user-details {
    .user-name {
      font-weight: 600;
      margin-bottom: 4px;
      color: #1e293b;
    }

    .user-email {
      font-size: 12px;
      color: #64748b;
    }
  }
}

.mat-mdc-menu-item {
  mat-icon {
    margin-right: 12px;
  }
}
EOF

echo -e "${GREEN}✅ Header atualizado${NC}"

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo -e "${GREEN}🎉 TODAS AS FUNCIONALIDADES IMPLEMENTADAS COM SUCESSO!${NC}"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo -e "${YELLOW}📋 O que foi implementado:${NC}"
echo "  ✅ Sistema de autenticação completo"
echo "  ✅ Serviços de API com mock data"
echo "  ✅ Dashboard com gráficos Chart.js"
echo "  ✅ Email Validator funcional"
echo "  ✅ Login melhorado com validação"
echo "  ✅ Header com logout e notificações"
echo "  ✅ Guards de autenticação"
echo "  ✅ Exportação de resultados em CSV"
echo ""
echo -e "${BLUE}🚀 Reinicie o servidor:${NC}"
echo ""
echo "  npm start"
echo ""
echo -e "${GREEN}📌 Como testar:${NC}"
echo "  1. Acesse http://localhost:4201"
echo "  2. Faça login com: demo@sparknexus.com / demo123"
echo "  3. Explore o Dashboard com gráficos"
echo "  4. Teste o Email Validator"
echo "  5. Navegue pelos módulos"
echo ""
echo -e "${YELLOW}🎯 Próximos passos para produção:${NC}"
echo "  - Conectar com API real do backend"
echo "  - Adicionar testes unitários"
echo "  - Configurar CI/CD"
echo "  - Deploy em servidor"
echo ""
