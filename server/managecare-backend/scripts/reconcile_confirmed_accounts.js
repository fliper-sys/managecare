const path = require('path');
const dotenv = require('dotenv');
const { Pool } = require('pg');
const { bindPoolToRequestUser, runWithUser } = require('../middleware/db_request_context');
const { LegacyAuthMigration } = require('../legacy_auth_migration');

dotenv.config({ path: path.join(__dirname, '..', '.env') });
dotenv.config({ path: path.join(__dirname, '..', '.env.production') });

async function main() {
  const pool = bindPoolToRequestUser(new Pool({
    host: process.env.DB_HOST || 'localhost',
    port: Number.parseInt(process.env.DB_PORT, 10) || 5432,
    user: process.env.DB_USER || 'postgres',
    password: process.env.DB_PASSWORD,
    database: process.env.DB_NAME || 'managecare',
    max: 2,
    connectionTimeoutMillis: 5000,
  }));
  try {
    const migration = new LegacyAuthMigration({
      pool,
      runWithUser,
      supabaseUrl: process.env.SUPABASE_URL,
      serviceRoleKey: process.env.SUPABASE_SERVICE_ROLE_KEY,
    });
    const summary = await migration.reconcileConfirmedAccounts();
    process.stdout.write(`${JSON.stringify(summary)}\n`);
  } finally {
    await pool.end();
  }
}

main().catch((error) => {
  process.stderr.write(`Account reconciliation failed: ${error.message}\n`);
  process.exitCode = 1;
});
