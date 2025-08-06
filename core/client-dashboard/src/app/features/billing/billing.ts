import { Component } from '@angular/core';
import { CommonModule } from '@angular/common';
import { MatCardModule } from '@angular/material/card';
import { MatButtonModule } from '@angular/material/button';

@Component({
  selector: 'app-billing',
  standalone: true,
  imports: [CommonModule, MatCardModule, MatButtonModule],
  templateUrl: './billing.html',
  styleUrls: ['./billing.scss']
})
export class BillingComponent {
  currentPlan = 'Growth';
  nextBillingDate = new Date();
  amount = 149;
}
