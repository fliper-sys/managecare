BEGIN;

ALTER TABLE public.administrative_financial_entries
  ADD COLUMN IF NOT EXISTS payment_method TEXT
  CHECK (payment_method IS NULL OR payment_method IN ('cash', 'transfer', 'mixed'));

COMMIT;
