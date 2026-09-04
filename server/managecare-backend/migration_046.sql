-- Petroleum pump upload manager review workflow and cash ledger.
ALTER TABLE pump_daily_uploads
  ADD COLUMN IF NOT EXISTS status TEXT NOT NULL DEFAULT 'pending_review',
  ADD COLUMN IF NOT EXISTS submitted_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  ADD COLUMN IF NOT EXISTS submitted_by UUID,
  ADD COLUMN IF NOT EXISTS submitted_by_name TEXT,
  ADD COLUMN IF NOT EXISTS reviewed_at TIMESTAMPTZ,
  ADD COLUMN IF NOT EXISTS reviewed_by UUID,
  ADD COLUMN IF NOT EXISTS reviewed_by_name TEXT,
  ADD COLUMN IF NOT EXISTS review_note TEXT,
  ADD COLUMN IF NOT EXISTS decline_reason TEXT,
  ADD COLUMN IF NOT EXISTS approved_sale_id UUID,
  ADD COLUMN IF NOT EXISTS approved_stock_deduction_applied BOOLEAN NOT NULL DEFAULT false,
  ADD COLUMN IF NOT EXISTS resubmitted_from_upload_id UUID;

UPDATE pump_daily_uploads
SET status = 'approved',
    approved_sale_id = COALESCE(approved_sale_id, sale_id),
    approved_stock_deduction_applied = true,
    submitted_at = COALESCE(submitted_at, uploaded_at)
WHERE status = 'pending_review'
  AND sale_id IS NOT NULL;

CREATE INDEX IF NOT EXISTS idx_pump_daily_uploads_status
  ON pump_daily_uploads(business_id, status, uploaded_at DESC);

CREATE INDEX IF NOT EXISTS idx_pump_daily_uploads_worker_status
  ON pump_daily_uploads(business_id, worker_id, status, uploaded_at DESC);

CREATE TABLE IF NOT EXISTS petroleum_cash_entries (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  business_id UUID NOT NULL REFERENCES businesses(id) ON DELETE CASCADE,
  source_type TEXT NOT NULL,
  upload_id UUID REFERENCES pump_daily_uploads(id) ON DELETE SET NULL,
  sale_id UUID REFERENCES sales(id) ON DELETE SET NULL,
  worker_id UUID,
  worker_name TEXT,
  pump_id UUID,
  pump_number TEXT,
  product_name TEXT,
  cash_amount DECIMAL(12,2) NOT NULL DEFAULT 0,
  pos_amount DECIMAL(12,2) NOT NULL DEFAULT 0,
  total_amount DECIMAL(12,2) NOT NULL DEFAULT 0,
  cash_breakdown JSONB NOT NULL DEFAULT '[]',
  entry_date DATE NOT NULL DEFAULT CURRENT_DATE,
  entry_time TIME NOT NULL DEFAULT CURRENT_TIME,
  note TEXT,
  created_by UUID,
  created_by_name TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_petroleum_cash_entries_business
  ON petroleum_cash_entries(business_id, entry_date DESC, created_at DESC);

CREATE INDEX IF NOT EXISTS idx_petroleum_cash_entries_source
  ON petroleum_cash_entries(business_id, source_type, entry_date DESC);

ALTER TABLE petroleum_bank_deposits
  ADD COLUMN IF NOT EXISTS deposited_cash_entry DECIMAL(12,2) NOT NULL DEFAULT 0,
  ADD COLUMN IF NOT EXISTS balance_cash_at_hand DECIMAL(12,2) NOT NULL DEFAULT 0,
  ADD COLUMN IF NOT EXISTS submitted_at TIMESTAMPTZ NOT NULL DEFAULT NOW();

CREATE TABLE IF NOT EXISTS petroleum_admin_cash_submissions (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  business_id UUID NOT NULL REFERENCES businesses(id) ON DELETE CASCADE,
  submitted_by UUID,
  submitted_by_name TEXT,
  receiver_name TEXT NOT NULL,
  amount DECIMAL(12,2) NOT NULL DEFAULT 0,
  balance_cash_at_hand DECIMAL(12,2) NOT NULL DEFAULT 0,
  submission_date DATE NOT NULL DEFAULT CURRENT_DATE,
  submission_time TIME NOT NULL DEFAULT CURRENT_TIME,
  note TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_petroleum_admin_cash_submissions_business
  ON petroleum_admin_cash_submissions(business_id, submission_date DESC, created_at DESC);
