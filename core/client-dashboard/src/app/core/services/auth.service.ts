import { Injectable, inject } from '@angular/core';
import { HttpClient } from '@angular/common/http';
import { Router } from '@angular/router';
import { Observable, BehaviorSubject, tap, map } from 'rxjs';

export interface User {
  id: string;
  email: string;
  name: string;
  organizationId: string;
  role: string;
}

export interface LoginResponse {
  token: string;
  user: User;
  expiresIn: number;
}

@Injectable({
  providedIn: 'root'
})
export class AuthService {
  private http = inject(HttpClient);
  private router = inject(Router);

  private apiUrl = 'http://localhost:3001/api';
  private currentUserSubject = new BehaviorSubject<User | null>(null);
  public currentUser$ = this.currentUserSubject.asObservable();

  constructor() {
    this.checkToken();
  }

  private checkToken(): void {
    const token = localStorage.getItem('token');
    const user = localStorage.getItem('user');
    if (token && user) {
      this.currentUserSubject.next(JSON.parse(user));
    }
  }

  login(email: string, password: string): Observable<LoginResponse> {

    console.log('login ----------------')
    // Por enquanto, simula login
    return new Observable(observer => {
      setTimeout(() => {
        const response: LoginResponse = {
          token: 'fake-jwt-token-' + Date.now(),
          user: {
            id: '1',
            email: email,
            name: email.split('@')[0],
            organizationId: 'org-1',
            role: 'admin'
          },
          expiresIn: 3600
        };

        localStorage.setItem('token', response.token);
        localStorage.setItem('user', JSON.stringify(response.user));
        this.currentUserSubject.next(response.user);

        observer.next(response);
        observer.complete();
      }, 1000);
    });

    // Quando tiver backend real:
    // return this.http.post<LoginResponse>(`${this.apiUrl}/auth/login`, { email, password })
    //   .pipe(
    //     tap(response => {
    //       localStorage.setItem('token', response.token);
    //       localStorage.setItem('user', JSON.stringify(response.user));
    //       this.currentUserSubject.next(response.user);
    //     })
    //   );
  }

  logout(): void {
    localStorage.removeItem('token');
    localStorage.removeItem('user');
    this.currentUserSubject.next(null);
    this.router.navigate(['/login']);
  }

  isAuthenticated(): boolean {
    return !!localStorage.getItem('token');
  }

  getToken(): string | null {
    return localStorage.getItem('token');
  }

  getCurrentUser(): User | null {
    return this.currentUserSubject.value;
  }
}
