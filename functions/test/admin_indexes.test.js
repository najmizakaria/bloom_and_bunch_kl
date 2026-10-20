'use strict';
const test = require('node:test');
const assert = require('node:assert/strict');
const {readFileSync} = require('node:fs');
const {join} = require('node:path');
const {indexes} = JSON.parse(readFileSync(join(__dirname, '../../firestore.indexes.json'), 'utf8'));

test('sales aggregation index covers filters, receipt date and summed amount', () => {
  const required = ['orderMode', 'paymentStatus', 'paidAt', 'totalAmount'];
  assert.ok(indexes.some(index => index.collectionGroup === 'orders' &&
    index.queryScope === 'COLLECTION' && required.every(field =>
      index.fields.some(spec => spec.fieldPath === field && spec.order === 'ASCENDING'))));
});

test('index definitions do not duplicate the implicit document-name suffix', () => {
  const normalized = indexes.map(index => {
    const fields = [...index.fields];
    if (fields.at(-1).fieldPath !== '__name__') {
      fields.push({fieldPath: '__name__', order: fields.at(-1).order ?? 'ASCENDING'});
    }
    return JSON.stringify({...index, fields});
  });
  assert.equal(new Set(normalized).size, normalized.length);
});
