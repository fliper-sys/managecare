require('dotenv').config();
const express = require('express');
const http = require('http');
const path = require('path');
const fs = require('fs');
const { Server } = require('socket.io');
const { Pool, types } = require('pg');
// node-postgres returns NUMERIC/DECIMAL columns (OID 1700) as strings by
// default, to avoid precision loss on values bigger than a JS double can
// hold exactly. Every price/quantity/amount column in this schema is
// NUMERIC, and the Flutter client casts them straight to `num`/`double` -
// parse them as floats here so the API always returns real numbers.
types.setTypeParser(1700, (value) => (value === null ? null : parseFloat(value)));
const jwt = require('jsonwebtoken');
const bcrypt = require('bcrypt');
const cors = require('cors');
const Minio = require('minio');

// ── Route imports ───────────────────────────────────────────
const inventoryRoutes = require('./routes/inventory');
const storesRoutes = require('./routes/stores');
const returnsRoutes = require('./routes/returns');
const inventoryAlertsRoutes = require('./routes/inventory_alerts');
const reordersRoutes = require('./routes/reorders');
const salesRoutes = require('./routes/sales');
const customersRoutes = require('./routes/customers');
const workersRoutes = require('./routes/workers');
const adminRoutes = require('./routes/admin');
const expensesRoutes = require('./routes/expenses');
const apartmentsRoutes = require('./routes/apartments');
const pharmacyRoutes = require('./routes/pharmacy');
const drinkRoutes = require('./routes/drink');
const restaurantRoutes = require('./routes/restaurant');
const hotelRoutes = require('./routes/hotel');
const procurementRoutes = require('./routes/procurement');
const pumpsRoutes = require('./routes/pumps');
const subscriptionsRoutes = require('./routes/subscriptions');
const paymentsRoutes = require('./routes/payments');
const distributorsRoutes = require('./routes/distributors');
const invoicesRoutes = require('./routes/invoices');
const uploadRoutes = require('./routes/upload');
const pushRoutes = require('./routes/push');

// ── Middleware imports ──────────────────────────────────────
const { authMiddleware, requireAuth } = require('./middleware/auth');
const { errorHandler } = require('./middleware/validation');
const crypto = require('crypto');
const os = require('os');
const nodemailer = require('nodemailer');

const PUBLIC_URL = process.env.PUBLIC_URL || 'https://backend.managecare.info';

let mailTransporter = null;
if (process.env.SMTP_HOST) {
  mailTransporter = nodemailer.createTransport({
    host: process.env.SMTP_HOST,
    port: parseInt(process.env.SMTP_PORT, 10) || 465,
    secure: (process.env.SMTP_PORT || '465') === '465',
    auth: { user: process.env.SMTP_USER, pass: process.env.SMTP_PASS },
  });
  console.log('[Mail] SMTP transport configured for', process.env.SMTP_HOST);
} else {
  console.warn('[Mail] SMTP_HOST not set - password recovery emails will not be sent');
}

async function sendMail({ to, subject, html }) {
  if (!mailTransporter) {
    throw new Error('SMTP is not configured');
  }
  const info = await mailTransporter.sendMail({
    from: `"${process.env.SMTP_SENDER_NAME || 'ManageCare'}" <${process.env.SMTP_USER}>`,
    to,
    subject,
    html,
  });
  console.log('[Mail] Sent:', info.messageId, 'to', to, 'response:', info.response);
}

// Email HTML needs inline styles, not a <style> block - many clients
// (Outlook desktop, some webmail) strip or ignore <style> tags entirely.
// Table-based layout keeps this rendering consistently across clients.
function renderResetEmailHtml({ name, resetUrl }) {
  const greeting = name ? `Hi ${escapeHtml(name)},` : 'Hi,';
  return `<!doctype html>
<html lang="en">
<head><meta charset="utf-8" /><meta name="viewport" content="width=device-width, initial-scale=1" /></head>
<body style="margin:0; padding:0; background-color:#0d1b2a; font-family:-apple-system,BlinkMacSystemFont,'Segoe UI',Roboto,Helvetica,Arial,sans-serif;">
  <table role="presentation" width="100%" cellpadding="0" cellspacing="0" style="background-color:#0d1b2a; padding:32px 16px;">
    <tr>
      <td align="center">
        <table role="presentation" width="480" cellpadding="0" cellspacing="0" style="max-width:480px; width:100%; background-color:#ffffff; border-radius:16px; overflow:hidden;">
          <tr>
            <td style="background:linear-gradient(135deg,#1a56db,#1543ab); background-color:#1a56db; padding:28px 32px;">
              <span style="color:#ffffff; font-size:20px; font-weight:700; letter-spacing:0.3px;">ManageCare</span>
            </td>
          </tr>
          <tr>
            <td style="padding:32px;">
              <div style="width:56px; height:56px; background-color:#eef2ff; border-radius:14px; text-align:center; line-height:56px; font-size:26px; margin-bottom:20px;">&#128274;</div>
              <h1 style="margin:0 0 16px; font-size:21px; line-height:1.3; color:#10223f; font-weight:700;">Reset your password</h1>
              <p style="margin:0 0 12px; font-size:15px; line-height:1.6; color:#4a5568;">${greeting}</p>
              <p style="margin:0 0 24px; font-size:15px; line-height:1.6; color:#4a5568;">We received a request to reset your ManageCare password. Click the button below to choose a new one. This link expires in <strong>1 hour</strong> and can only be used once.</p>
              <table role="presentation" cellpadding="0" cellspacing="0" style="margin:0 0 24px;">
                <tr>
                  <td style="background-color:#1a56db; border-radius:10px;">
                    <a href="${resetUrl}" style="display:inline-block; padding:14px 28px; font-size:15px; font-weight:600; color:#ffffff; text-decoration:none; border-radius:10px;">Reset Password</a>
                  </td>
                </tr>
              </table>
              <p style="margin:0 0 8px; font-size:13px; line-height:1.6; color:#94a3b8;">Or copy and paste this link into your browser:</p>
              <p style="margin:0 0 24px; font-size:13px; line-height:1.6; word-break:break-all;"><a href="${resetUrl}" style="color:#1a56db; text-decoration:underline;">${resetUrl}</a></p>
              <hr style="border:none; border-top:1px solid #e2e8f0; margin:0 0 20px;" />
              <p style="margin:0; font-size:13px; line-height:1.6; color:#94a3b8;">If you didn't request a password reset, you can safely ignore this email — your password won't be changed.</p>
            </td>
          </tr>
        </table>
        <p style="margin:20px 0 0; font-size:12px; color:#5b7290;">&copy; ${new Date().getFullYear()} ManageCare. This is an automated message, please don't reply.</p>
      </td>
    </tr>
  </table>
</body>
</html>`;
}

function escapeHtml(str) {
  return String(str || '').replace(/[&<>"']/g, (c) => ({
    '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;',
  }[c]));
}

function renderResetPasswordPage({ token, error, success }) {
  const body = success
    ? `
      <h1>Password updated</h1>
      <p>Your password has been changed. You can now sign in with your new password in the ManageCare app.</p>
    `
    : `
      <h1>Reset your password</h1>
      ${error ? `<p class="error">${escapeHtml(error)}</p>` : ''}
      ${token
        ? `
          <form method="POST" action="/reset-password">
            <input type="hidden" name="token" value="${escapeHtml(token)}" />
            <label>New password<input type="password" name="password" minlength="8" required autofocus /></label>
            <label>Confirm new password<input type="password" name="confirm_password" minlength="8" required /></label>
            <button type="submit">Set new password</button>
          </form>
        `
        : '<p>Request a new reset link from the ManageCare app.</p>'}
    `;

  return `<!doctype html>
<html lang="en">
<head>
<meta charset="utf-8" />
<meta name="viewport" content="width=device-width, initial-scale=1" />
<title>ManageCare - Reset Password</title>
<style>
  body { font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif; background: #0d1b2a; color: #1a2438; margin: 0; padding: 0; min-height: 100vh; display: flex; align-items: center; justify-content: center; }
  .card { background: #fff; border-radius: 16px; padding: 32px; max-width: 400px; width: calc(100% - 48px); box-shadow: 0 20px 60px rgba(0,0,0,0.3); }
  h1 { font-size: 22px; margin: 0 0 16px; }
  p { line-height: 1.5; color: #4a5568; }
  .error { color: #c0392b; background: #fdecea; padding: 10px 14px; border-radius: 8px; }
  label { display: block; margin: 16px 0 6px; font-size: 14px; font-weight: 600; }
  input { width: 100%; box-sizing: border-box; padding: 10px 12px; border: 1px solid #d0d7de; border-radius: 8px; font-size: 15px; }
  button { margin-top: 20px; width: 100%; padding: 12px; background: #1a56db; color: #fff; border: none; border-radius: 8px; font-size: 15px; font-weight: 600; cursor: pointer; }
  button:hover { background: #1543ab; }
</style>
</head>
<body>
  <div class="card">${body}</div>
</body>
</html>`;
}

// ── Worker self-service password change ──────────────────────
// A plain web page (no app deep-linking needed) so any worker - business
// staff in `workers`, or account holders in `profiles` - can set a new
// password by email alone, no current password required. Unlike
// /auth/v1/recover (which only looks up `profiles` by email and silently
// no-ops for workers-only accounts), this checks the same email lookup
// order the login route itself uses: profiles, then workers, then
// managecare_workers.
//
// Deliberately NOT gated on the current password: the Firebase->Postgres
// migration left plenty of accounts with a password the worker never
// actually chose (auto-generated, imported, or simply forgotten), so
// requiring it here would just lock people out. This trades verification
// for access during the migration - anyone who knows a worker's email can
// reset that worker's password. Revisit once accounts are fully settled.
const ACCOUNT_TYPE_TABLES = {
  owner: 'profiles',
  worker: 'workers',
  internal: 'managecare_workers',
};

function renderChangePasswordPage({ email, accountType, error, success }) {
  const body = success
    ? `
      <h1>Password updated</h1>
      <p>Your password has been changed. You can now sign in with your new password in the ManageCare app.</p>
    `
    : `
      <h1>Change your password</h1>
      ${error ? `<p class="error">${escapeHtml(error)}</p>` : ''}
      <form method="POST" action="/change-password">
        <label>Account type
          <select name="account_type" required>
            <option value="">Select one...</option>
            <option value="worker" ${accountType === 'worker' ? 'selected' : ''}>Staff / Worker</option>
            <option value="owner" ${accountType === 'owner' ? 'selected' : ''}>Business owner</option>
            <option value="internal" ${accountType === 'internal' ? 'selected' : ''}>ManageCare internal team</option>
          </select>
        </label>
        <p style="margin: -8px 0 0; font-size: 13px; color: #6b7280;">The same email can belong to a separate owner account and a separate staff account - pick which one you're resetting so the right one actually changes.</p>
        <label>Email<input type="email" name="email" value="${escapeHtml(email || '')}" required autofocus /></label>
        <label>New password<input type="password" name="new_password" minlength="8" required /></label>
        <label>Confirm new password<input type="password" name="confirm_password" minlength="8" required /></label>
        <button type="submit">Change password</button>
      </form>
    `;

  return `<!doctype html>
<html lang="en">
<head>
<meta charset="utf-8" />
<meta name="viewport" content="width=device-width, initial-scale=1" />
<title>ManageCare - Change Password</title>
<style>
  body { font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif; background: #0d1b2a; color: #1a2438; margin: 0; padding: 0; min-height: 100vh; display: flex; align-items: center; justify-content: center; }
  .card { background: #fff; border-radius: 16px; padding: 32px; max-width: 400px; width: calc(100% - 48px); box-shadow: 0 20px 60px rgba(0,0,0,0.3); }
  .brand { display: flex; align-items: center; gap: 10px; margin-bottom: 24px; }
  .brand .mark { width: 34px; height: 34px; border-radius: 8px; background: #1a56db; color: #fff; display: flex; align-items: center; justify-content: center; font-weight: 700; font-size: 13px; flex-shrink: 0; }
  .brand .name { font-weight: 700; font-size: 15px; letter-spacing: 0.01em; color: #1a2438; }
  h1 { font-size: 22px; margin: 0 0 16px; }
  p { line-height: 1.5; color: #4a5568; }
  .error { color: #c0392b; background: #fdecea; padding: 10px 14px; border-radius: 8px; }
  label { display: block; margin: 16px 0 6px; font-size: 14px; font-weight: 600; }
  input { width: 100%; box-sizing: border-box; padding: 10px 12px; border: 1px solid #d0d7de; border-radius: 8px; font-size: 15px; }
  button { margin-top: 20px; width: 100%; padding: 12px; background: #1a56db; color: #fff; border: none; border-radius: 8px; font-size: 15px; font-weight: 600; cursor: pointer; }
  button:hover { background: #1543ab; }
</style>
</head>
<body>
  <div class="card">
    <div class="brand"><div class="mark">MC</div><div class="name">ManageCare</div></div>
    ${body}
  </div>
</body>
</html>`;
}

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
app.set('trust proxy', 1); // behind nginx — use X-Forwarded-For for req.ip
app.use(cors());
app.use(express.json({ limit: '10mb' }));
app.use(express.urlencoded({ extended: true }));

// Raw text parser ONLY for ADMS routes (device sends plain text, not JSON)
app.use('/iclock', express.text({ type: '*/*' }));

const normalizeEmail = (email) => (email || '').trim().toLowerCase();

function signAccessToken(user, role = 'authenticated') {
  return jwt.sign(
    {
      sub: user.id,
      id: user.id,
      email: user.email,
      role,
      aud: 'authenticated',
    },
    process.env.JWT_SECRET,
    { expiresIn: '7d', algorithm: 'HS256' }
  );
}

// Refresh tokens are opaque, cryptographically random secrets stored
// server-side (never derivable from the user id) - see refresh_tokens table.
async function issueRefreshToken(dbClient, userId) {
  const token = crypto.randomBytes(32).toString('hex');
  await dbClient.query(
    `INSERT INTO refresh_tokens (token, user_id, expires_at)
     VALUES ($1, $2, NOW() + INTERVAL '30 days')`,
    [token, userId]
  );
  return token;
}

function buildAuthResponse(user, accessToken, refreshToken) {
  const now = new Date().toISOString();
  return {
    access_token: accessToken,
    token_type: 'bearer',
    expires_in: 604800,
    expires_at: Math.floor(Date.now() / 1000) + 604800,
    refresh_token: refreshToken,
    user: {
      id: user.id,
      aud: 'authenticated',
      role: 'authenticated',
      email: user.email,
      email_confirmed_at: user.email_confirmed_at || now,
      phone: user.phone_number || '',
      confirmed_at: user.email_confirmed_at || now,
      last_sign_in_at: now,
      app_metadata: { provider: 'email', providers: ['email'] },
      user_metadata: {
        full_name: user.full_name || '',
        phone_number: user.phone_number || '',
      },
      identities: [],
      created_at: user.created_at || now,
      updated_at: user.updated_at || now,
    },
  };
}

const isIdentifier = (value) => /^[a-zA-Z_][a-zA-Z0-9_]*$/.test(value || '');
const quoteIdentifier = (value) => {
  if (!isIdentifier(value)) {
    throw new Error(`Invalid identifier: ${value}`);
  }
  return `"${value}"`;
};

function getBearerUser(req) {
  const authHeader = req.headers.authorization;
  if (!authHeader || !authHeader.startsWith('Bearer ')) return null;
  try {
    const token = authHeader.substring(7);
    const decoded = jwt.verify(token, process.env.JWT_SECRET);
    return {
      id: decoded.sub || decoded.id,
      email: decoded.email,
      role: decoded.role || 'authenticated',
    };
  } catch (_) {
    return null;
  }
}

function wantsSingleObject(req) {
  return (req.headers.accept || '').includes('application/vnd.pgrst.object+json');
}

function buildRestWhere(query, values) {
  const conditions = [];
  for (const [rawKey, rawValue] of Object.entries(query)) {
    if (['select', 'order', 'limit', 'offset'].includes(rawKey)) continue;
    if (!isIdentifier(rawKey) || typeof rawValue !== 'string') continue;

    const dot = rawValue.indexOf('.');
    const op = dot === -1 ? 'eq' : rawValue.substring(0, dot);
    const value = dot === -1 ? rawValue : rawValue.substring(dot + 1);
    const column = quoteIdentifier(rawKey);

    if (op === 'eq') {
      values.push(value);
      conditions.push(`${column} = $${values.length}`);
    } else if (op === 'neq') {
      values.push(value);
      conditions.push(`${column} <> $${values.length}`);
    } else if (op === 'is') {
      conditions.push(value === 'null' ? `${column} IS NULL` : `${column} IS NOT NULL`);
    } else if (op === 'in') {
      // postgrest-dart quotes each list item defensively (e.g. in.("id1","id2")),
      // which older/simpler clients don't - strip one layer of surrounding
      // quotes per item so both forms parse to the same bare values.
      const items = value.replace(/^\(|\)$/g, '').split(',').filter(Boolean).map((item) => {
        const trimmed = item.trim();
        return trimmed.length >= 2 && trimmed.startsWith('"') && trimmed.endsWith('"')
          ? trimmed.slice(1, -1)
          : trimmed;
      });
      if (items.length > 0) {
        const placeholders = items.map((item) => {
          values.push(item);
          return `$${values.length}`;
        });
        conditions.push(`${column} IN (${placeholders.join(', ')})`);
      }
    } else if (['gt', 'gte', 'lt', 'lte', 'like', 'ilike'].includes(op)) {
      const sqlOp = { gt: '>', gte: '>=', lt: '<', lte: '<=', like: 'LIKE', ilike: 'ILIKE' }[op];
      values.push(value);
      conditions.push(`${column} ${sqlOp} $${values.length}`);
    }
  }

  return conditions.length ? ` WHERE ${conditions.join(' AND ')}` : '';
}

function buildRestOrder(query) {
  if (!query.order || typeof query.order !== 'string') return '';
  const orderParts = query.order.split(',').map((part) => {
    const [column, direction] = part.split('.');
    if (!isIdentifier(column)) return null;
    const dir = direction === 'desc' ? 'DESC' : 'ASC';
    return `${quoteIdentifier(column)} ${dir}`;
  }).filter(Boolean);
  return orderParts.length ? ` ORDER BY ${orderParts.join(', ')}` : '';
}

function buildRestLimit(query, values) {
  let clause = '';
  const limit = parseInt(query.limit, 10);
  const offset = parseInt(query.offset, 10);
  if (Number.isFinite(limit) && limit >= 0) {
    values.push(limit);
    clause += ` LIMIT $${values.length}`;
  }
  if (Number.isFinite(offset) && offset >= 0) {
    values.push(offset);
    clause += ` OFFSET $${values.length}`;
  }
  return clause;
}

// ── GoTrue-compatible auth endpoints ────────────────────────
// Supabase Flutter client SDK calls /auth/v1/* paths directly.
// Since we don't run a full Supabase Kong gateway, we proxy
// these to our custom auth endpoints.
app.post('/auth/v1/signup', async (req, res) => {
  const email = normalizeEmail(req.body.email);
  const { password, data } = req.body;

  if (!email || !password) {
    return res.status(400).json({ error: 'email and password are required' });
  }

  try {
    const existing = await pool.query('SELECT id FROM profiles WHERE lower(email) = $1', [email]);
    if (existing.rows.length > 0) {
      return res.status(400).json({ error: 'User already registered' });
    }

    const hash = await bcrypt.hash(password, 10);
    const result = await pool.query(
      `INSERT INTO profiles (email, password_hash, full_name, phone_number, pin)
       VALUES ($1, $2, $3, $4, $5)
       RETURNING id, email, full_name, phone_number, created_at, updated_at`,
      [
        email,
        hash,
        data?.full_name || data?.name || email.split('@')[0],
        data?.phone_number || data?.phone || null,
        data?.pin || '1234',
      ]
    );

    const user = result.rows[0];
    const token = signAccessToken(user);
    const newRefreshToken = await issueRefreshToken(pool, user.id);
    res.status(200).json(buildAuthResponse(user, token, newRefreshToken));
  } catch (err) {
    res.status(400).json({ error: err.message });
  }
});

app.post('/auth/v1/token', async (req, res) => {
  // Grant type = password → login
  // Grant type = refresh_token → session refresh
  const { email, password, refresh_token } = req.body;
  const grant_type = req.body.grant_type || req.query.grant_type;
  try {
    if (grant_type === 'refresh_token' && refresh_token) {
      const tokenRow = await pool.query(
        'SELECT user_id FROM refresh_tokens WHERE token = $1 AND expires_at > NOW()',
        [refresh_token]
      );
      if (tokenRow.rows.length === 0) {
        return res.status(401).json({ error: 'Invalid refresh token' });
      }
      const result = await pool.query(
        'SELECT id, email, full_name, phone_number, created_at, updated_at FROM profiles WHERE id = $1',
        [tokenRow.rows[0].user_id]
      );
      if (result.rows.length === 0) {
        return res.status(401).json({ error: 'Invalid refresh token' });
      }
      const user = result.rows[0];
      const token = signAccessToken(user);
      // Rotate: invalidate the used refresh token, issue a fresh one.
      await pool.query('DELETE FROM refresh_tokens WHERE token = $1', [refresh_token]);
      const newRefreshToken = await issueRefreshToken(pool, user.id);
      return res.json(buildAuthResponse(user, token, newRefreshToken));
    }

    // Standard login. The same email can be a completely separate account
    // in more than one of these tables (an owner's profiles row and a
    // workers row created for them by a business, for instance) - stopping
    // at the first table with a matching email meant the account you
    // actually meant to log into could be unreachable whenever a collision
    // existed, no matter what password you typed. So instead of returning
    // on the first email match, check every matching candidate and let the
    // password itself pick which account is meant.
    const normalizedEmail = normalizeEmail(email);
    const candidates = [
      ...(await pool.query(
        'SELECT * FROM profiles WHERE lower(email) = $1 AND COALESCE(is_active, true) = true',
        [normalizedEmail]
      )).rows,
      ...(await pool.query(
        'SELECT * FROM workers WHERE lower(email) = $1 AND is_active = true',
        [normalizedEmail]
      )).rows,
      // Internal ManageCare staff (programmers/testers/etc.) - column
      // aliases match what buildAuthResponse() below reads from `user`.
      ...(await pool.query(
        `SELECT *, name AS full_name, phone AS phone_number
         FROM managecare_workers WHERE lower(email) = $1 AND is_active = true`,
        [normalizedEmail]
      )).rows,
    ];

    let user = null;
    for (const candidate of candidates) {
      if (candidate.password_hash && await bcrypt.compare(password || '', candidate.password_hash)) {
        user = candidate;
        break;
      }
    }
    if (!user) {
      return res.status(401).json({ error: 'Invalid credentials' });
    }

    const token = signAccessToken(user);
    const newRefreshToken = await issueRefreshToken(pool, user.id);
    res.json(buildAuthResponse(user, token, newRefreshToken));
  } catch (err) {
    res.status(400).json({ error: err.message });
  }
});

app.get('/auth/v1/user', async (req, res) => {
  // Extract JWT from Authorization header
  const authHeader = req.headers.authorization;
  if (!authHeader || !authHeader.startsWith('Bearer ')) {
    return res.status(401).json({ error: 'No token provided' });
  }
  try {
    const token = authHeader.substring(7);
    const decoded = jwt.verify(token, process.env.JWT_SECRET);
    const userId = decoded.sub || decoded.id;
    const result = await pool.query(
      'SELECT id, email, full_name, phone_number, created_at, updated_at FROM profiles WHERE id = $1',
      [userId]
    );
    if (result.rows.length === 0) {
      return res.status(404).json({ error: 'User not found' });
    }
    const user = result.rows[0];
    res.json({
      id: user.id,
      email: user.email,
      user_metadata: { full_name: user.full_name },
      app_metadata: { role: 'authenticated' },
      aud: 'authenticated',
    });
  } catch (err) {
    res.status(401).json({ error: 'Invalid token' });
  }
});

app.put('/auth/v1/user', async (req, res) => {
  const authHeader = req.headers.authorization;
  if (!authHeader || !authHeader.startsWith('Bearer ')) {
    return res.status(401).json({ error: 'No token provided' });
  }
  try {
    const token = authHeader.substring(7);
    const decoded = jwt.verify(token, process.env.JWT_SECRET);
    const userId = decoded.sub || decoded.id;
    const { email, password, data } = req.body;
    const updates = {};
    if (email) updates.email = email;
    if (password) {
      const hash = await bcrypt.hash(password, 10);
      updates.password_hash = hash;
    }
    if (data) updates.full_name = data.full_name;
    if (Object.keys(updates).length > 0) {
      await pool.query(
        'UPDATE profiles SET ' + Object.keys(updates).map((k, i) => `${k} = $${i + 2}`).join(', ') + ' WHERE id = $1',
        [userId, ...Object.values(updates)]
      );
    }
    res.json({ id: userId, email: updates.email || decoded.email });
  } catch (err) {
    res.status(400).json({ error: err.message });
  }
});

app.post('/auth/v1/logout', async (req, res) => {
  // Revoke the refresh token if the client sends one, so a captured token
  // can't be replayed after the user has signed out.
  const { refresh_token } = req.body || {};
  if (refresh_token) {
    try {
      await pool.query('DELETE FROM refresh_tokens WHERE token = $1', [refresh_token]);
    } catch (_) {
      // Non-fatal - logout should still succeed even if this fails.
    }
  }
  res.json({});
});

// ── Password recovery ───────────────────────────────────────
// AuthService.sendPasswordResetEmail (gotrue-dart's resetPasswordForEmail)
// POSTs to /auth/v1/recover with an email + PKCE fields we don't need to
// validate for this simplified flow. The user completes the reset on a
// plain web page (the Flutter app has no deep-link handling for this -
// forgot_password_screen.dart just tells the user to check their email),
// so there's no need to replicate GoTrue's PKCE code-exchange flow.
app.post('/auth/v1/recover', async (req, res) => {
  try {
    const email = normalizeEmail(req.body?.email);
    if (!email) {
      return res.status(400).json({ error: 'email is required' });
    }

    const result = await pool.query(
      'SELECT id, full_name FROM profiles WHERE lower(email) = $1',
      [email]
    );

    // Always respond success regardless of whether the account exists,
    // to avoid leaking which emails are registered.
    if (result.rows.length > 0) {
      const user = result.rows[0];
      const token = crypto.randomBytes(32).toString('hex');
      await pool.query(
        `INSERT INTO password_reset_tokens (token, user_id, expires_at)
         VALUES ($1, $2, NOW() + INTERVAL '1 hour')`,
        [token, user.id]
      );

      const resetUrl = `${PUBLIC_URL}/reset-password?token=${token}`;
      try {
        await sendMail({
          to: email,
          subject: 'Reset your ManageCare password',
          html: renderResetEmailHtml({ name: user.full_name, resetUrl }),
        });
      } catch (mailErr) {
        console.error('[recover] Failed to send reset email:', mailErr.message);
      }
    }

    res.json({});
  } catch (err) {
    res.status(400).json({ error: err.message });
  }
});

// ── GET /reset-password?token=... - serves a minimal, self-contained form.
app.get('/reset-password', async (req, res) => {
  const token = typeof req.query.token === 'string' ? req.query.token : '';
  res.set('Content-Type', 'text/html; charset=utf-8');
  res.send(renderResetPasswordPage({ token }));
});

// ── POST /reset-password - processes the form submission.
app.post('/reset-password', express.urlencoded({ extended: true }), async (req, res) => {
  const { token, password, confirm_password } = req.body || {};
  res.set('Content-Type', 'text/html; charset=utf-8');

  if (!token) {
    return res.status(400).send(renderResetPasswordPage({ token: '', error: 'Missing reset token.' }));
  }
  if (!password || password.length < 8) {
    return res.status(400).send(renderResetPasswordPage({ token, error: 'Password must be at least 8 characters.' }));
  }
  if (password !== confirm_password) {
    return res.status(400).send(renderResetPasswordPage({ token, error: 'Passwords do not match.' }));
  }

  try {
    const tokenRow = await pool.query(
      'SELECT user_id FROM password_reset_tokens WHERE token = $1 AND used_at IS NULL AND expires_at > NOW()',
      [token]
    );
    if (tokenRow.rows.length === 0) {
      return res.status(400).send(renderResetPasswordPage({ token: '', error: 'This reset link is invalid or has expired. Request a new one from the app.' }));
    }

    const userId = tokenRow.rows[0].user_id;
    const hash = await bcrypt.hash(password, 10);

    const client = await pool.connect();
    try {
      await client.query('BEGIN');
      await client.query('UPDATE profiles SET password_hash = $1, updated_at = NOW() WHERE id = $2', [hash, userId]);
      await client.query('UPDATE workers SET password_hash = $1, updated_at = NOW() WHERE id = $2', [hash, userId]);
      await client.query('UPDATE password_reset_tokens SET used_at = NOW() WHERE token = $1', [token]);
      // Revoke any existing sessions - a leaked old refresh token shouldn't
      // survive a password reset.
      await client.query('DELETE FROM refresh_tokens WHERE user_id = $1', [userId]);
      await client.query('COMMIT');
    } catch (e) {
      await client.query('ROLLBACK');
      throw e;
    } finally {
      client.release();
    }

    res.send(renderResetPasswordPage({ token: '', success: true }));
  } catch (err) {
    res.status(500).send(renderResetPasswordPage({ token, error: 'Something went wrong. Please try again.' }));
  }
});

app.get('/change-password', (req, res) => {
  res.set('Content-Type', 'text/html; charset=utf-8');
  res.send(renderChangePasswordPage({}));
});

app.post('/change-password', express.urlencoded({ extended: true }), async (req, res) => {
  const { email, account_type, new_password, confirm_password } = req.body || {};
  res.set('Content-Type', 'text/html; charset=utf-8');

  const normalizedEmail = normalizeEmail(email);
  const table = ACCOUNT_TYPE_TABLES[account_type];
  if (!table) {
    return res.status(400).send(renderChangePasswordPage({ email, error: 'Select an account type.' }));
  }
  if (!normalizedEmail) {
    return res.status(400).send(renderChangePasswordPage({ email, accountType: account_type, error: 'Email is required.' }));
  }
  if (!new_password || new_password.length < 8) {
    return res.status(400).send(renderChangePasswordPage({ email, accountType: account_type, error: 'New password must be at least 8 characters.' }));
  }
  if (new_password !== confirm_password) {
    return res.status(400).send(renderChangePasswordPage({ email, accountType: account_type, error: 'New passwords do not match.' }));
  }

  try {
    // Scoped to exactly the selected table - the same email can be a
    // completely separate account in profiles vs. workers (different id,
    // different password_hash). Searching all three in priority order (the
    // way /auth/v1/token itself resolves a login) meant this endpoint could
    // silently change the wrong one - e.g. a worker's email that also
    // happens to match a profiles/owner account got the *owner's* password
    // changed, and logging in with it then authenticated as the owner.
    const result = await pool.query(
      `SELECT * FROM ${table} WHERE lower(email) = $1 AND COALESCE(is_active, true) = true`,
      [normalizedEmail]
    );
    const user = result.rows[0];

    if (!user) {
      // Deliberately generic - don't reveal whether the email exists.
      return res.status(400).send(renderChangePasswordPage({ email, accountType: account_type, error: 'No matching account found for that email and account type.' }));
    }

    const hash = await bcrypt.hash(new_password, 10);
    await pool.query(`UPDATE ${table} SET password_hash = $1, updated_at = NOW() WHERE id = $2`, [hash, user.id]);
    // A leaked old refresh token shouldn't survive a password change.
    await pool.query('DELETE FROM refresh_tokens WHERE user_id = $1', [user.id]);

    res.send(renderChangePasswordPage({ success: true }));
  } catch (err) {
    res.status(500).send(renderChangePasswordPage({ email, accountType: account_type, error: 'Something went wrong. Please try again.' }));
  }
});

// ── Minimal PostgREST-compatible API for supabase_flutter ───
// Supports the subset used by the migrated Flutter repositories:
// from(table).select/insert/update/upsert/delete with eq/order/limit filters,
// plus rpc('create_business_with_owner') and rpc('get_daily_sales_summary').
//
// Unlike real PostgREST (which relies on Postgres RLS policies to enforce
// per-row access transparently), this hand-rolled layer has no such
// database-level protection - authorization must be enforced explicitly
// here, per table, before any query runs.
app.options('/rest/v1/*', (_req, res) => res.sendStatus(204));

// Columns that must never be returned by the generic REST layer.
const SENSITIVE_COLUMNS = ['password_hash'];
function stripSensitive(row) {
  if (!row || typeof row !== 'object') return row;
  const clean = { ...row };
  for (const col of SENSITIVE_COLUMNS) delete clean[col];
  return clean;
}
function stripSensitiveRows(rows) {
  return Array.isArray(rows) ? rows.map(stripSensitive) : stripSensitive(rows);
}

// Tables scoped by a business_id column - access requires the caller to be
// an active member of that business.
const BUSINESS_SCOPED_TABLES = new Set([
  'inventory', 'sales', 'customers', 'workers',
  'expenses', 'procurements', 'distributors', 'subscription_transactions',
  'notifications', 'device_tokens',
]);

async function isBusinessMember(userId, businessId) {
  const result = await pool.query(
    'SELECT 1 FROM business_members WHERE user_id = $1 AND business_id = $2 AND is_active = true',
    [userId, businessId]
  );
  return result.rows.length > 0;
}

async function isBusinessOwner(userId, businessId) {
  const result = await pool.query(
    'SELECT 1 FROM business_members WHERE user_id = $1 AND business_id = $2 AND is_owner = true AND is_active = true',
    [userId, businessId]
  );
  return result.rows.length > 0;
}

// Requires auth on every /rest/v1/:table request, then enforces per-table
// tenant isolation before the request reaches the generic query builder.
async function restAuthorize(req, res, next) {
  const bearerUser = getBearerUser(req);
  if (!bearerUser) {
    return res.status(401).json({ error: 'Authentication required' });
  }
  req.user = bearerUser;

  const table = req.params.table;

  if (table === 'profiles') {
    // Self-service only via this generic layer.
    if (req.method === 'GET' || req.method === 'PATCH') {
      req.query.id = `eq.${bearerUser.id}`;
      return next();
    }
    return res.status(403).json({ error: 'Not permitted on this table' });
  }

  if (table === 'businesses') {
    if (req.method === 'GET') {
      // Filtered post-query below (see handler) to the caller's businesses.
      return next();
    }
    if (req.method === 'PATCH') {
      const targetId = typeof req.query.id === 'string' && req.query.id.startsWith('eq.')
        ? req.query.id.slice(3)
        : null;
      if (!targetId) {
        return res.status(400).json({ error: 'id filter is required' });
      }
      if (!(await isBusinessOwner(bearerUser.id, targetId))) {
        return res.status(403).json({ error: 'Only the business owner can update this business' });
      }
      return next();
    }
    return res.status(403).json({ error: 'Not permitted on this table' });
  }

  if (table === 'business_members') {
    // Membership rows control role/ownership - mutations must go through
    // the dedicated worker-management endpoints (/admin-api/workers,
    // /api/workers), which apply proper owner-only checks. Reads only here.
    if (req.method !== 'GET') {
      return res.status(403).json({ error: 'Use /api/workers to manage business membership' });
    }
    const rawBusinessId = req.query.business_id;
    const businessId = typeof rawBusinessId === 'string' && rawBusinessId.startsWith('eq.')
      ? rawBusinessId.slice(3)
      : null;
    if (businessId) {
      if (!(await isBusinessMember(bearerUser.id, businessId))) {
        return res.status(403).json({ error: 'You are not a member of this business' });
      }
      return next();
    }
    // No business_id filter: allow a caller to look up their OWN
    // memberships by user_id (needed to discover which businesses they
    // belong to in the first place - e.g. right after signing in).
    const rawUserId = req.query.user_id;
    const userId = typeof rawUserId === 'string' && rawUserId.startsWith('eq.')
      ? rawUserId.slice(3)
      : null;
    if (userId && userId === bearerUser.id) {
      return next();
    }
    return res.status(400).json({ error: 'A business_id filter, or a user_id filter matching yourself, is required' });
  }

  if (BUSINESS_SCOPED_TABLES.has(table)) {
    // Worker records grant role/permissions - like business_members,
    // mutating them requires owner status, matching /api/workers.
    const requiresOwner = table === 'workers' && req.method !== 'GET';

    if (req.method === 'POST') {
      const rows = Array.isArray(req.body) ? req.body : [req.body || {}];
      for (const row of rows) {
        if (!row.business_id) {
          return res.status(403).json({ error: 'business_id is required' });
        }
        const allowed = requiresOwner
          ? await isBusinessOwner(bearerUser.id, row.business_id)
          : await isBusinessMember(bearerUser.id, row.business_id);
        if (!allowed) {
          return res.status(403).json({ error: 'Not permitted for this business' });
        }
      }
      return next();
    }
    // GET / PATCH / DELETE all require an explicit business_id=eq.X filter.
    const raw = req.query.business_id;
    const businessId = typeof raw === 'string' && raw.startsWith('eq.') ? raw.slice(3) : null;
    if (!businessId) {
      return res.status(400).json({ error: 'business_id filter is required' });
    }
    const allowed = requiresOwner
      ? await isBusinessOwner(bearerUser.id, businessId)
      : await isBusinessMember(bearerUser.id, businessId);
    if (!allowed) {
      return res.status(403).json({ error: 'Not permitted for this business' });
    }
    return next();
  }

  // Any table not explicitly handled above is denied by default.
  return res.status(403).json({ error: `Direct access to '${table}' is not permitted` });
}

app.post('/rest/v1/rpc/create_business_with_owner', async (req, res) => {
  const bearerUser = getBearerUser(req);
  if (!bearerUser) {
    return res.status(401).json({ error: 'Authentication required' });
  }
  // The owner is always the authenticated caller - a client-supplied
  // owner id is never trusted, to prevent assigning businesses to
  // arbitrary users.
  const ownerId = bearerUser.id;
  const {
    p_business_id,
    p_name,
    p_business_type,
    p_address,
    p_phone,
    p_email,
    p_currency,
    p_logo_url,
    p_subscription_tier,
    p_subscription_plan,
    p_subscription_start_date,
    p_subscription_end_date,
    p_is_subscription_active,
  } = req.body || {};

  if (!p_name) {
    return res.status(400).json({ error: 'p_name is required' });
  }

  const client = await pool.connect();
  try {
    await client.query('BEGIN');
    const businessResult = await client.query(
      `INSERT INTO businesses (
         id, name, business_type, owner_id, address, phone, email, currency,
         logo_url, subscription_tier, subscription_plan, subscription_start_date,
         subscription_end_date, is_subscription_active, is_active
       )
       VALUES (COALESCE($1, uuid_generate_v4()), $2, $3, $4, $5, $6, $7, COALESCE($8, 'NGN'),
         $9, COALESCE($10, 'free'), COALESCE($11, 'free'), $12, $13, COALESCE($14, true), true)
       ON CONFLICT (id) DO UPDATE SET
         name = EXCLUDED.name,
         business_type = EXCLUDED.business_type,
         owner_id = EXCLUDED.owner_id,
         address = EXCLUDED.address,
         phone = EXCLUDED.phone,
         email = EXCLUDED.email,
         currency = EXCLUDED.currency,
         logo_url = EXCLUDED.logo_url,
         subscription_tier = EXCLUDED.subscription_tier,
         subscription_plan = EXCLUDED.subscription_plan,
         subscription_start_date = EXCLUDED.subscription_start_date,
         subscription_end_date = EXCLUDED.subscription_end_date,
         is_subscription_active = EXCLUDED.is_subscription_active,
         is_active = true,
         updated_at = NOW()
       RETURNING id`,
      [
        p_business_id || null,
        p_name,
        p_business_type || null,
        ownerId,
        p_address || null,
        p_phone || null,
        p_email || null,
        p_currency || 'NGN',
        p_logo_url || null,
        p_subscription_tier || 'free',
        p_subscription_plan || p_subscription_tier || 'free',
        p_subscription_start_date || null,
        p_subscription_end_date || null,
        typeof p_is_subscription_active === 'boolean' ? p_is_subscription_active : true,
      ]
    );
    const businessId = businessResult.rows[0].id;
    await client.query(
      `INSERT INTO business_members (user_id, business_id, role, is_owner, is_active)
       VALUES ($1, $2, 'owner', true, true)
       ON CONFLICT (user_id, business_id) DO UPDATE SET
         role = 'owner',
         is_owner = true,
         is_active = true,
         updated_at = NOW()`,
      [ownerId, businessId]
    );
    await client.query(
      'UPDATE profiles SET current_business_id = COALESCE(current_business_id, $2), updated_at = NOW() WHERE id = $1',
      [ownerId, businessId]
    );
    await client.query('COMMIT');
    res.json(businessId);
  } catch (err) {
    await client.query('ROLLBACK');
    res.status(400).json({ error: err.message });
  } finally {
    client.release();
  }
});

app.post('/rest/v1/rpc/get_daily_sales_summary', async (req, res) => {
  const bearerUser = getBearerUser(req);
  if (!bearerUser) {
    return res.status(401).json({ error: 'Authentication required' });
  }
  const { p_business_id, p_date } = req.body || {};
  if (!p_business_id) {
    return res.status(400).json({ error: 'p_business_id is required' });
  }
  if (!(await isBusinessMember(bearerUser.id, p_business_id))) {
    return res.status(403).json({ error: 'You are not a member of this business' });
  }
  try {
    const result = await pool.query(
      'SELECT * FROM get_daily_sales_summary($1, COALESCE($2::date, CURRENT_DATE))',
      [p_business_id, p_date || null]
    );
    res.json(result.rows);
  } catch (err) {
    res.status(400).json({ error: err.message });
  }
});

app.get('/rest/v1/:table', restAuthorize, async (req, res) => {
  try {
    const table = quoteIdentifier(req.params.table);
    const values = [];
    const where = buildRestWhere(req.query, values);
    const order = buildRestOrder(req.query);
    const limit = buildRestLimit(req.query, values);
    let rows = (await pool.query(`SELECT * FROM ${table}${where}${order}${limit}`, values)).rows;

    // businesses has no direct membership filter applied above (a caller
    // may legitimately list several businesses at once) - post-filter here.
    if (req.params.table === 'businesses') {
      const memberships = await pool.query(
        'SELECT business_id FROM business_members WHERE user_id = $1 AND is_active = true',
        [req.user.id]
      );
      const allowed = new Set(memberships.rows.map((m) => m.business_id));
      rows = rows.filter((r) => allowed.has(r.id));
    }

    rows = stripSensitiveRows(rows);

    if (wantsSingleObject(req)) {
      return rows.length ? res.json(rows[0]) : res.status(406).json({ error: 'No rows found' });
    }
    res.json(rows);
  } catch (err) {
    res.status(400).json({ error: err.message });
  }
});

app.post('/rest/v1/:table', restAuthorize, async (req, res) => {
  try {
    const table = quoteIdentifier(req.params.table);
    const rows = Array.isArray(req.body) ? req.body : [req.body || {}];
    const inserted = [];

    for (const row of rows) {
      const keys = Object.keys(row).filter(isIdentifier);
      if (keys.length === 0) {
        return res.status(400).json({ error: 'No valid fields supplied' });
      }

      const values = keys.map((key) => row[key]);
      const columns = keys.map(quoteIdentifier).join(', ');
      const placeholders = keys.map((_, index) => `$${index + 1}`).join(', ');
      const prefer = req.headers.prefer || '';
      const onConflict = typeof req.query.on_conflict === 'string' && isIdentifier(req.query.on_conflict)
        ? req.query.on_conflict
        : 'id';
      const isUpsert = prefer.includes('resolution=');
      const updateKeys = keys.filter((key) => key !== onConflict);
      const conflictSql = isUpsert
        ? updateKeys.length > 0
          ? ` ON CONFLICT (${quoteIdentifier(onConflict)}) DO UPDATE SET ${updateKeys
              .map((key) => `${quoteIdentifier(key)} = EXCLUDED.${quoteIdentifier(key)}`)
              .join(', ')}`
          : ` ON CONFLICT (${quoteIdentifier(onConflict)}) DO NOTHING`
        : '';
      const result = await pool.query(
        `INSERT INTO ${table} (${columns}) VALUES (${placeholders})${conflictSql} RETURNING *`,
        values
      );
      inserted.push(stripSensitive(result.rows[0]));
    }

    const body = Array.isArray(req.body) ? inserted : inserted[0];
    res.status(201).json(body);
  } catch (err) {
    res.status(400).json({ error: err.message });
  }
});

app.patch('/rest/v1/:table', restAuthorize, async (req, res) => {
  try {
    const table = quoteIdentifier(req.params.table);
    const keys = Object.keys(req.body || {}).filter(isIdentifier);
    if (keys.length === 0) {
      return res.status(400).json({ error: 'No valid fields supplied' });
    }

    const values = keys.map((key) => req.body[key]);
    const setSql = keys.map((key, index) => `${quoteIdentifier(key)} = $${index + 1}`).join(', ');
    const where = buildRestWhere(req.query, values);
    const result = await pool.query(`UPDATE ${table} SET ${setSql}${where} RETURNING *`, values);
    const rows = stripSensitiveRows(result.rows);
    res.json(wantsSingleObject(req) ? rows[0] : rows);
  } catch (err) {
    res.status(400).json({ error: err.message });
  }
});

app.delete('/rest/v1/:table', restAuthorize, async (req, res) => {
  try {
    const table = quoteIdentifier(req.params.table);
    const values = [];
    const where = buildRestWhere(req.query, values);
    if (!where) {
      return res.status(400).json({ error: 'DELETE requires a filter' });
    }
    const result = await pool.query(`DELETE FROM ${table}${where} RETURNING *`, values);
    res.json(wantsSingleObject(req) ? result.rows[0] : result.rows);
  } catch (err) {
    res.status(400).json({ error: err.message });
  }
});

// ── Status dashboard auth (password-gated) ──────────────────
const STATUS_COOKIE_NAME = 'mc_status_auth';
const STATUS_COOKIE_SECRET = process.env.JWT_SECRET || 'managecare-status-fallback-secret';

function signStatusToken() {
  return crypto.createHmac('sha256', STATUS_COOKIE_SECRET).update('status-dashboard-access-v1').digest('hex');
}

function parseCookies(req) {
  const header = req.headers.cookie;
  const out = {};
  if (!header) return out;
  header.split(';').forEach((part) => {
    const idx = part.indexOf('=');
    if (idx === -1) return;
    const key = part.slice(0, idx).trim();
    const val = decodeURIComponent(part.slice(idx + 1).trim());
    out[key] = val;
  });
  return out;
}

function hasStatusAccess(req) {
  const cookies = parseCookies(req);
  return Boolean(cookies[STATUS_COOKIE_NAME]) && cookies[STATUS_COOKIE_NAME] === signStatusToken();
}

// Lightweight in-memory brute-force guard (5 attempts / 15 min per IP)
const statusLoginAttempts = new Map();
function isStatusLoginRateLimited(ip) {
  const entry = statusLoginAttempts.get(ip);
  if (!entry) return false;
  if (Date.now() > entry.resetAt) {
    statusLoginAttempts.delete(ip);
    return false;
  }
  return entry.count >= 5;
}
function recordFailedStatusLogin(ip) {
  const entry = statusLoginAttempts.get(ip) || { count: 0, resetAt: Date.now() + 15 * 60 * 1000 };
  entry.count += 1;
  statusLoginAttempts.set(ip, entry);
}

app.post('/api/status-auth', (req, res) => {
  const ip = req.ip || req.socket?.remoteAddress || 'unknown';
  if (isStatusLoginRateLimited(ip)) {
    return res.status(429).json({ error: 'Too many attempts. Try again in a few minutes.' });
  }
  const password = req.body?.password;
  const expected = process.env.STATUS_PAGE_PASSWORD;
  if (!expected) {
    return res.status(503).json({ error: 'Status dashboard password is not configured on the server.' });
  }
  if (password !== expected) {
    recordFailedStatusLogin(ip);
    return res.status(401).json({ error: 'Incorrect password' });
  }
  statusLoginAttempts.delete(ip);
  res.cookie(STATUS_COOKIE_NAME, signStatusToken(), {
    httpOnly: true,
    secure: true,
    sameSite: 'lax',
    maxAge: 12 * 60 * 60 * 1000,
  });
  res.json({ ok: true });
});

app.get('/api/status-logout', (req, res) => {
  res.clearCookie(STATUS_COOKIE_NAME);
  res.redirect('/');
});

// ── Status dashboard data ────────────────────────────────────
const STATUS_TABLE_GROUPS = {
  Core: [['businesses', 'Businesses'], ['profiles', 'Users'], ['business_members', 'Business memberships'], ['workers', 'Workers'], ['managecare_workers', 'Managecare workers']],
  Commerce: [['sales', 'Sales'], ['sale_items', 'Sale items'], ['sale_deletions', 'Sale deletions'], ['inventory', 'Inventory items'], ['inventory_batches', 'Inventory batches'], ['inventory_history', 'Inventory history'], ['inventory_alert_acks', 'Inventory alert acks'], ['procurements', 'Procurements'], ['customers', 'Customers'], ['stores', 'Stores'], ['returns', 'Returns'], ['reorders', 'Reorders']],
  Verticals: [['apartments', 'Apartments'], ['apartment_units', 'Apartment units'], ['apartment_bookings', 'Apartment bookings'], ['apartment_booking_payments', 'Apartment booking payments'], ['pumps', 'Pumps'], ['pump_daily_uploads', 'Pump uploads'], ['pump_upload_adjustments', 'Pump upload adjustments'], ['restaurant_orders', 'Restaurant orders'], ['restaurant_menu_items', 'Restaurant menu items'], ['restaurant_tables', 'Restaurant tables'], ['restaurant_reservations', 'Restaurant reservations'], ['restaurant_staff', 'Restaurant staff'], ['restaurant_waste', 'Restaurant waste'], ['hotel_rooms', 'Hotel rooms'], ['hotel_guests', 'Hotel guests'], ['hotel_reservations', 'Hotel reservations'], ['hotel_folio_charges', 'Hotel folio charges'], ['hotel_service_orders', 'Hotel service orders'], ['pharmacy_patients', 'Pharmacy patients'], ['pharmacy_prescriptions', 'Pharmacy prescriptions'], ['pharmacy_treatments', 'Pharmacy treatments'], ['pharmacy_audit_log', 'Pharmacy audit log'], ['bakery_resupplies', 'Bakery resupplies'], ['distributors', 'Distributors'], ['distributor_sales', 'Distributor sales'], ['drink_orders', 'Drink orders'], ['bar_tables', 'Bar tables'], ['bar_invoices', 'Bar invoices'], ['attendance', 'Attendance'], ['devices', 'Devices']],
  Finance: [['payment_transactions', 'Payment transactions'], ['subscription_requests', 'Subscription requests'], ['subscription_events', 'Subscription events'], ['subscription_transactions', 'Subscription transactions'], ['invoices', 'Invoices'], ['expenses', 'Expenses'], ['company_expenses', 'Company expenses'], ['app_marketers', 'App marketers']],
  System: [['notifications', 'Notifications'], ['admin_notifications', 'Admin notifications'], ['admin_settings', 'Admin settings'], ['admin_work_items', 'Admin work items'], ['admin_email_logs', 'Admin email logs'], ['device_tokens', 'Device tokens'], ['refresh_tokens', 'Refresh tokens'], ['password_reset_tokens', 'Password reset tokens'], ['realtime_subscriptions', 'Realtime subscriptions'], ['sync_audit_log', 'Sync audit log']],
};

const STATUS_MODULES = [
  'Inventory', 'Stores', 'Sales', 'Returns', 'Reorders', 'Customers', 'Workers',
  'Admin', 'Expenses', 'Apartments', 'Pharmacy', 'Drink', 'Restaurant', 'Hotel',
  'Procurement', 'Pumps', 'Subscriptions', 'Payments', 'Distributors', 'Invoices', 'Upload',
  'Internal Worker Logins', 'Work Item Assignment',
];

async function gatherStatusData() {
  const startedAt = Date.now();
  let dbStatus = 'connected';
  let dbLatencyMs = null;
  let dbSize = null;

  try {
    const t0 = Date.now();
    await pool.query('SELECT 1');
    dbLatencyMs = Date.now() - t0;
    const sizeResult = await pool.query('SELECT pg_size_pretty(pg_database_size(current_database())) AS size');
    dbSize = sizeResult.rows[0].size;
  } catch (err) {
    dbStatus = 'disconnected';
  }

  const counts = {};
  const countJobs = [];
  Object.values(STATUS_TABLE_GROUPS).flat().forEach(([table, label]) => {
    countJobs.push(
      pool.query(`SELECT COUNT(*)::int AS n FROM ${table}`)
        .then((r) => { counts[label] = r.rows[0].n; })
        .catch(() => { counts[label] = null; })
    );
  });
  await Promise.all(countJobs);

  let businessTypes = [];
  try {
    const r = await pool.query(`
      SELECT COALESCE(NULLIF(TRIM(business_type), ''), 'unspecified') AS type, COUNT(*)::int AS n
      FROM businesses GROUP BY 1 ORDER BY n DESC LIMIT 14
    `);
    businessTypes = r.rows;
  } catch (err) { /* businesses table unreachable */ }

  let recentSignups7d = null;
  try {
    const r = await pool.query(`SELECT COUNT(*)::int AS n FROM profiles WHERE created_at >= NOW() - INTERVAL '7 days'`);
    recentSignups7d = r.rows[0].n;
  } catch (err) { /* profiles.created_at unavailable */ }

  let buckets = [];
  if (minioClient) {
    try {
      const list = await minioClient.listBuckets();
      buckets = list.map((b) => ({ name: b.name, createdAt: b.creationDate }));
    } catch (err) { /* minio unreachable */ }
  }

  const mem = process.memoryUsage();
  const cpus = os.cpus();

  return {
    generatedAt: new Date().toISOString(),
    renderTimeMs: Date.now() - startedAt,
    overallOk: dbStatus === 'connected',
    db: {
      status: dbStatus,
      latencyMs: dbLatencyMs,
      size: dbSize,
      pool: { total: pool.totalCount, idle: pool.idleCount, waiting: pool.waitingCount, max: pool.options?.max ?? null },
    },
    minio: { configured: Boolean(minioClient), buckets },
    process: {
      uptimeSeconds: process.uptime(),
      pid: process.pid,
      nodeVersion: process.version,
      env: process.env.NODE_ENV || 'production',
      memory: { rss: mem.rss, heapTotal: mem.heapTotal, heapUsed: mem.heapUsed, external: mem.external },
    },
    system: {
      hostname: os.hostname(),
      platform: os.platform(),
      release: os.release(),
      arch: os.arch(),
      cpuModel: cpus[0] ? cpus[0].model : 'unknown',
      cpuCores: cpus.length,
      loadAvg: os.loadavg(),
      totalMemGB: (os.totalmem() / 1024 / 1024 / 1024).toFixed(1),
      freeMemGB: (os.freemem() / 1024 / 1024 / 1024).toFixed(1),
      uptimeSeconds: os.uptime(),
    },
    counts,
    groups: Object.fromEntries(Object.entries(STATUS_TABLE_GROUPS).map(([k, arr]) => [k, arr.map(([, label]) => label)])),
    tableGroups: Object.fromEntries(Object.entries(STATUS_TABLE_GROUPS).map(([k, arr]) => [k, arr.map(([table, label]) => ({ table, label }))])),
    businessTypes,
    recentSignups7d,
    modules: STATUS_MODULES,
  };
}

function formatDuration(totalSeconds) {
  const s = Math.floor(totalSeconds);
  const d = Math.floor(s / 86400);
  const h = Math.floor((s % 86400) / 3600);
  const m = Math.floor((s % 3600) / 60);
  const parts = [];
  if (d) parts.push(`${d}d`);
  if (h) parts.push(`${h}h`);
  parts.push(`${m}m`);
  return parts.join(' ');
}

const STATUS_MB = (n) => (n / 1024 / 1024).toFixed(1);

function renderStatusLockScreen(errorMsg) {
  return `<!doctype html>
<html lang="en">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>ManageCare Backend — Locked</title>
<style>
  :root { color-scheme: dark; }
  * { box-sizing: border-box; }
  @keyframes drift { 0% { background-position: 0% 0%; } 100% { background-position: 100% 100%; } }
  @keyframes floatGlow { 0%,100% { transform: translateY(0) scale(1); opacity: 0.85; } 50% { transform: translateY(-6px) scale(1.05); opacity: 1; } }
  @keyframes shake { 10%,90% { transform: translateX(-1px); } 20%,80% { transform: translateX(2px); } 30%,50%,70% { transform: translateX(-4px); } 40%,60% { transform: translateX(4px); } }
  @keyframes fadeUp { from { opacity: 0; transform: translateY(14px); } to { opacity: 1; transform: translateY(0); } }
  body {
    margin: 0; min-height: 100vh; display: flex; align-items: center; justify-content: center;
    font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, Helvetica, Arial, sans-serif;
    background: linear-gradient(120deg, #0b1120, #171033, #0b1120, #0d1a33);
    background-size: 300% 300%;
    animation: drift 18s ease infinite;
    color: #e6ebf5;
    padding: 20px;
  }
  .card {
    width: 100%; max-width: 380px;
    background: rgba(255,255,255,0.05);
    border: 1px solid rgba(255,255,255,0.1);
    border-radius: 20px; padding: 40px 32px;
    backdrop-filter: blur(16px);
    box-shadow: 0 20px 60px rgba(0,0,0,0.4);
    animation: fadeUp 0.6s ease;
    text-align: center;
  }
  .card.shake { animation: shake 0.5s; }
  .lock-icon {
    width: 56px; height: 56px; margin: 0 auto 20px; border-radius: 16px;
    background: linear-gradient(135deg, #6366f1, #22d3ee);
    display: flex; align-items: center; justify-content: center;
    animation: floatGlow 3s ease-in-out infinite;
    box-shadow: 0 0 30px rgba(99,102,241,0.5);
  }
  h1 { font-size: 18px; margin: 0 0 4px; font-weight: 650; letter-spacing: -0.01em; }
  .sub { color: #8b95ab; font-size: 13px; margin-bottom: 28px; }
  input {
    width: 100%; padding: 13px 14px; border-radius: 10px; margin-bottom: 14px;
    background: rgba(255,255,255,0.06); border: 1px solid rgba(255,255,255,0.12);
    color: #e6ebf5; font-size: 14px; outline: none; transition: border-color 0.2s, box-shadow 0.2s;
  }
  input:focus { border-color: #6366f1; box-shadow: 0 0 0 3px rgba(99,102,241,0.2); }
  button {
    width: 100%; padding: 13px; border-radius: 10px; border: none; cursor: pointer;
    background: linear-gradient(135deg, #6366f1, #22d3ee); color: #05070d;
    font-weight: 650; font-size: 14px; transition: opacity 0.2s, transform 0.15s;
  }
  button:hover { opacity: 0.92; transform: translateY(-1px); }
  button:disabled { opacity: 0.6; cursor: default; transform: none; }
  .error { color: #f87171; font-size: 13px; margin-top: 14px; min-height: 16px; }
</style>
</head>
<body>
  <div class="card" id="lock-card">
    <div class="lock-icon">
      <svg width="26" height="26" viewBox="0 0 24 24" fill="none" stroke="#05070d" stroke-width="2.2" stroke-linecap="round" stroke-linejoin="round">
        <rect x="4" y="11" width="16" height="10" rx="2"></rect>
        <path d="M8 11V7a4 4 0 0 1 8 0v4"></path>
      </svg>
    </div>
    <h1>ManageCare Backend</h1>
    <div class="sub">Enter the access password to view the status dashboard</div>
    <form id="lock-form">
      <input type="password" id="lock-password" placeholder="Password" autocomplete="current-password" autofocus required />
      <button type="submit">Unlock</button>
      <div class="error" id="lock-error">${errorMsg ? errorMsg : ''}</div>
    </form>
  </div>
  <script>
    (function () {
      const form = document.getElementById('lock-form');
      const input = document.getElementById('lock-password');
      const card = document.getElementById('lock-card');
      const errorEl = document.getElementById('lock-error');
      form.addEventListener('submit', async function (e) {
        e.preventDefault();
        errorEl.textContent = '';
        const btn = form.querySelector('button');
        btn.disabled = true; btn.textContent = 'Verifying…';
        try {
          const res = await fetch('/api/status-auth', {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify({ password: input.value }),
          });
          if (res.ok) {
            window.location.reload();
            return;
          }
          const data = await res.json().catch(function () { return {}; });
          errorEl.textContent = data.error || 'Incorrect password';
          card.classList.remove('shake'); void card.offsetWidth; card.classList.add('shake');
          btn.disabled = false; btn.textContent = 'Unlock';
          input.select();
        } catch (err) {
          errorEl.textContent = 'Network error — try again';
          btn.disabled = false; btn.textContent = 'Unlock';
        }
      });
    })();
  </script>
</body>
</html>`;
}

function renderStatusDashboard(data) {
  const overallOk = data.overallOk;
  const groupLabels = { Core: 'Core', Commerce: 'Commerce', Verticals: 'Verticals', Finance: 'Finance', System: 'System' };
  const maxBusinessType = Math.max(1, ...data.businessTypes.map((r) => r.n));

  const countCardsForGroup = (groupName) => (data.groups[groupName] || []).map((label) => `
        <div class="card fade-in">
          <div class="label">${label}</div>
          <div class="value" data-count="${data.counts[label] ?? 0}">0</div>
        </div>`).join('');

  return `<!doctype html>
<html lang="en">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>ManageCare Backend — Status</title>
<style>
  :root { color-scheme: dark; }
  * { box-sizing: border-box; }
  @keyframes drift { 0% { background-position: 0% 0%; } 100% { background-position: 100% 100%; } }
  @keyframes fadeIn { from { opacity: 0; transform: translateY(10px); } to { opacity: 1; transform: translateY(0); } }
  @keyframes pulse { 0%,100% { box-shadow: 0 0 0 0 rgba(74,222,128,0.4); } 50% { box-shadow: 0 0 0 6px rgba(74,222,128,0); } }
  @keyframes pulseBad { 0%,100% { box-shadow: 0 0 0 0 rgba(248,113,113,0.4); } 50% { box-shadow: 0 0 0 6px rgba(248,113,113,0); } }
  @keyframes spin { to { transform: rotate(360deg); } }
  body {
    margin: 0; min-height: 100vh;
    font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, Helvetica, Arial, sans-serif;
    background: linear-gradient(120deg, #0b1120, #151233, #0b1120, #0d1a33);
    background-size: 300% 300%;
    animation: drift 25s ease infinite;
    color: #e6ebf5;
    padding: 40px 20px 64px;
  }
  .wrap { max-width: 1080px; margin: 0 auto; }
  .topbar { display: flex; align-items: center; justify-content: space-between; flex-wrap: wrap; gap: 16px; margin-bottom: 24px; }
  .brand { display: flex; align-items: center; gap: 14px; }
  .brand .logo {
    width: 44px; height: 44px; border-radius: 12px;
    background: linear-gradient(135deg, #6366f1, #22d3ee);
    display: flex; align-items: center; justify-content: center;
    font-weight: 700; font-size: 20px; color: #05070d;
  }
  .brand h1 { font-size: 21px; margin: 0; font-weight: 650; letter-spacing: -0.02em; }
  .brand .sub { color: #8b95ab; font-size: 12.5px; margin-top: 2px; }
  .top-actions { display: flex; align-items: center; gap: 12px; }
  .status-pill {
    display: inline-flex; align-items: center; gap: 8px;
    padding: 7px 14px; border-radius: 999px; font-size: 13px; font-weight: 600;
    background: ${overallOk ? 'rgba(34,197,94,0.12)' : 'rgba(239,68,68,0.12)'};
    color: ${overallOk ? '#4ade80' : '#f87171'};
    border: 1px solid ${overallOk ? 'rgba(74,222,128,0.3)' : 'rgba(248,113,113,0.3)'};
  }
  .status-pill .dot {
    width: 8px; height: 8px; border-radius: 50%;
    background: ${overallOk ? '#4ade80' : '#f87171'};
    animation: ${overallOk ? 'pulse' : 'pulseBad'} 2s infinite;
  }
  .logout-link { color: #8b95ab; font-size: 12.5px; text-decoration: none; border: 1px solid rgba(255,255,255,0.12); padding: 7px 12px; border-radius: 999px; transition: color 0.2s, border-color 0.2s; }
  .logout-link:hover { color: #e6ebf5; border-color: rgba(255,255,255,0.3); }
  .tabs { display: flex; gap: 4px; overflow-x: auto; border-bottom: 1px solid rgba(255,255,255,0.08); margin-bottom: 28px; }
  .tab-btn {
    background: none; border: none; color: #8b95ab; font-size: 13.5px; font-weight: 600;
    padding: 12px 16px; cursor: pointer; white-space: nowrap; position: relative; transition: color 0.2s;
  }
  .tab-btn:hover { color: #c7cede; }
  .tab-btn.active { color: #e6ebf5; }
  .tab-btn.active::after {
    content: ''; position: absolute; left: 10px; right: 10px; bottom: -1px; height: 2px;
    background: linear-gradient(90deg, #6366f1, #22d3ee); border-radius: 2px;
  }
  .tab-panel { display: none; animation: fadeIn 0.4s ease; }
  .tab-panel.active { display: block; }
  .grid { display: grid; grid-template-columns: repeat(auto-fit, minmax(190px, 1fr)); gap: 14px; margin-bottom: 28px; }
  .card {
    background: rgba(255,255,255,0.04);
    border: 1px solid rgba(255,255,255,0.08);
    border-radius: 16px; padding: 16px 18px;
    backdrop-filter: blur(10px);
    transition: transform 0.2s, border-color 0.2s, background 0.2s;
    animation: fadeIn 0.5s ease backwards;
  }
  .card:hover { transform: translateY(-3px); border-color: rgba(99,102,241,0.35); background: rgba(255,255,255,0.06); }
  .card .label { font-size: 11.5px; color: #8b95ab; text-transform: uppercase; letter-spacing: 0.06em; margin-bottom: 6px; }
  .card .value { font-size: 22px; font-weight: 650; }
  .card .value.small { font-size: 14.5px; font-weight: 550; }
  .card .value.ok { color: #4ade80; }
  .card .value.bad { color: #f87171; }
  section.block { margin-bottom: 30px; }
  section.block h2 {
    font-size: 12.5px; text-transform: uppercase; letter-spacing: 0.08em;
    color: #8b95ab; font-weight: 650; margin: 0 0 14px;
  }
  .modules { display: flex; flex-wrap: wrap; gap: 8px; }
  .modules span {
    padding: 6px 12px; border-radius: 8px; font-size: 13px;
    background: rgba(99,102,241,0.12); color: #a5b4fc;
    border: 1px solid rgba(99,102,241,0.25);
  }
  .meta-table { width: 100%; border-collapse: collapse; font-size: 13px; }
  .meta-table td { padding: 10px 0; border-bottom: 1px solid rgba(255,255,255,0.06); }
  .meta-table td:first-child { color: #8b95ab; width: 240px; }
  code { background: rgba(255,255,255,0.06); padding: 2px 6px; border-radius: 4px; font-size: 12px; }
  .bar-row { display: flex; align-items: center; gap: 12px; margin-bottom: 10px; }
  .bar-row .bar-label { width: 150px; font-size: 12.5px; color: #c7cede; text-transform: capitalize; flex-shrink: 0; }
  .bar-row .bar-track { flex: 1; height: 10px; border-radius: 6px; background: rgba(255,255,255,0.06); overflow: hidden; }
  .bar-row .bar-fill { height: 100%; border-radius: 6px; background: linear-gradient(90deg, #6366f1, #22d3ee); animation: fadeIn 0.6s ease; }
  .bar-row .bar-n { width: 44px; text-align: right; font-size: 12.5px; color: #8b95ab; flex-shrink: 0; }
  .bucket-list { display: flex; flex-direction: column; gap: 8px; }
  .bucket-list .bucket { display: flex; align-items: center; gap: 10px; padding: 10px 14px; background: rgba(255,255,255,0.04); border: 1px solid rgba(255,255,255,0.08); border-radius: 10px; font-size: 13px; }
  .spinner-dot { width: 6px; height: 6px; border-radius: 50%; background: #22d3ee; animation: pulse 2s infinite; }
  .browser-toolbar { display: flex; flex-wrap: wrap; gap: 10px; align-items: center; margin-bottom: 16px; }
  .browser-toolbar select, .browser-toolbar input {
    background: rgba(255,255,255,0.05); border: 1px solid rgba(255,255,255,0.14); color: #e6ebf5;
    padding: 9px 12px; border-radius: 8px; font-size: 13px; outline: none;
  }
  .browser-toolbar select:focus, .browser-toolbar input:focus { border-color: #6366f1; }
  .browser-toolbar input { flex: 1; min-width: 180px; }
  .browser-btn {
    background: linear-gradient(135deg, #6366f1, #22d3ee); color: #05070d; border: none;
    padding: 9px 18px; border-radius: 8px; font-size: 13px; font-weight: 650; cursor: pointer;
    transition: opacity 0.2s, transform 0.15s;
  }
  .browser-btn:hover { opacity: 0.9; transform: translateY(-1px); }
  .browser-btn:disabled { opacity: 0.5; cursor: default; transform: none; }
  .browser-count { color: #8b95ab; font-size: 12.5px; margin-left: auto; }
  .browser-results { overflow-x: auto; border: 1px solid rgba(255,255,255,0.08); border-radius: 12px; }
  .browser-results table { width: 100%; border-collapse: collapse; font-size: 12.5px; white-space: nowrap; }
  .browser-results th { text-align: left; padding: 10px 14px; background: rgba(255,255,255,0.05); color: #8b95ab; font-weight: 600; text-transform: uppercase; font-size: 10.5px; letter-spacing: 0.05em; position: sticky; top: 0; }
  .browser-results td { padding: 9px 14px; border-top: 1px solid rgba(255,255,255,0.06); color: #c7cede; max-width: 280px; overflow: hidden; text-overflow: ellipsis; }
  .browser-results tr:hover td { background: rgba(255,255,255,0.03); }
  footer { color: #5b6480; font-size: 12px; margin-top: 40px; text-align: center; }
  footer #last-updated { color: #8b95ab; }
</style>
</head>
<body>
  <div class="wrap">
    <div class="topbar">
      <div class="brand">
        <div class="logo">MC</div>
        <div>
          <h1>ManageCare Backend</h1>
          <div class="sub">Self-hosted API — Express + PostgreSQL + MinIO</div>
        </div>
      </div>
      <div class="top-actions">
        <div class="status-pill"><span class="dot"></span>${overallOk ? 'All systems operational' : 'Degraded — database unreachable'}</div>
        <a class="logout-link" href="/docs">Blueprint</a>
        <a class="logout-link" href="/api/status-logout">Lock</a>
      </div>
    </div>

    <div class="tabs">
      <button class="tab-btn active" data-tab="overview">Overview</button>
      <button class="tab-btn" data-tab="database">Database</button>
      <button class="tab-btn" data-tab="business-types">Business Types</button>
      <button class="tab-btn" data-tab="browser">Data Browser</button>
      <button class="tab-btn" data-tab="system">System</button>
      <button class="tab-btn" data-tab="modules">Modules & Storage</button>
    </div>

    <div class="tab-panel active" id="panel-overview">
      <section class="block">
        <h2>Live status</h2>
        <div class="grid">
          <div class="card"><div class="label">Database</div><div class="value ${data.db.status === 'connected' ? 'ok' : 'bad'} small" id="live-db-status">${data.db.status === 'connected' ? `Connected · ${data.db.latencyMs}ms` : 'Disconnected'}</div></div>
          <div class="card"><div class="label">Database size</div><div class="value small">${data.db.size || '—'}</div></div>
          <div class="card"><div class="label">Storage (MinIO)</div><div class="value ${data.minio.configured ? 'ok' : 'bad'} small">${data.minio.configured ? 'Configured' : 'Not configured'}</div></div>
          <div class="card"><div class="label">Process uptime</div><div class="value small">${formatDuration(data.process.uptimeSeconds)}</div></div>
        </div>
      </section>
      <section class="block">
        <h2>Key metrics</h2>
        <div class="grid">
          <div class="card"><div class="label">Businesses</div><div class="value" data-count="${data.counts['Businesses'] ?? 0}">0</div></div>
          <div class="card"><div class="label">Users</div><div class="value" data-count="${data.counts['Users'] ?? 0}">0</div></div>
          <div class="card"><div class="label">Sales</div><div class="value" data-count="${data.counts['Sales'] ?? 0}">0</div></div>
          <div class="card"><div class="label">Inventory items</div><div class="value" data-count="${data.counts['Inventory items'] ?? 0}">0</div></div>
          <div class="card"><div class="label">New users (7d)</div><div class="value" data-count="${data.recentSignups7d ?? 0}">0</div></div>
          <div class="card"><div class="label">DB pool (active/idle)</div><div class="value small">${data.db.pool.total - data.db.pool.idle} / ${data.db.pool.idle}</div></div>
        </div>
      </section>
    </div>

    <div class="tab-panel" id="panel-database">
      ${Object.keys(data.groups).map((groupName) => `
      <section class="block">
        <h2>${groupLabels[groupName] || groupName}</h2>
        <div class="grid">${countCardsForGroup(groupName)}</div>
      </section>`).join('')}
    </div>

    <div class="tab-panel" id="panel-business-types">
      <section class="block">
        <h2>Businesses by vertical</h2>
        ${data.businessTypes.length === 0 ? '<div style="color:#8b95ab;font-size:13px;">No business data available.</div>' : data.businessTypes.map((row) => `
        <div class="bar-row">
          <div class="bar-label">${row.type}</div>
          <div class="bar-track"><div class="bar-fill" style="width:${Math.max(4, (row.n / maxBusinessType) * 100)}%"></div></div>
          <div class="bar-n">${row.n}</div>
        </div>`).join('')}
      </section>
    </div>

    <div class="tab-panel" id="panel-browser">
      <section class="block">
        <h2>Browse stored data</h2>
        <p style="color:#8b95ab;font-size:13px;margin:0 0 14px;">Look at real rows from any tracked table — businesses, users, sales, and everything else the counts above are drawn from.</p>
        <div class="browser-toolbar">
          <select id="browser-table"></select>
          <input type="text" id="browser-search" placeholder="Filter by name (if this table has one)…" autocomplete="off" />
          <select id="browser-limit">
            <option value="25">25 rows</option>
            <option value="50" selected>50 rows</option>
            <option value="100">100 rows</option>
            <option value="200">200 rows</option>
          </select>
          <button id="browser-load" class="browser-btn">Load</button>
          <span id="browser-count" class="browser-count"></span>
        </div>
        <div id="browser-results" class="browser-results">
          <div style="color:#8b95ab;font-size:13px;">Pick a table above and click Load.</div>
        </div>
      </section>
    </div>

    <div class="tab-panel" id="panel-system">
      <section class="block">
        <h2>Runtime</h2>
        <table class="meta-table">
          <tr><td>Server time (UTC)</td><td>${data.generatedAt}</td></tr>
          <tr><td>Node.js</td><td>${data.process.nodeVersion}</td></tr>
          <tr><td>Environment</td><td>${data.process.env}</td></tr>
          <tr><td>Process ID</td><td>${data.process.pid}</td></tr>
          <tr><td>Process memory (RSS)</td><td>${STATUS_MB(data.process.memory.rss)} MB</td></tr>
          <tr><td>Heap used / total</td><td>${STATUS_MB(data.process.memory.heapUsed)} MB / ${STATUS_MB(data.process.memory.heapTotal)} MB</td></tr>
          <tr><td>Response time</td><td>${data.renderTimeMs}ms</td></tr>
          <tr><td>Health endpoint</td><td><code>GET /api/health</code></td></tr>
        </table>
      </section>
      <section class="block">
        <h2>Host</h2>
        <table class="meta-table">
          <tr><td>Hostname</td><td>${data.system.hostname}</td></tr>
          <tr><td>Platform</td><td>${data.system.platform} / ${data.system.arch}</td></tr>
          <tr><td>OS release</td><td>${data.system.release}</td></tr>
          <tr><td>CPU</td><td>${data.system.cpuModel} (${data.system.cpuCores} cores)</td></tr>
          <tr><td>Load average (1m/5m/15m)</td><td>${data.system.loadAvg.map((n) => n.toFixed(2)).join(' / ')}</td></tr>
          <tr><td>System memory</td><td>${data.system.freeMemGB} GB free / ${data.system.totalMemGB} GB total</td></tr>
          <tr><td>Host uptime</td><td>${formatDuration(data.system.uptimeSeconds)}</td></tr>
        </table>
      </section>
    </div>

    <div class="tab-panel" id="panel-modules">
      <section class="block">
        <h2>API Modules (${data.modules.length})</h2>
        <div class="modules">${data.modules.map((m) => `<span>${m}</span>`).join('')}</div>
      </section>
      <section class="block">
        <h2>MinIO buckets</h2>
        ${data.minio.buckets.length === 0 ? '<div style="color:#8b95ab;font-size:13px;">No buckets found or MinIO not reachable.</div>' : `
        <div class="bucket-list">${data.minio.buckets.map((b) => `<div class="bucket"><span class="spinner-dot"></span>${b.name}</div>`).join('')}</div>`}
      </section>
    </div>

    <footer>ManageCare · backend.managecare.info · last updated <span id="last-updated">${new Date(data.generatedAt).toLocaleTimeString()}</span></footer>
  </div>
  <script>
    (function () {
      const tabs = document.querySelectorAll('.tab-btn');
      const panels = document.querySelectorAll('.tab-panel');
      tabs.forEach(function (btn) {
        btn.addEventListener('click', function () {
          tabs.forEach(function (b) { b.classList.remove('active'); });
          panels.forEach(function (p) { p.classList.remove('active'); });
          btn.classList.add('active');
          document.getElementById('panel-' + btn.dataset.tab).classList.add('active');
        });
      });

      function animateCount(el) {
        const target = parseFloat(el.dataset.count);
        if (isNaN(target)) return;
        const duration = 900;
        const start = performance.now();
        function step(now) {
          const progress = Math.min((now - start) / duration, 1);
          const eased = 1 - Math.pow(1 - progress, 3);
          const value = Math.round(target * eased);
          el.textContent = value.toLocaleString();
          if (progress < 1) requestAnimationFrame(step);
          else el.textContent = target.toLocaleString();
        }
        requestAnimationFrame(step);
      }
      document.querySelectorAll('[data-count]').forEach(animateCount);

      async function refresh() {
        try {
          const res = await fetch('/api/status-data', { credentials: 'same-origin' });
          if (res.status === 401) { window.location.reload(); return; }
          const data = await res.json();
          document.getElementById('last-updated').textContent = new Date(data.generatedAt).toLocaleTimeString();
          const dbEl = document.getElementById('live-db-status');
          if (dbEl) dbEl.textContent = data.db.status === 'connected' ? ('Connected · ' + data.db.latencyMs + 'ms') : 'Disconnected';
        } catch (e) { /* ignore transient poll failures */ }
      }
      setInterval(refresh, 30000);

      // ── Data Browser ────────────────────────────────────────
      const TABLE_GROUPS = ${JSON.stringify(data.tableGroups)};
      const tableSelect = document.getElementById('browser-table');
      Object.entries(TABLE_GROUPS).forEach(function ([groupName, tables]) {
        const optgroup = document.createElement('optgroup');
        optgroup.label = groupName;
        tables.forEach(function (t) {
          const opt = document.createElement('option');
          opt.value = t.table;
          opt.textContent = t.label;
          optgroup.appendChild(opt);
        });
        tableSelect.appendChild(optgroup);
      });

      function escapeHtml(str) {
        return String(str).replace(/[&<>"']/g, function (c) {
          return { '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' }[c];
        });
      }

      function formatCell(value) {
        if (value === null || value === undefined) return '<span style="color:#4b5568;">—</span>';
        if (typeof value === 'object') return escapeHtml(JSON.stringify(value));
        return escapeHtml(String(value));
      }

      async function loadBrowserTable() {
        const table = tableSelect.value;
        const search = document.getElementById('browser-search').value.trim();
        const limit = document.getElementById('browser-limit').value;
        const btn = document.getElementById('browser-load');
        const countEl = document.getElementById('browser-count');
        const resultsEl = document.getElementById('browser-results');
        btn.disabled = true;
        btn.textContent = 'Loading…';
        resultsEl.innerHTML = '<div style="color:#8b95ab;font-size:13px;">Loading…</div>';
        try {
          const params = new URLSearchParams({ limit: limit });
          if (search) params.set('search', search);
          const res = await fetch('/api/status-table/' + encodeURIComponent(table) + '?' + params.toString(), { credentials: 'same-origin' });
          if (res.status === 401) { window.location.reload(); return; }
          const data = await res.json();
          if (!res.ok) {
            resultsEl.innerHTML = '<div style="color:#f87171;font-size:13px;">' + escapeHtml(data.error || 'Failed to load table') + '</div>';
            countEl.textContent = '';
            return;
          }
          countEl.textContent = data.count + ' row' + (data.count === 1 ? '' : 's');
          if (data.rows.length === 0) {
            resultsEl.innerHTML = '<div style="color:#8b95ab;font-size:13px;padding:16px;">No rows found.</div>';
            return;
          }
          const cols = data.columns.filter(function (c) { return data.rows.some(function (r) { return r[c] !== null && r[c] !== undefined; }); });
          const head = '<tr>' + cols.map(function (c) { return '<th>' + escapeHtml(c) + '</th>'; }).join('') + '</tr>';
          const body = data.rows.map(function (row) {
            return '<tr>' + cols.map(function (c) { return '<td title="' + escapeHtml(row[c]) + '">' + formatCell(row[c]) + '</td>'; }).join('') + '</tr>';
          }).join('');
          resultsEl.innerHTML = '<table><thead>' + head + '</thead><tbody>' + body + '</tbody></table>';
        } catch (e) {
          resultsEl.innerHTML = '<div style="color:#f87171;font-size:13px;">Request failed: ' + escapeHtml(e.message) + '</div>';
        } finally {
          btn.disabled = false;
          btn.textContent = 'Load';
        }
      }
      document.getElementById('browser-load').addEventListener('click', loadBrowserTable);
      document.getElementById('browser-search').addEventListener('keydown', function (e) { if (e.key === 'Enter') loadBrowserTable(); });
    })();
  </script>
</body>
</html>`;
}

// ── Landing / status dashboard (password-gated) ──────────────
app.get('/', async (req, res) => {
  if (!hasStatusAccess(req)) {
    return res.set('Content-Type', 'text/html; charset=utf-8').send(renderStatusLockScreen());
  }
  const data = await gatherStatusData();
  res.set('Content-Type', 'text/html; charset=utf-8').send(renderStatusDashboard(data));
});

// Static reference doc (schema/auth/storage/API/timeline) — same session
// cookie as the dashboard, so unlocking once covers both pages.
const BLUEPRINT_PATH = path.join(__dirname, 'static', 'blueprint.html');
app.get('/docs', (req, res) => {
  if (!hasStatusAccess(req)) {
    return res.set('Content-Type', 'text/html; charset=utf-8').send(renderStatusLockScreen());
  }
  fs.readFile(BLUEPRINT_PATH, 'utf8', (err, html) => {
    if (err) {
      return res.status(404).send('Blueprint not deployed yet.');
    }
    res.set('Content-Type', 'text/html; charset=utf-8').send(html);
  });
});

app.get('/api/status-data', async (req, res) => {
  if (!hasStatusAccess(req)) {
    return res.status(401).json({ error: 'Unauthorized' });
  }
  const data = await gatherStatusData();
  res.json(data);
});

// ── Status dashboard data browser ───────────────────────────
// Lets a logged-in dashboard viewer inspect actual rows for any tracked
// table (businesses, profiles, sales, ...) without opening a psql session.
// :table is validated against the same allowlist the dashboard's own counts
// come from, so this can never be used to query an arbitrary table name.
const STATUS_BROWSABLE_TABLES = new Set(
  Object.values(STATUS_TABLE_GROUPS).flat().map(([table]) => table)
);

app.get('/api/status-table/:table', async (req, res) => {
  if (!hasStatusAccess(req)) {
    return res.status(401).json({ error: 'Unauthorized' });
  }
  const { table } = req.params;
  if (!STATUS_BROWSABLE_TABLES.has(table)) {
    return res.status(400).json({ error: 'Unknown or unlisted table' });
  }
  const limit = Math.min(Math.max(parseInt(req.query.limit, 10) || 50, 1), 200);
  const search = (req.query.search || '').trim();

  try {
    const colsResult = await pool.query(
      `SELECT column_name FROM information_schema.columns WHERE table_schema = 'public' AND table_name = $1`,
      [table]
    );
    const columns = colsResult.rows.map((r) => r.column_name);
    const orderCol = ['created_at', 'updated_at'].find((c) => columns.includes(c));

    let query = `SELECT * FROM ${table}`;
    const params = [];
    if (search && columns.includes('name')) {
      params.push(`%${search}%`);
      query += ` WHERE name ILIKE $${params.length}`;
    }
    if (orderCol) query += ` ORDER BY ${orderCol} DESC`;
    params.push(limit);
    query += ` LIMIT $${params.length}`;

    const result = await pool.query(query, params);
    res.json({ table, columns, rows: result.rows, count: result.rows.length });
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

// ── Health check (no auth required) ─────────────────────────
// The Flutter client's ConnectivityHelper.hasInternetConnection() polls this
// endpoint to decide whether the app is online at all - it only cares that
// the HTTP request completes (any status code counts), with a 5s client
// timeout. `pool.query('SELECT 1')` acquires a connection from the same
// pool (max 20) every other route competes for, so under the kind of
// request-storm/slow-query load this backend can see with a large business
// (before the sales-query and polling-interval fixes elsewhere in this
// session), this handler could itself queue behind pool.options
// .connectionTimeoutMillis (5s) waiting for a free connection - long enough
// to blow the client's timeout and make a fully-online app show "You're
// Offline" purely because the DB pool was busy, not because anything was
// actually unreachable. Racing the DB ping against a short timeout keeps
// this endpoint fast (and the response always sent) regardless of pool
// congestion, while still reporting DB status when it's available quickly.
app.get('/api/health', async (req, res) => {
  const dbPing = pool.query('SELECT 1').then(() => 'connected').catch(() => 'disconnected');
  const dbTimeout = new Promise((resolve) => setTimeout(() => resolve('degraded'), 2000));
  const database = await Promise.race([dbPing, dbTimeout]);

  res.json({
    status: 'ok',
    timestamp: new Date().toISOString(),
    uptime: process.uptime(),
    memory: process.memoryUsage(),
    database,
    minio: minioClient ? 'configured' : 'not configured',
  });
});

// ── Auth routes (no auth required) ──────────────────────────
app.post('/api/auth/register', async (req, res) => {
  const email = normalizeEmail(req.body.email);
  const { password, role, data } = req.body;

  if (!email || !password) {
    return res.status(400).json({ error: 'email and password are required' });
  }

  try {
    const existing = await pool.query('SELECT id FROM profiles WHERE lower(email) = $1', [email]);
    if (existing.rows.length > 0) {
      return res.status(400).json({ error: 'User already registered' });
    }

    const hash = await bcrypt.hash(password, 10);
    const result = await pool.query(
      `INSERT INTO profiles (email, password_hash, full_name, phone_number, pin)
       VALUES ($1, $2, $3, $4, $5)
       RETURNING id, email, full_name, phone_number, created_at, updated_at`,
      [
        email,
        hash,
        data?.full_name || data?.name || req.body.full_name || email.split('@')[0],
        data?.phone_number || req.body.phone_number || null,
        data?.pin || req.body.pin || '1234',
      ]
    );

    const user = result.rows[0];
    if ((role || 'owner') === 'owner') {
      res.status(201).json({
        ...user,
        role: 'owner',
        access_token: signAccessToken(user),
      });
    } else {
      res.status(201).json(user);
    }
  } catch (err) {
    res.status(400).json({ error: err.message });
  }
});

app.post('/api/auth/login', async (req, res) => {
  const { email, password } = req.body;
  try {
    const normalizedEmail = normalizeEmail(email);
    let result = await pool.query(
      'SELECT * FROM profiles WHERE lower(email) = $1 AND COALESCE(is_active, true) = true',
      [normalizedEmail]
    );

    if (result.rows.length === 0) {
      result = await pool.query(
        'SELECT * FROM workers WHERE lower(email) = $1 AND is_active = true',
        [normalizedEmail]
      );
      if (result.rows.length === 0) {
        return res.status(401).json({ error: 'Invalid credentials' });
      }
    }

    const user = result.rows[0];

    if (!user.password_hash || !(await bcrypt.compare(password || '', user.password_hash))) {
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
app.use('/api/stores', authMiddleware, storesRoutes(pool));
app.use('/api/sales', authMiddleware, salesRoutes(pool));
app.use('/api/returns', authMiddleware, returnsRoutes(pool));
app.use('/api/inventory-alerts', authMiddleware, inventoryAlertsRoutes(pool));
app.use('/api/reorders', authMiddleware, reordersRoutes(pool));
app.use('/api/customers', authMiddleware, customersRoutes(pool));
app.use('/api/workers', authMiddleware, workersRoutes(pool));
app.use('/api/admin', authMiddleware, adminRoutes(pool));
app.use('/api/expenses', authMiddleware, expensesRoutes(pool));
app.use('/api/apartments', authMiddleware, apartmentsRoutes(pool));
app.use('/api/pharmacy', authMiddleware, pharmacyRoutes(pool));
app.use('/api/drink', authMiddleware, drinkRoutes(pool));
app.use('/api/restaurant', authMiddleware, restaurantRoutes(pool));
app.use('/api/hotel', authMiddleware, hotelRoutes(pool));
app.use('/api/procurement', authMiddleware, procurementRoutes(pool));
app.use('/api/pumps', authMiddleware, pumpsRoutes(pool));
app.use('/api/subscriptions', authMiddleware, subscriptionsRoutes(pool));
app.use('/api/payments', authMiddleware, paymentsRoutes());
app.use('/api/distributors', authMiddleware, distributorsRoutes(pool));
app.use('/api/invoices', authMiddleware, invoicesRoutes(pool));
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
    if (!business_id) {
      return res.status(400).json({ error: 'business_id is required' });
    }
    const ownerCheck = await pool.query(
      'SELECT id FROM business_members WHERE user_id = $1 AND business_id = $2 AND is_owner = true AND is_active = true',
      [req.user.id, business_id]
    );
    if (ownerCheck.rows.length === 0) {
      return res.status(403).json({ error: 'Only the business owner can add workers' });
    }

    const normalizedEmail = normalizeEmail(email);
    const hash = await bcrypt.hash(password, 10);

    const client = await pool.connect();
    try {
      await client.query('BEGIN');

      const existingProfile = await client.query(
        'SELECT id FROM profiles WHERE lower(email) = $1',
        [normalizedEmail]
      );

      const profileResult = existingProfile.rows.length > 0
        ? await client.query(
            `UPDATE profiles
             SET email = $2, password_hash = $3, full_name = $4, updated_at = NOW()
             WHERE id = $1
             RETURNING id, email, full_name`,
            [existingProfile.rows[0].id, normalizedEmail, hash, full_name]
          )
        : await client.query(
            `INSERT INTO profiles (email, password_hash, full_name)
             VALUES ($1, $2, $3)
             RETURNING id, email, full_name`,
            [normalizedEmail, hash, full_name]
          );

      const profile = profileResult.rows[0];
      const workerResult = await client.query(
        `INSERT INTO workers (id, email, password_hash, full_name, role, business_id, permissions)
         VALUES ($1, $2, $3, $4, $5, $6, $7)
         ON CONFLICT (id) DO UPDATE SET
           email = EXCLUDED.email,
           password_hash = EXCLUDED.password_hash,
           full_name = EXCLUDED.full_name,
           role = EXCLUDED.role,
           business_id = EXCLUDED.business_id,
           permissions = EXCLUDED.permissions,
           updated_at = NOW()
         RETURNING id, email, full_name, role`,
        [profile.id, normalizedEmail, hash, full_name, role || 'staff', business_id, JSON.stringify(permissions || {})]
      );

      await client.query(
        `INSERT INTO business_members (user_id, business_id, role, is_owner, is_active, permissions)
         VALUES ($1, $2, $3, false, true, $4)
         ON CONFLICT (user_id, business_id) DO UPDATE SET
           role = EXCLUDED.role,
           is_owner = false,
           is_active = true,
           permissions = EXCLUDED.permissions,
           updated_at = NOW()`,
        [profile.id, business_id, role || 'staff', JSON.stringify(permissions || {})]
      );

      await client.query('COMMIT');
      res.status(201).json(workerResult.rows[0]);
    } catch (err) {
      await client.query('ROLLBACK');
      throw err;
    } finally {
      client.release();
    }
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
