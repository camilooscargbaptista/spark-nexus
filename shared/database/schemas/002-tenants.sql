-- Spark Nexus Tenants Database Schema
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- Tenant-specific data isolation
CREATE SCHEMA IF NOT EXISTS tenant_demo_company;

-- Each tenant gets their own schema
-- This is created dynamically when a new organization signs up