/**
 * Sales API routes for ManageCare.
 */
const express = require('express');
const router = express.Router();
const { requireFields, pagination, asyncHandler } = require('../middleware/validation');
const { requireBusinessMembership } = require('../middleware/auth');

module.exports = function(pool) {
  router.use('/:businessId', requireBusinessMembership(pool));

  // GET /api/sales/:businessId - List sales with filters
  router.get('/:businessId', pagination, asyncHandler(async (req, res) => {
    const { businessId } = req.params;
    const { limit, offset } = req.pagination;
    const { status, paymentMethod, workerId, storeId, startDate, endDate, customerId } = req.query;

    let query = 'SELECT s.*, COALESCE(json_agg(si.*) FILTER (WHERE si.id IS NOT NULL), \'[]\') as items FROM sales s LEFT JOIN sale_items si ON si.sale_id = s.id WHERE s.business_id = $1';
    const params = [businessId];
    let paramIndex = 2;

    if (status) {
      query += ` AND s.status = $${paramIndex++}`;
      params.push(status);
    }
    if (paymentMethod) {
      query += ` AND s.payment_method = $${paramIndex++}`;
      params.push(paymentMethod);
    }
    if (workerId) {
      query += ` AND s.worker_id = $${paramIndex++}`;
      params.push(workerId);
    }
    if (storeId) {
      query += ` AND s.store_id = $${paramIndex++}`;
      params.push(storeId);
    }
    if (customerId) {
      query += ` AND s.customer_id = $${paramIndex++}`;
      params.push(customerId);
    }
    if (startDate) {
      query += ` AND s.created_at >= $${paramIndex++}`;
      params.push(startDate);
    }
    if (endDate) {
      query += ` AND s.created_at <= $${paramIndex++}`;
      params.push(endDate);
    }

    query += ' GROUP BY s.id ORDER BY s.created_at DESC';

    // Count
    const countResult = await pool.query(
      'SELECT COUNT(*) FROM sales WHERE business_id = $1',
      [businessId]
    );
    const total = parseInt(countResult.rows[0].count);

    // Fetch with items
    query += ` LIMIT $${paramIndex++} OFFSET $${paramIndex}`;
    params.push(limit, offset);

    const result = await pool.query(query, params);

    res.json({
      data: result.rows.map(formatSale),
      pagination: { page: req.pagination.page, limit, total, totalPages: Math.ceil(total / limit) },
    });
  }));

  // GET /api/sales/:businessId/summary - Sales summary
  router.get('/:businessId/summary', asyncHandler(async (req, res) => {
    const { businessId } = req.params;
    const { period, startDate, endDate } = req.query;

    let dateFilter;
    if (startDate && endDate) {
      dateFilter = `s.created_at >= '${startDate}' AND s.created_at <= '${endDate}'`;
    } else if (period === 'today') {
      dateFilter = "s.created_at >= CURRENT_DATE AND s.created_at < CURRENT_DATE + INTERVAL '1 day'";
    } else if (period === 'week') {
      dateFilter = "s.created_at >= date_trunc('week', CURRENT_DATE)";
    } else if (period === 'month') {
      dateFilter = "s.created_at >= date_trunc('month', CURRENT_DATE)";
    } else {
      dateFilter = "s.created_at >= date_trunc('month', CURRENT_DATE)";
    }

    const result = await pool.query(`
      SELECT
        COUNT(*)::INTEGER as total_transactions,
        COALESCE(SUM(s.final_amount), 0)::DECIMAL(12,2) as total_revenue,
        COALESCE(AVG(s.final_amount), 0)::DECIMAL(12,2) as average_sale,
        COALESCE(SUM(s.discount_amount), 0)::DECIMAL(12,2) as total_discounts,
        JSONB_OBJECT_AGG(
          COALESCE(s.payment_method, 'unknown'),
          COALESCE(pmt.total, 0)
        ) as payment_breakdown
      FROM sales s
      LEFT JOIN (
        SELECT payment_method, SUM(final_amount)::DECIMAL(12,2) as total
        FROM sales
        WHERE business_id = $1 AND ${dateFilter}
        GROUP BY payment_method
      ) pmt ON pmt.payment_method = s.payment_method
      WHERE s.business_id = $1 AND s.status = 'completed' AND ${dateFilter}
      GROUP BY s.business_id
    `, [businessId]);

    if (result.rows.length === 0) {
      return res.json({
        total_transactions: 0, total_revenue: 0, average_sale: 0,
        total_discounts: 0, payment_breakdown: {},
      });
    }
    res.json(result.rows[0]);
  }));

  // GET /api/sales/:businessId/daily/:date - Daily sales breakdown
  router.get('/:businessId/daily/:date', asyncHandler(async (req, res) => {
    const { businessId, date } = req.params;
    const result = await pool.query(
      `SELECT * FROM get_daily_sales_summary($1, $2::DATE)`,
      [businessId, date]
    );
    res.json(result.rows[0] || { total_sales: 0, transaction_count: 0, average_sale: 0, payment_breakdown: [] });
  }));

  // GET /api/sales/:businessId/:id - Get single sale with items
  router.get('/:businessId/:id', asyncHandler(async (req, res) => {
    const { businessId, id } = req.params;
    const result = await pool.query(
      `SELECT s.*, COALESCE(json_agg(si.*) FILTER (WHERE si.id IS NOT NULL), '[]') as items
       FROM sales s LEFT JOIN sale_items si ON si.sale_id = s.id
       WHERE s.id = $1 AND s.business_id = $2
       GROUP BY s.id`,
      [id, businessId]
    );
    if (result.rows.length === 0) {
      return res.status(404).json({ error: 'Sale not found' });
    }
    res.json(formatSale(result.rows[0]));
  }));

  // POST /api/sales/:businessId - Create sale with items.
  // Accepts an optional client-supplied id for idempotent offline-sync
  // retries (SalesRepositorySupabase.syncSaleToFirestore sends the locally
  // generated sale id so a retry after a partial failure - e.g. sale
  // created but the inventory decrement failed - doesn't create a second,
  // duplicate sale). If a sale with that id already exists, it's returned
  // as-is rather than re-inserted.
  router.post('/:businessId', requireFields('final_amount', 'payment_method', 'created_by'), asyncHandler(async (req, res) => {
    const { businessId } = req.params;
    const {
      id, customer_id, store_id, worker_id, worker_name,
      total_amount, discount_amount, tax_amount, final_amount,
      payment_method, status, notes, created_by, sale_type, items,
    } = req.body;

    if (id) {
      const existing = await pool.query(
        'SELECT * FROM sales WHERE id = $1 AND business_id = $2',
        [id, businessId]
      );
      if (existing.rows.length > 0) {
        return res.status(200).json({ ...existing.rows[0], items: items || [], alreadyExisted: true });
      }
    }

    // Create sale
    const saleResult = await pool.query(
      `INSERT INTO sales (id, business_id, customer_id, store_id, worker_id, worker_name,
        total_amount, discount_amount, tax_amount, final_amount,
        payment_method, status, notes, created_by, sale_type)
       VALUES (COALESCE($1, uuid_generate_v4()), $2, $3, $4, $5, $6, $7, $8, $9, $10, $11, $12, $13, $14, $15)
       RETURNING *`,
      [id || null, businessId, customer_id || null, store_id || null, worker_id || null, worker_name || null,
       total_amount || final_amount, discount_amount || 0, tax_amount || 0, final_amount,
       payment_method, status || 'completed', notes || null, created_by, sale_type || 'retail']
    );
    const sale = saleResult.rows[0];

    // Insert sale items
    if (items && Array.isArray(items) && items.length > 0) {
      for (const item of items) {
        await pool.query(
          `INSERT INTO sale_items (sale_id, product_id, product_name, quantity, unit_price, discount, total,
            pricing_mode, inventory_unit, sale_unit, sale_unit_multiplier)
           VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11)`,
          [sale.id, item.product_id || null, item.product_name,
           item.quantity, item.unit_price, item.discount || 0, item.total,
           item.pricing_mode || null, item.inventory_unit || null,
           item.sale_unit || null, item.sale_unit_multiplier || 1]
        );

        // Deduct from inventory
        if (item.product_id) {
          const qty = (item.quantity || 0) * (item.sale_unit_multiplier || 1);
          await pool.query(
            'UPDATE inventory SET quantity = GREATEST(0, quantity - $1), updated_at = NOW() WHERE id = $2 AND business_id = $3',
            [qty, item.product_id, businessId]
          );
        }
      }
    }

    // Update customer total purchases
    if (customer_id) {
      await pool.query(
        'UPDATE customers SET total_purchases = total_purchases + $1, total_spent = total_spent + $1, updated_at = NOW() WHERE id = $2',
        [final_amount, customer_id]
      );
    }

    res.status(201).json({ ...sale, items: items || [] });
  }));

  // PUT /api/sales/:businessId/:id - Update sale metadata (not items/inventory)
  router.put('/:businessId/:id', asyncHandler(async (req, res) => {
    const { businessId, id } = req.params;
    const {
      customer_id, store_id, worker_id, worker_name,
      total_amount, discount_amount, tax_amount, final_amount,
      payment_method, status, notes,
    } = req.body;

    const fields = [];
    const params = [];
    let paramIndex = 1;
    const set = (col, val) => {
      if (val !== undefined) { fields.push(`${col} = $${paramIndex++}`); params.push(val); }
    };
    set('customer_id', customer_id);
    set('store_id', store_id);
    set('worker_id', worker_id);
    set('worker_name', worker_name);
    set('total_amount', total_amount);
    set('discount_amount', discount_amount);
    set('tax_amount', tax_amount);
    set('final_amount', final_amount);
    set('payment_method', payment_method);
    set('status', status);
    set('notes', notes);

    if (fields.length === 0) {
      return res.status(400).json({ error: 'No fields to update' });
    }

    fields.push('updated_at = NOW()');
    params.push(id, businessId);

    const result = await pool.query(
      `UPDATE sales SET ${fields.join(', ')} WHERE id = $${paramIndex++} AND business_id = $${paramIndex} RETURNING *`,
      params
    );

    if (result.rows.length === 0) {
      return res.status(404).json({ error: 'Sale not found' });
    }
    res.json(result.rows[0]);
  }));

  // DELETE /api/sales/:businessId/:id - Delete sale (restore inventory,
  // log an audit record). Atomic: restock, audit log, and delete all happen
  // in one transaction so a failure partway through doesn't leave inventory
  // restored without a matching deletion (or vice versa).
  router.delete('/:businessId/:id', asyncHandler(async (req, res) => {
    const { businessId, id } = req.params;
    const reason = (req.body && req.body.reason) || null;

    const client = await pool.connect();
    try {
      await client.query('BEGIN');

      const saleResult = await client.query(
        'SELECT * FROM sales WHERE id = $1 AND business_id = $2 FOR UPDATE',
        [id, businessId]
      );
      if (saleResult.rows.length === 0) {
        await client.query('ROLLBACK');
        return res.status(404).json({ error: 'Sale not found' });
      }
      const sale = saleResult.rows[0];

      const itemsResult = await client.query(
        'SELECT * FROM sale_items WHERE sale_id = $1',
        [id]
      );

      for (const item of itemsResult.rows) {
        if (item.product_id) {
          const qty = parseFloat(item.quantity) * parseFloat(item.sale_unit_multiplier || 1);
          await client.query(
            'UPDATE inventory SET quantity = quantity + $1, updated_at = NOW() WHERE id = $2 AND business_id = $3',
            [qty, item.product_id, businessId]
          );
        }
      }

      await client.query(
        `INSERT INTO sale_deletions (business_id, sale_id, deleted_by, reason, sale_snapshot, items_snapshot)
         VALUES ($1, $2, $3, $4, $5, $6)`,
        [businessId, id, req.user.id, reason, JSON.stringify(sale), JSON.stringify(itemsResult.rows)]
      );

      await client.query('DELETE FROM sales WHERE id = $1 AND business_id = $2', [id, businessId]);

      await client.query('COMMIT');
      res.json({ message: 'Sale deleted successfully', id });
    } catch (err) {
      await client.query('ROLLBACK');
      throw err;
    } finally {
      client.release();
    }
  }));

  return router;
};

function formatSale(row) {
  return {
    ...row,
    items: typeof row.items === 'string' ? JSON.parse(row.items) : row.items,
  };
}

