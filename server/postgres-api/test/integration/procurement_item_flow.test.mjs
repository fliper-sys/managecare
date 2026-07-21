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

test('procurement items life-cycle', async (t) => {
  // create business
  const b = await post('/businesses', { name: 'Procurement Biz', business_type: 'supplier' });
  assert.equal(b.status, 201);
  const business = b.data;

  // create product
  const p = await post('/products', { business_id: business.id, name: 'Proc Product', price: 5 });
  assert.equal(p.status, 201);
  const product = p.data;

  // create procurement with items
  const procResp = await post('/procurements', {
    business_id: business.id,
    supplier_name: 'Supplier Co',
    total_amount: 50,
    items: [{ product_id: product.id, quantity: 10, unit_price: 5, total_amount: 50 }]
  });
  assert.equal(procResp.status, 201);
  const procurement = procResp.data;
  assert.ok(Array.isArray(procurement.items) && procurement.items.length === 1);
  const item = procurement.items[0];

  // update procurement
  const updateProc = await patch(`/procurements/${procurement.id}`, { supplier_name: 'Acme Supply', total_amount: 45, status: 'received' });
  assert.equal(updateProc.status, 200);
  assert.equal(updateProc.data.supplier_name, 'Acme Supply');
  assert.equal(Number(updateProc.data.total_amount), 45);
  assert.equal(updateProc.data.status, 'received');

  // patch procurement item
  const patchResp = await patch(`/procurement-items/${item.id}`, { quantity: 12, unit_price: 4.5 });
  assert.equal(patchResp.status, 200);
  assert.equal(Number(patchResp.data.quantity), 12);
  assert.equal(Number(patchResp.data.unit_price), 4.5);

  // fetch procurements and confirm item updated
  const procAfter = await get(`/procurements?business_id=${business.id}`);
  assert.equal(procAfter.status, 200);
  const updatedProc = procAfter.data.find(p => p.id === procurement.id);
  assert.ok(updatedProc);
  assert.equal(Number(updatedProc.items[0].quantity), 12);

  // delete procurement item
  const delResp = await del(`/procurement-items/${item.id}`);
  assert.equal(delResp.status, 204);

  // fetch procurement and confirm item removed
  const procFinal = await get(`/procurements?business_id=${business.id}`);
  const finalProc = procFinal.data.find(p => p.id === procurement.id);
  assert.ok(finalProc);
  assert.equal(finalProc.items.length, 0);

  // delete procurement
  const deleteProc = await del(`/procurements/${procurement.id}`);
  assert.equal(deleteProc.status, 204);

  const procAfterDelete = await get(`/procurements?business_id=${business.id}`);
  assert.equal(procAfterDelete.status, 200);
  assert.equal(procAfterDelete.data.find(p => p.id === procurement.id), undefined);
});
