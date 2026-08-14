-- ============================================================
-- ManageCare Complete Database Schema
-- Self-hosted Supabase/PostgreSQL backend
-- Run this on the VPS: psql -U postgres -d managecare -f schema.sql
-- ============================================================

-- Enable UUID generation
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
CREATE SCHEMA IF NOT EXISTS auth;

CREATE OR REPLACE FUNCTION auth.uid()
RETURNS UUID AS $$
BEGIN
  RETURN NULLIF(current_setting('request.jwt.claim.sub', true), '')::UUID;
EXCEPTION WHEN others THEN
  RETURN NULL;
END;
$$ LANGUAGE plpgsql STABLE;

-- ============================================================
-- TABLES
-- ============================================================

-- PROFILES (extends GoTrue auth.users)
-- This table is automatically populated via a trigger on auth.users insert.
-- Do NOT drop; it's already in use.
-- ALTER TABLE profiles ADD COLUMN IF NOT EXISTS ...
CREATE TABLE IF NOT EXISTS profiles (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  email TEXT UNIQUE,
  full_name TEXT,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS businesses (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  name TEXT NOT NULL DEFAULT '',
  business_type TEXT,
  owner_id UUID REFERENCES profiles(id),
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Add missing columns to profiles if they don't exist
ALTER TABLE profiles ADD COLUMN IF NOT EXISTS pin TEXT;
ALTER TABLE profiles ADD COLUMN IF NOT EXISTS current_business_id UUID REFERENCES businesses(id);
ALTER TABLE profiles ADD COLUMN IF NOT EXISTS phone_number TEXT;
ALTER TABLE profiles ADD COLUMN IF NOT EXISTS photo_url TEXT;
ALTER TABLE profiles ADD COLUMN IF NOT EXISTS password_hash TEXT;
ALTER TABLE profiles ADD COLUMN IF NOT EXISTS is_active BOOLEAN DEFAULT true;
ALTER TABLE profiles ADD COLUMN IF NOT EXISTS is_deleted BOOLEAN DEFAULT false;
ALTER TABLE profiles ADD COLUMN IF NOT EXISTS deleted_at TIMESTAMPTZ;
ALTER TABLE profiles ADD COLUMN IF NOT EXISTS deletion_reason TEXT;
ALTER TABLE profiles ADD COLUMN IF NOT EXISTS updated_at TIMESTAMPTZ DEFAULT NOW();

-- BUSINESSES
-- Already exists. Add missing columns if needed.
ALTER TABLE businesses ADD COLUMN IF NOT EXISTS name TEXT NOT NULL DEFAULT '';
ALTER TABLE businesses ADD COLUMN IF NOT EXISTS owner_id UUID REFERENCES profiles(id);
ALTER TABLE businesses ADD COLUMN IF NOT EXISTS address TEXT;
ALTER TABLE businesses ADD COLUMN IF NOT EXISTS phone TEXT;
ALTER TABLE businesses ADD COLUMN IF NOT EXISTS email TEXT;
ALTER TABLE businesses ADD COLUMN IF NOT EXISTS owner_name TEXT;
ALTER TABLE businesses ADD COLUMN IF NOT EXISTS currency TEXT DEFAULT 'NGN';
ALTER TABLE businesses ADD COLUMN IF NOT EXISTS logo_url TEXT;
ALTER TABLE businesses ADD COLUMN IF NOT EXISTS store_ids UUID[] DEFAULT '{}';
ALTER TABLE businesses ADD COLUMN IF NOT EXISTS is_active BOOLEAN DEFAULT true;
ALTER TABLE businesses ADD COLUMN IF NOT EXISTS last_sku_number INTEGER DEFAULT 0;
ALTER TABLE businesses ADD COLUMN IF NOT EXISTS business_class TEXT DEFAULT 'tier1';
ALTER TABLE businesses ADD COLUMN IF NOT EXISTS max_workers INTEGER;
ALTER TABLE businesses ADD COLUMN IF NOT EXISTS features JSONB DEFAULT '{}';
ALTER TABLE businesses ADD COLUMN IF NOT EXISTS subscription_tier TEXT DEFAULT 'free';
ALTER TABLE businesses ADD COLUMN IF NOT EXISTS subscription_plan TEXT DEFAULT 'free';
ALTER TABLE businesses ADD COLUMN IF NOT EXISTS subscription_start_date TIMESTAMPTZ;
ALTER TABLE businesses ADD COLUMN IF NOT EXISTS subscription_end_date TIMESTAMPTZ;
ALTER TABLE businesses ADD COLUMN IF NOT EXISTS is_subscription_active BOOLEAN DEFAULT false;
ALTER TABLE businesses ADD COLUMN IF NOT EXISTS is_restricted BOOLEAN DEFAULT false;
ALTER TABLE businesses ADD COLUMN IF NOT EXISTS restriction_status TEXT DEFAULT 'active';
ALTER TABLE businesses ADD COLUMN IF NOT EXISTS restriction_reason TEXT;
ALTER TABLE businesses ADD COLUMN IF NOT EXISTS restricted_at TIMESTAMPTZ;
ALTER TABLE businesses ADD COLUMN IF NOT EXISTS restricted_by UUID;
ALTER TABLE businesses ADD COLUMN IF NOT EXISTS restriction_lifted_at TIMESTAMPTZ;
ALTER TABLE businesses ADD COLUMN IF NOT EXISTS created_at TIMESTAMPTZ DEFAULT NOW();
ALTER TABLE businesses ADD COLUMN IF NOT EXISTS updated_at TIMESTAMPTZ DEFAULT NOW();

-- INVENTORY
CREATE TABLE IF NOT EXISTS inventory (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  business_id UUID NOT NULL REFERENCES businesses(id) ON DELETE CASCADE,
  name TEXT NOT NULL,
  sku TEXT,
  barcode TEXT,
  category TEXT,
  description TEXT,
  unit_price DECIMAL(12,2) NOT NULL DEFAULT 0,
  cost_price DECIMAL(12,2) DEFAULT 0,
  quantity DECIMAL(12,2) NOT NULL DEFAULT 0,
  min_stock_level DECIMAL(12,2) DEFAULT 0,
  unit TEXT DEFAULT 'pcs',
  expiry_date TIMESTAMPTZ,
  store_id UUID,
  is_active BOOLEAN DEFAULT true,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- SALES
CREATE TABLE IF NOT EXISTS sales (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  business_id UUID NOT NULL REFERENCES businesses(id) ON DELETE CASCADE,
  customer_id UUID,
  store_id UUID,
  worker_id UUID,
  worker_name TEXT,
  total_amount DECIMAL(12,2) NOT NULL,
  discount_amount DECIMAL(12,2) DEFAULT 0,
  tax_amount DECIMAL(12,2) DEFAULT 0,
  final_amount DECIMAL(12,2) NOT NULL,
  payment_method TEXT NOT NULL,
  status TEXT NOT NULL DEFAULT 'completed',
  notes TEXT,
  created_by UUID NOT NULL,
  sale_type TEXT DEFAULT 'retail',
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- SALE ITEMS
CREATE TABLE IF NOT EXISTS sale_items (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  sale_id UUID NOT NULL REFERENCES sales(id) ON DELETE CASCADE,
  product_id UUID,
  product_name TEXT NOT NULL,
  quantity DECIMAL(12,2) NOT NULL,
  unit_price DECIMAL(12,2) NOT NULL,
  discount DECIMAL(12,2) DEFAULT 0,
  total DECIMAL(12,2) NOT NULL,
  pricing_mode TEXT,
  inventory_unit TEXT,
  sale_unit TEXT,
  sale_unit_multiplier DECIMAL(12,2) DEFAULT 1
);

-- CUSTOMERS
CREATE TABLE IF NOT EXISTS customers (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  business_id UUID NOT NULL REFERENCES businesses(id) ON DELETE CASCADE,
  name TEXT NOT NULL,
  email TEXT,
  phone TEXT,
  address TEXT,
  city TEXT,
  state TEXT,
  loyalty_points INTEGER DEFAULT 0,
  total_purchases DECIMAL(12,2) DEFAULT 0,
  total_spent DECIMAL(12,2) DEFAULT 0,
  is_active BOOLEAN DEFAULT true,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- WORKERS (separate from profiles since workers may not have GoTrue accounts)
CREATE TABLE IF NOT EXISTS workers (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  email TEXT,
  password_hash TEXT,
  full_name TEXT NOT NULL,
  phone TEXT,
  role TEXT NOT NULL DEFAULT 'staff',
  business_id UUID NOT NULL REFERENCES businesses(id) ON DELETE CASCADE,
  store_id UUID,
  is_active BOOLEAN DEFAULT true,
  permissions JSONB DEFAULT '{}',
  pin TEXT,
  commission_percentage DECIMAL(5,2) DEFAULT 0,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- BUSINESS MEMBERS
CREATE TABLE IF NOT EXISTS business_members (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  user_id UUID NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
  business_id UUID NOT NULL REFERENCES businesses(id) ON DELETE CASCADE,
  role TEXT NOT NULL DEFAULT 'staff',
  store_id UUID,
  is_owner BOOLEAN DEFAULT false,
  is_active BOOLEAN DEFAULT true,
  permissions JSONB DEFAULT '{}',
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW(),
  UNIQUE(user_id, business_id)
);

-- ATTENDANCE (for biometric device integration)
CREATE TABLE IF NOT EXISTS attendance (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  worker_id UUID REFERENCES workers(id) ON DELETE SET NULL,
  business_id UUID REFERENCES businesses(id) ON DELETE CASCADE,
  device_sn TEXT,
  user_id_on_device TEXT,
  timestamp TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  status TEXT,
  verify_mode TEXT,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

-- DEVICES (biometric/ADMS devices)
CREATE TABLE IF NOT EXISTS devices (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  serial_number TEXT UNIQUE NOT NULL,
  business_id UUID REFERENCES businesses(id),
  name TEXT,
  last_seen TIMESTAMPTZ,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

-- EXPENSES
CREATE TABLE IF NOT EXISTS expenses (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  business_id UUID NOT NULL REFERENCES businesses(id) ON DELETE CASCADE,
  category TEXT NOT NULL,
  amount DECIMAL(12,2) NOT NULL,
  description TEXT,
  paid_by TEXT,
  receipt_url TEXT,
  created_by UUID,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- APARTMENT MANAGEMENT
CREATE TABLE IF NOT EXISTS apartments (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  business_id UUID NOT NULL REFERENCES businesses(id) ON DELETE CASCADE,
  title TEXT NOT NULL,
  description TEXT DEFAULT '',
  owner_id UUID,
  address TEXT DEFAULT '',
  photos JSONB DEFAULT '[]',
  amenities JSONB DEFAULT '[]',
  default_cancellation_policy_id TEXT,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS apartment_units (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  business_id UUID NOT NULL REFERENCES businesses(id) ON DELETE CASCADE,
  apartment_id UUID NOT NULL REFERENCES apartments(id) ON DELETE CASCADE,
  name TEXT NOT NULL,
  capacity INTEGER DEFAULT 1,
  price_per_night DECIMAL(12,2) DEFAULT 0,
  available_from TIMESTAMPTZ,
  available_to TIMESTAMPTZ,
  photos JSONB DEFAULT '[]',
  active BOOLEAN DEFAULT true,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS apartment_bookings (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  business_id UUID NOT NULL REFERENCES businesses(id) ON DELETE CASCADE,
  unit_id UUID REFERENCES apartment_units(id) ON DELETE SET NULL,
  apartment_id UUID REFERENCES apartments(id) ON DELETE SET NULL,
  tenant_id TEXT,
  check_in_date TIMESTAMPTZ NOT NULL,
  check_out_date TIMESTAMPTZ NOT NULL,
  nights INTEGER DEFAULT 0,
  guests INTEGER DEFAULT 1,
  status TEXT DEFAULT 'pending',
  subtotal DECIMAL(12,2) DEFAULT 0,
  deposit_amount DECIMAL(12,2) DEFAULT 0,
  discount DECIMAL(12,2) DEFAULT 0,
  total DECIMAL(12,2) DEFAULT 0,
  currency TEXT DEFAULT 'NGN',
  payment_status TEXT DEFAULT 'none',
  payment_method TEXT,
  provider_transaction_id TEXT,
  paid_at TIMESTAMPTZ,
  policy_snapshot JSONB DEFAULT '{}',
  receipt_url TEXT,
  receipt_pdf_path TEXT,
  next_reminder_at TIMESTAMPTZ,
  reminder_sent_flags JSONB DEFAULT '{}',
  cancel_reason TEXT,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_apartments_business ON apartments(business_id, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_apartment_units_apartment ON apartment_units(business_id, apartment_id, name);
CREATE INDEX IF NOT EXISTS idx_apartment_bookings_business ON apartment_bookings(business_id, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_apartment_bookings_unit_dates ON apartment_bookings(unit_id, check_in_date, check_out_date, status);

-- ADMIN SETTINGS
CREATE TABLE IF NOT EXISTS admin_settings (
  id TEXT PRIMARY KEY DEFAULT 'admin_settings',
  settings JSONB DEFAULT '{}',
  updated_by UUID,
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- ADMIN NOTIFICATIONS
CREATE TABLE IF NOT EXISTS admin_notifications (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  type TEXT NOT NULL,
  title TEXT NOT NULL,
  message TEXT,
  data JSONB DEFAULT '{}',
  is_read BOOLEAN DEFAULT false,
  created_by UUID,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

-- MANAGECARE INTERNAL WORKERS
CREATE TABLE IF NOT EXISTS managecare_workers (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  name TEXT NOT NULL,
  email TEXT,
  phone TEXT,
  role TEXT NOT NULL DEFAULT 'Customer Support',
  role_key TEXT,
  is_active BOOLEAN DEFAULT true,
  created_by UUID,
  updated_by UUID,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- ADMIN WORK ITEMS FOR PROGRAMMERS/IT
CREATE TABLE IF NOT EXISTS admin_work_items (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  title TEXT NOT NULL,
  description TEXT NOT NULL,
  assigned_to TEXT,
  type TEXT NOT NULL DEFAULT 'fix',
  priority TEXT DEFAULT 'normal',
  status TEXT DEFAULT 'pending',
  due_date TIMESTAMPTZ,
  created_by UUID,
  updated_by UUID,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- COMPANY EXPENSES REGISTERED BY MANAGECARE ADMIN
CREATE TABLE IF NOT EXISTS company_expenses (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  title TEXT NOT NULL,
  amount DECIMAL(12,2) NOT NULL DEFAULT 0,
  category TEXT,
  description TEXT,
  expense_date TIMESTAMPTZ DEFAULT NOW(),
  receipt_url TEXT,
  created_by UUID,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- APP MARKETERS
CREATE TABLE IF NOT EXISTS app_marketers (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  name TEXT,
  email TEXT,
  phone TEXT,
  is_active BOOLEAN DEFAULT true,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- SUBSCRIPTION HISTORY / REQUESTS
CREATE TABLE IF NOT EXISTS subscription_requests (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  business_id UUID REFERENCES businesses(id) ON DELETE SET NULL,
  user_id UUID REFERENCES profiles(id) ON DELETE SET NULL,
  plan_id TEXT,
  plan_name TEXT,
  amount DECIMAL(12,2) DEFAULT 0,
  currency TEXT DEFAULT 'NGN',
  status TEXT DEFAULT 'pending',
  payment_method TEXT,
  transaction_id TEXT,
  notes TEXT,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

ALTER TABLE subscription_requests ADD COLUMN IF NOT EXISTS business_id UUID REFERENCES businesses(id) ON DELETE SET NULL;
ALTER TABLE subscription_requests ADD COLUMN IF NOT EXISTS user_id UUID REFERENCES profiles(id) ON DELETE SET NULL;
ALTER TABLE subscription_requests ADD COLUMN IF NOT EXISTS plan_id TEXT;
ALTER TABLE subscription_requests ADD COLUMN IF NOT EXISTS plan_name TEXT;
ALTER TABLE subscription_requests ADD COLUMN IF NOT EXISTS amount DECIMAL(12,2) DEFAULT 0;
ALTER TABLE subscription_requests ADD COLUMN IF NOT EXISTS currency TEXT DEFAULT 'NGN';
ALTER TABLE subscription_requests ADD COLUMN IF NOT EXISTS status TEXT DEFAULT 'pending';
ALTER TABLE subscription_requests ADD COLUMN IF NOT EXISTS payment_method TEXT;
ALTER TABLE subscription_requests ADD COLUMN IF NOT EXISTS transaction_id TEXT;
ALTER TABLE subscription_requests ADD COLUMN IF NOT EXISTS notes TEXT;
ALTER TABLE subscription_requests ADD COLUMN IF NOT EXISTS created_at TIMESTAMPTZ DEFAULT NOW();
ALTER TABLE subscription_requests ADD COLUMN IF NOT EXISTS updated_at TIMESTAMPTZ DEFAULT NOW();

-- PAYMENT TRANSACTIONS FOR ADMIN REVENUE REPORTING
CREATE TABLE IF NOT EXISTS payment_transactions (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  business_id UUID REFERENCES businesses(id) ON DELETE SET NULL,
  business_name TEXT,
  transaction_id TEXT,
  amount DECIMAL(12,2) DEFAULT 0,
  currency TEXT DEFAULT 'NGN',
  email TEXT,
  method TEXT,
  status TEXT DEFAULT 'pending',
  business_category TEXT,
  business_tier TEXT,
  marketer_revenue DECIMAL(12,2) DEFAULT 0,
  marketer_commission DECIMAL(12,2) DEFAULT 0,
  processor_response JSONB DEFAULT '{}',
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

ALTER TABLE payment_transactions ADD COLUMN IF NOT EXISTS business_id UUID REFERENCES businesses(id) ON DELETE SET NULL;
ALTER TABLE payment_transactions ADD COLUMN IF NOT EXISTS business_name TEXT;
ALTER TABLE payment_transactions ADD COLUMN IF NOT EXISTS transaction_id TEXT;
ALTER TABLE payment_transactions ADD COLUMN IF NOT EXISTS amount DECIMAL(12,2) DEFAULT 0;
ALTER TABLE payment_transactions ADD COLUMN IF NOT EXISTS currency TEXT DEFAULT 'NGN';
ALTER TABLE payment_transactions ADD COLUMN IF NOT EXISTS email TEXT;
ALTER TABLE payment_transactions ADD COLUMN IF NOT EXISTS method TEXT;
ALTER TABLE payment_transactions ADD COLUMN IF NOT EXISTS status TEXT DEFAULT 'pending';
ALTER TABLE payment_transactions ADD COLUMN IF NOT EXISTS business_category TEXT;
ALTER TABLE payment_transactions ADD COLUMN IF NOT EXISTS business_tier TEXT;
ALTER TABLE payment_transactions ADD COLUMN IF NOT EXISTS marketer_revenue DECIMAL(12,2) DEFAULT 0;
ALTER TABLE payment_transactions ADD COLUMN IF NOT EXISTS marketer_commission DECIMAL(12,2) DEFAULT 0;
ALTER TABLE payment_transactions ADD COLUMN IF NOT EXISTS processor_response JSONB DEFAULT '{}';
ALTER TABLE payment_transactions ADD COLUMN IF NOT EXISTS created_at TIMESTAMPTZ DEFAULT NOW();
ALTER TABLE payment_transactions ADD COLUMN IF NOT EXISTS updated_at TIMESTAMPTZ DEFAULT NOW();

CREATE INDEX IF NOT EXISTS idx_businesses_restriction ON businesses(is_restricted, restriction_status);
CREATE INDEX IF NOT EXISTS idx_subscription_requests_business ON subscription_requests(business_id, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_payment_transactions_created ON payment_transactions(created_at DESC);
CREATE INDEX IF NOT EXISTS idx_payment_transactions_business ON payment_transactions(business_id);
CREATE INDEX IF NOT EXISTS idx_admin_work_items_status ON admin_work_items(status, priority);
CREATE INDEX IF NOT EXISTS idx_company_expenses_date ON company_expenses(expense_date DESC);

-- PROCUREMENT / PURCHASE ORDERS
CREATE TABLE IF NOT EXISTS procurements (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  business_id UUID NOT NULL REFERENCES businesses(id) ON DELETE CASCADE,
  supplier_name TEXT,
  total_amount DECIMAL(12,2) NOT NULL,
  status TEXT DEFAULT 'pending',
  notes TEXT,
  created_by UUID,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- SUPPLIERS / DISTRIBUTORS
CREATE TABLE IF NOT EXISTS distributors (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  business_id UUID NOT NULL REFERENCES businesses(id) ON DELETE CASCADE,
  name TEXT NOT NULL,
  contact_person TEXT,
  phone TEXT,
  email TEXT,
  address TEXT,
  is_active BOOLEAN DEFAULT true,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- SUBSCRIPTION TRANSACTIONS
CREATE TABLE IF NOT EXISTS subscription_transactions (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  business_id UUID NOT NULL REFERENCES businesses(id) ON DELETE CASCADE,
  user_id UUID REFERENCES profiles(id),
  amount DECIMAL(12,2) NOT NULL,
  plan TEXT NOT NULL,
  transaction_id TEXT,
  status TEXT DEFAULT 'pending',
  reference TEXT,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

-- Upgrade older partial VPS schemas where CREATE TABLE IF NOT EXISTS skipped
-- existing tables that were missing columns used by this backend.
ALTER TABLE inventory ADD COLUMN IF NOT EXISTS business_id UUID REFERENCES businesses(id) ON DELETE CASCADE;
ALTER TABLE inventory ADD COLUMN IF NOT EXISTS name TEXT;
ALTER TABLE inventory ADD COLUMN IF NOT EXISTS sku TEXT;
ALTER TABLE inventory ADD COLUMN IF NOT EXISTS barcode TEXT;
ALTER TABLE inventory ADD COLUMN IF NOT EXISTS category TEXT;
ALTER TABLE inventory ADD COLUMN IF NOT EXISTS description TEXT;
ALTER TABLE inventory ADD COLUMN IF NOT EXISTS unit_price DECIMAL(12,2) DEFAULT 0;
ALTER TABLE inventory ADD COLUMN IF NOT EXISTS cost_price DECIMAL(12,2) DEFAULT 0;
ALTER TABLE inventory ADD COLUMN IF NOT EXISTS quantity DECIMAL(12,2) DEFAULT 0;
ALTER TABLE inventory ADD COLUMN IF NOT EXISTS min_stock_level DECIMAL(12,2) DEFAULT 0;
ALTER TABLE inventory ADD COLUMN IF NOT EXISTS unit TEXT DEFAULT 'pcs';
ALTER TABLE inventory ADD COLUMN IF NOT EXISTS expiry_date TIMESTAMPTZ;
ALTER TABLE inventory ADD COLUMN IF NOT EXISTS store_id UUID;
ALTER TABLE inventory ADD COLUMN IF NOT EXISTS is_active BOOLEAN DEFAULT true;
ALTER TABLE inventory ADD COLUMN IF NOT EXISTS created_at TIMESTAMPTZ DEFAULT NOW();
ALTER TABLE inventory ADD COLUMN IF NOT EXISTS updated_at TIMESTAMPTZ DEFAULT NOW();

ALTER TABLE sales ADD COLUMN IF NOT EXISTS business_id UUID REFERENCES businesses(id) ON DELETE CASCADE;
ALTER TABLE sales ADD COLUMN IF NOT EXISTS customer_id UUID;
ALTER TABLE sales ADD COLUMN IF NOT EXISTS store_id UUID;
ALTER TABLE sales ADD COLUMN IF NOT EXISTS worker_id UUID;
ALTER TABLE sales ADD COLUMN IF NOT EXISTS worker_name TEXT;
ALTER TABLE sales ADD COLUMN IF NOT EXISTS total_amount DECIMAL(12,2) DEFAULT 0;
ALTER TABLE sales ADD COLUMN IF NOT EXISTS discount_amount DECIMAL(12,2) DEFAULT 0;
ALTER TABLE sales ADD COLUMN IF NOT EXISTS tax_amount DECIMAL(12,2) DEFAULT 0;
ALTER TABLE sales ADD COLUMN IF NOT EXISTS final_amount DECIMAL(12,2) DEFAULT 0;
ALTER TABLE sales ADD COLUMN IF NOT EXISTS payment_method TEXT;
ALTER TABLE sales ADD COLUMN IF NOT EXISTS status TEXT DEFAULT 'completed';
ALTER TABLE sales ADD COLUMN IF NOT EXISTS notes TEXT;
ALTER TABLE sales ADD COLUMN IF NOT EXISTS created_by UUID;
ALTER TABLE sales ADD COLUMN IF NOT EXISTS sale_type TEXT DEFAULT 'retail';
ALTER TABLE sales ADD COLUMN IF NOT EXISTS created_at TIMESTAMPTZ DEFAULT NOW();
ALTER TABLE sales ADD COLUMN IF NOT EXISTS updated_at TIMESTAMPTZ DEFAULT NOW();

ALTER TABLE sale_items ADD COLUMN IF NOT EXISTS sale_id UUID REFERENCES sales(id) ON DELETE CASCADE;
ALTER TABLE sale_items ADD COLUMN IF NOT EXISTS product_id UUID;
ALTER TABLE sale_items ADD COLUMN IF NOT EXISTS product_name TEXT;
ALTER TABLE sale_items ADD COLUMN IF NOT EXISTS quantity DECIMAL(12,2) DEFAULT 0;
ALTER TABLE sale_items ADD COLUMN IF NOT EXISTS unit_price DECIMAL(12,2) DEFAULT 0;
ALTER TABLE sale_items ADD COLUMN IF NOT EXISTS discount DECIMAL(12,2) DEFAULT 0;
ALTER TABLE sale_items ADD COLUMN IF NOT EXISTS total DECIMAL(12,2) DEFAULT 0;
ALTER TABLE sale_items ADD COLUMN IF NOT EXISTS pricing_mode TEXT;
ALTER TABLE sale_items ADD COLUMN IF NOT EXISTS inventory_unit TEXT;
ALTER TABLE sale_items ADD COLUMN IF NOT EXISTS sale_unit TEXT;
ALTER TABLE sale_items ADD COLUMN IF NOT EXISTS sale_unit_multiplier DECIMAL(12,2) DEFAULT 1;

ALTER TABLE customers ADD COLUMN IF NOT EXISTS business_id UUID REFERENCES businesses(id) ON DELETE CASCADE;
ALTER TABLE customers ADD COLUMN IF NOT EXISTS name TEXT;
ALTER TABLE customers ADD COLUMN IF NOT EXISTS email TEXT;
ALTER TABLE customers ADD COLUMN IF NOT EXISTS phone TEXT;
ALTER TABLE customers ADD COLUMN IF NOT EXISTS address TEXT;
ALTER TABLE customers ADD COLUMN IF NOT EXISTS city TEXT;
ALTER TABLE customers ADD COLUMN IF NOT EXISTS state TEXT;
ALTER TABLE customers ADD COLUMN IF NOT EXISTS loyalty_points INTEGER DEFAULT 0;
ALTER TABLE customers ADD COLUMN IF NOT EXISTS total_purchases DECIMAL(12,2) DEFAULT 0;
ALTER TABLE customers ADD COLUMN IF NOT EXISTS total_spent DECIMAL(12,2) DEFAULT 0;
ALTER TABLE customers ADD COLUMN IF NOT EXISTS is_active BOOLEAN DEFAULT true;
ALTER TABLE customers ADD COLUMN IF NOT EXISTS created_at TIMESTAMPTZ DEFAULT NOW();
ALTER TABLE customers ADD COLUMN IF NOT EXISTS updated_at TIMESTAMPTZ DEFAULT NOW();

ALTER TABLE workers ADD COLUMN IF NOT EXISTS email TEXT;
ALTER TABLE workers ADD COLUMN IF NOT EXISTS password_hash TEXT;
ALTER TABLE workers ADD COLUMN IF NOT EXISTS full_name TEXT;
ALTER TABLE workers ADD COLUMN IF NOT EXISTS phone TEXT;
ALTER TABLE workers ADD COLUMN IF NOT EXISTS role TEXT DEFAULT 'staff';
ALTER TABLE workers ADD COLUMN IF NOT EXISTS business_id UUID REFERENCES businesses(id) ON DELETE CASCADE;
ALTER TABLE workers ADD COLUMN IF NOT EXISTS store_id UUID;
ALTER TABLE workers ADD COLUMN IF NOT EXISTS is_active BOOLEAN DEFAULT true;
ALTER TABLE workers ADD COLUMN IF NOT EXISTS permissions JSONB DEFAULT '{}';
ALTER TABLE workers ADD COLUMN IF NOT EXISTS pin TEXT;
ALTER TABLE workers ADD COLUMN IF NOT EXISTS created_at TIMESTAMPTZ DEFAULT NOW();
ALTER TABLE workers ADD COLUMN IF NOT EXISTS updated_at TIMESTAMPTZ DEFAULT NOW();

ALTER TABLE attendance ADD COLUMN IF NOT EXISTS worker_id UUID REFERENCES workers(id) ON DELETE SET NULL;
ALTER TABLE attendance ADD COLUMN IF NOT EXISTS business_id UUID REFERENCES businesses(id) ON DELETE CASCADE;
ALTER TABLE attendance ADD COLUMN IF NOT EXISTS device_sn TEXT;
ALTER TABLE attendance ADD COLUMN IF NOT EXISTS user_id_on_device TEXT;
ALTER TABLE attendance ADD COLUMN IF NOT EXISTS timestamp TIMESTAMPTZ DEFAULT NOW();
ALTER TABLE attendance ADD COLUMN IF NOT EXISTS status TEXT;
ALTER TABLE attendance ADD COLUMN IF NOT EXISTS verify_mode TEXT;
ALTER TABLE attendance ADD COLUMN IF NOT EXISTS created_at TIMESTAMPTZ DEFAULT NOW();

ALTER TABLE devices ADD COLUMN IF NOT EXISTS serial_number TEXT;
ALTER TABLE devices ADD COLUMN IF NOT EXISTS business_id UUID REFERENCES businesses(id);
ALTER TABLE devices ADD COLUMN IF NOT EXISTS name TEXT;
ALTER TABLE devices ADD COLUMN IF NOT EXISTS last_seen TIMESTAMPTZ;
ALTER TABLE devices ADD COLUMN IF NOT EXISTS created_at TIMESTAMPTZ DEFAULT NOW();

ALTER TABLE expenses ADD COLUMN IF NOT EXISTS business_id UUID REFERENCES businesses(id) ON DELETE CASCADE;
ALTER TABLE expenses ADD COLUMN IF NOT EXISTS category TEXT;
ALTER TABLE expenses ADD COLUMN IF NOT EXISTS amount DECIMAL(12,2) DEFAULT 0;
ALTER TABLE expenses ADD COLUMN IF NOT EXISTS description TEXT;
ALTER TABLE expenses ADD COLUMN IF NOT EXISTS paid_by TEXT;
ALTER TABLE expenses ADD COLUMN IF NOT EXISTS receipt_url TEXT;
ALTER TABLE expenses ADD COLUMN IF NOT EXISTS created_by UUID;
ALTER TABLE expenses ADD COLUMN IF NOT EXISTS created_at TIMESTAMPTZ DEFAULT NOW();
ALTER TABLE expenses ADD COLUMN IF NOT EXISTS updated_at TIMESTAMPTZ DEFAULT NOW();

ALTER TABLE procurements ADD COLUMN IF NOT EXISTS business_id UUID REFERENCES businesses(id) ON DELETE CASCADE;
ALTER TABLE procurements ADD COLUMN IF NOT EXISTS supplier_name TEXT;
ALTER TABLE procurements ADD COLUMN IF NOT EXISTS total_amount DECIMAL(12,2) DEFAULT 0;
ALTER TABLE procurements ADD COLUMN IF NOT EXISTS status TEXT DEFAULT 'pending';
ALTER TABLE procurements ADD COLUMN IF NOT EXISTS notes TEXT;
ALTER TABLE procurements ADD COLUMN IF NOT EXISTS created_by UUID;
ALTER TABLE procurements ADD COLUMN IF NOT EXISTS created_at TIMESTAMPTZ DEFAULT NOW();
ALTER TABLE procurements ADD COLUMN IF NOT EXISTS updated_at TIMESTAMPTZ DEFAULT NOW();

ALTER TABLE distributors ADD COLUMN IF NOT EXISTS business_id UUID REFERENCES businesses(id) ON DELETE CASCADE;
ALTER TABLE distributors ADD COLUMN IF NOT EXISTS name TEXT;
ALTER TABLE distributors ADD COLUMN IF NOT EXISTS contact_person TEXT;
ALTER TABLE distributors ADD COLUMN IF NOT EXISTS phone TEXT;
ALTER TABLE distributors ADD COLUMN IF NOT EXISTS email TEXT;
ALTER TABLE distributors ADD COLUMN IF NOT EXISTS address TEXT;
ALTER TABLE distributors ADD COLUMN IF NOT EXISTS is_active BOOLEAN DEFAULT true;
ALTER TABLE distributors ADD COLUMN IF NOT EXISTS created_at TIMESTAMPTZ DEFAULT NOW();
ALTER TABLE distributors ADD COLUMN IF NOT EXISTS updated_at TIMESTAMPTZ DEFAULT NOW();

-- ============================================================
-- INDEXES
-- ============================================================

CREATE INDEX IF NOT EXISTS idx_inventory_business ON inventory(business_id);
CREATE INDEX IF NOT EXISTS idx_inventory_category ON inventory(category);
CREATE INDEX IF NOT EXISTS idx_inventory_sku ON inventory(sku);
CREATE INDEX IF NOT EXISTS idx_sales_business ON sales(business_id);
CREATE INDEX IF NOT EXISTS idx_sales_created ON sales(created_at DESC);
CREATE INDEX IF NOT EXISTS idx_sales_status ON sales(status);
CREATE INDEX IF NOT EXISTS idx_sales_payment ON sales(payment_method);
CREATE INDEX IF NOT EXISTS idx_sale_items_sale ON sale_items(sale_id);
CREATE INDEX IF NOT EXISTS idx_customers_business ON customers(business_id);
CREATE INDEX IF NOT EXISTS idx_customers_phone ON customers(phone);
CREATE INDEX IF NOT EXISTS idx_workers_business ON workers(business_id);
CREATE INDEX IF NOT EXISTS idx_workers_email ON workers(email);
CREATE INDEX IF NOT EXISTS idx_business_members_user ON business_members(user_id);
CREATE INDEX IF NOT EXISTS idx_business_members_business ON business_members(business_id);
CREATE INDEX IF NOT EXISTS idx_business_members_active ON business_members(business_id, is_active) WHERE is_active = true;
CREATE INDEX IF NOT EXISTS idx_attendance_worker ON attendance(worker_id);
CREATE INDEX IF NOT EXISTS idx_attendance_timestamp ON attendance(timestamp DESC);
CREATE INDEX IF NOT EXISTS idx_attendance_business ON attendance(business_id);
CREATE INDEX IF NOT EXISTS idx_attendance_device ON attendance(device_sn);
CREATE INDEX IF NOT EXISTS idx_devices_serial ON devices(serial_number);
CREATE INDEX IF NOT EXISTS idx_expenses_business ON expenses(business_id);
CREATE INDEX IF NOT EXISTS idx_procurements_business ON procurements(business_id);
CREATE INDEX IF NOT EXISTS idx_distributors_business ON distributors(business_id);
CREATE INDEX IF NOT EXISTS idx_subscription_transactions_business ON subscription_transactions(business_id);

-- ============================================================
-- FUNCTIONS
-- ============================================================

-- Create business with owner (called from Flutter registration)
CREATE OR REPLACE FUNCTION create_business_with_owner(
  p_name TEXT,
  p_business_type TEXT,
  p_owner_id UUID DEFAULT NULL
) RETURNS UUID AS $$
DECLARE
  v_business_id UUID;
  v_owner_id UUID;
BEGIN
  v_owner_id := COALESCE(p_owner_id, auth.uid());
  IF v_owner_id IS NULL THEN
    RAISE EXCEPTION 'owner_id is required';
  END IF;

  INSERT INTO businesses (name, business_type, owner_id, is_active)
  VALUES (p_name, p_business_type, v_owner_id, true)
  RETURNING id INTO v_business_id;

  INSERT INTO business_members (user_id, business_id, role, is_owner, is_active)
  VALUES (v_owner_id, v_business_id, 'owner', true, true);

  RETURN v_business_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Get daily sales summary
CREATE OR REPLACE FUNCTION get_daily_sales_summary(
  p_business_id UUID,
  p_date DATE DEFAULT CURRENT_DATE
) RETURNS TABLE (
  total_sales DECIMAL(12,2),
  transaction_count BIGINT,
  average_sale DECIMAL(12,2),
  payment_breakdown JSONB
) AS $$
BEGIN
  RETURN QUERY
  SELECT
    COALESCE(SUM(final_amount), 0)::DECIMAL(12,2) as total_sales,
    COUNT(*)::BIGINT as transaction_count,
    COALESCE(AVG(final_amount), 0)::DECIMAL(12,2) as average_sale,
    COALESCE(
      jsonb_agg(
        jsonb_build_object(
          'method', payment_method,
          'total', SUM(final_amount)::DECIMAL(12,2)
        )
      ) FILTER (WHERE payment_method IS NOT NULL),
      '[]'::JSONB
    ) as payment_breakdown
  FROM sales
  WHERE business_id = p_business_id
    AND DATE(created_at) = p_date
    AND status = 'completed';
END;
$$ LANGUAGE plpgsql STABLE;

-- ============================================================
-- ROW LEVEL SECURITY
-- ============================================================

-- Enable RLS on all tables
ALTER TABLE inventory ENABLE ROW LEVEL SECURITY;
ALTER TABLE sales ENABLE ROW LEVEL SECURITY;
ALTER TABLE sale_items ENABLE ROW LEVEL SECURITY;
ALTER TABLE customers ENABLE ROW LEVEL SECURITY;
ALTER TABLE workers ENABLE ROW LEVEL SECURITY;
ALTER TABLE attendance ENABLE ROW LEVEL SECURITY;
ALTER TABLE expenses ENABLE ROW LEVEL SECURITY;
ALTER TABLE procurements ENABLE ROW LEVEL SECURITY;
ALTER TABLE distributors ENABLE ROW LEVEL SECURITY;

-- Users can only access data for their own businesses
DROP POLICY IF EXISTS business_isolation ON inventory;
CREATE POLICY business_isolation ON inventory
  USING (business_id IN (
    SELECT business_id FROM business_members WHERE user_id = auth.uid()
  ));

DROP POLICY IF EXISTS business_isolation ON sales;
CREATE POLICY business_isolation ON sales
  USING (business_id IN (
    SELECT business_id FROM business_members WHERE user_id = auth.uid()
  ));

DROP POLICY IF EXISTS business_isolation ON customers;
CREATE POLICY business_isolation ON customers
  USING (business_id IN (
    SELECT business_id FROM business_members WHERE user_id = auth.uid()
  ));

DROP POLICY IF EXISTS business_isolation ON workers;
CREATE POLICY business_isolation ON workers
  USING (business_id IN (
    SELECT business_id FROM business_members WHERE user_id = auth.uid()
  ));

DROP POLICY IF EXISTS business_isolation ON attendance;
CREATE POLICY business_isolation ON attendance
  USING (business_id IN (
    SELECT business_id FROM business_members WHERE user_id = auth.uid()
  ));

DROP POLICY IF EXISTS business_isolation ON expenses;
CREATE POLICY business_isolation ON expenses
  USING (business_id IN (
    SELECT business_id FROM business_members WHERE user_id = auth.uid()
  ));

-- ============================================================
-- TRIGGER: auto-create profile on user signup (GoTrue)
-- ============================================================
CREATE OR REPLACE FUNCTION handle_new_user()
RETURNS TRIGGER AS $$
BEGIN
  INSERT INTO public.profiles (id, email, full_name)
  VALUES (NEW.id, NEW.email, COALESCE(NEW.raw_user_meta_data->>'full_name', ''));
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

DO $$
BEGIN
  IF to_regclass('auth.users') IS NOT NULL THEN
    EXECUTE 'DROP TRIGGER IF EXISTS on_auth_user_created ON auth.users';
    EXECUTE 'CREATE TRIGGER on_auth_user_created
      AFTER INSERT ON auth.users
      FOR EACH ROW EXECUTE FUNCTION handle_new_user()';
  END IF;
END;
$$;

DO $$
BEGIN
  IF EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'managecare') THEN
    GRANT USAGE ON SCHEMA public TO managecare;
    GRANT USAGE ON SCHEMA auth TO managecare;
    GRANT SELECT, INSERT, UPDATE, DELETE ON ALL TABLES IN SCHEMA public TO managecare;
    GRANT USAGE, SELECT ON ALL SEQUENCES IN SCHEMA public TO managecare;
    GRANT EXECUTE ON ALL FUNCTIONS IN SCHEMA public TO managecare;
    ALTER DEFAULT PRIVILEGES IN SCHEMA public
      GRANT SELECT, INSERT, UPDATE, DELETE ON TABLES TO managecare;
    ALTER DEFAULT PRIVILEGES IN SCHEMA public
      GRANT USAGE, SELECT ON SEQUENCES TO managecare;
    ALTER DEFAULT PRIVILEGES IN SCHEMA public
      GRANT EXECUTE ON FUNCTIONS TO managecare;
  END IF;
END;
$$;
