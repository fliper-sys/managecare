Backfill inventory migration

This folder contains a simple Node.js script to backfill existing Firestore inventory documents.

Requirements:
- Node.js 14+
- A Firebase service account JSON with Firestore access

Steps:
1. Install dependencies:

```bash
npm install firebase-admin
```

2. Set environment variables:

```bash
# Path to service account JSON
export GOOGLE_APPLICATION_CREDENTIALS="/path/to/serviceAccountKey.json"
# Target business id to update
export BUSINESS_ID="yourBusinessDocId"
```

3. Run the script:

```bash
node backfill_inventory.js
```

What it does:
- If an inventory doc lacks `price` but has `sellingPrice`, it sets `price = sellingPrice`.
- If `warehouseAllocations` is missing, it sets it to an empty object.

Caution: Test on a small dataset before running on production.
