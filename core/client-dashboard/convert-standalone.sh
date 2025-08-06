#!/bin/bash

# Script para configurar a aplicação com standalone components (padrão moderno)
# Execute dentro da pasta client-dashboard

echo "🚀 Convertendo para aplicação standalone moderna..."
echo ""

# Cores
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}📝 Atualizando main.ts para standalone...${NC}"

# Atualizar main.ts para usar bootstrapApplication
cat > src/main.ts << 'EOF'
import { bootstrapApplication } from '@angular/platform-browser';
import { provideRouter } from '@angular/router';
import { provideAnimations } from '@angular/platform-browser/animations';
import { provideHttpClient, withInterceptors } from '@angular/common/http';
import { importProvidersFrom } from '@angular/core';
import { MatNativeDateModule } from '@angular/material/core';

import { AppComponent } from './app/app';
import { routes } from './app/app.routes';
import { authInterceptor } from './app/core/interceptors/auth-interceptor';
import { errorInterceptor } from './app/core/interceptors/error-interceptor';

bootstrapApplication(AppComponent, {
  providers: [
    provideRouter(routes),
    provideAnimations(),
    provideHttpClient(
      withInterceptors([authInterceptor, errorInterceptor])
    ),
    importProvidersFrom(MatNativeDateModule)
  ]
}).catch(err => console.error(err));
EOF

echo -e "${GREEN}✅ main.ts atualizado${NC}"

echo -e "${BLUE}📝 Criando app.routes.ts...${NC}"

# Criar arquivo de rotas
cat > src/app/app.routes.ts << 'EOF'
import { Routes } from '@angular/router';
import { LayoutComponent } from './core/components/layout/layout';
import { LoginComponent } from './features/login/login';
import { DashboardComponent } from './features/dashboard/dashboard';
import { ModulesComponent } from './features/modules/modules';
import { EmailValidatorComponent } from './features/email-validator/email-validator';
import { BillingComponent } from './features/billing/billing';
import { SettingsComponent } from './features/settings/settings';
import { authGuard } from './core/guards/auth-guard';

export const routes: Routes = [
  {
    path: 'login',
    component: LoginComponent
  },
  {
    path: '',
    component: LayoutComponent,
    canActivate: [authGuard],
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
EOF

echo -e "${GREEN}✅ Rotas criadas${NC}"

echo -e "${BLUE}📝 Atualizando AppComponent para standalone...${NC}"

# AppComponent standalone
cat > src/app/app.ts << 'EOF'
import { Component } from '@angular/core';
import { RouterOutlet } from '@angular/router';

@Component({
  selector: 'app-root',
  standalone: true,
  imports: [RouterOutlet],
  template: '<router-outlet></router-outlet>',
  styles: []
})
export class AppComponent {
  title = 'Spark Nexus - Client Dashboard';
}
EOF

echo -e "${GREEN}✅ AppComponent atualizado${NC}"

echo -e "${BLUE}📝 Atualizando componentes para standalone com imports corretos...${NC}"

# LayoutComponent
cat > src/app/core/components/layout/layout.ts << 'EOF'
import { Component } from '@angular/core';
import { CommonModule } from '@angular/common';
import { RouterOutlet } from '@angular/router';
import { SidebarComponent } from '../sidebar/sidebar';
import { HeaderComponent } from '../header/header';

@Component({
  selector: 'app-layout',
  standalone: true,
  imports: [CommonModule, RouterOutlet, SidebarComponent, HeaderComponent],
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

# SidebarComponent
cat > src/app/core/components/sidebar/sidebar.ts << 'EOF'
import { Component, Input } from '@angular/core';
import { CommonModule } from '@angular/common';
import { Router } from '@angular/router';
import { MatIconModule } from '@angular/material/icon';
import { MatButtonModule } from '@angular/material/button';

interface MenuItem {
  icon: string;
  label: string;
  route: string;
  badge?: number;
}

@Component({
  selector: 'app-sidebar',
  standalone: true,
  imports: [CommonModule, MatIconModule, MatButtonModule],
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

# HeaderComponent
cat > src/app/core/components/header/header.ts << 'EOF'
import { Component, Output, EventEmitter } from '@angular/core';
import { CommonModule } from '@angular/common';
import { MatToolbarModule } from '@angular/material/toolbar';
import { MatIconModule } from '@angular/material/icon';
import { MatButtonModule } from '@angular/material/button';
import { MatMenuModule } from '@angular/material/menu';
import { MatDividerModule } from '@angular/material/divider';

@Component({
  selector: 'app-header',
  standalone: true,
  imports: [
    CommonModule,
    MatToolbarModule,
    MatIconModule,
    MatButtonModule,
    MatMenuModule,
    MatDividerModule
  ],
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
    console.log('Logout');
  }
}
EOF

# DashboardComponent
cat > src/app/features/dashboard/dashboard.ts << 'EOF'
import { Component, OnInit } from '@angular/core';
import { CommonModule } from '@angular/common';
import { MatCardModule } from '@angular/material/card';
import { MatIconModule } from '@angular/material/icon';
import { MatButtonModule } from '@angular/material/button';
import { MatChipsModule } from '@angular/material/chips';
import { MatProgressBarModule } from '@angular/material/progress-bar';

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
  standalone: true,
  imports: [
    CommonModule,
    MatCardModule,
    MatIconModule,
    MatButtonModule,
    MatChipsModule,
    MatProgressBarModule
  ],
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

# LoginComponent
cat > src/app/features/login/login.ts << 'EOF'
import { Component } from '@angular/core';
import { CommonModule } from '@angular/common';
import { FormsModule } from '@angular/forms';
import { Router } from '@angular/router';
import { MatCardModule } from '@angular/material/card';
import { MatInputModule } from '@angular/material/input';
import { MatFormFieldModule } from '@angular/material/form-field';
import { MatButtonModule } from '@angular/material/button';
import { MatIconModule } from '@angular/material/icon';

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
    MatIconModule
  ],
  templateUrl: './login.html',
  styleUrls: ['./login.scss']
})
export class LoginComponent {
  email = '';
  password = '';

  constructor(private router: Router) {}

  login(): void {
    console.log('Login:', this.email);
    localStorage.setItem('token', 'fake-token');
    this.router.navigate(['/dashboard']);
  }
}
EOF

# Outros componentes
cat > src/app/features/modules/modules.ts << 'EOF'
import { Component } from '@angular/core';
import { CommonModule } from '@angular/common';
import { MatCardModule } from '@angular/material/card';
import { MatIconModule } from '@angular/material/icon';
import { MatButtonModule } from '@angular/material/button';
import { MatChipsModule } from '@angular/material/chips';

@Component({
  selector: 'app-modules',
  standalone: true,
  imports: [CommonModule, MatCardModule, MatIconModule, MatButtonModule, MatChipsModule],
  templateUrl: './modules.html',
  styleUrls: ['./modules.scss']
})
export class ModulesComponent {
  modules = [
    { name: 'Email Validator', status: 'active', icon: 'email' },
    { name: 'CRM Connector', status: 'trial', icon: 'link' },
    { name: 'Lead Scorer', status: 'inactive', icon: 'analytics' }
  ];
}
EOF

cat > src/app/features/email-validator/email-validator.ts << 'EOF'
import { Component } from '@angular/core';
import { CommonModule } from '@angular/common';
import { FormsModule } from '@angular/forms';
import { MatCardModule } from '@angular/material/card';
import { MatInputModule } from '@angular/material/input';
import { MatFormFieldModule } from '@angular/material/form-field';
import { MatButtonModule } from '@angular/material/button';
import { MatIconModule } from '@angular/material/icon';

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
    MatIconModule
  ],
  templateUrl: './email-validator.html',
  styleUrls: ['./email-validator.scss']
})
export class EmailValidatorComponent {
  emailList = '';
  results: any[] = [];

  validateEmails(): void {
    console.log('Validating emails...');
  }
}
EOF

cat > src/app/features/billing/billing.ts << 'EOF'
import { Component } from '@angular/core';
import { CommonModule } from '@angular/common';
import { MatCardModule } from '@angular/material/card';
import { MatButtonModule } from '@angular/material/button';

@Component({
  selector: 'app-billing',
  standalone: true,
  imports: [CommonModule, MatCardModule, MatButtonModule],
  templateUrl: './billing.html',
  styleUrls: ['./billing.scss']
})
export class BillingComponent {
  currentPlan = 'Growth';
  nextBillingDate = new Date();
  amount = 149;
}
EOF

cat > src/app/features/settings/settings.ts << 'EOF'
import { Component } from '@angular/core';
import { CommonModule } from '@angular/common';
import { FormsModule } from '@angular/forms';
import { MatCardModule } from '@angular/material/card';
import { MatSlideToggleModule } from '@angular/material/slide-toggle';

@Component({
  selector: 'app-settings',
  standalone: true,
  imports: [CommonModule, FormsModule, MatCardModule, MatSlideToggleModule],
  templateUrl: './settings.html',
  styleUrls: ['./settings.scss']
})
export class SettingsComponent {
  settings = {
    notifications: true,
    darkMode: false,
    language: 'pt-BR'
  };
}
EOF

echo -e "${GREEN}✅ Componentes atualizados${NC}"

echo -e "${BLUE}📝 Atualizando guards para função...${NC}"

# Auth Guard como função
cat > src/app/core/guards/auth-guard.ts << 'EOF'
import { inject } from '@angular/core';
import { Router } from '@angular/router';
import { CanActivateFn } from '@angular/router';

export const authGuard: CanActivateFn = (route, state) => {
  const router = inject(Router);
  const token = localStorage.getItem('token');

  if (token) {
    return true;
  }

  // Por enquanto sempre retorna true para desenvolvimento
  return true;

  // Quando implementar auth real:
  // router.navigate(['/login']);
  // return false;
};
EOF

echo -e "${GREEN}✅ Guard atualizado${NC}"

echo -e "${BLUE}📝 Atualizando interceptors para função...${NC}"

# Auth Interceptor como função
cat > src/app/core/interceptors/auth-interceptor.ts << 'EOF'
import { HttpInterceptorFn } from '@angular/common/http';

export const authInterceptor: HttpInterceptorFn = (req, next) => {
  const token = localStorage.getItem('token');

  if (token) {
    req = req.clone({
      setHeaders: {
        Authorization: `Bearer ${token}`
      }
    });
  }

  return next(req);
};
EOF

# Error Interceptor como função
cat > src/app/core/interceptors/error-interceptor.ts << 'EOF'
import { HttpInterceptorFn } from '@angular/common/http';
import { catchError, throwError } from 'rxjs';

export const errorInterceptor: HttpInterceptorFn = (req, next) => {
  return next(req).pipe(
    catchError((error) => {
      console.error('HTTP Error:', error);
      return throwError(() => error);
    })
  );
};
EOF

echo -e "${GREEN}✅ Interceptors atualizados${NC}"

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo -e "${GREEN}✅ APLICAÇÃO CONVERTIDA PARA STANDALONE!${NC}"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo -e "${YELLOW}📋 O que foi feito:${NC}"
echo "  ✅ Convertido para aplicação standalone (padrão moderno)"
echo "  ✅ main.ts usa bootstrapApplication"
echo "  ✅ Componentes com imports corretos"
echo "  ✅ Guards e interceptors como funções"
echo "  ✅ Rotas configuradas"
echo ""
echo -e "${BLUE}🚀 Reinicie o servidor:${NC}"
echo ""
echo "  npm start"
echo ""
