/**
 * Workers API routes for ManageCare.
 */
const express = require('express');
const router = express.Router();
const { requireFields, pagination, asyncHandler } = require('../middleware/validation');

module.exports = function(pool) {

  // GET /api/workers/:businessId - List workers
  router.get('/:businessId', pagination, asyncHandler(async (req, res) => {
    const { businessId } = req.params;
    const { limit, offset } = req.pagination;
    const { search, isActive } = req.query;

    let query = 'SELECT * FROM workers WHERE business_id = $1';
    const params = [businessId];
    let paramIndex = 2;

    if (search) {
      query += ` AND (full_name ILIKE $${paramIndex} OR email ILIKE $${paramIndex} OR phone ILIKE $${paramIndex})`;
      params.push(`%${search}%`);
      paramIndex++;
    }
    if (isActive === 'true') {
      query += ' AND is_active = true';
    }

    const countResult = await pool.query(
      query.replace('SELECT *', 'SELECT COUNT(*)'), params
    );
    const total = parseInt(countResult.rows[0].count);

    query += ` ORDER BY full_name ASC LIMIT $${paramIndex++} OFFSET $${paramIndex}`;
    params.push(limit, offset);

    const result = await pool.query(query, params);
    res.json({
      data: result.rows,
      pagination: { page: req.pagination.page, limit, total, totalPages: Math.ceil(total / limit) },
    });
  }));

  // GET /api/workers/:businessId/:id - Get single worker
  router.get('/:businessId/:id', asyncHandler(async (req, res) => {
    const { businessId, id } = req.params;
    const result = await pool.query(
      'SELECT * FROM workers WHERE id = $1 AND business_id = $2',
      [id, businessId]
    );
    if (result.rows.length === 0) {
      return res.status(404).json({ error: 'Worker not found' });
    }
    res.json(result.rows[0]);
  }));

  // POST /api/workers/:businessId - Create worker
  router.post('/:businessId', requireFields('full_name', 'role'), asyncHandler(async (req, res) => {
    const { businessId } = req.params;
    const { email, full_name, phone, role, store_id, permissions, pin } = req.body;

    const result = await pool.query(
      `INSERT INTO workers (email, full_name, phone, role, business_id, store_id, permissions, pin)
       VALUES ($1, $2, $3, $4, $5, $6, $7, $8) RETURNING *`,
      [email || null, full_name, phone || null, role, businessId,
       store_id || null, JSON.stringify(permissions || {}), pin || null]
    );
    res.status(201).json(result.rows[0]);
  }));

  // PUT /api/workers/:businessId/:id - Update worker
  router.put('/:businessId/:id', asyncHandler(async (req, res) => {
    const { businessId, id } = req.params;
    const { email, full_name, phone, role, store_id, permissions, pin, is_active } = req.body;

    const fields = [];
    const params = [];
    let paramIndex = 1;

    if (email !== undefined) { fields.push(`email = $${paramIndex++}`); params.push(email); }
    if (full_name !== undefined) { fields.push(`full_name = $${paramIndex++}`); params.push(full_name); }
    if (phone !== undefined) { fields.push(`phone = $${paramIndex++}`); params.push(phone); }
    if (role !== undefined) { fields.push(`role = $${paramIndex++}`); params.push(role); }
    if (store_id !== undefined) { fields.push(`store_id = $${paramIndex++}`); params.push(store_id); }
    if (permissions !== undefined) { fields.push(`permissions = $${paramIndex++}`); params.push(JSON.stringify(permissions)); }
    if (pin !== undefined) { fields.push(`pin = $${paramIndex++}`); params.push(pin); }
    if (is_active !== undefined) { fields.push(`is_active = $${paramIndex++}`); params.push(is_active); }

    if (fields.length === 0) {
      return res.status(400).json({ error: 'No fields to update' });
    }

    fields.push('updated_at = NOW()');
    params.push(id, businessId);

    const result = await pool.query(
      `UPDATE workers SET ${fields.join(', ')} WHERE id = $${paramIndex++} AND business_id = $${paramIndex} RETURNING *`,
      params
    );

    if (result.rows.length === 0) {
      return res.status(404).json({ error: 'Worker not found' });
    }
    res.json(result.rows[0]);
  }));

  // DELETE /api/workers/:businessId/:id - Delete worker
  router.delete('/:businessId/:id', asyncHandler(async (req, res) => {
    const { businessId, id } = req.params;
    const result = await pool.query(
      'DELETE FROM workers WHERE id = $1 AND business_id = $2 RETURNING *',
      [id, businessId]
    );
    if (result.rows.length === 0) {
      return res.status(404).json({ error: 'Worker not found' });
    }
    res.json({ message: 'Worker deleted', id });
  }));

  return router;
};

