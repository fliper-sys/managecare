-- Distributor sales: a distributor buys finished bakery/retail products at
-- a per-sale discount off the shelf price. Mirrors into `sales`/`sale_items`
-- too so revenue dashboards that read from those tables stay complete,
-- matching the Firestore version's mirrored-write behavior.
ALTER TABLE distributors ADD COLUMN IF NOT EXISTS notes TEXT;

CREATE TABLE IF NOT EXISTS distributor_sales (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  business_id UUID NOT NULL REFERENCES businesses(id) ON DELETE CASCADE,
  sale_id UUID REFERENCES sales(id) ON DELETE SET NULL,
  distributor_id UUID NOT NULL REFERENCES distributors(id) ON DELETE CASCADE,
  distributor_name TEXT,
  product_id UUID,
  product_name TEXT,
  quantity NUMERIC(12,2) NOT NULL,
  unit_price NUMERIC(12,2) NOT NULL,
  discount_percent NUMERIC(5,2) NOT NULL DEFAULT 0,
  discounted_unit_price NUMERIC(12,2) NOT NULL,
  total_amount NUMERIC(12,2) NOT NULL,
  sales_rep_id UUID,
  sales_rep_name TEXT,
  notes TEXT,
  status TEXT NOT NULL DEFAULT 'completed',
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);
CREATE INDEX IF NOT EXISTS idx_distributor_sales_business_id ON distributor_sales(business_id);
CREATE INDEX IF NOT EXISTS idx_distributor_sales_distributor_id ON distributor_sales(distributor_id);
CREATE INDEX IF NOT EXISTS idx_distributor_sales_created_at ON distributor_sales(created_at DESC);
