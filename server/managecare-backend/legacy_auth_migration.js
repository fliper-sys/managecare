const bcrypt = require('bcrypt');

const normalizeEmail = (value) => String(value || '').trim().toLowerCase();

function makeRateLimiter({ windowMs = 15 * 60_000, maxAttempts = 8, now = Date.now } = {}) {
  const attempts = new Map();
  return (key) => {
    const time = now();
    const recent = (attempts.get(key) || []).filter((at) => time - at < windowMs);
    if (recent.length >= maxAttempts) {
      attempts.set(key, recent);
      return false;
    }
    recent.push(time);
    attempts.set(key, recent);
    if (attempts.size > 5000) {
      for (const [candidate, times] of attempts) {
        if (times.every((at) => time - at >= windowMs)) attempts.delete(candidate);
      }
    }
    return true;
  };
}

class LegacyAuthMigration {
  constructor({ pool, runWithUser, supabaseUrl, serviceRoleKey, fetchImpl = fetch }) {
    this.pool = pool;
    this.runWithUser = runWithUser;
    this.supabaseUrl = String(supabaseUrl || '').replace(/\/$/, '');
    this.serviceRoleKey = serviceRoleKey || '';
    this.fetch = fetchImpl;
  }

  async request(path, { method = 'GET', body, headers = {} } = {}) {
    const response = await this.fetch(`${this.supabaseUrl}${path}`, {
      method,
      headers: {
        apikey: this.serviceRoleKey,
        Authorization: `Bearer ${this.serviceRoleKey}`,
        ...headers,
        ...(body ? { 'Content-Type': 'application/json' } : {}),
        ...(method === 'POST' && path.startsWith('/rest/v1/')
          ? { Prefer: 'resolution=merge-duplicates,return=minimal' } : {}),
      },
      ...(body ? { body: JSON.stringify(body) } : {}),
      signal: AbortSignal.timeout(10_000),
    });
    const range = response.headers.get('content-range');
    const payload = await response.text();
    let data;
    try { data = payload ? JSON.parse(payload) : null; } catch (_) { data = null; }
    if (!response.ok) {
      const error = new Error(`Auth migration provider returned ${response.status}`);
      error.status = response.status;
      throw error;
    }
    if (Array.isArray(data) && range && !range.endsWith('/*')) {
      const total = Number(range.split('/').at(-1));
      if (Number.isFinite(total) && total > data.length) {
        const error = new Error('Auth data query was truncated; refusing an incomplete membership check');
        error.status = 502;
        throw error;
      }
    }
    return data;
  }

  async findAuthUser(email) {
    const query = new URLSearchParams({ select: 'id,email,full_name', email: `ilike.${email}`, limit: '100' });
    const rows = await this.request(`/rest/v1/profiles?${query}`);
    if (!Array.isArray(rows)) throw new Error('Auth profile lookup returned an invalid response');
    const exact = rows.filter((row) => normalizeEmail(row.email) === email);
    if (exact.length > 1) throw new Error('Auth email is ambiguous');
    return exact[0] || null;
  }

  async ensureAuthUser(email, password, fullName, legacyId) {
    let user = await this.findAuthUser(email);
    if (user) {
      const links = await this.pool.query(
        `SELECT legacy_user_id FROM legacy_auth_identity_links
         WHERE auth_user_id = $1 OR lower(email) = $2`, [user.id, email]);
      if (links.rows.some((row) => row.legacy_user_id !== legacyId)) {
        throw new Error('Auth account is already linked to another legacy identity');
      }
      if (!links.rows.some((row) => row.legacy_user_id === legacyId)) {
        await this.request(`/auth/v1/admin/users/${encodeURIComponent(user.id)}`, {
          method: 'PUT', body: { password },
        });
      }
    } else {
      user = await this.request('/auth/v1/admin/users', {
        method: 'POST',
        body: {
          email, password, email_confirm: true,
          user_metadata: { full_name: fullName || email.split('@')[0] },
        },
      });
    }
    if (!user?.id) throw new Error('Auth provider did not return a user id');
    return user.id;
  }

  async syncVerifiedMemberships(authId, legacyId, email) {
    const { rows } = await this.runWithUser(legacyId, () => this.pool.query(
      'SELECT link_legacy_auth_identity($1::uuid,$2::uuid,$3::text) AS result',
      [authId, legacyId, email]));
    return rows[0]?.result;
  }

  async reconcileVerifiedPassword({ email, password, fullName, legacyId }) {
    const normalizedEmail = normalizeEmail(email);
    if (!this.supabaseUrl || !this.serviceRoleKey) {
      const error = new Error('Auth migration is not configured'); error.status = 503; throw error;
    }
    const authId = await this.ensureAuthUser(normalizedEmail, password, fullName, legacyId);
    await this.request(`/auth/v1/admin/users/${encodeURIComponent(authId)}`, {
      method: 'PUT', body: { password, email_confirm: true },
    });
    const memberships = await this.syncVerifiedMemberships(authId, legacyId, normalizedEmail);
    return { authId, memberships };
  }

  // Profile-backed workers already have their business membership. Recovery
  // may use a different Auth UUID only when an existing verified identity link
  // maps that UUID to this exact legacy profile; it never creates or moves links.
  async reconcileProfileWorkerPassword({ email, password, legacyId }) {
    const normalizedEmail = normalizeEmail(email);
    if (!this.supabaseUrl || !this.serviceRoleKey) {
      const error = new Error('Auth migration is not configured'); error.status = 503; throw error;
    }
    const user = await this.findAuthUser(normalizedEmail);
    if (!user) {
      const error = new Error('Worker profile does not match its Auth identity'); error.status = 409; throw error;
    }
    const links = await this.pool.query(
      `SELECT legacy_user_id, auth_user_id FROM legacy_auth_identity_links
       WHERE legacy_user_id = $1 OR auth_user_id = $2 OR lower(email) = $3`,
      [legacyId, user.id, normalizedEmail]);
    const matchingVerifiedLink = links.rows.some((row) =>
      row.legacy_user_id === legacyId && row.auth_user_id === user.id);
    if (links.rows.some((row) => row.legacy_user_id !== legacyId || row.auth_user_id !== user.id)) {
      const error = new Error('Worker profile has a conflicting identity link'); error.status = 409; throw error;
    }
    if (user.id !== legacyId && !matchingVerifiedLink) {
      const error = new Error('Worker profile does not match its Auth identity'); error.status = 409; throw error;
    }
    await this.request(`/auth/v1/admin/users/${encodeURIComponent(user.id)}`, {
      method: 'PUT', body: { password, email_confirm: true },
    });
    return { authId: user.id };
  }

  async reconcileConfirmedAccounts() {
    const { rows } = await this.pool.query(
      'SELECT * FROM active_legacy_auth_candidates() ORDER BY email, legacy_user_id');
    const byEmail = new Map();
    for (const row of rows) {
      const email = normalizeEmail(row.email);
      if (!byEmail.has(email)) byEmail.set(email, []);
      byEmail.get(email).push(row);
    }
    const summary = { linked: 0, noAuthAccount: 0, unconfirmed: 0, ambiguous: 0, conflicts: 0 };
    const authUsers = await this.listAuthUsers();
    const authByEmail = new Map();
    for (const user of authUsers) {
      const email = normalizeEmail(user.email);
      if (!authByEmail.has(email)) authByEmail.set(email, []);
      authByEmail.get(email).push(user);
    }

    for (const [email, candidates] of byEmail) {
      if (candidates.length !== 1) {
        summary.ambiguous += 1;
        continue;
      }
      const candidate = candidates[0];
      try {
        const matches = authByEmail.get(email) || [];
        if (matches.length === 0) {
          summary.noAuthAccount += 1;
          continue;
        }
        if (matches.length !== 1) {
          summary.ambiguous += 1;
          continue;
        }
        const authUser = matches[0];
        if (normalizeEmail(authUser.email) !== email || !authUser.email_confirmed_at) {
          summary.unconfirmed += 1;
          continue;
        }
        await this.syncVerifiedMemberships(authUser.id, candidate.legacy_user_id, email);
        summary.linked += 1;
      } catch (_) {
        summary.conflicts += 1;
      }
    }
    return summary;
  }

  async listAuthUsers() {
    const all = [];
    for (let page = 1; page <= 100; page += 1) {
      const result = await this.request(
        `/auth/v1/admin/users?page=${page}&per_page=100`);
      const users = result?.users;
      if (!Array.isArray(users)) throw new Error('Auth user listing returned invalid data');
      all.push(...users);
      if (users.length < 100) return all;
    }
    throw new Error('Auth user listing exceeded the safety page limit');
  }

  async migrate({ email, password }) {
    const normalizedEmail = normalizeEmail(email);
    if (!this.supabaseUrl || !this.serviceRoleKey) {
      const error = new Error('Auth migration is not configured'); error.status = 503; throw error;
    }
    if (!normalizedEmail || typeof password !== 'string' || password.length === 0) {
      const error = new Error('Invalid credentials'); error.status = 401; throw error;
    }

    const [profiles, workers] = await Promise.all([
      this.pool.query(
        `SELECT id, email, full_name, password_hash FROM profiles
         WHERE lower(trim(email))=$1 AND COALESCE(is_active,true)=true
           AND COALESCE(is_deleted,false)=false AND password_hash IS NOT NULL`, [normalizedEmail]),
      this.pool.query(
        `SELECT id, email, full_name, password_hash FROM auth_worker_login_candidates($1)
         WHERE password_hash IS NOT NULL`, [normalizedEmail]),
    ]);
    const candidates = [...profiles.rows, ...workers.rows];
    const matches = [];
    for (const candidate of candidates) {
      if (await bcrypt.compare(password, candidate.password_hash)) matches.push(candidate);
    }
    const unique = [...new Map(matches.map((row) => [row.id, row])).values()];
    if (unique.length !== 1) {
      const error = new Error('Legacy credentials could not be uniquely verified'); error.status = 401; throw error;
    }

    const legacy = unique[0];
    const linked = await this.pool.query(
      `SELECT auth_user_id FROM legacy_auth_identity_links
       WHERE legacy_user_id = $1 OR lower(email) = $2`, [legacy.id, normalizedEmail]);
    if (linked.rows.some((row) => row.auth_user_id && row.auth_user_id !== linked.rows[0].auth_user_id)) {
      throw new Error('Legacy identity has conflicting account links');
    }
    const authId = await this.ensureAuthUser(normalizedEmail, password, legacy.full_name, legacy.id);
    if (linked.rows.length && linked.rows[0].auth_user_id !== authId) {
      throw new Error('Legacy identity is already linked to another Auth account');
    }
    const result = await this.syncVerifiedMemberships(authId, legacy.id, normalizedEmail);
    return { user_id: authId, linked: true, memberships: result || {} };
  }
}

module.exports = { LegacyAuthMigration, makeRateLimiter, normalizeEmail };
