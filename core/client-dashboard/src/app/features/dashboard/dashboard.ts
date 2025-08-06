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
