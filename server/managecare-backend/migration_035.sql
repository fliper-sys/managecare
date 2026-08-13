-- Adds legacy_firestore_id matching/dedup columns to tables targeted by the
-- Firestore historical-data import (batch 2), matching the pattern already
-- used on businesses/profiles/customers/workers/procurements/distributors.
ALTER TABLE stores ADD COLUMN IF NOT EXISTS legacy_firestore_id TEXT;
ALTER TABLE pumps ADD COLUMN IF NOT EXISTS legacy_firestore_id TEXT;
ALTER TABLE pump_daily_uploads ADD COLUMN IF NOT EXISTS legacy_firestore_id TEXT;
ALTER TABLE pump_upload_adjustments ADD COLUMN IF NOT EXISTS legacy_firestore_id TEXT;
ALTER TABLE invoices ADD COLUMN IF NOT EXISTS legacy_firestore_id TEXT;
ALTER TABLE inventory_history ADD COLUMN IF NOT EXISTS legacy_firestore_id TEXT;

CREATE INDEX IF NOT EXISTS idx_stores_legacy_fs ON stores(legacy_firestore_id);
CREATE INDEX IF NOT EXISTS idx_pumps_legacy_fs ON pumps(legacy_firestore_id);
CREATE INDEX IF NOT EXISTS idx_pump_daily_uploads_legacy_fs ON pump_daily_uploads(legacy_firestore_id);
CREATE INDEX IF NOT EXISTS idx_pump_upload_adjustments_legacy_fs ON pump_upload_adjustments(legacy_firestore_id);
CREATE INDEX IF NOT EXISTS idx_invoices_legacy_fs ON invoices(legacy_firestore_id);
CREATE INDEX IF NOT EXISTS idx_inventory_history_legacy_fs ON inventory_history(legacy_firestore_id);
