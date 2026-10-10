/**
 * Workers API routes for ManageCare.
 */
const express = require('express');
const router = express.Router();
const bcrypt = require('bcrypt');
const { requireFields, pagination, asyncHandler } = require('../middleware/validation');
const { requireBusinessMembership, requireBusinessOwner } = require('../middleware/auth');

module.exports = function(pool) {
  router.use('/:businessId', requireBusinessMembership(pool));

  const administrativeWorkerLimit = async (businessId) => {
    const businessResult = await pool.query(
      'SELECT business_type, subscription_tier FROM businesses WHERE id = $1',
      [businessId],
    );
    const business = businessResult.rows[0];
    if (!business || String(business.business_type).toLowerCase() !== 'administrative') return null;
    const limits = { tier1: 4, tier2: 10, tier3: 20, premium: 50, enterprise: null };
    const limit = limits[String(business.subscription_tier || 'tier1').toLowerCase()] ?? 4;
    if (limit == null) return null;
    const count = await pool.query('SELECT COUNT(*)::int AS count FROM workers WHERE business_id = $1 AND is_active = true', [businessId]);
    return { limit, usage: Number(count.rows[0].count || 0) };
  };

  // GET /api/workers/:businessId - List workers
  router.get('/:businessId', pagination, asyncHandler(async (req, res) => {
    const { businessId } = req.params;
    const { limit, offset } = req.pagination;
    const { search, isActive } = req.query;

    let query = 'SELECT * FROM workers WHERE business_id = $1';
    const params = [businessId];
    let paramIndex = 2;

    if (search) {
      query += ` AND (full_name ILIKE $${paramIndex} OR email ILIKE $${paramIndex} OR phone ILIKE $${paramIndex})`;
      params.push(`%${search}%`);
      paramIndex++;
    }
    if (isActive === 'true') {
      query += ' AND is_active = true';
    }

    const countResult = await pool.query(
      query.replace('SELECT *', 'SELECT COUNT(*)'), params
    );
    const total = parseInt(countResult.rows[0].count);

    query += ` ORDER BY full_name ASC LIMIT $${paramIndex++} OFFSET $${paramIndex}`;
    params.push(limit, offset);

    const result = await pool.query(query, params);
    result.rows.forEach((row) => delete row.password_hash);
    res.json({
      data: result.rows,
      pagination: { page: req.pagination.page, limit, total, totalPages: Math.ceil(total / limit) },
    });
  }));

  // GET /api/workers/:businessId/:id - Get single worker
  router.get('/:businessId/:id', asyncHandler(async (req, res) => {
    const { businessId, id } = req.params;
    const result = await pool.query(
      'SELECT * FROM workers WHERE id = $1 AND business_id = $2',
      [id, businessId]
    );
    if (result.rows.length === 0) {
      return res.status(404).json({ error: 'Worker not found' });
    }
    delete result.rows[0].password_hash;
    res.json(result.rows[0]);
  }));

  // POST /api/workers/:businessId - Create a worker with usable login credentials.
  router.post('/:businessId', requireBusinessOwner, requireFields('email', 'password', 'full_name', 'role'), asyncHandler(async (req, res) => {
    const { businessId } = req.params;
    const { email, full_name, phone, role, store_id, permissions, pin, password } = req.body;
    const permissionsJson = JSON.stringify(permissions || {});
    const passwordHash = await bcrypt.hash(password, 10);
    const quota = await administrativeWorkerLimit(businessId);
    if (quota && quota.usage >= quota.limit) {
      return res.status(409).json({ error: 'Subscription staff limit reached', limit_type: 'workers', limit: quota.limit, current_usage: quota.usage });
    }

    const result = await pool.query(
      `INSERT INTO workers (email, full_name, phone, role, business_id, store_id, permissions, pin, password_hash)
       VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9) RETURNING *`,
      [email.trim().toLowerCase(), full_name, phone || null, role, businessId,
       store_id || null, permissionsJson, pin || null, passwordHash]
    );
    delete result.rows[0].password_hash;
    res.status(201).json(result.rows[0]);
  }));

  // PUT /api/workers/:businessId/:id - Update worker (owner only).
  // When is_active/role/permissions/store_id changes, the matching
  // business_members row is upserted in the same transaction (see below) -
  // workers.id === profiles.id, and business_members is what actually
  // gates business access/membership checks and worker session permissions.
  router.put('/:businessId/:id', requireBusinessOwner, asyncHandler(async (req, res) => {
    const { businessId, id } = req.params;
    const { email, full_name, phone, role, store_id, permissions, pin, is_active, password, commission_percentage } = req.body;
    const permissionsJson = permissions !== undefined ? JSON.stringify(permissions) : undefined;

    const fields = [];
    const params = [];
    let paramIndex = 1;
    let passwordHash;

    if (email !== undefined) { fields.push(`email = $${paramIndex++}`); params.push(email); }
    if (full_name !== undefined) { fields.push(`full_name = $${paramIndex++}`); params.push(full_name); }
    if (phone !== undefined) { fields.push(`phone = $${paramIndex++}`); params.push(phone); }
    if (role !== undefined) { fields.push(`role = $${paramIndex++}`); params.push(role); }
    if (store_id !== undefined) { fields.push(`store_id = $${paramIndex++}`); params.push(store_id); }
    if (permissions !== undefined) { fields.push(`permissions = $${paramIndex++}`); params.push(permissionsJson); }
    if (pin !== undefined) { fields.push(`pin = $${paramIndex++}`); params.push(pin); }
    if (is_active !== undefined) { fields.push(`is_active = $${paramIndex++}`); params.push(is_active); }
    if (commission_percentage !== undefined) { fields.push(`commission_percentage = $${paramIndex++}`); params.push(commission_percentage); }
    // Owner-initiated reset - the owner is already authenticated as the
    // business owner here, so no "current password" proof is needed the
    // way the worker's own self-service /change-password page requires one.
    if (password) {
      passwordHash = await bcrypt.hash(password, 10);
      fields.push(`password_hash = $${paramIndex++}`);
      params.push(passwordHash);
    }

    if (fields.length === 0) {
      return res.status(400).json({ error: 'No fields to update' });
    }

    fields.push('updated_at = NOW()');
    params.push(id, businessId);

    const client = await pool.connect();
    try {
      await client.query('BEGIN');

      const result = await client.query(
        `UPDATE workers SET ${fields.join(', ')} WHERE id = $${paramIndex++} AND business_id = $${paramIndex} RETURNING *`,
        params
      );

      if (result.rows.length === 0) {
        await client.query('ROLLBACK');
        return res.status(404).json({ error: 'Worker not found' });
      }

      if (password) {
        await client.query(
          'UPDATE profiles SET password_hash = $1, updated_at = NOW() WHERE id = $2',
          [passwordHash, id]
        );
      }

      if (is_active !== undefined || role !== undefined || permissions !== undefined || store_id !== undefined) {
        const workerRow = result.rows[0];

        // business_members is what _composeUserModel() (session/login
        // resolution on the client) actually reads role/permissions from -
        // NOT the workers row just updated above. Workers created through
        // the app get a matching business_members row via /admin-api/workers,
        // but workers imported from the pre-migration Firestore data only
        // ever got a `workers` row. A bare UPDATE against business_members
        // for one of those workers matches zero rows and succeeds silently:
        // the owner sees "Worker updated" and workers.permissions changes,
        // but the grant never reaches the worker's own session. Upsert
        // instead, backfilling the profiles row business_members.user_id's
        // FK requires (email deliberately left out - profiles.email is
        // UNIQUE and several legacy workers share a blank email; the
        // worker's real email lives on the workers row untouched by this).
        await client.query(
          `INSERT INTO profiles (id, full_name)
           VALUES ($1, $2)
           ON CONFLICT (id) DO NOTHING`,
          [id, workerRow.full_name]
        );

        await client.query(
          `INSERT INTO business_members (user_id, business_id, role, is_owner, is_active, permissions, store_id)
           VALUES ($1, $2, $3, false, $4, $5, $6)
           ON CONFLICT (user_id, business_id) DO UPDATE SET
             role = EXCLUDED.role,
             is_active = EXCLUDED.is_active,
             permissions = EXCLUDED.permissions,
             store_id = EXCLUDED.store_id,
             updated_at = NOW()`,
          [
            id,
            businessId,
            role !== undefined ? role : workerRow.role,
            is_active !== undefined ? is_active : workerRow.is_active,
            permissionsJson !== undefined ? permissionsJson : JSON.stringify(workerRow.permissions || {}),
            store_id !== undefined ? store_id : workerRow.store_id,
          ]
        );
      }

      await client.query('COMMIT');
      delete result.rows[0].password_hash;
      res.json(result.rows[0]);
    } catch (err) {
      await client.query('ROLLBACK');
      throw err;
    } finally {
      client.release();
    }
  }));

  // DELETE /api/workers/:businessId/:id - Delete worker (owner only).
  // Also deactivates (not deletes - sales/attendance rows may reference
  // this user_id) the matching business_members row so membership checks
  // and worker counts stop treating them as part of the business.
  router.delete('/:businessId/:id', requireBusinessOwner, asyncHandler(async (req, res) => {
    const { businessId, id } = req.params;

    const client = await pool.connect();
    try {
      await client.query('BEGIN');

      const result = await client.query(
        'DELETE FROM workers WHERE id = $1 AND business_id = $2 RETURNING *',
        [id, businessId]
      );
      if (result.rows.length === 0) {
        await client.query('ROLLBACK');
        return res.status(404).json({ error: 'Worker not found' });
      }

      await client.query(
        'UPDATE business_members SET is_active = false, updated_at = NOW() WHERE user_id = $1 AND business_id = $2',
        [id, businessId]
      );

      await client.query('COMMIT');
      res.json({ message: 'Worker deleted', id });
    } catch (err) {
      await client.query('ROLLBACK');
      throw err;
    } finally {
      client.release();
    }
  }));

  return router;
};

