/**
 * Drink/Bar vertical API routes for ManageCare.
 *
 * Drinks themselves are just inventory items (use the existing
 * /api/inventory routes). This file covers what's genuinely bar-specific:
 * saved bar table labels, draft orders, and invoices/tabs.
 */
const express = require('express');
const router = express.Router();
const { requireFields, asyncHandler } = require('../middleware/validation');
const { requireBusinessMembership } = require('../middleware/auth');

module.exports = function(pool) {
  router.use('/:businessId', requireBusinessMembership(pool));

  // ---------- Bar tables ----------

  router.get('/:businessId/bar-tables', asyncHandler(async (req, res) => {
    const result = await pool.query(
      'SELECT * FROM bar_tables WHERE business_id = $1 ORDER BY label ASC',
      [req.params.businessId]
    );
    res.json({ data: result.rows });
  }));

  router.post('/:businessId/bar-tables', requireFields('label'), asyncHandler(async (req, res) => {
    const { businessId } = req.params;
    const { label } = req.body;
    const result = await pool.query(
      `INSERT INTO bar_tables (business_id, label)
       VALUES ($1, $2)
       ON CONFLICT (business_id, label) DO UPDATE SET updated_at = NOW()
       RETURNING *`,
      [businessId, label]
    );
    res.status(201).json(result.rows[0]);
  }));

  router.delete('/:businessId/bar-tables/:label', asyncHandler(async (req, res) => {
    const { businessId, label } = req.params;
    await pool.query(
      'DELETE FROM bar_tables WHERE business_id = $1 AND label = $2',
      [businessId, label]
    );
    res.json({ message: 'Bar table deleted', label });
  }));

  // ---------- Orders (draft/pre-payment) ----------

  router.get('/:businessId/orders', asyncHandler(async (req, res) => {
    const result = await pool.query(
      'SELECT * FROM drink_orders WHERE business_id = $1 ORDER BY created_at DESC',
      [req.params.businessId]
    );
    res.json({ data: result.rows });
  }));

  router.post('/:businessId/orders', asyncHandler(async (req, res) => {
    const { businessId } = req.params;
    const { id, status, lines, total } = req.body;
    const result = await pool.query(
      `INSERT INTO drink_orders (id, business_id, status, lines, total)
       VALUES (COALESCE($1::uuid, uuid_generate_v4()), $2, $3, $4, $5)
       ON CONFLICT (id) DO UPDATE SET
         status = EXCLUDED.status, lines = EXCLUDED.lines, total = EXCLUDED.total, updated_at = NOW()
       RETURNING *`,
      [id || null, businessId, status || 'pending', JSON.stringify(lines || []), total || 0]
    );
    res.status(201).json(result.rows[0]);
  }));

  router.put('/:businessId/orders/:id', asyncHandler(async (req, res) => {
    const { businessId, id } = req.params;
    const { status, lines, total } = req.body;

    const fields = [];
    const params = [];
    let paramIndex = 1;
    if (status !== undefined) { fields.push(`status = $${paramIndex++}`); params.push(status); }
    if (lines !== undefined) { fields.push(`lines = $${paramIndex++}`); params.push(JSON.stringify(lines)); }
    if (total !== undefined) { fields.push(`total = $${paramIndex++}`); params.push(total); }

    if (fields.length === 0) {
      return res.status(400).json({ error: 'No fields to update' });
    }
    fields.push('updated_at = NOW()');
    params.push(id, businessId);

    const result = await pool.query(
      `UPDATE drink_orders SET ${fields.join(', ')} WHERE id = $${paramIndex++} AND business_id = $${paramIndex} RETURNING *`,
      params
    );
    if (result.rows.length === 0) {
      return res.status(404).json({ error: 'Order not found' });
    }
    res.json(result.rows[0]);
  }));

  // ---------- Invoices (open tabs / tables, converted to a sale on payment) ----------

  router.get('/:businessId/invoices', asyncHandler(async (req, res) => {
    const result = await pool.query(
      'SELECT * FROM bar_invoices WHERE business_id = $1 ORDER BY created_at DESC',
      [req.params.businessId]
    );
    res.json({ data: result.rows });
  }));

  router.post('/:businessId/invoices', requireFields('invoice_number'), asyncHandler(async (req, res) => {
    const { businessId } = req.params;
    const {
      id, invoice_number, invoice_type, status, customer_id, customer_name, customer_phone,
      customer_email, table_label, notes, lines, subtotal, tax, discount, total,
      converted_at, linked_sale_id, payment_method, worker_id, worker_name, store_id,
    } = req.body;

    const result = await pool.query(
      `INSERT INTO bar_invoices (
         id, business_id, invoice_number, invoice_type, status, customer_id, customer_name, customer_phone,
         customer_email, table_label, notes, lines, subtotal, tax, discount, total,
         converted_at, linked_sale_id, payment_method, worker_id, worker_name, store_id
       ) VALUES (
         COALESCE($1::uuid, uuid_generate_v4()), $2, $3, $4, $5, $6, $7, $8,
         $9, $10, $11, $12, $13, $14, $15, $16,
         $17, $18, $19, $20, $21, $22
       )
       ON CONFLICT (id) DO UPDATE SET
         invoice_type = EXCLUDED.invoice_type, status = EXCLUDED.status, customer_id = EXCLUDED.customer_id,
         customer_name = EXCLUDED.customer_name, customer_phone = EXCLUDED.customer_phone,
         customer_email = EXCLUDED.customer_email, table_label = EXCLUDED.table_label, notes = EXCLUDED.notes,
         lines = EXCLUDED.lines, subtotal = EXCLUDED.subtotal, tax = EXCLUDED.tax, discount = EXCLUDED.discount,
         total = EXCLUDED.total, converted_at = EXCLUDED.converted_at, linked_sale_id = EXCLUDED.linked_sale_id,
         payment_method = EXCLUDED.payment_method, worker_id = EXCLUDED.worker_id, worker_name = EXCLUDED.worker_name,
         store_id = EXCLUDED.store_id, updated_at = NOW()
       RETURNING *`,
      [
        id || null, businessId, invoice_number, invoice_type || 'invoice', status || 'open',
        customer_id || null, customer_name || null, customer_phone || null, customer_email || null,
        table_label || null, notes || null, JSON.stringify(lines || []), subtotal || 0, tax || 0,
        discount || 0, total || 0, converted_at || null, linked_sale_id || null, payment_method || null,
        worker_id || null, worker_name || null, store_id || null,
      ]
    );
    res.status(201).json(result.rows[0]);
  }));

  return router;
};
