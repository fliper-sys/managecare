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
    const { search, isActive, startDate, endDate } = req.query;

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
    if (startDate) {
      query += ` AND first_purchase_date >= $${paramIndex++}`;
      params.push(startDate);
    }
    if (endDate) {
      query += ` AND first_purchase_date <= $${paramIndex++}`;
      params.push(endDate);
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
    const { name, email, phone, address, city, state, notes } = req.body;

    const result = await pool.query(
      `INSERT INTO customers (business_id, name, email, phone, address, city, state, notes)
       VALUES ($1, $2, $3, $4, $5, $6, $7, $8) RETURNING *`,
      [businessId, name, email || null, phone || null, address || null, city || null, state || null, notes || null]
    );
    res.status(201).json(result.rows[0]);
  }));

  // PUT /api/customers/:businessId/:id - Update customer
  router.put('/:businessId/:id', asyncHandler(async (req, res) => {
    const { businessId, id } = req.params;
    const { name, email, phone, address, city, state, is_active, notes } = req.body;

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
    if (notes !== undefined) { fields.push(`notes = $${paramIndex++}`); params.push(notes); }

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

  // PATCH /api/customers/:businessId/:id/purchase - Record a purchase.
  // Atomic server-side increment (avoids a read-then-write race between
  // concurrent POS terminals updating the same customer).
  router.patch('/:businessId/:id/purchase', requireFields('amount'), asyncHandler(async (req, res) => {
    const { businessId, id } = req.params;
    const amount = parseFloat(req.body.amount);
    if (!Number.isFinite(amount)) {
      return res.status(400).json({ error: 'amount must be a number' });
    }
    const { metadata } = req.body;

    const result = await pool.query(
      `UPDATE customers SET
         total_transactions = total_transactions + 1,
         total_spent = total_spent + $1,
         average_order_value = (total_spent + $1) / (total_transactions + 1),
         first_purchase_date = COALESCE(first_purchase_date, NOW()),
         last_purchase_date = NOW(),
         metadata = metadata || COALESCE($4::jsonb, '{}'::jsonb),
         updated_at = NOW()
       WHERE id = $2 AND business_id = $3
       RETURNING *`,
      [amount, id, businessId, metadata ? JSON.stringify(metadata) : null]
    );

    if (result.rows.length === 0) {
      return res.status(404).json({ error: 'Customer not found' });
    }
    res.json(result.rows[0]);
  }));

  // PATCH /api/customers/:businessId/:id/metadata - Merge extra JSONB fields
  // only (no stat increments). For callers that already recorded the
  // purchase itself elsewhere (e.g. sale creation's customer_id side
  // effect) and just need to attach vertical-specific extras like a
  // preferred table or a common-purchases tally, without double-counting
  // total_spent/total_transactions via /purchase.
  router.patch('/:businessId/:id/metadata', requireFields('metadata'), asyncHandler(async (req, res) => {
    const { businessId, id } = req.params;
    const { metadata } = req.body;

    const result = await pool.query(
      `UPDATE customers SET metadata = metadata || $1::jsonb, updated_at = NOW()
       WHERE id = $2 AND business_id = $3
       RETURNING *`,
      [JSON.stringify(metadata || {}), id, businessId]
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

