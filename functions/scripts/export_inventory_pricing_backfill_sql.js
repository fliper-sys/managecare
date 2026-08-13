#!/usr/bin/env node

/**
 * Generate SQL to backfill zero-valued price/cost/wholesale_price columns
 * in the private-DB `inventory` table from legacy Firestore, across every
 * business. Only touches rows that are CURRENTLY zero (or missing, for
 * wholesale_price) in Postgres - the WHERE guard is evaluated by Postgres
 * at apply time, so this never clobbers a price/cost a user has since
 * edited in the app, even if that edit happened after this file was
 * generated.
 *
 * Usage from repo root:
 *   cd functions
 *   node scripts/export_inventory_pricing_backfill_sql.js --service-account ./serviceAccountKey.json --out ../inventory-pricing-backfill.sql
 */

const fs = require('fs');
const path = require('path');
const admin = require('firebase-admin');

const args = process.argv.slice(2);
const outIndex = args.indexOf('--out');
const outFile = outIndex >= 0 ? args[outIndex + 1] : '../inventory-pricing-backfill.sql';
const serviceAccountIndex = args.indexOf('--service-account');
const serviceAccountPath = serviceAccountIndex >= 0 ? args[serviceAccountIndex + 1] : process.env.GOOGLE_APPLICATION_CREDENTIALS;

if (!admin.apps.length) {
  const options = {};
  if (serviceAccountPath) {
    const resolvedPath = path.resolve(process.cwd(), serviceAccountPath);
    const serviceAccount = JSON.parse(fs.readFileSync(resolvedPath, 'utf8'));
    options.credential = admin.credential.cert(serviceAccount);
    options.projectId = serviceAccount.project_id;
  }
  admin.initializeApp(options);
}

const db = admin.firestore();

function sqlStr(value) {
  if (value === undefined || value === null || value === '') return 'NULL';
  return `'${String(value).replace(/'/g, "''")}'`;
}

function firstPositiveNumber(data, keys) {
  for (const key of keys) {
    const value = data[key];
    if (value === undefined || value === null || value === '') continue;
    const parsed = Number(value);
    if (Number.isFinite(parsed) && parsed > 0) return parsed;
  }
  return null;
}

async function main() {
  const lines = [
    '-- Inventory price/cost/wholesale_price backfill (zero-value only)',
    `-- Generated at ${new Date().toISOString()}`,
    '-- Only updates rows where the Postgres value is currently 0/missing;',
    '-- never overwrites a price a user has already edited in the app.',
    'BEGIN;',
  ];

  let scanned = 0;
  const perBusiness = {};
  const totals = { price: 0, cost: 0, wholesale: 0 };

  const businesses = await db.collection('businesses').get();
  for (const businessDoc of businesses.docs) {
    const bname = businessDoc.data().name || businessDoc.data().businessName || businessDoc.id;
    const inventory = await businessDoc.ref.collection('inventory').get();
    for (const inventoryDoc of inventory.docs) {
      scanned++;
      const data = inventoryDoc.data();
      const bareId = inventoryDoc.id;
      const fullId = `${businessDoc.id}/inventory/${inventoryDoc.id}`;
      const idClause = `(legacy_firestore_id = ${sqlStr(fullId)} OR legacy_firestore_id = ${sqlStr(bareId)})`;

      const price = firstPositiveNumber(data, ['price', 'sellingPrice', 'unitPrice']);
      const cost = firstPositiveNumber(data, ['cost', 'costPrice']);
      const wholesale = firstPositiveNumber(data, ['wholesalePrice', 'wholesale_price']);

      let touched = false;
      if (price !== null) {
        lines.push(
          `UPDATE inventory SET unit_price = ${price}, updated_at = NOW() WHERE ${idClause} AND unit_price = 0;`
        );
        totals.price++;
        touched = true;
      }
      if (cost !== null) {
        lines.push(
          `UPDATE inventory SET cost_price = ${cost}, updated_at = NOW() WHERE ${idClause} AND cost_price = 0;`
        );
        totals.cost++;
        touched = true;
      }
      if (wholesale !== null) {
        lines.push(
          `UPDATE inventory SET metadata = COALESCE(metadata, '{}'::jsonb) || '{"wholesale_price":${wholesale}}'::jsonb, updated_at = NOW() WHERE ${idClause} AND (metadata->>'wholesale_price' IS NULL OR (metadata->>'wholesale_price')::numeric = 0);`
        );
        totals.wholesale++;
        touched = true;
      }

      if (touched) {
        perBusiness[bname] = perBusiness[bname] || { price: 0, cost: 0, wholesale: 0 };
        if (price !== null) perBusiness[bname].price++;
        if (cost !== null) perBusiness[bname].cost++;
        if (wholesale !== null) perBusiness[bname].wholesale++;
      }
    }
  }

  lines.push('COMMIT;');
  lines.push(
    `-- scanned=${scanned} price_updates=${totals.price} cost_updates=${totals.cost} wholesale_updates=${totals.wholesale}`
  );

  const resolvedOut = path.resolve(process.cwd(), outFile);
  fs.writeFileSync(resolvedOut, `${lines.join('\n')}\n`);

  console.log(`Wrote ${resolvedOut}`);
  console.log(`Scanned ${scanned} inventory docs.`);
  console.log(
    `Candidate updates: price=${totals.price} cost=${totals.cost} wholesale=${totals.wholesale} (actual count applied may be lower - guarded by "AND column = 0" at apply time)`
  );
  console.log('\nPer-business breakdown (businesses with at least one candidate update):');
  const sorted = Object.entries(perBusiness).sort((a, b) => (b[1].price + b[1].cost + b[1].wholesale) - (a[1].price + a[1].cost + a[1].wholesale));
  for (const [name, counts] of sorted) {
    console.log(`  ${name}: price=${counts.price} cost=${counts.cost} wholesale=${counts.wholesale}`);
  }
}

main().catch((error) => {
  console.error('FATAL', error);
  process.exit(1);
});
