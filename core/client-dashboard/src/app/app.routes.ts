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
