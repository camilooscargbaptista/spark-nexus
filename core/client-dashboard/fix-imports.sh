#!/bin/bash

# Script para corrigir todos os imports e exportações
# Execute dentro da pasta client-dashboard

echo "🔧 Corrigindo imports e exportações..."
echo ""

# Cores
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}📝 Corrigindo exportações dos componentes...${NC}"

# Corrigir ModulesComponent
cat > src/app/features/modules/modules.ts << 'EOF'
import { Component } from '@angular/core';

@Component({
  selector: 'app-modules',
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

# Corrigir EmailValidatorComponent
cat > src/app/features/email-validator/email-validator.ts << 'EOF'
import { Component } from '@angular/core';

@Component({
  selector: 'app-email-validator',
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

# Corrigir BillingComponent
cat > src/app/features/billing/billing.ts << 'EOF'
import { Component } from '@angular/core';

@Component({
  selector: 'app-billing',
  templateUrl: './billing.html',
  styleUrls: ['./billing.scss']
})
export class BillingComponent {
  currentPlan = 'Growth';
  nextBillingDate = new Date();
  amount = 149;
}
EOF

# Corrigir SettingsComponent
cat > src/app/features/settings/settings.ts << 'EOF'
import { Component } from '@angular/core';

@Component({
  selector: 'app-settings',
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

# Corrigir LoginComponent
cat > src/app/features/login/login.ts << 'EOF'
import { Component } from '@angular/core';
import { Router } from '@angular/router';

@Component({
  selector: 'app-login',
  templateUrl: './login.html',
  styleUrls: ['./login.scss']
})
export class LoginComponent {
  email = '';
  password = '';

  constructor(private router: Router) {}

  login(): void {
    // TODO: Implementar login real
    console.log('Login:', this.email);
    this.router.navigate(['/dashboard']);
  }
}
EOF

echo -e "${GREEN}✅ Componentes corrigidos${NC}"
echo ""

echo -e "${BLUE}🔧 Corrigindo interceptors...${NC}"

# Corrigir AuthInterceptor
cat > src/app/core/interceptors/auth-interceptor.ts << 'EOF'
import { Injectable } from '@angular/core';
import { HttpRequest, HttpHandler, HttpEvent, HttpInterceptor } from '@angular/common/http';
import { Observable } from 'rxjs';

@Injectable()
export class AuthInterceptor implements HttpInterceptor {
  intercept(request: HttpRequest<any>, next: HttpHandler): Observable<HttpEvent<any>> {
    const token = localStorage.getItem('token');

    if (token) {
      request = request.clone({
        setHeaders: {
          Authorization: `Bearer ${token}`
        }
      });
    }

    return next.handle(request);
  }
}
EOF

# Corrigir ErrorInterceptor
cat > src/app/core/interceptors/error-interceptor.ts << 'EOF'
import { Injectable } from '@angular/core';
import { HttpRequest, HttpHandler, HttpEvent, HttpInterceptor, HttpErrorResponse } from '@angular/common/http';
import { Observable, throwError } from 'rxjs';
import { catchError } from 'rxjs/operators';

@Injectable()
export class ErrorInterceptor implements HttpInterceptor {
  intercept(request: HttpRequest<any>, next: HttpHandler): Observable<HttpEvent<any>> {
    return next.handle(request).pipe(
      catchError((error: HttpErrorResponse) => {
        console.error('HTTP Error:', error);
        return throwError(() => error);
      })
    );
  }
}
EOF

echo -e "${GREEN}✅ Interceptors corrigidos${NC}"
echo ""

echo -e "${BLUE}📝 Atualizando templates HTML...${NC}"

# Login HTML
cat > src/app/features/login/login.html << 'EOF'
<div class="login-container">
  <mat-card class="login-card">
    <mat-card-header>
      <mat-card-title>
        <span class="logo">🚀</span>
        Spark Nexus
      </mat-card-title>
    </mat-card-header>
    <mat-card-content>
      <h2>Entrar na sua conta</h2>
      <mat-form-field appearance="outline" class="full-width">
        <mat-label>Email</mat-label>
        <input matInput [(ngModel)]="email" type="email">
        <mat-icon matSuffix>email</mat-icon>
      </mat-form-field>

      <mat-form-field appearance="outline" class="full-width">
        <mat-label>Senha</mat-label>
        <input matInput [(ngModel)]="password" type="password">
        <mat-icon matSuffix>lock</mat-icon>
      </mat-form-field>

      <button mat-raised-button color="primary" class="full-width" (click)="login()">
        Entrar
      </button>
    </mat-card-content>
  </mat-card>
</div>
EOF

# Login SCSS
cat > src/app/features/login/login.scss << 'EOF'
.login-container {
  height: 100vh;
  display: flex;
  align-items: center;
  justify-content: center;
  background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
}

.login-card {
  width: 400px;
  padding: 20px;

  mat-card-header {
    justify-content: center;
    margin-bottom: 20px;

    mat-card-title {
      display: flex;
      align-items: center;
      gap: 10px;
      font-size: 24px;
      font-weight: 600;

      .logo {
        font-size: 32px;
      }
    }
  }

  h2 {
    text-align: center;
    margin-bottom: 20px;
    color: #1e293b;
  }

  .full-width {
    width: 100%;
    margin-bottom: 16px;
  }
}
EOF

# Modules HTML
cat > src/app/features/modules/modules.html << 'EOF'
<div class="modules-page">
  <div class="page-header">
    <h1>Módulos</h1>
    <p>Gerencie seus módulos ativos</p>
  </div>

  <div class="modules-grid">
    <mat-card *ngFor="let module of modules" class="module-card">
      <mat-card-header>
        <mat-icon>{{ module.icon }}</mat-icon>
        <mat-chip [class]="'status-' + module.status">
          {{ module.status }}
        </mat-chip>
      </mat-card-header>
      <mat-card-content>
        <h3>{{ module.name }}</h3>
        <button mat-button color="primary">Configurar</button>
      </mat-card-content>
    </mat-card>
  </div>
</div>
EOF

# Email Validator HTML
cat > src/app/features/email-validator/email-validator.html << 'EOF'
<div class="email-validator-page">
  <div class="page-header">
    <h1>Email Validator</h1>
    <p>Valide emails em massa</p>
  </div>

  <mat-card>
    <mat-card-content>
      <mat-form-field appearance="outline" class="full-width">
        <mat-label>Cole os emails aqui (um por linha)</mat-label>
        <textarea matInput [(ngModel)]="emailList" rows="10"></textarea>
      </mat-form-field>

      <button mat-raised-button color="primary" (click)="validateEmails()">
        <mat-icon>check_circle</mat-icon>
        Validar Emails
      </button>
    </mat-card-content>
  </mat-card>
</div>
EOF

# Billing HTML
cat > src/app/features/billing/billing.html << 'EOF'
<div class="billing-page">
  <div class="page-header">
    <h1>Faturamento</h1>
    <p>Gerencie sua assinatura e pagamentos</p>
  </div>

  <mat-card>
    <mat-card-header>
      <mat-card-title>Plano Atual: {{ currentPlan }}</mat-card-title>
    </mat-card-header>
    <mat-card-content>
      <p>Próxima cobrança: {{ nextBillingDate | date }}</p>
      <p>Valor: R$ {{ amount }}/mês</p>
      <button mat-raised-button color="primary">Alterar Plano</button>
    </mat-card-content>
  </mat-card>
</div>
EOF

# Settings HTML
cat > src/app/features/settings/settings.html << 'EOF'
<div class="settings-page">
  <div class="page-header">
    <h1>Configurações</h1>
    <p>Personalize sua experiência</p>
  </div>

  <mat-card>
    <mat-card-content>
      <mat-slide-toggle [(ngModel)]="settings.notifications">
        Notificações
      </mat-slide-toggle>
      <br><br>
      <mat-slide-toggle [(ngModel)]="settings.darkMode">
        Modo Escuro
      </mat-slide-toggle>
    </mat-card-content>
  </mat-card>
</div>
EOF

echo -e "${GREEN}✅ Templates atualizados${NC}"
echo ""

echo -e "${BLUE}📝 Criando estilos para as páginas...${NC}"

# Estilo comum para todas as páginas
COMMON_STYLES='
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

.full-width {
  width: 100%;
}
'

# Aplicar estilos
echo "$COMMON_STYLES" > src/app/features/modules/modules.scss
echo "$COMMON_STYLES" > src/app/features/email-validator/email-validator.scss
echo "$COMMON_STYLES" > src/app/features/billing/billing.scss
echo "$COMMON_STYLES" > src/app/features/settings/settings.scss

echo -e "${GREEN}✅ Estilos aplicados${NC}"
echo ""

echo -e "${BLUE}🔧 Verificando Material Module...${NC}"

# Verificar se MaterialModule existe, senão criar
if [ ! -f "src/app/shared/material.module.ts" ]; then
  echo -e "${YELLOW}Criando MaterialModule...${NC}"
  cat > src/app/shared/material.module.ts << 'EOF'
import { NgModule } from '@angular/core';
import { MatButtonModule } from '@angular/material/button';
import { MatCardModule } from '@angular/material/card';
import { MatIconModule } from '@angular/material/icon';
import { MatInputModule } from '@angular/material/input';
import { MatFormFieldModule } from '@angular/material/form-field';
import { MatSidenavModule } from '@angular/material/sidenav';
import { MatToolbarModule } from '@angular/material/toolbar';
import { MatListModule } from '@angular/material/list';
import { MatTableModule } from '@angular/material/table';
import { MatPaginatorModule } from '@angular/material/paginator';
import { MatSortModule } from '@angular/material/sort';
import { MatDialogModule } from '@angular/material/dialog';
import { MatSnackBarModule } from '@angular/material/snack-bar';
import { MatProgressSpinnerModule } from '@angular/material/progress-spinner';
import { MatProgressBarModule } from '@angular/material/progress-bar';
import { MatTabsModule } from '@angular/material/tabs';
import { MatCheckboxModule } from '@angular/material/checkbox';
import { MatRadioModule } from '@angular/material/radio';
import { MatSelectModule } from '@angular/material/select';
import { MatDatepickerModule } from '@angular/material/datepicker';
import { MatNativeDateModule } from '@angular/material/core';
import { MatMenuModule } from '@angular/material/menu';
import { MatTooltipModule } from '@angular/material/tooltip';
import { MatChipsModule } from '@angular/material/chips';
import { MatBadgeModule } from '@angular/material/badge';
import { MatExpansionModule } from '@angular/material/expansion';
import { MatSlideToggleModule } from '@angular/material/slide-toggle';
import { MatDividerModule } from '@angular/material/divider';

const MaterialModules = [
  MatButtonModule,
  MatCardModule,
  MatIconModule,
  MatInputModule,
  MatFormFieldModule,
  MatSidenavModule,
  MatToolbarModule,
  MatListModule,
  MatTableModule,
  MatPaginatorModule,
  MatSortModule,
  MatDialogModule,
  MatSnackBarModule,
  MatProgressSpinnerModule,
  MatProgressBarModule,
  MatTabsModule,
  MatCheckboxModule,
  MatRadioModule,
  MatSelectModule,
  MatDatepickerModule,
  MatNativeDateModule,
  MatMenuModule,
  MatTooltipModule,
  MatChipsModule,
  MatBadgeModule,
  MatExpansionModule,
  MatSlideToggleModule,
  MatDividerModule
];

@NgModule({
  imports: MaterialModules,
  exports: MaterialModules
})
export class MaterialModule { }
EOF
fi

echo -e "${GREEN}✅ Material Module verificado${NC}"
echo ""

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo -e "${GREEN}✅ CORREÇÕES APLICADAS COM SUCESSO!${NC}"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo -e "${YELLOW}📋 O que foi corrigido:${NC}"
echo "  ✅ Exportações dos componentes"
echo "  ✅ Interceptors convertidos para classes"
echo "  ✅ Templates HTML atualizados"
echo "  ✅ Estilos aplicados"
echo "  ✅ Material Module verificado"
echo ""
echo -e "${BLUE}🚀 Agora reinicie o servidor:${NC}"
echo ""
echo "  npm start"
echo ""
