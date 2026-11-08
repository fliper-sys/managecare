ALTER TABLE hotel_reservations
  ADD COLUMN IF NOT EXISTS amount_paid DECIMAL(12,2) NOT NULL DEFAULT 0,
  ADD COLUMN IF NOT EXISTS payment_breakdown JSONB NOT NULL DEFAULT '{}'::jsonb;

UPDATE hotel_reservations
SET amount_paid = COALESCE(total_price, 0),
    payment_breakdown = CASE LOWER(COALESCE(payment_method, ''))
      WHEN 'cash' THEN jsonb_build_object(
        'cash', COALESCE(total_price, 0), 'card', 0, 'transfer', 0
      )
      WHEN 'card' THEN jsonb_build_object(
        'cash', 0, 'card', COALESCE(total_price, 0), 'transfer', 0
      )
      WHEN 'transfer' THEN jsonb_build_object(
        'cash', 0, 'card', 0, 'transfer', COALESCE(total_price, 0)
      )
      ELSE payment_breakdown
    END
WHERE payment_status = 'paid'
  AND amount_paid = 0;

ALTER TABLE bar_invoices
  ADD COLUMN IF NOT EXISTS payment_breakdown JSONB NOT NULL DEFAULT '{}'::jsonb,
  ADD COLUMN IF NOT EXISTS confirmed_by_id UUID,
  ADD COLUMN IF NOT EXISTS confirmed_by_name TEXT,
  ADD COLUMN IF NOT EXISTS confirmed_at TIMESTAMPTZ,
  ADD COLUMN IF NOT EXISTS collected_by_id UUID,
  ADD COLUMN IF NOT EXISTS collected_by_name TEXT,
  ADD COLUMN IF NOT EXISTS collected_at TIMESTAMPTZ;
