-- Matches the soft-delete/recovery columns businesses already has, so
-- profiles can go through the same 30-day admin-recoverable delete flow.
ALTER TABLE profiles ADD COLUMN IF NOT EXISTS deleted_by_id UUID REFERENCES profiles(id);
ALTER TABLE profiles ADD COLUMN IF NOT EXISTS deleted_by_type TEXT;
ALTER TABLE profiles ADD COLUMN IF NOT EXISTS recovery_deadline_at TIMESTAMPTZ;
