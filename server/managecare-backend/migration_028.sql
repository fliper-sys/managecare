-- Applies the tables/columns that schema.sql already documents for the
-- Apartment vertical and the Admin panel, but which were never actually
-- migrated onto the live database (routes/apartments.js and routes/admin.js
-- reference these and would fail with "relation does not exist" otherwise).

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

-- Apartment booking payment ledger, replacing the Firestore
-- businesses/{id}/bookings/{id}/payments subcollection PaymentProvider used
-- to write to directly.
CREATE TABLE IF NOT EXISTS apartment_booking_payments (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  business_id UUID NOT NULL REFERENCES businesses(id) ON DELETE CASCADE,
  booking_id UUID NOT NULL REFERENCES apartment_bookings(id) ON DELETE CASCADE,
  amount DECIMAL(12,2) NOT NULL,
  currency TEXT NOT NULL DEFAULT 'NGN',
  provider TEXT,
  transaction_id TEXT,
  processor_response JSONB DEFAULT '{}',
  status TEXT NOT NULL DEFAULT 'completed',
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_apartments_business ON apartments(business_id, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_apartment_units_apartment ON apartment_units(business_id, apartment_id, name);
CREATE INDEX IF NOT EXISTS idx_apartment_bookings_business ON apartment_bookings(business_id, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_apartment_bookings_unit_dates ON apartment_bookings(unit_id, check_in_date, check_out_date, status);
CREATE INDEX IF NOT EXISTS idx_apartment_booking_payments_booking_id ON apartment_booking_payments(booking_id);
CREATE INDEX IF NOT EXISTS idx_apartment_booking_payments_business_id ON apartment_booking_payments(business_id);

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

-- businesses columns admin.js/admin_repository.dart reference that the live
-- table (migrated incrementally over this project's history) never got.
ALTER TABLE businesses ADD COLUMN IF NOT EXISTS owner_name TEXT;
ALTER TABLE businesses ADD COLUMN IF NOT EXISTS business_class TEXT DEFAULT 'tier1';
ALTER TABLE businesses ADD COLUMN IF NOT EXISTS max_workers INTEGER;
ALTER TABLE businesses ADD COLUMN IF NOT EXISTS features JSONB DEFAULT '{}';
ALTER TABLE businesses ADD COLUMN IF NOT EXISTS is_restricted BOOLEAN DEFAULT false;
ALTER TABLE businesses ADD COLUMN IF NOT EXISTS restriction_status TEXT DEFAULT 'active';
ALTER TABLE businesses ADD COLUMN IF NOT EXISTS restriction_reason TEXT;
ALTER TABLE businesses ADD COLUMN IF NOT EXISTS restricted_at TIMESTAMPTZ;
ALTER TABLE businesses ADD COLUMN IF NOT EXISTS restricted_by UUID;
ALTER TABLE businesses ADD COLUMN IF NOT EXISTS restriction_lifted_at TIMESTAMPTZ;

CREATE INDEX IF NOT EXISTS idx_businesses_restriction ON businesses(is_restricted, restriction_status);
CREATE INDEX IF NOT EXISTS idx_subscription_requests_business ON subscription_requests(business_id, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_payment_transactions_created ON payment_transactions(created_at DESC);
CREATE INDEX IF NOT EXISTS idx_payment_transactions_business ON payment_transactions(business_id);
CREATE INDEX IF NOT EXISTS idx_admin_work_items_status ON admin_work_items(status, priority);
CREATE INDEX IF NOT EXISTS idx_company_expenses_date ON company_expenses(expense_date DESC);
