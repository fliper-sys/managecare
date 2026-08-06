-- Returns/refunds: previously lived as a Firestore `returns` subcollection
-- plus per-item `returnedQuantities` dot-path counters on the sale doc.
-- Ports both: a real audit-trail table, and running counters on `sales` so
-- a second partial return on the same sale knows exactly how much of each
-- item is still returnable.
ALTER TABLE sales ADD COLUMN IF NOT EXISTS return_amount DECIMAL(12,2) NOT NULL DEFAULT 0;
ALTER TABLE sales ADD COLUMN IF NOT EXISTS returned_quantities JSONB NOT NULL DEFAULT '{}';
ALTER TABLE sales ADD COLUMN IF NOT EXISTS has_return BOOLEAN NOT NULL DEFAULT false;

CREATE TABLE IF NOT EXISTS returns (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  business_id UUID NOT NULL REFERENCES businesses(id) ON DELETE CASCADE,
  sale_id UUID NOT NULL REFERENCES sales(id) ON DELETE CASCADE,
  reason TEXT,
  refund_method TEXT,
  refund_amount DECIMAL(12,2) NOT NULL DEFAULT 0,
  exclude_from_totals BOOLEAN NOT NULL DEFAULT false,
  items_returned JSONB NOT NULL DEFAULT '[]',
  processed_by_id UUID,
  processed_by_name TEXT,
  entered_by_id UUID,
  entered_by_name TEXT,
  entered_by_email TEXT,
  entered_by_role TEXT,
  sale_reference TEXT,
  sold_by_id UUID,
  sold_by_name TEXT,
  customer_id UUID,
  customer_name TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_returns_business_id ON returns(business_id);
CREATE INDEX IF NOT EXISTS idx_returns_sale_id ON returns(sale_id);
