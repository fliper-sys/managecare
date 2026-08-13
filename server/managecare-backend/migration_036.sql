-- Two more dedup columns for the batch-2 Firestore import, missed in migration_035.
ALTER TABLE distributor_sales ADD COLUMN IF NOT EXISTS legacy_firestore_id TEXT;
ALTER TABLE bakery_resupplies ADD COLUMN IF NOT EXISTS legacy_firestore_id TEXT;

CREATE INDEX IF NOT EXISTS idx_distributor_sales_legacy_fs ON distributor_sales(legacy_firestore_id);
CREATE INDEX IF NOT EXISTS idx_bakery_resupplies_legacy_fs ON bakery_resupplies(legacy_firestore_id);
