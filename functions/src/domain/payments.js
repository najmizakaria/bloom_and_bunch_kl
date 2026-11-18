'use strict';
const { createHash } = require('node:crypto');
const MODE = 'toyyibpay_sandbox';
const STRIPE_MODE = 'stripe_sandbox';
const STRIPE_LIVE_MODE = 'stripe_live';
const HOLD_MS = 30 * 60 * 1000;
const isStripeMode = (mode) => mode === STRIPE_MODE || mode === STRIPE_LIVE_MODE;
const isOnlineMode = (mode) => mode === MODE || isStripeMode(mode);
const requiresPayment = (order) => isOnlineMode(order?.orderMode) && order.paymentStatus !== 'paid';
const paymentId = (uid, checkoutId) =>
  createHash('sha256')
    .update(JSON.stringify([uid, checkoutId]))
    .digest('hex');

module.exports = { MODE, STRIPE_MODE, STRIPE_LIVE_MODE, HOLD_MS, isStripeMode, isOnlineMode, requiresPayment, paymentId };
