'use strict';

const { test, mock } = require('node:test');
const assert = require('node:assert/strict');
const { HttpsError } = require('firebase-functions/v2/https');
const { OrderError } = require('../domain');
const { createCallable } = require('../src/presentation/callable');

function fixture(profile) {
  const reads = [];
  const db = {
    doc: (path) => ({
      get: async () => {
        reads.push(path);
        return { data: () => profile };
      },
    }),
  };
  return { reads, callable: createCallable({ db, options: { region: 'asia-southeast1' } }) };
}

test('unauthenticated requests never reach persistence or application services', async () => {
  const { reads, callable } = fixture({});
  let called = false;
  await assert.rejects(
    () =>
      callable(() => {
        called = true;
      }).run({ data: {} }),
    (error) => error.code === 'unauthenticated' && error.message === 'Please sign in.',
  );
  assert.deepEqual(reads, []);
  assert.equal(called, false);
});

test('suspended accounts never execute an application action', async () => {
  const { reads, callable } = fixture({ accountSuspended: true });
  let called = false;
  await assert.rejects(
    () =>
      callable(() => {
        called = true;
      }).run({ auth: { uid: 'blocked' } }),
    (error) => error.code === 'permission-denied',
  );
  assert.deepEqual(reads, ['users/blocked']);
  assert.equal(called, false);
});

test('the application receives the original request and decides missing-profile policy', async () => {
  const { callable } = fixture(undefined);
  const req = { auth: { uid: 'customer' }, data: { checkoutId: 'retry' } };
  const result = { orderIds: ['original_order'] };
  assert.equal(
    await callable((input) => {
      assert.equal(input, req);
      return result;
    }).run(req),
    result,
  );
});

test('domain errors retain their public code/message and callable details survive', async () => {
  const { callable } = fixture({});
  const req = { auth: { uid: 'customer' } };
  const expected = new HttpsError('aborted', 'Cart changed.', { revision: 2 });
  await assert.rejects(
    () =>
      callable(() => {
        throw expected;
      }).run(req),
    (error) => error === expected,
  );
  await assert.rejects(
    () =>
      callable(() => {
        throw new OrderError('Restock roses.', 'failed-precondition');
      }).run(req),
    (error) =>
      error instanceof HttpsError &&
      error.code === 'failed-precondition' &&
      error.message === 'Restock roses.',
  );
});

test('unexpected infrastructure failures keep the existing sanitized client response', async () => {
  const { callable } = fixture({});
  const log = mock.method(console, 'error', () => {});
  try {
    await assert.rejects(
      () =>
        callable(() => {
          throw new Error('Private infrastructure failure');
        }).run({ auth: { uid: 'customer' } }),
      (error) =>
        error.code === 'internal' &&
        error.message === 'Unable to finish this action. Please retry.',
    );
    assert.equal(log.mock.callCount(), 1);
  } finally {
    log.mock.restore();
  }
});
