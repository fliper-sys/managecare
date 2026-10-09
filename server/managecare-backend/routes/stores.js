/**
 * Stores API routes for ManageCare (multi-store businesses).
 */
const express = require('express');
const router = express.Router();
const { requireFields, asyncHandler } = require('../middleware/validation');
const { requireBusinessMembership, requireBusinessOwner } = require('../middleware/auth');

module.exports = function(pool) {
  router.use('/:businessId', requireBusinessMembership(pool));

  const administrativeBranchLimit = async (businessId) => {
    const businessResult = await pool.query('SELECT business_type, subscription_tier FROM businesses WHERE id = $1', [businessId]);
    const business = businessResult.rows[0];
    if (!business || String(business.business_type).toLowerCase() !== 'administrative') return null;
    const limits = { tier1: 0, tier2: 2, tier3: 5, premium: 10, enterprise: null };
    const limit = limits[String(business.subscription_tier || 'tier1').toLowerCase()] ?? 0;
    if (limit == null) return null;
    const count = await pool.query('SELECT COUNT(*)::int AS count FROM stores WHERE business_id = $1 AND is_active = true', [businessId]);
    return { limit, usage: Number(count.rows[0].count || 0) };
  };

  // GET /api/stores/:businessId - List stores
  router.get('/:businessId', asyncHandler(async (req, res) => {
    const { businessId } = req.params;
    const result = await pool.query(
      'SELECT * FROM stores WHERE business_id = $1 AND is_active = true ORDER BY name ASC',
      [businessId]
    );
    res.json(result.rows);
  }));

  // POST /api/stores/:businessId - Create store (owner only)
  router.post('/:businessId', requireBusinessOwner, requireFields('name'), asyncHandler(async (req, res) => {
    const { businessId } = req.params;
    const { name, location, address, phone } = req.body;
    const quota = await administrativeBranchLimit(businessId);
    if (quota && quota.usage >= quota.limit) {
      return res.status(409).json({ error: 'Subscription branch limit reached', limit_type: 'branches', limit: quota.limit, current_usage: quota.usage });
    }
    const result = await pool.query(
      `INSERT INTO stores (business_id, name, location, address, phone)
       VALUES ($1, $2, $3, $4, $5) RETURNING *`,
      [businessId, name, location || null, address || null, phone || null]
    );
    res.status(201).json(result.rows[0]);
  }));

  // PUT /api/stores/:businessId/:id - Update store (owner only)
  router.put('/:businessId/:id', requireBusinessOwner, asyncHandler(async (req, res) => {
    const { businessId, id } = req.params;
    const { name, location, address, phone, is_active } = req.body;

    const fields = [];
    const params = [];
    let paramIndex = 1;
    const set = (col, val) => {
      if (val !== undefined) { fields.push(`${col} = $${paramIndex++}`); params.push(val); }
    };
    set('name', name);
    set('location', location);
    set('address', address);
    set('phone', phone);
    set('is_active', is_active);

    if (fields.length === 0) {
      return res.status(400).json({ error: 'No fields to update' });
    }
    fields.push('updated_at = NOW()');
    params.push(id, businessId);

    const result = await pool.query(
      `UPDATE stores SET ${fields.join(', ')} WHERE id = $${paramIndex++} AND business_id = $${paramIndex} RETURNING *`,
      params
    );
    if (result.rows.length === 0) {
      return res.status(404).json({ error: 'Store not found' });
    }
    res.json(result.rows[0]);
  }));

  // DELETE /api/stores/:businessId/:id - Soft delete (owner only)
  router.delete('/:businessId/:id', requireBusinessOwner, asyncHandler(async (req, res) => {
    const { businessId, id } = req.params;
    const result = await pool.query(
      'UPDATE stores SET is_active = false, updated_at = NOW() WHERE id = $1 AND business_id = $2 RETURNING *',
      [id, businessId]
    );
    if (result.rows.length === 0) {
      return res.status(404).json({ error: 'Store not found' });
    }
    res.json({ message: 'Store deleted', id });
  }));

  return router;
};
