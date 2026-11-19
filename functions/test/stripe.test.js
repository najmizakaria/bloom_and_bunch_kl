'use strict';
const assert = require('node:assert/strict');
const { test } = require('node:test');
const Stripe = require('stripe');
const { createStripeGateway } = require('../src/infrastructure/payments/stripe');

const payment = { id: 'checkout', totalSen: 3400, expiresAt: { toMillis: () => 1800000000000 } };
const session = {
  id: 'cs_test_session1', client_reference_id: payment.id, mode: 'payment', currency: 'myr',
  amount_total: 3400, status: 'open', payment_status: 'unpaid', livemode: false,
  url: 'https://checkout.stripe.com/c/pay/cs_test_session1#hosted',
};

test('Stripe Checkout preserves MYR, card settings, and the same request on retry', async () => {
  const calls = [];
  const gateway = createStripeGateway({
    returnUrl: 'https://bloomandbunchkl.com/payment-return.html', configuration: 'pmc_demo',
    client: { checkout: { sessions: { async create(...args) { calls.push(args); return session; } } } },
  });
  assert.deepEqual(await gateway.create(payment), { stripeSessionId: session.id, paymentUrl: session.url });
  await gateway.create(payment);
  assert.deepEqual(calls[0], calls[1]);
  const [fields, options] = calls[0];
  assert.deepEqual(fields.line_items[0].price_data, {
    currency: 'myr', unit_amount: 3400, product_data: { name: 'Bloom & Bunch KL order' },
  });
  assert.equal(fields.payment_method_configuration, 'pmc_demo');
  assert.equal(options.idempotencyKey, 'bloom-checkout-checkout');
  assert.equal(new URL(fields.success_url).searchParams.get('payment_id'), payment.id);
});

test('Stripe verification rejects a different checkout, total, currency or live session', async () => {
  let response = session;
  const gateway = createStripeGateway({
    client: { checkout: { sessions: { async retrieve() { return response; } } } },
  });
  for (const change of [{ id: 'cs_test_other' }, { amount_total: 3300 }, { currency: 'usd' }, { livemode: true }]) {
    response = { ...session, ...change };
    await assert.rejects(() => gateway.retrieve({ ...payment, stripeSessionId: session.id }),
      (error) => error.code === 'failed-precondition');
  }
});

test('Stripe returns both hosted URL paths with the matching sandbox session ID', async () => {
  let url;
  const gateway = createStripeGateway({
    returnUrl: 'https://bloomandbunchkl.com/payment-return.html',
    client: { checkout: { sessions: { async create() { return { ...session, url }; } } } },
  });
  for (const path of ['c', 'g']) {
    url = 'https://checkout.stripe.com/' + path + '/pay/' + session.id + '#hosted';
    assert.equal((await gateway.create(payment)).paymentUrl, url);
  }
  for (const invalid of ['https://checkout.stripe.com/g/pay/cs_test_other',
    'https://checkout.stripe.com.example.test/g/pay/' + session.id]) {
    url = invalid;
    await assert.rejects(() => gateway.create(payment), { code: 'unavailable' });
  }
});

test('Stripe recovery finds only the matching verified session', async () => {
  const created = { gte: 100, lte: 200 };
  const gateway = createStripeGateway({
    client: { checkout: { sessions: { async *list(query) {
      assert.deepEqual(query, { created, limit: 100 });
      yield { ...session, client_reference_id: 'other' };
      yield session;
    } } } },
  });
  assert.deepEqual(await gateway.findSession(payment, created), session);
});

test('Stripe webhook uses the signature over the original request bytes', () => {
  const client = new Stripe('fixture-key');
  const secret = 'fixture-webhook-secret';
  const payload = JSON.stringify({ type: 'checkout.session.completed', livemode: false });
  const header = client.webhooks.generateTestHeaderString({ payload, secret });
  const gateway = createStripeGateway({ client, webhookSecret: secret });
  assert.equal(gateway.verifyWebhook(Buffer.from(payload), header).type, 'checkout.session.completed');
  assert.throws(() => gateway.verifyWebhook(Buffer.from(payload + ' '), header),
    (error) => error.code === 'permission-denied');
});

test('live checkout uses cards and rejects charges until manual payouts are ready', async () => {
  let payoutsEnabled = false;
  let schedule = 'manual';
  const calls = [];
  const livePayment = { ...payment, environment: 'live' };
  const liveSession = { ...session, id: 'cs_live_session1', livemode: true,
    url: 'https://checkout.stripe.com/g/pay/cs_live_session1#hosted' };
  const gateway = createStripeGateway({
    live: true,
    returnUrl: 'https://bloomandbunchkl.com/payment-return.html',
    client: {
      accounts: { retrieve: async () => ({country: 'MY', charges_enabled: true, payouts_enabled: payoutsEnabled}) },
      balanceSettings: { retrieve: async () => ({payments: {payouts: {schedule: {interval: schedule}}}}) },
      checkout: { sessions: {
        create: async (fields) => { calls.push(fields); return liveSession; },
        retrieve: async () => session,
      } },
    },
  });
  await assert.rejects(() => gateway.create(livePayment), /configures payouts/);
  payoutsEnabled = true;
  schedule = 'daily';
  await assert.rejects(() => gateway.create(livePayment), /configures payouts/);
  assert.equal(calls.length, 0);
  schedule = 'manual';
  assert.equal((await gateway.create(livePayment)).stripeSessionId, liveSession.id);
  assert.deepEqual(calls[0].allowed_payment_method_types, ['card']);
  assert.equal(calls[0].payment_method_configuration, undefined);
  await assert.rejects(() => gateway.retrieve(livePayment), {code:'failed-precondition'});
  await assert.rejects(() => gateway.create(payment), {code:'failed-precondition'});
  assert.equal(calls.length, 1);
});
