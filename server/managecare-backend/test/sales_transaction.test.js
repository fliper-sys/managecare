const assert = require('node:assert/strict');
const { test } = require('node:test');
const express = require('express');
const salesRoutes = require('../routes/sales');

const businessId = '11111111-1111-4111-8111-111111111111';
const saleId = '22222222-2222-4222-8222-222222222222';
const productId = '33333333-3333-4333-8333-333333333333';

function createTestApp({
  inventoryFound = true,
  inventoryCategory = 'Fuel',
  barInvoiceCollected = false,
} = {}) {
  const state = { sale: null, items: [], stockUpdates: 0, commits: 0, rollbacks: 0, saleDeletes: 0 };
  const sale = (id, createdAt, saleType) => ({
    id,
    business_id: businessId,
    final_amount: 1250,
    sale_type: saleType,
    created_at: createdAt,
  });

  const client = {
    async query(sql, params = []) {
      if (sql === 'BEGIN') return { rows: [] };
      if (sql === 'COMMIT') {
        state.commits += 1;
        return { rows: [] };
      }
      if (sql === 'ROLLBACK') {
        state.rollbacks += 1;
        state.sale = null;
        state.items = [];
        return { rows: [] };
      }
      if (sql.includes('AS full_name') && sql.includes('FROM workers w')) {
        return { rows: [] };
      }
      if (sql.includes('SELECT * FROM sales WHERE id = $1 AND business_id = $2 FOR UPDATE')) {
        return { rows: state.sale ? [state.sale] : [] };
      }
      if (sql.includes('ABS(COALESCE(s.final_amount')) {
        return { rows: [] };
      }
      if (sql.includes('SELECT id FROM inventory WHERE id = $1 AND business_id = $2')) {
        return { rows: inventoryFound ? [{ id: productId }] : [] };
      }
      if (sql.includes('SELECT id, category, name, unit FROM inventory')) {
        return {
          rows: inventoryFound
            ? [{
                id: productId,
                category: inventoryCategory,
                name: inventoryCategory === 'Fuel' ? 'Petrol' : 'Bottle',
                unit: inventoryCategory === 'Fuel' ? 'L' : 'bottle',
              }]
            : [],
        };
      }
      if (sql.includes('FROM bar_invoices')) {
        return { rows: barInvoiceCollected ? [{ '?column?': 1 }] : [] };
      }
      if (sql.includes('INSERT INTO sales')) {
        state.sale = sale(params[0] || saleId, params[16], params[15]);
        return { rows: [state.sale] };
      }
      if (sql.includes('SELECT * FROM sale_items')) {
        return { rows: state.items };
      }
      if (sql.includes('AS is_fuel_sale')) {
        return { rows: [{ is_fuel_sale: true }] };
      }
      if (sql.includes('DELETE FROM sales')) {
        state.saleDeletes += 1;
        return { rows: [] };
      }
      if (sql.includes('INSERT INTO sale_items')) {
        if (inventoryCategory === 'Fuel') {
          state.stockUpdates += 1; // Simulates the installed PostgreSQL trigger.
        }
        state.items.push({ sale_id: saleId, product_id: params[1], quantity: params[3] });
        return { rows: [] };
      }
      if (sql.includes('UPDATE inventory')) {
        state.stockUpdates += 1;
        return { rowCount: inventoryFound ? 1 : 0, rows: [] };
      }
      if (sql.includes('UPDATE customers')) return { rowCount: 1, rows: [] };
      throw new Error(`Unexpected SQL in sales test: ${sql}`);
    },
    release() {},
  };
  const pool = {
    async query() {
      return { rows: [{ id: 'member', role: 'owner', is_owner: true }] };
    },
    async connect() { return client; },
  };

  const app = express();
  app.use(express.json());
  app.use((req, _res, next) => {
    req.user = { id: '44444444-4444-4444-8444-444444444444' };
    next();
  });
  app.use('/api/sales', salesRoutes(pool));
  app.use((err, _req, res, _next) => {
    res.status(err.statusCode || 500).json({ error: err.message });
  });
  return { app, state };
}

async function postSale(app, body = {
  id: saleId,
  final_amount: 1250,
  payment_method: 'cash',
  sale_type: 'fuel',
  items: [{
    product_id: productId,
    product_name: 'Petrol',
    quantity: 2.5,
    unit_price: 500,
    total: 1250,
    sale_unit_multiplier: 1,
  }],
}) {
  const server = app.listen(0);
  try {
    const { port } = server.address();
    return await fetch(`http://127.0.0.1:${port}/api/sales/${businessId}`, {
      method: 'POST',
      headers: { 'content-type': 'application/json' },
      body: JSON.stringify(body),
    });
  } finally {
    await new Promise((resolve) => server.close(resolve));
  }
}

test('fuel sale and stock deduction commit together; retry does not deduct twice', async () => {
  const { app, state } = createTestApp();
  const first = await postSale(app);
  assert.equal(first.status, 201, await first.text());
  assert.equal(state.commits, 1);
  assert.equal(state.stockUpdates, 1);

  const retry = await postSale(app);
  assert.equal(retry.status, 200);
  assert.equal((await retry.json()).alreadyExisted, true);
  assert.equal(state.stockUpdates, 1);
  assert.equal(state.commits, 2);
});

test('fuel sale rolls back when its product is not in business inventory', async () => {
  const { app, state } = createTestApp({ inventoryFound: false });
  const response = await postSale(app);
  assert.equal(response.status, 400, await response.text());
  assert.equal(state.rollbacks, 1);
  assert.equal(state.sale, null);
  assert.equal(state.items.length, 0);
});

test('legacy camelCase pump sale with SALE id syncs idempotently', async () => {
  const { app, state } = createTestApp();
  const legacyPayload = {
    id: 'SALE-1700000000000',
    finalAmount: 1250,
    paymentMethod: 'cash',
    saleType: 'fuel',
    createdAt: '2026-10-12T10:00:00.000Z',
    items: [{
      productId,
      productName: 'Petrol',
      quantity: 2.5,
      unitPrice: 500,
      total: 1250,
    }],
  };
  const first = await postSale(app, legacyPayload);
  assert.equal(first.status, 201);
  const firstResult = await first.json();
  assert.match(firstResult.id, /^[0-9a-f-]{36}$/i);
  assert.equal(firstResult.created_at, legacyPayload.createdAt);
  assert.equal(state.stockUpdates, 1);

  const retry = await postSale(app, legacyPayload);
  assert.equal(retry.status, 200);
  assert.equal((await retry.json()).alreadyExisted, true);
  assert.equal(state.stockUpdates, 1);
});

test('petrol alias uses database stock deduction without a second route decrement', async () => {
  const { app, state } = createTestApp();
  const response = await postSale(app, {
    id: saleId,
    finalAmount: 1250,
    paymentMethod: 'cash',
    saleType: 'petrol',
    items: [{
      productId,
      productName: 'Petrol',
      quantity: 2.5,
      unitPrice: 500,
      total: 1250,
    }],
  });
  assert.equal(response.status, 201);
  assert.equal(state.stockUpdates, 1);
});

test('collected bar invoice does not deduct inventory a second time', async () => {
  const { app, state } = createTestApp({
    inventoryCategory: 'Beverage',
    barInvoiceCollected: true,
  });
  const response = await postSale(app, {
    id: saleId,
    final_amount: 1250,
    payment_method: 'mixed',
    sale_type: 'bar',
    items: [{
      product_id: productId,
      product_name: 'Bottle',
      quantity: 2,
      unit_price: 625,
      total: 1250,
    }],
  });

  assert.equal(response.status, 201);
  assert.equal(state.stockUpdates, 0);
  assert.equal(state.items.length, 1);
});

test('direct bar sale still deducts inventory', async () => {
  const { app, state } = createTestApp({ inventoryCategory: 'Beverage' });
  const response = await postSale(app, {
    id: saleId,
    final_amount: 1250,
    payment_method: 'cash',
    sale_type: 'bar',
    items: [{
      product_id: productId,
      product_name: 'Bottle',
      quantity: 2,
      unit_price: 625,
      total: 1250,
    }],
  });

  assert.equal(response.status, 201);
  assert.equal(state.stockUpdates, 1);
});

test('fuel sale deletion is rejected before restoring aggregate inventory', async () => {
  const { app, state } = createTestApp();
  state.sale = { id: saleId, business_id: businessId, sale_type: 'fuel' };
  state.items = [{ sale_id: saleId, product_id: productId, quantity: 2.5 }];
  const server = app.listen(0);
  try {
    const response = await fetch(
      `http://127.0.0.1:${server.address().port}/api/sales/${businessId}/${saleId}`,
      { method: 'DELETE', headers: { 'content-type': 'application/json' }, body: '{}' },
    );
    assert.equal(response.status, 409);
    assert.match((await response.json()).error, /badge allocations/);
    assert.equal(state.stockUpdates, 0);
    assert.equal(state.saleDeletes, 0);
    assert.equal(state.rollbacks, 1);
  } finally {
    await new Promise((resolve) => server.close(resolve));
  }
});
