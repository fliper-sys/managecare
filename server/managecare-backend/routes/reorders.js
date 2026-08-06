/**
 * Reorder tracking API routes for ManageCare.
 */
const express = require('express');
const router = express.Router();
const { requireFields, asyncHandler } = require('../middleware/validation');
const { requireBusinessMembership } = require('../middleware/auth');

module.exports = function(pool) {
  router.use('/:businessId', requireBusinessMembership(pool));

  // GET /api/reorders/:businessId - List reorders (optionally filter by status)
  router.get('/:businessId', asyncHandler(async (req, res) => {
    const { businessId } = req.params;
    const { status } = req.query;

    let query = 'SELECT * FROM reorders WHERE business_id = $1';
    const params = [businessId];
    if (status) {
      query += ' AND status = $2';
      params.push(status);
    }
    query += ' ORDER BY created_at DESC';

    const result = await pool.query(query, params);
    res.json({ data: result.rows });
  }));

  // POST /api/reorders/:businessId - Create a reorder
  router.post('/:businessId', requireFields('product_id', 'product_name', 'quantity'), asyncHandler(async (req, res) => {
    const { businessId } = req.params;
    const { product_id, product_name, quantity, source } = req.body;

    const result = await pool.query(
      `INSERT INTO reorders (business_id, product_id, product_name, quantity, source)
       VALUES ($1, $2, $3, $4, $5) RETURNING *`,
      [businessId, product_id, product_name, quantity, source || 'alert']
    );

    res.status(201).json(result.rows[0]);
  }));

  // PATCH /api/reorders/:businessId/:id/receive - Mark a reorder as received
  router.patch('/:businessId/:id/receive', asyncHandler(async (req, res) => {
    const { businessId, id } = req.params;

    const result = await pool.query(
      `UPDATE reorders SET status = 'received', updated_at = NOW()
       WHERE id = $1 AND business_id = $2 RETURNING *`,
      [id, businessId]
    );
    if (result.rows.length === 0) {
      return res.status(404).json({ error: 'Reorder not found' });
    }
    res.json(result.rows[0]);
  }));

  return router;
};
