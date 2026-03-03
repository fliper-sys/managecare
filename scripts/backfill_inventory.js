/*
Simple Firebase admin script to backfill inventory documents:
- if `price` missing but `sellingPrice` present, set `price = sellingPrice`
- if `warehouseAllocations` missing, set it to {}

Usage:
1. Install dependencies: npm install firebase-admin
2. Set env: export GOOGLE_APPLICATION_CREDENTIALS="/path/to/serviceAccountKey.json"
   and set BUSINESS_ID env var to the business doc id to operate on.
3. Run: node backfill_inventory.js

Caution: run on a test dataset first.
*/

const admin = require('firebase-admin');
const BUSINESS_ID = process.env.BUSINESS_ID;

if (!process.env.GOOGLE_APPLICATION_CREDENTIALS) {
  console.error('Please set GOOGLE_APPLICATION_CREDENTIALS to your service account json');
  process.exit(1);
}
if (!BUSINESS_ID) {
  console.error('Please set BUSINESS_ID env var to the target business id');
  process.exit(1);
}

admin.initializeApp();
const db = admin.firestore();

async function backfill() {
  const invRef = db.collection('businesses').doc(BUSINESS_ID).collection('inventory');
  const snapshot = await invRef.get();
  console.log(`Found ${snapshot.size} inventory docs`);
  let updated = 0;
  for (const doc of snapshot.docs) {
    const data = doc.data();
    const updates = {};
    if ((data.price === undefined || data.price === null) && data.sellingPrice !== undefined) {
      updates.price = data.sellingPrice;
    }
    if (data.warehouseAllocations === undefined) {
      updates.warehouseAllocations = {};
    }
    if (Object.keys(updates).length > 0) {
      await invRef.doc(doc.id).update(updates);
      console.log(`Updated ${doc.id}:`, updates);
      updated++;
    }
  }
  console.log(`Done. Updated ${updated} documents.`);
}

backfill().catch(err => {
  console.error('Error during backfill', err);
  process.exit(1);
});
