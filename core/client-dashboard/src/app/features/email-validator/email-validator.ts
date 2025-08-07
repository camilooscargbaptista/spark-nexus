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
