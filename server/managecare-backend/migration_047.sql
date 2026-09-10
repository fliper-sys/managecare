-- Admin corrections for petroleum cash tracking totals.
CREATE TABLE IF NOT EXISTS petroleum_cash_total_corrections (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  business_id UUID NOT NULL REFERENCES businesses(id) ON DELETE CASCADE,
  cash_income DECIMAL(12,2),
  pos_income DECIMAL(12,2),
  total_bank_deposits DECIMAL(12,2),
  total_admin_submissions DECIMAL(12,2),
  balance_cash_at_hand DECIMAL(12,2),
  note TEXT,
  corrected_by UUID,
  corrected_by_name TEXT,
  corrected_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE UNIQUE INDEX IF NOT EXISTS idx_petroleum_cash_total_corrections_business
  ON petroleum_cash_total_corrections(business_id);