-- Preserve counted note denominations for petroleum pump cash uploads.
ALTER TABLE pump_daily_uploads
  ADD COLUMN IF NOT EXISTS cash_breakdown JSONB NOT NULL DEFAULT '[]';
