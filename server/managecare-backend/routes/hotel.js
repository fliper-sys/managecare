/**
 * Hotel vertical API routes for ManageCare.
 * Rooms, reservations, service orders, folio charges, and a denormalized
 * guest-profile sync table.
 */
const express = require('express');
const router = express.Router();
const { requireFields, asyncHandler } = require('../middleware/validation');
const { requireBusinessMembership } = require('../middleware/auth');

module.exports = function(pool) {
  router.use('/:businessId', requireBusinessMembership(pool));

  // ---------- Rooms ----------

  router.get('/:businessId/rooms', asyncHandler(async (req, res) => {
    const result = await pool.query(
      'SELECT * FROM hotel_rooms WHERE business_id = $1 ORDER BY number ASC',
      [req.params.businessId]
    );
    res.json({ data: result.rows });
  }));

  router.post('/:businessId/rooms', requireFields('number'), asyncHandler(async (req, res) => {
    const { businessId } = req.params;
    const {
      id, number, type, capacity, price_per_night, half_day_price, status, emoji, amenities, images,
      price_intervals, floor, rating, size, bed_size, extra_details, half_day_hours, full_day_checkout_time,
    } = req.body;

    const result = await pool.query(
      `INSERT INTO hotel_rooms (
         id, business_id, number, type, capacity, price_per_night, half_day_price, status, emoji, amenities,
         images, price_intervals, floor, rating, size, bed_size, extra_details, half_day_hours, full_day_checkout_time
       )
       VALUES (
         COALESCE($1::uuid, uuid_generate_v4()), $2, $3, $4, $5, $6, $7, $8, $9,
         COALESCE($10::jsonb, '[]'::jsonb), COALESCE($11::jsonb, '[]'::jsonb), COALESCE($12::jsonb, '[]'::jsonb),
         $13, $14, $15, $16, COALESCE($17::jsonb, '{}'::jsonb), $18, $19
       )
       ON CONFLICT (id) DO UPDATE SET
         number = EXCLUDED.number, type = EXCLUDED.type, capacity = EXCLUDED.capacity, price_per_night = EXCLUDED.price_per_night,
         half_day_price = EXCLUDED.half_day_price,
         status = EXCLUDED.status, emoji = EXCLUDED.emoji, amenities = EXCLUDED.amenities, images = EXCLUDED.images,
         price_intervals = EXCLUDED.price_intervals, floor = EXCLUDED.floor, rating = EXCLUDED.rating,
         size = EXCLUDED.size, bed_size = EXCLUDED.bed_size, extra_details = EXCLUDED.extra_details,
         half_day_hours = EXCLUDED.half_day_hours, full_day_checkout_time = EXCLUDED.full_day_checkout_time,
         updated_at = NOW()
       RETURNING *`,
      [id || null, businessId, number, type || 'single', capacity || 1, price_per_night || 0, half_day_price || 0,
       status || 'available', emoji || null, amenities ? JSON.stringify(amenities) : null, images ? JSON.stringify(images) : null,
       price_intervals ? JSON.stringify(price_intervals) : null, floor || 1, rating ?? 4.5, size || null, bed_size || null,
       extra_details ? JSON.stringify(extra_details) : null, half_day_hours || 12, full_day_checkout_time || '12:00']
    );
    res.status(201).json(result.rows[0]);
  }));

  router.put('/:businessId/rooms/:id', asyncHandler(async (req, res) => {
    const { businessId, id } = req.params;
    const {
      number, type, capacity, price_per_night, half_day_price, status, emoji, amenities, images,
      price_intervals, floor, rating, size, bed_size, extra_details, half_day_hours, full_day_checkout_time,
    } = req.body;

    const fields = [];
    const params = [];
    let paramIndex = 1;
    const set = (col, val) => { if (val !== undefined) { fields.push(`${col} = $${paramIndex++}`); params.push(val); } };
    set('number', number);
    set('type', type);
    set('capacity', capacity);
    set('price_per_night', price_per_night);
    set('half_day_price', half_day_price);
    set('status', status);
    set('emoji', emoji);
    set('floor', floor);
    set('rating', rating);
    set('size', size);
    set('bed_size', bed_size);
    set('half_day_hours', half_day_hours);
    set('full_day_checkout_time', full_day_checkout_time);
    if (amenities !== undefined) { fields.push(`amenities = $${paramIndex++}`); params.push(JSON.stringify(amenities)); }
    if (images !== undefined) { fields.push(`images = $${paramIndex++}`); params.push(JSON.stringify(images)); }
    if (price_intervals !== undefined) { fields.push(`price_intervals = $${paramIndex++}`); params.push(JSON.stringify(price_intervals)); }
    if (extra_details !== undefined) { fields.push(`extra_details = $${paramIndex++}`); params.push(JSON.stringify(extra_details)); }

    if (fields.length === 0) return res.status(400).json({ error: 'No fields to update' });
    fields.push('updated_at = NOW()');
    params.push(id, businessId);

    const result = await pool.query(
      `UPDATE hotel_rooms SET ${fields.join(', ')} WHERE id = $${paramIndex++} AND business_id = $${paramIndex} RETURNING *`,
      params
    );
    if (result.rows.length === 0) return res.status(404).json({ error: 'Room not found' });
    res.json(result.rows[0]);
  }));

  // ---------- Reservations ----------

  router.get('/:businessId/reservations', asyncHandler(async (req, res) => {
    const result = await pool.query(
      'SELECT * FROM hotel_reservations WHERE business_id = $1 ORDER BY check_in DESC',
      [req.params.businessId]
    );
    res.json({ data: result.rows });
  }));

  router.post('/:businessId/reservations', requireFields('guest_name', 'check_in', 'check_out'), asyncHandler(async (req, res) => {
    const { businessId } = req.params;
    const {
      id, room_id, room_number, guest_name, guest_email, guest_phone, guest_sex, occupant_count, guest_address, guest_nationality,
      guest_id_type, guest_id_number, next_of_kin_name, next_of_kin_phone, next_of_kin_relationship,
      booking_source, company_name, vehicle_plate_number, vehicle_make, vehicle_model, vehicle_year, vehicle_color,
      payment_method, mixed_payment_note, stay_duration_type, estimated_arrival_at,
      check_in, check_out, adults, children, status, total_price, special_requests, payment_status,
    } = req.body;

    const result = await pool.query(
      `INSERT INTO hotel_reservations (
         id, business_id, room_id, room_number, guest_name, guest_email, guest_phone, guest_sex, occupant_count, guest_address, guest_nationality,
         guest_id_type, guest_id_number, next_of_kin_name, next_of_kin_phone, next_of_kin_relationship,
         booking_source, company_name, vehicle_plate_number, vehicle_make, vehicle_model, vehicle_year, vehicle_color,
         payment_method, mixed_payment_note, stay_duration_type, estimated_arrival_at,
         check_in, check_out, adults, children, status, total_price, special_requests, payment_status
       ) VALUES (
         COALESCE($1::uuid, uuid_generate_v4()), $2, $3, $4, $5, $6, $7, $8, $9, $10, $11,
         $12, $13, $14, $15, $16,
         $17, $18, $19, $20, $21, $22, $23,
         $24, $25, $26, $27,
         $28, $29, $30, $31, $32, $33, COALESCE($34::jsonb, '[]'::jsonb), $35
       )
       RETURNING *`,
      [
        id || null, businessId, room_id || null, room_number || null, guest_name, guest_email || null,
        guest_phone || null, guest_sex || null, occupant_count || adults || 1, guest_address || null, guest_nationality || null,
        guest_id_type || null, guest_id_number || null, next_of_kin_name || null, next_of_kin_phone || null, next_of_kin_relationship || null,
        booking_source || 'walk-in', company_name || null, vehicle_plate_number || null, vehicle_make || null,
        vehicle_model || null, vehicle_year || null, vehicle_color || null, payment_method || 'cash', mixed_payment_note || null,
        stay_duration_type || 'full_day', estimated_arrival_at || null, check_in, check_out, adults || 1, children || 0,
        status || 'confirmed', total_price || 0, special_requests ? JSON.stringify(special_requests) : null,
        payment_status || 'unpaid',
      ]
    );
    res.status(201).json(result.rows[0]);
  }));

  router.put('/:businessId/reservations/:id', asyncHandler(async (req, res) => {
    const { businessId, id } = req.params;
    const {
      status, payment_status, payment_method, mixed_payment_note, stay_duration_type,
      estimated_arrival_at, check_out, total_price, special_requests, cancel_reason,
    } = req.body;

    const fields = [];
    const params = [];
    let paramIndex = 1;
    const set = (col, val) => { if (val !== undefined) { fields.push(`${col} = $${paramIndex++}`); params.push(val); } };
    set('status', status);
    set('payment_status', payment_status);
    set('payment_method', payment_method);
    set('mixed_payment_note', mixed_payment_note);
    set('stay_duration_type', stay_duration_type);
    set('estimated_arrival_at', estimated_arrival_at);
    set('check_out', check_out);
    set('total_price', total_price);
    set('cancel_reason', cancel_reason);
    if (special_requests !== undefined) { fields.push(`special_requests = $${paramIndex++}`); params.push(JSON.stringify(special_requests)); }

    if (fields.length === 0) return res.status(400).json({ error: 'No fields to update' });
    fields.push('updated_at = NOW()');
    params.push(id, businessId);

    const result = await pool.query(
      `UPDATE hotel_reservations SET ${fields.join(', ')} WHERE id = $${paramIndex++} AND business_id = $${paramIndex} RETURNING *`,
      params
    );
    if (result.rows.length === 0) return res.status(404).json({ error: 'Reservation not found' });
    res.json(result.rows[0]);
  }));

  // ---------- Service orders ----------

  router.get('/:businessId/service-orders', asyncHandler(async (req, res) => {
    const result = await pool.query(
      'SELECT * FROM hotel_service_orders WHERE business_id = $1 ORDER BY requested_at DESC',
      [req.params.businessId]
    );
    res.json({ data: result.rows });
  }));

  router.post('/:businessId/service-orders', requireFields('service_name'), asyncHandler(async (req, res) => {
    const { businessId } = req.params;
    const { id, room_id, reservation_id, service_name, description, status, priority, charge_amount, source, requested_at, completed_at } = req.body;

    const result = await pool.query(
      `INSERT INTO hotel_service_orders (id, business_id, room_id, reservation_id, service_name, description, status, priority, charge_amount, source, requested_at, completed_at)
       VALUES (COALESCE($1::uuid, uuid_generate_v4()), $2, $3, $4, $5, $6, $7, $8, $9, $10, COALESCE($11, NOW()), $12)
       ON CONFLICT (id) DO UPDATE SET
         status = EXCLUDED.status, priority = EXCLUDED.priority, charge_amount = EXCLUDED.charge_amount,
         completed_at = EXCLUDED.completed_at, updated_at = NOW()
       RETURNING *`,
      [id || null, businessId, room_id || null, reservation_id || null, service_name, description || null,
       status || 'pending', priority || 'medium', charge_amount ?? null, source || 'hotel_service', requested_at || null, completed_at || null]
    );
    res.status(201).json(result.rows[0]);
  }));

  router.put('/:businessId/service-orders/:id', asyncHandler(async (req, res) => {
    const { businessId, id } = req.params;
    const { status, completed_at, charge_amount } = req.body;

    const fields = [];
    const params = [];
    let paramIndex = 1;
    const set = (col, val) => { if (val !== undefined) { fields.push(`${col} = $${paramIndex++}`); params.push(val); } };
    set('status', status);
    set('completed_at', completed_at);
    set('charge_amount', charge_amount);

    if (fields.length === 0) return res.status(400).json({ error: 'No fields to update' });
    fields.push('updated_at = NOW()');
    params.push(id, businessId);

    const result = await pool.query(
      `UPDATE hotel_service_orders SET ${fields.join(', ')} WHERE id = $${paramIndex++} AND business_id = $${paramIndex} RETURNING *`,
      params
    );
    if (result.rows.length === 0) return res.status(404).json({ error: 'Service order not found' });
    res.json(result.rows[0]);
  }));

  // ---------- Folio charges ----------

  router.get('/:businessId/folio-charges', asyncHandler(async (req, res) => {
    const result = await pool.query(
      'SELECT * FROM hotel_folio_charges WHERE business_id = $1 ORDER BY created_at DESC',
      [req.params.businessId]
    );
    res.json({ data: result.rows });
  }));

  router.post('/:businessId/folio-charges', requireFields('reservation_id', 'description', 'amount'), asyncHandler(async (req, res) => {
    const { businessId } = req.params;
    const { reservation_id, room_id, room_number, description, amount, category, source, source_order_id, created_by_id, created_by_name, metadata } = req.body;

    const result = await pool.query(
      `INSERT INTO hotel_folio_charges (business_id, reservation_id, room_id, room_number, description, amount, category, source, source_order_id, created_by_id, created_by_name, metadata)
       VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11, COALESCE($12::jsonb, '{}'::jsonb))
       RETURNING *`,
      [businessId, reservation_id, room_id || null, room_number || null, description, amount,
       category || 'extra', source || 'manual', source_order_id || null, created_by_id || null,
       created_by_name || null, metadata ? JSON.stringify(metadata) : null]
    );
    res.status(201).json(result.rows[0]);
  }));

  // ---------- Guest profile sync (denormalized, write-mostly) ----------

  router.post('/:businessId/guests', requireFields('guest_key'), asyncHandler(async (req, res) => {
    const { businessId } = req.params;
    const {
      guest_key, guest_name, guest_email, guest_phone, guest_address, guest_nationality, guest_id_type,
      guest_id_number, next_of_kin_name, next_of_kin_phone, next_of_kin_relationship, booking_source,
      company_name, vehicle_plate_number, reservation_count, checked_in_count, total_spend, guest_tier,
      tier_discount_rate, active_reservation_id, current_room_id, current_room_number, last_check_in, last_check_out,
    } = req.body;

    const result = await pool.query(
      `INSERT INTO hotel_guests (
         business_id, guest_key, guest_name, guest_email, guest_phone, guest_address, guest_nationality, guest_id_type,
         guest_id_number, next_of_kin_name, next_of_kin_phone, next_of_kin_relationship, booking_source,
         company_name, vehicle_plate_number, reservation_count, checked_in_count, total_spend, guest_tier,
         tier_discount_rate, active_reservation_id, current_room_id, current_room_number, last_check_in, last_check_out
       ) VALUES (
         $1, $2, $3, $4, $5, $6, $7, $8,
         $9, $10, $11, $12, $13,
         $14, $15, $16, $17, $18, $19,
         $20, $21, $22, $23, $24, $25
       )
       ON CONFLICT (business_id, guest_key) DO UPDATE SET
         guest_name = EXCLUDED.guest_name, guest_email = EXCLUDED.guest_email, guest_phone = EXCLUDED.guest_phone,
         guest_address = EXCLUDED.guest_address, guest_nationality = EXCLUDED.guest_nationality,
         guest_id_type = EXCLUDED.guest_id_type, guest_id_number = EXCLUDED.guest_id_number,
         next_of_kin_name = EXCLUDED.next_of_kin_name, next_of_kin_phone = EXCLUDED.next_of_kin_phone,
         next_of_kin_relationship = EXCLUDED.next_of_kin_relationship, booking_source = EXCLUDED.booking_source,
         company_name = EXCLUDED.company_name, vehicle_plate_number = EXCLUDED.vehicle_plate_number,
         reservation_count = EXCLUDED.reservation_count, checked_in_count = EXCLUDED.checked_in_count,
         total_spend = EXCLUDED.total_spend, guest_tier = EXCLUDED.guest_tier, tier_discount_rate = EXCLUDED.tier_discount_rate,
         active_reservation_id = EXCLUDED.active_reservation_id, current_room_id = EXCLUDED.current_room_id,
         current_room_number = EXCLUDED.current_room_number, last_check_in = EXCLUDED.last_check_in,
         last_check_out = EXCLUDED.last_check_out, updated_at = NOW()
       RETURNING *`,
      [
        businessId, guest_key, guest_name || null, guest_email || null, guest_phone || null, guest_address || null,
        guest_nationality || null, guest_id_type || null, guest_id_number || null, next_of_kin_name || null,
        next_of_kin_phone || null, next_of_kin_relationship || null, booking_source || null, company_name || null,
        vehicle_plate_number || null, reservation_count || 0, checked_in_count || 0, total_spend || 0,
        guest_tier || null, tier_discount_rate ?? null, active_reservation_id || null, current_room_id || null,
        current_room_number || null, last_check_in || null, last_check_out || null,
      ]
    );
    res.status(201).json(result.rows[0]);
  }));

  return router;
};
