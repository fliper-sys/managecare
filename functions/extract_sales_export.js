#!/usr/bin/env node
/**
 * Extract sales history for a specific business from the ManageCare Postgres
 * database and write it as a Firestore-shaped JSON file for import.
 *
 * Usage (run on the VPS where Postgres listens on 127.0.0.1:5432):
 *   cd /opt/managecare-backend
 *   DB_PASSWORD='BqHjAf8aMMmhHhOlW0j6bYIj4T7Owrya' \
 *     node extract_sales_export.js \
 *       --business aa2f33c7-80b2-5b53-9500-d57512cd29fd \
 *       --days 2 \
 *       --out londonspa_sales_last_2_days.json
 *
 * The business may be given as either the Postgres UUID or the legacy
 * Firestore id (bus_...).
 *
 * Env vars: DB_HOST, DB_PORT, DB_USER, DB_PASSWORD, DB_NAME
 */
const { Client } = require('pg');
const fs = require('fs');
const path = require('path');

const args = process.argv.slice(2);
const arg = (name, fallback) => {
  const i = args.indexOf(name);
  return i >= 0 && args[i + 1] !== undefined ? args[i + 1] : fallback;
};

const BUSINESS = arg('--business', 'aa2f33c7-80b2-5b53-9500-d57512cd29fd');
const DAYS = parseInt(arg('--days', '2'), 10) || 2;
const OUT = arg('--out', 'londonspa_sales_last_2_days.json');

// Load a .env from the current directory (or a --env path) if present, so
// the script uses the real DB credentials from the VPS rather than a
// hard-coded default.
const envPath = arg('--env', path.join(process.cwd(), '.env'));
if (fs.existsSync(envPath)) {
  for (const line of fs.readFileSync(envPath, 'utf8').split('\n')) {
    const m = line.match(/^\s*([A-Za-z_][A-Za-z0-9_]*)\s*=\s*(.*)\s*$/);
    if (m && process.env[m[1]] === undefined) {
      process.env[m[1]] = m[2];
    }
  }
}

const DB = {
  host: process.env.DB_HOST || '127.0.0.1',
  port: parseInt(process.env.DB_PORT || '5432', 10),
  user: process.env.DB_USER || 'managecare',
  password: process.env.DB_PASSWORD,
  database: process.env.DB_NAME || 'managecare',
};

function toIso(v) {
  if (v === null || v === undefined) return null;
  if (v instanceof Date) return v.toISOString();
  return new Date(v).toISOString();
}

function toNum(v) {
  if (v === null || v === undefined) return 0;
  const n = Number(v);
  return Number.isFinite(n) ? n : 0;
}

async function main() {
  if (!DB.password) {
    console.error('DB_PASSWORD is required (see extract_sales_export.js header).');
    process.exit(1);
  }

  const client = new Client(DB);
  await client.connect();

  // Resolve the business row by UUID or legacy Firestore id.
  const bizResult = await client.query(
    `SELECT id, name, legacy_firestore_id FROM businesses
     WHERE id::text = $1 OR legacy_firestore_id = $1`,
    [BUSINESS]
  );
  if (bizResult.rows.length === 0) {
    console.error(`No business found matching "${BUSINESS}".`);
    await client.end();
    process.exit(1);
  }
  const business = bizResult.rows[0];
  const businessId = business.id;
  console.log(
    `Business: ${business.name} (id=${businessId}, legacy=${business.legacy_firestore_id || 'none'})`
  );

  const since = new Date(Date.now() - DAYS * 24 * 60 * 60 * 1000);
  console.log(`Fetching sales since ${since.toISOString()} (${DAYS} day(s)).`);

  // Fetch the sales rows for the window.
  const salesResult = await client.query(
    `SELECT s.*
       FROM sales s
      WHERE s.business_id = $1
        AND s.created_at >= $2
      ORDER BY s.created_at ASC`,
    [businessId, since]
  );
  const sales = salesResult.rows;
  console.log(`Found ${sales.length} sale(s) in window.`);

  if (sales.length === 0) {
    // Still write a valid (empty) export so downstream steps behave.
    const out = {
      exportedAt: new Date().toISOString(),
      businessId,
      businessName: business.name,
      days: DAYS,
      since: since.toISOString(),
      sales: [],
    };
    fs.writeFileSync(OUT, JSON.stringify(out, null, 2));
    console.log(`Wrote ${OUT} (0 sales).`);
    await client.end();
    return;
  }

  // Fetch all line items for those sales in one query.
  const saleIds = sales.map((s) => s.id);
  const itemsResult = await client.query(
    `SELECT si.* FROM sale_items si WHERE si.sale_id = ANY($1)`,
    [saleIds]
  );
  const itemsBySale = new Map();
  for (const item of itemsResult.rows) {
    if (!itemsBySale.has(item.sale_id)) itemsBySale.set(item.sale_id, []);
    itemsBySale.get(item.sale_id).push(item);
  }

  // Transform into Firestore camelCase document shape.
  // Mirrors the legacy SalesRepositoryImpl write shape:
  //   root sales/{saleId}  +  businesses/{businessId}/sales/{saleId}
  const docs = sales.map((s) => {
    const items = (itemsBySale.get(s.id) || []).map((i) => ({
      id: i.id,
      productId: i.product_id || null,
      productName: i.product_name,
      quantity: toNum(i.quantity),
      unitPrice: toNum(i.unit_price),
      discount: toNum(i.discount),
      total: toNum(i.total),
      pricingMode: i.pricing_mode || null,
      inventoryUnit: i.inventory_unit || null,
      saleUnit: i.sale_unit || null,
      saleUnitMultiplier: toNum(i.sale_unit_multiplier),
    }));

    return {
      id: s.id,
      businessId: s.business_id,
      customerId: s.customer_id || null,
      storeId: s.store_id || null,
      workerId: s.worker_id || null,
      workerName: s.worker_name || null,
      totalAmount: toNum(s.total_amount),
      discountAmount: toNum(s.discount_amount),
      taxAmount: toNum(s.tax_amount),
      finalAmount: toNum(s.final_amount),
      paymentMethod: s.payment_method || 'cash',
      status: s.status || 'completed',
      notes: s.notes || null,
      createdBy: s.created_by || null,
      saleType: s.sale_type || 'retail',
      createdAt: toIso(s.created_at),
      updatedAt: toIso(s.updated_at),
      items,
    };
  });

  const out = {
    exportedAt: new Date().toISOString(),
    businessId,
    businessName: business.name,
    legacyFirestoreId: business.legacy_firestore_id || null,
    days: DAYS,
    since: since.toISOString(),
    sales: docs,
  };

  fs.writeFileSync(OUT, JSON.stringify(out, null, 2));
  console.log(`Wrote ${OUT} (${docs.length} sales, ${itemsBySale.size} with items).`);
  await client.end();
}

main().catch((err) => {
  console.error('FATAL', err);
  process.exit(1);
});

