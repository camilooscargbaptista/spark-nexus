// Interfaces do Spark Nexus

export interface User {
  id: string;
  email: string;
  name: string;
  organizationId: string;
  role: 'admin' | 'user' | 'viewer';
  createdAt: Date;
}

export interface Organization {
  id: string;
  name: string;
  slug: string;
  plan: 'trial' | 'starter' | 'growth' | 'scale';
  users: number;
  createdAt: Date;
  settings?: OrganizationSettings;
}

export interface OrganizationSettings {
  allowSignup: boolean;
  maxUsers: number;
  features: string[];
}

export interface Module {
  id: string;
  name: string;
  description: string;
  icon: string;
  status: 'active' | 'inactive' | 'trial';
  usage?: ModuleUsage;
  settings?: any;
}

export interface ModuleUsage {
  current: number;
  limit: number;
  period: 'daily' | 'weekly' | 'monthly';
  lastReset: Date;
}

export interface DashboardStats {
  totalModules: number;
  activeModules: number;
  totalUsers: number;
  currentUsage: number;
  events: DashboardEvent[];
}

export interface DashboardEvent {
  id: string;
  type: string;
  title: string;
  description: string;
  timestamp: Date;
  icon?: string;
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

export interface BillingInfo {
  plan: string;
  status: 'active' | 'cancelled' | 'past_due';
  currentPeriodEnd: Date;
  amount: number;
  currency: string;
  paymentMethod?: PaymentMethod;
  invoices: Invoice[];
}

export interface PaymentMethod {
  id: string;
  type: 'card' | 'bank';
  last4: string;
  brand?: string;
}

export interface Invoice {
  id: string;
  date: Date;
  amount: number;
  status: 'paid' | 'pending' | 'failed';
  downloadUrl?: string;
}
