const path = require('path');
const dotenv = require('dotenv');
const { Pool } = require('pg');

dotenv.config({ path: path.join(__dirname, '..', '.env') });
dotenv.config({ path: path.join(__dirname, '..', '.env.production') });

const candidateSql = `
  SELECT p.id, p.email, p.password_hash, p.full_name, p.phone_number,
         p.created_at, p.updated_at, b.id AS business_id, b.owner_id
  FROM profiles p
  JOIN businesses b ON b.id = p.current_business_id
  JOIN profiles owner_profile ON owner_profile.id = b.owner_id
  WHERE COALESCE(p.is_active, true) = true
    AND COALESCE(p.is_deleted, false) = false
    AND b.is_active = true
    AND COALESCE(b.is_deleted, false) = false
    AND COALESCE(owner_profile.is_active, true) = true
    AND COALESCE(owner_profile.is_deleted, false) = false
    AND b.owner_id <> p.id
  ORDER BY p.id`;

async function main() {
  const pool = new Pool({
    host: process.env.DB_HOST || 'localhost',
    port: Number.parseInt(process.env.DB_PORT, 10) || 5432,
    user: process.env.DB_USER || 'postgres',
    password: process.env.DB_PASSWORD,
    database: process.env.DB_NAME || 'managecare',
    max: 2,
    connectionTimeoutMillis: 5000,
  });

  try {
    const current = await pool.query(
      `SELECT (SELECT COUNT(*)::int FROM workers) AS workers,
              (SELECT COUNT(*)::int FROM business_members) AS memberships`);
    const candidates = await pool.query(candidateSql);
    const summary = {
      existingWorkerRows: current.rows[0].workers,
      existingMembershipRows: current.rows[0].memberships,
      candidateProfiles: candidates.rowCount,
      emailsPresent: candidates.rows.filter((row) => row.email?.trim()).length,
      passwordHashesPresent: candidates.rows.filter((row) => row.password_hash).length,
      mode: process.argv.includes('--apply') ? 'apply' : 'dry-run',
    };

    if (!process.argv.includes('--apply')) {
      process.stdout.write(`${JSON.stringify(summary)}\n`);
      return;
    }

    const client = await pool.connect();
    try {
      await client.query('BEGIN');
      await client.query("SELECT pg_advisory_xact_lock(hashtext('managecare-worker-profile-backfill-v1'))");
      const fresh = await client.query(candidateSql);
      if (fresh.rowCount !== candidates.rowCount) {
        throw new Error('Eligible profile set changed during backfill; no rows were changed');
      }
      let insertedWorkerRows = 0;
      let insertedMembershipRows = 0;
      let skippedExistingMemberships = 0;
      let skippedOtherBusinessWorkers = 0;
      let skippedInactiveOrOwnerMemberships = 0;
      for (const row of fresh.rows) {
        await client.query(
          `SELECT set_config('request.jwt.claim.sub', $1, true),
                  set_config('request.jwt.claims', $2, true)`,
          [row.id, JSON.stringify({ sub: row.id, role: 'authenticated' })],
        );
        const existingWorker = await client.query('SELECT business_id FROM auth_worker_session()');
        if (existingWorker.rowCount && existingWorker.rows[0].business_id !== row.business_id) {
          skippedOtherBusinessWorkers += 1;
          continue;
        }

        await client.query(
          `SELECT set_config('request.jwt.claim.sub', $1, true),
                  set_config('request.jwt.claims', $2, true)`,
          [row.owner_id, JSON.stringify({ sub: row.owner_id, role: 'authenticated' })],
        );
        const existingMembership = await client.query(
          `SELECT is_active, is_owner FROM business_members
           WHERE user_id = $1 AND business_id = $2`,
          [row.id, row.business_id],
        );
        if (existingMembership.rowCount) {
          if (existingMembership.rows[0].is_owner || !existingMembership.rows[0].is_active) {
            skippedInactiveOrOwnerMemberships += 1;
          } else {
            skippedExistingMemberships += 1;
          }
          continue;
        }

        const membership = await client.query(
          `INSERT INTO business_members
             (user_id, business_id, role, is_owner, is_active, permissions)
           VALUES ($1, $2, 'staff', false, true, '{}'::jsonb)
           ON CONFLICT (user_id, business_id) DO NOTHING
           RETURNING user_id`,
          [row.id, row.business_id],
        );
        if (membership.rowCount !== 1) {
          throw new Error('Could not safely create a worker membership; rolling back');
        }
        insertedMembershipRows += 1;

        if (existingWorker.rowCount) continue;

        await client.query(
          `SELECT set_config('request.jwt.claim.sub', $1, true),
                  set_config('request.jwt.claims', $2, true)`,
          [row.id, JSON.stringify({ sub: row.id, role: 'authenticated' })],
        );
        const worker = await client.query(
          `INSERT INTO workers
             (id, email, password_hash, full_name, phone, role, business_id,
              is_active, permissions, created_at, updated_at)
           VALUES ($1, NULLIF(trim($2), ''), $3,
                   COALESCE(NULLIF(trim($4), ''), NULLIF(trim($2), ''), 'Worker'),
                   $5, 'staff', $6, true, '{}'::jsonb,
                   COALESCE($7, NOW()), NOW())
           ON CONFLICT (id) DO NOTHING
           RETURNING id`,
          [row.id, row.email, row.password_hash, row.full_name, row.phone_number, row.business_id, row.created_at],
        );
        if (worker.rowCount !== 1) {
          await client.query(
            `SELECT set_config('request.jwt.claim.sub', $1, true),
                    set_config('request.jwt.claims', $2, true)`,
            [row.owner_id, JSON.stringify({ sub: row.owner_id, role: 'authenticated' })],
          );
          await client.query(
            'DELETE FROM business_members WHERE user_id = $1 AND business_id = $2',
            [row.id, row.business_id],
          );
          insertedMembershipRows -= 1;
          skippedOtherBusinessWorkers += 1;
          continue;
        }
        insertedWorkerRows += 1;
      }
      await client.query('COMMIT');
      summary.insertedWorkerRows = insertedWorkerRows;
      summary.insertedMembershipRows = insertedMembershipRows;
      summary.skippedExistingMemberships = skippedExistingMemberships;
      summary.skippedInactiveOrOwnerMemberships = skippedInactiveOrOwnerMemberships;
      summary.skippedOtherBusinessWorkers = skippedOtherBusinessWorkers;
    } catch (error) {
      await client.query('ROLLBACK').catch(() => {});
      throw error;
    } finally {
      client.release();
    }

    process.stdout.write(`${JSON.stringify(summary)}\n`);
  } finally {
    await pool.end();
  }
}

main().catch((error) => {
  process.stderr.write(`Worker profile rebuild failed: ${error.message}\n`);
  process.exitCode = 1;
});
