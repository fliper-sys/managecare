require('dotenv').config();
const express = require('express');
const http = require('http');
const { Server } = require('socket.io');
const { Pool } = require('pg');
const jwt = require('jsonwebtoken');
const bcrypt = require('bcrypt');
const cors = require('cors');

const app = express();
const server = http.createServer(app);
const io = new Server(server, { cors: { origin: '*' } });

const pool = new Pool({
  host: process.env.DB_HOST,
  user: process.env.DB_USER,
  password: process.env.DB_PASSWORD,
  database: process.env.DB_NAME,
});

app.use(cors());
app.use(express.json());

// Raw text parser ONLY for ADMS routes (device sends plain text, not JSON)
app.use('/iclock', express.text({ type: '*/*' }));

// ---------- AUTH ROUTES ----------
app.post('/api/auth/register', async (req, res) => {
  const { email, password, role } = req.body;
  const hash = await bcrypt.hash(password, 10);
  try {
    const result = await pool.query(
      'INSERT INTO users (email, password_hash, role) VALUES ($1, $2, $3) RETURNING id, email, role',
      [email, hash, role || 'staff']
    );
    res.json(result.rows[0]);
  } catch (err) {
    res.status(400).json({ error: err.message });
  }
});

app.post('/api/auth/login', async (req, res) => {
  const { email, password } = req.body;
  const result = await pool.query('SELECT * FROM users WHERE email = $1', [email]);
  const user = result.rows[0];
  if (!user || !(await bcrypt.compare(password, user.password_hash))) {
    return res.status(401).json({ error: 'Invalid credentials' });
  }
  const token = jwt.sign({ id: user.id, role: user.role }, process.env.JWT_SECRET, { expiresIn: '7d' });
  res.json({ token, user: { id: user.id, email: user.email, role: user.role } });
});

function authMiddleware(req, res, next) {
  const token = req.headers.authorization?.split(' ')[1];
  if (!token) return res.status(401).json({ error: 'No token' });
  try {
    req.user = jwt.verify(token, process.env.JWT_SECRET);
    next();
  } catch {
    res.status(401).json({ error: 'Invalid token' });
  }
}

// ---------- ADMS ROUTES (Hipppoint F16 device talks here) ----------

// Device handshake
app.get('/iclock/cdata', async (req, res) => {
  const { SN } = req.query;
  console.log('Handshake from device:', SN);

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

// Attendance log push
app.post('/iclock/cdata', async (req, res) => {
  const { SN, table } = req.query;

  if (table === 'ATTLOG') {
    const rawBody = req.body;
    console.log('Raw ATTLOG from', SN, ':', rawBody);

    const lines = rawBody.trim().split('\n').filter(Boolean);
    for (const line of lines) {
      const parts = line.split('\t');
      const [userIdOnDevice, timestamp, status, verifyMode] = parts;

      await pool.query(
        `INSERT INTO attendance (device_sn, user_id_on_device, timestamp, status, verify_mode)
         VALUES ($1, $2, $3, $4, $5)`,
        [SN, userIdOnDevice, timestamp, status, verifyMode]
      );

      // Push live update to connected Flutter clients via Socket.io
      io.emit('new_attendance', { deviceSN: SN, userIdOnDevice, timestamp, status, verifyMode });
    }

    await pool.query('UPDATE devices SET last_seen = NOW() WHERE serial_number = $1', [SN]);
  }

  res.send('OK');
});

// Command polling
app.get('/iclock/getrequest', (req, res) => {
  res.send('OK'); // no pending commands
});

app.post('/iclock/devicecmd', (req, res) => {
  console.log('Device command response:', req.body);
  res.send('OK');
});

// ---------- APP API (for Flutter client) ----------
app.get('/api/attendance', authMiddleware, async (req, res) => {
  const result = await pool.query(
    'SELECT * FROM attendance ORDER BY timestamp DESC LIMIT 100'
  );
  res.json(result.rows);
});

// ---------- SOCKET.IO ----------
io.on('connection', (socket) => {
  console.log('Client connected:', socket.id);
});

const PORT = process.env.PORT || 80;
server.listen(PORT, () => console.log(`Server running on port ${PORT}`));