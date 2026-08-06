#!/usr/bin/env node
/**
 * One-off helper: find the Firestore document id for Londonspa&skincare so
 * the import targets the same `businesses/{businessId}/sales` path shape the
 * legacy app reads from.
 *
 * Usage (from functions/ so firebase-admin is resolvable):
 *   node check_business_firestore.js
 */
const admin = require('firebase-admin');
const sa = require('../manage-care-1e96b-firebase-adminsdk-fbsvc-e00b7024eb.json');

if (!admin.apps.length) {
  admin.initializeApp({ credential: admin.credential.cert(sa) });
}
const db = admin.firestore();

(async () => {
  const snap = await db.collection('businesses').get();
  console.log(`Total business docs: ${snap.size}`);
  for (const doc of snap.docs) {
    const d = doc.data() || {};
    const name = d.name || d.businessName || '(no name)';
    if (/london|spa|skincare/i.test(String(name)) || /bus_1768722675912/.test(doc.id)) {
      console.log('MATCH:', JSON.stringify({
        firestoreDocId: doc.id,
        name,
        legacyId: d.legacyFirestoreId || d.legacy_firestore_id || null,
        businessType: d.businessType || null,
        created: d.createdAt ? (d.createdAt.toDate ? d.createdAt.toDate().toISOString() : d.createdAt) : null,
      }, null, 2));
    }
  }
  console.log('--- sample of first 5 business doc ids ---');
  for (const doc of snap.docs.slice(0, 5)) {
    console.log(doc.id, '-', doc.data().name || '(no name)');
  }
})().catch((e) => {
  console.error('FATAL', e.message);
  process.exit(1);
});

