BEGIN;

-- Opaque, one-time links that can target either a legacy owner profile or a
-- worker row. Only the SHA-256 token digest is stored; the raw token is mailed.
CREATE TABLE IF NOT EXISTS account_password_reset_tokens (
  token_hash TEXT PRIMARY KEY,
  account_type TEXT NOT NULL CHECK (account_type IN ('owner', 'worker')),
  legacy_user_id UUID NOT NULL,
  expires_at TIMESTAMPTZ NOT NULL,
  used_at TIMESTAMPTZ,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_account_password_reset_target
  ON account_password_reset_tokens(account_type, legacy_user_id, expires_at);

GRANT SELECT, INSERT, UPDATE, DELETE ON account_password_reset_tokens TO managecare;

COMMIT;
