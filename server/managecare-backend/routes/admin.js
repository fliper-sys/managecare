/**
 * Admin API routes for ManageCare.
 * These endpoints back the app admin dashboard while Firestore is phased out.
 */
const express = require('express');
const router = express.Router();
const { asyncHandler } = require('../middleware/validation');

const revenueStatuses = ['approved', 'completed', 'paid', 'successful', 'success'];

function toBool(value) {
  if (typeof value === 'boolean') return value;
  if (typeof value === 'string') return value.toLowerCase() === 'true';
  return Boolean(value);
}

function pickColumns(body, allowed) {
  const sets = [];
  const values = [];

  Object.entries(allowed).forEach(([inputKey, column]) => {
    if (Object.prototype.hasOwnProperty.call(body, inputKey)) {
      values.push(body[inputKey]);
      sets.push(`${column} = $${values.length}`);
    }
  });

  return { sets, values };
}

module.exports = function(pool) {
  router.get('/dashboard', asyncHandler(async (req, res) => {
    const [
      businessStats,
      userCount,
      workerCount,
      revenueStats,
      pendingSubscriptions,
      marketers,
      businesses,
      users,
    ] = await Promise.all([
      pool.query(`
        SELECT
          COUNT(*)::INTEGER AS total_businesses,
          COUNT(*) FILTER (
            WHERE COALESCE(is_active, true) = true
              AND COALESCE(is_subscription_active, false) = true
              AND (subscription_end_date IS NULL OR subscription_end_date > NOW())
              AND COALESCE(is_restricted, false) = false
          )::INTEGER AS active_subscriptions,
          COUNT(*) FILTER (
            WHERE COALESCE(is_restricted, false) = true
              OR restriction_status IN ('restricted', 'suspended', 'blocked')
          )::INTEGER AS restricted_businesses
        FROM businesses
      `),
      pool.query('SELECT COUNT(*)::INTEGER AS total FROM profiles'),
      pool.query('SELECT COUNT(*)::INTEGER AS total FROM workers'),
      pool.query(`
        SELECT
          COALESCE(SUM(amount) FILTER (WHERE status = ANY($1)), 0)::DECIMAL(12,2) AS total_revenue,
          COUNT(*)::INTEGER AS total_transactions,
          COUNT(*) FILTER (WHERE status IN ('pending', 'submitted', 'awaiting_approval'))::INTEGER AS pending_payments
        FROM payment_transactions
      `, [revenueStatuses]),
      pool.query(`
        SELECT COUNT(*)::INTEGER AS total
        FROM subscription_requests
        WHERE status IN ('pending', 'submitted', 'awaiting_approval', 'awaiting_payment')
      `),
      pool.query('SELECT COUNT(*)::INTEGER AS total FROM app_marketers'),
      pool.query(`
        SELECT
          b.*,
          p.full_name AS owner_name,
          COUNT(w.id)::INTEGER AS total_workers
        FROM businesses b
        LEFT JOIN profiles p ON p.id = b.owner_id
        LEFT JOIN workers w ON w.business_id = b.id
        GROUP BY b.id, p.full_name
        ORDER BY b.created_at DESC
      `),
      pool.query(`
        SELECT
          p.id,
          p.email,
          p.full_name,
          p.phone_number,
          p.current_business_id,
          NULL::UUID AS business_id,
          'profile' AS type,
          'profiles' AS table_source,
          false AS is_worker,
          p.is_active,
          p.created_at,
          p.updated_at,
          b.name AS business_name,
          b.subscription_tier,
          b.is_subscription_active,
          b.is_restricted AS business_restricted,
          b.restriction_reason AS business_restriction_reason
        FROM profiles p
        LEFT JOIN businesses b ON b.id = p.current_business_id
        UNION ALL
        SELECT
          w.id,
          w.email,
          w.full_name,
          w.phone AS phone_number,
          w.business_id AS current_business_id,
          w.business_id,
          'worker' AS type,
          'workers' AS table_source,
          true AS is_worker,
          w.is_active,
          w.created_at,
          w.updated_at,
          b.name AS business_name,
          b.subscription_tier,
          b.is_subscription_active,
          b.is_restricted AS business_restricted,
          b.restriction_reason AS business_restriction_reason
        FROM workers w
        LEFT JOIN businesses b ON b.id = w.business_id
        ORDER BY created_at DESC NULLS LAST
      `),
    ]);

    res.json({
      stats: {
        totalBusinesses: businessStats.rows[0].total_businesses || 0,
        activeSubscriptions: businessStats.rows[0].active_subscriptions || 0,
        restrictedBusinesses: businessStats.rows[0].restricted_businesses || 0,
        totalRevenue: Number(revenueStats.rows[0].total_revenue || 0),
        totalTransactions: revenueStats.rows[0].total_transactions || 0,
        pendingPayments: revenueStats.rows[0].pending_payments || 0,
        pendingSubscriptionApprovals: pendingSubscriptions.rows[0].total || 0,
        totalMarketers: marketers.rows[0].total || 0,
        activeUsers: (userCount.rows[0].total || 0) + (workerCount.rows[0].total || 0),
      },
      usersCount: userCount.rows[0].total || 0,
      workersCount: workerCount.rows[0].total || 0,
      businesses: businesses.rows,
      users: users.rows,
    });
  }));

  router.get('/businesses/:id', asyncHandler(async (req, res) => {
    const result = await pool.query(`
      SELECT b.*, p.full_name AS owner_name, COUNT(w.id)::INTEGER AS total_workers
      FROM businesses b
      LEFT JOIN profiles p ON p.id = b.owner_id
      LEFT JOIN workers w ON w.business_id = b.id
      WHERE b.id = $1
      GROUP BY b.id, p.full_name
    `, [req.params.id]);
    if (result.rows.length === 0) return res.status(404).json({ error: 'Business not found' });
    res.json(result.rows[0]);
  }));

  router.get('/businesses/:id/daily-sales', asyncHandler(async (req, res) => {
    const { id: businessId } = req.params;
    const date = req.query.date ? new Date(req.query.date) : new Date();
    if (Number.isNaN(date.getTime())) {
      return res.status(400).json({ error: 'Invalid date' });
    }
    const start = new Date(Date.UTC(date.getUTCFullYear(), date.getUTCMonth(), date.getUTCDate()));
    const end = new Date(start.getTime() + 24 * 60 * 60 * 1000);
    const prevStart = new Date(start.getTime() - 24 * 60 * 60 * 1000);

    const [salesResult, itemsResult, prevResult] = await Promise.all([
      pool.query(`
        SELECT id, worker_name, payment_method, final_amount, created_at
        FROM sales
        WHERE business_id = $1 AND created_at >= $2 AND created_at < $3
        ORDER BY created_at DESC
      `, [businessId, start, end]),
      pool.query(`
        SELECT si.sale_id, si.product_name, si.quantity, si.total,
               COALESCE(i.cost_price, 0) AS cost_price
        FROM sale_items si
        JOIN sales s ON s.id = si.sale_id
        LEFT JOIN inventory i ON i.id = si.product_id
        WHERE s.business_id = $1 AND s.created_at >= $2 AND s.created_at < $3
      `, [businessId, start, end]),
      pool.query(`
        SELECT COALESCE(SUM(final_amount), 0)::DECIMAL(12,2) AS total
        FROM sales
        WHERE business_id = $1 AND created_at >= $2 AND created_at < $3
      `, [businessId, prevStart, start]),
    ]);

    const cashierTotals = {};
    const paymentMethodTotals = {};
    let totalSales = 0;
    const transactions = salesResult.rows.map((row) => {
      const amount = Number(row.final_amount) || 0;
      totalSales += amount;
      const cashier = row.worker_name || 'Unknown';
      cashierTotals[cashier] = (cashierTotals[cashier] || 0) + amount;
      const method = row.payment_method || 'Unknown';
      paymentMethodTotals[method] = (paymentMethodTotals[method] || 0) + amount;
      return { id: row.id, cashier, total: amount, createdAt: row.created_at };
    });

    const items = {};
    let totalCost = 0;
    for (const row of itemsResult.rows) {
      const qty = Number(row.quantity) || 0;
      const lineTotal = Number(row.total) || 0;
      const lineCost = (Number(row.cost_price) || 0) * qty;
      totalCost += lineCost;
      const name = row.product_name || 'Unknown';
      if (!items[name]) items[name] = { quantity: 0, sales: 0 };
      items[name].quantity += qty;
      items[name].sales += lineTotal;
    }

    const grossProfit = totalSales - totalCost;
    const grossMarginPercent = totalSales > 0 ? (grossProfit / totalSales) * 100 : 0;

    res.json({
      totalSales,
      totalCost,
      grossProfit,
      grossMarginPercent,
      transactionCount: transactions.length,
      items,
      cashierTotals,
      paymentMethodTotals,
      transactions,
      previousDayTotal: Number(prevResult.rows[0].total) || 0,
    });
  }));

  router.get('/users/:id', asyncHandler(async (req, res) => {
    const result = await pool.query(`
      SELECT p.id, p.email, p.full_name, p.phone_number, p.current_business_id,
             NULL::UUID AS business_id, 'profile' AS type, 'profiles' AS table_source,
             false AS is_worker, p.is_active, p.created_at, p.updated_at,
             b.name AS business_name, b.subscription_tier, b.is_subscription_active,
             b.is_restricted AS business_restricted, b.restriction_reason AS business_restriction_reason
      FROM profiles p
      LEFT JOIN businesses b ON b.id = p.current_business_id
      WHERE p.id = $1
      UNION ALL
      SELECT w.id, w.email, w.full_name, w.phone AS phone_number, w.business_id AS current_business_id,
             w.business_id, 'worker' AS type, 'workers' AS table_source,
             true AS is_worker, w.is_active, w.created_at, w.updated_at,
             b.name AS business_name, b.subscription_tier, b.is_subscription_active,
             b.is_restricted AS business_restricted, b.restriction_reason AS business_restriction_reason
      FROM workers w
      LEFT JOIN businesses b ON b.id = w.business_id
      WHERE w.id = $1
    `, [req.params.id]);
    if (result.rows.length === 0) return res.status(404).json({ error: 'User not found' });
    res.json(result.rows[0]);
  }));

  router.patch('/users/:id', asyncHandler(async (req, res) => {
    const allowed = {
      fullName: 'full_name',
      full_name: 'full_name',
      phoneNumber: 'phone_number',
      phone_number: 'phone_number',
      isActive: 'is_active',
    };
    const { sets, values } = pickColumns(req.body || {}, allowed);
    if (sets.length === 0) {
      return res.status(400).json({ error: 'No supported user fields supplied' });
    }
    values.push(req.params.id);
    const result = await pool.query(`
      UPDATE profiles
      SET ${sets.join(', ')}, updated_at = NOW()
      WHERE id = $${values.length}
      RETURNING *
    `, values);
    if (result.rows.length === 0) return res.status(404).json({ error: 'User not found' });
    res.json(result.rows[0]);
  }));

  router.post('/businesses/:businessId/members/:userId/remove', asyncHandler(async (req, res) => {
    const { businessId, userId } = req.params;
    const client = await pool.connect();
    try {
      await client.query('BEGIN');
      const workerResult = await client.query(`
        UPDATE workers SET is_active = false, updated_at = NOW()
        WHERE id = $1 AND business_id = $2
        RETURNING id
      `, [userId, businessId]);
      await client.query(`
        DELETE FROM business_members WHERE user_id = $1 AND business_id = $2
      `, [userId, businessId]);
      await client.query(`
        UPDATE profiles SET current_business_id = NULL, updated_at = NOW()
        WHERE id = $1 AND current_business_id = $2
      `, [userId, businessId]);
      await client.query('COMMIT');
      res.json({ userId, businessId, removed: true, wasWorker: workerResult.rows.length > 0 });
    } catch (error) {
      await client.query('ROLLBACK');
      throw error;
    } finally {
      client.release();
    }
  }));

  // POST /admin/notifications/broadcast - admin-privileged bulk notification
  // send, bypassing the business-membership check /api/push/send enforces
  // for regular users.
  router.post('/notifications/broadcast', asyncHandler(async (req, res) => {
    const { title, body, userIds, type } = req.body || {};
    if (!title || !body) {
      return res.status(400).json({ error: 'title and body are required' });
    }
    const targets = Array.isArray(userIds) ? userIds.filter(Boolean) : [];
    if (targets.length === 0) {
      return res.status(400).json({ error: 'userIds must be a non-empty array' });
    }

    // notifications.user_id references profiles, not workers - insert
    // one-by-one so a worker id (or any bad id) in the target list doesn't
    // fail the whole broadcast.
    const io = req.app.get('io');
    const sent = [];
    for (const userId of targets) {
      try {
        const result = await pool.query(`
          INSERT INTO notifications (user_id, title, body, type)
          VALUES ($1, $2, $3, $4)
          RETURNING *
        `, [userId, title, body, type || 'general']);
        const notification = result.rows[0];
        sent.push(notification.id);
        if (io) io.to(`user:${userId}`).emit('notification', notification);
      } catch (error) {
        console.error(`[Admin] Broadcast notification skipped for ${userId}:`, error.message);
      }
    }

    res.status(201).json({ message: 'Notifications sent', count: sent.length, attempted: targets.length });
  }));

  router.get('/emails', asyncHandler(async (req, res) => {
    const result = await pool.query('SELECT * FROM admin_email_logs ORDER BY created_at DESC LIMIT 200');
    res.json({ data: result.rows });
  }));

  router.post('/emails', asyncHandler(async (req, res) => {
    const { subject, body, recipients } = req.body || {};
    if (!subject || !Array.isArray(recipients) || recipients.length === 0) {
      return res.status(400).json({ error: 'subject and a non-empty recipients array are required' });
    }
    const result = await pool.query(`
      INSERT INTO admin_email_logs (subject, body, recipients, sent_by)
      VALUES ($1, $2, $3::jsonb, $4)
      RETURNING *
    `, [subject, body || '', JSON.stringify(recipients), req.user?.id || null]);
    res.status(201).json(result.rows[0]);
  }));

  router.patch('/emails/:id', asyncHandler(async (req, res) => {
    const { status, sentCount, failedCount, failedRecipients } = req.body || {};
    const result = await pool.query(`
      UPDATE admin_email_logs
      SET status = COALESCE($1, status),
          sent_count = COALESCE($2, sent_count),
          failed_count = COALESCE($3, failed_count),
          failed_recipients = COALESCE($4::jsonb, failed_recipients),
          completed_at = NOW()
      WHERE id = $5
      RETURNING *
    `, [
      status || null,
      sentCount ?? null,
      failedCount ?? null,
      failedRecipients ? JSON.stringify(failedRecipients) : null,
      req.params.id,
    ]);
    if (result.rows.length === 0) return res.status(404).json({ error: 'Email log not found' });
    res.json(result.rows[0]);
  }));

  // Grants informational "admin yearly access" subscription fields on a
  // worker's own record. Note: worker access is gated at the business
  // subscription level (see SubscriptionService.isSubscriptionActive), not
  // per-worker or per-record flags, so this has no effect on access - it's
  // audit/display metadata only, stored in the existing permissions JSONB
  // escape hatch rather than adding dedicated columns.
  function subscriptionGrantJson() {
    const now = new Date();
    const expiry = new Date(now.getTime() + 365 * 24 * 60 * 60 * 1000);
    return {
      hasActiveSubscription: true,
      subscriptionPlan: 'admin_yearly',
      subscriptionStartDate: now.toISOString(),
      subscriptionEndDate: expiry.toISOString(),
      subscriptionPaymentRequired: false,
      subscriptionSource: 'admin-grant',
      subscriptionActivatedBy: 'admin',
    };
  }

  router.post('/workers/:id/subscription', asyncHandler(async (req, res) => {
    const result = await pool.query(`
      UPDATE workers
      SET permissions = COALESCE(permissions, '{}'::jsonb) || $1::jsonb, updated_at = NOW()
      WHERE id = $2
      RETURNING *
    `, [JSON.stringify(subscriptionGrantJson()), req.params.id]);
    if (result.rows.length === 0) return res.status(404).json({ error: 'Worker not found' });
    res.json(result.rows[0]);
  }));

  router.post('/businesses/:businessId/workers/subscription', asyncHandler(async (req, res) => {
    const result = await pool.query(`
      UPDATE workers
      SET permissions = COALESCE(permissions, '{}'::jsonb) || $1::jsonb, updated_at = NOW()
      WHERE business_id = $2
      RETURNING id
    `, [JSON.stringify(subscriptionGrantJson()), req.params.businessId]);
    res.json({ updated: result.rows.length });
  }));

  // ── Soft-delete / recovery (30-day admin-recoverable window) ──────────
  const RECOVERY_WINDOW_MS = 30 * 24 * 60 * 60 * 1000;

  router.post('/businesses/:id/delete', asyncHandler(async (req, res) => {
    const deadline = new Date(Date.now() + RECOVERY_WINDOW_MS);
    const result = await pool.query(`
      UPDATE businesses
      SET is_deleted = true, is_active = false, deleted_at = NOW(),
          deleted_by_id = $1, deleted_by_type = 'admin',
          deletion_reason = $2, recovery_deadline_at = $3, updated_at = NOW()
      WHERE id = $4
      RETURNING *
    `, [req.user?.id || null, req.body?.reason || 'Deleted by admin. Recoverable for 30 days.', deadline, req.params.id]);
    if (result.rows.length === 0) return res.status(404).json({ error: 'Business not found' });

    await pool.query(`
      INSERT INTO admin_notifications (type, title, message, data, created_by)
      VALUES ('business', 'Business Deleted', $1, $2, $3)
    `, [
      `${result.rows[0].name} was deleted by admin.`,
      { businessId: req.params.id, businessName: result.rows[0].name, eventType: 'deleted', recoveryDeadlineAt: deadline },
      req.user?.id || null,
    ]);

    res.json(result.rows[0]);
  }));

  router.post('/businesses/:id/restore', asyncHandler(async (req, res) => {
    const existing = await pool.query('SELECT * FROM businesses WHERE id = $1', [req.params.id]);
    if (existing.rows.length === 0) return res.status(404).json({ error: 'Business not found' });
    const biz = existing.rows[0];
    if (!biz.is_deleted) return res.status(400).json({ error: 'Business is not deleted' });
    if (biz.recovery_deadline_at && new Date(biz.recovery_deadline_at) < new Date()) {
      return res.status(400).json({ error: 'Recovery window has expired' });
    }

    const result = await pool.query(`
      UPDATE businesses
      SET is_deleted = false, is_active = true, deleted_at = NULL,
          deleted_by_id = NULL, deleted_by_type = NULL,
          deletion_reason = NULL, recovery_deadline_at = NULL, updated_at = NOW()
      WHERE id = $1
      RETURNING *
    `, [req.params.id]);

    await pool.query(`
      INSERT INTO admin_notifications (type, title, message, data, created_by)
      VALUES ('business', 'Business Restored', $1, $2, $3)
    `, [
      `${result.rows[0].name} was restored by admin.`,
      { businessId: req.params.id, businessName: result.rows[0].name, eventType: 'restored' },
      req.user?.id || null,
    ]);

    res.json(result.rows[0]);
  }));

  router.post('/users/:id/delete', asyncHandler(async (req, res) => {
    const deadline = new Date(Date.now() + RECOVERY_WINDOW_MS);
    const profileResult = await pool.query(`
      UPDATE profiles
      SET is_deleted = true, is_active = false, deleted_at = NOW(),
          deleted_by_id = $1, deleted_by_type = 'admin',
          deletion_reason = $2, recovery_deadline_at = $3, updated_at = NOW()
      WHERE id = $4
      RETURNING id, full_name
    `, [req.user?.id || null, req.body?.reason || 'Deleted by admin. Recoverable for 30 days.', deadline, req.params.id]);

    const workerResult = await pool.query(`
      UPDATE workers SET is_active = false, updated_at = NOW()
      WHERE id = $1
      RETURNING id, full_name
    `, [req.params.id]);

    if (profileResult.rows.length === 0 && workerResult.rows.length === 0) {
      return res.status(404).json({ error: 'User not found' });
    }

    const displayName = profileResult.rows[0]?.full_name || workerResult.rows[0]?.full_name || 'User';
    await pool.query(`
      INSERT INTO admin_notifications (type, title, message, data, created_by)
      VALUES ('user', 'User Deleted', $1, $2, $3)
    `, [
      `${displayName} was deleted by admin.`,
      {
        userId: req.params.id,
        displayName,
        eventType: profileResult.rows.length > 0 ? 'deleted' : 'deactivated',
        recoveryDeadlineAt: profileResult.rows.length > 0 ? deadline : null,
      },
      req.user?.id || null,
    ]);

    res.json({ id: req.params.id, deleted: true, wasProfile: profileResult.rows.length > 0, wasWorker: workerResult.rows.length > 0 });
  }));

  router.post('/users/:id/restore', asyncHandler(async (req, res) => {
    const existing = await pool.query('SELECT * FROM profiles WHERE id = $1', [req.params.id]);
    if (existing.rows.length > 0) {
      const profile = existing.rows[0];
      if (!profile.is_deleted) return res.status(400).json({ error: 'User is not deleted' });
      if (profile.recovery_deadline_at && new Date(profile.recovery_deadline_at) < new Date()) {
        return res.status(400).json({ error: 'Recovery window has expired' });
      }

      const result = await pool.query(`
        UPDATE profiles
        SET is_deleted = false, is_active = true, deleted_at = NULL,
            deleted_by_id = NULL, deleted_by_type = NULL,
            deletion_reason = NULL, recovery_deadline_at = NULL, updated_at = NOW()
        WHERE id = $1
        RETURNING *
      `, [req.params.id]);

      await pool.query(`
        INSERT INTO admin_notifications (type, title, message, data, created_by)
        VALUES ('user', 'User Restored', $1, $2, $3)
      `, [
        `${result.rows[0].full_name || 'User'} was restored by admin.`,
        { userId: req.params.id, eventType: 'restored' },
        req.user?.id || null,
      ]);

      return res.json(result.rows[0]);
    }

    const workerResult = await pool.query(`
      UPDATE workers SET is_active = true, updated_at = NOW()
      WHERE id = $1
      RETURNING *
    `, [req.params.id]);
    if (workerResult.rows.length === 0) return res.status(404).json({ error: 'User not found' });
    res.json(workerResult.rows[0]);
  }));

  router.get('/settings', asyncHandler(async (req, res) => {
    const result = await pool.query(
      "SELECT settings FROM admin_settings WHERE id = 'admin_settings' LIMIT 1"
    );
    res.json(result.rows[0]?.settings || {});
  }));

  router.put('/settings', asyncHandler(async (req, res) => {
    const result = await pool.query(`
      INSERT INTO admin_settings (id, settings, updated_by, updated_at)
      VALUES ('admin_settings', $1, $2, NOW())
      ON CONFLICT (id)
      DO UPDATE SET settings = EXCLUDED.settings, updated_by = EXCLUDED.updated_by, updated_at = NOW()
      RETURNING settings
    `, [req.body || {}, req.user?.id || null]);
    res.json(result.rows[0].settings || {});
  }));

  router.patch('/businesses/:id', asyncHandler(async (req, res) => {
    const allowed = {
      name: 'name',
      businessName: 'name',
      businessType: 'business_type',
      address: 'address',
      phone: 'phone',
      email: 'email',
      ownerName: 'owner_name',
      currency: 'currency',
      businessClass: 'business_class',
      maxWorkers: 'max_workers',
      features: 'features',
      isActive: 'is_active',
      subscriptionTier: 'subscription_tier',
      subscriptionPlan: 'subscription_plan',
      subscriptionStartDate: 'subscription_start_date',
      subscriptionEndDate: 'subscription_end_date',
      isSubscriptionActive: 'is_subscription_active',
      isRestricted: 'is_restricted',
      restrictionStatus: 'restriction_status',
      restrictionReason: 'restriction_reason',
    };
    const { sets, values } = pickColumns(req.body || {}, allowed);
    if (sets.length === 0) {
      return res.status(400).json({ error: 'No supported business fields supplied' });
    }

    values.push(req.params.id);
    const result = await pool.query(`
      UPDATE businesses
      SET ${sets.join(', ')}, updated_at = NOW()
      WHERE id = $${values.length}
      RETURNING *
    `, values);

    if (result.rows.length === 0) {
      return res.status(404).json({ error: 'Business not found' });
    }
    res.json(result.rows[0]);
  }));

  router.post('/businesses/:id/restriction', asyncHandler(async (req, res) => {
    const restricted = toBool(req.body?.restricted);
    const reason = restricted
      ? (req.body?.reason || 'Access restricted by admin.')
      : null;
    const status = restricted ? 'restricted' : 'active';
    const result = await pool.query(`
      UPDATE businesses
      SET
        is_restricted = $1,
        restriction_status = $2,
        restriction_reason = $3,
        restricted_at = CASE WHEN $1 THEN NOW() ELSE NULL END,
        restricted_by = CASE WHEN $1 THEN $4::uuid ELSE NULL END,
        restriction_lifted_at = CASE WHEN $1 THEN NULL ELSE NOW() END,
        is_active = CASE WHEN $1 THEN false ELSE true END,
        updated_at = NOW()
      WHERE id = $5
      RETURNING *
    `, [restricted, status, reason, req.user?.id || null, req.params.id]);

    if (result.rows.length === 0) {
      return res.status(404).json({ error: 'Business not found' });
    }

    await pool.query(`
      INSERT INTO admin_notifications (type, title, message, data, created_by)
      VALUES ($1, $2, $3, $4, $5)
    `, [
      'business_restriction',
      restricted ? 'Business Restricted' : 'Business Restored',
      restricted ? 'Business was restricted by admin.' : 'Business access was restored by admin.',
      {
        businessId: req.params.id,
        restricted,
        reason,
      },
      req.user?.id || null,
    ]);

    res.json(result.rows[0]);
  }));

  // Combines subscription_requests (manual/admin-approval flow) with
  // subscription_events (Kora self-service activate/renew/expire/cancel
  // audit trail) so the admin subscription-history view shows every
  // subscription action regardless of which flow produced it.
  // Admin manually grants/extends a business's subscription: sets the
  // business's subscription fields, approves any pending subscription
  // requests for it, logs a subscription_events row, and notifies the
  // owner + workers.
  router.post('/businesses/:id/grant-subscription', asyncHandler(async (req, res) => {
    const { id: businessId } = req.params;
    const { businessName, tier, durationDays, source } = req.body || {};
    if (!tier || !durationDays) {
      return res.status(400).json({ error: 'tier and durationDays are required' });
    }
    const normalizedTier = tier.toLowerCase();
    const planId = `${normalizedTier}_${durationDays}d`;

    const client = await pool.connect();
    try {
      await client.query('BEGIN');
      const now = new Date();
      const endDate = new Date(now.getTime() + durationDays * 24 * 60 * 60 * 1000);

      const bizResult = await client.query(`
        UPDATE businesses SET
          subscription_tier = $1, subscription_plan = $2, business_class = $1,
          subscription_start_date = $3, subscription_end_date = $4,
          is_subscription_active = true, subscription_status = 'approved',
          subscription_review_status = 'approved', subscription_synced_at = NOW(),
          updated_at = NOW()
        WHERE id = $5
        RETURNING *
      `, [normalizedTier, planId, now, endDate, businessId]);
      if (bizResult.rows.length === 0) {
        await client.query('ROLLBACK');
        return res.status(404).json({ error: 'Business not found' });
      }
      const business = bizResult.rows[0];
      const resolvedName = businessName || business.name;

      const pendingResult = await client.query(`
        UPDATE subscription_requests
        SET status = 'approved', updated_at = NOW()
        WHERE business_id = $1 AND status = 'pending'
        RETURNING id
      `, [businessId]);

      await client.query(`
        INSERT INTO subscription_events
          (business_id, action, plan_id, plan_tier, start_date, end_date)
        VALUES ($1, 'admin_granted', $2, $3, $4, $5)
      `, [businessId, planId, normalizedTier, now, endDate]);

      const recipients = await client.query(`
        SELECT id FROM profiles WHERE current_business_id = $1
        UNION
        SELECT id FROM workers WHERE business_id = $1 AND is_active = true
      `, [businessId]);

      const endLabel = `${endDate.getDate()}/${endDate.getMonth() + 1}/${endDate.getFullYear()}`;
      const io = req.app.get('io');
      for (const row of recipients.rows) {
        try {
          const notifResult = await client.query(`
            INSERT INTO notifications (user_id, business_id, title, body, type)
            VALUES ($1, $2, $3, $4, 'subscription')
            RETURNING *
          `, [
            row.id, businessId, 'Subscription Activated',
            `${resolvedName} now has a ${normalizedTier.toUpperCase()} subscription active until ${endLabel}.`,
          ]);
          if (io) io.to(`user:${row.id}`).emit('notification', notifResult.rows[0]);
        } catch (error) {
          console.error(`[Admin] grant-subscription notify skipped for ${row.id}:`, error.message);
        }
      }

      await client.query('COMMIT');
      res.json({ business, approvedPendingCount: pendingResult.rows.length });
    } catch (error) {
      await client.query('ROLLBACK');
      throw error;
    } finally {
      client.release();
    }
  }));

  router.post('/businesses/:id/decline-subscription', asyncHandler(async (req, res) => {
    const { id: businessId } = req.params;
    const { reason } = req.body || {};
    const declineReason = (reason || '').trim() || 'Declined by admin review.';

    const client = await pool.connect();
    try {
      await client.query('BEGIN');
      const bizResult = await client.query(`
        UPDATE businesses SET
          is_subscription_active = false, subscription_status = 'declined',
          subscription_review_status = 'declined', updated_at = NOW()
        WHERE id = $1
        RETURNING *
      `, [businessId]);
      if (bizResult.rows.length === 0) {
        await client.query('ROLLBACK');
        return res.status(404).json({ error: 'Business not found' });
      }

      const pendingResult = await client.query(`
        UPDATE subscription_requests
        SET status = 'rejected', notes = $2, updated_at = NOW()
        WHERE business_id = $1 AND status = 'pending'
        RETURNING id
      `, [businessId, declineReason]);

      await client.query(`
        INSERT INTO subscription_events (business_id, action)
        VALUES ($1, 'admin_declined')
      `, [businessId]);

      await client.query('COMMIT');
      res.json({ business: bizResult.rows[0], declinedPendingCount: pendingResult.rows.length });
    } catch (error) {
      await client.query('ROLLBACK');
      throw error;
    } finally {
      client.release();
    }
  }));

  // GET /admin/subscription-requests - enriched list (user + business
  // context joined server-side) for the admin payments review screen.
  router.get('/subscription-requests', asyncHandler(async (req, res) => {
    const result = await pool.query(`
      SELECT
        sr.*,
        p.full_name AS user_name, p.email AS user_email,
        b.name AS business_name, b.subscription_tier AS business_tier,
        b.business_class AS business_class
      FROM subscription_requests sr
      LEFT JOIN profiles p ON p.id = sr.user_id
      LEFT JOIN businesses b ON b.id = COALESCE(sr.business_id, p.current_business_id)
      ORDER BY sr.created_at DESC
      LIMIT 500
    `);
    res.json({ data: result.rows });
  }));

  // POST /admin/subscription-requests/:id/approve - grants the requested
  // plan to the request's business + profile, marks the request approved,
  // and marks any matching payment_transactions row as processed.
  router.post('/subscription-requests/:id/approve', asyncHandler(async (req, res) => {
    const { id } = req.params;
    const { durationDays } = req.body || {};
    if (!durationDays) return res.status(400).json({ error: 'durationDays is required' });

    const client = await pool.connect();
    try {
      await client.query('BEGIN');
      const reqResult = await client.query('SELECT * FROM subscription_requests WHERE id = $1', [id]);
      if (reqResult.rows.length === 0) {
        await client.query('ROLLBACK');
        return res.status(404).json({ error: 'Subscription request not found' });
      }
      const request = reqResult.rows[0];

      let businessId = request.business_id;
      if (!businessId && request.user_id) {
        const profile = await client.query('SELECT current_business_id FROM profiles WHERE id = $1', [request.user_id]);
        businessId = profile.rows[0]?.current_business_id || null;
      }

      const now = new Date();
      const endDate = new Date(now.getTime() + durationDays * 24 * 60 * 60 * 1000);
      const planTier = request.plan_id ? request.plan_id.split('_')[0] : null;

      if (businessId) {
        await client.query(`
          UPDATE businesses SET
            subscription_tier = COALESCE($1, subscription_tier), subscription_plan = $2,
            subscription_start_date = $3, subscription_end_date = $4,
            is_subscription_active = true, subscription_status = 'approved',
            subscription_review_status = 'approved', subscription_synced_at = NOW(),
            updated_at = NOW()
          WHERE id = $5
        `, [planTier, request.plan_id, now, endDate, businessId]);
      }
      if (request.user_id) {
        await client.query(`
          UPDATE profiles SET
            subscription_business_id = COALESCE($1, subscription_business_id),
            subscription_plan = $2, subscription_tier = COALESCE($3, subscription_tier),
            has_active_subscription = true, subscription_status = 'approved',
            subscription_start_date = $4, subscription_end_date = $5,
            subscription_payment_required = false, subscription_amount = $6,
            subscription_activated_at = NOW(), updated_at = NOW()
          WHERE id = $7
        `, [businessId, request.plan_id, planTier, now, endDate, request.amount, request.user_id]);
      }

      await client.query(`
        UPDATE subscription_requests SET status = 'approved', updated_at = NOW() WHERE id = $1
      `, [id]);

      if (request.transaction_id) {
        await client.query(`
          UPDATE payment_transactions SET status = 'processed', updated_at = NOW()
          WHERE transaction_id = $1
        `, [request.transaction_id]);
      }

      await client.query(`
        INSERT INTO subscription_events
          (user_id, business_id, action, plan_id, plan_tier, amount, start_date, end_date)
        VALUES ($1, $2, 'admin_approved', $3, $4, $5, $6, $7)
      `, [request.user_id, businessId, request.plan_id, planTier, request.amount, now, endDate]);

      await client.query('COMMIT');
      res.json({ success: true, businessId, userId: request.user_id, startDate: now, endDate });
    } catch (error) {
      await client.query('ROLLBACK');
      throw error;
    } finally {
      client.release();
    }
  }));

  router.post('/subscription-requests/:id/decline', asyncHandler(async (req, res) => {
    const { id } = req.params;
    const { reason } = req.body || {};
    const declineReason = (reason || '').trim() || 'Declined by admin review.';

    const client = await pool.connect();
    try {
      await client.query('BEGIN');
      const reqResult = await client.query('SELECT * FROM subscription_requests WHERE id = $1', [id]);
      if (reqResult.rows.length === 0) {
        await client.query('ROLLBACK');
        return res.status(404).json({ error: 'Subscription request not found' });
      }
      const request = reqResult.rows[0];
      let businessId = request.business_id;
      if (!businessId && request.user_id) {
        const profile = await client.query('SELECT current_business_id FROM profiles WHERE id = $1', [request.user_id]);
        businessId = profile.rows[0]?.current_business_id || null;
      }

      await client.query(`
        UPDATE subscription_requests SET status = 'rejected', notes = $2, updated_at = NOW() WHERE id = $1
      `, [id, declineReason]);

      if (businessId) {
        await client.query(`
          UPDATE businesses SET is_subscription_active = false, subscription_status = 'declined',
                 subscription_review_status = 'declined', updated_at = NOW()
          WHERE id = $1
        `, [businessId]);
      }
      if (request.user_id) {
        await client.query(`
          UPDATE profiles SET has_active_subscription = false, subscription_status = 'declined',
                 subscription_payment_required = true, updated_at = NOW()
          WHERE id = $1
        `, [request.user_id]);
      }
      if (request.transaction_id) {
        await client.query(`
          UPDATE payment_transactions SET status = 'declined', updated_at = NOW()
          WHERE transaction_id = $1
        `, [request.transaction_id]);
      }

      await client.query(`
        INSERT INTO subscription_events (user_id, business_id, action, plan_id)
        VALUES ($1, $2, 'admin_declined', $3)
      `, [request.user_id, businessId, request.plan_id]);

      await client.query('COMMIT');
      res.json({ success: true });
    } catch (error) {
      await client.query('ROLLBACK');
      throw error;
    } finally {
      client.release();
    }
  }));

  // POST /admin/payment-transactions/:id/approve - approves a raw payment
  // transaction directly (no subscription_requests row involved), resolving
  // the target business/user from the transaction row itself.
  router.post('/payment-transactions/:id/approve', asyncHandler(async (req, res) => {
    const { id } = req.params;
    const { planId, planTier, durationDays } = req.body || {};
    if (!planId || !durationDays) {
      return res.status(400).json({ error: 'planId and durationDays are required' });
    }

    const client = await pool.connect();
    try {
      await client.query('BEGIN');
      const txResult = await client.query('SELECT * FROM payment_transactions WHERE id = $1', [id]);
      if (txResult.rows.length === 0) {
        await client.query('ROLLBACK');
        return res.status(404).json({ error: 'Transaction not found' });
      }
      const tx = txResult.rows[0];

      let businessId = tx.business_id;
      let userId = null;
      if (tx.email) {
        const profile = await client.query('SELECT id, current_business_id FROM profiles WHERE lower(email) = lower($1)', [tx.email]);
        if (profile.rows.length > 0) {
          userId = profile.rows[0].id;
          businessId = businessId || profile.rows[0].current_business_id;
        }
      }

      const now = new Date();
      const endDate = new Date(now.getTime() + durationDays * 24 * 60 * 60 * 1000);

      if (businessId) {
        await client.query(`
          UPDATE businesses SET
            subscription_tier = COALESCE($1, subscription_tier), subscription_plan = $2,
            subscription_start_date = $3, subscription_end_date = $4,
            is_subscription_active = true, subscription_status = 'approved',
            subscription_review_status = 'approved', subscription_synced_at = NOW(),
            updated_at = NOW()
          WHERE id = $5
        `, [planTier, planId, now, endDate, businessId]);
      }
      if (userId) {
        await client.query(`
          UPDATE profiles SET
            subscription_business_id = COALESCE($1, subscription_business_id),
            subscription_plan = $2, subscription_tier = COALESCE($3, subscription_tier),
            has_active_subscription = true, subscription_status = 'approved',
            subscription_start_date = $4, subscription_end_date = $5,
            subscription_payment_required = false, subscription_amount = $6,
            subscription_activated_at = NOW(), updated_at = NOW()
          WHERE id = $7
        `, [businessId, planId, planTier, now, endDate, tx.amount, userId]);
      }

      await client.query(`
        UPDATE payment_transactions SET status = 'processed', updated_at = NOW() WHERE id = $1
      `, [id]);
      await client.query(`
        UPDATE subscription_requests SET status = 'approved', updated_at = NOW()
        WHERE transaction_id = $1 AND status = 'pending'
      `, [tx.transaction_id]);

      await client.query(`
        INSERT INTO subscription_events
          (user_id, business_id, action, plan_id, plan_tier, amount, start_date, end_date)
        VALUES ($1, $2, 'admin_approved', $3, $4, $5, $6, $7)
      `, [userId, businessId, planId, planTier, tx.amount, now, endDate]);

      await client.query('COMMIT');
      res.json({ success: true, businessId, userId, startDate: now, endDate });
    } catch (error) {
      await client.query('ROLLBACK');
      throw error;
    } finally {
      client.release();
    }
  }));

  router.post('/payment-transactions/:id/decline', asyncHandler(async (req, res) => {
    const { id } = req.params;
    const { reason } = req.body || {};
    const result = await pool.query(`
      UPDATE payment_transactions SET status = 'declined', updated_at = NOW()
      WHERE id = $1
      RETURNING *
    `, [id]);
    if (result.rows.length === 0) return res.status(404).json({ error: 'Transaction not found' });
    res.json({ success: true, reason: reason || null });
  }));

  router.get('/businesses/:id/subscriptions', asyncHandler(async (req, res) => {
    const result = await pool.query(`
      SELECT * FROM (
        SELECT
          id, plan_id, plan_name, NULL AS plan_tier, amount, status,
          created_at AS "createdAt", 'request' AS source
        FROM subscription_requests
        WHERE business_id = $1
        UNION ALL
        SELECT
          id, plan_id, NULL AS plan_name, plan_tier, amount, action AS status,
          created_at AS "createdAt", 'event' AS source
        FROM subscription_events
        WHERE business_id = $1
      ) combined
      ORDER BY "createdAt" DESC
      LIMIT 50
    `, [req.params.id]);
    res.json({ data: result.rows });
  }));

  router.get('/payments', asyncHandler(async (req, res) => {
    const params = [];
    const where = [];
    if (req.query.startDate) {
      params.push(req.query.startDate);
      where.push(`pt.created_at >= $${params.length}`);
    }
    if (req.query.endDate) {
      params.push(req.query.endDate);
      where.push(`pt.created_at <= $${params.length}`);
    }

    const result = await pool.query(`
      SELECT
        pt.*,
        COALESCE(pt.business_name, b.name) AS business_name,
        COALESCE(pt.business_category, b.business_type) AS business_category,
        COALESCE(pt.business_tier, b.subscription_tier) AS business_tier
      FROM payment_transactions pt
      LEFT JOIN businesses b ON b.id = pt.business_id
      ${where.length ? `WHERE ${where.join(' AND ')}` : ''}
      ORDER BY pt.created_at DESC
    `, params);
    res.json({ data: result.rows });
  }));

  router.get('/internal-workers', asyncHandler(async (req, res) => {
    const result = await pool.query(`
      SELECT *
      FROM managecare_workers
      ORDER BY created_at DESC
    `);
    res.json({ data: result.rows });
  }));

  router.post('/internal-workers', asyncHandler(async (req, res) => {
    const { name, email, phone, role, roleKey, isActive } = req.body || {};
    if (!name || !role) {
      return res.status(400).json({ error: 'name and role are required' });
    }
    const result = await pool.query(`
      INSERT INTO managecare_workers
        (name, email, phone, role, role_key, is_active, created_by, updated_by)
      VALUES ($1, $2, $3, $4, $5, $6, $7, $7)
      RETURNING *
    `, [name, email || null, phone || null, role, roleKey || null, isActive !== false, req.user?.id || null]);
    res.status(201).json(result.rows[0]);
  }));

  router.put('/internal-workers/:id', asyncHandler(async (req, res) => {
    const allowed = {
      name: 'name',
      email: 'email',
      phone: 'phone',
      role: 'role',
      roleKey: 'role_key',
      isActive: 'is_active',
    };
    const { sets, values } = pickColumns(req.body || {}, allowed);
    if (sets.length === 0) {
      return res.status(400).json({ error: 'No supported worker fields supplied' });
    }
    values.push(req.user?.id || null);
    values.push(req.params.id);
    const result = await pool.query(`
      UPDATE managecare_workers
      SET ${sets.join(', ')}, updated_by = $${values.length - 1}, updated_at = NOW()
      WHERE id = $${values.length}
      RETURNING *
    `, values);
    if (result.rows.length === 0) {
      return res.status(404).json({ error: 'Worker not found' });
    }
    res.json(result.rows[0]);
  }));

  router.get('/company-expenses', asyncHandler(async (req, res) => {
    const params = [];
    const where = [];
    if (req.query.startDate) {
      params.push(req.query.startDate);
      where.push(`expense_date >= $${params.length}`);
    }
    if (req.query.endDate) {
      params.push(req.query.endDate);
      where.push(`expense_date <= $${params.length}`);
    }
    const result = await pool.query(`
      SELECT *
      FROM company_expenses
      ${where.length ? `WHERE ${where.join(' AND ')}` : ''}
      ORDER BY expense_date DESC, created_at DESC
    `, params);
    res.json({ data: result.rows });
  }));

  router.post('/company-expenses', asyncHandler(async (req, res) => {
    const {
      title,
      amount,
      category,
      description,
      expenseDate,
      receiptUrl,
    } = req.body || {};
    if (!title || amount == null) {
      return res.status(400).json({ error: 'title and amount are required' });
    }
    const result = await pool.query(`
      INSERT INTO company_expenses
        (title, amount, category, description, expense_date, receipt_url, created_by)
      VALUES ($1, $2, $3, $4, COALESCE($5::TIMESTAMPTZ, NOW()), $6, $7)
      RETURNING *
    `, [
      title,
      amount,
      category || null,
      description || null,
      expenseDate || null,
      receiptUrl || null,
      req.user?.id || null,
    ]);
    res.status(201).json(result.rows[0]);
  }));

  router.get('/work-items', asyncHandler(async (req, res) => {
    const result = await pool.query(`
      SELECT *
      FROM admin_work_items
      ORDER BY
        CASE priority
          WHEN 'urgent' THEN 0
          WHEN 'high' THEN 1
          WHEN 'normal' THEN 2
          ELSE 3
        END,
        COALESCE(due_date, NOW()) ASC,
        created_at DESC
    `);
    res.json({ data: result.rows });
  }));

  router.post('/work-items', asyncHandler(async (req, res) => {
    const {
      title,
      description,
      assignedTo,
      type,
      priority,
      status,
      dueDate,
    } = req.body || {};
    if (!title || !description) {
      return res.status(400).json({ error: 'title and description are required' });
    }
    const result = await pool.query(`
      INSERT INTO admin_work_items
        (title, description, assigned_to, type, priority, status, due_date, created_by, updated_by)
      VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $8)
      RETURNING *
    `, [
      title,
      description,
      assignedTo || null,
      type || 'fix',
      priority || 'normal',
      status || 'pending',
      dueDate || null,
      req.user?.id || null,
    ]);
    res.status(201).json(result.rows[0]);
  }));

  router.patch('/work-items/:id', asyncHandler(async (req, res) => {
    const allowed = {
      title: 'title',
      description: 'description',
      assignedTo: 'assigned_to',
      type: 'type',
      priority: 'priority',
      status: 'status',
      dueDate: 'due_date',
    };
    const { sets, values } = pickColumns(req.body || {}, allowed);
    if (sets.length === 0) {
      return res.status(400).json({ error: 'No supported work item fields supplied' });
    }
    values.push(req.user?.id || null);
    values.push(req.params.id);
    const result = await pool.query(`
      UPDATE admin_work_items
      SET ${sets.join(', ')}, updated_by = $${values.length - 1}, updated_at = NOW()
      WHERE id = $${values.length}
      RETURNING *
    `, values);
    if (result.rows.length === 0) {
      return res.status(404).json({ error: 'Work item not found' });
    }
    res.json(result.rows[0]);
  }));

  return router;
};
