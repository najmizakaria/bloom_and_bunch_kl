'use strict';
const {test, before, after} = require('node:test');
const assert = require('node:assert/strict');
const {createHash} = require('node:crypto');
const {readFileSync} = require('node:fs');
const {resolve} = require('node:path');
const {createPaymentHandlers, MODE, paymentId} = require('../payments');
const enabled = !!process.env.FIRESTORE_EMULATOR_HOST;
let db, api, Timestamp;
const clock = Date.parse('2026-10-16T03:00:00Z');
const req = (uid, id) => ({auth: {uid}, data: {paymentId: id}});
const paidRow = (id, amount = '80.00') => ({billpaymentStatus: '1', billExternalReferenceNo: id,
  billpaymentAmount: amount, billpaymentInvoiceNo: 'TX_' + id});

before(async () => {
  if (!enabled) return;
  if (!process.env.GCLOUD_PROJECT?.startsWith('demo-')) throw Error('Demo emulators only');
  Object.assign(process.env, {TOYYIBPAY_ENABLED: 'true', TOYYIBPAY_SANDBOX_CATEGORY_CODE: 'test-category',
    TOYYIBPAY_RETURN_URL: 'https://example.test/payment-return.html'});
  api = require('../index');
  ({Timestamp} = require('firebase-admin/firestore'));
  db = require('firebase-admin/firestore').getFirestore();
  for (const [uid, role] of [['pay_buyer', 'customer'], ['pay_other', 'customer'], ['pay_rider', 'rider'], ['pay_staff', 'florist']]) {
    await db.doc('users/' + uid).set({uid, role, roles: [role], activeRole: role,
      name: 'Sandbox Test', email: 'test@example.test', phone: '0123456789', createdAt: new Date()});
  }
});
after(async () => { if (db) await db.terminate(); });

async function fixture(id, extra = {}) {
  const orderIds = [id + '_ready', id + '_planned'];
  const common = {customerId: 'pay_buyer', checkoutGroupId: id, paymentId: id, orderMode: MODE,
    paymentStatus: 'pending', riderId: null, latitude: 3.139, longitude: 101.687,
    deliveryAddress: '12 Test Street, Kuala Lumpur', createdAt: new Date(), estimatedDispatchDate: '2026-10-16'};
  await db.doc('bouquets/' + id).set({name: 'Bouquet', readyStock: 8, stockCount: 8});
  await db.doc('flowers/' + id).set({stockQuantity: 10, reservedQuantity: 4});
  await db.doc('orders/' + orderIds[0]).set({...common, totalAmount: 50, fulfillmentType: 'ready_now',
    orderStatus: 'Ready for Delivery', materialState: 'not_required', items: [{bouquetId: id, quantity: 2}]});
  await db.doc('orders/' + orderIds[1]).set({...common, totalAmount: 30, fulfillmentType: 'pre_order',
    orderStatus: 'Awaiting Preparation', materialState: 'reserved', materialRequirements: {[id]: 4}, items: []});
  await db.doc('payments/' + id).set({id, customerId: 'pay_buyer', checkoutId: id, orderIds,
    totalSen: 8000, status: 'awaiting_bill', expiresAt: Timestamp.fromMillis(clock + 1800000),
    nextCheckAt: Timestamp.fromMillis(clock + 2100000), ...extra});
  let calls = 0, rows = [], mayDeactivate = true;
  const gateway = {
    async create() { calls++; return {billCode: 'bill_' + id, paymentUrl: 'https://dev.toyyibpay.com/bill_' + id}; },
    async transactions() { return rows; }, async deactivate() { return mayDeactivate; },
  };
  const handlers = createPaymentHandlers({db, getGateway: () => gateway, getSecret: () => 'test-secret', now: () => clock,
    writeAvailableJob(tx, orderId) { tx.set(db.doc('delivery_jobs/' + orderId), {orderId, orderStatus: 'Ready for Delivery'}); },
  });
  return {handlers, gateway, orderIds, get calls() { return calls; },
    set rows(value) { rows = value; }, set mayDeactivate(value) { mayDeactivate = value; }};
}

test('mixed checkout creates one backend-owned payment and does not publish unpaid delivery jobs', {skip: !enabled}, async () => {
  const policy = require('../store-policy').configured, previous = {...policy};
  try {
    Object.assign(policy, {mode: MODE, serviceArea: {latitude: 3.139, longitude: 101.687, radiusKm: 20, label: 'KL'}, dailyDeliveryCapacity: 100});
    await db.doc('bouquets/pay_checkout').set({name: 'Bouquet', price: 50, isPublished: true,
      readyStock: 5, availableForReadyNow: true, availableForPreOrder: true, recipeStems: {pay_checkout: 2}, leadTimeBusinessDays: 2});
    await db.doc('flowers/pay_checkout').set({name: 'Rose', stockQuantity: 10, reservedQuantity: 0, pricePerStem: 3});
    const address = {recipientName: 'Recipient', recipientPhone: '0123456789', address: '12 Test Street, Kuala Lumpur', note: '', latitude: 3.139, longitude: 101.687};
    await db.doc('users/pay_buyer/addresses/home').set(address);
    const items = ['ready_now', 'pre_order'].map(fulfillmentType => ({bouquetId: 'pay_checkout', quantity: 1, fulfillmentType}));
    const quote = await api.quoteCheckout.run({auth: {uid: 'pay_buyer'}, data: {items, address}});
    const request = {auth: {uid: 'pay_buyer'}, data: {checkoutId: 'pay_checkout', addressId: 'home', address, items, expectedTotal: 100, quoteId: quote.quoteId}};
    const result = await api.placeOrder.run(request);
    assert.deepEqual(await api.placeOrder.run(request), result);
    const id = paymentId('pay_buyer', 'pay_checkout'), payment = (await db.doc('payments/' + id).get()).data();
    assert.equal(payment.totalSen, 10000); assert.equal(payment.orderIds.length, 2);
    for (const orderId of result.orderIds) {
      assert.equal((await db.doc('orders/' + orderId).get()).data().paymentId, id);
      assert.equal((await db.doc('delivery_jobs/' + orderId).get()).exists, false);
    }
    process.env.TOYYIBPAY_ENABLED = 'false';
    await assert.rejects(() => api.quoteCheckout.run({auth: {uid: 'pay_buyer'}, data: {items, address}}), e => e.code === 'failed-precondition');
  } finally { Object.assign(policy, previous); process.env.TOYYIBPAY_ENABLED = 'true'; }
});

test('one bill per checkout survives racing clicks and repeated payment opening', {skip: !enabled}, async () => {
  const f = await fixture('pay_race');
  const results = await Promise.all([f.handlers.create(req('pay_buyer', 'pay_race')), f.handlers.create(req('pay_buyer', 'pay_race'))]);
  assert.equal(f.calls, 1); assert.ok(results.some(r => r.paymentUrl));
  assert.equal((await f.handlers.create(req('pay_buyer', 'pay_race'))).paymentUrl, 'https://dev.toyyibpay.com/bill_pay_race');
  assert.equal(f.calls, 1);
});

test('lost bill response is never blindly retried as another remote bill', {skip: !enabled}, async () => {
  const f = await fixture('pay_unknown');
  f.gateway.create = async () => { throw Error('timeout'); };
  await assert.rejects(() => f.handlers.create(req('pay_buyer', 'pay_unknown')));
  assert.equal((await f.handlers.create(req('pay_buyer', 'pay_unknown'))).status, 'creation_unknown');
});

test('verified settlement pays all deliveries atomically; duplicate callbacks and failures cannot downgrade it', {skip: !enabled}, async () => {
  const id = 'pay_settle', f = await fixture(id);
  await f.handlers.create(req('pay_buyer', id));
  f.rows = [paidRow(id)];
  const body = {status: '1', order_id: id, billcode: 'bill_' + id, refno: 'REF'};
  body.hash = createHash('md5').update('test-secret1' + id + 'REFok').digest('hex');
  await Promise.all([f.handlers.callback(body), f.handlers.callback(body)]);
  for (const order of f.orderIds) assert.equal((await db.doc('orders/' + order).get()).data().paymentStatus, 'paid');
  assert.equal((await db.doc('delivery_jobs/' + f.orderIds[0]).get()).exists, true);
  f.rows = [{...paidRow(id), billpaymentStatus: '3'}];
  assert.equal((await f.handlers.status(req('pay_buyer', id))).status, 'paid');
  assert.equal((await db.doc('payments/' + id).get()).data().nextCheckAt, undefined);
});

test('forged callbacks, wrong bill, wrong amount and wrong reference never fulfill orders', {skip: !enabled}, async () => {
  const id = 'pay_forged', f = await fixture(id);
  await f.handlers.create(req('pay_buyer', id));
  await assert.rejects(() => f.handlers.callback({status: '1', order_id: id, hash: '0'.repeat(32)}));
  for (const row of [paidRow(id, '0.01'), paidRow('wrong'), {...paidRow(id), billpaymentStatus: '2'}]) {
    f.rows = [row]; assert.equal((await f.handlers.status(req('pay_buyer', id))).status, 'pending');
  }
  const body = {status: '1', order_id: id, billcode: 'wrong', refno: 'REF'};
  body.hash = createHash('md5').update('test-secret1' + id + 'REFok').digest('hex');
  await assert.rejects(() => f.handlers.callback(body));
  for (const order of f.orderIds) assert.equal((await db.doc('orders/' + order).get()).data().paymentStatus, 'pending');
});

test('customers cannot access other payments; unauthenticated callables are rejected', {skip: !enabled}, async () => {
  const f = await fixture('pay_owner');
  await assert.rejects(() => f.handlers.status(req('pay_other', 'pay_owner')), e => e.code === 'permission-denied');
  await assert.rejects(() => f.handlers.create(req('pay_other', 'pay_owner')), e => e.code === 'permission-denied');
  await assert.rejects(() => api.createToyyibpayPayment.run({data: {paymentId: 'pay_owner'}}), e => e.code === 'unauthenticated');
});

test('unpaid orders cannot be prepared, dispatched, accepted or manually marked paid', {skip: !enabled}, async () => {
  const f = await fixture('pay_gate');
  for (const [uid, action, orderId] of [['pay_staff', 'prepare', f.orderIds[1]], ['pay_staff', 'ready', f.orderIds[1]],
    ['pay_rider', 'accept', f.orderIds[0]], ['pay_staff', 'cancel', f.orderIds[1]]]) {
    await assert.rejects(() => api.transitionOrder.run({auth: {uid}, data: {action, orderId}}), e => e.code === 'failed-precondition');
  }
  const page = await api.listAvailableDeliveries.run({auth: {uid: 'pay_rider'}, data: {}});
  assert.ok(!page.deliveries.some(j => j.orderId === f.orderIds[0]));
  await assert.rejects(() => api.confirmManualPayment.run({auth: {uid: 'pay_staff'}, data: {orderId: f.orderIds[0]}}));
});

test('expired unpaid checkout restores stock and reservations once; pending banks retain them', {skip: !enabled}, async () => {
  const id = 'pay_expire', f = await fixture(id, {status: 'pending', billCode: 'bill_' + id,
    expiresAt: Timestamp.fromMillis(clock - 1000)});
  f.mayDeactivate = false;
  await f.handlers.expire(await db.doc('payments/' + id).get());
  assert.equal((await db.doc('payments/' + id).get()).data().status, 'pending');
  f.mayDeactivate = true;
  await Promise.all([f.handlers.expire(await db.doc('payments/' + id).get()), f.handlers.expire(await db.doc('payments/' + id).get())]);
  assert.equal((await db.doc('bouquets/' + id).get()).data().readyStock, 10);
  assert.equal((await db.doc('flowers/' + id).get()).data().reservedQuantity, 0);
  for (const order of f.orderIds) assert.equal((await db.doc('orders/' + order).get()).data().orderStatus, 'Cancelled');
  // A late successful payment requires review instead of fulfilling released stock.
  f.rows = [paidRow(id)];
  assert.equal((await f.handlers.status(req('pay_buyer', id))).status, 'needs_review');
  assert.equal((await db.doc('orders/' + f.orderIds[0]).get()).data().paymentStatus, 'expired');
});

test('payment completed before expiry is settled instead of releasing inventory', {skip: !enabled}, async () => {
  const id = 'pay_expire_paid', f = await fixture(id, {status: 'pending', billCode: 'bill_' + id,
    expiresAt: Timestamp.fromMillis(clock - 1000)});
  f.rows = [paidRow(id)];
  await f.handlers.expire(await db.doc('payments/' + id).get());
  assert.equal((await db.doc('payments/' + id).get()).data().status, 'paid');
  assert.equal((await db.doc('bouquets/' + id).get()).data().readyStock, 8);
});

test('payment expiry restores reserved capacity and uncertain bills retain inventory for review', {skip: !enabled}, async () => {
  const id = 'pay_capacity', f = await fixture(id, {capacityReserved: true, expiresAt: Timestamp.fromMillis(clock - 1000)});
  await db.doc('delivery_capacity/2026-10-16').set({acceptedGroups: 5});
  await f.handlers.expire(await db.doc('payments/' + id).get());
  assert.equal((await db.doc('delivery_capacity/2026-10-16').get()).data().acceptedGroups, 3);
  const uncertain = await fixture('pay_hold', {status: 'creation_unknown', expiresAt: Timestamp.fromMillis(clock - 1000)});
  await uncertain.handlers.expire(await db.doc('payments/pay_hold').get());
  assert.equal((await db.doc('payments/pay_hold').get()).data().status, 'needs_review');
  assert.equal((await db.doc('bouquets/pay_hold').get()).data().readyStock, 8);
});

test('account deletion anonymises payment owner and removes checkout identifier', {skip: !enabled}, async () => {
  await db.doc('users/pay_delete').set({role: 'customer'});
  await db.doc('payments/pay_delete').set({customerId: 'pay_delete', checkoutId: 'private_checkout', status: 'paid'});
  await api.deleteAccount.run({auth: {uid: 'pay_delete', token: {auth_time: Math.floor(Date.now() / 1000)}}, data: {}});
  const record = (await db.doc('payments/pay_delete').get()).data();
  assert.equal(record.customerId, 'deleted_customer');
  assert.equal(record.checkoutId, undefined);
});

test('client SDK cannot read or forge backend-only payment records', {skip: !enabled}, async () => {
  const {initializeTestEnvironment, assertFails} = require('@firebase/rules-unit-testing');
  const {doc, getDoc, setDoc} = require('firebase/firestore');
  const env = await initializeTestEnvironment({projectId: process.env.GCLOUD_PROJECT,
    firestore: {rules: readFileSync(resolve(__dirname, '../../firestore.rules'), 'utf8')}});
  try {
    const client = env.authenticatedContext('pay_buyer').firestore();
    await assertFails(getDoc(doc(client, 'payments', 'pay_owner')));
    await assertFails(setDoc(doc(client, 'payments', 'pay_owner'), {status: 'paid'}));
  } finally { await env.cleanup(); }
});
