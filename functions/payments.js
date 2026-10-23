'use strict';
const { FieldValue, Timestamp } = require('firebase-admin/firestore');
const service = require('./src/application/payments');
const gatewayApi = require('./toyyibpay');

// Retain the existing factory API for tools and integration tests.
module.exports = {
  ...require('./src/domain/payments'),
  createPaymentHandlers: (dependencies) =>
    service.createPaymentHandlers({ ...dependencies, FieldValue, Timestamp, gatewayApi }),
};
