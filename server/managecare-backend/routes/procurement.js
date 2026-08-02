/**
 * Procurement API routes for ManageCare.
 *
 * A procurement is a batch purchase of one or more existing inventory
 * items. Creating one atomically: updates each inventory row's quantity
 * and weighted-average cost, records a per-item batch (for expiry/lot
 * tracking and the "procurements for this product" drill-down), logs an
 * inventory_history entry, and writes the procurement header + an items
 * JSONB snapshot (for display/CSV export without re-joining batches).
 */
const express = require('express');
const router = express.Router();
const { asyncHandler } = require('../middleware/validation');
const { requireBusinessMembership } = require('../middleware/auth');

module.exports = function(pool) {
  router.use('/:businessId', requireBusinessMembership(pool));

  // GET /api/procurement/:businessId - List procurements (optionally by sourceType)
  router.get('/:businessId', asyncHandler(async (req, res) => {
    const { businessId } = req.params;
    const { sourceType } = req.query;

    let query = 'SELECT * FROM procurements WHERE business_id = $1';
    const params = [businessId];
    if (sourceType) {
      query += ' AND source_type = $2';
      params.push(sourceType);
    }
    query += ' ORDER BY created_at DESC';

    const result = await pool.query(query, params);
    res.json({ data: result.rows });
  }));

  // GET /api/procurement/:businessId/product/:productId - Batches for one product
  router.get('/:businessId/product/:productId', asyncHandler(async (req, res) => {
    const { businessId, productId } = req.params;
    const result = await pool.query(
      'SELECT * FROM inventory_batches WHERE business_id = $1 AND inventory_id = $2 ORDER BY created_at DESC',
      [businessId, productId]
    );
    res.json({ data: result.rows });
  }));

  // GET /api/procurement/:businessId/:id - Single procurement
  router.get('/:businessId/:id', asyncHandler(async (req, res) => {
    const { businessId, id } = req.params;
    const result = await pool.query(
      'SELECT * FROM procurements WHERE id = $1 AND business_id = $2',
      [id, businessId]
    );
    if (result.rows.length === 0) {
      return res.status(404).json({ error: 'Procurement not found' });
    }
    res.json(result.rows[0]);
  }));

  // Client-side items can carry a stale/non-uuid product reference (an old
  // Firestore-era slug like "petrol", a placeholder id from before a
  // product synced) - feeding that straight into a uuid column throws
  // "invalid input syntax for type uuid" and rolls back the *entire*
  // procurement, not just that one line item. Treat anything that isn't a
  // real uuid as absent instead, same pattern already used in pumps.js.
  const UUID_RE = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;
  const asUuidOrNull = (v) => (v && UUID_RE.test(v) ? v : null);

  // POST /api/procurement/:businessId - Create a batch procurement
  router.post('/:businessId', asyncHandler(async (req, res) => {
    const { businessId } = req.params;
    const {
      items, supplier_id, supplier_name, invoice_ref, reference_image_url,
      created_by, created_by_name, created_by_email, store_id, store_name,
      source_type, baker_id, baker_name, sales_rep_id, sales_rep_name, notes,
    } = req.body;

    if (!Array.isArray(items) || items.length === 0) {
      return res.status(400).json({ error: 'items must be a non-empty array' });
    }

    const client = await pool.connect();
    try {
      await client.query('BEGIN');

      // Pass 1: compute totals/snapshot only - no writes yet, since the
      // procurement header must exist before batches can reference its id.
      let totalCost = 0;
      let totalQuantity = 0;
      const itemsSnapshot = [];

      for (const item of items) {
        const productId = asUuidOrNull(item.product_id || item.productId);
        const name = item.name || '';
        const quantity = parseFloat(item.quantity) || 0;
        const cost = parseFloat(item.cost) || 0;
        const unit = item.unit || '';
        const purchaseQuantity = item.purchase_quantity ?? item.purchaseQuantity ?? quantity;
        const purchaseUnit = item.purchase_unit || item.purchaseUnit || unit;
        const purchaseUnitCost = item.purchase_unit_cost ?? item.purchaseUnitCost ?? cost;
        const batchLabel = (item.batch_label || item.batchLabel || '').trim() || null;
        const expiryDate = item.expiry_date || item.expiryDate || null;
        const itemTotal = item.purchase_total ?? item.purchaseTotal ?? (purchaseQuantity * purchaseUnitCost);

        totalCost += itemTotal;
        totalQuantity += quantity;
        itemsSnapshot.push({
          productId, name, quantity, unit, cost, total: itemTotal,
          purchaseQuantity, purchaseUnit, purchaseUnitCost, batchLabel, expiryDate,
        });
      }

      const procurementResult = await client.query(
        `INSERT INTO procurements (
           business_id, supplier_name, total_amount, status, notes, created_by,
           items, total_quantity, items_count, invoice_ref, reference_image_url,
           store_id, store_name, source_type, created_by_name, created_by_email,
           baker_id, baker_name, sales_rep_id, sales_rep_name
         ) VALUES ($1, $2, $3, 'completed', $4, $5, $6, $7, $8, $9, $10, $11, $12, $13, $14, $15, $16, $17, $18, $19)
         RETURNING *`,
        [
          businessId, supplier_name || null, totalCost, notes || null, created_by || null,
          JSON.stringify(itemsSnapshot), totalQuantity, itemsSnapshot.length, invoice_ref || null,
          reference_image_url || null, store_id || null, store_name || null, source_type || null,
          created_by_name || null, created_by_email || null, baker_id || null, baker_name || null,
          sales_rep_id || null, sales_rep_name || null,
        ]
      );
      const procurement = procurementResult.rows[0];

      // Pass 2: apply inventory/batch/history writes, now that a real
      // procurement id exists for inventory_batches.procurement_id to reference.
      for (const snapshot of itemsSnapshot) {
        const productId = snapshot.productId;
        if (!productId) continue;

        const invResult = await client.query(
          'SELECT * FROM inventory WHERE id = $1 AND business_id = $2 FOR UPDATE',
          [productId, businessId]
        );
        if (invResult.rows.length === 0) continue;

        const inv = invResult.rows[0];
        const existingQuantity = parseFloat(inv.quantity) || 0;
        const existingCost = parseFloat(inv.cost_price) || 0;
        const updatedQuantity = existingQuantity + snapshot.quantity;
        const weightedCost = updatedQuantity <= 0
          ? snapshot.cost
          : ((existingQuantity * existingCost) + (snapshot.quantity * snapshot.cost)) / updatedQuantity;

        await client.query(
          'UPDATE inventory SET quantity = $1, cost_price = $2, updated_at = NOW() WHERE id = $3 AND business_id = $4',
          [updatedQuantity, weightedCost, productId, businessId]
        );

        const batchResult = await client.query(
          `INSERT INTO inventory_batches (
             business_id, inventory_id, procurement_id, batch_label, quantity, remaining_quantity,
             unit, cost, total, purchase_quantity, purchase_unit, purchase_unit_cost, expiry_date,
             supplier_name, invoice_ref, reference_image_url
           ) VALUES ($1, $2, $3, $4, $5, $5, $6, $7, $8, $9, $10, $11, $12, $13, $14, $15)
           RETURNING id`,
          [businessId, productId, procurement.id, snapshot.batchLabel, snapshot.quantity, snapshot.unit,
           snapshot.cost, snapshot.total, snapshot.purchaseQuantity, snapshot.purchaseUnit,
           snapshot.purchaseUnitCost, snapshot.expiryDate,
           supplier_name || null, invoice_ref || null, reference_image_url || null]
        );

        await client.query(
          `INSERT INTO inventory_history (business_id, inventory_id, change_type, quantity_change, quantity_after, notes, performed_by_id, performed_by_name, metadata)
           VALUES ($1, $2, 'procurement', $3, $4, $5, $6, $7, $8)`,
          [businessId, productId, snapshot.quantity, updatedQuantity, invoice_ref || null,
           created_by || null, created_by_name || null, JSON.stringify({ batchId: batchResult.rows[0].id })]
        );
      }

      await client.query('COMMIT');
      res.status(201).json(procurement);
    } catch (err) {
      await client.query('ROLLBACK');
      throw err;
    } finally {
      client.release();
    }
  }));

  return router;
};
