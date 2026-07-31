/**
 * Draft sales-invoice routes for ManageCare.
 */
const express = require('express');
const router = express.Router();
const { requireFields, asyncHandler } = require('../middleware/validation');
const { requireBusinessMembership } = require('../middleware/auth');

module.exports = function(pool) {
  router.use('/:businessId', requireBusinessMembership(pool));

  router.get('/:businessId', asyncHandler(async (req, res) => {
    const result = await pool.query(
      'SELECT * FROM invoices WHERE business_id = $1 ORDER BY created_at DESC LIMIT 200',
      [req.params.businessId]
    );
    res.json({ data: result.rows });
  }));

  router.post('/:businessId', requireFields('invoiceNumber'), asyncHandler(async (req, res) => {
    const { businessId } = req.params;
    const {
      invoiceNumber, status, source, customerId, customerName, customerEmail,
      customerPhone, items, subtotal, tax, discount, total, createdBy, createdByName,
    } = req.body;

    const result = await pool.query(
      `INSERT INTO invoices (
         business_id, invoice_number, status, source, customer_id, customer_name,
         customer_email, customer_phone, items, subtotal, tax, discount, total,
         created_by, created_by_name
       ) VALUES ($1, $2, $3, $4, $5, $6, $7, $8, COALESCE($9::jsonb, '[]'::jsonb), $10, $11, $12, $13, $14, $15)
       RETURNING *`,
      [
        businessId, invoiceNumber, status || 'draft', source || null, customerId || null,
        customerName || null, customerEmail || null, customerPhone || null,
        items ? JSON.stringify(items) : null, subtotal || 0, tax || 0, discount || 0, total || 0,
        createdBy || null, createdByName || null,
      ]
    );
    res.status(201).json(result.rows[0]);
  }));

  return router;
};
