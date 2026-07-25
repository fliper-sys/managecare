/**
 * Expenses API routes for ManageCare.
 */
const express = require('express');
const router = express.Router();
const { requireFields, pagination, asyncHandler } = require('../middleware/validation');

module.exports = function(pool) {

  // GET /api/expenses/:businessId - List expenses
  router.get('/:businessId', pagination, asyncHandler(async (req, res) => {
    const { businessId } = req.params;
    const { limit, offset } = req.pagination;
    const { category, startDate, endDate } = req.query;

    let query = 'SELECT * FROM expenses WHERE business_id = $1';
    const params = [businessId];
    let paramIndex = 2;

    if (category) {
      query += ` AND category = $${paramIndex++}`;
      params.push(category);
    }
    if (startDate) {
      query += ` AND created_at >= $${paramIndex++}`;
      params.push(startDate);
    }
    if (endDate) {
      query += ` AND created_at <= $${paramIndex++}`;
      params.push(endDate);
    }

    const countResult = await pool.query(
      query.replace('SELECT *', 'SELECT COUNT(*)'), params
    );
    const total = parseInt(countResult.rows[0].count);

    query += ` ORDER BY created_at DESC LIMIT $${paramIndex++} OFFSET $${paramIndex}`;
    params.push(limit, offset);

    const result = await pool.query(query, params);
    res.json({
      data: result.rows,
      pagination: { page: req.pagination.page, limit, total, totalPages: Math.ceil(total / limit) },
    });
  }));

  // GET /api/expenses/:businessId/summary - Expense summary
  router.get('/:businessId/summary', asyncHandler(async (req, res) => {
    const { businessId } = req.params;
    const { period } = req.query;

    let dateFilter;
    if (period === 'today') {
      dateFilter = "created_at >= CURRENT_DATE AND created_at < CURRENT_DATE + INTERVAL '1 day'";
    } else if (period === 'week') {
      dateFilter = "created_at >= date_trunc('week', CURRENT_DATE)";
    } else if (period === 'month') {
      dateFilter = "created_at >= date_trunc('month', CURRENT_DATE)";
    } else {
      dateFilter = "created_at >= date_trunc('month', CURRENT_DATE)";
    }

    const result = await pool.query(`
      SELECT
        COUNT(*)::INTEGER as total_expenses,
        COALESCE(SUM(amount), 0)::DECIMAL(12,2) as total_amount,
        JSONB_OBJECT_AGG(category, cat.total) as category_breakdown
      FROM expenses e
      LEFT JOIN (
        SELECT category, SUM(amount)::DECIMAL(12,2) as total
        FROM expenses WHERE business_id = $1 AND ${dateFilter}
        GROUP BY category
      ) cat ON cat.category = e.category
      WHERE e.business_id = $1 AND ${dateFilter}
      GROUP BY e.business_id
    `, [businessId]);

    if (result.rows.length === 0) {
      return res.json({ total_expenses: 0, total_amount: 0, category_breakdown: {} });
    }
    res.json(result.rows[0]);
  }));

  // POST /api/expenses/:businessId - Create expense
  router.post('/:businessId', requireFields('category', 'amount'), asyncHandler(async (req, res) => {
    const { businessId } = req.params;
    const { category, amount, description, paid_by, created_by } = req.body;

    const result = await pool.query(
      `INSERT INTO expenses (business_id, category, amount, description, paid_by, created_by)
       VALUES ($1, $2, $3, $4, $5, $6) RETURNING *`,
      [businessId, category, amount, description || null, paid_by || null, created_by || null]
    );
    res.status(201).json(result.rows[0]);
  }));

  // DELETE /api/expenses/:businessId/:id
  router.delete('/:businessId/:id', asyncHandler(async (req, res) => {
    const { businessId, id } = req.params;
    const result = await pool.query(
      'DELETE FROM expenses WHERE id = $1 AND business_id = $2 RETURNING *',
      [id, businessId]
    );
    if (result.rows.length === 0) {
      return res.status(404).json({ error: 'Expense not found' });
    }
    res.json({ message: 'Expense deleted', id });
  }));

  return router;
};

