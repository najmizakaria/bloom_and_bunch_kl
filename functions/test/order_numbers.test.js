'use strict';
const { test } = require('node:test');
const assert = require('node:assert/strict');

test('order numbers start at one, survive retries, and stay unique across checkouts', {
  skip: !process.env.FIRESTORE_EMULATOR_HOST,
}, async () => {
  const { initializeApp, deleteApp } = require('firebase-admin/app');
  const { getFirestore } = require('firebase-admin/firestore');
  const { createBackend } = require('../src/create-backend');
  const policy = require('../store-policy');
  const app = initializeApp({ projectId: `demo-order-numbers-${process.pid}` });
  const db = getFirestore(app);

  try {
    const api = createBackend({ db });
    const address = {
      recipientName: 'Customer', recipientPhone: '0123456789',
      address: '12 Test Street, Kuala Lumpur', note: '', latitude: 3.139, longitude: 101.687,
    };
    const legacy = db.doc('orders/legacy-order');
    const legacyData = { customerId: 'buyer', orderStatus: 'Pending' };
    await db.batch()
      .set(legacy, legacyData)
      .set(db.doc('users/buyer'), { role: 'customer' })
      .set(db.doc('users/buyer/addresses/home'), address)
      .set(db.doc('users/admin'), { role: 'admin' })
      .set(db.doc('flowers/rose'), { name: 'Rose', stockQuantity: 30, pricePerStem: 3 })
      .set(db.doc('bouquets/roses'), {
        name: 'Roses', price: 50, readyStock: 5, availableForReadyNow: true,
        availableForPreOrder: true, isPublished: true, leadTimeBusinessDays: 2,
        recipeStems: { rose: 3 },
      }).commit();

    const buyer = (data) => ({ auth: { uid: 'buyer' }, data });
    const ready = { bouquetId: 'roses', fulfillmentType: 'ready_now', quantity: 1 };
    const planned = {
      ...ready, fulfillmentType: 'pre_order',
      requestedDeliveryDate: policy.dateFor(new Date(), 2, policy.configured),
    };
    const items = [ready, planned];
    const quote = await api.quoteCheckout.run(buyer({ items, address }));
    const payload = {
      items, address, addressId: 'home', checkoutId: 'split',
      quoteId: quote.quoteId, expectedTotal: quote.totalSen / 100,
    };
    await assert.rejects(() => api.placeOrder.run(buyer({ ...payload, quoteId: 'stale' })));
    const [first, retry] = await Promise.all([
      api.placeOrder.run(buyer(payload)), api.placeOrder.run(buyer(payload)),
    ]);
    assert.deepEqual(retry, first);
    const readNumbers = async (ids) => (await db.getAll(...ids.map((id) => db.doc('orders/' + id))))
      .map((order) => order.get('orderNumber'));
    assert.deepEqual(await readNumbers(first.orderIds), ['#ORDER0001', '#ORDER0002']);
    const receipt = await db.doc('users/buyer/receipts/split').get();
    assert.deepEqual(receipt.get('groups').map((group) => group.orderNumber), ['#ORDER0001', '#ORDER0002']);

    const next = await Promise.all(['next-a', 'next-b'].map((checkoutId) =>
      api.placeOrder.run(buyer({ checkoutId, items: [ready], address, addressId: 'home', expectedTotal: 50 })),
    ));
    const numbers = await readNumbers(next.flatMap((result) => result.orderIds));
    assert.deepEqual(numbers.sort(), ['#ORDER0003', '#ORDER0004']);
    const adminSearch = (search) => api.adminOrders.run({ auth: { uid: 'admin' }, data: { search } });
    assert.equal((await adminSearch('#order0001')).orders[0].id, first.orderIds[0]);
    assert.equal((await adminSearch(legacy.id)).orders[0].id, legacy.id);
    assert.deepEqual((await legacy.get()).data(), legacyData);
  } finally {
    await db.terminate();
    await deleteApp(app);
  }
});
