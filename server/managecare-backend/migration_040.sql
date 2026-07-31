-- refresh_tokens.user_id had a hard FK to profiles(id) only, but sessions
-- are now issued for three identity tables (profiles, workers,
-- managecare_workers) via the same /auth/v1/token flow. A workers-table or
-- managecare_workers-table login could never get a refresh token and would
-- 400 on login with a foreign key violation. There's no single table a
-- polymorphic user_id can reference, so the constraint is dropped rather
-- than repointed - the token itself is an opaque, unguessable secret
-- (crypto.randomBytes(32)), so this isn't a meaningful security loosening.
ALTER TABLE refresh_tokens DROP CONSTRAINT IF EXISTS refresh_tokens_user_id_fkey;
