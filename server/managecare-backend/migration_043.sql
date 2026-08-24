-- Preserve per-method split for mixed-payment retail/POS sales.
ALTER TABLE sales
  ADD COLUMN IF NOT EXISTS payment_breakdown JSONB NOT NULL DEFAULT '[]';

