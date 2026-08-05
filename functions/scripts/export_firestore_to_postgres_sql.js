#!/usr/bin/env node

/**
 * Export legacy Firestore data into an idempotent PostgreSQL import script.
 *
 * Usage from repo root:
 *   cd functions
 *   node scripts/export_firestore_to_postgres_sql.js --out ../firestore-postgres-import.sql
 *
 * Auth:
 *   Set GOOGLE_APPLICATION_CREDENTIALS to a Firebase service-account JSON, or
 *   run after `gcloud auth application-default login`.
 *
 * Optional:
 *   MIGRATION_TEMP_PASSWORD_HASH='bcrypt hash' adds a login password to imported
 *   profiles. Without it, imported users keep their data but need a password set
 *   later before they can log in to the private backend.
 */

const fs = require('fs');
const path = require('path');
const crypto = require('crypto');
const admin = require('firebase-admin');
const bcrypt = require('bcryptjs');

const args = process.argv.slice(2);
const outIndex = args.indexOf('--out');
const outFile = outIndex >= 0 ? args[outIndex + 1] : '../firestore-postgres-import.sql';
const projectIndex = args.indexOf('--project');
const projectId =
  projectIndex >= 0 ? args[projectIndex + 1] : process.env.FIREBASE_PROJECT_ID;
const serviceAccountIndex = args.indexOf('--service-account');
const serviceAccountPath =
  serviceAccountIndex >= 0
    ? args[serviceAccountIndex + 1]
    : process.env.GOOGLE_APPLICATION_CREDENTIALS;
const passwordCsvIndex = args.indexOf('--password-csv');
const passwordCsvFile =
  passwordCsvIndex >= 0 ? args[passwordCsvIndex + 1] : '../firestore-import-passwords.csv';
const generateTempPasswords = args.includes('--generate-temp-passwords');
const dryRun = args.includes('--dry-run');

if (!admin.apps.length) {
  const options = {};
  if (projectId) options.projectId = projectId;
  if (serviceAccountPath) {
    const resolvedPath = path.resolve(process.cwd(), serviceAccountPath);
    const serviceAccount = JSON.parse(fs.readFileSync(resolvedPath, 'utf8'));
    options.credential = admin.credential.cert(serviceAccount);
    options.projectId = projectId || serviceAccount.project_id;
  }
  admin.initializeApp(options);
}

const db = admin.firestore();
const fixedNamespace = '0f8fad5b-d9cb-469f-a165-70867728950e';
const staticTempPasswordHash = process.env.MIGRATION_TEMP_PASSWORD_HASH || null;
const generatedPasswords = new Map();
const passwordRows = [];

function uuidFor(kind, id) {
  const input = `${fixedNamespace}:${kind}:${id}`;
  const bytes = crypto.createHash('sha1').update(input).digest().subarray(0, 16);
  bytes[6] = (bytes[6] & 0x0f) | 0x50;
  bytes[8] = (bytes[8] & 0x3f) | 0x80;
  const hex = bytes.toString('hex');
  return `${hex.slice(0, 8)}-${hex.slice(8, 12)}-${hex.slice(12, 16)}-${hex.slice(16, 20)}-${hex.slice(20)}`;
}

function sql(value) {
  if (value === undefined || value === null || value === '') return 'NULL';
  if (typeof value === 'number') return Number.isFinite(value) ? String(value) : 'NULL';
  if (typeof value === 'boolean') return value ? 'TRUE' : 'FALSE';
  if (value instanceof Date) return `'${value.toISOString().replace(/'/g, "''")}'`;
  return `'${String(value).replace(/'/g, "''")}'`;
}

function jsonSql(value) {
  if (value === undefined || value === null) return "'{}'::jsonb";
  return `${sql(JSON.stringify(value))}::jsonb`;
}

function dateValue(value) {
  if (!value) return null;
  if (value instanceof Date) return value;
  if (typeof value.toDate === 'function') return value.toDate();
  if (typeof value === 'string') {
    const parsed = new Date(value);
    return Number.isNaN(parsed.getTime()) ? null : parsed;
  }
  if (typeof value === 'number') {
    const parsed = new Date(value);
    return Number.isNaN(parsed.getTime()) ? null : parsed;
  }
  return null;
}

function text(data, keys, fallback = null) {
  for (const key of keys) {
    const value = data[key];
    if (value !== undefined && value !== null && String(value).trim() !== '') {
      return String(value).trim();
    }
  }
  return fallback;
}

function num(data, keys, fallback = 0) {
  for (const key of keys) {
    const value = data[key];
    if (value !== undefined && value !== null && value !== '') {
      const parsed = Number(value);
      if (Number.isFinite(parsed)) return parsed;
    }
  }
  return fallback;
}

function bool(data, keys, fallback = true) {
  for (const key of keys) {
    const value = data[key];
    if (typeof value === 'boolean') return value;
    if (typeof value === 'string') return value.toLowerCase() === 'true';
  }
  return fallback;
}

function optionalNum(data, keys) {
  for (const key of keys) {
    const value = data[key];
    if (value !== undefined && value !== null && value !== '') {
      const parsed = Number(value);
      if (Number.isFinite(parsed)) return parsed;
    }
  }
  return null;
}

function inventoryMetadata(data) {
  const metadata = {};
  const wholesalePrice = optionalNum(data, ['wholesalePrice', 'wholesale_price']);

  if (wholesalePrice !== null) metadata.wholesale_price = wholesalePrice;

  return metadata;
}

function pgUuid(kind, id) {
  return `${sql(uuidFor(kind, id))}::uuid`;
}

function mapBusinessId(raw) {
  if (!raw) return null;
  return uuidFor('business', raw);
}

function mapProfileId(raw) {
  if (!raw) return null;
  return uuidFor('profile', raw);
}

async function passwordHashFor(profileId, email) {
  if (staticTempPasswordHash) return staticTempPasswordHash;
  if (!generateTempPasswords) return null;
  if (generatedPasswords.has(profileId)) return generatedPasswords.get(profileId).hash;

  const password = `Mc-${crypto.randomBytes(9).toString('base64url')}!1`;
  const hash = await bcrypt.hash(password, 10);
  generatedPasswords.set(profileId, { password, hash });
  passwordRows.push({
    profileId,
    email: email || '',
    temporaryPassword: password,
  });
  return hash;
}

async function getAll(collectionPath) {
  const snap = await db.collection(collectionPath).get();
  return snap.docs.map((doc) => ({ id: doc.id, data: doc.data(), ref: doc.ref }));
}

async function getSubcollection(docRef, name) {
  const snap = await docRef.collection(name).get();
  return snap.docs.map((doc) => ({ id: doc.id, data: doc.data(), ref: doc.ref }));
}

function profileInsert(id, legacyId, data, passwordHash = null, emailOverride) {
  const email = emailOverride === undefined ? text(data, ['email']) : emailOverride;
  const fullName = text(data, ['fullName', 'full_name', 'name', 'displayName'], email || legacyId);
  const phone = text(data, ['phoneNumber', 'phone', 'phone_number']);
  const photo = text(data, ['photoUrl', 'photo_url', 'avatar']);
  const pin = text(data, ['pin']);
  const createdAt = dateValue(data.createdAt || data.created_at);
  const updatedAt = dateValue(data.updatedAt || data.updated_at);
  return `INSERT INTO profiles (id, legacy_firestore_id, email, full_name, phone_number, photo_url, pin, current_business_id, password_hash, created_at, updated_at)
VALUES (${sql(id)}::uuid, ${sql(legacyId)}, ${sql(email)}, ${sql(fullName)}, ${sql(phone)}, ${sql(photo)}, ${sql(pin)}, NULL, ${sql(passwordHash)}, COALESCE(${sql(createdAt)}::timestamptz, NOW()), COALESCE(${sql(updatedAt)}::timestamptz, NOW()))
ON CONFLICT (id) DO UPDATE SET
  legacy_firestore_id = COALESCE(profiles.legacy_firestore_id, EXCLUDED.legacy_firestore_id),
  email = COALESCE(EXCLUDED.email, profiles.email),
  full_name = COALESCE(EXCLUDED.full_name, profiles.full_name),
  phone_number = COALESCE(EXCLUDED.phone_number, profiles.phone_number),
  photo_url = COALESCE(EXCLUDED.photo_url, profiles.photo_url),
  pin = COALESCE(EXCLUDED.pin, profiles.pin),
  current_business_id = COALESCE(EXCLUDED.current_business_id, profiles.current_business_id),
  password_hash = COALESCE(EXCLUDED.password_hash, profiles.password_hash),
  updated_at = NOW();`;
}

function businessInsert(id, legacyId, data, ownerProfileId) {
  const name = text(data, ['name', 'businessName'], 'Untitled Business');
  const businessType = text(data, ['businessType', 'business_type', 'type']);
  const createdAt = dateValue(data.createdAt || data.created_at);
  const updatedAt = dateValue(data.updatedAt || data.updated_at);
  return `INSERT INTO businesses (id, legacy_firestore_id, name, business_type, owner_id, address, phone, email, currency, logo_url, subscription_tier, subscription_plan, subscription_start_date, subscription_end_date, is_subscription_active, is_active, created_at, updated_at)
VALUES (${sql(id)}::uuid, ${sql(legacyId)}, ${sql(name)}, ${sql(businessType)}, ${ownerProfileId ? `${sql(ownerProfileId)}::uuid` : 'NULL'}, ${sql(text(data, ['address']))}, ${sql(text(data, ['phone']))}, ${sql(text(data, ['email']))}, ${sql(text(data, ['currency'], 'NGN'))}, ${sql(text(data, ['logoUrl', 'photoUrl', 'logo_url']))}, ${sql(text(data, ['subscriptionTier', 'subscription_tier'], 'free'))}, ${sql(text(data, ['subscriptionPlan', 'subscription_plan'], text(data, ['subscriptionTier'], 'free')))}, ${sql(dateValue(data.subscriptionStartDate || data.subscription_start_date))}::timestamptz, ${sql(dateValue(data.subscriptionEndDate || data.subscription_end_date))}::timestamptz, ${sql(bool(data, ['isSubscriptionActive', 'is_subscription_active'], true))}, ${sql(bool(data, ['isActive', 'is_active'], true))}, COALESCE(${sql(createdAt)}::timestamptz, NOW()), COALESCE(${sql(updatedAt)}::timestamptz, NOW()))
ON CONFLICT (id) DO UPDATE SET
  name = EXCLUDED.name,
  business_type = EXCLUDED.business_type,
  owner_id = COALESCE(EXCLUDED.owner_id, businesses.owner_id),
  address = COALESCE(EXCLUDED.address, businesses.address),
  phone = COALESCE(EXCLUDED.phone, businesses.phone),
  email = COALESCE(EXCLUDED.email, businesses.email),
  currency = COALESCE(EXCLUDED.currency, businesses.currency),
  logo_url = COALESCE(EXCLUDED.logo_url, businesses.logo_url),
  subscription_tier = COALESCE(EXCLUDED.subscription_tier, businesses.subscription_tier),
  subscription_plan = COALESCE(EXCLUDED.subscription_plan, businesses.subscription_plan),
  subscription_start_date = COALESCE(EXCLUDED.subscription_start_date, businesses.subscription_start_date),
  subscription_end_date = COALESCE(EXCLUDED.subscription_end_date, businesses.subscription_end_date),
  is_subscription_active = EXCLUDED.is_subscription_active,
  is_active = EXCLUDED.is_active,
  updated_at = NOW();`;
}

function membershipInsert(profileId, businessId, role = 'staff', isOwner = false, permissions = {}) {
  return `INSERT INTO business_members (user_id, business_id, role, is_owner, is_active, permissions)
VALUES (${sql(profileId)}::uuid, ${sql(businessId)}::uuid, ${sql(role)}, ${sql(isOwner)}, TRUE, ${jsonSql(permissions)})
ON CONFLICT (user_id, business_id) DO UPDATE SET
  role = EXCLUDED.role,
  is_owner = EXCLUDED.is_owner,
  is_active = TRUE,
  permissions = COALESCE(EXCLUDED.permissions, business_members.permissions),
  updated_at = NOW();`;
}

function inventoryInsert(id, legacyId, businessId, data) {
  return `INSERT INTO inventory (id, legacy_firestore_id, business_id, name, sku, barcode, category, description, unit_price, cost_price, quantity, min_stock_level, unit, expiry_date, is_active, metadata, created_at, updated_at)
VALUES (${sql(id)}::uuid, ${sql(legacyId)}, ${sql(businessId)}::uuid, ${sql(text(data, ['name', 'productName', 'title'], 'Unnamed Item'))}, ${sql(text(data, ['sku']))}, ${sql(text(data, ['barcode']))}, ${sql(text(data, ['category']))}, ${sql(text(data, ['description']))}, ${sql(num(data, ['unit_price', 'unitPrice', 'price', 'sellingPrice'], 0))}, ${sql(num(data, ['cost_price', 'costPrice', 'cost', 'purchasePrice'], 0))}, ${sql(num(data, ['quantity', 'stock'], 0))}, ${sql(num(data, ['min_stock_level', 'minStockLevel', 'lowStockThreshold'], 0))}, ${sql(text(data, ['unit', 'uom'], 'pcs'))}, ${sql(dateValue(data.expiryDate || data.expiry_date))}::timestamptz, ${sql(bool(data, ['isActive', 'is_active'], true))}, ${jsonSql(inventoryMetadata(data))}, COALESCE(${sql(dateValue(data.createdAt || data.created_at))}::timestamptz, NOW()), COALESCE(${sql(dateValue(data.updatedAt || data.updated_at))}::timestamptz, NOW()))
ON CONFLICT (id) DO UPDATE SET
  name = EXCLUDED.name,
  sku = COALESCE(EXCLUDED.sku, inventory.sku),
  barcode = COALESCE(EXCLUDED.barcode, inventory.barcode),
  category = COALESCE(EXCLUDED.category, inventory.category),
  description = COALESCE(EXCLUDED.description, inventory.description),
  unit_price = EXCLUDED.unit_price,
  cost_price = EXCLUDED.cost_price,
  quantity = EXCLUDED.quantity,
  min_stock_level = EXCLUDED.min_stock_level,
  unit = EXCLUDED.unit,
  expiry_date = COALESCE(EXCLUDED.expiry_date, inventory.expiry_date),
  is_active = EXCLUDED.is_active,
  metadata = inventory.metadata || EXCLUDED.metadata,
  updated_at = NOW();`;
}

function customerInsert(id, legacyId, businessId, data) {
  return `INSERT INTO customers (id, legacy_firestore_id, business_id, name, email, phone, address, city, state, loyalty_points, total_purchases, total_spent, is_active, created_at, updated_at)
VALUES (${sql(id)}::uuid, ${sql(legacyId)}, ${sql(businessId)}::uuid, ${sql(text(data, ['name', 'fullName'], 'Unnamed Customer'))}, ${sql(text(data, ['email']))}, ${sql(text(data, ['phone', 'phoneNumber']))}, ${sql(text(data, ['address']))}, ${sql(text(data, ['city']))}, ${sql(text(data, ['state']))}, ${sql(num(data, ['loyaltyPoints', 'loyalty_points'], 0))}, ${sql(num(data, ['totalPurchases', 'total_purchases'], 0))}, ${sql(num(data, ['totalSpent', 'total_spent'], 0))}, ${sql(bool(data, ['isActive', 'is_active'], true))}, COALESCE(${sql(dateValue(data.createdAt || data.created_at))}::timestamptz, NOW()), COALESCE(${sql(dateValue(data.updatedAt || data.updated_at))}::timestamptz, NOW()))
ON CONFLICT (id) DO UPDATE SET
  name = EXCLUDED.name,
  email = COALESCE(EXCLUDED.email, customers.email),
  phone = COALESCE(EXCLUDED.phone, customers.phone),
  address = COALESCE(EXCLUDED.address, customers.address),
  city = COALESCE(EXCLUDED.city, customers.city),
  state = COALESCE(EXCLUDED.state, customers.state),
  loyalty_points = EXCLUDED.loyalty_points,
  total_purchases = EXCLUDED.total_purchases,
  total_spent = EXCLUDED.total_spent,
  is_active = EXCLUDED.is_active,
  updated_at = NOW();`;
}

function workerInsert(id, legacyId, businessId, data) {
  const email = text(data, ['email']);
  return `INSERT INTO workers (id, legacy_firestore_id, email, full_name, phone, role, business_id, is_active, permissions, pin, created_at, updated_at)
VALUES (${sql(id)}::uuid, ${sql(legacyId)}, ${sql(email)}, ${sql(text(data, ['fullName', 'full_name', 'name'], email || 'Worker'))}, ${sql(text(data, ['phone', 'phoneNumber']))}, ${sql(text(data, ['role'], 'staff'))}, ${sql(businessId)}::uuid, ${sql(bool(data, ['isActive', 'is_active'], true))}, ${jsonSql(data.permissions || {})}, ${sql(text(data, ['pin']))}, COALESCE(${sql(dateValue(data.createdAt || data.created_at))}::timestamptz, NOW()), COALESCE(${sql(dateValue(data.updatedAt || data.updated_at))}::timestamptz, NOW()))
ON CONFLICT (id) DO UPDATE SET
  email = COALESCE(EXCLUDED.email, workers.email),
  full_name = EXCLUDED.full_name,
  phone = COALESCE(EXCLUDED.phone, workers.phone),
  role = EXCLUDED.role,
  is_active = EXCLUDED.is_active,
  permissions = COALESCE(EXCLUDED.permissions, workers.permissions),
  pin = COALESCE(EXCLUDED.pin, workers.pin),
  updated_at = NOW();`;
}

function expenseInsert(id, legacyId, businessId, data, createdBy = null) {
  return `INSERT INTO expenses (id, legacy_firestore_id, business_id, category, amount, description, paid_by, receipt_url, created_by, created_at, updated_at)
VALUES (${sql(id)}::uuid, ${sql(legacyId)}, ${sql(businessId)}::uuid, ${sql(text(data, ['category'], 'General'))}, ${sql(num(data, ['amount', 'total'], 0))}, ${sql(text(data, ['description', 'notes']))}, ${sql(text(data, ['paidBy', 'paid_by']))}, ${sql(text(data, ['receiptUrl', 'receipt_url']))}, ${createdBy ? `${sql(createdBy)}::uuid` : 'NULL'}, COALESCE(${sql(dateValue(data.createdAt || data.created_at || data.date))}::timestamptz, NOW()), COALESCE(${sql(dateValue(data.updatedAt || data.updated_at))}::timestamptz, NOW()))
ON CONFLICT (id) DO UPDATE SET
  category = EXCLUDED.category,
  amount = EXCLUDED.amount,
  description = COALESCE(EXCLUDED.description, expenses.description),
  paid_by = COALESCE(EXCLUDED.paid_by, expenses.paid_by),
  receipt_url = COALESCE(EXCLUDED.receipt_url, expenses.receipt_url),
  updated_at = NOW();`;
}

function saleInsert(id, legacyId, businessId, data, createdBy = null) {
  const total = num(data, ['total_amount', 'totalAmount', 'total', 'finalAmount'], 0);
  return `INSERT INTO sales (id, legacy_firestore_id, business_id, customer_id, worker_name, total_amount, discount_amount, tax_amount, final_amount, payment_method, status, notes, created_by, sale_type, created_at, updated_at)
VALUES (${sql(id)}::uuid, ${sql(legacyId)}, ${sql(businessId)}::uuid, NULL, ${sql(text(data, ['workerName', 'cashierName']))}, ${sql(total)}, ${sql(num(data, ['discountAmount', 'discount_amount', 'discount'], 0))}, ${sql(num(data, ['taxAmount', 'tax_amount', 'tax'], 0))}, ${sql(num(data, ['finalAmount', 'final_amount', 'total'], total))}, ${sql(text(data, ['paymentMethod', 'payment_method'], 'cash'))}, ${sql(text(data, ['status'], 'completed'))}, ${sql(text(data, ['notes']))}, ${sql(createdBy)}::uuid, ${sql(text(data, ['saleType', 'sale_type'], 'retail'))}, COALESCE(${sql(dateValue(data.createdAt || data.created_at || data.timestamp || data.date))}::timestamptz, NOW()), COALESCE(${sql(dateValue(data.updatedAt || data.updated_at))}::timestamptz, NOW()))
ON CONFLICT (id) DO UPDATE SET
  worker_name = COALESCE(EXCLUDED.worker_name, sales.worker_name),
  total_amount = EXCLUDED.total_amount,
  discount_amount = EXCLUDED.discount_amount,
  tax_amount = EXCLUDED.tax_amount,
  final_amount = EXCLUDED.final_amount,
  payment_method = EXCLUDED.payment_method,
  status = EXCLUDED.status,
  notes = COALESCE(EXCLUDED.notes, sales.notes),
  updated_at = NOW();`;
}

function saleItemInsert(id, legacyId, saleId, data) {
  const qty = num(data, ['quantity', 'qty'], 1);
  const price = num(data, ['unitPrice', 'unit_price', 'price'], 0);
  return `INSERT INTO sale_items (id, legacy_firestore_id, sale_id, product_name, quantity, unit_price, discount, total, pricing_mode, inventory_unit, sale_unit, sale_unit_multiplier)
VALUES (${sql(id)}::uuid, ${sql(legacyId)}, ${sql(saleId)}::uuid, ${sql(text(data, ['productName', 'name', 'title'], 'Item'))}, ${sql(qty)}, ${sql(price)}, ${sql(num(data, ['discount'], 0))}, ${sql(num(data, ['total', 'lineTotal'], qty * price))}, ${sql(text(data, ['pricingMode', 'pricing_mode']))}, ${sql(text(data, ['inventoryUnit', 'inventory_unit', 'unit']))}, ${sql(text(data, ['saleUnit', 'sale_unit']))}, ${sql(num(data, ['saleUnitMultiplier', 'sale_unit_multiplier'], 1))})
ON CONFLICT (id) DO UPDATE SET
  product_name = EXCLUDED.product_name,
  quantity = EXCLUDED.quantity,
  unit_price = EXCLUDED.unit_price,
  discount = EXCLUDED.discount,
  total = EXCLUDED.total;`;
}

async function main() {
  const lines = [
    '-- Firestore to ManageCare Postgres import',
    `-- Generated at ${new Date().toISOString()}`,
    '\\set ON_ERROR_STOP on',
    'BEGIN;',
  ];
  const counts = {};
  const inc = (key, amount = 1) => { counts[key] = (counts[key] || 0) + amount; };

  const users = await getAll('users');
  const userIds = new Set(users.map((u) => u.id));
  const businesses = await getAll('businesses');
  const businessLegacyIds = new Set(businesses.map((b) => b.id));
  const businessOwnerProfileIds = new Map();
  const ownerIds = new Set();
  const currentBusinessUpdates = [];
  const migrationProfileId = uuidFor('profile', 'migration-system');
  const importEmails = [];
  const emailOwners = new Map();

  for (const user of users) {
    const email = text(user.data, ['email']);
    if (!email) continue;
    const key = email.toLowerCase();
    importEmails.push(key);
    if (!emailOwners.has(key)) {
      emailOwners.set(key, user.id);
    }
  }

  const uniqueImportEmails = [...new Set(importEmails)];
  if (uniqueImportEmails.length) {
    lines.push('-- Free legacy Firestore emails from private-test profiles before import.');
    lines.push(`UPDATE profiles
SET email = 'private-conflict+' || id::text || '@managecare.invalid',
    updated_at = NOW()
WHERE email IS NOT NULL
  AND lower(email) IN (${uniqueImportEmails.map(sql).join(', ')})
  AND legacy_firestore_id IS NULL;`);
  }

  for (const b of businesses) {
    const owner = text(b.data, ['ownerId', 'owner_id', 'uid', 'userId']);
    if (owner) ownerIds.add(owner);
  }

  for (const id of ownerIds) {
    if (!userIds.has(id)) {
      const profileId = mapProfileId(id);
      const passwordHash = await passwordHashFor(profileId, null);
      lines.push(profileInsert(profileId, id, { fullName: id }, passwordHash));
      inc('profiles');
    }
  }

  lines.push(profileInsert(
    migrationProfileId,
    'migration-system',
    {
      email: 'migration-system@managecare.invalid',
      fullName: 'Migration System',
    },
    null,
    'migration-system@managecare.invalid'
  ));
  inc('profiles');

  for (const user of users) {
    const currentBusinessLegacyId = text(user.data, ['currentBusinessId', 'businessId']);
    const profileId = mapProfileId(user.id);
    const email = text(user.data, ['email']);
    const emailKey = email?.toLowerCase();
    const effectiveEmail =
      emailKey && emailOwners.get(emailKey) === user.id ? email : null;
    const passwordHash = await passwordHashFor(profileId, effectiveEmail);
    lines.push(profileInsert(profileId, user.id, user.data, passwordHash, effectiveEmail));
    if (currentBusinessLegacyId && businessLegacyIds.has(currentBusinessLegacyId)) {
      currentBusinessUpdates.push({
        profileId,
        businessId: mapBusinessId(currentBusinessLegacyId),
      });
    }
    inc('profiles');
  }

  for (const business of businesses) {
    const ownerLegacyId = text(business.data, ['ownerId', 'owner_id', 'uid', 'userId']);
    const ownerProfileId = ownerLegacyId ? mapProfileId(ownerLegacyId) : null;
    const businessId = mapBusinessId(business.id);
    businessOwnerProfileIds.set(business.id, ownerProfileId || migrationProfileId);
    lines.push(businessInsert(businessId, business.id, business.data, ownerProfileId));
    inc('businesses');
    if (ownerProfileId) {
      lines.push(membershipInsert(ownerProfileId, businessId, 'owner', true));
      inc('business_members');
    }

    for (const name of ['inventory', 'customers', 'workers', 'expenses', 'sales']) {
      const docs = await getSubcollection(business.ref, name);
      for (const doc of docs) {
        const legacy = `${business.id}/${name}/${doc.id}`;
        if (name === 'inventory') {
          lines.push(inventoryInsert(uuidFor('inventory', legacy), legacy, businessId, doc.data));
          inc('inventory');
        } else if (name === 'customers') {
          lines.push(customerInsert(uuidFor('customer', legacy), legacy, businessId, doc.data));
          inc('customers');
        } else if (name === 'workers') {
          lines.push(workerInsert(uuidFor('worker', legacy), legacy, businessId, doc.data));
          inc('workers');
        } else if (name === 'expenses') {
          const createdBy = mapProfileId(text(doc.data, ['createdBy', 'userId', 'ownerId']));
          lines.push(expenseInsert(uuidFor('expense', legacy), legacy, businessId, doc.data, createdBy));
          inc('expenses');
        } else if (name === 'sales') {
          const createdBy =
            mapProfileId(text(doc.data, ['createdBy', 'userId', 'ownerId'])) ||
            businessOwnerProfileIds.get(business.id) ||
            migrationProfileId;
          const saleId = uuidFor('sale', legacy);
          lines.push(saleInsert(saleId, legacy, businessId, doc.data, createdBy));
          inc('sales');
          const rawItems = doc.data.items || doc.data.products || doc.data.saleItems || [];
          if (Array.isArray(rawItems)) {
            rawItems.forEach((item, index) => {
              const itemLegacy = `${legacy}/items/${item.id || index}`;
              lines.push(saleItemInsert(uuidFor('sale_item', itemLegacy), itemLegacy, saleId, item));
              inc('sale_items');
            });
          }
        }
      }
    }
  }

  for (const update of currentBusinessUpdates) {
    lines.push(`UPDATE profiles SET current_business_id = ${sql(update.businessId)}::uuid, updated_at = NOW() WHERE id = ${sql(update.profileId)}::uuid;`);
  }

  lines.push('COMMIT;');
  lines.push('');
  lines.push('-- Imported row counts:');
  for (const [key, value] of Object.entries(counts).sort()) {
    lines.push(`-- ${key}: ${value}`);
  }

  const resolved = path.resolve(process.cwd(), outFile);
  if (!dryRun) fs.writeFileSync(resolved, `${lines.join('\n')}\n`, 'utf8');

  let passwordCsv = null;
  if (!dryRun && passwordRows.length) {
    passwordCsv = path.resolve(process.cwd(), passwordCsvFile);
    const csv = [
      'profile_id,email,temporary_password',
      ...passwordRows.map((row) =>
        [row.profileId, row.email, row.temporaryPassword]
          .map((v) => `"${String(v).replace(/"/g, '""')}"`)
          .join(',')
      ),
    ].join('\n');
    fs.writeFileSync(passwordCsv, `${csv}\n`, 'utf8');
  }

  console.log(JSON.stringify({ out: resolved, passwordCsv, dryRun, counts }, null, 2));
}

main().catch((err) => {
  console.error(err);
  process.exit(1);
});
