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
