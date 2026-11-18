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

function verifySession(session, payment) {
  if (session.livemode !== false || session.mode !== 'payment' || session.currency !== 'myr' ||
      !/^cs_test_[A-Za-z0-9]+$/.test(session.id ?? '') ||
      session.client_reference_id !== payment.id || session.amount_total !== payment.totalSen ||
      (payment.stripeSessionId && session.id !== payment.stripeSessionId) ||
      (session.payment_status === 'paid' &&
        (session.status !== 'complete' || typeof session.payment_intent !== 'string'))) {
    d.fail('Stripe Checkout does not match this payment.', 'failed-precondition');
  }
  return session;
}

function createStripeGateway({ secret, returnUrl, configuration, webhookSecret, client }) {
  if (!client && !/^(?:rk|sk)_test_/.test(secret ?? ''))
    d.fail('Stripe sandbox is not configured.', 'failed-precondition');
  const stripe = client ?? new StripeClient(secret, { timeout: 15000, maxNetworkRetries: 1 });
  const sessions = stripe.checkout.sessions;
  return {
    async create(payment) {
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
        payment_method_configuration: configuration,
        adaptive_pricing: { enabled: false },
        integration_identifier: 'bloom-bunch-checkout-qkdpwzrm',
        success_url: redirect.href,
        cancel_url: redirect.href,
        // Stripe requires at least 30 minutes from session creation. The
        // reservation sweep closes the session at the earlier order deadline.
        expires_at: Math.ceil(payment.expiresAt.toMillis() / 1000) + 1800,
      }, { idempotencyKey: 'bloom-checkout-' + payment.id });
      verifySession(session, payment);
      return { stripeSessionId: session.id, paymentUrl: checkoutUrl(session.url, session.id) };
    },
    async findSession(payment, created) {
      let match;
      for await (const session of sessions.list({ created, limit: 100 })) {
        if (session.client_reference_id !== payment.id) continue;
        if (match) d.fail('Multiple Stripe sessions need store review.', 'failed-precondition');
        match = verifySession(session, payment);
      }
      return match;
    },
    async retrieve(payment, id = payment.stripeSessionId) {
      return verifySession(await sessions.retrieve(id), payment);
    },
    async expire(payment) {
      const session = await this.retrieve(payment);
      if (session.status !== 'open') return session;
      try {
        return verifySession(await sessions.expire(session.id), payment);
      } catch (error) {
        // Payment can win the race with expiry. Read Stripe's final state.
        const current = await this.retrieve(payment);
        if (current.status === 'open') throw error;
        return current;
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
