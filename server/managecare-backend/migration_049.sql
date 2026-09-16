-- Preserve the cash-expense baseline for cash-at-hand corrections.
ALTER TABLE petroleum_cash_total_corrections
  ADD COLUMN IF NOT EXISTS base_cash_expenses DECIMAL(12,2) NOT NULL DEFAULT 0;

-- Existing corrections predate this baseline; prevent historical expenses from
-- being counted as new activity after deployment.
UPDATE petroleum_cash_total_corrections c
SET base_cash_expenses = COALESCE(
  (SELECT SUM(amount)
   FROM expenses
   WHERE business_id = c.business_id
     AND COALESCE(payment_method, 'cash') = 'cash'),
  0
)
WHERE c.corrected_at < NOW();-- Track whether operating expenses were paid from cash or by transfer.
ALTER TABLE expenses
  ADD COLUMN IF NOT EXISTS payment_method TEXT NOT NULL DEFAULT 'cash';

CREATE INDEX IF NOT EXISTS idx_expenses_business_payment_method
  ON expenses(business_id, payment_method, created_at DESC);
