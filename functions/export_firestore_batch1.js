// One-time export: pulls `workers` and `payment_transactions` out of Firestore
// for import into Postgres. Read-only against Firestore. Writes a single JSON
// file that the VPS-side import script consumes.
const admin = require('firebase-admin');
const fs = require('fs');
const path = require('path');

const sa = require('../manage-care-1e96b-firebase-adminsdk-fbsvc-e00b7024eb.json');
admin.initializeApp({ credential: admin.credential.cert(sa) });
const db = admin.firestore();

const OUT_PATH = process.argv[2] || path.join(__dirname, 'firestore_export_batch1.json');

async function exportCollection(name) {
  const snap = await db.collection(name).get();
  return snap.docs.map((doc) => ({ firestoreId: doc.id, ...doc.data() }));
}

(async () => {
  const workers = await exportCollection('workers');
  const paymentTransactions = await exportCollection('payment_transactions');

  const out = {
    exportedAt: new Date().toISOString(),
    workers,
    paymentTransactions,
  };
  fs.writeFileSync(OUT_PATH, JSON.stringify(out));
  console.log(`Exported ${workers.length} workers, ${paymentTransactions.length} payment_transactions -> ${OUT_PATH}`);
})().catch((e) => {
  console.error('FATAL', e.message);
  process.exit(1);
});
