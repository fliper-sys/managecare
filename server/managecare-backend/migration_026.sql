-- Fuel pump configuration + daily meter-reading reconciliation uploads,
-- including the dispute-review workflow. Field names deliberately mirror
-- the Firestore document shape (including the historically-swapped
-- opening_photo_url/closing_photo_url naming) so the Dart-side rewrite is
-- a mechanical field-by-field port, not a redesign.
CREATE TABLE IF NOT EXISTS pumps (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  business_id UUID NOT NULL REFERENCES businesses(id) ON DELETE CASCADE,
  pump_number TEXT NOT NULL,
  product_id UUID,
  product_name TEXT,
  product_unit TEXT,
  product_price DECIMAL(12,2) NOT NULL DEFAULT 0,
  model TEXT,
  serial_number TEXT,
  manufacturer TEXT,
  manufacture_year TEXT,
  is_active BOOLEAN NOT NULL DEFAULT true,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);
CREATE INDEX IF NOT EXISTS idx_pumps_business_id ON pumps(business_id);

CREATE TABLE IF NOT EXISTS pump_daily_uploads (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  business_id UUID NOT NULL REFERENCES businesses(id) ON DELETE CASCADE,
  pump_id UUID REFERENCES pumps(id) ON DELETE SET NULL,
  pump_number TEXT,
  product_id UUID,
  product_name TEXT,
  product_unit TEXT,
  product_price DECIMAL(12,2) NOT NULL DEFAULT 0,
  worker_id UUID,
  worker_name TEXT,
  upload_fingerprint TEXT,
  sale_id UUID,

  opening_volume DECIMAL(14,3) NOT NULL DEFAULT 0,
  closing_volume DECIMAL(14,3) NOT NULL DEFAULT 0,
  digital_volume DECIMAL(14,3) NOT NULL DEFAULT 0,
  volume_difference DECIMAL(14,3) NOT NULL DEFAULT 0,
  analog_opening_volume DECIMAL(14,3) NOT NULL DEFAULT 0,
  analog_closing_volume DECIMAL(14,3) NOT NULL DEFAULT 0,
  sold_volume DECIMAL(14,3) NOT NULL DEFAULT 0,
  cash_derived_volume DECIMAL(14,3) NOT NULL DEFAULT 0,
  previous_analog_closing_volume DECIMAL(14,3),
  previous_shift_closing_cash DECIMAL(12,2),
  previous_closing_volume DECIMAL(14,3),
  expected_amount DECIMAL(12,2) NOT NULL DEFAULT 0,
  shift_opening_cash DECIMAL(12,2) NOT NULL DEFAULT 0,
  shift_close_cash DECIMAL(12,2) NOT NULL DEFAULT 0,
  shift_cash_difference DECIMAL(12,2) NOT NULL DEFAULT 0,
  today_pump_cash DECIMAL(12,2) NOT NULL DEFAULT 0,
  cash_amount DECIMAL(12,2) NOT NULL DEFAULT 0,
  cash_breakdown JSONB NOT NULL DEFAULT '[]',
  pos_amount DECIMAL(12,2) NOT NULL DEFAULT 0,
  total_paid DECIMAL(12,2) NOT NULL DEFAULT 0,

  discrepancy_notes JSONB NOT NULL DEFAULT '[]',
  discrepancy_summary TEXT,

  shift_opening_cash_photo_url TEXT,
  shift_close_cash_photo_url TEXT,
  opening_photo_url TEXT,
  closing_photo_url TEXT,

  is_disputed BOOLEAN NOT NULL DEFAULT false,
  disputed_at TIMESTAMPTZ,
  disputed_by UUID,
  disputed_by_name TEXT,
  dispute_reason TEXT,
  dispute_resolved_at TIMESTAMPTZ,
  dispute_resolved_by UUID,
  dispute_resolved_by_name TEXT,

  category TEXT NOT NULL DEFAULT 'pump_daily_upload',
  uploaded_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);
CREATE INDEX IF NOT EXISTS idx_pump_daily_uploads_business_id ON pump_daily_uploads(business_id);
CREATE INDEX IF NOT EXISTS idx_pump_daily_uploads_pump_id ON pump_daily_uploads(pump_id);
CREATE INDEX IF NOT EXISTS idx_pump_daily_uploads_is_disputed ON pump_daily_uploads(is_disputed);
-- Server-side duplicate-submission guard (the Firestore version only
-- checked client-side, which is race-prone under concurrent submits).
CREATE UNIQUE INDEX IF NOT EXISTS idx_pump_daily_uploads_fingerprint
  ON pump_daily_uploads(business_id, pump_id, upload_fingerprint)
  WHERE upload_fingerprint IS NOT NULL;

CREATE TABLE IF NOT EXISTS pump_upload_adjustments (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  business_id UUID NOT NULL REFERENCES businesses(id) ON DELETE CASCADE,
  upload_id UUID NOT NULL REFERENCES pump_daily_uploads(id) ON DELETE CASCADE,
  pump_id UUID,
  pump_number TEXT,
  product_name TEXT,
  uploaded_at TIMESTAMPTZ,
  action TEXT NOT NULL,
  changes JSONB NOT NULL DEFAULT '[]',
  note TEXT,
  adjusted_by UUID,
  adjusted_by_name TEXT,
  adjusted_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);
CREATE INDEX IF NOT EXISTS idx_pump_upload_adjustments_business_id ON pump_upload_adjustments(business_id);
CREATE INDEX IF NOT EXISTS idx_pump_upload_adjustments_upload_id ON pump_upload_adjustments(upload_id);
