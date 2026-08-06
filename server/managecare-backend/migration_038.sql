-- Lets managecare_workers rows authenticate through the existing
-- /auth/v1/token (password grant) flow, the same way `profiles` and
-- `workers` already do. No password_hash column exists on this table today.
ALTER TABLE managecare_workers ADD COLUMN IF NOT EXISTS password_hash TEXT;
