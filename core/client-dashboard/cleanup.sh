#!/bin/bash

# Script para limpar arquivos antigos e finalizar conversão para standalone
# Execute dentro da pasta client-dashboard

echo "🧹 Limpando arquivos antigos e finalizando conversão..."
echo ""

# Cores
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
RED='\033[0;31m'
NC='\033[0m'

echo -e "${YELLOW}🗑️ Removendo arquivos antigos do módulo...${NC}"

# Remover arquivos antigos
if [ -f "src/app/app-module.ts" ]; then
    rm src/app/app-module.ts
    echo -e "${GREEN}✅ app-module.ts removido${NC}"
fi

if [ -f "src/app/app-routing-module.ts" ]; then
    rm src/app/app-routing-module.ts
    echo -e "${GREEN}✅ app-routing-module.ts removido${NC}"
fi

# Remover módulos antigos se existirem
if [ -f "src/app/core/core.module.ts" ]; then
    rm src/app/core/core.module.ts
    echo -e "${GREEN}✅ core.module.ts removido${NC}"
fi

if [ -f "src/app/features/features.module.ts" ]; then
    rm src/app/features/features.module.ts
    echo -e "${GREEN}✅ features.module.ts removido${NC}"
fi

if [ -f "src/app/shared/shared.module.ts" ]; then
    rm src/app/shared/shared.module.ts
    echo -e "${GREEN}✅ shared.module.ts removido${NC}"
fi

echo ""
echo -e "${BLUE}📝 Verificando e atualizando main.ts...${NC}"

# Garantir que main.ts está correto
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

echo -e "${GREEN}✅ main.ts verificado${NC}"

echo ""
echo -e "${BLUE}📝 Verificando app.component...${NC}"

# Garantir que app.ts está correto
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

# Remover app.html se existir (não é mais necessário)
if [ -f "src/app/app.html" ]; then
    rm src/app/app.html
    echo -e "${GREEN}✅ app.html removido (template inline agora)${NC}"
fi

# Remover app.scss se estiver vazio
if [ -f "src/app/app.scss" ]; then
    if [ ! -s "src/app/app.scss" ]; then
        rm src/app/app.scss
        echo -e "${GREEN}✅ app.scss vazio removido${NC}"
    fi
fi

echo ""
echo -e "${BLUE}📝 Verificando arquivo de rotas...${NC}"

# Verificar se app.routes.ts existe
if [ ! -f "src/app/app.routes.ts" ]; then
    echo -e "${YELLOW}Criando arquivo de rotas...${NC}"
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
fi

echo -e "${GREEN}✅ Arquivo de rotas verificado${NC}"

echo ""
echo -e "${BLUE}🔍 Verificando se há referências aos arquivos antigos...${NC}"

# Procurar por referências aos módulos antigos
REFS_FOUND=0

if grep -r "app-module" src/ 2>/dev/null | grep -v "Binary file"; then
    echo -e "${RED}⚠️ Ainda há referências a app-module${NC}"
    REFS_FOUND=1
fi

if grep -r "app-routing-module" src/ 2>/dev/null | grep -v "Binary file"; then
    echo -e "${RED}⚠️ Ainda há referências a app-routing-module${NC}"
    REFS_FOUND=1
fi

if [ $REFS_FOUND -eq 0 ]; then
    echo -e "${GREEN}✅ Nenhuma referência aos arquivos antigos encontrada${NC}"
fi

echo ""
echo -e "${BLUE}📝 Criando arquivo de teste spec.ts atualizado...${NC}"

# Criar arquivo de teste para app component (opcional)
cat > src/app/app.spec.ts << 'EOF'
import { TestBed } from '@angular/core/testing';
import { RouterTestingModule } from '@angular/router/testing';
import { AppComponent } from './app';

describe('AppComponent', () => {
  beforeEach(async () => {
    await TestBed.configureTestingModule({
      imports: [AppComponent, RouterTestingModule]
    }).compileComponents();
  });

  it('should create the app', () => {
    const fixture = TestBed.createComponent(AppComponent);
    const app = fixture.componentInstance;
    expect(app).toBeTruthy();
  });

  it('should have a title', () => {
    const fixture = TestBed.createComponent(AppComponent);
    const app = fixture.componentInstance;
    expect(app.title).toEqual('Spark Nexus - Client Dashboard');
  });
});
EOF

echo -e "${GREEN}✅ Arquivo de teste criado${NC}"

echo ""
echo -e "${BLUE}🔧 Limpando cache do Angular...${NC}"

# Limpar cache do Angular
if [ -d ".angular" ]; then
    rm -rf .angular
    echo -e "${GREEN}✅ Cache do Angular limpo${NC}"
fi

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo -e "${GREEN}🎉 LIMPEZA E CONVERSÃO COMPLETAS!${NC}"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo -e "${YELLOW}📋 O que foi feito:${NC}"
echo "  ✅ Arquivos antigos de módulo removidos"
echo "  ✅ Aplicação totalmente standalone"
echo "  ✅ Cache limpo"
echo "  ✅ Arquivos verificados"
echo ""
echo -e "${BLUE}🚀 Agora execute:${NC}"
echo ""
echo "  npm start"
echo ""
echo -e "${GREEN}A aplicação deve funcionar sem erros!${NC}"
echo ""
echo -e "${YELLOW}📌 Estrutura atual:${NC}"
echo "  - main.ts (bootstrapApplication)"
echo "  - app.ts (AppComponent standalone)"
echo "  - app.routes.ts (rotas)"
echo "  - Todos os componentes standalone"
echo "  - Sem NgModules"
echo ""
