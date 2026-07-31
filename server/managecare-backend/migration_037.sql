-- Generic per-business settings bag (WhatsApp Cloud API credentials, receipt
-- settings, etc.) - the Dart BusinessModel has had a `settings` field since
-- the Firestore era, but it was never wired to a Postgres column, so writes
-- silently vanished and reads always came back empty.
ALTER TABLE businesses ADD COLUMN IF NOT EXISTS settings JSONB DEFAULT '{}'::jsonb;
