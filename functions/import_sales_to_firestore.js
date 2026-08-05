#!/usr/bin/env node
/**
 * Import a sales JSON export (from extract_sales_export.js) into Firestore.
 *
 * Mirrors the legacy SalesRepositoryImpl write shape:
 *   - Root:  sales/{saleId}
 *   - Nested: businesses/{businessId}/sales/{saleId}
 *   - Daily summary: businesses/{businessId}/salesSummaries/{YYYY-MM-DD}
 *
 * Usage (from functions/):
 *   node import_sales_to_firestore.js \
 *     --in londonspa_sales_last_2_days.json \
 *     --sa ../manage-care-1e96b-firebase-adminsdk-fbsvc-e00b7024eb.json \
 *     --fb-business-id bus_1768722675912
 *
 * --fb-business-id is REQUIRED for printing into Firestore: the legacy app
 * stores businesses under the Firestore document id (e.g. bus_1768722675912)
 * and filters sales by where('businessId', isEqualTo: <that id>). The export
 * carries the Postgres UUID (aa2f33c7-...) as businessId, so it must be
 * mapped to the Firestore business document id here — otherwise the legacy
 * app's queries would never see these sales.
 *
 * Idempotent: uses set(merge) so re-running won't duplicate or clobber
 * unrelated fields.
 */
const admin = require('firebase-admin');
const fs = require('fs');

const args = process.argv.slice(2);
const arg = (name, fallback) => {
  const i = args.indexOf(name);
  return i >= 0 && args[i + 1] !== undefined ? args[i + 1] : fallback;
};

const IN = arg('--in', 'londonspa_sales_last_2_days.json');
const SA = arg(
  '--sa',
  '../manage-care-1e96b-firebase-adminsdk-fbsvc-e00b7024eb.json'
);
// Legacy Firestore business document id (validation below).
const FB_BIZ = arg('--fb-business-id', '');
const DRY = args.includes('--dry-run');

function dayKey(iso) {
  const d = new Date(iso);
  if (Number.isNaN(d.getTime())) return null;
  return `${d.getFullYear()}-${String(d.getMonth() + 1).padStart(2, '0')}-${String(
    d.getDate()
  ).padStart(2, '0')}`;
}

async function main() {
  if (!fs.existsSync(IN)) {
    console.error(`Export file not found: ${IN}`);
    process.exit(1);
  }
const exportData = JSON.parse(fs.readFileSync(IN, 'utf8'));
  const sales = exportData.sales || [];
  const pgBusinessId = exportData.businessId || sales[0]?.businessId;

  if (!pgBusinessId) {
    console.error('No businessId found in export.');
    process.exit(1);
  }
  if (!FB_BIZ) {
    console.error('--fb-business-id is required (the Firestore business document id).');
    process.exit(1);
  }
  if (!sales.length) {
    console.warn('Export has 0 sales. Nothing to import.');
    if (!DRY) return;
  }

  // The legacy app keys businesses by their Firestore document id and filters
  // sales by where('businessId', isEqualTo: <that id>). Map the Postgres UUID
  // to the Firestore business id for the write path + businessId field.
  const businessId = FB_BIZ;

  if (!admin.apps.length) {
    if (!fs.existsSync(SA)) {
      console.error(`Service account key not found: ${SA}`);
      process.exit(1);
    }
    admin.initializeApp({
      credential: admin.credential.cert(SA),
    });
  }
  const db = admin.firestore();

  let imported = 0;
  const summaries = new Map(); // dayKey -> { totalSales, totalTransactions }

  const batchSize = 450;
  let batch = db.batch();
  let pending = 0;

  const flush = async () => {
    await batch.commit();
    batch = db.batch();
    pending = 0;
  };

  for (const sale of sales) {
    const saleId = sale.id;
    if (!saleId) {
      console.warn('Skipping sale without id:', sale);
      continue;
    }

    // createdAt/updatedAt as ISO strings -> Firestore Timestamps
    const doc = { ...sale };
    for (const k of ['createdAt', 'updatedAt']) {
      if (typeof doc[k] === 'string' && doc[k]) {
        const d = new Date(doc[k]);
        if (!Number.isNaN(d.getTime())) doc[k] = admin.firestore.Timestamp.fromDate(d);
      }
    }

    const rootRef = db.collection('sales').doc(saleId);
    const nestedRef = db
      .collection('businesses')
      .doc(businessId)
      .collection('sales')
      .doc(saleId);

    const rootWrite = { ...doc, id: saleId, businessId };
    batch.set(rootRef, rootWrite, { merge: true });
    batch.set(nestedRef, rootWrite, { merge: true });
    pending += 2;

    const dk = dayKey(doc.createdAt?.toDate?.() || sale.createdAt);
    if (dk) {
      const summary = summaries.get(dk) || { totalSales: 0, totalTransactions: 0 };
      summary.totalSales += sale.finalAmount || 0;
      summary.totalTransactions += 1;
      summaries.set(dk, summary);
    }

    imported += 1;
    if (pending >= batchSize) await flush();
  }

  // Daily summaries (increment-style merge so existing totals are preserved).
  for (const [dk, summary] of summaries.entries()) {
    const ref = db
      .collection('businesses')
      .doc(businessId)
      .collection('salesSummaries')
      .doc(dk);
    batch.set(
      ref,
      {
        date: dk,
        totalSales: admin.firestore.FieldValue.increment(summary.totalSales),
        totalTransactions:
          admin.firestore.FieldValue.increment(summary.totalTransactions),
        lastUpdated: admin.firestore.FieldValue.serverTimestamp(),
      },
      { merge: true }
    );
    pending += 1;
    if (pending >= batchSize) await flush();
  }

  if (pending > 0) await flush();

  console.log(`\nImport complete. sales=${imported} summaries=${summaries.size}`);
  for (const [dk, s] of summaries.entries()) {
    console.log(`  ${dk}: ${s.totalTransactions} tx, ${s.totalSales.toFixed(2)} total`);
  }
}

main().catch((err) => {
  console.error('FATAL', err);
  process.exit(1);
});

