Firestore PHP Migration Script

Purpose
-------
This script helps migrate user documents by populating `businessIds` (array) and `currentBusinessId` based on data found in `businesses` documents (owners arrays, owner field, and members/workers subcollections).

How it works
------------
- Uses a Google service account JSON to obtain an OAuth2 access token (JWT flow).
- Lists all documents in the `businesses` collection.
- For each business, gathers referenced user identifiers from fields and subcollections.
- Builds a mapping userId -> [businessIds].
- For each user, merges businessIds with the user's existing `businessIds` array and sets `currentBusinessId` when missing.
- In dry-run mode, writes a JSON report describing planned changes.
- In apply mode, updates user documents via Firestore REST API.

Security & Safety
-----------------
- Always run with `--dry-run` first and review the generated report.
- Protect your service account JSON; place it in a directory inaccessible from the public web.
- Consider deleting or moving the service account file after the migration completes.
- If you must run this on a public web server, use CLI execution only (do not expose the script via HTTP endpoints) or protect it behind strong authentication.

Requirements
------------
- PHP 7.2+ with OpenSSL and cURL extensions enabled.
- A Google service account JSON file with the necessary permissions to read and write Firestore data.

Usage
-----
Place your service account JSON (e.g., `sa.json`) in the directory and run:

Dry-run (recommended first):

  php migrate.php --sa=sa.json --dry-run --out=report.json

Apply changes (only after validating the report):

  php migrate.php --sa=sa.json --apply --out=report.json

Optional: create missing user docs when applying:

  php migrate.php --sa=sa.json --apply --create-missing --out=report.json

Output
------
The script writes a JSON report (default `migration_report.json`) containing:
- project, timestamp, businessCount
- changes: an array of per-user planned or executed actions
- summary: counts of planned/updated/noops/missing/errors

Notes & Caveats
----------------
- The script assumes business documents are in `businesses` and user documents are in `users`.
- It looks for member records in subcollections named `members` and `workers`.
- If your schema differs (different field names, collection names), the script will need small edits.
- Do not run `--apply` until you have carefully reviewed the dry-run report.

Support
-------
If you want, I can adapt the script to match your exact document schema (field names or collection names) if you paste a sample `business` and `user` document here.
