#!/usr/bin/env node

/**
 * Generate SQL to backfill private-DB inventory wholesale prices from legacy Firestore.
 *
 * Usage from repo root:
 *   cd functions
 *   node scripts/export_inventory_wholesale_backfill_sql.js --service-account ./serviceAccountKey.json --out ../inventory-wholesale-backfill.sql
 *
 * The generated SQL updates inventory rows by legacy_firestore_id, so it is
 * safe to run after the main Firestore -> Postgres import.
 */

const fs = require('fs');
const path = require('path');
const admin = require('firebase-admin');

const args = process.argv.slice(2);
const outIndex = args.indexOf('--out');
const outFile =
  outIndex >= 0 ? args[outIndex + 1] : '../inventory-wholesale-backfill.sql';
const projectIndex = args.indexOf('--project');
const projectId =
  projectIndex >= 0 ? args[projectIndex + 1] : process.env.FIREBASE_PROJECT_ID;
const serviceAccountIndex = args.indexOf('--service-account');
const serviceAccountPath =
  serviceAccountIndex >= 0
    ? args[serviceAccountIndex + 1]
    : process.env.GOOGLE_APPLICATION_CREDENTIALS;

if (!admin.apps.length) {
  const options = {};
  if (projectId) options.projectId = projectId;
  if (serviceAccountPath) {
    const resolvedPath = path.resolve(process.cwd(), serviceAccountPath);
    const serviceAccount = JSON.parse(fs.readFileSync(resolvedPath, 'utf8'));
    options.credential = admin.credential.cert(serviceAccount);
    options.projectId = projectId || serviceAccount.project_id;
  }
  admin.initializeApp(options);
}

const db = admin.firestore();

function sql(value) {
  if (value === undefined || value === null || value === '') return 'NULL';
  return `'${String(value).replace(/'/g, "''")}'`;
}

function jsonSql(value) {
  return `${sql(JSON.stringify(value))}::jsonb`;
}

function optionalNum(data, keys) {
  for (const key of keys) {
    const value = data[key];
    if (value !== undefined && value !== null && value !== '') {
      const parsed = Number(value);
      if (Number.isFinite(parsed)) return parsed;
    }
  }
  return null;
}

function inventoryMetadata(data) {
  const metadata = {};
  const wholesalePrice = optionalNum(data, ['wholesalePrice', 'wholesale_price']);

  if (wholesalePrice !== null) metadata.wholesale_price = wholesalePrice;

  return metadata;
}

async function main() {
  const lines = [
    '-- Inventory wholesale/distributor metadata backfill',
    `-- Generated at ${new Date().toISOString()}`,
    'BEGIN;',
  ];

  let scanned = 0;
  let updates = 0;
  const businesses = await db.collection('businesses').get();
  for (const businessDoc of businesses.docs) {
    const inventory = await businessDoc.ref.collection('inventory').get();
    for (const inventoryDoc of inventory.docs) {
      scanned++;
      const legacyId = `${businessDoc.id}/inventory/${inventoryDoc.id}`;
      const metadata = inventoryMetadata(inventoryDoc.data());
      if (Object.keys(metadata).length === 0) continue;
      updates++;
      lines.push(
        `UPDATE inventory SET metadata = COALESCE(metadata, '{}'::jsonb) || ${jsonSql(metadata)}, updated_at = NOW() WHERE legacy_firestore_id = ${sql(legacyId)};`
      );
    }
  }

  lines.push('COMMIT;');
  lines.push(`-- scanned_inventory=${scanned} updated_inventory=${updates}`);

  const resolvedOut = path.resolve(process.cwd(), outFile);
  fs.writeFileSync(resolvedOut, `${lines.join('\n')}\n`);
  console.log(`Wrote ${resolvedOut}`);
  console.log(`Scanned ${scanned} inventory docs; generated ${updates} updates.`);
}

main().catch((error) => {
  console.error('FATAL', error);
  process.exit(1);
});
