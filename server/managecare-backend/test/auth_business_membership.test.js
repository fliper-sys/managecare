const assert = require('node:assert/strict');
const { test } = require('node:test');
const express = require('express');
const { requireBusinessMembership, requireBusinessReadAccess } = require('../middleware/auth');
const { getRequestUserId } = require('../middleware/db_request_context');

const businessId = '11111111-1111-4111-8111-111111111111';
const userId = '22222222-2222-4222-8222-222222222222';

async function membershipFor(pool) {
  const app = express();
  app.use((req, _res, next) => {
    req.user = { id: userId, isAnon: false };
    next();
  });
  app.get('/:businessId', requireBusinessMembership(pool), (req, res) => {
    res.json(req.businessMembership);
  });

  const server = app.listen(0);
  try {
    const response = await fetch(`http://127.0.0.1:${server.address().port}/${businessId}`);
    return { status: response.status, body: await response.json() };
  } finally {
    await new Promise((resolve) => server.close(resolve));
  }
}

async function readAccessFor(pool, method) {
  const app = express();
  app.use((req, _res, next) => {
    req.user = { id: userId, email: 'admin@example.com', isAnon: false };
    next();
  });
  app.all('/:businessId', requireBusinessReadAccess(pool), (req, res) => {
    res.json({ membership: req.businessMembership, requestUserId: getRequestUserId() });
  });

  const server = app.listen(0);
  try {
    const response = await fetch(`http://127.0.0.1:${server.address().port}/${businessId}`, { method });
    return { status: response.status, body: await response.json() };
  } finally {
    await new Promise((resolve) => server.close(resolve));
  }
}

test('canonical business owner overrides a stale lower-privilege membership role', async () => {
  const pool = {
    async query(sql) {
      if (sql.includes('FROM business_members')) {
        return { rows: [{ id: 'membership-id', role: 'manager', is_owner: false }] };
      }
      if (sql.includes('FROM businesses')) return { rows: [{ id: businessId }] };
      throw new Error(`Unexpected SQL: ${sql}`);
    },
  };

  const result = await membershipFor(pool);
  assert.equal(result.status, 200);
  assert.equal(result.body.role, 'owner');
  assert.equal(result.body.is_owner, true);
});

test('a non-owner manager retains their existing membership role', async () => {
  const pool = {
    async query(sql) {
      if (sql.includes('FROM business_members')) {
        return { rows: [{ id: 'membership-id', role: 'manager', is_owner: false }] };
      }
      if (sql.includes('FROM businesses')) return { rows: [] };
      throw new Error(`Unexpected SQL: ${sql}`);
    },
  };

  const result = await membershipFor(pool);
  assert.equal(result.status, 200);
  assert.equal(result.body.role, 'manager');
  assert.equal(result.body.is_owner, false);
});

test('platform admin can make legacy business-scoped GETs in the owner RLS context', async () => {
  const previous = process.env.PLATFORM_ADMIN_EMAILS;
  process.env.PLATFORM_ADMIN_EMAILS = 'admin@example.com';
  try {
    const pool = {
      async query() { return { rows: [{ owner_id: '33333333-3333-4333-8333-333333333333' }] }; },
    };
    const result = await readAccessFor(pool, 'GET');
    assert.equal(result.status, 200);
    assert.equal(result.body.requestUserId, '33333333-3333-4333-8333-333333333333');
    assert.equal(result.body.membership.role, 'platform_admin');
    assert.equal(result.body.membership.is_owner, false);
  } finally {
    if (previous === undefined) delete process.env.PLATFORM_ADMIN_EMAILS;
    else process.env.PLATFORM_ADMIN_EMAILS = previous;
  }
});

test('platform admin does not bypass membership checks for writes', async () => {
  const previous = process.env.PLATFORM_ADMIN_EMAILS;
  process.env.PLATFORM_ADMIN_EMAILS = 'admin@example.com';
  try {
    const pool = {
      async query(sql) {
        if (sql.includes('FROM business_members')) return { rows: [] };
        if (sql.includes('FROM businesses')) return { rows: [] };
        if (sql.includes('FROM workers')) return { rows: [] };
        throw new Error(`Unexpected SQL: ${sql}`);
      },
    };
    const result = await readAccessFor(pool, 'POST');
    assert.equal(result.status, 403);
    assert.equal(result.body.error, 'You are not a member of this business');
  } finally {
    if (previous === undefined) delete process.env.PLATFORM_ADMIN_EMAILS;
    else process.env.PLATFORM_ADMIN_EMAILS = previous;
  }
});
