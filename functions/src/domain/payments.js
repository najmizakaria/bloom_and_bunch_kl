'use strict';
const { createHash } = require('node:crypto');
const MODE = 'toyyibpay_sandbox';
const STRIPE_MODE = 'stripe_sandbox';
const HOLD_MS = 30 * 60 * 1000;
const isOnlineMode = (mode) => mode === MODE || mode === STRIPE_MODE;
const requiresPayment = (order) => isOnlineMode(order?.orderMode) && order.paymentStatus !== 'paid';
const paymentId = (uid, checkoutId) =>
  createHash('sha256')
    .update(JSON.stringify([uid, checkoutId]))
    .digest('hex');

module.exports = { MODE, STRIPE_MODE, HOLD_MS, isOnlineMode, requiresPayment, paymentId };
