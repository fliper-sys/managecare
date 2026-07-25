require('dotenv').config();
const express = require('express');
const http = require('http');
const path = require('path');
const { Server } = require('socket.io');
const { Pool } = require('pg');
const jwt = require('jsonwebtoken');
const bcrypt = require('bcrypt');
const cors = require('cors');
const Minio = require('minio');

// ── Route imports ───────────────────────────────────────────
const inventoryRoutes = require('./routes/inventory');
const salesRoutes = require('./routes/sales');
const customersRoutes = require('./routes/customers');
const workersRoutes = require('./routes/workers');
const expensesRoutes = require('./routes/expenses');
const uploadRoutes = require('./routes/upload');
const pushRoutes = require('./routes/push');

// ── Middleware imports ──────────────────────────────────────
const { authMiddleware, requireAuth } = require('./middleware/auth');
const { errorHandler } = require('./middleware/validation');

// ── App setup ───────────────────────────────────────────────
const app = express();
const server = http.createServer(app);
const io = new Server(server, { cors: { origin: '*' } });

// ── PostgreSQL connection pool ──────────────────────────────
const pool = new Pool({
  host: process.env.DB_HOST || 'localhost',
  port: parseInt(process.env.DB_PORT) || 5432,
  user: process.env.DB_USER || 'postgres',
  password: process.env.DB_PASSWORD,
  database: process.env.DB_NAME || 'managecare',
  // Connection pool settings for production
  max: parseInt(process.env.DB_POOL_MAX) || 20,
  idleTimeoutMillis: 30000,
  connectionTimeoutMillis: 5000,
});

// ── MinIO client (optional - for file storage) ──────────────
let minioClient = null;
if (process.env.MINIO_ENDPOINT) {
  minioClient = new Minio.Client({
    endPoint: process.env.MINIO_ENDPOINT,
    port: parseInt(process.env.MINIO_PORT) || 9000,
    useSSL: process.env.MINIO_USE_SSL === 'true',
    accessKey: process.env.MINIO_ACCESS_KEY || 'minioadmin',
    secretKey: process.env.MINIO_SECRET_KEY || 'minioadmin',
  });
  console.log('[MinIO] Client initialized for', process.env.MINIO_ENDPOINT);
}

// ── Middleware ──────────────────────────────────────────────
app.use(cors());
app.use(express.json({ limit: '10mb' }));
app.use(express.urlencoded({ extended: true }));

// Raw text parser ONLY for ADMS routes (device sends plain text, not JSON)
app.use('/iclock', express.text({ type: '*/*' }));

// ── Health check (no auth required) ─────────────────────────
app.get('/api/health', async (req, res) => {
  try {
    await pool.query('SELECT 1');
    res.json({
      status: 'ok',
      timestamp: new Date().toISOString(),
      uptime: process.uptime(),
      memory: process.memoryUsage(),
      database: 'connected',
      minio: minioClient ? 'configured' : 'not configured',
    });
  } catch (err) {
    res.status(503).json({
      status: 'error',
      database: 'disconnected',
      error: err.message,
    });
  }
});

// ── Auth routes (no auth required) ──────────────────────────
app.post('/api/auth/register', async (req, res) => {
  const { email, password, role } = req.body;
  const hash = await bcrypt.hash(password, 10);
  try {
    const result = await pool.query(
      `INSERT INTO workers (email, password_hash, full_name, role)
       VALUES ($1, $2, $3, $4) RETURNING id, email, role`,
      [email, hash, email.split('@')[0], role || 'staff']
    );
    res.json(result.rows[0]);
  } catch (err) {
    res.status(400).json({ error: err.message });
  }
});

app.post('/api/auth/login', async (req, res) => {
  const { email, password } = req.body;
  try {
    // Try workers table first
    let result = await pool.query(
      'SELECT * FROM workers WHERE email = $1 AND is_active = true',
      [email]
    );

    if (result.rows.length === 0) {
      // Try profiles for owner/GoTrue users
      result = await pool.query(
        'SELECT id, email, full_name FROM profiles WHERE email = $1',
        [email]
      );
      if (result.rows.length === 0) {
        return res.status(401).json({ error: 'Invalid credentials' });
      }
    }

    const user = result.rows[0];

    // For GoTrue users, we don't store password_hash here
    if (user.password_hash && !(await bcrypt.compare(password, user.password_hash))) {
      return res.status(401).json({ error: 'Invalid credentials' });
    }

    const token = jwt.sign(
      { id: user.id, email: user.email, role: user.role || 'staff' },
      process.env.JWT_SECRET,
      { expiresIn: '7d' }
    );

    res.json({
      token,
      user: { id: user.id, email: user.email, role: user.role || 'staff', full_name: user.full_name },
    });
  } catch (err) {
    res.status(400).json({ error: err.message });
  }
});

// ── ADMS ROUTES (Hipppoint F16 device talks here) ──────────
app.get('/iclock/cdata', async (req, res) => {
  const { SN } = req.query;
  console.log('[ADMS] Handshake from device:', SN);

  await pool.query(
    `INSERT INTO devices (serial_number, last_seen) VALUES ($1, NOW())
     ON CONFLICT (serial_number) DO UPDATE SET last_seen = NOW()`,
    [SN]
  );

  res.set('Content-Type', 'text/plain');
  res.send(
    'GET OPTION FROM: ' + SN + '\n' +
    'Stamp=9999\nOpStamp=9999\nErrorDelay=30\nDelay=30\n' +
    'TransTimes=00:00;14:05\nTransInterval=1\nTransFlag=1111000000\n' +
    'Realtime=1\nEncrypt=0'
  );
});

app.post('/iclock/cdata', async (req, res) => {
  const { SN, table } = req.query;

  if (table === 'ATTLOG') {
    const rawBody = req.body;
    console.log('[ADMS] Raw ATTLOG from', SN);

    const lines = rawBody.trim().split('\n').filter(Boolean);
    for (const line of lines) {
      const parts = line.split('\t');
      const [userIdOnDevice, timestamp, status, verifyMode] = parts;

      const result = await pool.query(
        `INSERT INTO attendance (device_sn, user_id_on_device, timestamp, status, verify_mode)
         VALUES ($1, $2, $3, $4, $5) RETURNING *`,
        [SN, userIdOnDevice, timestamp, status, verifyMode]
      );

      // Push live update to connected Flutter clients via Socket.io
      io.emit('new_attendance', result.rows[0]);
    }

    await pool.query('UPDATE devices SET last_seen = NOW() WHERE serial_number = $1', [SN]);
  }

  res.send('OK');
});

app.get('/iclock/getrequest', (req, res) => res.send('OK'));
app.post('/iclock/devicecmd', (req, res) => {
  console.log('[ADMS] Device command response:', req.body);
  res.send('OK');
});

// ── Attendance API (for Flutter client) ─────────────────────
app.get('/api/attendance', authMiddleware, async (req, res) => {
  const { businessId, limit: queryLimit } = req.query;
  let query = 'SELECT * FROM attendance';
  const params = [];
  const conditions = [];

  if (businessId) {
    conditions.push('business_id = $' + (params.length + 1));
    params.push(businessId);
  }

  if (conditions.length > 0) {
    query += ' WHERE ' + conditions.join(' AND ');
  }

  query += ' ORDER BY timestamp DESC LIMIT $' + (params.length + 1);
  params.push(parseInt(queryLimit) || 100);

  const result = await pool.query(query, params);
  res.json(result.rows);
});

// ── Business-scoped API routes (require auth) ──────────────
app.use('/api/inventory', authMiddleware, inventoryRoutes(pool));
app.use('/api/sales', authMiddleware, salesRoutes(pool));
app.use('/api/customers', authMiddleware, customersRoutes(pool));
app.use('/api/workers', authMiddleware, workersRoutes(pool));
app.use('/api/expenses', authMiddleware, expensesRoutes(pool));
app.use('/api/upload', authMiddleware, uploadRoutes(pool, minioClient));
// Separate routers for push and notifications
const pushRouter = pushRoutes(pool);
const notificationRouter = pushRoutes(pool);
app.use('/api/push', authMiddleware, pushRouter);
app.use('/api/notifications', authMiddleware, notificationRouter);

// ── Business CRUD routes ────────────────────────────────────
app.get('/api/businesses', authMiddleware, async (req, res) => {
  try {
    const result = await pool.query(
      `SELECT b.* FROM businesses b
       JOIN business_members bm ON bm.business_id = b.id
       WHERE bm.user_id = $1 AND bm.is_active = true AND b.is_active = true
       ORDER BY b.created_at DESC`,
      [req.user.id]
    );
    res.json(result.rows);
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

app.get('/api/businesses/:id', authMiddleware, async (req, res) => {
  try {
    const result = await pool.query(
      'SELECT * FROM businesses WHERE id = $1 AND is_active = true',
      [req.params.id]
    );
    if (result.rows.length === 0) {
      return res.status(404).json({ error: 'Business not found' });
    }
    res.json(result.rows[0]);
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

// ── Subscription validation ─────────────────────────────────
app.post('/api/subscriptions/validate/:businessId', authMiddleware, async (req, res) => {
  try {
    const { businessId } = req.params;
    const result = await pool.query(
      `SELECT is_subscription_active, subscription_end_date
       FROM businesses WHERE id = $1`,
      [businessId]
    );
    if (result.rows.length === 0) {
      return res.status(404).json({ error: 'Business not found' });
    }

    const biz = result.rows[0];
    const isValid = biz.is_subscription_active &&
      (!biz.subscription_end_date || new Date(biz.subscription_end_date) > new Date());

    res.json({
      isValid,
      isActive: biz.is_subscription_active,
      endDate: biz.subscription_end_date,
      now: new Date().toISOString(),
    });
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

// ── Admin API (service-role protected) ─────────────────────
app.post('/admin-api/workers', authMiddleware, async (req, res) => {
  // This endpoint is called from Flutter's AuthenticationService.createWorkerUser
  try {
    const { business_id, email, password, full_name, role, permissions } = req.body;
    const hash = await bcrypt.hash(password, 10);

    const result = await pool.query(
      `INSERT INTO workers (email, full_name, role, business_id, permissions)
       VALUES ($1, $2, $3, $4, $5) RETURNING id, email, full_name, role`,
      [email, full_name, role || 'staff', business_id, JSON.stringify(permissions || {})]
    );

    res.status(201).json(result.rows[0]);
  } catch (err) {
    res.status(400).json({ error: err.message });
  }
});

// ── Error handler (must be last) ────────────────────────────
app.use(errorHandler);

// ── Make Socket.io accessible to route handlers ────────────
app.set('io', io);

// ── Socket.IO ────────────────────────────────────────────────
io.on('connection', (socket) => {
  console.log('[Socket.IO] Client connected:', socket.id);

  socket.on('join_business', (businessId) => {
    socket.join(`business:${businessId}`);
    console.log(`[Socket.IO] ${socket.id} joined business:${businessId}`);
  });

  socket.on('join_user', (userId) => {
    socket.join(`user:${userId}`);
    console.log(`[Socket.IO] ${socket.id} joined user:${userId}`);
  });

  socket.on('disconnect', () => {
    console.log('[Socket.IO] Client disconnected:', socket.id);
  });
});

// ── Server start ─────────────────────────────────────────────
const PORT = process.env.PORT || 3000;
server.listen(PORT, '0.0.0.0', () => {
  console.log(`[Server] ManageCare API running on port ${PORT}`);
  console.log(`[Server] Health check: http://localhost:${PORT}/api/health`);
});
