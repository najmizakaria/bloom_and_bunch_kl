'use strict';
// Feature regression coverage.
const { test, before, after } = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const { initializeTestEnvironment, assertSucceeds, assertFails } = require('@firebase/rules-unit-testing');
const { doc, updateDoc } = require('firebase/firestore');
const enabled = !!process.env.FIRESTORE_EMULATOR_HOST;
let api, db, rules;
const uid = 'feature_audit_customer';
const address = { label: 'Home', address: '12 Main Street, Kuala Lumpur', recipientName: 'Audit', recipientPhone: '0123456789', note: '', isDefault: true, latitude: 3.139, longitude: 101.6869 };
const ready = { name: 'Audit bouquet', description: '', category: 'Birthday', imageUrl: '', price: 50, readyStock: 10, availableForReadyNow: true, isPublished: true };
function request(checkoutId, addressId, items, expectedTotal, shownAddress = address) {
  return { auth: { uid }, data: { checkoutId, addressId, items, expectedTotal, address: shownAddress } };
}
before(async () => {
  if (!enabled) return;
  if (!process.env.FIRESTORE_EMULATOR_HOST || !process.env.GCLOUD_PROJECT?.startsWith('demo-')) throw Error('Run only against a demo Firestore emulator.');
  api = require('../index');
  db = require('firebase-admin/firestore').getFirestore();
  rules = await initializeTestEnvironment({ projectId: 'demo-bloom', firestore: { rules: fs.readFileSync(path.resolve(__dirname, '../../firestore.rules'), 'utf8') } });
  await db.doc(`users/${uid}`).set({ uid, name: 'Audit', email: 'audit@example.com', phone: '0123456789', role: 'customer', roles: ['customer'], activeRole: 'customer', createdAt: new Date() });
  await db.doc('users/feature_audit_florist').set({ role: 'florist' });
  await db.doc('bouquets/feature_audit_ready').set(ready);
});
after(async () => { if (rules) await rules.cleanup(); if (db) await db.terminate(); });
const readyItem = { bouquetId: 'feature_audit_ready', fulfillmentType: 'ready_now', quantity: 1 };

test('REGRESSION: reject undispatchable checkout before deducting stock', {skip: !enabled}, async () => {
  const manual = { ...address, latitude: null, longitude: null };
  await db.doc(`users/${uid}/addresses/manual`).set(manual);
  const before = (await db.doc('bouquets/feature_audit_ready').get()).data().readyStock;
  let result;
  try {
    result = await api.placeOrder.run(request('audit_manual', 'manual', [readyItem], 50, manual));
  } catch (error) {
    assert.ok(['failed-precondition', 'invalid-argument'].includes(error.code));
    assert.equal((await db.doc('bouquets/feature_audit_ready').get()).data().readyStock, before);
    return;
  }
  const order = (await db.doc(`orders/${result.orderIds[0]}`).get()).data();
  const job = await db.doc(`delivery_jobs/${result.orderIds[0]}`).get();
  assert.equal(job.exists, true, `Checkout succeeded as ${order.orderStatus}, but no rider job exists and ready stock was deducted`);
});

test('REGRESSION: do not silently use an address different from checkout confirmation', {skip: !enabled}, async () => {
  const changed = { ...address, address: '99 Other Street, Cyberjaya', latitude: 2.92, longitude: 101.65 };
  await db.doc(`users/${uid}/addresses/changed`).set(changed);
  let result;
  try {
    result = await api.placeOrder.run(request('audit_address_changed', 'changed', [readyItem], 50));
  } catch (error) {
    assert.equal(error.code, 'failed-precondition');
    return;
  }
  const order = (await db.doc(`orders/${result.orderIds[0]}`).get()).data();
  assert.equal(order.deliveryAddress, address.address, 'Saved address changed after checkout loaded; confirmation was not validated');
});

test('REGRESSION: notification preference can be saved by its owner', {skip: !enabled}, async () => {
  const client = rules.authenticatedContext(uid).firestore();
  await assertSucceeds(updateDoc(doc(client, 'users', uid), { notificationsEnabled: false }));
});

test('REGRESSION: reject a published pre-order recipe that checkout cannot accept', {skip: !enabled}, async () => {
  await db.doc('bouquets/feature_audit_recipe').set({ ...ready, availableForPreOrder: true, recipeStems: { feature_audit_rose: 12 }, leadTimeBusinessDays: 2 });
  const client = rules.authenticatedContext('feature_audit_florist').firestore();
  await assertFails(updateDoc(doc(client, 'bouquets', 'feature_audit_recipe'), { recipeStems: { feature_audit_rose: 101 } }));
});

test('REGRESSION: custom checkout agrees with current fractional stem prices', {skip: !enabled}, async () => {
  await db.doc(`users/${uid}/addresses/rounding`).set(address);
  await db.doc('flowers/feature_audit_rose').set({ name: 'Rose', category: 'Rose', imageUrl: '', stockQuantity: 0, reservedQuantity: 0, pricePerStem: 0.333, availableForCustomOrder: true });
  const item = { fulfillmentType: 'custom', quantity: 1, customStems: { feature_audit_rose: 3 }, wrapper: 'Kraft Paper (Classic)', ribbon: 'Red Satin', cardNote: '', requestedDeliveryDate:require('../store-policy').dateFor(new Date(),2,require('../store-policy').configured) };
  // Same formula used by the builder and ReorderService.
  const displayedTotal = 7 + 0.333 * 3;
  await api.placeOrder.run(request('audit_rounding', 'rounding', [item], displayedTotal));
});

test('REGRESSION: malformed cart entry returns a validation error', {skip: !enabled}, async () => {
  await assert.rejects(() => api.placeOrder.run(request('audit_null', 'rounding', [null], 50)), error => error.code === 'invalid-argument');
});

test('CONTROL: valid address checkout creates an available rider job', {skip: !enabled}, async () => {
  await db.doc(`users/${uid}/addresses/control`).set(address);
  const result = await api.placeOrder.run(request('audit_control', 'control', [readyItem], 50));
  assert.equal((await db.doc(`delivery_jobs/${result.orderIds[0]}`).get()).exists, true);
});



test('rules accept supported recipes and reject total/type violations', {skip: !enabled}, async () => {
  const ref=doc(rules.authenticatedContext('feature_audit_florist').firestore(), 'bouquets', 'feature_audit_recipe');
  await assertSucceeds(updateDoc(ref, {recipeStems:{feature_audit_rose:100, tulip:50}}));
  await assertFails(updateDoc(ref, {recipeStems:{feature_audit_rose:100, tulip:51}}));
  await assertFails(updateDoc(ref, {recipeStems:{feature_audit_rose:1.5}}));
  await assertFails(updateDoc(ref, {recipeStems:{feature_audit_rose:'12'}}));
  await assertFails(updateDoc(ref, {recipeStems:{}}));
  await assertSucceeds(updateDoc(ref, {recipeStems:Object.fromEntries(Array.from({length:30},(_,i)=>['flower_'+i,1]))}));
  await assertFails(updateDoc(ref, {recipeStems:Object.fromEntries(Array.from({length:31},(_,i)=>['flower_'+i,1]))}));
});
