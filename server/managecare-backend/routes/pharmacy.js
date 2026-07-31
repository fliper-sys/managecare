/**
 * Pharmacy vertical API routes for ManageCare.
 *
 * Drugs are just inventory items (use the existing /api/inventory routes -
 * pharmacy-only fields like manufacturer/dosageForm/strength live in
 * inventory.metadata). This file covers what's genuinely pharmacy-specific:
 * patients, prescriptions, treatments, and the controlled-substance audit
 * log.
 */
const express = require('express');
const router = express.Router();
const { requireFields, asyncHandler } = require('../middleware/validation');
const { requireBusinessMembership } = require('../middleware/auth');

module.exports = function(pool) {
  router.use('/:businessId', requireBusinessMembership(pool));

  // ---------- Dashboard ----------

  // GET /api/pharmacy/:businessId/dashboard-stats
  router.get('/:businessId/dashboard-stats', asyncHandler(async (req, res) => {
    const { businessId } = req.params;

    const prescriptionsToday = await pool.query(
      `SELECT COUNT(*)::INTEGER AS count FROM pharmacy_prescriptions
       WHERE business_id = $1 AND created_at >= CURRENT_DATE AND created_at < CURRENT_DATE + INTERVAL '1 day'`,
      [businessId]
    );
    const expiringSoon = await pool.query(
      `SELECT COUNT(*)::INTEGER AS count FROM inventory
       WHERE business_id = $1 AND expiry_date IS NOT NULL
         AND expiry_date <= NOW() + INTERVAL '7 days' AND expiry_date > NOW()`,
      [businessId]
    );

    res.json({
      prescriptionsToday: prescriptionsToday.rows[0].count,
      expiringSoon: expiringSoon.rows[0].count,
    });
  }));

  // ---------- Patients ----------

  router.get('/:businessId/patients', asyncHandler(async (req, res) => {
    const result = await pool.query(
      'SELECT * FROM pharmacy_patients WHERE business_id = $1 ORDER BY name ASC',
      [req.params.businessId]
    );
    res.json({ data: result.rows });
  }));

  router.post('/:businessId/patients', requireFields('name'), asyncHandler(async (req, res) => {
    const { businessId } = req.params;
    const { id, name, phone, email, address, date_of_birth, allergies, blood_type, additional_notes } = req.body;

    const result = await pool.query(
      `INSERT INTO pharmacy_patients (id, business_id, name, phone, email, address, date_of_birth, allergies, blood_type, additional_notes)
       VALUES (COALESCE($1, uuid_generate_v4()), $2, $3, $4, $5, $6, $7, $8, $9, $10)
       ON CONFLICT (id) DO UPDATE SET
         name = EXCLUDED.name, phone = EXCLUDED.phone, email = EXCLUDED.email, address = EXCLUDED.address,
         date_of_birth = EXCLUDED.date_of_birth, allergies = EXCLUDED.allergies, blood_type = EXCLUDED.blood_type,
         additional_notes = EXCLUDED.additional_notes, updated_at = NOW()
       RETURNING *`,
      [id || null, businessId, name, phone || null, email || null, address || null,
       date_of_birth || null, allergies || null, blood_type || null, additional_notes || null]
    );
    res.status(201).json(result.rows[0]);
  }));

  router.put('/:businessId/patients/:id', asyncHandler(async (req, res) => {
    const { businessId, id } = req.params;
    const { name, phone, email, address, date_of_birth, allergies, blood_type, additional_notes } = req.body;

    const fields = [];
    const params = [];
    let paramIndex = 1;
    const set = (col, val) => {
      if (val !== undefined) { fields.push(`${col} = $${paramIndex++}`); params.push(val); }
    };
    set('name', name);
    set('phone', phone);
    set('email', email);
    set('address', address);
    set('date_of_birth', date_of_birth);
    set('allergies', allergies);
    set('blood_type', blood_type);
    set('additional_notes', additional_notes);

    if (fields.length === 0) {
      return res.status(400).json({ error: 'No fields to update' });
    }
    fields.push('updated_at = NOW()');
    params.push(id, businessId);

    const result = await pool.query(
      `UPDATE pharmacy_patients SET ${fields.join(', ')} WHERE id = $${paramIndex++} AND business_id = $${paramIndex} RETURNING *`,
      params
    );
    if (result.rows.length === 0) {
      return res.status(404).json({ error: 'Patient not found' });
    }
    res.json(result.rows[0]);
  }));

  // ---------- Prescriptions ----------

  router.get('/:businessId/prescriptions', asyncHandler(async (req, res) => {
    const result = await pool.query(
      'SELECT * FROM pharmacy_prescriptions WHERE business_id = $1 ORDER BY issued_at DESC',
      [req.params.businessId]
    );
    res.json({ data: result.rows });
  }));

  router.post('/:businessId/prescriptions', asyncHandler(async (req, res) => {
    const { businessId } = req.params;
    const {
      id, patient_id, patient_name, items, status, prescriber_id, prescriber_name,
      notes, attachment_reference, attachment_required, patient_date_of_birth, issued_at,
    } = req.body;

    const result = await pool.query(
      `INSERT INTO pharmacy_prescriptions (
         id, business_id, patient_id, patient_name, items, status, prescriber_id, prescriber_name,
         notes, attachment_reference, attachment_required, patient_date_of_birth, issued_at
       ) VALUES (COALESCE($1, uuid_generate_v4()), $2, $3, $4, $5, $6, $7, $8, $9, $10, $11, $12, COALESCE($13, NOW()))
       ON CONFLICT (id) DO UPDATE SET
         patient_id = EXCLUDED.patient_id, patient_name = EXCLUDED.patient_name, items = EXCLUDED.items,
         status = EXCLUDED.status, prescriber_id = EXCLUDED.prescriber_id, prescriber_name = EXCLUDED.prescriber_name,
         notes = EXCLUDED.notes, attachment_reference = EXCLUDED.attachment_reference,
         attachment_required = EXCLUDED.attachment_required, patient_date_of_birth = EXCLUDED.patient_date_of_birth,
         updated_at = NOW()
       RETURNING *`,
      [id || null, businessId, patient_id || null, patient_name || null, JSON.stringify(items || []),
       status || 'pending', prescriber_id || null, prescriber_name || null, notes || null,
       attachment_reference || null, attachment_required === true, patient_date_of_birth || null, issued_at || null]
    );
    res.status(201).json(result.rows[0]);
  }));

  router.put('/:businessId/prescriptions/:id', asyncHandler(async (req, res) => {
    const { businessId, id } = req.params;
    const { patient_id, patient_name, items, status, prescriber_id, prescriber_name,
      notes, attachment_reference, attachment_required } = req.body;

    const fields = [];
    const params = [];
    let paramIndex = 1;
    const set = (col, val) => {
      if (val !== undefined) { fields.push(`${col} = $${paramIndex++}`); params.push(val); }
    };
    set('patient_id', patient_id);
    set('patient_name', patient_name);
    if (items !== undefined) { fields.push(`items = $${paramIndex++}`); params.push(JSON.stringify(items)); }
    set('status', status);
    set('prescriber_id', prescriber_id);
    set('prescriber_name', prescriber_name);
    set('notes', notes);
    set('attachment_reference', attachment_reference);
    set('attachment_required', attachment_required);

    if (fields.length === 0) {
      return res.status(400).json({ error: 'No fields to update' });
    }
    fields.push('updated_at = NOW()');
    params.push(id, businessId);

    const result = await pool.query(
      `UPDATE pharmacy_prescriptions SET ${fields.join(', ')} WHERE id = $${paramIndex++} AND business_id = $${paramIndex} RETURNING *`,
      params
    );
    if (result.rows.length === 0) {
      return res.status(404).json({ error: 'Prescription not found' });
    }
    res.json(result.rows[0]);
  }));

  // ---------- Treatments ----------

  router.get('/:businessId/treatments', asyncHandler(async (req, res) => {
    const result = await pool.query(
      'SELECT * FROM pharmacy_treatments WHERE business_id = $1 ORDER BY start_date DESC',
      [req.params.businessId]
    );
    res.json({ data: result.rows });
  }));

  router.post('/:businessId/treatments', requireFields('name'), asyncHandler(async (req, res) => {
    const { businessId } = req.params;
    const {
      id, patient_id, name, drug_name, dosage, frequency_per_day, duration_days,
      start_date, end_date, is_active, administered_log,
    } = req.body;

    const result = await pool.query(
      `INSERT INTO pharmacy_treatments (
         id, business_id, patient_id, name, drug_name, dosage, frequency_per_day, duration_days,
         start_date, end_date, is_active, administered_log
       ) VALUES (COALESCE($1, uuid_generate_v4()), $2, $3, $4, $5, $6, $7, $8, COALESCE($9, NOW()), $10, $11, $12)
       ON CONFLICT (id) DO UPDATE SET
         patient_id = EXCLUDED.patient_id, name = EXCLUDED.name, drug_name = EXCLUDED.drug_name,
         dosage = EXCLUDED.dosage, frequency_per_day = EXCLUDED.frequency_per_day,
         duration_days = EXCLUDED.duration_days, start_date = EXCLUDED.start_date, end_date = EXCLUDED.end_date,
         is_active = EXCLUDED.is_active, administered_log = EXCLUDED.administered_log, updated_at = NOW()
       RETURNING *`,
      [id || null, businessId, patient_id || null, name, drug_name || null, dosage || null,
       frequency_per_day || 1, duration_days || 1, start_date || null, end_date || null,
       is_active !== false, JSON.stringify(administered_log || [])]
    );
    res.status(201).json(result.rows[0]);
  }));

  router.put('/:businessId/treatments/:id', asyncHandler(async (req, res) => {
    const { businessId, id } = req.params;
    const { patient_id, name, drug_name, dosage, frequency_per_day, duration_days,
      start_date, end_date, is_active, administered_log } = req.body;

    const fields = [];
    const params = [];
    let paramIndex = 1;
    const set = (col, val) => {
      if (val !== undefined) { fields.push(`${col} = $${paramIndex++}`); params.push(val); }
    };
    set('patient_id', patient_id);
    set('name', name);
    set('drug_name', drug_name);
    set('dosage', dosage);
    set('frequency_per_day', frequency_per_day);
    set('duration_days', duration_days);
    set('start_date', start_date);
    set('end_date', end_date);
    set('is_active', is_active);
    if (administered_log !== undefined) {
      fields.push(`administered_log = $${paramIndex++}`);
      params.push(JSON.stringify(administered_log));
    }

    if (fields.length === 0) {
      return res.status(400).json({ error: 'No fields to update' });
    }
    fields.push('updated_at = NOW()');
    params.push(id, businessId);

    const result = await pool.query(
      `UPDATE pharmacy_treatments SET ${fields.join(', ')} WHERE id = $${paramIndex++} AND business_id = $${paramIndex} RETURNING *`,
      params
    );
    if (result.rows.length === 0) {
      return res.status(404).json({ error: 'Treatment not found' });
    }
    res.json(result.rows[0]);
  }));

  // ---------- Audit log ----------

  router.post('/:businessId/audit', asyncHandler(async (req, res) => {
    const { businessId } = req.params;
    const { action, actor_id, ...details } = req.body || {};

    const result = await pool.query(
      `INSERT INTO pharmacy_audit_log (business_id, action, actor_id, details)
       VALUES ($1, $2, $3, $4) RETURNING *`,
      [businessId, action || null, actor_id || null, JSON.stringify(details || {})]
    );
    res.status(201).json(result.rows[0]);
  }));

  return router;
};
