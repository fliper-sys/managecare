require('dotenv').config();

const fs = require('fs');
const path = require('path');
const { Pool } = require('pg');

const pool = new Pool({
  host: process.env.DB_HOST || 'localhost',
  port: parseInt(process.env.DB_PORT, 10) || 5432,
  user: process.env.DB_USER || 'postgres',
  password: process.env.DB_PASSWORD,
  database: process.env.DB_NAME || 'managecare',
});

const migrationDir = process.argv[2] || '/tmp/admin_migrations';

async function tableExists(tableName) {
  const result = await pool.query('SELECT to_regclass($1) AS table_name', [
    `public.${tableName}`,
  ]);
  return Boolean(result.rows[0].table_name);
}

async function columnExists(tableName, columnName) {
  const result = await pool.query(
    `SELECT 1
       FROM information_schema.columns
      WHERE table_schema = 'public'
        AND table_name = $1
        AND column_name = $2`,
    [tableName, columnName],
  );
  return result.rowCount > 0;
}

const migrations = [
  {
    file: 'migration_042_administrative.sql',
    missing: async () => !(await tableExists('administrative_clients')),
  },
  {
    file: 'migration_050_administrative_extensions.sql',
    missing: async () =>
      !(await columnExists('administrative_clients', 'archived_at')),
  },
  {
    file: 'migration_051_administrative_finance.sql',
    missing: async () => !(await tableExists('administrative_invoices')),
  },
  {
    file: 'migration_052_administrative_workflow_security.sql',
    missing: async () =>
      !(await tableExists('administrative_document_versions')) ||
      !(await tableExists('administrative_task_comments')),
  },
  {
    file: 'migration_053_administrative_operations.sql',
    missing: async () => !(await tableExists('administrative_calendar_events')),
  },
  {
    file: 'migration_054_administrative_document_tasks.sql',
    missing: async () => !(await columnExists('administrative_tasks', 'priority')),
  },
  {
    file: 'migration_055_administrative_usage.sql',
    missing: async () => !(await tableExists('administrative_usage')),
  },
  {
    file: 'migration_056_administrative_task_submissions.sql',
    missing: async () =>
      !(await columnExists('administrative_tasks', 'submitted_version_id')),
  },
];

(async () => {
  const applied = [];
  const skipped = [];

  for (const migration of migrations) {
    if (!(await migration.missing())) {
      skipped.push(migration.file);
      continue;
    }

    const sql = fs.readFileSync(path.join(migrationDir, migration.file), 'utf8');
    await pool.query(sql);
    applied.push(migration.file);
  }

  console.log(JSON.stringify({ applied, skipped }, null, 2));
})()
  .catch((err) => {
    console.error(err);
    process.exitCode = 1;
  })
  .finally(() => pool.end());
