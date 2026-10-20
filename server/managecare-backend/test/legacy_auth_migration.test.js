const test = require('node:test');
const assert = require('node:assert/strict');
const bcrypt = require('bcrypt');
const { LegacyAuthMigration, makeRateLimiter } = require('../legacy_auth_migration');

test('legacy migration rejects a wrong password before calling Supabase Admin', async () => {
  const hash = await bcrypt.hash('correct-passphrase', 4);
  const pool = {
    query: async (sql) => sql.includes('auth_worker_login_candidates')
      ? { rows: [] }
      : { rows: [{ id: 'legacy-id', email: 'owner@example.com', password_hash: hash }] },
  };
  let providerCalls = 0;
  const migration = new LegacyAuthMigration({
    pool,
    runWithUser: (_id, callback) => callback(),
    supabaseUrl: 'https://supabase.example',
    serviceRoleKey: 'server-only-test-key',
    fetchImpl: async () => { providerCalls += 1; throw new Error('unexpected provider call'); },
  });

  await assert.rejects(
    migration.migrate({ email: 'OWNER@example.com', password: 'wrong-passphrase' }),
    (error) => error.status === 401,
  );
  assert.equal(providerCalls, 0);
});

test('legacy migration refuses ambiguous matching owner/worker credentials', async () => {
  const hash = await bcrypt.hash('same-passphrase', 4);
  const pool = {
    query: async (sql) => sql.includes('auth_worker_login_candidates')
      ? { rows: [{ id: 'worker-id', email: 'owner@example.com', password_hash: hash }] }
      : { rows: [{ id: 'owner-id', email: 'owner@example.com', password_hash: hash }] },
  };
  const migration = new LegacyAuthMigration({
    pool,
    runWithUser: (_id, callback) => callback(),
    supabaseUrl: 'https://supabase.example',
    serviceRoleKey: 'server-only-test-key',
    fetchImpl: async () => { throw new Error('unexpected provider call'); },
  });

  await assert.rejects(
    migration.migrate({ email: 'owner@example.com', password: 'same-passphrase' }),
    (error) => error.status === 401,
  );
});

test('membership linking is performed once by the database identity-link function', async () => {
  const calls = [];
  const migration = new LegacyAuthMigration({
    pool: { query: async (sql, values) => {
      calls.push({ sql, values });
      return { rows: [{ result: { owner_memberships_added: 1 } }] };
    } },
    runWithUser: (id, callback) => {
      assert.equal(id, 'legacy-id');
      return callback();
    },
    supabaseUrl: 'https://supabase.example',
    serviceRoleKey: 'server-only-test-key',
    fetchImpl: async () => { throw new Error('membership linking must not call Supabase REST'); },
  });

  const result = await migration.syncVerifiedMemberships('auth-id', 'legacy-id', 'owner@example.com');
  assert.deepEqual(result, { owner_memberships_added: 1 });
  assert.equal(calls.length, 1);
  assert.match(calls[0].sql, /link_legacy_auth_identity/);
  assert.deepEqual(calls[0].values, ['auth-id', 'legacy-id', 'owner@example.com']);
});

test('legacy migration limiter enforces the configured attempt window', () => {
  let now = 1_000;
  const allowed = makeRateLimiter({ windowMs: 1_000, maxAttempts: 2, now: () => now });
  assert.equal(allowed('ip:email'), true);
  assert.equal(allowed('ip:email'), true);
  assert.equal(allowed('ip:email'), false);
  now += 1_001;
  assert.equal(allowed('ip:email'), true);
});
