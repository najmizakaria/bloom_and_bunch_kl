'use strict';
const { test, before, after } = require('node:test');
const assert = require('node:assert/strict');
const enabled = !!process.env.FIRESTORE_EMULATOR_HOST && !!process.env.FIREBASE_AUTH_EMULATOR_HOST;
let db, api;
const req = (uid, data = {}) => ({ auth: { uid, token: { auth_time: Math.floor(Date.now() / 1000) } }, data });
const act = (uid, orderId, action, extra = {}) => api.transitionOrder.run(req(uid, { orderId, action, ...extra }));
async function rider(uid, extra = {}) {
  await db.doc('users/' + uid).set({ role: 'rider', name: uid, ...extra });
  await db.doc('rider_applications/' + uid).set({ status: 'approved', name: uid, phone: '0123456789' });
}
async function order(id, extra = {}) {
  await db.doc('orders/' + id).set({ customerId: 'handoff_buyer', riderId: null,
    orderStatus: 'Ready for Delivery', orderMode: 'demo', paymentStatus: 'not_required',
    deliveryAddress: '12 Test Street, Kuala Lumpur', latitude: 3.139, longitude: 101.687,
    createdAt: new Date(), ...extra });
  return id;
}
const assignment = (riderId, requestId, expectedRiderId = null) => ({ riderId, requestId, expectedRiderId, expectedAssignmentRevision: expectedRiderId ? 1 : 0, reason: expectedRiderId ? 'Rider unavailable at store' : '' });
before(async () => {
  if (!enabled) return;
  if (!process.env.GCLOUD_PROJECT?.startsWith('demo-')) throw Error('Demo emulators required.');
  api = require('../index'); db = require('firebase-admin/firestore').getFirestore();
  for (const [uid, role] of [['handoff_florist', 'florist'], ['handoff_admin', 'admin'], ['handoff_buyer', 'customer']])
    await db.doc('users/' + uid).set({ role });
});
after(async () => { if (db) await db.terminate(); });

test('ready-made checkout waits for florist packing and does not deduct stock again', { skip: !enabled }, async () => {
  const address = { recipientName: 'Recipient', recipientPhone: '0123456789', address: '12 Test Street, Kuala Lumpur', latitude: 3.139, longitude: 101.687 };
  await db.doc('users/handoff_buyer/addresses/home').set(address);
  await db.doc('bouquets/handoff_ready').set({ name: 'Ready bouquet', price: 50, readyStock: 2, availableForReadyNow: true, isPublished: true });
  const data = { checkoutId: 'handoff_checkout', addressId: 'home', address,
    items: [{ bouquetId: 'handoff_ready', fulfillmentType: 'ready_now', quantity: 1 }], expectedTotal: 50 };
  const result = await api.placeOrder.run(req('handoff_buyer', data)), id = result.orderIds[0];
  assert.equal((await db.doc('orders/' + id).get()).data().orderStatus, 'Awaiting Preparation');
  assert.equal((await db.doc('delivery_jobs/' + id).get()).exists, false);
  await rider('handoff_pack_rider');
  await assert.rejects(() => act('handoff_pack_rider', id, 'accept'), /prepared/);
  await act('handoff_florist', id, 'prepare');
  await Promise.all([act('handoff_florist', id, 'ready'), act('handoff_florist', id, 'ready')]);
  assert.equal((await db.doc('bouquets/handoff_ready').get()).data().readyStock, 1);
  assert.equal((await db.doc('orders/' + id).get()).data().materialState, 'not_required');
  assert.equal((await db.doc('delivery_jobs/' + id).get()).exists, true);
  assert.equal((await db.collection('orders/' + id + '/events').get()).size, 3);
  assert.ok((await db.doc('delivery_queue/current').get()).data().revision > 0);
});

test('acceptance assigns only; collection is owner-only, idempotent and required before delivery', { skip: !enabled }, async () => {
  await rider('handoff_collect'); await rider('handoff_stranger');
  const id = await order('handoff_collect_order');
  await act('handoff_collect', id, 'accept');
  assert.equal((await db.doc('orders/' + id).get()).data().orderStatus, 'Rider assigned');
  await assert.rejects(() => act('handoff_collect', id, 'deliver'), /not out for delivery/);
  await assert.rejects(() => act('handoff_stranger', id, 'collect'), e => e.code === 'permission-denied');
  await assert.rejects(() => api.deleteAccount.run(req('handoff_collect')), /active orders or deliveries/);
  await db.doc('orders/' + id).update({ support: { status: 'open' } });
  await assert.rejects(() => act('handoff_collect', id, 'collect'), /open order issue/);
  await db.doc('orders/' + id).update({ support: { status: 'resolved' } });
  await Promise.all([act('handoff_collect', id, 'collect'), act('handoff_collect', id, 'collect')]);
  const collected = (await db.doc('orders/' + id).get()).data();
  assert.equal(collected.orderStatus, 'Out for Delivery'); assert.ok(collected.collectedAt);
  assert.equal((await db.collection('orders/' + id + '/events').get()).size, 2);
  await act('handoff_collect', id, 'deliver'); await act('handoff_buyer', id, 'confirmReceived');
  assert.equal((await db.doc('users/handoff_collect').get()).data().activeDeliveryId, undefined);
});

test('staff assignment and rider acceptance racing produce exactly one assignment', { skip: !enabled }, async () => {
  await rider('handoff_staff_target'); await rider('handoff_accept_target');
  const id = await order('handoff_assignment_race');
  const results = await Promise.allSettled([
    act('handoff_florist', id, 'assign', assignment('handoff_staff_target', 'race_assign')),
    act('handoff_accept_target', id, 'accept'),
  ]);
  assert.equal(results.filter(r => r.status === 'fulfilled').length, 1);
  assert.equal((await db.collection('orders/' + id + '/assignment_events').get()).size, 1);
  const current = (await db.doc('orders/' + id).get()).data();
  assert.equal(current.orderStatus, 'Rider assigned');
  assert.equal((await db.doc('users/' + current.riderId).get()).data().activeDeliveryId, id);
});

test('reassignment releases the old lock and retries never overwrite a later assignment', { skip: !enabled }, async () => {
  await rider('handoff_old'); await rider('handoff_new');
  const id = await order('handoff_reassign'), first = assignment('handoff_old', 'initial');
  await act('handoff_florist', id, 'assign', first); await act('handoff_florist', id, 'assign', first);
  const replacement = assignment('handoff_new', 'replace', 'handoff_old');
  await assert.rejects(() => act('handoff_buyer', id, 'assign', replacement), e => e.code === 'permission-denied');
  await assert.rejects(() => act('handoff_admin', id, 'assign', { ...replacement, reason: '' }), /assignment reason/);
  await act('handoff_admin', id, 'assign', replacement); await act('handoff_admin', id, 'assign', replacement);
  assert.equal((await db.doc('users/handoff_old').get()).data().activeDeliveryId, undefined);
  assert.equal((await db.doc('users/handoff_new').get()).data().activeDeliveryId, id);
  await assert.rejects(() => act('handoff_florist', id, 'assign', first), /assignment changed/);
  await assert.rejects(() => act('handoff_old', id, 'collect'), e => e.code === 'permission-denied');
  const release = { expectedRiderId: 'handoff_new', expectedAssignmentRevision: 2, requestId: 'release', reason: 'Rider cannot collect' };
  await act('handoff_florist', id, 'unassign', release); await act('handoff_florist', id, 'unassign', release);
  assert.equal((await db.doc('users/handoff_new').get()).data().activeDeliveryId, undefined);
  assert.equal((await db.doc('delivery_jobs/' + id).get()).exists, true);
  assert.equal((await db.collection('orders/' + id + '/assignment_events').get()).size, 3);
  await assert.rejects(() => act('handoff_florist', id, 'assign', first), /assignment changed/);
});

test('collection racing with reassignment has a single winner and a consistent rider lock', { skip: !enabled }, async () => {
  await rider('handoff_race_old'); await rider('handoff_race_new');
  const id = await order('handoff_collect_race');
  await act('handoff_florist', id, 'assign', assignment('handoff_race_old', 'before_collect'));
  const result = await Promise.allSettled([
    act('handoff_race_old', id, 'collect'),
    act('handoff_florist', id, 'assign', assignment('handoff_race_new', 'race_collect', 'handoff_race_old')),
  ]);
  assert.equal(result.filter(r => r.status === 'fulfilled').length, 1);
  const current = (await db.doc('orders/' + id).get()).data();
  assert.equal((await db.doc('users/' + current.riderId).get()).data().activeDeliveryId, id);
  if (current.orderStatus === 'Out for Delivery')
    await assert.rejects(() => act('handoff_florist', id, 'unassign', { expectedRiderId: current.riderId, requestId: 'too_late', reason: 'Late release' }), /assignment changed/);
});

test('assignment enforces scheduling, payment, issues, contact approval and rider capacity', { skip: !enabled }, async () => {
  await rider('handoff_checks');
  const id = await order('handoff_checked');
  for (const patch of [{ scheduledDeliveryDate: '2099-01-01' }, { orderMode: 'toyyibpay_sandbox', paymentStatus: 'pending' }, { support: { status: 'open' } }, { latitude: 999 }]) {
    await order(id, patch);
    await assert.rejects(() => act('handoff_florist', id, 'assign', assignment('handoff_checks', 'blocked')), e => e.code === 'failed-precondition');
  }
  await order(id); await db.doc('rider_applications/handoff_checks').update({ phone: 'bad' });
  await assert.rejects(() => act('handoff_florist', id, 'assign', assignment('handoff_checks', 'contact')), /approved/);
  await rider('handoff_checks');
  const other = await order('handoff_other_order');
  const result = await Promise.allSettled([id, other].map((key) => act('handoff_florist', key, 'assign', assignment('handoff_checks', key))));
  assert.equal(result.filter(r => r.status === 'fulfilled').length, 1);
});

test('staff rider directory excludes busy, suspended, deleting, unapproved and buying riders', { skip: !enabled }, async () => {
  for (const uid of ['handoff_z_free', 'handoff_z_busy', 'handoff_z_suspended', 'handoff_z_deleting', 'handoff_z_unapproved', 'handoff_z_buyer']) await rider(uid);
  await db.doc('users/handoff_z_suspended').update({ accountSuspended: true });
  await db.doc('users/handoff_z_deleting').update({ deletionPending: true });
  await db.doc('rider_applications/handoff_z_unapproved').update({ status: 'pending' });
  await order('handoff_z_active', { riderId: 'handoff_z_busy', orderStatus: 'Rider assigned' });
  const id = await order('handoff_z_directory', { customerId: 'handoff_z_buyer' });
  await assert.rejects(() => api.listAssignableRiders.run(req('handoff_buyer', { orderId: id })), e => e.code === 'permission-denied');
  const page = await api.listAssignableRiders.run(req('handoff_florist', { orderId: id, cursor: 'handoff_z_' }));
  assert.deepEqual(page.riders.filter(r => r.id.startsWith('handoff_z_')).map(r => r.id), ['handoff_z_free']);
  assert.deepEqual(Object.keys(page.riders.find(r => r.id === 'handoff_z_free')).sort(), ['id', 'name']);
});

test('reporting an issue removes a ready job and resolution restores it without marking delivery complete', { skip: !enabled }, async () => {
  const id = await order('handoff_issue');
  await act('handoff_florist', id, 'ready');
  await api.reportOrderIssue.run(req('handoff_buyer', { orderId: id, reason: 'wrong_address', comment: 'Check entrance' }));
  assert.equal((await db.doc('delivery_jobs/' + id).get()).exists, false);
  await api.resolveOrderIssue.run(req('handoff_florist', { orderId: id, response: 'Confirmed entrance' }));
  assert.equal((await db.doc('delivery_jobs/' + id).get()).exists, true);
  assert.equal((await db.doc('orders/' + id).get()).data().orderStatus, 'Ready for Delivery');
});

test('reassignment notifies both riders once without sending recipient information', { skip: !enabled }, async () => {
  const messaging = require('firebase-admin/messaging').getMessaging(), original = messaging.sendEachForMulticast;
  const messages = [];
  for (const uid of ['handoff_notice_old', 'handoff_notice_new']) {
    await rider(uid, { notificationsEnabled: true });
    await db.doc('notification_devices/' + uid).set({ uid, token: uid + '_token' });
  }
  messaging.sendEachForMulticast = async message => { messages.push(message); return { responses: message.tokens.map(() => ({ success: true })) }; };
  const event = { id: 'handoff_notice_event', params: { orderId: 'handoff_notice_order' }, data: {
    before: { data: () => ({ orderStatus: 'Rider assigned', riderId: 'handoff_notice_old' }) },
    after: { data: () => ({ orderStatus: 'Rider assigned', riderId: 'handoff_notice_new', customerId: 'handoff_buyer', recipientPhone: 'PRIVATE' }) },
  } };
  try {
    await api.notifyOrderStatus.run(event); await api.notifyOrderStatus.run(event);
    assert.equal(messages.length, 2);
    assert.deepEqual(messages.map(m => m.data.riderId).sort(), ['handoff_notice_new', 'handoff_notice_old']);
    assert.ok(messages.every(m => !JSON.stringify(m).includes('PRIVATE')));
    await db.doc('users/handoff_notice_old').update({ accountSuspended: true });
    await api.notifyOrderStatus.run({ ...event, id: 'handoff_notice_suspended' });
    assert.equal(messages.length, 3);
    assert.equal(messages[2].data.riderId, 'handoff_notice_new');
  } finally { messaging.sendEachForMulticast = original; }
});
