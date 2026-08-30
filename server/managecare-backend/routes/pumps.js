/**
 * Fuel pump API routes for ManageCare.
 * Pump configuration (CRUD), daily meter-reading reconciliation uploads,
 * the dispute-review workflow, and the append-only adjustment audit log.
 */
const express = require('express');
const router = express.Router();
const { requireFields, asyncHandler } = require('../middleware/validation');
const { requireBusinessMembership, requireBusinessOwner } = require('../middleware/auth');

module.exports = function(pool) {
  router.use('/:businessId', requireBusinessMembership(pool));

  // ---------- Pumps (configuration) ----------

  router.get('/:businessId/pumps', asyncHandler(async (req, res) => {
    const { businessId } = req.params;
    const { isActive } = req.query;
    let query = 'SELECT * FROM pumps WHERE business_id = $1';
    const params = [businessId];
    if (isActive === 'true') query += ' AND is_active = true';
    query += ' ORDER BY pump_number ASC';
    const result = await pool.query(query, params);
    res.json({ data: result.rows });
  }));

  router.post('/:businessId/pumps', requireFields('pump_number'), asyncHandler(async (req, res) => {
    const { businessId } = req.params;
    const { id, pump_number, product_id, product_name, product_unit, product_price, model, serial_number, manufacturer, manufacture_year } = req.body;

    const result = await pool.query(
      `INSERT INTO pumps (id, business_id, pump_number, product_id, product_name, product_unit, product_price, model, serial_number, manufacturer, manufacture_year)
       VALUES (COALESCE($1::uuid, uuid_generate_v4()), $2, $3, $4, $5, $6, $7, $8, $9, $10, $11)
       ON CONFLICT (id) DO UPDATE SET
         pump_number = EXCLUDED.pump_number, product_id = EXCLUDED.product_id, product_name = EXCLUDED.product_name,
         product_unit = EXCLUDED.product_unit, product_price = EXCLUDED.product_price, model = EXCLUDED.model,
         serial_number = EXCLUDED.serial_number, manufacturer = EXCLUDED.manufacturer,
         manufacture_year = EXCLUDED.manufacture_year, updated_at = NOW()
       RETURNING *`,
      [id || null, businessId, pump_number, product_id || null, product_name || null, product_unit || null,
       product_price || 0, model || null, serial_number || null, manufacturer || null, manufacture_year || null]
    );
    res.status(201).json(result.rows[0]);
  }));

  router.put('/:businessId/pumps/:id', asyncHandler(async (req, res) => {
    const { businessId, id } = req.params;
    const { pump_number, product_id, product_name, product_unit, product_price, model, serial_number, manufacturer, manufacture_year, is_active } = req.body;

    const fields = [];
    const params = [];
    let paramIndex = 1;
    const set = (col, val) => { if (val !== undefined) { fields.push(`${col} = $${paramIndex++}`); params.push(val); } };
    set('pump_number', pump_number);
    set('product_id', product_id);
    set('product_name', product_name);
    set('product_unit', product_unit);
    set('product_price', product_price);
    set('model', model);
    set('serial_number', serial_number);
    set('manufacturer', manufacturer);
    set('manufacture_year', manufacture_year);
    set('is_active', is_active);

    if (fields.length === 0) return res.status(400).json({ error: 'No fields to update' });
    fields.push('updated_at = NOW()');
    params.push(id, businessId);

    const result = await pool.query(
      `UPDATE pumps SET ${fields.join(', ')} WHERE id = $${paramIndex++} AND business_id = $${paramIndex} RETURNING *`,
      params
    );
    if (result.rows.length === 0) return res.status(404).json({ error: 'Pump not found' });
    res.json(result.rows[0]);
  }));

  // ---------- Pump daily uploads ----------

  router.get('/:businessId/uploads', asyncHandler(async (req, res) => {
    const { businessId } = req.params;
    const { pumpId, from, to, isDisputed, limit } = req.query;

    let query = 'SELECT * FROM pump_daily_uploads WHERE business_id = $1';
    const params = [businessId];
    let paramIndex = 2;
    if (pumpId) { query += ` AND pump_id = $${paramIndex++}`; params.push(pumpId); }
    if (from) { query += ` AND uploaded_at >= $${paramIndex++}`; params.push(from); }
    if (to) { query += ` AND uploaded_at <= $${paramIndex++}`; params.push(to); }
    if (isDisputed === 'true') query += ' AND is_disputed = true';
    if (isDisputed === 'false') query += ' AND is_disputed = false';
    query += ` ORDER BY uploaded_at DESC LIMIT $${paramIndex++}`;
    params.push(Math.min(500, parseInt(limit) || 200));

    const result = await pool.query(query, params);
    res.json({ data: result.rows });
  }));

  // GET /:businessId/uploads/latest?pumpId= - most recent upload for a pump (prefill)
  router.get('/:businessId/uploads/latest', asyncHandler(async (req, res) => {
    const { businessId } = req.params;
    const { pumpId } = req.query;
    if (!pumpId) return res.status(400).json({ error: 'pumpId is required' });

    const result = await pool.query(
      'SELECT * FROM pump_daily_uploads WHERE business_id = $1 AND pump_id = $2 ORDER BY uploaded_at DESC LIMIT 1',
      [businessId, pumpId]
    );
    res.json(result.rows[0] || null);
  }));

  // Client bookkeeping ids like "SALE-<timestamp>" (used for an offline
  // sale queued locally, before a real server id exists) are not valid
  // uuids - inserting one straight into a uuid column crashes the whole
  // upload with a 500. Treat anything that isn't a real uuid as absent
  // instead, same pattern sales.js already uses for its own id column.
  const UUID_RE = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;
  const asUuidOrNull = (v) => (v && UUID_RE.test(v) ? v : null);

  router.post('/:businessId/uploads', requireFields('pump_id'), asyncHandler(async (req, res) => {
    const { businessId } = req.params;
    const b = req.body;

    const closingVolume = parseFloat(b.closing_volume) || 0;
    const openingVolume = parseFloat(b.opening_volume) || 0;
    if (closingVolume <= openingVolume) {
      return res.status(400).json({ error: 'Closing volume must be greater than opening volume' });
    }

    try {
      const expectedAmount = Number.parseFloat(b.expected_amount) || 0;
      const totalPaid = Number.parseFloat(b.total_paid) || 0;
      if (expectedAmount > 0 || totalPaid > 0) {
        const duplicate = await pool.query(
          `SELECT *
           FROM pump_daily_uploads
           WHERE business_id = $1
             AND pump_id = $2
             AND uploaded_at >= NOW() - INTERVAL '2 minutes'
             AND ABS(COALESCE(expected_amount, 0) - $3) < 0.01
             AND ABS(COALESCE(total_paid, 0) - $4) < 0.01
           ORDER BY uploaded_at DESC
           LIMIT 1`,
          [businessId, b.pump_id, expectedAmount, totalPaid]
        );
        if (duplicate.rows.length > 0) {
          return res.status(409).json({ error: 'A matching pump upload was already recorded moments ago.' });
        }
      }

      const result = await pool.query(
        `INSERT INTO pump_daily_uploads (
           business_id, pump_id, pump_number, product_id, product_name, product_unit, product_price,
           worker_id, worker_name, upload_fingerprint, sale_id,
           opening_volume, closing_volume, digital_volume, volume_difference, analog_opening_volume,
           analog_closing_volume, sold_volume, cash_derived_volume, previous_analog_closing_volume,
           previous_shift_closing_cash, previous_closing_volume, expected_amount, shift_opening_cash,
           shift_close_cash, shift_cash_difference, today_pump_cash, cash_amount, pos_amount, total_paid,
           cash_breakdown, discrepancy_notes, discrepancy_summary,
           shift_opening_cash_photo_url, shift_close_cash_photo_url, opening_photo_url, closing_photo_url
         ) VALUES (
           $1, $2, $3, $4, $5, $6, $7,
           $8, $9, $10, $11,
           $12, $13, $14, $15, $16,
           $17, $18, $19, $20,
           $21, $22, $23, $24,
           $25, $26, $27, $28, $29, $30,
           COALESCE($31::jsonb, '[]'::jsonb), COALESCE($32::jsonb, '[]'::jsonb), $33,
           $34, $35, $36, $37
         )
         RETURNING *`,
        [
          businessId, b.pump_id, b.pump_number || null, asUuidOrNull(b.product_id), b.product_name || null, b.product_unit || null, b.product_price || 0,
          asUuidOrNull(b.worker_id), b.worker_name || null, b.upload_fingerprint || null, asUuidOrNull(b.sale_id),
          b.opening_volume || 0, b.closing_volume || 0, b.digital_volume || 0, b.volume_difference || 0, b.analog_opening_volume || 0,
          b.analog_closing_volume || 0, b.sold_volume || 0, b.cash_derived_volume || 0, b.previous_analog_closing_volume ?? null,
          b.previous_shift_closing_cash ?? null, b.previous_closing_volume ?? null, b.expected_amount || 0, b.shift_opening_cash || 0,
          b.shift_close_cash || 0, b.shift_cash_difference || 0, b.today_pump_cash || 0, b.cash_amount || 0, b.pos_amount || 0, b.total_paid || 0,
          b.cash_breakdown ? JSON.stringify(b.cash_breakdown) : null, b.discrepancy_notes ? JSON.stringify(b.discrepancy_notes) : null, b.discrepancy_summary || null,
          b.shift_opening_cash_photo_url || null, b.shift_close_cash_photo_url || null, b.opening_photo_url || null, b.closing_photo_url || null,
        ]
      );
      res.status(201).json(result.rows[0]);
    } catch (err) {
      if (err.code === '23505') {
        return res.status(409).json({ error: 'This upload has already been submitted (duplicate detected).' });
      }
      throw err;
    }
  }));

  // PATCH /:businessId/uploads/:id/dispute - mark as disputed
  router.patch('/:businessId/uploads/:id/dispute', asyncHandler(async (req, res) => {
    const { businessId, id } = req.params;
    const { disputed_by, disputed_by_name, dispute_reason } = req.body;

    const client = await pool.connect();
    try {
      await client.query('BEGIN');
      const result = await client.query(
        `UPDATE pump_daily_uploads SET
           is_disputed = true, disputed_at = NOW(), disputed_by = $1, disputed_by_name = $2,
           dispute_reason = $3, updated_at = NOW()
         WHERE id = $4 AND business_id = $5 RETURNING *`,
        [disputed_by || null, disputed_by_name || null, dispute_reason || null, id, businessId]
      );
      if (result.rows.length === 0) {
        await client.query('ROLLBACK');
        return res.status(404).json({ error: 'Upload not found' });
      }
      const upload = result.rows[0];
      await client.query(
        `INSERT INTO pump_upload_adjustments (business_id, upload_id, pump_id, pump_number, product_name, uploaded_at, action, changes, note, adjusted_by, adjusted_by_name)
         VALUES ($1, $2, $3, $4, $5, $6, 'disputed', '[]'::jsonb, $7, $8, $9)`,
        [businessId, id, upload.pump_id, upload.pump_number, upload.product_name, upload.uploaded_at,
         dispute_reason || null, disputed_by || null, disputed_by_name || null]
      );
      await client.query('COMMIT');
      res.json(upload);
    } catch (err) {
      await client.query('ROLLBACK');
      throw err;
    } finally {
      client.release();
    }
  }));

  // PATCH /:businessId/uploads/:id/adjust - reviewer overwrites raw figures, server recomputes derived fields
  router.patch('/:businessId/uploads/:id/adjust', asyncHandler(async (req, res) => {
    const { businessId, id } = req.params;
    const { updates, note, adjusted_by, adjusted_by_name } = req.body;
    const editable = ['shift_opening_cash', 'shift_close_cash', 'opening_volume', 'closing_volume',
      'analog_opening_volume', 'analog_closing_volume', 'sold_volume', 'cash_amount', 'pos_amount'];

    if (!updates || typeof updates !== 'object' || Object.keys(updates).length === 0) {
      return res.status(400).json({ error: 'updates must be a non-empty object' });
    }

    const client = await pool.connect();
    try {
      await client.query('BEGIN');
      const existingResult = await client.query(
        'SELECT * FROM pump_daily_uploads WHERE id = $1 AND business_id = $2 FOR UPDATE',
        [id, businessId]
      );
      if (existingResult.rows.length === 0) {
        await client.query('ROLLBACK');
        return res.status(404).json({ error: 'Upload not found' });
      }
      const existing = existingResult.rows[0];

      const changes = [];
      const merged = { ...existing };
      for (const field of editable) {
        if (updates[field] === undefined) continue;
        const oldValue = parseFloat(existing[field]) || 0;
        const newValue = parseFloat(updates[field]) || 0;
        if (oldValue === newValue) continue;
        changes.push({ field: toCamel(field), oldValue, newValue });
        merged[field] = newValue;
      }

      const digitalVolume = parseFloat(merged.closing_volume) - parseFloat(merged.opening_volume);
      if (digitalVolume <= 0) {
        await client.query('ROLLBACK');
        return res.status(400).json({ error: 'Closing volume must be greater than opening volume' });
      }
      const shiftCashDifference = parseFloat(merged.shift_close_cash) - parseFloat(merged.shift_opening_cash);
      const expectedAmount = Math.max(0, Math.round(shiftCashDifference * 100) / 100);
      const totalPaid = parseFloat(merged.cash_amount) + parseFloat(merged.pos_amount);

      const result = await client.query(
        `UPDATE pump_daily_uploads SET
           shift_opening_cash = $1, shift_close_cash = $2, opening_volume = $3, closing_volume = $4,
           analog_opening_volume = $5, analog_closing_volume = $6, sold_volume = $7, cash_amount = $8, pos_amount = $9,
           digital_volume = $10, volume_difference = $10, shift_cash_difference = $11, expected_amount = $12,
           cash_derived_volume = $7, today_pump_cash = $8, total_paid = $13, updated_at = NOW()
         WHERE id = $14 AND business_id = $15
         RETURNING *`,
        [merged.shift_opening_cash, merged.shift_close_cash, merged.opening_volume, merged.closing_volume,
         merged.analog_opening_volume, merged.analog_closing_volume, merged.sold_volume, merged.cash_amount, merged.pos_amount,
         digitalVolume, shiftCashDifference, expectedAmount, totalPaid, id, businessId]
      );
      const upload = result.rows[0];

      await client.query(
        `INSERT INTO pump_upload_adjustments (business_id, upload_id, pump_id, pump_number, product_name, uploaded_at, action, changes, note, adjusted_by, adjusted_by_name)
         VALUES ($1, $2, $3, $4, $5, $6, 'adjusted', $7::jsonb, $8, $9, $10)`,
        [businessId, id, upload.pump_id, upload.pump_number, upload.product_name, upload.uploaded_at,
         JSON.stringify(changes), note || null, adjusted_by || null, adjusted_by_name || null]
      );
      await client.query('COMMIT');
      res.json(upload);
    } catch (err) {
      await client.query('ROLLBACK');
      throw err;
    } finally {
      client.release();
    }
  }));

  // PATCH /:businessId/uploads/:id/resolve - clear the dispute flag
  router.patch('/:businessId/uploads/:id/resolve', asyncHandler(async (req, res) => {
    const { businessId, id } = req.params;
    const { note, resolved_by, resolved_by_name } = req.body;

    const client = await pool.connect();
    try {
      await client.query('BEGIN');
      const result = await client.query(
        `UPDATE pump_daily_uploads SET
           is_disputed = false, dispute_resolved_at = NOW(), dispute_resolved_by = $1, dispute_resolved_by_name = $2,
           updated_at = NOW()
         WHERE id = $3 AND business_id = $4 RETURNING *`,
        [resolved_by || null, resolved_by_name || null, id, businessId]
      );
      if (result.rows.length === 0) {
        await client.query('ROLLBACK');
        return res.status(404).json({ error: 'Upload not found' });
      }
      const upload = result.rows[0];
      await client.query(
        `INSERT INTO pump_upload_adjustments (business_id, upload_id, pump_id, pump_number, product_name, uploaded_at, action, changes, note, adjusted_by, adjusted_by_name)
         VALUES ($1, $2, $3, $4, $5, $6, 'resolved', '[]'::jsonb, $7, $8, $9)`,
        [businessId, id, upload.pump_id, upload.pump_number, upload.product_name, upload.uploaded_at,
         note || null, resolved_by || null, resolved_by_name || null]
      );
      await client.query('COMMIT');
      res.json(upload);
    } catch (err) {
      await client.query('ROLLBACK');
      throw err;
    } finally {
      client.release();
    }
  }));

  // DELETE /:businessId/uploads/:id - owner-only hard delete. The upload's
  // sold_volume was already decremented from inventory when the matching
  // sale was created, so deleting the upload without adding it back left
  // the fuel stock permanently short by whatever that upload sold.
  router.delete('/:businessId/uploads/:id', requireBusinessOwner, asyncHandler(async (req, res) => {
    const { businessId, id } = req.params;
    const client = await pool.connect();
    try {
      await client.query('BEGIN');
      const result = await client.query(
        'DELETE FROM pump_daily_uploads WHERE id = $1 AND business_id = $2 RETURNING id, product_id, sold_volume',
        [id, businessId]
      );
      if (result.rows.length === 0) {
        await client.query('ROLLBACK');
        return res.status(404).json({ error: 'Upload not found' });
      }
      const deleted = result.rows[0];
      const soldVolume = parseFloat(deleted.sold_volume) || 0;
      if (deleted.product_id && soldVolume > 0) {
        await client.query(
          'UPDATE inventory SET quantity = quantity + $1, updated_at = NOW() WHERE id = $2 AND business_id = $3',
          [soldVolume, deleted.product_id, businessId]
        );
      }
      await client.query('COMMIT');
      res.json({ message: 'Upload deleted', id });
    } catch (err) {
      await client.query('ROLLBACK');
      throw err;
    } finally {
      client.release();
    }
  }));

  // ---------- Bank deposits ----------

  router.get('/:businessId/bank-deposits', asyncHandler(async (req, res) => {
    const { businessId } = req.params;
    const { limit } = req.query;
    const result = await pool.query(
      `SELECT * FROM petroleum_bank_deposits
       WHERE business_id = $1
       ORDER BY deposit_date DESC, deposit_time DESC, created_at DESC
       LIMIT $2`,
      [businessId, Math.min(500, parseInt(limit) || 100)]
    );
    res.json({ data: result.rows });
  }));

  router.post('/:businessId/bank-deposits', requireFields('depositor_name', 'amount', 'bank_name'), asyncHandler(async (req, res) => {
    const { businessId } = req.params;
    const b = req.body;
    const result = await pool.query(
      `INSERT INTO petroleum_bank_deposits (
         business_id, depositor_name, deposit_date, deposit_time, amount,
         bank_name, account_number, account_name, receipt_url,
         recorded_by, recorded_by_name
       ) VALUES (
         $1, $2, COALESCE($3::date, CURRENT_DATE), COALESCE($4::time, CURRENT_TIME), $5,
         $6, $7, $8, $9, $10, $11
       )
       RETURNING *`,
      [
        businessId,
        b.depositor_name,
        b.deposit_date || null,
        b.deposit_time || null,
        b.amount || 0,
        b.bank_name,
        b.account_number || null,
        b.account_name || null,
        b.receipt_url || null,
        asUuidOrNull(b.recorded_by),
        b.recorded_by_name || null,
      ]
    );
    res.status(201).json(result.rows[0]);
  }));

  // ---------- Adjustment audit log ----------

  router.get('/:businessId/upload-adjustments', asyncHandler(async (req, res) => {
    const { businessId } = req.params;
    const { uploadId, limit } = req.query;
    let query = 'SELECT * FROM pump_upload_adjustments WHERE business_id = $1';
    const params = [businessId];
    let paramIndex = 2;
    if (uploadId) { query += ` AND upload_id = $${paramIndex++}`; params.push(uploadId); }
    query += ` ORDER BY adjusted_at DESC LIMIT $${paramIndex++}`;
    params.push(Math.min(500, parseInt(limit) || 200));
    const result = await pool.query(query, params);
    res.json({ data: result.rows });
  }));

  return router;
};

function toCamel(snake) {
  return snake.replace(/_([a-z])/g, (_, c) => c.toUpperCase());
}
