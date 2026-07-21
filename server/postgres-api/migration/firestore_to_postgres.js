import dotenv from 'dotenv';
import { initializeApp, cert } from 'firebase-admin/app';
import { getFirestore } from 'firebase-admin/firestore';
import { Pool } from 'pg';
import fs from 'fs';
import path from 'path';

dotenv.config({ path: path.resolve(process.cwd(), '.env') });

const firebaseServiceAccountPath = process.env.FIREBASE_SERVICE_ACCOUNT_PATH;
if (!firebaseServiceAccountPath) {
  throw new Error('FIREBASE_SERVICE_ACCOUNT_PATH must be set in .env');
}

const serviceAccount = JSON.parse(fs.readFileSync(firebaseServiceAccountPath, 'utf8'));

initializeApp({
  credential: cert(serviceAccount),
});

const firestore = getFirestore();
const pool = new Pool({
  host: process.env.DB_HOST || '127.0.0.1',
  port: Number(process.env.DB_PORT || 5432),
  database: process.env.DB_NAME || 'managecare',
  user: process.env.DB_USER || 'managecare',
  password: process.env.DB_PASSWORD || '',
});

async function migrateBusinesses() {
  const snapshot = await firestore.collection('businesses').get();
  for (const doc of snapshot.docs) {
    const data = doc.data();
    await pool.query(
      `INSERT INTO businesses (id, name, business_type, created_at, updated_at)
       VALUES ($1, $2, $3, $4, $5)
       ON CONFLICT (id) DO UPDATE SET name = EXCLUDED.name, business_type = EXCLUDED.business_type, updated_at = EXCLUDED.updated_at`,
      [doc.id, data.name || null, data.businessType || null, data.createdAt?.toDate() || new Date(), data.updatedAt?.toDate() || new Date()],
    );
  }
}

async function migrateProducts() {
  const snapshot = await firestore.collection('inventory').get();
  for (const doc of snapshot.docs) {
    const data = doc.data();
    await pool.query(
      `INSERT INTO products (id, business_id, name, category, sku, barcode, price, cost, quantity, unit, is_ingredient, created_at, updated_at)
       VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11, $12, $13)
       ON CONFLICT (id) DO UPDATE SET
         business_id = EXCLUDED.business_id,
         name = EXCLUDED.name,
         category = EXCLUDED.category,
         sku = EXCLUDED.sku,
         barcode = EXCLUDED.barcode,
         price = EXCLUDED.price,
         cost = EXCLUDED.cost,
         quantity = EXCLUDED.quantity,
         unit = EXCLUDED.unit,
         is_ingredient = EXCLUDED.is_ingredient,
         updated_at = EXCLUDED.updated_at`,
      [
        doc.id,
        data.businessId || null,
        data.name || null,
        data.category || null,
        data.sku || null,
        data.barcode || null,
        Number(data.price ?? data.cost ?? 0),
        Number(data.cost ?? 0),
        Number(data.quantity ?? 0),
        data.unit || null,
        data.isIngredient === true || data.isIngredient === 'true',
        data.createdAt?.toDate() || new Date(),
        data.updatedAt?.toDate() || new Date(),
      ],
    );
  }
}

async function migrateSales() {
  const snapshot = await firestore.collection('sales').get();
  for (const doc of snapshot.docs) {
    const data = doc.data();
    await pool.query(
      `INSERT INTO sales (id, business_id, customer_name, total_amount, payment_method, status, created_at, updated_at)
       VALUES ($1, $2, $3, $4, $5, $6, $7, $8)
       ON CONFLICT (id) DO UPDATE SET
         business_id = EXCLUDED.business_id,
         customer_name = EXCLUDED.customer_name,
         total_amount = EXCLUDED.total_amount,
         payment_method = EXCLUDED.payment_method,
         status = EXCLUDED.status,
         updated_at = EXCLUDED.updated_at`,
      [
        doc.id,
        data.businessId || null,
        data.customerName || data.customer_name || null,
        Number(data.totalAmount ?? 0),
        data.paymentMethod || data.payment_method || null,
        data.status || 'completed',
        data.createdAt?.toDate() || new Date(),
        data.updatedAt?.toDate() || new Date(),
      ],
    );

    if (Array.isArray(data.items)) {
      for (const item of data.items) {
        const itemId = item.id || `${doc.id}-${item.productId || item.product_id || 'item'}`;
        await pool.query(
          `INSERT INTO sale_items (id, sale_id, product_id, quantity, unit_price, total_amount, created_at)
           VALUES ($1, $2, $3, $4, $5, $6, $7)
           ON CONFLICT (id) DO UPDATE SET
             product_id = EXCLUDED.product_id,
             quantity = EXCLUDED.quantity,
             unit_price = EXCLUDED.unit_price,
             total_amount = EXCLUDED.total_amount`,
          [
            itemId,
            doc.id,
            item.productId || item.product_id || null,
            Number(item.quantity ?? 0),
            Number(item.unitPrice ?? item.price ?? 0),
            Number(item.totalAmount ?? 0),
            item.createdAt?.toDate() || data.createdAt?.toDate() || new Date(),
          ],
        );
      }
    }
  }
}

async function migrateProcurements() {
  const snapshot = await firestore.collection('procurements').get();
  for (const doc of snapshot.docs) {
    const data = doc.data();
    await pool.query(
      `INSERT INTO procurements (id, business_id, supplier_name, total_amount, status, created_at, updated_at)
       VALUES ($1, $2, $3, $4, $5, $6, $7)
       ON CONFLICT (id) DO UPDATE SET
         business_id = EXCLUDED.business_id,
         supplier_name = EXCLUDED.supplier_name,
         total_amount = EXCLUDED.total_amount,
         status = EXCLUDED.status,
         updated_at = EXCLUDED.updated_at`,
      [
        doc.id,
        data.businessId || null,
        data.supplierName || data.supplier_name || null,
        Number(data.totalAmount ?? 0),
        data.status || 'pending',
        data.createdAt?.toDate() || new Date(),
        data.updatedAt?.toDate() || new Date(),
      ],
    );

    if (Array.isArray(data.items)) {
      for (const item of data.items) {
        const itemId = item.id || `${doc.id}-${item.productId || item.product_id || 'item'}`;
        await pool.query(
          `INSERT INTO procurement_items (id, procurement_id, product_id, quantity, unit_price, total_amount, created_at)
           VALUES ($1, $2, $3, $4, $5, $6, $7)
           ON CONFLICT (id) DO UPDATE SET
             product_id = EXCLUDED.product_id,
             quantity = EXCLUDED.quantity,
             unit_price = EXCLUDED.unit_price,
             total_amount = EXCLUDED.total_amount`,
          [
            itemId,
            doc.id,
            item.productId || item.product_id || null,
            Number(item.quantity ?? 0),
            Number(item.unitPrice ?? item.price ?? 0),
            Number(item.totalAmount ?? 0),
            item.createdAt?.toDate() || data.createdAt?.toDate() || new Date(),
          ],
        );
      }
    }
  }
}

async function run() {
  try {
    console.log('Migrating businesses...');
    await migrateBusinesses();
    console.log('Migrating products...');
    await migrateProducts();
    console.log('Migrating sales...');
    await migrateSales();
    console.log('Migrating procurements...');
    await migrateProcurements();
    console.log('Verifying item deletion support...');
    await verifyItemDeletionSupport();
    console.log('Migration complete');
  } catch (error) {
    console.error('Migration failed:', error);
  } finally {
    await pool.end();
    process.exit(0);
  }
}

run();

async function verifyItemDeletionSupport() {
  // Create a temporary business, sale, and sale_item, then delete the item to ensure deletes work
  const client = await pool.connect();
  try {
    await client.query('BEGIN');
    const bRes = await client.query(
      `INSERT INTO businesses (name) VALUES ($1) RETURNING *`,
      ['migration_test_business'],
    );
    const businessId = bRes.rows[0].id;

    const sRes = await client.query(
      `INSERT INTO sales (business_id, total_amount) VALUES ($1, $2) RETURNING *`,
      [businessId, 0],
    );
    const saleId = sRes.rows[0].id;

    const siRes = await client.query(
      `INSERT INTO sale_items (sale_id, product_id, quantity, unit_price, total_amount) VALUES ($1, $2, $3, $4, $5) RETURNING *`,
      [saleId, null, 1, 0, 0],
    );
    const saleItemId = siRes.rows[0].id;

    const delSi = await client.query('DELETE FROM sale_items WHERE id = $1 RETURNING *', [saleItemId]);
    if (!delSi.rowCount) throw new Error('sale_items deletion check failed');

    // cleanup sale and business
    await client.query('DELETE FROM sales WHERE id = $1', [saleId]);
    await client.query('DELETE FROM businesses WHERE id = $1', [businessId]);

    // procurement path
    const pbRes = await client.query(
      `INSERT INTO businesses (name) VALUES ($1) RETURNING *`,
      ['migration_test_business_proc'],
    );
    const pbId = pbRes.rows[0].id;

    const pRes = await client.query(
      `INSERT INTO procurements (business_id, supplier_name, total_amount) VALUES ($1, $2, $3) RETURNING *`,
      [pbId, 'migration_supplier', 0],
    );
    const procId = pRes.rows[0].id;

    const piRes = await client.query(
      `INSERT INTO procurement_items (procurement_id, product_id, quantity, unit_price, total_amount) VALUES ($1, $2, $3, $4, $5) RETURNING *`,
      [procId, null, 1, 0, 0],
    );
    const procItemId = piRes.rows[0].id;

    const delPi = await client.query('DELETE FROM procurement_items WHERE id = $1 RETURNING *', [procItemId]);
    if (!delPi.rowCount) throw new Error('procurement_items deletion check failed');

    await client.query('DELETE FROM procurements WHERE id = $1', [procId]);
    await client.query('DELETE FROM businesses WHERE id = $1', [pbId]);

    await client.query('COMMIT');
    console.log('Item deletion support verified');
  } catch (err) {
    await client.query('ROLLBACK');
    console.error('Item deletion support check failed:', err.message || err);
    throw err;
  } finally {
    client.release();
  }
}
