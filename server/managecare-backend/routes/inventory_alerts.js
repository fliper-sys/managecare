/**
 * Inventory alerts API routes for ManageCare.
 *
 * Alerts are computed fresh from the `inventory` table on every read
 * (current stock vs min_stock_level) rather than persisted as their own
 * synced records - Postgres can compute this on the fly, so there's nothing
 * to keep in sync. Only acknowledgement state is persisted, and only stays
 * "acknowledged" for as long as the severity that was acknowledged hasn't
 * changed (e.g. warning -> critical re-surfaces it).
 */
const express = require('express');
const router = express.Router();
const { asyncHandler } = require('../middleware/validation');
const { requireBusinessMembership } = require('../middleware/auth');

function computeSeverity(quantity, minThreshold) {
  if (minThreshold <= 0) return 'normal';
  const percentage = (quantity / minThreshold) * 100;
  if (percentage <= 25) return 'critical';
  if (percentage <= 50) return 'warning';
  return 'normal';
}

module.exports = function(pool) {
  router.use('/:businessId', requireBusinessMembership(pool));

  // GET /api/inventory-alerts/:businessId - List current low-stock alerts
  router.get('/:businessId', asyncHandler(async (req, res) => {
    const { businessId } = req.params;

    const inventoryResult = await pool.query(
      `SELECT id, name, quantity, min_stock_level FROM inventory
       WHERE business_id = $1 AND is_active = true AND min_stock_level > 0
         AND quantity <= min_stock_level`,
      [businessId]
    );

    if (inventoryResult.rows.length === 0) {
      return res.json({ data: [] });
    }

    // Latest ack per product (DISTINCT ON relies on the ORDER BY to pick
    // the most recent row per product_id).
    const acksResult = await pool.query(
      `SELECT DISTINCT ON (product_id) product_id, severity, acknowledged_at
       FROM inventory_alert_acks
       WHERE business_id = $1
       ORDER BY product_id, acknowledged_at DESC`,
      [businessId]
    );
    const acksByProduct = {};
    for (const ack of acksResult.rows) {
      acksByProduct[ack.product_id] = ack;
    }

    const alerts = inventoryResult.rows.map((item) => {
      const quantity = parseFloat(item.quantity);
      const minThreshold = parseFloat(item.min_stock_level);
      const severity = computeSeverity(quantity, minThreshold);
      const ack = acksByProduct[item.id];
      const acknowledged = !!ack && ack.severity === severity;

      return {
        id: item.id,
        businessId,
        productId: item.id,
        productName: item.name,
        currentStock: Math.round(quantity),
        minimumThreshold: Math.round(minThreshold),
        reorderQuantity: minThreshold > 0 ? Math.round(minThreshold * 2) : 50,
        severity,
        isActive: true,
        acknowledged,
        acknowledgedAt: acknowledged ? ack.acknowledged_at : null,
        createdAt: null,
        updatedAt: null,
      };
    });

    res.json({ data: alerts });
  }));

  // POST /api/inventory-alerts/:businessId/:productId/acknowledge
  router.post('/:businessId/:productId/acknowledge', asyncHandler(async (req, res) => {
    const { businessId, productId } = req.params;

    const itemResult = await pool.query(
      'SELECT quantity, min_stock_level FROM inventory WHERE id = $1 AND business_id = $2',
      [productId, businessId]
    );
    if (itemResult.rows.length === 0) {
      return res.status(404).json({ error: 'Product not found' });
    }
    const severity = computeSeverity(
      parseFloat(itemResult.rows[0].quantity),
      parseFloat(itemResult.rows[0].min_stock_level)
    );

    const result = await pool.query(
      `INSERT INTO inventory_alert_acks (business_id, product_id, severity, acknowledged_by)
       VALUES ($1, $2, $3, $4) RETURNING *`,
      [businessId, productId, severity, req.user.id]
    );

    res.status(201).json(result.rows[0]);
  }));

  return router;
};
