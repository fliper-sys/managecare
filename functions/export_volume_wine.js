// One-off, read-only export: find the "Volume Wine" business in Firestore,
// dump the business doc, its inventory subcollection, and its owner's
// Firebase Auth account, so it can be inspected/manually reconciled against
// Postgres without touching either database.
const admin = require('firebase-admin');
const fs = require('fs');
const path = require('path');

const sa = require('../manage-care-1e96b-firebase-adminsdk-fbsvc-e00b7024eb.json');
admin.initializeApp({ credential: admin.credential.cert(sa) });
const db = admin.firestore();

const OUT_PATH = process.argv[2] || path.join(__dirname, 'volume_wine_export.json');
const TARGET_IDS = ['bus_1779823912466', 'bus_1785475772188'];

(async () => {
  const matches = [];
  for (const id of TARGET_IDS) {
    const doc = await db.collection('businesses').doc(id).get();
    if (doc.exists) matches.push(doc);
  }

  if (matches.length === 0) {
    console.log(`No business found for ids: ${TARGET_IDS.join(', ')}`);
    process.exit(0);
  }

  const results = [];
  for (const bizDoc of matches) {
    const business = { firestoreId: bizDoc.id, ...bizDoc.data() };

    const invSnap = await db.collection(`businesses/${bizDoc.id}/inventory`).get();
    const inventory = invSnap.docs.map((d) => ({ firestoreId: d.id, ...d.data() }));

    let owner = null;
    const ownerId = business.ownerId;
    if (ownerId) {
      try {
        const userRecord = await admin.auth().getUser(ownerId);
        owner = {
          uid: userRecord.uid,
          email: userRecord.email || null,
          phoneNumber: userRecord.phoneNumber || null,
          displayName: userRecord.displayName || null,
          disabled: userRecord.disabled,
          creationTime: userRecord.metadata.creationTime,
          lastSignInTime: userRecord.metadata.lastSignInTime,
        };
      } catch (e) {
        owner = { uid: ownerId, error: `Auth lookup failed: ${e.message}` };
      }
    }

    results.push({ business, owner, inventoryCount: inventory.length, inventory });
  }

  const out = { exportedAt: new Date().toISOString(), matches: results };
  fs.writeFileSync(OUT_PATH, JSON.stringify(out, null, 2));

  console.log(`Found ${results.length} matching business(es):`);
  for (const r of results) {
    console.log(`  - "${r.business.name}" (${r.business.firestoreId})`);
    console.log(`    owner: ${r.owner ? (r.owner.email || r.owner.uid) : 'none/ownerId missing'}`);
    console.log(`    inventory items: ${r.inventoryCount}`);
  }
  console.log(`-> ${OUT_PATH}`);
})().catch((e) => {
  console.error('FATAL', e.message);
  process.exit(1);
});
