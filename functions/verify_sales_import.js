#!/usr/bin/env node
/**
 * Verify the sales import for Londonspa&skincare in Firestore.
 *
 * Usage:
 *   node verify_sales_import.js
 */
const admin = require('firebase-admin');
const sa = require('../manage-care-1e96b-firebase-adminsdk-fbsvc-e00b7024eb.json');

if (!admin.apps.length) {
  admin.initializeApp({ credential: admin.credential.cert(sa) });
}
const db = admin.firestore();
const BIZ = 'bus_1768722675912';

(async () => {
  // Root sales collection filtered by businessId
const rootSnap = await db
    .collection('sales')
    .where('businessId', '==', BIZ)
    .get();
  console.log('ROOT sales count (businessId filter):', rootSnap.size);

  // Nested business sales collection
  const nestedSnap = await db
    .collection('businesses')
    .doc(BIZ)
    .collection('sales')
    .get();
  console.log('NESTED businesses/{biz}/sales count:', nestedSnap.size);

  // Daily summaries
  const summariesSnap = await db
    .collection('businesses')
    .doc(BIZ)
    .collection('salesSummaries')
    .get();
  console.log('salesSummaries docs:');
  for (const doc of summariesSnap.docs) {
    console.log('  ', doc.id, JSON.stringify(doc.data()));
  }

  // Sample one sale doc to confirm shape + timestamps
  if (nestedSnap.docs.length > 0) {
    const sample = nestedSnap.docs[0].data();
    console.log('\nSAMPLE nested sale:');
    console.log('  id:', nestedSnap.docs[0].id);
    console.log('  businessId:', sample.businessId);
    console.log('  finalAmount:', sample.finalAmount);
    console.log('  paymentMethod:', sample.paymentMethod);
    console.log('  createdAt type:', sample.createdAt ? sample.createdAt.constructor.name : null);
    console.log('  createdAt:', sample.createdAt ? sample.createdAt.toDate().toISOString() : null);
    console.log('  items count:', Array.isArray(sample.items) ? sample.items.length : 0);
    console.log('  first item:', JSON.stringify(sample.items ? sample.items[0] : null));
  }

  // Check date range filter reads (the legacy app queries by createdAt range)
  const start = new Date('2026-08-02T00:00:00.000Z');
  const end = new Date('2026-08-03T23:59:59.999Z');
  const rangeSnap = await db
    .collection('businesses')
    .doc(BIZ)
    .collection('sales')
    .where('createdAt', '>=', start)
    .where('createdAt', '<=', end)
    .get();
  console.log('\nDate-range query count (Aug 2-3):', rangeSnap.size);
})().catch((e) => {
  console.error('FATAL', e.message);
  process.exit(1);
});

