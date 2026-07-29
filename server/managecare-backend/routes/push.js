const express = require('express');
const { asyncHandler, requireFields } = require('../middleware/validation');

/**
 * Push notification routes for self-hosted push service.
 *
 * ─ POST /api/push/register          – Register device token
 * ─ DELETE /api/push/device/:deviceId – Unregister device
 * ─ POST /api/push/send               – Send notification (server/admin only)
 * ─ GET  /api/notifications/unread/:userId – Fetch unread notifications
 * ─ PUT  /api/notifications/:id/read  – Mark notification as read
 */
module.exports = function(pool) {
  const router = express.Router();

  // ── POST /api/push/register ──────────────────────────────────
  // Register a device token for push delivery. The token is always
  // registered for the authenticated caller - a client-supplied user_id
  // is ignored to prevent registering devices against other users.
  router.post('/register', requireFields('device_id'), asyncHandler(async (req, res) => {
    const { device_id, platform, device_name } = req.body;
    const user_id = req.user.id;

    const result = await pool.query(
      `INSERT INTO device_tokens (device_id, user_id, platform, device_name, last_seen)
       VALUES ($1, $2, $3, $4, NOW())
       ON CONFLICT (device_id) DO UPDATE SET
         user_id = EXCLUDED.user_id,
         platform = COALESCE(EXCLUDED.platform, device_tokens.platform),
         device_name = COALESCE(EXCLUDED.device_name, device_tokens.device_name),
         last_seen = NOW()
       RETURNING *`,
      [device_id, user_id, platform || 'mobile', device_name || null]
    );

    const io = req.app.get('io');
    if (io) {
      io.to(`user:${user_id}`).emit('device_registered', result.rows[0]);
    }

    res.status(201).json({
      message: 'Device registered',
      device: result.rows[0],
    });
  }));

  // ── DELETE /api/push/device/:deviceId ────────────────────────
  // Unregister a device - only the device's own owner may do this.
  router.delete('/device/:deviceId', asyncHandler(async (req, res) => {
    const { deviceId } = req.params;

    const existing = await pool.query(
      'SELECT user_id FROM device_tokens WHERE device_id = $1',
      [deviceId]
    );
    if (existing.rows.length === 0) {
      return res.status(404).json({ error: 'Device not found' });
    }
    if (existing.rows[0].user_id !== req.user.id) {
      return res.status(403).json({ error: 'You do not own this device' });
    }

    const result = await pool.query(
      'DELETE FROM device_tokens WHERE device_id = $1 RETURNING *',
      [deviceId]
    );

    res.json({ message: 'Device unregistered', device_id: deviceId });
  }));

  // ── POST /api/push/send ──────────────────────────────────────
  // Send a notification. If business_id is provided, the caller must be a
  // member of that business. Otherwise the caller may only notify themself.
  router.post('/send', requireFields('title', 'body'), asyncHandler(async (req, res) => {
    const { business_id, title, body, type, data } = req.body;
    let target_user_id = req.body.user_id;

    if (business_id) {
      const membership = await pool.query(
        'SELECT id FROM business_members WHERE user_id = $1 AND business_id = $2 AND is_active = true',
        [req.user.id, business_id]
      );
      if (membership.rows.length === 0) {
        return res.status(403).json({ error: 'You are not a member of this business' });
      }
    } else {
      // No business context: callers may only notify themselves.
      target_user_id = req.user.id;
    }

    if (!target_user_id) {
      return res.status(400).json({ error: 'user_id is required' });
    }

    const result = await pool.query(
      `INSERT INTO notifications (user_id, business_id, title, body, type, data)
       VALUES ($1, $2, $3, $4, $5, $6)
       RETURNING *`,
      [target_user_id, business_id || null, title, body, type || 'general', data ? JSON.stringify(data) : null]
    );

    const notification = result.rows[0];

    const io = req.app.get('io');
    if (io) {
      io.to(`user:${target_user_id}`).emit('notification', notification);
      if (business_id) {
        io.to(`business:${business_id}`).emit('notification', notification);
      }
    }

    const devices = await pool.query(
      'SELECT device_id FROM device_tokens WHERE user_id = $1',
      [target_user_id]
    );

    res.status(201).json({
      message: 'Notification sent',
      notification,
      devices_online: devices.rows.length,
    });
  }));

  // ── GET /api/notifications/unread/:userId ────────────────────
  // A user may only read their own notifications.
  router.get('/unread/:userId', asyncHandler(async (req, res) => {
    const { userId } = req.params;
    if (userId !== req.user.id) {
      return res.status(403).json({ error: 'You can only view your own notifications' });
    }
    const { limit: queryLimit } = req.query;
    const limit = Math.min(100, parseInt(queryLimit) || 50);

    const result = await pool.query(
      `SELECT * FROM notifications
       WHERE user_id = $1 AND is_read = false
       ORDER BY created_at DESC
       LIMIT $2`,
      [userId, limit]
    );

    res.json(result.rows);
  }));

  // ── GET /api/notifications/:userId (all notifications) ───────
  router.get('/:userId', asyncHandler(async (req, res) => {
    const { userId } = req.params;
    if (userId !== req.user.id) {
      return res.status(403).json({ error: 'You can only view your own notifications' });
    }
    const { limit: queryLimit, offset: queryOffset, unreadOnly } = req.query;
    const limit = Math.min(100, parseInt(queryLimit) || 50);
    const offset = parseInt(queryOffset) || 0;

    let query = 'SELECT * FROM notifications WHERE user_id = $1';
    const params = [userId];

    if (unreadOnly === 'true') {
      query += ' AND is_read = false';
    }

    const countResult = await pool.query(
      query.replace('SELECT *', 'SELECT COUNT(*)'),
      params
    );
    const total = parseInt(countResult.rows[0].count);

    query += ' ORDER BY created_at DESC LIMIT $2 OFFSET $3';
    params.push(limit, offset);

    const result = await pool.query(query, params);

    res.json({
      data: result.rows,
      pagination: {
        total,
        limit,
        offset,
        remaining: Math.max(0, total - (offset + limit)),
      },
    });
  }));

  // ── PUT /api/notifications/:id/read ──────────────────────────
  // Only the notification's own recipient may mark it read.
  router.put('/:id/read', asyncHandler(async (req, res) => {
    const { id } = req.params;

    const result = await pool.query(
      `UPDATE notifications
       SET is_read = true, read_at = NOW()
       WHERE id = $1 AND user_id = $2
       RETURNING *`,
      [id, req.user.id]
    );

    if (result.rows.length === 0) {
      return res.status(404).json({ error: 'Notification not found' });
    }

    res.json({
      message: 'Notification marked as read',
      notification: result.rows[0],
    });
  }));

  // ── PUT /api/notifications/read-all/:userId ──────────────────
  router.put('/read-all/:userId', asyncHandler(async (req, res) => {
    const { userId } = req.params;
    if (userId !== req.user.id) {
      return res.status(403).json({ error: 'You can only manage your own notifications' });
    }

    const result = await pool.query(
      `UPDATE notifications
       SET is_read = true, read_at = NOW()
       WHERE user_id = $1 AND is_read = false
       RETURNING id`,
      [userId]
    );

    res.json({
      message: `${result.rows.length} notification(s) marked as read`,
      count: result.rows.length,
    });
  }));

  // ── DELETE /api/notifications/:id ────────────────────────────
  // Only the notification's own recipient may delete it.
  router.delete('/:id', asyncHandler(async (req, res) => {
    const { id } = req.params;

    const result = await pool.query(
      'DELETE FROM notifications WHERE id = $1 AND user_id = $2 RETURNING id',
      [id, req.user.id]
    );

    if (result.rows.length === 0) {
      return res.status(404).json({ error: 'Notification not found' });
    }

    res.json({ message: 'Notification deleted', id: parseInt(id) });
  }));

  return router;
};
