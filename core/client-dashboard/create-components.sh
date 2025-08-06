#!/bin/bash

# Script para criar todos os componentes do Spark Nexus Client Dashboard
# Execute este script dentro da pasta client-dashboard

echo "🚀 Criando componentes do Spark Nexus..."
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

echo -e "${BLUE}📦 Criando módulos principais...${NC}"

# Criar módulos
ng generate module core --routing --skip-tests
ng generate module shared --skip-tests
ng generate module features --routing --skip-tests

echo -e "${GREEN}✅ Módulos criados${NC}"
echo ""

echo -e "${BLUE}🎨 Criando componentes do layout...${NC}"

# Componentes do core
ng generate component core/components/sidebar --skip-tests
ng generate component core/components/header --skip-tests
ng generate component core/components/layout --skip-tests

echo -e "${GREEN}✅ Componentes de layout criados${NC}"
echo ""

echo -e "${BLUE}📄 Criando páginas principais...${NC}"

# Features/Pages
ng generate component features/dashboard --skip-tests
ng generate component features/modules --skip-tests
ng generate component features/email-validator --skip-tests
ng generate component features/billing --skip-tests
ng generate component features/settings --skip-tests
ng generate component features/login --skip-tests

echo -e "${GREEN}✅ Páginas criadas${NC}"
echo ""

echo -e "${BLUE}🔧 Criando serviços...${NC}"

# Serviços
ng generate service core/services/auth --skip-tests
ng generate service core/services/api --skip-tests
ng generate service core/services/module --skip-tests
ng generate service core/services/organization --skip-tests
ng generate service core/services/theme --skip-tests

echo -e "${GREEN}✅ Serviços criados${NC}"
echo ""

echo -e "${BLUE}🛡️ Criando guards e interceptors...${NC}"

# Guards
ng generate guard core/guards/auth --implements CanActivate --skip-tests

# Interceptors
ng generate interceptor core/interceptors/auth --skip-tests
ng generate interceptor core/interceptors/error --skip-tests

echo -e "${GREEN}✅ Guards e interceptors criados${NC}"
echo ""

echo -e "${BLUE}📝 Criando interfaces...${NC}"

# Criar pasta de interfaces
mkdir -p src/app/core/interfaces

# Criar arquivo de interfaces
cat > src/app/core/interfaces/models.ts << 'EOF'
// Interfaces do Spark Nexus

export interface User {
  id: string;
  email: string;
  name: string;
  organizationId: string;
  role: 'admin' | 'user' | 'viewer';
  createdAt: Date;
}

export interface Organization {
  id: string;
  name: string;
  slug: string;
  plan: 'trial' | 'starter' | 'growth' | 'scale';
  users: number;
  createdAt: Date;
  settings?: OrganizationSettings;
}

export interface OrganizationSettings {
  allowSignup: boolean;
  maxUsers: number;
  features: string[];
}

export interface Module {
  id: string;
  name: string;
  description: string;
  icon: string;
  status: 'active' | 'inactive' | 'trial';
  usage?: ModuleUsage;
  settings?: any;
}

export interface ModuleUsage {
  current: number;
  limit: number;
  period: 'daily' | 'weekly' | 'monthly';
  lastReset: Date;
}

export interface DashboardStats {
  totalModules: number;
  activeModules: number;
  totalUsers: number;
  currentUsage: number;
  events: DashboardEvent[];
}

export interface DashboardEvent {
  id: string;
  type: string;
  title: string;
  description: string;
  timestamp: Date;
  icon?: string;
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

export interface BillingInfo {
  plan: string;
  status: 'active' | 'cancelled' | 'past_due';
  currentPeriodEnd: Date;
  amount: number;
  currency: string;
  paymentMethod?: PaymentMethod;
  invoices: Invoice[];
}

export interface PaymentMethod {
  id: string;
  type: 'card' | 'bank';
  last4: string;
  brand?: string;
}

export interface Invoice {
  id: string;
  date: Date;
  amount: number;
  status: 'paid' | 'pending' | 'failed';
  downloadUrl?: string;
}
EOF

echo -e "${GREEN}✅ Interfaces criadas${NC}"
echo ""

echo -e "${BLUE}🎨 Importando módulos do Angular Material...${NC}"

# Criar módulo compartilhado para Material
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
  MatSlideToggleModule
];

@NgModule({
  imports: MaterialModules,
  exports: MaterialModules
})
export class MaterialModule { }
EOF

echo -e "${GREEN}✅ Módulo Material criado${NC}"
echo ""

echo -e "${BLUE}📁 Estrutura final de pastas:${NC}"
echo ""
tree src/app -d -L 3 2>/dev/null || find src/app -type d -maxdepth 3 | sed 's|src/app|.|' | sort

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo -e "${GREEN}✅ TODOS OS COMPONENTES CRIADOS COM SUCESSO!${NC}"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo -e "${YELLOW}📋 Resumo:${NC}"
echo "  ✅ 3 módulos principais criados"
echo "  ✅ 9 componentes criados"
echo "  ✅ 5 serviços criados"
echo "  ✅ 1 guard criado"
echo "  ✅ 2 interceptors criados"
echo "  ✅ Interfaces TypeScript criadas"
echo "  ✅ Módulo Material configurado"
echo ""
echo -e "${BLUE}🚀 Próximo passo:${NC}"
echo "  Implementar a lógica dos componentes"
echo ""
