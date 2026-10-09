-- Administrative client lifecycle support.
ALTER TABLE administrative_clients
  ADD COLUMN IF NOT EXISTS is_active BOOLEAN NOT NULL DEFAULT true,
  ADD COLUMN IF NOT EXISTS archived_at TIMESTAMPTZ;

CREATE INDEX IF NOT EXISTS administrative_clients_active_idx
  ON administrative_clients (business_id, is_active, created_at DESC);
