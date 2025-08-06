import { Component } from '@angular/core';
import { CommonModule } from '@angular/common';
import { MatCardModule } from '@angular/material/card';
import { MatIconModule } from '@angular/material/icon';
import { MatButtonModule } from '@angular/material/button';
import { MatChipsModule } from '@angular/material/chips';

@Component({
  selector: 'app-modules',
  standalone: true,
  imports: [CommonModule, MatCardModule, MatIconModule, MatButtonModule, MatChipsModule],
  templateUrl: './modules.html',
  styleUrls: ['./modules.scss']
})
export class ModulesComponent {
  modules = [
    { name: 'Email Validator', status: 'active', icon: 'email' },
    { name: 'CRM Connector', status: 'trial', icon: 'link' },
    { name: 'Lead Scorer', status: 'inactive', icon: 'analytics' }
  ];
}
