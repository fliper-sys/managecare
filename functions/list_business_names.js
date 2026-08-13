// One-off, read-only: dump every business name + id in Firestore so a
// fuzzy/misspelled name can be matched by eye.
const admin = require('firebase-admin');

const sa = require('../manage-care-1e96b-firebase-adminsdk-fbsvc-e00b7024eb.json');
admin.initializeApp({ credential: admin.credential.cert(sa) });
const db = admin.firestore();

(async () => {
  const snap = await db.collection('businesses').get();
  const rows = snap.docs.map((d) => ({
    id: d.id,
    name: d.data().name || '(no name)',
    ownerId: d.data().ownerId || null,
    businessType: d.data().businessType || null,
  }));
  rows.sort((a, b) => a.name.toLowerCase().localeCompare(b.name.toLowerCase()));
  console.log(`Total businesses: ${rows.length}`);
  for (const r of rows) {
    console.log(`${r.name.padEnd(40)} type=${(r.businessType || '').padEnd(14)} id=${r.id} owner=${r.ownerId || 'none'}`);
  }
})().catch((e) => {
  console.error('FATAL', e.message);
  process.exit(1);
});
