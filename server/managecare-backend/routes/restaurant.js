/**
 * Restaurant vertical API routes for ManageCare.
 * Menu items, tables, orders, reservations, staff, and waste tracking.
 */
const express = require('express');
const router = express.Router();
const { requireFields, asyncHandler } = require('../middleware/validation');
const { requireBusinessMembership } = require('../middleware/auth');

module.exports = function(pool) {
  router.use('/:businessId', requireBusinessMembership(pool));

  // ---------- Menu ----------

  router.get('/:businessId/menu', asyncHandler(async (req, res) => {
    const result = await pool.query(
      'SELECT * FROM restaurant_menu_items WHERE business_id = $1 ORDER BY category ASC, name ASC',
      [req.params.businessId]
    );
    res.json({ data: result.rows });
  }));

  router.post('/:businessId/menu', requireFields('name'), asyncHandler(async (req, res) => {
    const { businessId } = req.params;
    const {
      id, name, category, price, cost, description, available, preparation_time,
      image_url, rating, review_count, inventory_product_id, inventory_stock, options, ingredients,
    } = req.body;

    const result = await pool.query(
      `INSERT INTO restaurant_menu_items (
         id, business_id, name, category, price, cost, description, available, preparation_time,
         image_url, rating, review_count, inventory_product_id, inventory_stock, options, ingredients
       ) VALUES (
         COALESCE($1::uuid, uuid_generate_v4()), $2, $3, $4, $5, $6, $7, $8, $9,
         $10, $11, $12, $13, $14, COALESCE($15::jsonb, '[]'::jsonb), COALESCE($16::jsonb, '[]'::jsonb)
       )
       ON CONFLICT (id) DO UPDATE SET
         name = EXCLUDED.name, category = EXCLUDED.category, price = EXCLUDED.price, cost = EXCLUDED.cost,
         description = EXCLUDED.description, available = EXCLUDED.available, preparation_time = EXCLUDED.preparation_time,
         image_url = EXCLUDED.image_url, rating = EXCLUDED.rating, review_count = EXCLUDED.review_count,
         inventory_product_id = EXCLUDED.inventory_product_id, inventory_stock = EXCLUDED.inventory_stock,
         options = EXCLUDED.options, ingredients = EXCLUDED.ingredients, updated_at = NOW()
       RETURNING *`,
      [
        id || null, businessId, name, category || 'Menu', price || 0, cost ?? null, description || null,
        available !== false, preparation_time || 15, image_url || null, rating ?? null, review_count ?? null,
        inventory_product_id || null, inventory_stock ?? null,
        options ? JSON.stringify(options) : null, ingredients ? JSON.stringify(ingredients) : null,
      ]
    );
    res.status(201).json(result.rows[0]);
  }));

  router.put('/:businessId/menu/:id', asyncHandler(async (req, res) => {
    const { businessId, id } = req.params;
    const {
      name, category, price, cost, description, available, preparation_time,
      image_url, rating, review_count, inventory_product_id, inventory_stock, options, ingredients,
    } = req.body;

    const fields = [];
    const params = [];
    let paramIndex = 1;
    const set = (col, val) => { if (val !== undefined) { fields.push(`${col} = $${paramIndex++}`); params.push(val); } };
    set('name', name);
    set('category', category);
    set('price', price);
    set('cost', cost);
    set('description', description);
    set('available', available);
    set('preparation_time', preparation_time);
    set('image_url', image_url);
    set('rating', rating);
    set('review_count', review_count);
    set('inventory_product_id', inventory_product_id);
    set('inventory_stock', inventory_stock);
    if (options !== undefined) { fields.push(`options = $${paramIndex++}`); params.push(JSON.stringify(options)); }
    if (ingredients !== undefined) { fields.push(`ingredients = $${paramIndex++}`); params.push(JSON.stringify(ingredients)); }

    if (fields.length === 0) return res.status(400).json({ error: 'No fields to update' });
    fields.push('updated_at = NOW()');
    params.push(id, businessId);

    const result = await pool.query(
      `UPDATE restaurant_menu_items SET ${fields.join(', ')} WHERE id = $${paramIndex++} AND business_id = $${paramIndex} RETURNING *`,
      params
    );
    if (result.rows.length === 0) return res.status(404).json({ error: 'Menu item not found' });
    res.json(result.rows[0]);
  }));

  router.delete('/:businessId/menu/:id', asyncHandler(async (req, res) => {
    const { businessId, id } = req.params;
    await pool.query('DELETE FROM restaurant_menu_items WHERE id = $1 AND business_id = $2', [id, businessId]);
    res.json({ message: 'Menu item deleted', id });
  }));

  // ---------- Tables ----------

  router.get('/:businessId/tables', asyncHandler(async (req, res) => {
    const result = await pool.query(
      'SELECT * FROM restaurant_tables WHERE business_id = $1 ORDER BY table_number ASC',
      [req.params.businessId]
    );
    res.json({ data: result.rows });
  }));

  router.post('/:businessId/tables', requireFields('table_number'), asyncHandler(async (req, res) => {
    const { businessId } = req.params;
    const { id, table_number, capacity, status, assigned_waiter_id, assigned_waiter_name, reserved_until } = req.body;

    const result = await pool.query(
      `INSERT INTO restaurant_tables (id, business_id, table_number, capacity, status, assigned_waiter_id, assigned_waiter_name, reserved_until)
       VALUES (COALESCE($1::uuid, uuid_generate_v4()), $2, $3, $4, $5, $6, $7, $8)
       ON CONFLICT (id) DO UPDATE SET
         table_number = EXCLUDED.table_number, capacity = EXCLUDED.capacity, status = EXCLUDED.status,
         assigned_waiter_id = EXCLUDED.assigned_waiter_id, assigned_waiter_name = EXCLUDED.assigned_waiter_name,
         reserved_until = EXCLUDED.reserved_until, updated_at = NOW()
       RETURNING *`,
      [id || null, businessId, table_number, capacity || 2, status || 'available',
       assigned_waiter_id || null, assigned_waiter_name || null, reserved_until || null]
    );
    res.status(201).json(result.rows[0]);
  }));

  router.put('/:businessId/tables/:id', asyncHandler(async (req, res) => {
    const { businessId, id } = req.params;
    const { table_number, capacity, status, assigned_waiter_id, assigned_waiter_name, reserved_until } = req.body;

    const fields = [];
    const params = [];
    let paramIndex = 1;
    const set = (col, val) => { if (val !== undefined) { fields.push(`${col} = $${paramIndex++}`); params.push(val); } };
    set('table_number', table_number);
    set('capacity', capacity);
    set('status', status);
    set('assigned_waiter_id', assigned_waiter_id);
    set('assigned_waiter_name', assigned_waiter_name);
    set('reserved_until', reserved_until);

    if (fields.length === 0) return res.status(400).json({ error: 'No fields to update' });
    fields.push('updated_at = NOW()');
    params.push(id, businessId);

    const result = await pool.query(
      `UPDATE restaurant_tables SET ${fields.join(', ')} WHERE id = $${paramIndex++} AND business_id = $${paramIndex} RETURNING *`,
      params
    );
    if (result.rows.length === 0) return res.status(404).json({ error: 'Table not found' });
    res.json(result.rows[0]);
  }));

  router.delete('/:businessId/tables/:id', asyncHandler(async (req, res) => {
    const { businessId, id } = req.params;
    await pool.query('DELETE FROM restaurant_tables WHERE id = $1 AND business_id = $2', [id, businessId]);
    res.json({ message: 'Table deleted', id });
  }));

  // ---------- Orders ----------

  router.get('/:businessId/orders', asyncHandler(async (req, res) => {
    const result = await pool.query(
      'SELECT * FROM restaurant_orders WHERE business_id = $1 ORDER BY created_at DESC',
      [req.params.businessId]
    );
    res.json({ data: result.rows });
  }));

  router.post('/:businessId/orders', asyncHandler(async (req, res) => {
    const { businessId } = req.params;
    const {
      id, table_id, table_number, room_id, guest_id, order_target_type, order_target_label,
      customer_id, customer_name, customer_phone, customer_email, items, subtotal, tax, discount, total,
      status, payment_status, assigned_chef_id, assigned_waiter_id, payment_methods, payment_breakdown,
      notes, order_type, completed_at,
    } = req.body;

    const result = await pool.query(
      `INSERT INTO restaurant_orders (
         id, business_id, table_id, table_number, room_id, guest_id, order_target_type, order_target_label,
         customer_id, customer_name, customer_phone, customer_email, items, subtotal, tax, discount, total,
         status, payment_status, assigned_chef_id, assigned_waiter_id, payment_methods, payment_breakdown,
         notes, order_type, completed_at
       ) VALUES (
         COALESCE($1::uuid, uuid_generate_v4()), $2, $3, $4, $5, $6, $7, $8,
         $9, $10, $11, $12, COALESCE($13::jsonb, '[]'::jsonb), $14, $15, $16, $17,
         $18, $19, $20, $21, COALESCE($22::jsonb, '[]'::jsonb), COALESCE($23::jsonb, '[]'::jsonb),
         $24, $25, $26
       )
       ON CONFLICT (id) DO UPDATE SET
         table_id = EXCLUDED.table_id, table_number = EXCLUDED.table_number, room_id = EXCLUDED.room_id,
         guest_id = EXCLUDED.guest_id, order_target_type = EXCLUDED.order_target_type,
         order_target_label = EXCLUDED.order_target_label, customer_id = EXCLUDED.customer_id,
         customer_name = EXCLUDED.customer_name, customer_phone = EXCLUDED.customer_phone,
         customer_email = EXCLUDED.customer_email, items = EXCLUDED.items, subtotal = EXCLUDED.subtotal,
         tax = EXCLUDED.tax, discount = EXCLUDED.discount, total = EXCLUDED.total, status = EXCLUDED.status,
         payment_status = EXCLUDED.payment_status, assigned_chef_id = EXCLUDED.assigned_chef_id,
         assigned_waiter_id = EXCLUDED.assigned_waiter_id, payment_methods = EXCLUDED.payment_methods,
         payment_breakdown = EXCLUDED.payment_breakdown, notes = EXCLUDED.notes, order_type = EXCLUDED.order_type,
         completed_at = EXCLUDED.completed_at, updated_at = NOW()
       RETURNING *`,
      [
        id || null, businessId, table_id || null, table_number ?? null, room_id || null, guest_id || null,
        order_target_type || null, order_target_label || null, customer_id || null, customer_name || null,
        customer_phone || null, customer_email || null, items ? JSON.stringify(items) : null,
        subtotal || 0, tax || 0, discount || 0, total || 0, status || 'pending', payment_status || 'pending',
        assigned_chef_id || null, assigned_waiter_id || null,
        payment_methods ? JSON.stringify(payment_methods) : null, payment_breakdown ? JSON.stringify(payment_breakdown) : null,
        notes || null, order_type || 'dine-in', completed_at || null,
      ]
    );
    res.status(201).json(result.rows[0]);
  }));

  router.put('/:businessId/orders/:id', asyncHandler(async (req, res) => {
    const { businessId, id } = req.params;
    const {
      status, payment_status, assigned_chef_id, assigned_waiter_id, payment_methods, payment_breakdown,
      completed_at, notes,
    } = req.body;

    const fields = [];
    const params = [];
    let paramIndex = 1;
    const set = (col, val) => { if (val !== undefined) { fields.push(`${col} = $${paramIndex++}`); params.push(val); } };
    set('status', status);
    set('payment_status', payment_status);
    set('assigned_chef_id', assigned_chef_id);
    set('assigned_waiter_id', assigned_waiter_id);
    set('completed_at', completed_at);
    set('notes', notes);
    if (payment_methods !== undefined) { fields.push(`payment_methods = $${paramIndex++}`); params.push(JSON.stringify(payment_methods)); }
    if (payment_breakdown !== undefined) { fields.push(`payment_breakdown = $${paramIndex++}`); params.push(JSON.stringify(payment_breakdown)); }

    if (fields.length === 0) return res.status(400).json({ error: 'No fields to update' });
    fields.push('updated_at = NOW()');
    params.push(id, businessId);

    const result = await pool.query(
      `UPDATE restaurant_orders SET ${fields.join(', ')} WHERE id = $${paramIndex++} AND business_id = $${paramIndex} RETURNING *`,
      params
    );
    if (result.rows.length === 0) return res.status(404).json({ error: 'Order not found' });
    res.json(result.rows[0]);
  }));

  // ---------- Reservations ----------

  router.get('/:businessId/reservations', asyncHandler(async (req, res) => {
    const result = await pool.query(
      'SELECT * FROM restaurant_reservations WHERE business_id = $1 ORDER BY reservation_date_time ASC',
      [req.params.businessId]
    );
    res.json({ data: result.rows });
  }));

  router.post('/:businessId/reservations', requireFields('customer_name', 'customer_phone', 'reservation_date_time'), asyncHandler(async (req, res) => {
    const { businessId } = req.params;
    const {
      id, customer_name, customer_phone, guest_count, reservation_date_time, status,
      special_requests, table_id, table_number, assigned_waiter_id, assigned_waiter_name,
    } = req.body;

    const result = await pool.query(
      `INSERT INTO restaurant_reservations (
         id, business_id, customer_name, customer_phone, guest_count, reservation_date_time, status,
         special_requests, table_id, table_number, assigned_waiter_id, assigned_waiter_name
       ) VALUES (COALESCE($1::uuid, uuid_generate_v4()), $2, $3, $4, $5, $6, $7, $8, $9, $10, $11, $12)
       ON CONFLICT (id) DO UPDATE SET
         customer_name = EXCLUDED.customer_name, customer_phone = EXCLUDED.customer_phone,
         guest_count = EXCLUDED.guest_count, reservation_date_time = EXCLUDED.reservation_date_time,
         status = EXCLUDED.status, special_requests = EXCLUDED.special_requests, table_id = EXCLUDED.table_id,
         table_number = EXCLUDED.table_number, assigned_waiter_id = EXCLUDED.assigned_waiter_id,
         assigned_waiter_name = EXCLUDED.assigned_waiter_name, updated_at = NOW()
       RETURNING *`,
      [id || null, businessId, customer_name, customer_phone, guest_count || 1, reservation_date_time,
       status || 'pending', special_requests || null, table_id || null, table_number ?? null,
       assigned_waiter_id || null, assigned_waiter_name || null]
    );
    res.status(201).json(result.rows[0]);
  }));

  router.put('/:businessId/reservations/:id', asyncHandler(async (req, res) => {
    const { businessId, id } = req.params;
    const { status, assigned_waiter_id, assigned_waiter_name, table_id, table_number } = req.body;

    const fields = [];
    const params = [];
    let paramIndex = 1;
    const set = (col, val) => { if (val !== undefined) { fields.push(`${col} = $${paramIndex++}`); params.push(val); } };
    set('status', status);
    set('assigned_waiter_id', assigned_waiter_id);
    set('assigned_waiter_name', assigned_waiter_name);
    set('table_id', table_id);
    set('table_number', table_number);

    if (fields.length === 0) return res.status(400).json({ error: 'No fields to update' });
    fields.push('updated_at = NOW()');
    params.push(id, businessId);

    const result = await pool.query(
      `UPDATE restaurant_reservations SET ${fields.join(', ')} WHERE id = $${paramIndex++} AND business_id = $${paramIndex} RETURNING *`,
      params
    );
    if (result.rows.length === 0) return res.status(404).json({ error: 'Reservation not found' });
    res.json(result.rows[0]);
  }));

  // ---------- Staff ----------

  router.get('/:businessId/staff', asyncHandler(async (req, res) => {
    const result = await pool.query(
      'SELECT * FROM restaurant_staff WHERE business_id = $1 ORDER BY name ASC',
      [req.params.businessId]
    );
    res.json({ data: result.rows });
  }));

  router.post('/:businessId/staff', requireFields('name'), asyncHandler(async (req, res) => {
    const { businessId } = req.params;
    const { id, name, phone, role, active, sections, permissions } = req.body;

    const result = await pool.query(
      `INSERT INTO restaurant_staff (id, business_id, name, phone, role, active, sections, permissions)
       VALUES (COALESCE($1::uuid, uuid_generate_v4()), $2, $3, $4, $5, $6, COALESCE($7::jsonb, '[]'::jsonb), COALESCE($8::jsonb, '[]'::jsonb))
       ON CONFLICT (id) DO UPDATE SET
         name = EXCLUDED.name, phone = EXCLUDED.phone, role = EXCLUDED.role, active = EXCLUDED.active,
         sections = EXCLUDED.sections, permissions = EXCLUDED.permissions, updated_at = NOW()
       RETURNING *`,
      [id || null, businessId, name, phone || null, role || 'waiter', active !== false,
       sections ? JSON.stringify(sections) : null, permissions ? JSON.stringify(permissions) : null]
    );
    res.status(201).json(result.rows[0]);
  }));

  router.put('/:businessId/staff/:id', asyncHandler(async (req, res) => {
    const { businessId, id } = req.params;
    const { name, phone, role, active, sections, permissions } = req.body;

    const fields = [];
    const params = [];
    let paramIndex = 1;
    const set = (col, val) => { if (val !== undefined) { fields.push(`${col} = $${paramIndex++}`); params.push(val); } };
    set('name', name);
    set('phone', phone);
    set('role', role);
    set('active', active);
    if (sections !== undefined) { fields.push(`sections = $${paramIndex++}`); params.push(JSON.stringify(sections)); }
    if (permissions !== undefined) { fields.push(`permissions = $${paramIndex++}`); params.push(JSON.stringify(permissions)); }

    if (fields.length === 0) return res.status(400).json({ error: 'No fields to update' });
    fields.push('updated_at = NOW()');
    params.push(id, businessId);

    const result = await pool.query(
      `UPDATE restaurant_staff SET ${fields.join(', ')} WHERE id = $${paramIndex++} AND business_id = $${paramIndex} RETURNING *`,
      params
    );
    if (result.rows.length === 0) return res.status(404).json({ error: 'Staff member not found' });
    res.json(result.rows[0]);
  }));

  router.delete('/:businessId/staff/:id', asyncHandler(async (req, res) => {
    const { businessId, id } = req.params;
    await pool.query('DELETE FROM restaurant_staff WHERE id = $1 AND business_id = $2', [id, businessId]);
    res.json({ message: 'Staff member deleted', id });
  }));

  // ---------- Waste ----------

  router.get('/:businessId/waste', asyncHandler(async (req, res) => {
    const result = await pool.query(
      'SELECT * FROM restaurant_waste WHERE business_id = $1 ORDER BY recorded_at DESC',
      [req.params.businessId]
    );
    res.json({ data: result.rows });
  }));

  // POST /api/restaurant/:businessId/waste - Record waste. Atomically
  // deducts from inventory and logs an inventory_history entry, same
  // pattern as the resupply/returns transactions in other verticals.
  router.post('/:businessId/waste', requireFields('product_id', 'product_name', 'quantity', 'type'), asyncHandler(async (req, res) => {
    const { businessId } = req.params;
    const { product_id, product_name, quantity, unit, type, reason, recorded_by_id, recorded_by_name } = req.body;

    if (!(quantity > 0)) {
      return res.status(400).json({ error: 'Waste quantity must be greater than zero' });
    }

    const client = await pool.connect();
    try {
      await client.query('BEGIN');

      const inventoryResult = await client.query(
        'SELECT * FROM inventory WHERE id = $1 AND business_id = $2 FOR UPDATE',
        [product_id, businessId]
      );
      if (inventoryResult.rows.length === 0) {
        await client.query('ROLLBACK');
        return res.status(404).json({ error: 'Inventory item not found' });
      }

      const inventoryItem = inventoryResult.rows[0];
      const currentQuantity = parseFloat(inventoryItem.quantity) || 0;
      const currentCost = parseFloat(inventoryItem.cost_price) || 0;
      if (currentQuantity < quantity) {
        await client.query('ROLLBACK');
        return res.status(400).json({ error: 'Not enough stock available to record this waste' });
      }

      const remainingQuantity = currentQuantity - quantity;
      const costImpact = currentCost * quantity;

      await client.query(
        'UPDATE inventory SET quantity = $1, updated_at = NOW() WHERE id = $2 AND business_id = $3',
        [remainingQuantity, product_id, businessId]
      );

      const wasteResult = await client.query(
        `INSERT INTO restaurant_waste (
           business_id, product_id, product_name, quantity, unit, type, reason,
           cost_impact, remaining_quantity, recorded_by_id, recorded_by_name
         ) VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11)
         RETURNING *`,
        [businessId, product_id, product_name, quantity, unit || 'unit', type, reason || null,
         costImpact, remainingQuantity, recorded_by_id || null, recorded_by_name || null]
      );

      await client.query(
        `INSERT INTO inventory_history (business_id, inventory_id, change_type, quantity_change, quantity_after, notes, performed_by_id, performed_by_name, metadata)
         VALUES ($1, $2, 'restaurant_waste', $3, $4, $5, $6, $7, $8)`,
        [businessId, product_id, -quantity, remainingQuantity, reason || null, recorded_by_id || null,
         recorded_by_name || null, JSON.stringify({ type })]
      );

      await client.query('COMMIT');
      res.status(201).json(wasteResult.rows[0]);
    } catch (err) {
      await client.query('ROLLBACK');
      throw err;
    } finally {
      client.release();
    }
  }));

  return router;
};
