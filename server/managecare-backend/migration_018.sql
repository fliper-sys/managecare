-- Audit trail for sale deletions, previously a Firestore `sale_deletions`
-- subcollection written inside the same transaction as the delete itself.
CREATE TABLE IF NOT EXISTS sale_deletions (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  business_id UUID NOT NULL REFERENCES businesses(id) ON DELETE CASCADE,
  sale_id UUID NOT NULL,
  deleted_by UUID,
  reason TEXT,
  sale_snapshot JSONB NOT NULL DEFAULT '{}',
  items_snapshot JSONB NOT NULL DEFAULT '[]',
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_sale_deletions_business_id ON sale_deletions(business_id);
