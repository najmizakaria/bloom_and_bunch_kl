'use strict';
const { createHash } = require('node:crypto');
const MODE = 'toyyibpay_sandbox';
const HOLD_MS = 30 * 60 * 1000;
const requiresPayment = (order) => order?.orderMode === MODE && order.paymentStatus !== 'paid';
const paymentId = (uid, checkoutId) =>
  createHash('sha256')
    .update(JSON.stringify([uid, checkoutId]))
    .digest('hex');

module.exports = { MODE, HOLD_MS, requiresPayment, paymentId };
