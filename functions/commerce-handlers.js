'use strict';
const { FieldValue } = require('firebase-admin/firestore');
const service = require('./src/application/commerce');
const policyApi = require('./store-policy');

module.exports = {
  createHandlers: (dependencies) =>
    service.createHandlers({ ...dependencies, FieldValue, policyApi }),
};
