-- Drink/Bar vertical. Drinks themselves are just inventory items (the
-- `inventory` table/routes, already used by every migrated vertical);
-- bottlesPerCarton/emoji-style extras fold into inventory.metadata (already
-- added for pharmacy). This migration adds what's genuinely bar-specific:
-- saved bar table labels, draft orders (pre-payment), and invoices/tabs
-- (open tab -> converted to a sale on payment). It also adds a generic
-- metadata column to customers, reusing the same JSONB-escape-hatch pattern,
-- so bar-specific customer stats (preferred table, common purchases) don't
-- need their own columns.
ALTER TABLE customers ADD COLUMN IF NOT EXISTS metadata JSONB NOT NULL DEFAULT '{}';

CREATE TABLE IF NOT EXISTS bar_tables (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  business_id UUID NOT NULL REFERENCES businesses(id) ON DELETE CASCADE,
  label TEXT NOT NULL,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  UNIQUE (business_id, label)
);
CREATE INDEX IF NOT EXISTS idx_bar_tables_business_id ON bar_tables(business_id);

CREATE TABLE IF NOT EXISTS drink_orders (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  business_id UUID NOT NULL REFERENCES businesses(id) ON DELETE CASCADE,
  status TEXT NOT NULL DEFAULT 'pending',
  lines JSONB NOT NULL DEFAULT '[]',
  total DECIMAL(12,2) NOT NULL DEFAULT 0,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);
CREATE INDEX IF NOT EXISTS idx_drink_orders_business_id ON drink_orders(business_id);

CREATE TABLE IF NOT EXISTS bar_invoices (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  business_id UUID NOT NULL REFERENCES businesses(id) ON DELETE CASCADE,
  invoice_number TEXT NOT NULL,
  invoice_type TEXT NOT NULL DEFAULT 'invoice',
  status TEXT NOT NULL DEFAULT 'open',
  customer_id UUID,
  customer_name TEXT,
  customer_phone TEXT,
  customer_email TEXT,
  table_label TEXT,
  notes TEXT,
  lines JSONB NOT NULL DEFAULT '[]',
  subtotal DECIMAL(12,2) NOT NULL DEFAULT 0,
  tax DECIMAL(12,2) NOT NULL DEFAULT 0,
  discount DECIMAL(12,2) NOT NULL DEFAULT 0,
  total DECIMAL(12,2) NOT NULL DEFAULT 0,
  converted_at TIMESTAMPTZ,
  linked_sale_id UUID,
  payment_method TEXT,
  worker_id UUID,
  worker_name TEXT,
  store_id UUID,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);
CREATE INDEX IF NOT EXISTS idx_bar_invoices_business_id ON bar_invoices(business_id);
