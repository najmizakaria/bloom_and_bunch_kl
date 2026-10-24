'use strict';

const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const { builtinModules } = require('node:module');
const sourceRoot = path.resolve(__dirname, '../src');

function files(directory) {
  return fs.readdirSync(directory, { withFileTypes: true }).flatMap((entry) => {
    const file = path.join(directory, entry.name);
    return entry.isDirectory() ? files(file) : file.endsWith('.js') ? [file] : [];
  });
}

for (const layer of ['domain', 'application']) {
  test(`${layer} dependencies point inward and do not import Firebase`, () => {
    for (const file of files(path.join(sourceRoot, layer))) {
      const source = fs.readFileSync(file, 'utf8');
      for (const [, dependency] of source.matchAll(/require\(['"]([^'"]+)['"]\)/g)) {
        if (dependency.startsWith('node:') || builtinModules.includes(dependency)) continue;
        assert.ok(dependency.startsWith('.'), `${file}: external SDK ${dependency}`);
        const target = path.resolve(path.dirname(file), dependency);
        const allowed = layer === 'domain' ? ['domain'] : ['domain', 'application'];
        assert.ok(
          allowed.some((name) => target.startsWith(path.join(sourceRoot, name) + path.sep)),
          `${file}: outward dependency ${dependency}`,
        );
      }
      if (layer === 'domain') {
        assert.doesNotMatch(
          source,
          /process\.env|firebase-|initializeApp|onCall\(/,
          `${file}: runtime configuration belongs outside the domain`,
        );
      }
    }
  });
}

test('independent store-policy instances do not share deployment configuration', () => {
  const { createStorePolicy } = require('../src/domain/store-policy');
  const defaults = require('../store-policy.json');
  const first = createStorePolicy({ ...defaults });
  const second = createStorePolicy({ ...defaults });
  first.configured.bookingWindowDays = 7;
  assert.equal(second.configured.bookingWindowDays, defaults.bookingWindowDays);
  assert.notEqual(first.configured, second.configured);
});

test('legacy imports preserve domain error identity and payment policy', () => {
  assert.equal(require('../domain').OrderError, require('../src/domain/domain').OrderError);
  const legacy = require('../payments');
  const policy = require('../src/domain/payments');
  for (const name of ['MODE', 'HOLD_MS', 'paymentId', 'requiresPayment']) {
    assert.equal(legacy[name], policy[name]);
  }
});
