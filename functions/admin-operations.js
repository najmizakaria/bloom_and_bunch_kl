'use strict';
const runtime = require('firebase-admin/firestore');
const service = require('./src/application/admin');
const { validate } = require('./store-policy');

module.exports = {
  statusValues: service.statusValues,
  boundaries: (now) => service.boundaries(now, runtime.Timestamp),
  createAdminHandlers: (dependencies) =>
    service.createAdminHandlers({ ...dependencies, ...runtime, validatePolicy: validate }),
};
