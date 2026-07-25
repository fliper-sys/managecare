-- ============================================================
-- ManageCare Complete Database Schema
-- Self-hosted Supabase/PostgreSQL backend
-- Run this on the VPS: psql -U postgres -d managecare -f schema.sql
-- ============================================================

-- Enable UUID generation
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- ============================================================
-- TABLES
-- ============================================================

-- PROFILES (extends GoTrue auth.users)
-- This table is automatically populated via a trigger on auth.users insert.
-- Do NOT drop; it's already in use.
-- ALTER TABLE profiles ADD COLUMN IF NOT EXISTS ...

-- Add missing columns to profiles if they don't exist
ALTER TABLE profiles ADD COLUMN IF NOT EXISTS pin TEXT;
ALTER TABLE profiles ADD COLUMN IF NOT EXISTS current_business_id UUID REFERENCES businesses(id);
ALTER TABLE profiles ADD COLUMN IF NOT EXISTS phone_number TEXT;
ALTER TABLE profiles ADD COLUMN IF NOT EXISTS photo_url TEXT;

-- BUSINESSES
-- Already exists. Add missing columns if needed.
ALTER TABLE businesses ADD COLUMN IF NOT EXISTS name TEXT NOT NULL DEFAULT '';
ALTER TABLE businesses ADD COLUMN IF NOT EXISTS owner_id UUID REFERENCES profiles(id);
ALTER TABLE businesses ADD COLUMN IF NOT EXISTS address TEXT;
ALTER TABLE businesses ADD COLUMN IF NOT EXISTS phone TEXT;
ALTER TABLE businesses ADD COLUMN IF NOT EXISTS email TEXT;
ALTER TABLE businesses ADD COLUMN IF NOT EXISTS currency TEXT DEFAULT 'NGN';
ALTER TABLE businesses ADD COLUMN IF NOT EXISTS logo_url TEXT;
ALTER TABLE businesses ADD COLUMN IF NOT EXISTS store_ids UUID[] DEFAULT '{}';
ALTER TABLE businesses ADD COLUMN IF NOT EXISTS is_active BOOLEAN DEFAULT true;
ALTER TABLE businesses ADD COLUMN IF NOT EXISTS last_sku_number INTEGER DEFAULT 0;
ALTER TABLE businesses ADD COLUMN IF NOT EXISTS subscription_tier TEXT DEFAULT 'free';
ALTER TABLE businesses ADD COLUMN IF NOT EXISTS subscription_start_date TIMESTAMPTZ;
ALTER TABLE businesses ADD COLUMN IF NOT EXISTS subscription_end_date TIMESTAMPTZ;
ALTER TABLE businesses ADD COLUMN IF NOT EXISTS is_subscription_active BOOLEAN DEFAULT false;
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
  full_name TEXT NOT NULL,
  phone TEXT,
  role TEXT NOT NULL DEFAULT 'staff',
  business_id UUID NOT NULL REFERENCES businesses(id) ON DELETE CASCADE,
  store_id UUID,
  is_active BOOLEAN DEFAULT true,
  permissions JSONB DEFAULT '{}',
  pin TEXT,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
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
CREATE POLICY business_isolation ON inventory
  USING (business_id IN (
    SELECT business_id FROM business_members WHERE user_id = auth.uid()
  ));

CREATE POLICY business_isolation ON sales
  USING (business_id IN (
    SELECT business_id FROM business_members WHERE user_id = auth.uid()
  ));

CREATE POLICY business_isolation ON customers
  USING (business_id IN (
    SELECT business_id FROM business_members WHERE user_id = auth.uid()
  ));

CREATE POLICY business_isolation ON workers
  USING (business_id IN (
    SELECT business_id FROM business_members WHERE user_id = auth.uid()
  ));

CREATE POLICY business_isolation ON attendance
  USING (business_id IN (
    SELECT business_id FROM business_members WHERE user_id = auth.uid()
  ));

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

DROP TRIGGER IF EXISTS on_auth_user_created ON auth.users;
CREATE TRIGGER on_auth_user_created
  AFTER INSERT ON auth.users
  FOR EACH ROW EXECUTE FUNCTION handle_new_user();
