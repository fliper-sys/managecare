/**
 * Migration script: populate `businessIds` and `currentBusinessId` in user documents.
 *
 * Usage:
 *  - Dry run (default): node add_business_ids_to_users.js
 *  - Apply changes: node add_business_ids_to_users.js --apply
 *  - Limit processing (for testing): node add_business_ids_to_users.js --limit=100
 *
 * Notes:
 * - Requires GOOGLE_APPLICATION_CREDENTIALS set to a service account JSON with Firestore privileges
 * - The script scans all businesses and maps owners/members to user IDs, then updates users.
 */

const admin = require('firebase-admin');
const { argv } = require('process');
const fs = require('fs');

const args = require('minimist')(argv.slice(2), {
  boolean: ['apply'],
  default: { apply: false },
});

const APPLY = !!args.apply;
const LIMIT = args.limit ? parseInt(args.limit, 10) : null;

if (!process.env.GOOGLE_APPLICATION_CREDENTIALS) {
  console.error('Please set GOOGLE_APPLICATION_CREDENTIALS to a service account JSON file.');
  process.exit(1);
}

admin.initializeApp({ credential: admin.credential.applicationDefault() });
const db = admin.firestore();

(async () => {
  console.log('Starting migration: add_business_ids_to_users');
  console.log(`Mode: ${APPLY ? 'APPLY' : 'DRY RUN'}`);

  // 1. Scan businesses and build user -> set(businessId) map
  const userToBusinesses = new Map();

  console.log('Fetching businesses...');
  const businessesSnap = await db.collection('businesses').get();
  console.log(`Found ${businessesSnap.size} businesses`);

  let bcount = 0;
  for (const bdoc of businessesSnap.docs) {
    bcount++;
    if (LIMIT && bcount > LIMIT) break;
    const bid = bdoc.id;
    const data = bdoc.data();

    // owners array (common pattern)
    const owners = Array.isArray(data.owners) ? data.owners : [];
    for (const uid of owners) {
      if (!uid) continue;
      const set = userToBusinesses.get(uid) || new Set();
      set.add(bid);
      userToBusinesses.set(uid, set);
    }

    // check for members subcollection (businesses/{bid}/members/{uid})
    try {
      const membersSnap = await db.collection('businesses').doc(bid).collection('members').get();
      for (const mdoc of membersSnap.docs) {
        const uid = mdoc.id;
        if (!uid) continue;
        const set = userToBusinesses.get(uid) || new Set();
        set.add(bid);
        userToBusinesses.set(uid, set);
      }
    } catch (e) {
      // ignore if members subcollection doesn't exist
    }

    // sometimes businesses store a single owner field
    const owner = data.owner || data.ownerId || data.userId;
    if (owner && typeof owner === 'string') {
      const set = userToBusinesses.get(owner) || new Set();
      set.add(bid);
      userToBusinesses.set(owner, set);
    }
  }

  console.log(`Mapped businesses to ${userToBusinesses.size} users (via owners/members).`);

  // 2. Iterate users and prepare updates
  console.log('Fetching users...');
  const usersSnap = await db.collection('users').get();
  console.log(`Found ${usersSnap.size} users`);

  const summary = {
    totalUsers: usersSnap.size,
    usersWithExistingBusinessIds: 0,
    usersUpdated: 0,
    usersNoBusinesses: 0,
    details: [],
  };

  let ucount = 0;
  for (const udoc of usersSnap.docs) {
    ucount++;
    if (LIMIT && ucount > LIMIT) break;

    const uid = udoc.id;
    const data = udoc.data();

    const existing = Array.isArray(data.businessIds) ? data.businessIds : [];
    if (existing && existing.length > 0) summary.usersWithExistingBusinessIds++;

    const legacySingle = data.businessId || data.business || data.defaultBusinessId || null;

    // union businesses from businesses mapping and existing fields
    const set = new Set(existing);
    if (legacySingle && typeof legacySingle === 'string') set.add(legacySingle);
    const mapped = userToBusinesses.get(uid);
    if (mapped) for (const bid of mapped) set.add(bid);

    const businessIds = Array.from(set);

    // determine currentBusinessId: prefer existing if valid, else first in businessIds
    let currentBusinessId = data.currentBusinessId || data.activeBusinessId || null;
    if (currentBusinessId && !businessIds.includes(currentBusinessId)) {
      currentBusinessId = null; // reset if not member
    }
    if (!currentBusinessId && businessIds.length > 0) currentBusinessId = businessIds[0];

    if (businessIds.length === 0) summary.usersNoBusinesses++;

    const needsUpdate = (
      !arrayEquals(existing, businessIds) ||
      (data.currentBusinessId || null) !== currentBusinessId
    );

    if (needsUpdate) {
      summary.details.push({ uid, existing, businessIds, currentBusinessId });
      if (APPLY) {
        // write update
        try {
          await db.collection('users').doc(uid).update({
            businessIds: businessIds,
            currentBusinessId: currentBusinessId,
          });
          summary.usersUpdated++;
          console.log(`Updated user ${uid}: ${businessIds.length} businesses`);
        } catch (e) {
          console.error(`Failed to update user ${uid}:`, e.message || e);
        }
      } else {
        console.log(`[DRY RUN] Would update ${uid}: businessIds=${JSON.stringify(businessIds)}, currentBusinessId=${currentBusinessId}`);
      }
    }
  }

  // write summary to file (dry-run or apply)
  const outFile = `migration_add_business_ids_${Date.now()}.json`;
  fs.writeFileSync(outFile, JSON.stringify({ summary }, null, 2));
  console.log(`Wrote summary to ${outFile}`);

  console.log('Summary:', summary);
  console.log('Done.');
  process.exit(0);
})();

function arrayEquals(a, b) {
  if (!Array.isArray(a) && !Array.isArray(b)) return true;
  if (!Array.isArray(a) || !Array.isArray(b)) return false;
  if (a.length !== b.length) return false;
  const sa = [...a].sort();
  const sb = [...b].sort();
  for (let i = 0; i < sa.length; i++) if (sa[i] !== sb[i]) return false;
  return true;
}
