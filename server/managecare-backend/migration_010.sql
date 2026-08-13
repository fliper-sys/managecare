-- Support idempotent imports from the legacy Firebase/Firestore app.
-- Firestore document ids are often not UUIDs, so imported rows use generated
-- UUID ids and keep original ids in legacy_firestore_id.

ALTER TABLE profiles ADD COLUMN IF NOT EXISTS legacy_firestore_id TEXT;
ALTER TABLE businesses ADD COLUMN IF NOT EXISTS legacy_firestore_id TEXT;
ALTER TABLE inventory ADD COLUMN IF NOT EXISTS legacy_firestore_id TEXT;
ALTER TABLE sales ADD COLUMN IF NOT EXISTS legacy_firestore_id TEXT;
ALTER TABLE sale_items ADD COLUMN IF NOT EXISTS legacy_firestore_id TEXT;
ALTER TABLE customers ADD COLUMN IF NOT EXISTS legacy_firestore_id TEXT;
ALTER TABLE workers ADD COLUMN IF NOT EXISTS legacy_firestore_id TEXT;
ALTER TABLE expenses ADD COLUMN IF NOT EXISTS legacy_firestore_id TEXT;
ALTER TABLE procurements ADD COLUMN IF NOT EXISTS legacy_firestore_id TEXT;
ALTER TABLE distributors ADD COLUMN IF NOT EXISTS legacy_firestore_id TEXT;

CREATE UNIQUE INDEX IF NOT EXISTS idx_profiles_legacy_firestore_id
  ON profiles(legacy_firestore_id) WHERE legacy_firestore_id IS NOT NULL;
CREATE UNIQUE INDEX IF NOT EXISTS idx_businesses_legacy_firestore_id
  ON businesses(legacy_firestore_id) WHERE legacy_firestore_id IS NOT NULL;
CREATE UNIQUE INDEX IF NOT EXISTS idx_inventory_business_legacy_firestore_id
  ON inventory(business_id, legacy_firestore_id) WHERE legacy_firestore_id IS NOT NULL;
CREATE UNIQUE INDEX IF NOT EXISTS idx_sales_business_legacy_firestore_id
  ON sales(business_id, legacy_firestore_id) WHERE legacy_firestore_id IS NOT NULL;
CREATE UNIQUE INDEX IF NOT EXISTS idx_customers_business_legacy_firestore_id
  ON customers(business_id, legacy_firestore_id) WHERE legacy_firestore_id IS NOT NULL;
CREATE UNIQUE INDEX IF NOT EXISTS idx_workers_business_legacy_firestore_id
  ON workers(business_id, legacy_firestore_id) WHERE legacy_firestore_id IS NOT NULL;
CREATE UNIQUE INDEX IF NOT EXISTS idx_expenses_business_legacy_firestore_id
  ON expenses(business_id, legacy_firestore_id) WHERE legacy_firestore_id IS NOT NULL;
