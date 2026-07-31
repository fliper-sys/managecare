/**
 * Apartment management API routes for ManageCare.
 */
const express = require('express');
const router = express.Router();
const { requireFields, asyncHandler } = require('../middleware/validation');
const { requireBusinessMembership } = require('../middleware/auth');

function setFields(body, allowed) {
  const fields = [];
  const params = [];
  Object.entries(allowed).forEach(([key, column]) => {
    if (Object.prototype.hasOwnProperty.call(body, key)) {
      params.push(body[key]);
      fields.push(`${column} = $${params.length}`);
    }
  });
  return { fields, params };
}

function arrayJson(value) {
  return JSON.stringify(Array.isArray(value) ? value : []);
}

function objectJson(value) {
  return JSON.stringify(value && typeof value === 'object' ? value : {});
}

module.exports = function(pool) {
  router.use('/:businessId', requireBusinessMembership(pool));

  router.get('/:businessId', asyncHandler(async (req, res) => {
    const result = await pool.query(
      'SELECT * FROM apartments WHERE business_id = $1 ORDER BY created_at DESC',
      [req.params.businessId]
    );
    res.json({ data: result.rows });
  }));

  router.post('/:businessId', requireFields('title'), asyncHandler(async (req, res) => {
    const { businessId } = req.params;
    const {
      id,
      title,
      description,
      ownerId,
      address,
      photos,
      amenities,
      defaultCancellationPolicyId,
    } = req.body;

    const result = await pool.query(`
      INSERT INTO apartments (
        id, business_id, title, description, owner_id, address,
        photos, amenities, default_cancellation_policy_id
      )
      VALUES (
        COALESCE($1::uuid, uuid_generate_v4()), $2, $3, $4, $5, $6,
        COALESCE($7::jsonb, '[]'::jsonb), COALESCE($8::jsonb, '[]'::jsonb), $9
      )
      RETURNING *
    `, [
      id || null,
      businessId,
      title,
      description || '',
      ownerId || null,
      address || '',
      arrayJson(photos),
      arrayJson(amenities),
      defaultCancellationPolicyId || null,
    ]);
    res.status(201).json(result.rows[0]);
  }));

  router.get('/:businessId/availability', asyncHandler(async (req, res) => {
    const { businessId } = req.params;
    const { unitId, checkIn, checkOut } = req.query;
    if (!unitId || !checkIn || !checkOut) {
      return res.status(400).json({ error: 'unitId, checkIn and checkOut are required' });
    }

    const result = await pool.query(`
      SELECT COUNT(*)::INTEGER AS conflicts
      FROM apartment_bookings
      WHERE business_id = $1
        AND unit_id = $2
        AND status IN ('pending', 'confirmed', 'checkedIn')
        AND check_in_date < $4::TIMESTAMPTZ
        AND check_out_date > $3::TIMESTAMPTZ
    `, [businessId, unitId, checkIn, checkOut]);
    res.json({ available: (result.rows[0].conflicts || 0) === 0 });
  }));

  router.get('/:businessId/bookings', asyncHandler(async (req, res) => {
    const { businessId } = req.params;
    const { apartmentId, unitId } = req.query;
    const limit = Math.min(parseInt(req.query.limit, 10) || 100, 500);
    const params = [businessId];
    const where = ['business_id = $1'];
    if (apartmentId) {
      params.push(apartmentId);
      where.push(`apartment_id = $${params.length}`);
    }
    if (unitId) {
      params.push(unitId);
      where.push(`unit_id = $${params.length}`);
    }
    params.push(limit);
    const result = await pool.query(`
      SELECT *
      FROM apartment_bookings
      WHERE ${where.join(' AND ')}
      ORDER BY created_at DESC
      LIMIT $${params.length}
    `, params);
    res.json({ data: result.rows });
  }));

  router.post('/:businessId/bookings', requireFields('unitId', 'apartmentId', 'checkInDate', 'checkOutDate'), asyncHandler(async (req, res) => {
    const { businessId } = req.params;
    const client = await pool.connect();
    try {
      await client.query('BEGIN');
      const conflict = await client.query(`
        SELECT id
        FROM apartment_bookings
        WHERE business_id = $1
          AND unit_id = $2
          AND status IN ('pending', 'confirmed', 'checkedIn')
          AND check_in_date < $4::TIMESTAMPTZ
          AND check_out_date > $3::TIMESTAMPTZ
        LIMIT 1
        FOR UPDATE
      `, [businessId, req.body.unitId, req.body.checkInDate, req.body.checkOutDate]);

      if (conflict.rows.length > 0) {
        await client.query('ROLLBACK');
        return res.status(409).json({ error: 'Requested dates overlap with an existing booking' });
      }

      const result = await client.query(`
        INSERT INTO apartment_bookings (
          id, business_id, unit_id, apartment_id, tenant_id, check_in_date,
          check_out_date, nights, guests, status, subtotal, deposit_amount,
          discount, total, currency, payment_status, payment_method,
          provider_transaction_id, paid_at, policy_snapshot, receipt_url,
          receipt_pdf_path, next_reminder_at, reminder_sent_flags, created_at
        )
        VALUES (
          COALESCE($1::uuid, uuid_generate_v4()), $2, $3, $4, $5,
          $6::TIMESTAMPTZ, $7::TIMESTAMPTZ, $8, $9, $10, $11, $12,
          $13, $14, $15, $16, $17, $18, $19::TIMESTAMPTZ,
          COALESCE($20::jsonb, '{}'::jsonb), $21, $22, $23::TIMESTAMPTZ,
          COALESCE($24::jsonb, '{}'::jsonb), COALESCE($25::TIMESTAMPTZ, NOW())
        )
        RETURNING *
      `, [
        req.body.id || null,
        businessId,
        req.body.unitId,
        req.body.apartmentId,
        req.body.tenantId || null,
        req.body.checkInDate,
        req.body.checkOutDate,
        req.body.nights || 0,
        req.body.guests || 1,
        req.body.requirePayment ? 'pending' : (req.body.status || 'pending'),
        req.body.subtotal || 0,
        req.body.depositAmount || 0,
        req.body.discount || 0,
        req.body.total || 0,
        req.body.currency || 'NGN',
        req.body.requirePayment ? 'pending' : (req.body.paymentStatus || 'none'),
        req.body.paymentMethod || null,
        req.body.providerTransactionId || null,
        req.body.paidAt || null,
        objectJson(req.body.policySnapshot),
        req.body.receiptUrl || null,
        req.body.receiptPdfPath || null,
        req.body.nextReminderAt || null,
        objectJson(req.body.reminderSentFlags),
        req.body.createdAt || null,
      ]);
      await client.query('COMMIT');
      res.status(201).json(result.rows[0]);
    } catch (error) {
      await client.query('ROLLBACK');
      throw error;
    } finally {
      client.release();
    }
  }));

  router.get('/:businessId/bookings/:id', asyncHandler(async (req, res) => {
    const result = await pool.query(
      'SELECT * FROM apartment_bookings WHERE id = $1 AND business_id = $2',
      [req.params.id, req.params.businessId]
    );
    if (result.rows.length === 0) return res.status(404).json({ error: 'Booking not found' });
    res.json(result.rows[0]);
  }));

  router.patch('/:businessId/bookings/:id', asyncHandler(async (req, res) => {
    const allowed = {
      status: 'status',
      cancelReason: 'cancel_reason',
      paymentStatus: 'payment_status',
      paymentMethod: 'payment_method',
      providerTransactionId: 'provider_transaction_id',
      receiptUrl: 'receipt_url',
      receiptPdfPath: 'receipt_pdf_path',
      paidAt: 'paid_at',
      nextReminderAt: 'next_reminder_at',
    };
    const { fields, params } = setFields(req.body || {}, allowed);
    if (req.body?.reminderSentFlags !== undefined) {
      params.push(objectJson(req.body.reminderSentFlags));
      fields.push(`reminder_sent_flags = $${params.length}::jsonb`);
    }
    if (fields.length === 0) return res.status(400).json({ error: 'No fields to update' });
    fields.push('updated_at = NOW()');
    params.push(req.params.id, req.params.businessId);
    const result = await pool.query(`
      UPDATE apartment_bookings
      SET ${fields.join(', ')}
      WHERE id = $${params.length - 1} AND business_id = $${params.length}
      RETURNING *
    `, params);
    if (result.rows.length === 0) return res.status(404).json({ error: 'Booking not found' });
    res.json(result.rows[0]);
  }));

  router.get('/:businessId/bookings/:id/payments', asyncHandler(async (req, res) => {
    const result = await pool.query(
      'SELECT * FROM apartment_booking_payments WHERE booking_id = $1 AND business_id = $2 ORDER BY created_at DESC',
      [req.params.id, req.params.businessId]
    );
    res.json({ data: result.rows });
  }));

  router.post('/:businessId/bookings/:id/payments', requireFields('amount'), asyncHandler(async (req, res) => {
    const { businessId, id } = req.params;
    const {
      amount, currency, provider, transactionId, processorResponse, status,
    } = req.body;

    const result = await pool.query(`
      INSERT INTO apartment_booking_payments (
        business_id, booking_id, amount, currency, provider,
        transaction_id, processor_response, status
      )
      VALUES ($1, $2, $3, $4, $5, $6, COALESCE($7::jsonb, '{}'::jsonb), $8)
      RETURNING *
    `, [
      businessId,
      id,
      amount,
      currency || 'NGN',
      provider || null,
      transactionId || null,
      objectJson(processorResponse),
      status || 'completed',
    ]);
    res.status(201).json(result.rows[0]);
  }));

  router.get('/:businessId/:apartmentId/units', asyncHandler(async (req, res) => {
    const result = await pool.query(
      'SELECT * FROM apartment_units WHERE business_id = $1 AND apartment_id = $2 ORDER BY name ASC',
      [req.params.businessId, req.params.apartmentId]
    );
    res.json({ data: result.rows });
  }));

  router.post('/:businessId/:apartmentId/units', requireFields('name'), asyncHandler(async (req, res) => {
    const result = await pool.query(`
      INSERT INTO apartment_units (
        id, business_id, apartment_id, name, capacity, price_per_night,
        available_from, available_to, photos, active
      )
      VALUES (
        COALESCE($1::uuid, uuid_generate_v4()), $2, $3, $4, $5, $6,
        $7::TIMESTAMPTZ, $8::TIMESTAMPTZ, COALESCE($9::jsonb, '[]'::jsonb), $10
      )
      RETURNING *
    `, [
      req.body.id || null,
      req.params.businessId,
      req.params.apartmentId,
      req.body.name,
      req.body.capacity || 1,
      req.body.pricePerNight || req.body.price_per_night || 0,
      req.body.availableFrom || null,
      req.body.availableTo || null,
      arrayJson(req.body.photos),
      req.body.active !== false,
    ]);
    res.status(201).json(result.rows[0]);
  }));

  router.patch('/:businessId/:apartmentId/units/:unitId', asyncHandler(async (req, res) => {
    const allowed = {
      name: 'name',
      capacity: 'capacity',
      pricePerNight: 'price_per_night',
      price_per_night: 'price_per_night',
      availableFrom: 'available_from',
      availableTo: 'available_to',
      active: 'active',
    };
    const { fields, params } = setFields(req.body || {}, allowed);
    if (req.body?.photos !== undefined) {
      params.push(arrayJson(req.body.photos));
      fields.push(`photos = $${params.length}::jsonb`);
    }
    if (fields.length === 0) return res.status(400).json({ error: 'No fields to update' });
    fields.push('updated_at = NOW()');
    params.push(req.params.unitId, req.params.apartmentId, req.params.businessId);
    const result = await pool.query(`
      UPDATE apartment_units
      SET ${fields.join(', ')}
      WHERE id = $${params.length - 2}
        AND apartment_id = $${params.length - 1}
        AND business_id = $${params.length}
      RETURNING *
    `, params);
    if (result.rows.length === 0) return res.status(404).json({ error: 'Unit not found' });
    res.json(result.rows[0]);
  }));

  router.delete('/:businessId/:apartmentId/units/:unitId', asyncHandler(async (req, res) => {
    const result = await pool.query(
      'DELETE FROM apartment_units WHERE id = $1 AND apartment_id = $2 AND business_id = $3 RETURNING id',
      [req.params.unitId, req.params.apartmentId, req.params.businessId]
    );
    if (result.rows.length === 0) return res.status(404).json({ error: 'Unit not found' });
    res.json({ id: req.params.unitId, deleted: true });
  }));

  router.patch('/:businessId/:apartmentId', asyncHandler(async (req, res) => {
    const allowed = {
      title: 'title',
      description: 'description',
      ownerId: 'owner_id',
      address: 'address',
      defaultCancellationPolicyId: 'default_cancellation_policy_id',
    };
    const { fields, params } = setFields(req.body || {}, allowed);
    if (req.body?.photos !== undefined) {
      params.push(arrayJson(req.body.photos));
      fields.push(`photos = $${params.length}::jsonb`);
    }
    if (req.body?.amenities !== undefined) {
      params.push(arrayJson(req.body.amenities));
      fields.push(`amenities = $${params.length}::jsonb`);
    }
    if (fields.length === 0) return res.status(400).json({ error: 'No fields to update' });
    fields.push('updated_at = NOW()');
    params.push(req.params.apartmentId, req.params.businessId);
    const result = await pool.query(`
      UPDATE apartments
      SET ${fields.join(', ')}
      WHERE id = $${params.length - 1} AND business_id = $${params.length}
      RETURNING *
    `, params);
    if (result.rows.length === 0) return res.status(404).json({ error: 'Apartment not found' });
    res.json(result.rows[0]);
  }));

  router.delete('/:businessId/:apartmentId', asyncHandler(async (req, res) => {
    const result = await pool.query(
      'DELETE FROM apartments WHERE id = $1 AND business_id = $2 RETURNING id',
      [req.params.apartmentId, req.params.businessId]
    );
    if (result.rows.length === 0) return res.status(404).json({ error: 'Apartment not found' });
    res.json({ id: req.params.apartmentId, deleted: true });
  }));

  return router;
};
