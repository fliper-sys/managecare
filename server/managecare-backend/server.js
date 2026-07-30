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
const storesRoutes = require('./routes/stores');
const returnsRoutes = require('./routes/returns');
const inventoryAlertsRoutes = require('./routes/inventory_alerts');
const reordersRoutes = require('./routes/reorders');
const salesRoutes = require('./routes/sales');
const customersRoutes = require('./routes/customers');
const workersRoutes = require('./routes/workers');
const expensesRoutes = require('./routes/expenses');
const uploadRoutes = require('./routes/upload');
const pushRoutes = require('./routes/push');

// ── Middleware imports ──────────────────────────────────────
const { authMiddleware, requireAuth } = require('./middleware/auth');
const { errorHandler } = require('./middleware/validation');
const crypto = require('crypto');
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
      const items = value.replace(/^\(|\)$/g, '').split(',').filter(Boolean);
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

    // Standard login
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
    }
    if (result.rows.length === 0) {
      return res.status(401).json({ error: 'Invalid credentials' });
    }
    const user = result.rows[0];
    if (!user.password_hash || !(await bcrypt.compare(password || '', user.password_hash))) {
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
