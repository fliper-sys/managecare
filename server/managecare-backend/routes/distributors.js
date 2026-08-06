/**
 * Distributor API routes for ManageCare.
 * A distributor buys finished products (bakery or retail) at a per-sale
 * discount off the shelf price.
 */
const express = require('express');
const router = express.Router();
const { requireFields, asyncHandler } = require('../middleware/validation');
const { requireBusinessMembership } = require('../middleware/auth');

module.exports = function(pool) {
  router.use('/:businessId', requireBusinessMembership(pool));

  router.get('/:businessId', asyncHandler(async (req, res) => {
    const result = await pool.query(
      'SELECT * FROM distributors WHERE business_id = $1 AND is_active = true ORDER BY name ASC',
      [req.params.businessId]
    );
    res.json({ data: result.rows });
  }));

  router.post('/:businessId', requireFields('name'), asyncHandler(async (req, res) => {
    const { businessId } = req.params;
    const { name, contactPerson, phone, email, address, notes } = req.body;
    const result = await pool.query(
      `INSERT INTO distributors (business_id, name, contact_person, phone, email, address, notes)
       VALUES ($1, $2, $3, $4, $5, $6, $7)
       RETURNING *`,
      [businessId, name.trim(), contactPerson || null, phone || null, email || null, address || null, notes || null]
    );
    res.status(201).json(result.rows[0]);
  }));

  router.get('/:businessId/sales', asyncHandler(async (req, res) => {
    const { businessId } = req.params;
    const { distributorId, limit } = req.query;
    const params = [businessId];
    let query = 'SELECT * FROM distributor_sales WHERE business_id = $1';
    if (distributorId) {
      params.push(distributorId);
      query += ` AND distributor_id = $${params.length}`;
    }
    params.push(Math.min(500, parseInt(limit) || 200));
    query += ` ORDER BY created_at DESC LIMIT $${params.length}`;
    const result = await pool.query(query, params);
    res.json({ data: result.rows });
  }));

  // POST /:businessId/sales - atomically decrements the product's stock,
  // records the sale in the dedicated distributor_sales ledger, and mirrors
  // it into sales/sale_items so revenue dashboards stay complete.
  router.post('/:businessId/sales', requireFields('distributorId', 'productId', 'quantity', 'unitPrice'), asyncHandler(async (req, res) => {
    const { businessId } = req.params;
    const {
      distributorId, productId, quantity, unitPrice, discountPercent,
      salesRepId, salesRepName, notes,
    } = req.body;

    const qty = Number(quantity);
    if (!(qty > 0)) return res.status(400).json({ error: 'quantity must be greater than zero' });
    const discount = Number(discountPercent) || 0;
    const discountedUnitPrice = Number(unitPrice) * (1 - discount / 100);
    const totalAmount = discountedUnitPrice * qty;

    const client = await pool.connect();
    try {
      await client.query('BEGIN');

      const distResult = await client.query('SELECT * FROM distributors WHERE id = $1 AND business_id = $2', [distributorId, businessId]);
      if (distResult.rows.length === 0) {
        await client.query('ROLLBACK');
        return res.status(404).json({ error: 'Distributor not found' });
      }
      const distributor = distResult.rows[0];

      const invResult = await client.query(
        'SELECT * FROM inventory WHERE id = $1 AND business_id = $2 FOR UPDATE',
        [productId, businessId]
      );
      if (invResult.rows.length === 0) {
        await client.query('ROLLBACK');
        return res.status(404).json({ error: 'Product not found' });
      }
      const product = invResult.rows[0];
      const updatedQuantity = Number(product.quantity) - qty;
      if (updatedQuantity < 0) {
        await client.query('ROLLBACK');
        return res.status(400).json({ error: 'Insufficient stock for distributor sale' });
      }

      await client.query(
        'UPDATE inventory SET quantity = $1, updated_at = NOW() WHERE id = $2 AND business_id = $3',
        [updatedQuantity, productId, businessId]
      );

      const saleResult = await client.query(
        `INSERT INTO sales (business_id, worker_id, worker_name, total_amount, final_amount, payment_method, status, sale_type, created_by, notes)
         VALUES ($1, $2, $3, $4, $4, 'distributor', 'completed', 'distributor', $2, $5)
         RETURNING *`,
        [businessId, salesRepId || req.user?.id || null, salesRepName || null, totalAmount, notes || null]
      );
      const sale = saleResult.rows[0];

      await client.query(
        `INSERT INTO sale_items (sale_id, product_id, product_name, quantity, unit_price, discount, total)
         VALUES ($1, $2, $3, $4, $5, $6, $7)`,
        [sale.id, productId, product.name, qty, discountedUnitPrice, Number(unitPrice) - discountedUnitPrice, totalAmount]
      );

      await client.query(
        `INSERT INTO inventory_history (business_id, inventory_id, change_type, quantity_change, quantity_after, notes, performed_by_id, performed_by_name, metadata)
         VALUES ($1, $2, 'distributor_sale', $3, $4, $5, $6, $7, $8)`,
        [
          businessId, productId, -qty, updatedQuantity, notes || null,
          salesRepId || null, salesRepName || null,
          JSON.stringify({ distributorId, distributorName: distributor.name }),
        ]
      );

      const distSaleResult = await client.query(
        `INSERT INTO distributor_sales
           (business_id, sale_id, distributor_id, distributor_name, product_id, product_name,
            quantity, unit_price, discount_percent, discounted_unit_price, total_amount,
            sales_rep_id, sales_rep_name, notes)
         VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11, $12, $13, $14)
         RETURNING *`,
        [
          businessId, sale.id, distributorId, distributor.name, productId, product.name,
          qty, unitPrice, discount, discountedUnitPrice, totalAmount,
          salesRepId || null, salesRepName || null, notes || null,
        ]
      );

      await client.query('COMMIT');
      res.status(201).json(distSaleResult.rows[0]);
    } catch (error) {
      await client.query('ROLLBACK');
      throw error;
    } finally {
      client.release();
    }
  }));

  return router;
};
