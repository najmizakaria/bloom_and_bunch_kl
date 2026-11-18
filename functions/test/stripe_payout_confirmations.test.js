'use strict';

const assert = require('node:assert/strict');
const { test } = require('node:test');
const { createPayoutSweep, payoutGate } = require('../src/application/payouts');
const { createStripeGateway } = require('../src/infrastructure/payments/stripe');

const payment = { id: 'payment', customerId: 'customer', totalSen: 5500, transactionId: 'pi_example' };
const confirmed = {
  paymentId: payment.id, customerId: payment.customerId, orderMode: 'stripe_sandbox',
  paymentStatus: 'paid', orderStatus: 'Completed', deliveredAt: true, customerAcceptedAt: true,
};

test('all deliveries must be confirmed and clear of issues before payout', () => {
  assert.equal(payoutGate(payment, [confirmed, confirmed]), 'eligible');
  assert.equal(payoutGate(payment, [confirmed, { ...confirmed, customerAcceptedAt: null }]), 'awaiting_delivery');
  assert.equal(payoutGate(payment, [{ ...confirmed, support: { status: 'open' } }]), 'awaiting_delivery');
  assert.equal(payoutGate(payment, [{ ...confirmed, orderStatus: 'Cancelled' }]), 'review');
  assert.equal(payoutGate(payment, [{ ...confirmed, customerId: 'different' }]), 'review');
});

test('Stripe payout uses the available net MYR amount and a stable idempotency key', async () => {
  const charge = {
    livemode: false, captured: true, amount_captured: payment.totalSen, amount_refunded: 0,
    disputed: false, balance_transaction: { currency: 'myr', status: 'available', net: 5250 },
  };
  let interval = 'daily';
  let requests = 0;
  const gateway = createStripeGateway({ client: {
    checkout: { sessions: {} },
    balanceSettings: { retrieve: async () => ({ payments: { payouts: { schedule: { interval } } } }) },
    paymentIntents: { retrieve: async () => ({ livemode: false, status: 'succeeded', currency: 'myr', amount_received: 5500, latest_charge: charge }) },
    balance: { retrieve: async () => ({ available: [{ currency: 'myr', source_types: { card: 5250 } }] }) },
    payouts: { create: async (params, options) => {
      requests++;
      assert.equal(options.idempotencyKey, 'bloom-order-payout-payment');
      assert.equal(params.metadata.bloom_payment_id, payment.id);
      return { id: 'po_test', livemode: false, ...params };
    } },
  } });
  assert.match((await gateway.payoutAmount(payment)).review, /manual/);
  interval = 'manual';
  charge.amount_refunded = 500;
  assert.match((await gateway.payoutAmount(payment)).review, /refunded/);
  charge.amount_refunded = 0;
  const { amount } = await gateway.payoutAmount(payment);
  assert.equal(amount, 5250);
  assert.equal((await gateway.createPayout(payment, amount)).id, 'po_test');
  assert.equal(requests, 1);
});

test('scheduled payout only submits once, after the last delivery is confirmed', async () => {
  const timestamp = (ms) => ({ toMillis: () => ms });
  let now = Date.now();
  const state = {
    ...payment, provider: 'stripe', environment: 'sandbox', status: 'paid',
    orderIds: ['first', 'last'], payoutNextCheckAt: timestamp(now),
  };
  const last = { ...confirmed, customerAcceptedAt: null };
  const paymentRef = { update: async (fields) => Object.assign(state, fields) };
  const db = {
    collection: () => ({ where: () => ({ limit: () => ({ get: async () => ({ docs: [{ ref: paymentRef }] }) }) }) }),
    doc: (path) => path,
    runTransaction: (work) => work({
      get: async (ref) => ({ data: () => ref === paymentRef ? { ...state } : ref === 'orders/last' ? last : confirmed }),
      update: (_, fields) => Object.assign(state, fields),
    }),
  };
  let payouts = 0;
  const sweep = createPayoutSweep({
    db, now: () => now, Timestamp: { fromMillis: timestamp }, FieldValue: { delete: () => undefined },
    getStripeGateway: () => ({
      payoutAmount: async () => ({ amount: 5250 }),
      createPayout: async () => { payouts++; return { id: 'po_test', status: 'paid' }; },
    }),
  });
  await sweep();
  assert.equal(payouts, 0);
  last.customerAcceptedAt = timestamp(now);
  now += 15 * 60 * 1000;
  await sweep();
  await sweep();
  assert.equal(payouts, 1);
  assert.equal(state.payoutStatus, 'paid_out');
});
