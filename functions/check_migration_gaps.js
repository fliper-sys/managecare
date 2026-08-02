// One-off, read-only: for every business in Firestore, print its id/name so
// it can be checked against Postgres's `legacy_firestore_id` column to find
// any business that never made it across during the migration.
const admin = require('firebase-admin');

const sa = require('../manage-care-1e96b-firebase-adminsdk-fbsvc-e00b7024eb.json');
admin.initializeApp({ credential: admin.credential.cert(sa) });
const db = admin.firestore();

(async () => {
  const snap = await db.collection('businesses').get();
  for (const doc of snap.docs) {
    const data = doc.data();
    console.log(`${doc.id}\t${(data.name || '').replace(/\t/g, ' ')}\t${data.ownerId || ''}`);
  }
})().catch((e) => {
  console.error('FATAL', e.message);
  process.exit(1);
});
