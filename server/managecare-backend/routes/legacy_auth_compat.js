const express = require('express');
const {
  LegacyAuthMigration,
  makeRateLimiter,
  normalizeEmail,
} = require('../legacy_auth_migration');

module.exports = (pool, runWithUser) => {
  const router = express.Router();
  const migration = new LegacyAuthMigration({
    pool,
    runWithUser,
    supabaseUrl: process.env.SUPABASE_URL,
    serviceRoleKey: process.env.SUPABASE_SERVICE_ROLE_KEY,
  });
  const allowAttempt = makeRateLimiter();

  router.post('/legacy-migrate', async (req, res) => {
    const email = normalizeEmail(req.body?.email);
    if (!allowAttempt(`${req.ip}:${email}`)) {
      return res.status(429).json({ error: 'Too many attempts. Please try again later.' });
    }
    try {
      const result = await migration.migrate({ email, password: req.body?.password });
      return res.json({ migrated: true, user_id: result.user_id });
    } catch (error) {
      if (error.status === 503) {
        return res.status(503).json({ error: 'Account compatibility is temporarily unavailable.' });
      }
      if (error.status === 401) {
        return res.status(401).json({ error: 'Legacy credentials could not be verified.' });
      }
      console.error('[LegacyAuthMigration] Account compatibility failed:', error.message);
      return res.status(409).json({ error: 'Account needs administrator review before it can be linked.' });
    }
  });

  return router;
};
