-- Procurement system. `procurements` already exists (schema.sql) as a bare
-- header row (supplier_name, total_amount, status, notes) with no line
-- items at all - extend it with the fields the app's ProcurementRepository
-- actually needs (an items JSONB snapshot for display/CSV export, plus the
-- denormalized display fields the old Firestore docs carried directly).
-- Batch-level detail (one row per line item, used for weighted-average cost
-- tracking and the "procurements for this product" drill-down) gets its own
-- table - in Firestore this was two redundant collections
-- (inventory/{id}/batches and inventory/{id}/procurements) since Firestore
-- can't join; one relational table replaces both.
ALTER TABLE procurements
  ADD COLUMN IF NOT EXISTS items JSONB NOT NULL DEFAULT '[]',
  ADD COLUMN IF NOT EXISTS total_quantity DECIMAL(14,3) NOT NULL DEFAULT 0,
  ADD COLUMN IF NOT EXISTS items_count INTEGER NOT NULL DEFAULT 0,
  ADD COLUMN IF NOT EXISTS invoice_ref TEXT,
  ADD COLUMN IF NOT EXISTS reference_image_url TEXT,
  ADD COLUMN IF NOT EXISTS store_id UUID,
  ADD COLUMN IF NOT EXISTS store_name TEXT,
  ADD COLUMN IF NOT EXISTS source_type TEXT,
  ADD COLUMN IF NOT EXISTS created_by_name TEXT,
  ADD COLUMN IF NOT EXISTS created_by_email TEXT,
  ADD COLUMN IF NOT EXISTS baker_id TEXT,
  ADD COLUMN IF NOT EXISTS baker_name TEXT,
  ADD COLUMN IF NOT EXISTS sales_rep_id TEXT,
  ADD COLUMN IF NOT EXISTS sales_rep_name TEXT;

CREATE INDEX IF NOT EXISTS idx_procurements_business_id ON procurements(business_id);
CREATE INDEX IF NOT EXISTS idx_procurements_source_type ON procurements(source_type);

CREATE TABLE IF NOT EXISTS inventory_batches (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  business_id UUID NOT NULL REFERENCES businesses(id) ON DELETE CASCADE,
  inventory_id UUID NOT NULL,
  procurement_id UUID NOT NULL REFERENCES procurements(id) ON DELETE CASCADE,
  batch_label TEXT,
  quantity DECIMAL(14,3) NOT NULL DEFAULT 0,
  remaining_quantity DECIMAL(14,3) NOT NULL DEFAULT 0,
  unit TEXT,
  cost DECIMAL(12,2) NOT NULL DEFAULT 0,
  total DECIMAL(12,2) NOT NULL DEFAULT 0,
  purchase_quantity DECIMAL(14,3),
  purchase_unit TEXT,
  purchase_unit_cost DECIMAL(12,2),
  expiry_date TIMESTAMPTZ,
  supplier_name TEXT,
  invoice_ref TEXT,
  reference_image_url TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);
CREATE INDEX IF NOT EXISTS idx_inventory_batches_business_id ON inventory_batches(business_id);
CREATE INDEX IF NOT EXISTS idx_inventory_batches_inventory_id ON inventory_batches(inventory_id);
CREATE INDEX IF NOT EXISTS idx_inventory_batches_procurement_id ON inventory_batches(procurement_id);
