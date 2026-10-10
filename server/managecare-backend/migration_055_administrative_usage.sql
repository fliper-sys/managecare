CREATE TABLE IF NOT EXISTS administrative_usage (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  business_id UUID NOT NULL UNIQUE REFERENCES businesses(id) ON DELETE CASCADE,
  storage_bytes BIGINT NOT NULL DEFAULT 0 CHECK (storage_bytes >= 0),
  staff_count INTEGER NOT NULL DEFAULT 0 CHECK (staff_count >= 0),
  client_count INTEGER NOT NULL DEFAULT 0 CHECK (client_count >= 0),
  branch_count INTEGER NOT NULL DEFAULT 0 CHECK (branch_count >= 0),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);