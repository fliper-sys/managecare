import express from 'express';
import dotenv from 'dotenv';
import { Pool } from 'pg';

dotenv.config();

const app = express();
const port = process.env.PORT || 4000;

const pool = new Pool({
  host: process.env.DB_HOST || '127.0.0.1',
  port: Number(process.env.DB_PORT || 5432),
  database: process.env.DB_NAME || 'managecare',
  user: process.env.DB_USER || 'managecare',
  password: process.env.DB_PASSWORD || '',
});

app.use(express.json());

const respondBadRequest = (res, errors) => res.status(400).json({ errors });
const parseNumber = (value) => {
  if (value === undefined || value === null || value === '') return null;
  const parsed = Number(value);
  return Number.isFinite(parsed) ? parsed : NaN;
};

const validateEmail = (value) => {
  if (typeof value !== 'string') return false;
  return /^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(value);
};

const buildUpdateQuery = (table, id, fields, { updatedAt = true } = {}) => {
  const keys = Object.keys(fields);
  if (!keys.length) return null;
  const sets = keys.map((key, index) => `${key} = $${index + 1}`);
  const values = keys.map((key) => fields[key]);
  const query = `UPDATE ${table} SET ${sets.join(', ')}${updatedAt ? ', updated_at = NOW()' : ''} WHERE id = $${keys.length + 1} RETURNING *`;
  return { query, values: [...values, id] };
};

app.get('/health', async (_req, res) => {
  try {
    const result = await pool.query('SELECT NOW() AS now');
    res.json({ status: 'ok', timestamp: result.rows[0].now });
  } catch (error) {
    res.status(500).json({ status: 'error', message: error.message });
  }
});

app.get('/products', async (_req, res) => {
  try {
    const result = await pool.query('SELECT * FROM products ORDER BY name ASC');
    res.json(result.rows);
  } catch (error) {
    res.status(500).json({ error: error.message });
  }
});

app.post('/products', async (req, res) => {
  const { business_id, name, category, sku, barcode, price, cost, quantity, unit, is_ingredient } = req.body;
  const errors = [];

  if (!name || typeof name !== 'string') errors.push('name is required and must be a string');
  if (price !== undefined && Number.isNaN(parseNumber(price))) errors.push('price must be a number');
  if (cost !== undefined && Number.isNaN(parseNumber(cost))) errors.push('cost must be a number');
  if (quantity !== undefined && Number.isNaN(parseNumber(quantity))) errors.push('quantity must be a number');
  if (is_ingredient !== undefined && typeof is_ingredient !== 'boolean' && is_ingredient !== 'true' && is_ingredient !== 'false') {
    errors.push('is_ingredient must be a boolean');
  }

  if (errors.length) return respondBadRequest(res, errors);

  try {
    const result = await pool.query(
      `INSERT INTO products (business_id, name, category, sku, barcode, price, cost, quantity, unit, is_ingredient)
       VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10)
       RETURNING *`,
      [
        business_id || null,
        name,
        category || null,
        sku || null,
        barcode || null,
        parseNumber(price) ?? 0,
        parseNumber(cost) ?? 0,
        parseNumber(quantity) ?? 0,
        unit || null,
        is_ingredient === true || is_ingredient === 'true',
      ],
    );
    res.status(201).json(result.rows[0]);
  } catch (error) {
    res.status(500).json({ error: error.message });
  }
});

app.get('/businesses', async (_req, res) => {
  try {
    const result = await pool.query('SELECT * FROM businesses ORDER BY name ASC');
    res.json(result.rows);
  } catch (error) {
    res.status(500).json({ error: error.message });
  }
});

app.post('/businesses', async (req, res) => {
  const { name, business_type } = req.body;
  const errors = [];

  if (!name || typeof name !== 'string') errors.push('name is required and must be a string');
  if (business_type !== undefined && typeof business_type !== 'string') errors.push('business_type must be a string');

  if (errors.length) return respondBadRequest(res, errors);

  try {
    const result = await pool.query(
      `INSERT INTO businesses (name, business_type)
       VALUES ($1, $2)
       RETURNING *`,
      [name, business_type || null],
    );
    res.status(201).json(result.rows[0]);
  } catch (error) {
    res.status(500).json({ error: error.message });
  }
});

app.get('/users', async (req, res) => {
  try {
    const { business_id } = req.query;
    const values = [];
    let query = 'SELECT * FROM users';

    if (business_id) {
      values.push(business_id);
      query += ' WHERE business_id = $1';
    }

    query += ' ORDER BY created_at DESC';
    const result = await pool.query(query, values);
    res.json(result.rows);
  } catch (error) {
    res.status(500).json({ error: error.message });
  }
});

app.post('/users', async (req, res) => {
  const { business_id, email, full_name, role } = req.body;
  const errors = [];

  if (!business_id || typeof business_id !== 'string') errors.push('business_id is required and must be a string');
  if (!email || typeof email !== 'string' || !validateEmail(email)) errors.push('email is required and must be valid');
  if (full_name !== undefined && typeof full_name !== 'string') errors.push('full_name must be a string');
  if (role !== undefined && typeof role !== 'string') errors.push('role must be a string');

  if (errors.length) return respondBadRequest(res, errors);

  try {
    const result = await pool.query(
      `INSERT INTO users (business_id, email, full_name, role)
       VALUES ($1, $2, $3, $4)
       RETURNING *`,
      [business_id, email, full_name || null, role || null],
    );
    res.status(201).json(result.rows[0]);
  } catch (error) {
    res.status(500).json({ error: error.message });
  }
});

app.get('/sales', async (req, res) => {
  try {
    const { business_id } = req.query;
    const values = [];
    let query = `SELECT s.*, COALESCE(json_agg(json_build_object(
      'id', si.id,
      'product_id', si.product_id,
      'quantity', si.quantity,
      'unit_price', si.unit_price,
      'total_amount', si.total_amount,
      'created_at', si.created_at
    ) ORDER BY si.created_at) FILTER (WHERE si.id IS NOT NULL), '[]') AS items
      FROM sales s
      LEFT JOIN sale_items si ON si.sale_id = s.id`;

    if (business_id) {
      values.push(business_id);
      query += ' WHERE s.business_id = $1';
    }

    query += ' GROUP BY s.id ORDER BY s.created_at DESC';
    const result = await pool.query(query, values);
    res.json(result.rows);
  } catch (error) {
    res.status(500).json({ error: error.message });
  }
});

app.post('/sales', async (req, res) => {
  const { business_id, customer_name, total_amount, payment_method, status, items } = req.body;
  const errors = [];

  if (!business_id || typeof business_id !== 'string') errors.push('business_id is required and must be a string');
  if (customer_name !== undefined && typeof customer_name !== 'string') errors.push('customer_name must be a string');
  if (Number.isNaN(parseNumber(total_amount))) errors.push('total_amount must be a number');
  if (payment_method !== undefined && typeof payment_method !== 'string') errors.push('payment_method must be a string');
  if (status !== undefined && typeof status !== 'string') errors.push('status must be a string');
  if (items !== undefined && !Array.isArray(items)) errors.push('items must be an array');

  if (Array.isArray(items)) {
    items.forEach((item, index) => {
      if (!item.product_id || typeof item.product_id !== 'string') errors.push(`items[${index}].product_id is required and must be a string`);
      if (Number.isNaN(parseNumber(item.quantity))) errors.push(`items[${index}].quantity must be a number`);
      if (Number.isNaN(parseNumber(item.unit_price ?? item.price))) errors.push(`items[${index}].unit_price must be a number`);
      if (Number.isNaN(parseNumber(item.total_amount))) errors.push(`items[${index}].total_amount must be a number`);
    });
  }

  if (errors.length) return respondBadRequest(res, errors);

  const client = await pool.connect();
  try {
    await client.query('BEGIN');

    const saleResult = await client.query(
      `INSERT INTO sales (business_id, customer_name, total_amount, payment_method, status)
       VALUES ($1, $2, $3, $4, $5)
       RETURNING *`,
      [business_id, customer_name || null, parseNumber(total_amount) ?? 0, payment_method || null, status || 'completed'],
    );

    const sale = saleResult.rows[0];
    const insertedItems = [];

    if (Array.isArray(items)) {
      for (const item of items) {
        const itemResult = await client.query(
          `INSERT INTO sale_items (sale_id, product_id, quantity, unit_price, total_amount)
           VALUES ($1, $2, $3, $4, $5)
           RETURNING *`,
          [
            sale.id,
            item.product_id,
            parseNumber(item.quantity) ?? 0,
            parseNumber(item.unit_price ?? item.price) ?? 0,
            parseNumber(item.total_amount) ?? 0,
          ],
        );
        insertedItems.push(itemResult.rows[0]);
      }
    }

    await client.query('COMMIT');
    res.status(201).json({ ...sale, items: insertedItems });
  } catch (error) {
    await client.query('ROLLBACK');
    res.status(500).json({ error: error.message });
  } finally {
    client.release();
  }
});

app.patch('/sale-items/:id', async (req, res) => {
  const { id } = req.params;
  const { product_id, quantity, unit_price, total_amount } = req.body;
  const errors = [];
  const fields = {};

  if (product_id !== undefined) {
    if (!product_id || typeof product_id !== 'string') errors.push('product_id must be a non-empty string');
    else fields.product_id = product_id;
  }
  if (quantity !== undefined) {
    if (Number.isNaN(parseNumber(quantity))) errors.push('quantity must be a number');
    else fields.quantity = parseNumber(quantity);
  }
  if (unit_price !== undefined) {
    if (Number.isNaN(parseNumber(unit_price))) errors.push('unit_price must be a number');
    else fields.unit_price = parseNumber(unit_price);
  }
  if (total_amount !== undefined) {
    if (Number.isNaN(parseNumber(total_amount))) errors.push('total_amount must be a number');
    else fields.total_amount = parseNumber(total_amount);
  }

  if (errors.length) return respondBadRequest(res, errors);
  if (!Object.keys(fields).length) return respondBadRequest(res, ['No fields provided to update']);

  try {
    const update = buildUpdateQuery('sale_items', id, fields, { updatedAt: false });
    const result = await pool.query(update.query, update.values);
    if (!result.rowCount) return res.status(404).json({ error: 'sale item not found' });
    res.json(result.rows[0]);
  } catch (error) {
    res.status(500).json({ error: error.message });
  }
});

app.delete('/sale-items/:id', async (req, res) => {
  try {
    const result = await pool.query('DELETE FROM sale_items WHERE id = $1 RETURNING *', [req.params.id]);
    if (!result.rowCount) return res.status(404).json({ error: 'sale item not found' });
    res.status(204).send();
  } catch (error) {
    res.status(500).json({ error: error.message });
  }
});

app.patch('/procurement-items/:id', async (req, res) => {
  const { id } = req.params;
  const { product_id, quantity, unit_price, total_amount } = req.body;
  const errors = [];
  const fields = {};

  if (product_id !== undefined) {
    if (!product_id || typeof product_id !== 'string') errors.push('product_id must be a non-empty string');
    else fields.product_id = product_id;
  }
  if (quantity !== undefined) {
    if (Number.isNaN(parseNumber(quantity))) errors.push('quantity must be a number');
    else fields.quantity = parseNumber(quantity);
  }
  if (unit_price !== undefined) {
    if (Number.isNaN(parseNumber(unit_price))) errors.push('unit_price must be a number');
    else fields.unit_price = parseNumber(unit_price);
  }
  if (total_amount !== undefined) {
    if (Number.isNaN(parseNumber(total_amount))) errors.push('total_amount must be a number');
    else fields.total_amount = parseNumber(total_amount);
  }

  if (errors.length) return respondBadRequest(res, errors);
  if (!Object.keys(fields).length) return respondBadRequest(res, ['No fields provided to update']);

  try {
    const update = buildUpdateQuery('procurement_items', id, fields, { updatedAt: false });
    const result = await pool.query(update.query, update.values);
    if (!result.rowCount) return res.status(404).json({ error: 'procurement item not found' });
    res.json(result.rows[0]);
  } catch (error) {
    res.status(500).json({ error: error.message });
  }
});

app.delete('/procurement-items/:id', async (req, res) => {
  try {
    const result = await pool.query('DELETE FROM procurement_items WHERE id = $1 RETURNING *', [req.params.id]);
    if (!result.rowCount) return res.status(404).json({ error: 'procurement item not found' });
    res.status(204).send();
  } catch (error) {
    res.status(500).json({ error: error.message });
  }
});

app.get('/procurements', async (req, res) => {
  try {
    const { business_id } = req.query;
    const values = [];
    let query = `SELECT p.*, COALESCE(json_agg(json_build_object(
      'id', pi.id,
      'product_id', pi.product_id,
      'quantity', pi.quantity,
      'unit_price', pi.unit_price,
      'total_amount', pi.total_amount,
      'created_at', pi.created_at
    ) ORDER BY pi.created_at) FILTER (WHERE pi.id IS NOT NULL), '[]') AS items
      FROM procurements p
      LEFT JOIN procurement_items pi ON pi.procurement_id = p.id`;

    if (business_id) {
      values.push(business_id);
      query += ' WHERE p.business_id = $1';
    }

    query += ' GROUP BY p.id ORDER BY p.created_at DESC';
    const result = await pool.query(query, values);
    res.json(result.rows);
  } catch (error) {
    res.status(500).json({ error: error.message });
  }
});

app.post('/procurements', async (req, res) => {
  const { business_id, supplier_name, total_amount, status, items } = req.body;
  const errors = [];

  if (!business_id || typeof business_id !== 'string') errors.push('business_id is required and must be a string');
  if (!supplier_name || typeof supplier_name !== 'string') errors.push('supplier_name is required and must be a string');
  if (Number.isNaN(parseNumber(total_amount))) errors.push('total_amount must be a number');
  if (status !== undefined && typeof status !== 'string') errors.push('status must be a string');
  if (items !== undefined && !Array.isArray(items)) errors.push('items must be an array');

  if (Array.isArray(items)) {
    items.forEach((item, index) => {
      if (!item.product_id || typeof item.product_id !== 'string') errors.push(`items[${index}].product_id is required and must be a string`);
      if (Number.isNaN(parseNumber(item.quantity))) errors.push(`items[${index}].quantity must be a number`);
      if (Number.isNaN(parseNumber(item.unit_price ?? item.price))) errors.push(`items[${index}].unit_price must be a number`);
      if (Number.isNaN(parseNumber(item.total_amount))) errors.push(`items[${index}].total_amount must be a number`);
    });
  }

  if (errors.length) return respondBadRequest(res, errors);

  const client = await pool.connect();
  try {
    await client.query('BEGIN');

    const procurementResult = await client.query(
      `INSERT INTO procurements (business_id, supplier_name, total_amount, status)
       VALUES ($1, $2, $3, $4)
       RETURNING *`,
      [business_id, supplier_name, parseNumber(total_amount) ?? 0, status || 'pending'],
    );

    const procurement = procurementResult.rows[0];
    const insertedItems = [];

    if (Array.isArray(items)) {
      for (const item of items) {
        const itemResult = await client.query(
          `INSERT INTO procurement_items (procurement_id, product_id, quantity, unit_price, total_amount)
           VALUES ($1, $2, $3, $4, $5)
           RETURNING *`,
          [
            procurement.id,
            item.product_id,
            parseNumber(item.quantity) ?? 0,
            parseNumber(item.unit_price ?? item.price) ?? 0,
            parseNumber(item.total_amount) ?? 0,
          ],
        );
        insertedItems.push(itemResult.rows[0]);
      }
    }

    await client.query('COMMIT');
    res.status(201).json({ ...procurement, items: insertedItems });
  } catch (error) {
    await client.query('ROLLBACK');
    res.status(500).json({ error: error.message });
  } finally {
    client.release();
  }
});

app.put('/products/:id', async (req, res) => {
  const { id } = req.params;
  const { business_id, name, category, sku, barcode, price, cost, quantity, unit, is_ingredient } = req.body;
  const errors = [];

  if (!name || typeof name !== 'string') errors.push('name is required and must be a string');
  if (price !== undefined && Number.isNaN(parseNumber(price))) errors.push('price must be a number');
  if (cost !== undefined && Number.isNaN(parseNumber(cost))) errors.push('cost must be a number');
  if (quantity !== undefined && Number.isNaN(parseNumber(quantity))) errors.push('quantity must be a number');
  if (is_ingredient !== undefined && typeof is_ingredient !== 'boolean' && is_ingredient !== 'true' && is_ingredient !== 'false') {
    errors.push('is_ingredient must be a boolean');
  }

  if (errors.length) return respondBadRequest(res, errors);

  try {
    const result = await pool.query(
      `UPDATE products SET business_id = $1, name = $2, category = $3, sku = $4, barcode = $5, price = $6, cost = $7, quantity = $8, unit = $9, is_ingredient = $10, updated_at = NOW()
       WHERE id = $11 RETURNING *`,
      [business_id || null, name, category || null, sku || null, barcode || null, parseNumber(price) ?? 0, parseNumber(cost) ?? 0, parseNumber(quantity) ?? 0, unit || null, is_ingredient === true || is_ingredient === 'true', id],
    );
    if (!result.rowCount) return res.status(404).json({ error: 'product not found' });
    res.json(result.rows[0]);
  } catch (error) {
    res.status(500).json({ error: error.message });
  }
});

app.delete('/products/:id', async (req, res) => {
  try {
    const result = await pool.query('DELETE FROM products WHERE id = $1 RETURNING *', [req.params.id]);
    if (!result.rowCount) return res.status(404).json({ error: 'product not found' });
    res.status(204).send();
  } catch (error) {
    res.status(500).json({ error: error.message });
  }
});

app.put('/businesses/:id', async (req, res) => {
  const { id } = req.params;
  const { name, business_type } = req.body;
  const errors = [];

  if (!name || typeof name !== 'string') errors.push('name is required and must be a string');
  if (business_type !== undefined && typeof business_type !== 'string') errors.push('business_type must be a string');

  if (errors.length) return respondBadRequest(res, errors);

  try {
    const result = await pool.query(
      `UPDATE businesses SET name = $1, business_type = $2, updated_at = NOW()
       WHERE id = $3 RETURNING *`,
      [name, business_type || null, id],
    );
    if (!result.rowCount) return res.status(404).json({ error: 'business not found' });
    res.json(result.rows[0]);
  } catch (error) {
    res.status(500).json({ error: error.message });
  }
});

app.delete('/businesses/:id', async (req, res) => {
  try {
    const result = await pool.query('DELETE FROM businesses WHERE id = $1 RETURNING *', [req.params.id]);
    if (!result.rowCount) return res.status(404).json({ error: 'business not found' });
    res.status(204).send();
  } catch (error) {
    res.status(500).json({ error: error.message });
  }
});

app.put('/users/:id', async (req, res) => {
  const { id } = req.params;
  const { business_id, email, full_name, role } = req.body;
  const errors = [];

  if (!business_id || typeof business_id !== 'string') errors.push('business_id is required and must be a string');
  if (!email || typeof email !== 'string' || !validateEmail(email)) errors.push('email is required and must be valid');
  if (full_name !== undefined && typeof full_name !== 'string') errors.push('full_name must be a string');
  if (role !== undefined && typeof role !== 'string') errors.push('role must be a string');

  if (errors.length) return respondBadRequest(res, errors);

  try {
    const result = await pool.query(
      `UPDATE users SET business_id = $1, email = $2, full_name = $3, role = $4, updated_at = NOW()
       WHERE id = $5 RETURNING *`,
      [business_id, email, full_name || null, role || null, id],
    );
    if (!result.rowCount) return res.status(404).json({ error: 'user not found' });
    res.json(result.rows[0]);
  } catch (error) {
    res.status(500).json({ error: error.message });
  }
});

app.delete('/users/:id', async (req, res) => {
  try {
    const result = await pool.query('DELETE FROM users WHERE id = $1 RETURNING *', [req.params.id]);
    if (!result.rowCount) return res.status(404).json({ error: 'user not found' });
    res.status(204).send();
  } catch (error) {
    res.status(500).json({ error: error.message });
  }
});

app.put('/sales/:id', async (req, res) => {
  const { id } = req.params;
  const { business_id, customer_name, total_amount, payment_method, status } = req.body;
  const errors = [];

  if (!business_id || typeof business_id !== 'string') errors.push('business_id is required and must be a string');
  if (customer_name !== undefined && typeof customer_name !== 'string') errors.push('customer_name must be a string');
  if (Number.isNaN(parseNumber(total_amount))) errors.push('total_amount must be a number');
  if (payment_method !== undefined && typeof payment_method !== 'string') errors.push('payment_method must be a string');
  if (status !== undefined && typeof status !== 'string') errors.push('status must be a string');

  if (errors.length) return respondBadRequest(res, errors);

  try {
    const result = await pool.query(
      `UPDATE sales SET business_id = $1, customer_name = $2, total_amount = $3, payment_method = $4, status = $5, updated_at = NOW()
       WHERE id = $6 RETURNING *`,
      [business_id, customer_name || null, parseNumber(total_amount) ?? 0, payment_method || null, status || 'completed', id],
    );
    if (!result.rowCount) return res.status(404).json({ error: 'sale not found' });
    res.json(result.rows[0]);
  } catch (error) {
    res.status(500).json({ error: error.message });
  }
});

app.delete('/sales/:id', async (req, res) => {
  const client = await pool.connect();
  try {
    await client.query('BEGIN');
    await client.query('DELETE FROM sale_items WHERE sale_id = $1', [req.params.id]);
    const result = await client.query('DELETE FROM sales WHERE id = $1 RETURNING *', [req.params.id]);
    if (!result.rowCount) {
      await client.query('ROLLBACK');
      return res.status(404).json({ error: 'sale not found' });
    }
    await client.query('COMMIT');
    res.status(204).send();
  } catch (error) {
    await client.query('ROLLBACK');
    res.status(500).json({ error: error.message });
  } finally {
    client.release();
  }
});

app.put('/procurements/:id', async (req, res) => {
  const { id } = req.params;
  const { business_id, supplier_name, total_amount, status } = req.body;
  const errors = [];

  if (!business_id || typeof business_id !== 'string') errors.push('business_id is required and must be a string');
  if (!supplier_name || typeof supplier_name !== 'string') errors.push('supplier_name is required and must be a string');
  if (Number.isNaN(parseNumber(total_amount))) errors.push('total_amount must be a number');
  if (status !== undefined && typeof status !== 'string') errors.push('status must be a string');

  if (errors.length) return respondBadRequest(res, errors);

  try {
    const result = await pool.query(
      `UPDATE procurements SET business_id = $1, supplier_name = $2, total_amount = $3, status = $4, updated_at = NOW()
       WHERE id = $5 RETURNING *`,
      [business_id, supplier_name, parseNumber(total_amount) ?? 0, status || 'pending', id],
    );
    if (!result.rowCount) return res.status(404).json({ error: 'procurement not found' });
    res.json(result.rows[0]);
  } catch (error) {
    res.status(500).json({ error: error.message });
  }
});

app.delete('/procurements/:id', async (req, res) => {
  const client = await pool.connect();
  try {
    await client.query('BEGIN');
    await client.query('DELETE FROM procurement_items WHERE procurement_id = $1', [req.params.id]);
    const result = await client.query('DELETE FROM procurements WHERE id = $1 RETURNING *', [req.params.id]);
    if (!result.rowCount) {
      await client.query('ROLLBACK');
      return res.status(404).json({ error: 'procurement not found' });
    }
    await client.query('COMMIT');
    res.status(204).send();
  } catch (error) {
    await client.query('ROLLBACK');
    res.status(500).json({ error: error.message });
  } finally {
    client.release();
  }
});

app.patch('/products/:id', async (req, res) => {
  const { id } = req.params;
  const { business_id, name, category, sku, barcode, price, cost, quantity, unit, is_ingredient } = req.body;
  const errors = [];
  const fields = {};

  if (business_id !== undefined) {
    if (typeof business_id !== 'string') errors.push('business_id must be a string');
    else fields.business_id = business_id;
  }
  if (name !== undefined) {
    if (!name || typeof name !== 'string') errors.push('name must be a non-empty string');
    else fields.name = name;
  }
  if (category !== undefined) {
    if (category !== null && typeof category !== 'string') errors.push('category must be a string');
    else fields.category = category;
  }
  if (sku !== undefined) {
    if (sku !== null && typeof sku !== 'string') errors.push('sku must be a string');
    else fields.sku = sku;
  }
  if (barcode !== undefined) {
    if (barcode !== null && typeof barcode !== 'string') errors.push('barcode must be a string');
    else fields.barcode = barcode;
  }
  if (price !== undefined) {
    if (Number.isNaN(parseNumber(price))) errors.push('price must be a number');
    else fields.price = parseNumber(price);
  }
  if (cost !== undefined) {
    if (Number.isNaN(parseNumber(cost))) errors.push('cost must be a number');
    else fields.cost = parseNumber(cost);
  }
  if (quantity !== undefined) {
    if (Number.isNaN(parseNumber(quantity))) errors.push('quantity must be a number');
    else fields.quantity = parseNumber(quantity);
  }
  if (unit !== undefined) {
    if (unit !== null && typeof unit !== 'string') errors.push('unit must be a string');
    else fields.unit = unit;
  }
  if (is_ingredient !== undefined) {
    if (typeof is_ingredient !== 'boolean' && is_ingredient !== 'true' && is_ingredient !== 'false') {
      errors.push('is_ingredient must be a boolean');
    } else {
      fields.is_ingredient = is_ingredient === true || is_ingredient === 'true';
    }
  }

  if (errors.length) return respondBadRequest(res, errors);
  if (!Object.keys(fields).length) return respondBadRequest(res, ['No fields provided to update']);

  try {
    const update = buildUpdateQuery('products', id, fields);
    const result = await pool.query(update.query, update.values);
    if (!result.rowCount) return res.status(404).json({ error: 'product not found' });
    res.json(result.rows[0]);
  } catch (error) {
    res.status(500).json({ error: error.message });
  }
});

app.patch('/businesses/:id', async (req, res) => {
  const { id } = req.params;
  const { name, business_type } = req.body;
  const errors = [];
  const fields = {};

  if (name !== undefined) {
    if (!name || typeof name !== 'string') errors.push('name must be a non-empty string');
    else fields.name = name;
  }
  if (business_type !== undefined) {
    if (business_type !== null && typeof business_type !== 'string') errors.push('business_type must be a string');
    else fields.business_type = business_type;
  }

  if (errors.length) return respondBadRequest(res, errors);
  if (!Object.keys(fields).length) return respondBadRequest(res, ['No fields provided to update']);

  try {
    const update = buildUpdateQuery('businesses', id, fields);
    const result = await pool.query(update.query, update.values);
    if (!result.rowCount) return res.status(404).json({ error: 'business not found' });
    res.json(result.rows[0]);
  } catch (error) {
    res.status(500).json({ error: error.message });
  }
});

app.patch('/users/:id', async (req, res) => {
  const { id } = req.params;
  const { business_id, email, full_name, role } = req.body;
  const errors = [];
  const fields = {};

  if (business_id !== undefined) {
    if (typeof business_id !== 'string') errors.push('business_id must be a string');
    else fields.business_id = business_id;
  }
  if (email !== undefined) {
    if (!email || typeof email !== 'string' || !validateEmail(email)) errors.push('email must be valid');
    else fields.email = email;
  }
  if (full_name !== undefined) {
    if (full_name !== null && typeof full_name !== 'string') errors.push('full_name must be a string');
    else fields.full_name = full_name;
  }
  if (role !== undefined) {
    if (role !== null && typeof role !== 'string') errors.push('role must be a string');
    else fields.role = role;
  }

  if (errors.length) return respondBadRequest(res, errors);
  if (!Object.keys(fields).length) return respondBadRequest(res, ['No fields provided to update']);

  try {
    const update = buildUpdateQuery('users', id, fields);
    const result = await pool.query(update.query, update.values);
    if (!result.rowCount) return res.status(404).json({ error: 'user not found' });
    res.json(result.rows[0]);
  } catch (error) {
    res.status(500).json({ error: error.message });
  }
});

app.patch('/sales/:id', async (req, res) => {
  const { id } = req.params;
  const { business_id, customer_name, total_amount, payment_method, status } = req.body;
  const errors = [];
  const fields = {};

  if (business_id !== undefined) {
    if (typeof business_id !== 'string') errors.push('business_id must be a string');
    else fields.business_id = business_id;
  }
  if (customer_name !== undefined) {
    if (customer_name !== null && typeof customer_name !== 'string') errors.push('customer_name must be a string');
    else fields.customer_name = customer_name;
  }
  if (total_amount !== undefined) {
    if (Number.isNaN(parseNumber(total_amount))) errors.push('total_amount must be a number');
    else fields.total_amount = parseNumber(total_amount);
  }
  if (payment_method !== undefined) {
    if (payment_method !== null && typeof payment_method !== 'string') errors.push('payment_method must be a string');
    else fields.payment_method = payment_method;
  }
  if (status !== undefined) {
    if (status !== null && typeof status !== 'string') errors.push('status must be a string');
    else fields.status = status;
  }

  if (errors.length) return respondBadRequest(res, errors);
  if (!Object.keys(fields).length) return respondBadRequest(res, ['No fields provided to update']);

  try {
    const update = buildUpdateQuery('sales', id, fields);
    const result = await pool.query(update.query, update.values);
    if (!result.rowCount) return res.status(404).json({ error: 'sale not found' });
    res.json(result.rows[0]);
  } catch (error) {
    res.status(500).json({ error: error.message });
  }
});

app.patch('/procurements/:id', async (req, res) => {
  const { id } = req.params;
  const { business_id, supplier_name, total_amount, status } = req.body;
  const errors = [];
  const fields = {};

  if (business_id !== undefined) {
    if (typeof business_id !== 'string') errors.push('business_id must be a string');
    else fields.business_id = business_id;
  }
  if (supplier_name !== undefined) {
    if (!supplier_name || typeof supplier_name !== 'string') errors.push('supplier_name must be a non-empty string');
    else fields.supplier_name = supplier_name;
  }
  if (total_amount !== undefined) {
    if (Number.isNaN(parseNumber(total_amount))) errors.push('total_amount must be a number');
    else fields.total_amount = parseNumber(total_amount);
  }
  if (status !== undefined) {
    if (status !== null && typeof status !== 'string') errors.push('status must be a string');
    else fields.status = status;
  }

  if (errors.length) return respondBadRequest(res, errors);
  if (!Object.keys(fields).length) return respondBadRequest(res, ['No fields provided to update']);

  try {
    const update = buildUpdateQuery('procurements', id, fields);
    const result = await pool.query(update.query, update.values);
    if (!result.rowCount) return res.status(404).json({ error: 'procurement not found' });
    res.json(result.rows[0]);
  } catch (error) {
    res.status(500).json({ error: error.message });
  }
});

app.listen(port, () => {
  console.log(`ManageCare PostgreSQL API listening on port ${port}`);
});
