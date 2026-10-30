ALTER TABLE bakery_resupplies
  ADD COLUMN IF NOT EXISTS status TEXT NOT NULL DEFAULT 'approved',
  ADD COLUMN IF NOT EXISTS approved_by_id UUID,
  ADD COLUMN IF NOT EXISTS approved_by_name TEXT,
  ADD COLUMN IF NOT EXISTS approved_at TIMESTAMPTZ,
  ADD COLUMN IF NOT EXISTS decision_notes TEXT,
  ADD COLUMN IF NOT EXISTS updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW();

CREATE INDEX IF NOT EXISTS idx_bakery_resupplies_business_status
  ON bakery_resupplies(business_id, status, created_at DESC);

CREATE TABLE IF NOT EXISTS bakery_spoilage_records (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  business_id UUID NOT NULL REFERENCES businesses(id) ON DELETE CASCADE,
  inventory_id UUID NOT NULL REFERENCES inventory(id) ON DELETE CASCADE,
  inventory_name TEXT NOT NULL,
  quantity NUMERIC(12,2) NOT NULL CHECK (quantity > 0),
  unit TEXT,
  reason TEXT NOT NULL,
  notes TEXT,
  reported_by_id UUID,
  reported_by_name TEXT,
  status TEXT NOT NULL DEFAULT 'pending',
  decided_by_id UUID,
  decided_by_name TEXT,
  decided_at TIMESTAMPTZ,
  decision_notes TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_bakery_spoilage_business_status
  ON bakery_spoilage_records(business_id, status, created_at DESC);
