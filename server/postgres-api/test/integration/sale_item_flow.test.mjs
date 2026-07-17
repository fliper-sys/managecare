import assert from 'node:assert/strict';
import { test } from 'node:test';

const base = `http://127.0.0.1:${process.env.PORT || 4000}`;

async function post(path, body) {
  const res = await fetch(base + path, {
    method: 'POST',
    headers: { 'content-type': 'application/json' },
    body: JSON.stringify(body),
  });
  const text = await res.text();
  let data = null;
  try { data = text ? JSON.parse(text) : null; } catch(e){ data = text; }
  return { status: res.status, data };
}

async function get(path) {
  const res = await fetch(base + path);
  const data = await res.json();
  return { status: res.status, data };
}

async function patch(path, body) {
  const res = await fetch(base + path, {
    method: 'PATCH',
    headers: { 'content-type': 'application/json' },
    body: JSON.stringify(body),
  });
  const data = await res.json();
  return { status: res.status, data };
}

async function del(path) {
  const res = await fetch(base + path, { method: 'DELETE' });
  return { status: res.status };
}

test('sale items life-cycle', async (t) => {
  // create business
  const b = await post('/businesses', { name: 'Test Biz', business_type: 'retail' });
  assert.equal(b.status, 201);
  const business = b.data;

  // create product
  const p = await post('/products', { business_id: business.id, name: 'Test Product', price: 10 });
  assert.equal(p.status, 201);
  const product = p.data;

  // create sale with items
  const saleResp = await post('/sales', {
    business_id: business.id,
    customer_name: 'Alice',
    total_amount: 20,
    items: [{ product_id: product.id, quantity: 2, unit_price: 10, total_amount: 20 }]
  });
  assert.equal(saleResp.status, 201);
  const sale = saleResp.data;
  assert.ok(Array.isArray(sale.items) && sale.items.length === 1);
  const item = sale.items[0];

  // update sale
  const updateSale = await patch(`/sales/${sale.id}`, { customer_name: 'Alice Smith', total_amount: 30, payment_method: 'cash', status: 'pending' });
  assert.equal(updateSale.status, 200);
  assert.equal(updateSale.data.customer_name, 'Alice Smith');
  assert.equal(Number(updateSale.data.total_amount), 30);
  assert.equal(updateSale.data.payment_method, 'cash');
  assert.equal(updateSale.data.status, 'pending');

  // patch sale item
  const patchResp = await patch(`/sale-items/${item.id}`, { quantity: 3, unit_price: 9 });
  assert.equal(patchResp.status, 200);
  assert.equal(Number(patchResp.data.quantity), 3);
  assert.equal(Number(patchResp.data.unit_price), 9);

  // fetch sale and confirm item updated
  const saleAfter = await get(`/sales?business_id=${business.id}`);
  assert.equal(saleAfter.status, 200);
  const updatedSale = saleAfter.data.find(s => s.id === sale.id);
  assert.ok(updatedSale);
  assert.equal(Number(updatedSale.items[0].quantity), 3);

  // delete sale item
  const delResp = await del(`/sale-items/${item.id}`);
  assert.equal(delResp.status, 204);

  // fetch sale and confirm item removed
  const saleFinal = await get(`/sales?business_id=${business.id}`);
  const finalSale = saleFinal.data.find(s => s.id === sale.id);
  assert.ok(finalSale);
  assert.equal(finalSale.items.length, 0);

  // delete sale
  const deleteSale = await del(`/sales/${sale.id}`);
  assert.equal(deleteSale.status, 204);

  const saleAfterDelete = await get(`/sales?business_id=${business.id}`);
  assert.equal(saleAfterDelete.status, 200);
  assert.equal(saleAfterDelete.data.find(s => s.id === sale.id), undefined);
});
