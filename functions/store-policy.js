'use strict';
const { createStorePolicy } = require('./src/domain/store-policy');
const configured = { ...require('./store-policy.json') };
// Retain the existing import-time environment override and object identity.
if (process.env.STORE_ORDER_MODE) configured.mode = process.env.STORE_ORDER_MODE;
module.exports = createStorePolicy(configured);
