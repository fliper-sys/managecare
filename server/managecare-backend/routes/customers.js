/**
 * Customers API routes for ManageCare.
 */
const express = require('express');
const router = express.Router();
const { requireFields, pagination, asyncHandler } = require('../middleware/validation');
const { requireBusinessMembership } = require('../middleware/auth');

module.exports = function(pool) {
  router.use('/:businessId', requireBusinessMembership(pool));

  // GET /api/customers/:businessId - List customers
  router.get('/:businessId', pagination, asyncHandler(async (req, res) => {
    const { businessId } = req.params;
    const { limit, offset } = req.pagination;
    const { search, isActive } = req.query;

    let query = 'SELECT * FROM customers WHERE business_id = $1';
    const params = [businessId];
    let paramIndex = 2;

    if (search) {
      query += ` AND (name ILIKE $${paramIndex} OR phone ILIKE $${paramIndex} OR email ILIKE $${paramIndex})`;
      params.push(`%${search}%`);
      paramIndex++;
    }
    if (isActive === 'true') {
      query += ' AND is_active = true';
    }

    const countResult = await pool.query(
      query.replace('SELECT *', 'SELECT COUNT(*)'),
      params
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

  // GET /api/customers/:businessId/top - Top customers by spend
  router.get('/:businessId/top', asyncHandler(async (req, res) => {
    const { businessId } = req.params;
    const limit = Math.min(50, parseInt(req.query.limit) || 10);
    const result = await pool.query(
      'SELECT * FROM customers WHERE business_id = $1 AND is_active = true ORDER BY total_spent DESC LIMIT $2',
      [businessId, limit]
    );
    res.json(result.rows);
  }));

  // GET /api/customers/:businessId/:id - Get single customer
  router.get('/:businessId/:id', asyncHandler(async (req, res) => {
    const { businessId, id } = req.params;
    const result = await pool.query(
      'SELECT * FROM customers WHERE id = $1 AND business_id = $2',
      [id, businessId]
    );
    if (result.rows.length === 0) {
      return res.status(404).json({ error: 'Customer not found' });
    }
    res.json(result.rows[0]);
  }));

  // POST /api/customers/:businessId - Create customer
  router.post('/:businessId', requireFields('name'), asyncHandler(async (req, res) => {
    const { businessId } = req.params;
    const { name, email, phone, address, city, state } = req.body;

    const result = await pool.query(
      `INSERT INTO customers (business_id, name, email, phone, address, city, state)
       VALUES ($1, $2, $3, $4, $5, $6, $7) RETURNING *`,
      [businessId, name, email || null, phone || null, address || null, city || null, state || null]
    );
    res.status(201).json(result.rows[0]);
  }));

  // PUT /api/customers/:businessId/:id - Update customer
  router.put('/:businessId/:id', asyncHandler(async (req, res) => {
    const { businessId, id } = req.params;
    const { name, email, phone, address, city, state, is_active } = req.body;

    const fields = [];
    const params = [];
    let paramIndex = 1;

    if (name !== undefined) { fields.push(`name = $${paramIndex++}`); params.push(name); }
    if (email !== undefined) { fields.push(`email = $${paramIndex++}`); params.push(email); }
    if (phone !== undefined) { fields.push(`phone = $${paramIndex++}`); params.push(phone); }
    if (address !== undefined) { fields.push(`address = $${paramIndex++}`); params.push(address); }
    if (city !== undefined) { fields.push(`city = $${paramIndex++}`); params.push(city); }
    if (state !== undefined) { fields.push(`state = $${paramIndex++}`); params.push(state); }
    if (is_active !== undefined) { fields.push(`is_active = $${paramIndex++}`); params.push(is_active); }

    if (fields.length === 0) {
      return res.status(400).json({ error: 'No fields to update' });
    }

    fields.push('updated_at = NOW()');
    params.push(id, businessId);

    const result = await pool.query(
      `UPDATE customers SET ${fields.join(', ')} WHERE id = $${paramIndex++} AND business_id = $${paramIndex} RETURNING *`,
      params
    );

    if (result.rows.length === 0) {
      return res.status(404).json({ error: 'Customer not found' });
    }
    res.json(result.rows[0]);
  }));

  // DELETE /api/customers/:businessId/:id - Soft delete
  router.delete('/:businessId/:id', asyncHandler(async (req, res) => {
    const { businessId, id } = req.params;
    const result = await pool.query(
      'UPDATE customers SET is_active = false, updated_at = NOW() WHERE id = $1 AND business_id = $2 RETURNING *',
      [id, businessId]
    );
    if (result.rows.length === 0) {
      return res.status(404).json({ error: 'Customer not found' });
    }
    res.json({ message: 'Customer deleted', id });
  }));

  return router;
};

