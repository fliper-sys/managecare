-- Track whether operating expenses were paid from cash or by transfer.
ALTER TABLE expenses
  ADD COLUMN IF NOT EXISTS payment_method TEXT NOT NULL DEFAULT 'cash';

CREATE INDEX IF NOT EXISTS idx_expenses_business_payment_method
  ON expenses(business_id, payment_method, created_at DESC);
