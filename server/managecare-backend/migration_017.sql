-- Inventory alerts previously lived as synced Firestore docs (one per
-- low-stock product, kept in sync by a client-side "check thresholds" pass).
-- Postgres can compute the same thing on read directly from `inventory`
-- (quantity vs min_stock_level), so there's no need to persist alert state
-- itself - only the one thing that doesn't derive from current data:
-- whether a given severity level has already been acknowledged.
CREATE TABLE IF NOT EXISTS inventory_alert_acks (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  business_id UUID NOT NULL REFERENCES businesses(id) ON DELETE CASCADE,
  product_id UUID NOT NULL REFERENCES inventory(id) ON DELETE CASCADE,
  severity TEXT NOT NULL,
  acknowledged_by UUID,
  acknowledged_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_inventory_alert_acks_product ON inventory_alert_acks(business_id, product_id);

-- Reorders are real actionable state (pending/ordered/received), unlike the
-- alerts themselves, so this does get its own table.
CREATE TABLE IF NOT EXISTS reorders (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  business_id UUID NOT NULL REFERENCES businesses(id) ON DELETE CASCADE,
  product_id UUID NOT NULL,
  product_name TEXT NOT NULL,
  quantity INTEGER NOT NULL DEFAULT 0,
  status TEXT NOT NULL DEFAULT 'pending',
  source TEXT NOT NULL DEFAULT 'alert',
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_reorders_business_id ON reorders(business_id);
