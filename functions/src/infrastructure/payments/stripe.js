'use strict';
const StripeClient = require('stripe');
const d = require('../../domain/domain');

function checkoutUrl(value, sessionId) {
  try {
    const url = new URL(value);
    if (url.origin === 'https://checkout.stripe.com' && !url.username && !url.password &&
        (url.pathname === '/c/pay/' + sessionId || url.pathname === '/g/pay/' + sessionId)) return url.href;
  } catch (_) {
    // An invalid hosted URL must never be sent to the app.
  }
  d.fail('Stripe Checkout is unavailable.', 'unavailable');
}

function verifySession(session, payment, live) {
  const sessionPattern = live ? /^cs_live_[A-Za-z0-9]+$/ : /^cs_test_[A-Za-z0-9]+$/;
  if ((payment.environment === 'live') !== live || session.livemode !== live ||
      session.mode !== 'payment' || session.currency !== 'myr' ||
      !sessionPattern.test(session.id ?? '') ||
      session.client_reference_id !== payment.id || session.amount_total !== payment.totalSen ||
      (payment.stripeSessionId && session.id !== payment.stripeSessionId) ||
      (session.payment_status === 'paid' &&
        (session.status !== 'complete' || typeof session.payment_intent !== 'string'))) {
    d.fail('Stripe Checkout does not match this payment.', 'failed-precondition');
  }
  return session;
}

function createStripeGateway({ secret, returnUrl, configuration, webhookSecret, client, live = false }) {
  const keyPattern = live ? /^(?:rk|sk)_live_/ : /^(?:rk|sk)_test_/;
  if (!client && !keyPattern.test(secret ?? ''))
    d.fail(live ? 'Live Stripe Checkout is not configured.' : 'Stripe sandbox is not configured.', 'failed-precondition');
  const stripe = client ?? new StripeClient(secret, { timeout: 15000, maxNetworkRetries: 1 });
  const sessions = stripe.checkout.sessions;
  function verifyEnvironment(payment) {
    if ((payment.environment === 'live') !== live)
      d.fail('Stripe payment environment does not match.', 'failed-precondition');
  }
  return {
    async create(payment) {
      verifyEnvironment(payment);
      if (live) {
        const [account, settings] = await Promise.all([stripe.accounts.retrieve(null), stripe.balanceSettings.retrieve()]);
        if (account.country !== 'MY' || !account.charges_enabled || !account.payouts_enabled ||
            settings.payments?.payouts?.schedule?.interval !== 'manual')
          d.fail('Live payments are unavailable until the store configures payouts.', 'failed-precondition');
      }
      const redirect = new URL(returnUrl);
      redirect.searchParams.set('payment_id', payment.id);
      redirect.searchParams.set('provider', 'stripe');
      const session = await sessions.create({
        mode: 'payment',
        client_reference_id: payment.id,
        line_items: [{
          price_data: { currency: 'myr', unit_amount: payment.totalSen,
            product_data: { name: 'Bloom & Bunch KL order' } },
          quantity: 1,
        }],
        ...(live ? { payment_method_types: ['card'] } : {
          payment_method_configuration: configuration,
          integration_identifier: 'bloom-bunch-checkout-qkdpwzrm',
        }),
        adaptive_pricing: { enabled: false },
        success_url: redirect.href,
        cancel_url: redirect.href,
        // Stripe requires at least 30 minutes from session creation. The
        // reservation sweep closes the session at the earlier order deadline.
        expires_at: Math.ceil(payment.expiresAt.toMillis() / 1000) + 1800,
      }, { idempotencyKey: 'bloom-checkout-' + payment.id });
      verifySession(session, payment, live);
      return { stripeSessionId: session.id, paymentUrl: checkoutUrl(session.url, session.id) };
    },
    async findSession(payment, created) {
      verifyEnvironment(payment);
      let match;
      for await (const session of sessions.list({ created, limit: 100 })) {
        if (session.client_reference_id !== payment.id) continue;
        if (match) d.fail('Multiple Stripe sessions need store review.', 'failed-precondition');
        match = verifySession(session, payment, live);
      }
      return match;
    },
    async retrieve(payment, id = payment.stripeSessionId) {
      verifyEnvironment(payment);
      return verifySession(await sessions.retrieve(id), payment, live);
    },
    async expire(payment) {
      const session = await this.retrieve(payment);
      if (session.status !== 'open') return session;
      try {
        return verifySession(await sessions.expire(session.id), payment, live);
      } catch (error) {
        // Payment can win the race with expiry. Read Stripe's final state.
        const current = await this.retrieve(payment);
        if (current.status === 'open') throw error;
        return current;
      }
    },
    async payoutAmount(payment) {
      verifyEnvironment(payment);
      const settings = await stripe.balanceSettings.retrieve();
      if (settings.payments?.payouts?.schedule?.interval !== 'manual')
        return { review: 'Stripe manual payouts are required.' };
      const intent = await stripe.paymentIntents.retrieve(payment.transactionId, {
        expand: ['latest_charge.balance_transaction'],
      });
      const charge = intent.latest_charge;
      if (intent.livemode !== live || intent.status !== 'succeeded' ||
          intent.currency !== 'myr' || intent.amount_received !== payment.totalSen ||
          charge?.livemode !== live || !charge.captured || charge.amount_captured !== payment.totalSen ||
          charge.disputed || charge.amount_refunded !== 0)
        return { review: 'The Stripe charge is refunded, disputed, or no longer matches.' };
      const transaction = charge.balance_transaction;
      if (!transaction || typeof transaction === 'string') return {};
      if (transaction.currency !== 'myr' || !Number.isSafeInteger(transaction.net) || transaction.net <= 0)
        return { review: 'The Stripe charge has an invalid net payout amount.' };
      if (transaction.status !== 'available') return {};
      const balance = await stripe.balance.retrieve();
      const available = balance.available.find((entry) => entry.currency === 'myr');
      return (available?.source_types?.card ?? 0) >= transaction.net ? { amount: transaction.net } : {};
    },
    async createPayout(payment, amount) {
      verifyEnvironment(payment);
      const payout = await stripe.payouts.create({
        amount, currency: 'myr', source_type: 'card',
        metadata: { bloom_payment_id: payment.id },
      }, { idempotencyKey: 'bloom-order-payout-' + payment.id });
      if (payout.livemode !== live || payout.amount !== amount || payout.currency !== 'myr')
        d.fail('Stripe payout does not match.', 'failed-precondition');
      return payout;
    },
    async retrievePayout(id) {
      const payout = await stripe.payouts.retrieve(id);
      if (payout.livemode !== live) d.fail('Stripe payout environment does not match.', 'failed-precondition');
      return payout;
    },
    async findPayout(payment) {
      verifyEnvironment(payment);
      const since = Math.floor(payment.payoutStartedAt.toMillis() / 1000) - 60;
      for await (const payout of stripe.payouts.list({ created: { gte: since }, limit: 100 })) {
        if (payout.metadata?.bloom_payment_id !== payment.id) continue;
        if (payout.livemode !== live || payout.amount !== payment.payoutAmountSen || payout.currency !== 'myr')
          d.fail('Stripe payout does not match.', 'failed-precondition');
        return payout;
      }
    },
    verifyWebhook(rawBody, signature) {
      if (!webhookSecret || !signature) d.fail('Invalid Stripe signature.', 'permission-denied');
      try {
        return stripe.webhooks.constructEvent(rawBody, signature, webhookSecret);
      } catch (_) {
        d.fail('Invalid Stripe signature.', 'permission-denied');
      }
    },
  };
}

module.exports = { createStripeGateway };
