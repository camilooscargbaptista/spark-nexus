#!/bin/bash

# Script para corrigir os tipos do Chart.js
# Execute dentro da pasta client-dashboard

echo "🔧 Corrigindo tipos do Chart.js..."
echo ""

# Cores
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}📝 Corrigindo dashboard.ts com tipos corretos do Chart.js...${NC}"

# Corrigir o Dashboard Component
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

// Definir tipo correto para trend
type TrendType = 'up' | 'down' | 'neutral';

interface StatCard {
  icon: string;
  title: string;
  value: string | number;
  change: string;
  trend: TrendType;
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

  stats: StatCard[] = [
    {
      icon: 'email',
      title: 'Emails Validados',
      value: '0',
      change: 'Carregando...',
      trend: 'neutral',
      color: '#4f46e5'
    },
    {
      icon: 'check_circle',
      title: 'Taxa de Válidos',
      value: '0%',
      change: 'Carregando...',
      trend: 'neutral',
      color: '#10b981'
    },
    {
      icon: 'trending_up',
      title: 'Score Médio',
      value: '0',
      change: 'Carregando...',
      trend: 'neutral',
      color: '#f59e0b'
    },
    {
      icon: 'account_balance_wallet',
      title: 'Créditos Restantes',
      value: '0',
      change: 'Carregando...',
      trend: 'neutral',
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
      // Atualizar estatísticas
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

      // Criar gráficos após um pequeno delay para garantir que o ViewChild está pronto
      setTimeout(() => {
        this.createLineChart(data.chartData);
        this.createDoughnutChart();
      }, 100);
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
    if (!this.lineChartRef || !this.lineChartRef.nativeElement) {
      console.warn('Line chart element not ready');
      return;
    }

    const ctx = this.lineChartRef.nativeElement.getContext('2d');

    // Destruir gráfico existente se houver
    if (this.lineChart) {
      this.lineChart.destroy();
    }

    this.lineChart = new Chart(ctx, {
      type: 'line',
      data: chartData,
      options: {
        responsive: true,
        maintainAspectRatio: false,
        plugins: {
          legend: {
            position: 'bottom',
            labels: {
              padding: 15,
              font: {
                size: 12
              }
            }
          },
          title: {
            display: true,
            text: 'Evolução Mensal',
            font: {
              size: 16,
              weight: 600  // Usar número em vez de string
            },
            padding: {
              bottom: 20
            }
          }
        },
        scales: {
          y: {
            beginAtZero: true,
            grid: {
              display: true,
              color: 'rgba(0, 0, 0, 0.05)'
            }
          },
          x: {
            grid: {
              display: false
            }
          }
        }
      }
    });
  }

  createDoughnutChart(): void {
    if (!this.doughnutChartRef || !this.doughnutChartRef.nativeElement) {
      console.warn('Doughnut chart element not ready');
      return;
    }

    const ctx = this.doughnutChartRef.nativeElement.getContext('2d');

    // Destruir gráfico existente se houver
    if (this.doughnutChart) {
      this.doughnutChart.destroy();
    }

    this.doughnutChart = new Chart(ctx, {
      type: 'doughnut',
      data: {
        labels: ['Válidos', 'Inválidos', 'Duvidosos'],
        datasets: [{
          data: [92.3, 5.2, 2.5],
          backgroundColor: [
            '#10b981',
            '#ef4444',
            '#f59e0b'
          ],
          borderWidth: 0
        }]
      },
      options: {
        responsive: true,
        maintainAspectRatio: false,
        plugins: {
          legend: {
            position: 'bottom',
            labels: {
              padding: 15,
              font: {
                size: 12
              }
            }
          },
          title: {
            display: true,
            text: 'Distribuição de Validações',
            font: {
              size: 16,
              weight: 600  // Usar número em vez de string
            },
            padding: {
              bottom: 20
            }
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

echo -e "${GREEN}✅ Dashboard corrigido com tipos corretos${NC}"

# Verificar se precisa instalar tipos do Chart.js
echo -e "${BLUE}📝 Verificando tipos do Chart.js...${NC}"

if ! npm list @types/chart.js >/dev/null 2>&1; then
    echo -e "${YELLOW}Instalando tipos do Chart.js...${NC}"
    npm install --save-dev @types/chart.js
    echo -e "${GREEN}✅ Tipos do Chart.js instalados${NC}"
else
    echo -e "${GREEN}✅ Tipos do Chart.js já estão instalados${NC}"
fi

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo -e "${GREEN}✅ TIPOS DO CHART.JS CORRIGIDOS!${NC}"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo -e "${YELLOW}📋 O que foi corrigido:${NC}"
echo "  ✅ weight: 600 (número) em vez de '600' (string)"
echo "  ✅ Tipos do Chart.js verificados"
echo ""
echo -e "${BLUE}🚀 Reinicie o servidor:${NC}"
echo ""
echo "  npm start"
echo ""
