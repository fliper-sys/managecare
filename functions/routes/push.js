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
  // Register a device token for push delivery.
  // Body: { device_id, user_id, platform?, device_name? }
  router.post('/register', requireFields('device_id', 'user_id'), asyncHandler(async (req, res) => {
    const { device_id, user_id, platform, device_name } = req.body;

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

    // Emit to connected Socket.IO clients that this user's device list changed
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
  // Unregister a device (remove from device_tokens).
  router.delete('/device/:deviceId', asyncHandler(async (req, res) => {
    const { deviceId } = req.params;

    const result = await pool.query(
      'DELETE FROM device_tokens WHERE device_id = $1 RETURNING *',
      [deviceId]
    );

    if (result.rows.length === 0) {
      return res.status(404).json({ error: 'Device not found' });
    }

    res.json({ message: 'Device unregistered', device_id: deviceId });
  }));

  // ── POST /api/push/send ──────────────────────────────────────
  // Send a notification to a specific user (or broadcast to a business).
  // Body: { user_id, title, body, type?, business_id?, data? }
  // Only the server itself or admin-level callers should invoke this.
  router.post('/send', requireFields('user_id', 'title', 'body'), asyncHandler(async (req, res) => {
    const { user_id, business_id, title, body, type, data } = req.body;

    const result = await pool.query(
      `INSERT INTO notifications (user_id, business_id, title, body, type, data)
       VALUES ($1, $2, $3, $4, $5, $6)
       RETURNING *`,
      [user_id, business_id || null, title, body, type || 'general', data ? JSON.stringify(data) : null]
    );

    const notification = result.rows[0];

    // Deliver in real-time via Socket.IO
    const io = req.app.get('io');
    if (io) {
      // Send to user's personal room
      io.to(`user:${user_id}`).emit('notification', notification);

      // Also send to business room if business_id provided
      if (business_id) {
        io.to(`business:${business_id}`).emit('notification', notification);
      }
    }

    // Also deliver to all connected devices for this user
    const devices = await pool.query(
      'SELECT device_id FROM device_tokens WHERE user_id = $1',
      [user_id]
    );

    res.status(201).json({
      message: 'Notification sent',
      notification,
      devices_online: devices.rows.length,
    });
  }));

  // ── GET /api/notifications/unread/:userId ────────────────────
  // Fetch all unread notifications for a user.
  router.get('/unread/:userId', asyncHandler(async (req, res) => {
    const { userId } = req.params;
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
  // Fetch all notifications for a user (read + unread), paginated.
  router.get('/:userId', asyncHandler(async (req, res) => {
    const { userId } = req.params;
    const { limit: queryLimit, offset: queryOffset, unreadOnly } = req.query;
    const limit = Math.min(100, parseInt(queryLimit) || 50);
    const offset = parseInt(queryOffset) || 0;

    let query = 'SELECT * FROM notifications WHERE user_id = $1';
    const params = [userId];

    if (unreadOnly === 'true') {
      query += ' AND is_read = false';
    }

    // Count total
    const countResult = await pool.query(
      query.replace('SELECT *', 'SELECT COUNT(*)'),
      params
    );
    const total = parseInt(countResult.rows[0].count);

    // Fetch paginated
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
  // Mark a specific notification as read.
  router.put('/:id/read', asyncHandler(async (req, res) => {
    const { id } = req.params;

    const result = await pool.query(
      `UPDATE notifications
       SET is_read = true, read_at = NOW()
       WHERE id = $1
       RETURNING *`,
      [id]
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
  // Mark ALL unread notifications for a user as read.
  router.put('/read-all/:userId', asyncHandler(async (req, res) => {
    const { userId } = req.params;

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
  // Delete a specific notification.
  router.delete('/:id', asyncHandler(async (req, res) => {
    const { id } = req.params;

    const result = await pool.query(
      'DELETE FROM notifications WHERE id = $1 RETURNING id',
      [id]
    );

    if (result.rows.length === 0) {
      return res.status(404).json({ error: 'Notification not found' });
    }

    res.json({ message: 'Notification deleted', id: parseInt(id) });
  }));

  return router;
};
