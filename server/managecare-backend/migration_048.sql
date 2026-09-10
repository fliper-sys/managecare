-- Preserve cumulative petroleum cash corrections and their audit history.
ALTER TABLE petroleum_cash_total_corrections
  ADD COLUMN IF NOT EXISTS base_cash_income DECIMAL(12,2) NOT NULL DEFAULT 0,
  ADD COLUMN IF NOT EXISTS base_pos_income DECIMAL(12,2) NOT NULL DEFAULT 0,
  ADD COLUMN IF NOT EXISTS base_total_bank_deposits DECIMAL(12,2) NOT NULL DEFAULT 0,
  ADD COLUMN IF NOT EXISTS base_total_admin_submissions DECIMAL(12,2) NOT NULL DEFAULT 0;

CREATE TABLE IF NOT EXISTS petroleum_cash_total_correction_log (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  business_id UUID NOT NULL REFERENCES businesses(id) ON DELETE CASCADE,
  cash_income_before DECIMAL(12,2) NOT NULL,
  cash_income_after DECIMAL(12,2) NOT NULL,
  pos_income_before DECIMAL(12,2) NOT NULL,
  pos_income_after DECIMAL(12,2) NOT NULL,
  total_bank_deposits_before DECIMAL(12,2) NOT NULL,
  total_bank_deposits_after DECIMAL(12,2) NOT NULL,
  total_admin_submissions_before DECIMAL(12,2) NOT NULL,
  total_admin_submissions_after DECIMAL(12,2) NOT NULL,
  balance_cash_at_hand_before DECIMAL(12,2) NOT NULL,
  balance_cash_at_hand_after DECIMAL(12,2) NOT NULL,
  note TEXT,
  corrected_by UUID,
  corrected_by_name TEXT,
  corrected_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_petroleum_cash_total_correction_log_business
  ON petroleum_cash_total_correction_log(business_id, corrected_at DESC);

-- Existing correction rows were created before raw baselines existed. Use the
-- current aggregate as their baseline so the first post-migration increment
-- is not counted twice.
UPDATE petroleum_cash_total_corrections c
SET base_cash_income = COALESCE((SELECT SUM(cash_amount) FROM petroleum_cash_entries WHERE business_id = c.business_id), 0),
    base_pos_income = COALESCE((SELECT SUM(pos_amount) FROM petroleum_cash_entries WHERE business_id = c.business_id), 0),
    base_total_bank_deposits = COALESCE((SELECT SUM(amount) FROM petroleum_bank_deposits WHERE business_id = c.business_id), 0),
    base_total_admin_submissions = COALESCE((SELECT SUM(amount) FROM petroleum_admin_cash_submissions WHERE business_id = c.business_id), 0)
WHERE c.corrected_at < NOW();
