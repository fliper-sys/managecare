// One-time export: pulls the per-business nested subcollections identified
// as real gaps (stores, procurements, pumps + uploads + adjustments,
// distributors + sales, bakery resupplies, invoices, fuel stock history)
// out of Firestore for import into Postgres. Read-only against Firestore.
const admin = require('firebase-admin');
const fs = require('fs');
const path = require('path');

const sa = require('../manage-care-1e96b-firebase-adminsdk-fbsvc-e00b7024eb.json');
admin.initializeApp({ credential: admin.credential.cert(sa) });
const db = admin.firestore();

const OUT_PATH = process.argv[2] || path.join(__dirname, 'firestore_export_batch2.json');

const TARGETS = [
  'stores', 'procurements', 'pump_configurations', 'pump_daily_uploads',
  'pump_upload_adjustments', 'fuel_stock_procurement_history',
  'distributors', 'distributor_sales', 'bakery_resupplies', 'invoices',
];

(async () => {
  const bizSnap = await db.collection('businesses').get();
  const out = {};
  TARGETS.forEach((t) => { out[t] = []; });

  for (const bizDoc of bizSnap.docs) {
    for (const t of TARGETS) {
      const snap = await bizDoc.ref.collection(t).get();
      snap.docs.forEach((doc) => {
        out[t].push({ firestoreId: doc.id, businessFirestoreId: bizDoc.id, ...doc.data() });
      });
    }
  }

  const result = { exportedAt: new Date().toISOString(), collections: out };
  fs.writeFileSync(OUT_PATH, JSON.stringify(result));
  console.log('Exported:');
  TARGETS.forEach((t) => console.log(' ', t.padEnd(30), out[t].length));
  console.log('->', OUT_PATH);
})().catch((e) => {
  console.error('FATAL', e.message);
  process.exit(1);
});
