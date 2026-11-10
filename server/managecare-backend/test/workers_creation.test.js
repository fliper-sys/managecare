const assert = require('node:assert/strict');
const { test } = require('node:test');
const express = require('express');
const workerRoutes = require('../routes/workers');

const businessId = '11111111-1111-4111-8111-111111111111';
const ownerId = '22222222-2222-4222-8222-222222222222';
const workerId = '33333333-3333-4333-8333-333333333333';

function createApp() {
  const state = { worker: null, inserts: 0 };
  const pool = {
    async query(sql, params = []) {
      if (sql.includes('FROM business_members')) {
        return { rows: [{ id: 'membership-id', role: 'owner', is_owner: true }] };
      }
      if (sql.includes('SELECT business_type, subscription_tier FROM businesses')) {
        return { rows: [{ business_type: 'bakery', subscription_tier: 'tier1' }] };
      }
      if (sql.includes('SELECT business_type, subscription_tier, subscription_plan FROM businesses')) {
        return { rows: [{ business_type: 'bakery', subscription_tier: 'tier1' }] };
      }
      if (sql.includes('INSERT INTO workers')) {
        state.inserts += 1;
        state.worker = {
          id: workerId,
          email: params[0],
          full_name: params[1],
          phone: params[2],
          role: params[3],
          business_id: params[4],
          store_id: params[5],
          permissions: JSON.parse(params[6]),
          pin: params[7],
          password_hash: params[8],
        };
        return { rows: [{ ...state.worker }] };
      }
      if (sql.includes('SELECT COUNT(*) FROM workers')) {
        return { rows: [{ count: state.worker ? '1' : '0' }] };
      }
      if (sql.includes('SELECT * FROM workers WHERE business_id = $1')) {
        return { rows: state.worker ? [{ ...state.worker }] : [] };
      }
      throw new Error(`Unexpected SQL in workers test: ${sql}`);
    },
  };

  const app = express();
  app.use(express.json());
  app.use((req, _res, next) => {
    req.user = { id: ownerId, isAnon: false };
    next();
  });
  app.use('/api/workers', workerRoutes(pool));
  return { app, state };
}

async function request(app, path, { method = 'GET', body } = {}) {
  const server = app.listen(0);
  try {
    return await fetch(`http://127.0.0.1:${server.address().port}${path}`, {
      method,
      headers: { 'content-type': 'application/json' },
      ...(body === undefined ? {} : { body: JSON.stringify(body) }),
    });
  } finally {
    await new Promise((resolve) => server.close(resolve));
  }
}

test('bakery worker can be created without login and appears in business list', async () => {
  const { app, state } = createApp();
  const created = await request(app, `/api/workers/${businessId}`, {
    method: 'POST',
    body: {
      full_name: 'Baker One',
      role: 'baker',
      email: '',
      is_login_enabled: false,
      store_id: null,
      pin: '1234',
      permissions: { production: true },
    },
  });

  const worker = await created.json();
  assert.equal(created.status, 201);
  assert.equal(worker.is_login_enabled, false);
  assert.equal(worker.email, null);
  assert.equal(worker.password_hash, undefined);
  assert.equal(state.worker.password_hash, null);
  assert.equal(state.inserts, 1);

  const listed = await request(app, `/api/workers/${businessId}`);
  const result = await listed.json();
  assert.equal(listed.status, 200);
  assert.equal(result.data.length, 1);
  assert.equal(result.data[0].id, workerId);
  assert.equal(result.data[0].is_login_enabled, false);
  assert.equal(result.data[0].password_hash, undefined);
});

test('worker creation still requires credentials unless login is explicitly disabled', async () => {
  const { app, state } = createApp();
  const response = await request(app, `/api/workers/${businessId}`, {
    method: 'POST',
    body: { full_name: 'Baker One', role: 'baker' },
  });

  assert.equal(response.status, 400);
  assert.match((await response.json()).error, /email and password/i);
  assert.equal(state.inserts, 0);
});
