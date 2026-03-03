Migration: Add `businessIds` to user documents

This migration populates `businessIds` (array) and `currentBusinessId` in your `users` collection.

How it works
- Scans `businesses` collection and builds a map of userId -> businessIds by inspecting:
  - `businesses/{bid}.owners` (array)
  - `businesses/{bid}/members` subcollection (document ids)
  - legacy owner fields (e.g., `owner`, `ownerId`)
- Scans `users` collection and unions existing `businessIds`, `businessId` legacy field, and mapped businesses.
- Sets `currentBusinessId` to existing valid value or first business id found.

Usage
1. Ensure GOOGLE_APPLICATION_CREDENTIALS points to a service account JSON with Firestore permissions:
   - Windows (PowerShell): $env:GOOGLE_APPLICATION_CREDENTIALS = "C:\path\to\serviceAccount.json"
   - macOS/Linux: export GOOGLE_APPLICATION_CREDENTIALS="/path/to/serviceAccount.json"

2. Dry run (default):
   node add_business_ids_to_users.js

3. Apply changes (writes to Firestore):
   node add_business_ids_to_users.js --apply

4. Limit processed docs for testing:
   node add_business_ids_to_users.js --limit=100

Notes
- The script is conservative: it only writes `businessIds` and `currentBusinessId` to `users`.
- Review generated JSON summary file before applying (`migration_add_business_ids_TIMESTAMP.json`).
- Consider running the script in a staging environment or with a small limit before full run.
