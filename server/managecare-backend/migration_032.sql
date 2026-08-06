-- Bakery production assignments issued from ingredient stock to bakers.
CREATE TABLE IF NOT EXISTS bakery_resupplies (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  business_id UUID NOT NULL REFERENCES businesses(id) ON DELETE CASCADE,
  inventory_id UUID NOT NULL REFERENCES inventory(id) ON DELETE CASCADE,
  inventory_name TEXT,
  quantity NUMERIC(12,2) NOT NULL DEFAULT 0,
  unit TEXT,
  baker_id UUID,
  baker_name TEXT,
  notes TEXT,
  performed_by_id UUID,
  performed_by_name TEXT,
  expected_production_amount NUMERIC(12,2) NOT NULL DEFAULT 0,
  actual_production_amount NUMERIC(12,2) NOT NULL DEFAULT 0,
  production_unit TEXT,
  production_item_name TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_bakery_resupplies_business_id ON bakery_resupplies(business_id);
CREATE INDEX IF NOT EXISTS idx_bakery_resupplies_baker_id ON bakery_resupplies(baker_id);
CREATE INDEX IF NOT EXISTS idx_bakery_resupplies_created_at ON bakery_resupplies(created_at DESC);
