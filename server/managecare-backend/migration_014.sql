-- InventoryRepositorySupabase.addHistoryEntry/recordBakeryResupply need
-- somewhere to persist to - this table didn't exist yet.
CREATE TABLE IF NOT EXISTS inventory_history (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  business_id UUID NOT NULL REFERENCES businesses(id) ON DELETE CASCADE,
  inventory_id UUID NOT NULL REFERENCES inventory(id) ON DELETE CASCADE,
  change_type TEXT NOT NULL DEFAULT 'adjustment',
  quantity_change NUMERIC(12,2),
  quantity_after NUMERIC(12,2),
  notes TEXT,
  performed_by_id UUID,
  performed_by_name TEXT,
  metadata JSONB NOT NULL DEFAULT '{}',
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_inventory_history_inventory_id ON inventory_history(inventory_id);
CREATE INDEX IF NOT EXISTS idx_inventory_history_business_id ON inventory_history(business_id);
