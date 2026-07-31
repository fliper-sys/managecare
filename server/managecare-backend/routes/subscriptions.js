/**
 * Subscription API routes for ManageCare, replacing the Firestore-backed
 * SubscriptionService. Businesses are the primary source of truth (an
 * owner's subscription lives on their business row); profiles carry a
 * synced/fallback copy for users with no resolvable business yet, matching
 * both code paths the Firestore version had.
 */
const express = require('express');
const router = express.Router();
const { asyncHandler } = require('../middleware/validation');

const GRACE_PERIOD_DAYS = 7;

function addDays(date, days) {
  return new Date(date.getTime() + days * 24 * 60 * 60 * 1000);
}

function isWithinAccessWindow(endDate, now) {
  if (!endDate) return true;
  return now.getTime() <= addDays(endDate, GRACE_PERIOD_DAYS).getTime();
}

module.exports = function(pool) {
  async function resolveBusinessId(userId, explicitBusinessId) {
    if (explicitBusinessId) return explicitBusinessId;
    if (!userId) return null;
    const result = await pool.query(
      'SELECT current_business_id, subscription_business_id FROM profiles WHERE id = $1',
      [userId]
    );
    if (result.rows.length === 0) return null;
    return result.rows[0].current_business_id || result.rows[0].subscription_business_id || null;
  }

  async function writeUserSubscriptionSummary(client, {
    userId, businessId, planId, planTier, planFamily, businessType,
    startDate, endDate, isActive, status, amount, receiptUrl,
  }) {
    if (!userId) return;
    await client.query(`
      UPDATE profiles SET
        current_business_id = COALESCE($1, current_business_id),
        subscription_business_id = $1,
        subscription_plan = $2,
        subscription_tier = $3,
        subscription_family = $4,
        subscription_business_type = $5,
        has_active_subscription = $6,
        subscription_status = $7,
        subscription_start_date = $8,
        subscription_end_date = $9,
        subscription_payment_required = NOT $6,
        subscription_receipt_url = $10,
        subscription_amount = $11,
        subscription_activated_at = NOW(),
        updated_at = NOW()
      WHERE id = $12
    `, [businessId || null, planId || null, planTier || null, planFamily || null,
        businessType || null, isActive, status, startDate, endDate,
        receiptUrl || null, amount ?? null, userId]);
  }

  async function syncBusinessSubscription(client, businessId, {
    planId, planTier, planFamily, businessType, startDate, endDate,
    amount, receiptUrl, status, isActive,
  }) {
    await client.query(`
      UPDATE businesses SET
        subscription_tier = $1,
        subscription_plan = $2,
        business_class = COALESCE($1, business_class),
        subscription_family = $3,
        subscription_business_type = COALESCE($4, subscription_business_type),
        subscription_start_date = $5,
        subscription_end_date = $6,
        subscription_amount = COALESCE($7, subscription_amount),
        subscription_receipt_url = COALESCE($8, subscription_receipt_url),
        is_subscription_active = $9,
        subscription_status = $10,
        subscription_review_status = $10,
        subscription_synced_at = NOW(),
        updated_at = NOW()
      WHERE id = $11
    `, [planTier || null, planId || null, planFamily || null, businessType || null,
        startDate, endDate, amount ?? null, receiptUrl || null, isActive, status, businessId]);
  }

  async function logEvent(client, {
    userId, businessId, action, planId, planTier, planFamily, amount, receiptUrl, startDate, endDate,
  }) {
    await client.query(`
      INSERT INTO subscription_events
        (user_id, business_id, action, plan_id, plan_tier, plan_family, amount, receipt_url, start_date, end_date)
      VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10)
    `, [userId || null, businessId || null, action, planId || null, planTier || null,
        planFamily || null, amount ?? null, receiptUrl || null, startDate || null, endDate || null]);
  }

  router.get('/business/:businessId', asyncHandler(async (req, res) => {
    const result = await pool.query('SELECT * FROM businesses WHERE id = $1', [req.params.businessId]);
    if (result.rows.length === 0) return res.status(404).json({ error: 'Business not found' });
    res.json(result.rows[0]);
  }));

  router.get('/user/:userId', asyncHandler(async (req, res) => {
    const result = await pool.query('SELECT * FROM profiles WHERE id = $1', [req.params.userId]);
    if (result.rows.length === 0) return res.status(404).json({ error: 'User not found' });
    res.json(result.rows[0]);
  }));

  // POST /activate - mode 'immediate' (Kora self-checkout: always starts now)
  // or 'renew' (extends from the existing end date if it's still in the future).
  router.post('/activate', asyncHandler(async (req, res) => {
    const {
      userId, businessId: explicitBusinessId, planId, planTier, planFamily, businessType,
      amount, receiptUrl, durationDays, mode,
    } = req.body || {};
    if (!planId || !durationDays) {
      return res.status(400).json({ error: 'planId and durationDays are required' });
    }

    const client = await pool.connect();
    try {
      await client.query('BEGIN');
      const businessId = await resolveBusinessId(userId, explicitBusinessId);
      const now = new Date();

      let startDate = now;
      let endDate = addDays(now, durationDays);
      let action = 'subscription_activated';

      if (mode === 'renew') {
        let existingEnd = null;
        if (businessId) {
          const biz = await client.query('SELECT subscription_end_date FROM businesses WHERE id = $1', [businessId]);
          existingEnd = biz.rows[0]?.subscription_end_date || null;
        } else if (userId) {
          const profile = await client.query('SELECT subscription_end_date FROM profiles WHERE id = $1', [userId]);
          existingEnd = profile.rows[0]?.subscription_end_date || null;
        }
        if (existingEnd && new Date(existingEnd) > now) {
          startDate = new Date(existingEnd);
          endDate = addDays(startDate, durationDays);
          action = 'subscription_renewed';
        }
      }

      await writeUserSubscriptionSummary(client, {
        userId, businessId, planId, planTier, planFamily, businessType,
        startDate, endDate, isActive: true, status: 'approved', amount, receiptUrl,
      });

      if (businessId) {
        await syncBusinessSubscription(client, businessId, {
          planId, planTier, planFamily, businessType, startDate, endDate,
          amount, receiptUrl, status: 'approved', isActive: true,
        });
      }

      await logEvent(client, {
        userId, businessId, action, planId, planTier, planFamily, amount, receiptUrl, startDate, endDate,
      });

      await client.query('COMMIT');
      res.json({ success: true, businessId, startDate, endDate, action });
    } catch (error) {
      await client.query('ROLLBACK');
      throw error;
    } finally {
      client.release();
    }
  }));

  // POST /business/:businessId/sync - admin manually applies a plan to a business
  // (no per-user profile write, matches syncSubscriptionToBusiness).
  router.post('/business/:businessId/sync', asyncHandler(async (req, res) => {
    const { businessId } = req.params;
    const { planId, planTier, planFamily, businessType, startDate, endDate, amount, receiptUrl } = req.body || {};
    if (!planId || !startDate || !endDate) {
      return res.status(400).json({ error: 'planId, startDate and endDate are required' });
    }
    const client = await pool.connect();
    try {
      await client.query('BEGIN');
      await syncBusinessSubscription(client, businessId, {
        planId, planTier, planFamily, businessType,
        startDate: new Date(startDate), endDate: new Date(endDate),
        amount, receiptUrl, status: 'approved', isActive: true,
      });
      await logEvent(client, {
        businessId, action: 'subscription_synced', planId, planTier, planFamily,
        amount, receiptUrl, startDate, endDate,
      });
      await client.query('COMMIT');
      res.json({ success: true });
    } catch (error) {
      await client.query('ROLLBACK');
      throw error;
    } finally {
      client.release();
    }
  }));

  router.post('/expire', asyncHandler(async (req, res) => {
    const { userId, businessId: explicitBusinessId } = req.body || {};
    const client = await pool.connect();
    try {
      await client.query('BEGIN');
      const businessId = await resolveBusinessId(userId, explicitBusinessId);
      if (userId) {
        await client.query(`
          UPDATE profiles SET has_active_subscription = false, subscription_payment_required = true,
                 subscription_status = 'expired', updated_at = NOW()
          WHERE id = $1
        `, [userId]);
      }
      if (businessId) {
        await client.query(`
          UPDATE businesses SET is_subscription_active = false, subscription_status = 'expired',
                 subscription_review_status = 'expired', updated_at = NOW()
          WHERE id = $1
        `, [businessId]);
      }
      await logEvent(client, { userId, businessId, action: 'subscription_expired' });
      await client.query('COMMIT');
      res.json({ success: true });
    } catch (error) {
      await client.query('ROLLBACK');
      throw error;
    } finally {
      client.release();
    }
  }));

  router.post('/cancel', asyncHandler(async (req, res) => {
    const { userId, businessId: explicitBusinessId } = req.body || {};
    const client = await pool.connect();
    try {
      await client.query('BEGIN');
      const businessId = await resolveBusinessId(userId, explicitBusinessId);
      if (userId) {
        await client.query(`
          UPDATE profiles SET has_active_subscription = false, subscription_payment_required = false,
                 subscription_status = 'cancelled', updated_at = NOW()
          WHERE id = $1
        `, [userId]);
      }
      if (businessId) {
        await client.query(`
          UPDATE businesses SET is_subscription_active = false, subscription_status = 'cancelled',
                 subscription_review_status = 'cancelled', updated_at = NOW()
          WHERE id = $1
        `, [businessId]);
      }
      await logEvent(client, { userId, businessId, action: 'subscription_cancelled' });
      await client.query('COMMIT');
      res.json({ success: true });
    } catch (error) {
      await client.query('ROLLBACK');
      throw error;
    } finally {
      client.release();
    }
  }));

  // POST /validate - checks grace-period expiry, writes back 'expired' if
  // needed, syncs the profile row, returns whether access is currently valid.
  router.post('/validate', asyncHandler(async (req, res) => {
    const { userId, businessId: explicitBusinessId } = req.body || {};
    const client = await pool.connect();
    try {
      await client.query('BEGIN');
      const businessId = await resolveBusinessId(userId, explicitBusinessId);
      const now = new Date();

      if (businessId) {
        const bizResult = await client.query('SELECT * FROM businesses WHERE id = $1', [businessId]);
        if (bizResult.rows.length === 0) {
          await client.query('ROLLBACK');
          return res.json({ valid: false });
        }
        const biz = bizResult.rows[0];
        const isActive = biz.is_subscription_active === true;
        const status = (biz.subscription_status || '').toLowerCase();
        const isTrial = status === 'trial';
        const endDate = biz.subscription_end_date ? new Date(biz.subscription_end_date) : null;
        const isValid = isActive && (!endDate || (isTrial
          ? now <= endDate
          : isWithinAccessWindow(endDate, now)));

        if (isActive && endDate && !isValid) {
          await client.query(`
            UPDATE businesses SET is_subscription_active = false, subscription_status = 'expired',
                   subscription_review_status = 'expired', updated_at = NOW()
            WHERE id = $1
          `, [businessId]);
        }

        if (userId) {
          await client.query(`
            UPDATE profiles SET
              current_business_id = COALESCE(current_business_id, $1),
              subscription_business_id = $1,
              subscription_business_type = COALESCE($2, subscription_business_type),
              subscription_plan = $3,
              subscription_tier = $4,
              subscription_family = COALESCE($5, subscription_family),
              subscription_start_date = $6,
              subscription_end_date = $7,
              has_active_subscription = $8,
              subscription_status = $9,
              subscription_payment_required = NOT $8,
              updated_at = NOW()
            WHERE id = $10
          `, [businessId, biz.business_type, biz.subscription_plan, biz.subscription_tier,
              biz.subscription_family, biz.subscription_start_date, biz.subscription_end_date,
              isValid, isValid ? (isTrial ? 'trial' : 'approved') : 'expired', userId]);
        }

        await client.query('COMMIT');
        return res.json({ valid: isValid });
      }

      // No business resolvable - fall back to the profile's own subscription fields.
      if (!userId) {
        await client.query('ROLLBACK');
        return res.json({ valid: false });
      }
      const profileResult = await client.query('SELECT * FROM profiles WHERE id = $1', [userId]);
      if (profileResult.rows.length === 0) {
        await client.query('ROLLBACK');
        return res.json({ valid: false });
      }
      const profile = profileResult.rows[0];
      const hasActive = profile.has_active_subscription === true;
      const endDate = profile.subscription_end_date ? new Date(profile.subscription_end_date) : null;
      let valid = hasActive;
      if (hasActive && endDate && !isWithinAccessWindow(endDate, now)) {
        await client.query(`
          UPDATE profiles SET has_active_subscription = false, subscription_payment_required = true,
                 subscription_status = 'expired', updated_at = NOW()
          WHERE id = $1
        `, [userId]);
        await logEvent(client, { userId, action: 'subscription_expired' });
        valid = false;
      }
      await client.query('COMMIT');
      res.json({ valid });
    } catch (error) {
      await client.query('ROLLBACK');
      throw error;
    } finally {
      client.release();
    }
  }));

  // Combines subscription_requests (manual/admin-approval flow) with
  // subscription_events (self-service activate/renew/expire/cancel audit
  // trail) for the user-facing "Subscription Transactions" screen.
  router.get('/history', asyncHandler(async (req, res) => {
    const { businessId, userId } = req.query;
    if (!businessId && !userId) {
      return res.status(400).json({ error: 'businessId or userId is required' });
    }

    const reqParams = [];
    const reqWhere = [];
    if (businessId) { reqParams.push(businessId); reqWhere.push(`business_id = $${reqParams.length}`); }
    if (userId) { reqParams.push(userId); reqWhere.push(`user_id = $${reqParams.length}`); }

    const evtParams = [];
    const evtWhere = [];
    if (businessId) { evtParams.push(businessId); evtWhere.push(`business_id = $${evtParams.length}`); }
    if (userId) { evtParams.push(userId); evtWhere.push(`user_id = $${evtParams.length}`); }

    const [requests, events] = await Promise.all([
      pool.query(`
        SELECT id, business_id, user_id, plan_id, plan_name, amount, NULL AS receipt_url,
               status, created_at AS "createdAt"
        FROM subscription_requests
        WHERE ${reqWhere.join(' AND ')}
        ORDER BY created_at DESC LIMIT 50
      `, reqParams),
      pool.query(`
        SELECT id, business_id, user_id, plan_id, plan_tier, amount, receipt_url,
               action AS status, created_at AS "createdAt"
        FROM subscription_events
        WHERE ${evtWhere.join(' AND ')}
        ORDER BY created_at DESC LIMIT 50
      `, evtParams),
    ]);

    const combined = [...requests.rows, ...events.rows].sort(
      (a, b) => new Date(b.createdAt) - new Date(a.createdAt)
    );
    res.json({ data: combined.slice(0, 50) });
  }));

  router.get('/events', asyncHandler(async (req, res) => {
    const { userId, businessId } = req.query;
    const params = [];
    const where = [];
    if (userId) { params.push(userId); where.push(`user_id = $${params.length}`); }
    if (businessId) { params.push(businessId); where.push(`business_id = $${params.length}`); }
    const result = await pool.query(`
      SELECT * FROM subscription_events
      ${where.length ? `WHERE ${where.join(' AND ')}` : ''}
      ORDER BY created_at DESC LIMIT 200
    `, params);
    res.json({ data: result.rows });
  }));

  return router;
};
