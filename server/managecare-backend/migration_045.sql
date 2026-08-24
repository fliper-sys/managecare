-- Petroleum manager bank deposit records. These are cash movement records,
-- not operating expenses, so they live outside the expenses table.
CREATE TABLE IF NOT EXISTS petroleum_bank_deposits (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  business_id UUID NOT NULL REFERENCES businesses(id) ON DELETE CASCADE,
  depositor_name TEXT NOT NULL,
  deposit_date DATE NOT NULL DEFAULT CURRENT_DATE,
  deposit_time TIME NOT NULL DEFAULT CURRENT_TIME,
  amount DECIMAL(12,2) NOT NULL DEFAULT 0,
  bank_name TEXT NOT NULL,
  account_number TEXT,
  account_name TEXT,
  receipt_url TEXT,
  recorded_by UUID,
  recorded_by_name TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_petroleum_bank_deposits_business
  ON petroleum_bank_deposits(business_id, deposit_date DESC);
