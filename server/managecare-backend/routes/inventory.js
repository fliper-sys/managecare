/**
 * Inventory API routes for ManageCare.
 * All routes require authentication and business membership.
 */
const express = require('express');
const router = express.Router();
const { requireFields, requireBusinessId, pagination, asyncHandler } = require('../middleware/validation');
const { requireBusinessMembership } = require('../middleware/auth');

module.exports = function(pool) {
  router.use('/:businessId', requireBusinessMembership(pool));

  // GET /api/inventory/:businessId - List inventory items
  router.get('/:businessId', pagination, asyncHandler(async (req, res) => {
    const { businessId } = req.params;
    const { limit, offset } = req.pagination;
    const { category, storeId, search, lowStock, isActive } = req.query;

    let query = 'SELECT * FROM inventory WHERE business_id = $1';
    const params = [businessId];
    let paramIndex = 2;

    if (category) {
      query += ` AND category = $${paramIndex++}`;
      params.push(category);
    }
    if (storeId) {
      query += ` AND store_id = $${paramIndex++}`;
      params.push(storeId);
    }
    if (search) {
      query += ` AND (name ILIKE $${paramIndex} OR sku ILIKE $${paramIndex} OR barcode ILIKE $${paramIndex})`;
      params.push(`%${search}%`);
      paramIndex++;
    }
    if (lowStock === 'true') {
      query += ' AND quantity <= min_stock_level AND min_stock_level > 0';
    }
    if (isActive === 'true') {
      query += ' AND is_active = true';
    }

    // Count total
    const countResult = await pool.query(
      query.replace('SELECT *', 'SELECT COUNT(*)'),
      params
    );
    const total = parseInt(countResult.rows[0].count);

    // Fetch paginated
    query += ` ORDER BY name ASC LIMIT $${paramIndex++} OFFSET $${paramIndex}`;
    params.push(limit, offset);

    const result = await pool.query(query, params);

    res.json({
      data: result.rows,
      pagination: {
        page: req.pagination.page,
        limit,
        total,
        totalPages: Math.ceil(total / limit),
      },
    });
  }));

  // GET /api/inventory/:businessId/:id - Get single inventory item
  router.get('/:businessId/:id', asyncHandler(async (req, res) => {
    const { businessId, id } = req.params;
    const result = await pool.query(
      'SELECT * FROM inventory WHERE id = $1 AND business_id = $2',
      [id, businessId]
    );
    if (result.rows.length === 0) {
      return res.status(404).json({ error: 'Inventory item not found' });
    }
    res.json(result.rows[0]);
  }));

  // POST /api/inventory/:businessId - Create inventory item
  router.post('/:businessId', requireFields('name', 'unit_price'), asyncHandler(async (req, res) => {
    const { businessId } = req.params;
    const {
      name, sku, barcode, category, description, unit_price, cost_price,
      quantity, min_stock_level, unit, expiry_date, store_id,
    } = req.body;

    // Auto-generate SKU if not provided
    let finalSku = sku;
    if (!finalSku || finalSku.trim() === '') {
      const skuResult = await pool.query(
        'UPDATE businesses SET last_sku_number = last_sku_number + 1 WHERE id = $1 RETURNING last_sku_number',
        [businessId]
      );
      const num = skuResult.rows[0]?.last_sku_number || Math.floor(Math.random() * 99999);
      finalSku = `SKU-${String(num).padStart(5, '0')}`;
    }

    const result = await pool.query(
      `INSERT INTO inventory (business_id, name, sku, barcode, category, description, unit_price, cost_price, quantity, min_stock_level, unit, expiry_date, store_id)
       VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11, $12, $13)
       RETURNING *`,
      [businessId, name, finalSku, barcode || null, category || null, description || null,
       unit_price, cost_price || 0, quantity || 0, min_stock_level || 0, unit || 'pcs',
       expiry_date || null, store_id || null]
    );

    res.status(201).json(result.rows[0]);
  }));

  // PUT /api/inventory/:businessId/:id - Update inventory item
  router.put('/:businessId/:id', asyncHandler(async (req, res) => {
    const { businessId, id } = req.params;
    const {
      name, sku, barcode, category, description, unit_price, cost_price,
      quantity, min_stock_level, unit, expiry_date, store_id, is_active,
    } = req.body;

    // Build dynamic update
    const fields = [];
    const params = [];
    let paramIndex = 1;

    if (name !== undefined) { fields.push(`name = $${paramIndex++}`); params.push(name); }
    if (sku !== undefined) { fields.push(`sku = $${paramIndex++}`); params.push(sku); }
    if (barcode !== undefined) { fields.push(`barcode = $${paramIndex++}`); params.push(barcode); }
    if (category !== undefined) { fields.push(`category = $${paramIndex++}`); params.push(category); }
    if (description !== undefined) { fields.push(`description = $${paramIndex++}`); params.push(description); }
    if (unit_price !== undefined) { fields.push(`unit_price = $${paramIndex++}`); params.push(unit_price); }
    if (cost_price !== undefined) { fields.push(`cost_price = $${paramIndex++}`); params.push(cost_price); }
    if (quantity !== undefined) { fields.push(`quantity = $${paramIndex++}`); params.push(quantity); }
    if (min_stock_level !== undefined) { fields.push(`min_stock_level = $${paramIndex++}`); params.push(min_stock_level); }
    if (unit !== undefined) { fields.push(`unit = $${paramIndex++}`); params.push(unit); }
    if (expiry_date !== undefined) { fields.push(`expiry_date = $${paramIndex++}`); params.push(expiry_date); }
    if (store_id !== undefined) { fields.push(`store_id = $${paramIndex++}`); params.push(store_id); }
    if (is_active !== undefined) { fields.push(`is_active = $${paramIndex++}`); params.push(is_active); }

    if (fields.length === 0) {
      return res.status(400).json({ error: 'No fields to update' });
    }

    fields.push(`updated_at = NOW()`);
    params.push(id, businessId);

    const result = await pool.query(
      `UPDATE inventory SET ${fields.join(', ')} WHERE id = $${paramIndex++} AND business_id = $${paramIndex} RETURNING *`,
      params
    );

    if (result.rows.length === 0) {
      return res.status(404).json({ error: 'Inventory item not found' });
    }
    res.json(result.rows[0]);
  }));

  // DELETE /api/inventory/:businessId/:id - Soft delete inventory item
  router.delete('/:businessId/:id', asyncHandler(async (req, res) => {
    const { businessId, id } = req.params;
    const result = await pool.query(
      'UPDATE inventory SET is_active = false, updated_at = NOW() WHERE id = $1 AND business_id = $2 RETURNING *',
      [id, businessId]
    );
    if (result.rows.length === 0) {
      return res.status(404).json({ error: 'Inventory item not found' });
    }
    res.json({ message: 'Inventory item deleted', id });
  }));

  // PATCH /api/inventory/:businessId/:id/quantity - Update stock quantity
  router.patch('/:businessId/:id/quantity', requireFields('quantity'), asyncHandler(async (req, res) => {
    const { businessId, id } = req.params;
    const { quantity, operation } = req.body;

    let query;
    if (operation === 'increment') {
      query = 'UPDATE inventory SET quantity = quantity + $1, updated_at = NOW() WHERE id = $2 AND business_id = $3 RETURNING *';
    } else if (operation === 'decrement') {
      query = 'UPDATE inventory SET quantity = GREATEST(0, quantity - $1), updated_at = NOW() WHERE id = $2 AND business_id = $3 RETURNING *';
    } else {
      query = 'UPDATE inventory SET quantity = $1, updated_at = NOW() WHERE id = $2 AND business_id = $3 RETURNING *';
    }

    const result = await pool.query(query, [quantity, id, businessId]);
    if (result.rows.length === 0) {
      return res.status(404).json({ error: 'Inventory item not found' });
    }
    res.json(result.rows[0]);
  }));

  // POST /api/inventory/:businessId/:id/history - Add a history entry
  router.post('/:businessId/:id/history', asyncHandler(async (req, res) => {
    const { businessId, id } = req.params;
    const {
      change_type, quantity_change, quantity_after, notes,
      performed_by_id, performed_by_name, ...rest
    } = req.body || {};

    const item = await pool.query(
      'SELECT id FROM inventory WHERE id = $1 AND business_id = $2',
      [id, businessId]
    );
    if (item.rows.length === 0) {
      return res.status(404).json({ error: 'Inventory item not found' });
    }

    const result = await pool.query(
      `INSERT INTO inventory_history
         (business_id, inventory_id, change_type, quantity_change, quantity_after, notes, performed_by_id, performed_by_name, metadata)
       VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9)
       RETURNING *`,
      [
        businessId, id, change_type || 'adjustment', quantity_change ?? null, quantity_after ?? null,
        notes || null, performed_by_id || null, performed_by_name || null, JSON.stringify(rest || {}),
      ]
    );
    res.status(201).json(result.rows[0]);
  }));

  // GET /api/inventory/:businessId/:id/history - List history entries
  router.get('/:businessId/:id/history', pagination, asyncHandler(async (req, res) => {
    const { businessId, id } = req.params;
    const { limit, offset } = req.pagination;

    const result = await pool.query(
      `SELECT * FROM inventory_history
       WHERE business_id = $1 AND inventory_id = $2
       ORDER BY created_at DESC LIMIT $3 OFFSET $4`,
      [businessId, id, limit, offset]
    );
    res.json({ data: result.rows });
  }));

  // POST /api/inventory/:businessId/:id/resupply - Record a bakery-style
  // resupply: increments quantity and logs a history entry atomically.
  router.post('/:businessId/:id/resupply', requireFields('quantity'), asyncHandler(async (req, res) => {
    const { businessId, id } = req.params;
    const {
      quantity, baker_id, baker_name, notes, performed_by_id, performed_by_name,
      expected_production_amount, actual_production_amount, production_unit, production_item_name,
    } = req.body;

    const client = await pool.connect();
    try {
      await client.query('BEGIN');
      const updated = await client.query(
        `UPDATE inventory SET quantity = quantity + $1, updated_at = NOW()
         WHERE id = $2 AND business_id = $3 RETURNING *`,
        [quantity, id, businessId]
      );
      if (updated.rows.length === 0) {
        await client.query('ROLLBACK');
        return res.status(404).json({ error: 'Inventory item not found' });
      }

      const historyEntry = await client.query(
        `INSERT INTO inventory_history
           (business_id, inventory_id, change_type, quantity_change, quantity_after, notes, performed_by_id, performed_by_name, metadata)
         VALUES ($1, $2, 'resupply', $3, $4, $5, $6, $7, $8)
         RETURNING *`,
        [
          businessId, id, quantity, updated.rows[0].quantity, notes || null,
          performed_by_id || null, performed_by_name || null,
          JSON.stringify({
            baker_id, baker_name, expected_production_amount,
            actual_production_amount, production_unit, production_item_name,
          }),
        ]
      );

      await client.query('COMMIT');
      res.status(201).json({ inventory: updated.rows[0], history: historyEntry.rows[0] });
    } catch (err) {
      await client.query('ROLLBACK');
      throw err;
    } finally {
      client.release();
    }
  }));

  // PATCH /api/inventory/:businessId/assign-store - Bulk-assign a store to
  // every inventory item currently without one (used when a business
  // creates its first store after already having unassigned stock).
  router.patch('/:businessId/assign-store', requireFields('store_id'), asyncHandler(async (req, res) => {
    const { businessId } = req.params;
    const { store_id } = req.body;

    const result = await pool.query(
      `UPDATE inventory SET store_id = $1, updated_at = NOW()
       WHERE business_id = $2 AND store_id IS NULL
       RETURNING id`,
      [store_id, businessId]
    );
    res.json({ updated: result.rows.length });
  }));

  return router;
};

