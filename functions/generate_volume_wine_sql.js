// Generates a one-off SQL script that recovers "Volume B Wine, Cocktails &
// Grills" (Firestore bus_1785475772188) into Postgres, since it never made
// it across during the Firebase -> Postgres migration. Reads the export
// already pulled by export_volume_wine.js; writes SQL only, does not touch
// either database itself.
const fs = require('fs');
const path = require('path');

const data = require('./volume_wine_export.json');
const wine = data.matches.find((m) => m.business.firestoreId === 'bus_1785475772188');
if (!wine) throw new Error('Volume B Wine record not found in export');

const OWNER_ID = '0068e472-0d52-5ee3-a001-d6d42e4fc5a7'; // profiles.id for volumeb838@gmail.com
const DUPLICATE_BUSINESS_IDS = [
  'b7ba032e-706f-4bad-8e44-818843faeebd',
  '9d0d7856-641e-4708-875f-ceeef93ffdf8',
];

function sqlStr(v) {
  if (v === null || v === undefined || v === '') return 'NULL';
  return `'${String(v).replace(/'/g, "''")}'`;
}
function sqlNum(v) {
  if (v === null || v === undefined) return 'NULL';
  const n = Number(v);
  return Number.isFinite(n) ? String(n) : 'NULL';
}
function sqlBool(v) {
  return v ? 'true' : 'false';
}
function tsFromFirestore(v) {
  if (!v) return 'NULL';
  if (v._seconds !== undefined) return sqlStr(new Date(v._seconds * 1000).toISOString());
  return sqlStr(v);
}

const b = wine.business;

const lines = [];
lines.push('BEGIN;');
lines.push('');
lines.push('-- Recover "Volume B Wine, Cocktails & Grills" (never migrated from Firestore)');
lines.push(`INSERT INTO businesses (name, business_type, owner_id, address, phone, email, currency, is_active, legacy_firestore_id, created_at, business_class)`);
lines.push(`VALUES (${sqlStr(b.name)}, ${sqlStr(b.businessType)}, ${sqlStr(OWNER_ID)}, ${sqlStr(b.address)}, ${sqlStr(b.phone)}, ${sqlStr(b.email)}, ${sqlStr(b.currency || 'NGN')}, true, ${sqlStr(b.firestoreId)}, ${tsFromFirestore(b.createdAt)}, ${sqlStr(b.businessClass || 'tier1')})`);
lines.push(`RETURNING id \\gset new_biz_`);
lines.push('');

lines.push('-- Link the existing owner to the recovered business');
lines.push(`INSERT INTO business_members (user_id, business_id, role, is_owner, is_active)`);
lines.push(`VALUES (${sqlStr(OWNER_ID)}, :'new_biz_id', 'owner', true, true);`);
lines.push('');

lines.push(`-- Recover all ${wine.inventory.length} products`);
for (const item of wine.inventory) {
  lines.push(
    `INSERT INTO inventory (business_id, name, sku, barcode, category, description, unit_price, cost_price, quantity, unit, is_active, legacy_firestore_id, created_at) VALUES (` +
      [
        ":'new_biz_id'",
        sqlStr(item.name),
        sqlStr(item.sku),
        sqlStr(item.barcode),
        sqlStr(item.category),
        sqlStr(item.description),
        sqlNum(item.price),
        sqlNum(item.cost),
        sqlNum(item.quantity),
        sqlStr(item.unit || 'pcs'),
        'true',
        sqlStr(item.firestoreId),
        tsFromFirestore(item.createdAt),
      ].join(', ') +
      ');'
  );
}
lines.push('');

lines.push('-- The owner\'s current_business_id may point at one of the empty');
lines.push('-- duplicates (that FK has no ON DELETE action, unlike business_members\'');
lines.push('-- cascade) - repoint it at the recovered business first so the deletes');
lines.push('-- below don\'t get blocked.');
lines.push(`UPDATE profiles SET current_business_id = :'new_biz_id' WHERE current_business_id IN (${DUPLICATE_BUSINESS_IDS.map(sqlStr).join(', ')});`);
lines.push('');

lines.push('-- Remove the two empty duplicate businesses created today while the owner');
lines.push('-- was trying to recover the missing business by hand (business_members rows');
lines.push('-- cascade-delete via FK).');
for (const id of DUPLICATE_BUSINESS_IDS) {
  lines.push(`DELETE FROM businesses WHERE id = ${sqlStr(id)};`);
}
lines.push('');
lines.push('COMMIT;');

const outPath = path.join(__dirname, 'recover_volume_wine.sql');
fs.writeFileSync(outPath, lines.join('\n'));
console.log(`Wrote ${outPath}`);
console.log(`Products: ${wine.inventory.length}`);
