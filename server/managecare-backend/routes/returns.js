/**
 * Returns/refunds API routes for ManageCare.
 */
const express = require('express');
const router = express.Router();
const { requireFields, pagination, asyncHandler } = require('../middleware/validation');
const { requireBusinessMembership } = require('../middleware/auth');

module.exports = function(pool) {
  router.use('/:businessId', requireBusinessMembership(pool));

  // GET /api/returns/:businessId - List returns (optional filter by saleId)
  router.get('/:businessId', pagination, asyncHandler(async (req, res) => {
    const { businessId } = req.params;
    const { saleId } = req.query;
    const { limit, offset } = req.pagination;

    let query = 'SELECT * FROM returns WHERE business_id = $1';
    const params = [businessId];
    if (saleId) {
      query += ' AND sale_id = $2';
      params.push(saleId);
    }
    query += ` ORDER BY created_at DESC LIMIT $${params.length + 1} OFFSET $${params.length + 2}`;
    params.push(limit, offset);

    const result = await pool.query(query, params);
    res.json({ data: result.rows });
  }));

  // POST /api/returns/:businessId - Process a return/refund.
  // Atomically: records the return, increments the sale's running
  // return_amount and per-item returned_quantities, and flips the sale's
  // status to 'refunded' once the total returned covers the sale total (or
  // 'partially_refunded' otherwise) - so Sales History's status filters
  // stay accurate across multiple partial returns on the same sale.
  router.post('/:businessId', requireFields('sale_id', 'refund_amount'), asyncHandler(async (req, res) => {
    const { businessId } = req.params;
    const {
      sale_id, reason, refund_method, refund_amount, exclude_from_totals,
      items_returned, processed_by_id, processed_by_name,
      entered_by_id, entered_by_name, entered_by_email, entered_by_role,
      sale_reference, sold_by_id, sold_by_name, customer_id, customer_name,
    } = req.body;

    const client = await pool.connect();
    try {
      await client.query('BEGIN');

      const saleResult = await client.query(
        'SELECT * FROM sales WHERE id = $1 AND business_id = $2 FOR UPDATE',
        [sale_id, businessId]
      );
      if (saleResult.rows.length === 0) {
        await client.query('ROLLBACK');
        return res.status(404).json({ error: 'Sale not found' });
      }
      const sale = saleResult.rows[0];

      const newReturnAmount = parseFloat(sale.return_amount || 0) + parseFloat(refund_amount);
      const saleTotal = parseFloat(sale.final_amount || 0);
      const status = saleTotal <= 0 || newReturnAmount >= saleTotal - 0.01
        ? 'refunded'
        : 'partially_refunded';

      const returnedQuantities = { ...(sale.returned_quantities || {}) };
      const items = Array.isArray(items_returned) ? items_returned : [];
      for (const item of items) {
        const productId = item && item.productId;
        const qty = Number(item && item.quantity) || 0;
        if (!productId || qty <= 0) continue;
        returnedQuantities[productId] = (Number(returnedQuantities[productId]) || 0) + qty;
      }

      const updatedSale = await client.query(
        `UPDATE sales SET
           return_amount = $1,
           returned_quantities = $2,
           has_return = true,
           status = $3,
           updated_at = NOW()
         WHERE id = $4 AND business_id = $5
         RETURNING *`,
        [newReturnAmount, JSON.stringify(returnedQuantities), status, sale_id, businessId]
      );

      const returnResult = await client.query(
        `INSERT INTO returns (
           business_id, sale_id, reason, refund_method, refund_amount, exclude_from_totals,
           items_returned, processed_by_id, processed_by_name,
           entered_by_id, entered_by_name, entered_by_email, entered_by_role,
           sale_reference, sold_by_id, sold_by_name, customer_id, customer_name
         ) VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11, $12, $13, $14, $15, $16, $17, $18)
         RETURNING *`,
        [
          businessId, sale_id, reason || null, refund_method || null, refund_amount, exclude_from_totals === true,
          JSON.stringify(items), processed_by_id || null, processed_by_name || null,
          entered_by_id || null, entered_by_name || null, entered_by_email || null, entered_by_role || null,
          sale_reference || null, sold_by_id || null, sold_by_name || null, customer_id || null, customer_name || null,
        ]
      );

      await client.query('COMMIT');
      res.status(201).json({ return: returnResult.rows[0], sale: updatedSale.rows[0] });
    } catch (err) {
      await client.query('ROLLBACK');
      throw err;
    } finally {
      client.release();
    }
  }));

  return router;
};
