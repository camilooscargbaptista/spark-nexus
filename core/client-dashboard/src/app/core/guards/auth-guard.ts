import { inject } from '@angular/core';
import { Router } from '@angular/router';
import { CanActivateFn } from '@angular/router';

export const authGuard: CanActivateFn = (route, state) => {
  const router = inject(Router);
  const token = localStorage.getItem('token');

  if (token) {
    return true;
  }

  // Por enquanto sempre retorna true para desenvolvimento
  return true;

  // Quando implementar auth real:
  // router.navigate(['/login']);
  // return false;
};
