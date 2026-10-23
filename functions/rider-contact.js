'use strict';
// Preserve the public factory and pure helpers for existing callers.
module.exports = {
  ...require('./src/domain/rider-contact'),
  ...require('./src/application/rider-contact'),
};
