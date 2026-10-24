'use strict';

const test = require('node:test');
const assert = require('node:assert/strict');
const expected = require('./fixtures/function-contract.json');

// Captured from the pre-refactor entry point, before extracting any handlers.
// A rename or changed trigger/region/schedule/secret binding is a breaking change.
test('all existing Functions retain their deployment contract', () => {
  const api = require('../index');
  const actual = Object.fromEntries(
    Object.entries(api).map(([name, fn]) => [name, JSON.parse(JSON.stringify(fn.__endpoint))]),
  );
  assert.deepEqual(actual, expected);
});
