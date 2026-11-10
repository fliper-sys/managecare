const assert = require('node:assert/strict');
const { test } = require('node:test');
const express = require('express');
const pumpRoutes = require('../routes/pumps');
const { errorHandler } = require('../middleware/validation');

const businessId = '11111111-1111-4111-8111-111111111111';
const uploadId = '22222222-2222-4222-8222-222222222222';
const productId = '33333333-3333-4333-8333-333333333333';
const userId = '44444444-4444-4444-8444-444444444444';

test('pump review reports insufficient badge stock as a conflict and rolls back', async () => {
  const state = { rollback: false, released: false, pumpUploadId: null };
  const client = {
    async query(sql, params = []) {
      if (sql === 'BEGIN') return { rows: [] };
      if (sql === 'ROLLBACK') {
        state.rollback = true;
        return { rows: [] };
      }
      if (sql.includes('SELECT * FROM pump_daily_uploads')) {
        return {
          rows: [{
            id: uploadId,
            business_id: businessId,
            status: 'pending_review',
            batch_stock_enforced: true,
            product_id: productId,
            product_name: 'Petrol',
            product_unit: 'L',
            product_price: 500,
            opening_volume: 10,
            closing_volume: 12,
            digital_volume: 2,
            cash_amount: 1000,
            pos_amount: 0,
            total_paid: 1000,
          }],
        };
      }
      if (sql.includes('INSERT INTO sales')) {
        state.pumpUploadId = params[9];
        return { rows: [{ id: '55555555-5555-4555-8555-555555555555' }] };
      }
      if (sql.includes('INSERT INTO sale_items')) {
        const error = new Error('Insufficient petroleum badge stock for product');
        error.code = '23514';
        throw error;
      }
      throw new Error(`Unexpected SQL: ${sql}`);
    },
    release() { state.released = true; },
  };
  const pool = {
    async query(sql) {
      if (sql.includes('FROM business_members')) {
        return { rows: [{ id: 'membership', role: 'owner', is_owner: true }] };
      }
      throw new Error(`Unexpected pool SQL: ${sql}`);
    },
    async connect() { return client; },
  };

  const app = express();
  app.use(express.json());
  app.use((req, _res, next) => {
    req.user = { id: userId, isAnon: false };
    next();
  });
  app.use('/api/pumps', pumpRoutes(pool));
  app.use(errorHandler);

  const server = app.listen(0);
  try {
    const response = await fetch(
      `http://127.0.0.1:${server.address().port}/api/pumps/${businessId}/uploads/${uploadId}/review`,
      { method: 'PATCH', headers: { 'content-type': 'application/json' }, body: JSON.stringify({}) },
    );
    assert.equal(response.status, 409);
    assert.match((await response.json()).error, /Insufficient petroleum badge stock/);
    assert.equal(state.rollback, true);
    assert.equal(state.released, true);
    assert.equal(state.pumpUploadId, uploadId);
  } finally {
    await new Promise((resolve) => server.close(resolve));
  }
});

test('legacy pre-batch pump review remains approvable and links its upload sale', async () => {
  const state = { rollback: false, released: false, pumpUploadId: null };
  const sale = { id: '55555555-5555-4555-8555-555555555555' };
  const approvedUpload = { id: uploadId, status: 'approved', approved_sale_id: sale.id };
  const client = {
    async query(sql, params = []) {
      if (sql === 'BEGIN' || sql === 'COMMIT' || sql === 'ROLLBACK') {
        if (sql === 'ROLLBACK') state.rollback = true;
        return { rows: [] };
      }
      if (sql.includes('SELECT * FROM pump_daily_uploads')) {
        return { rows: [{
          id: uploadId,
          business_id: businessId,
          status: 'pending_review',
          batch_stock_enforced: false,
          product_id: productId,
          product_name: 'Petrol',
          product_unit: 'L',
          product_price: 500,
          opening_volume: 10,
          closing_volume: 12,
          digital_volume: 2,
          cash_amount: 1000,
          pos_amount: 0,
          total_paid: 1000,
        }] };
      }
      if (sql.includes('INSERT INTO sales')) {
        state.pumpUploadId = params[9];
        return { rows: [sale] };
      }
      if (sql.includes('INSERT INTO sale_items')) return { rows: [] };
      if (sql.includes('SELECT badge_allocations FROM sale_items')) return { rows: [{ badge_allocations: [] }] };
      if (sql.includes('UPDATE petroleum_badge_allocations')) return { rows: [] };
      if (sql.includes('INSERT INTO petroleum_cash_entries')) return { rows: [] };
      if (sql.includes('UPDATE pump_daily_uploads SET\n           pump_number')) return { rows: [approvedUpload] };
      if (sql.includes('UPDATE pump_daily_uploads SET badge_allocations')) return { rows: [] };
      if (sql.includes('INSERT INTO pump_upload_adjustments')) return { rows: [] };
      throw new Error(`Unexpected SQL: ${sql}`);
    },
    release() { state.released = true; },
  };
  const pool = {
    async query(sql) {
      if (sql.includes('FROM business_members')) {
        return { rows: [{ id: 'membership', role: 'owner', is_owner: true }] };
      }
      throw new Error(`Unexpected pool SQL: ${sql}`);
    },
    async connect() { return client; },
  };
  const app = express();
  app.use(express.json());
  app.use((req, _res, next) => { req.user = { id: userId, isAnon: false }; next(); });
  app.use('/api/pumps', pumpRoutes(pool));
  app.use(errorHandler);

  const server = app.listen(0);
  try {
    const response = await fetch(
      `http://127.0.0.1:${server.address().port}/api/pumps/${businessId}/uploads/${uploadId}/review`,
      { method: 'PATCH', headers: { 'content-type': 'application/json' }, body: JSON.stringify({}) },
    );
    assert.equal(response.status, 200, await response.text());
    assert.equal(state.rollback, false);
    assert.equal(state.released, true);
    assert.equal(state.pumpUploadId, uploadId);
  } finally {
    await new Promise((resolve) => server.close(resolve));
  }
});
