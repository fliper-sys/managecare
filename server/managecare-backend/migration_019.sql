-- Soft-delete + 30-day self-recovery for businesses and profiles, replacing
-- the Firestore-based DeletionRecoveryService's array-bookkeeping approach
-- (which annotated every linked user doc on delete/restore). In this
-- relational model business_members rows are left untouched by a business
-- soft-delete - membership is still real, the business is just hidden from
-- use until restored - so none of that per-user bookkeeping is needed.
ALTER TABLE businesses ADD COLUMN IF NOT EXISTS is_deleted BOOLEAN NOT NULL DEFAULT false;
ALTER TABLE businesses ADD COLUMN IF NOT EXISTS deleted_at TIMESTAMPTZ;
ALTER TABLE businesses ADD COLUMN IF NOT EXISTS deleted_by_id UUID;
ALTER TABLE businesses ADD COLUMN IF NOT EXISTS deleted_by_type TEXT;
ALTER TABLE businesses ADD COLUMN IF NOT EXISTS recovery_deadline_at TIMESTAMPTZ;
ALTER TABLE businesses ADD COLUMN IF NOT EXISTS deletion_reason TEXT;

-- profiles already has is_deleted/deleted_at/deletion_reason (see schema.sql)
ALTER TABLE profiles ADD COLUMN IF NOT EXISTS recovery_deadline_at TIMESTAMPTZ;
ALTER TABLE profiles ADD COLUMN IF NOT EXISTS deleted_by_id UUID;
