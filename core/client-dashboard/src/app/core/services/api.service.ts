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
