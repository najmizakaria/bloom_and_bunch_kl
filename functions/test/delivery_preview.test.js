'use strict';
const {test} = require('node:test');
const assert = require('node:assert/strict');
const {addressArea, preview} = require('../delivery-preview');

test('preview includes the order address but excludes recipient contact and map coordinates', () => {
  const value = preview({deliveryLocality:'Kajang',deliveryPostcode:'43000',deliveryState:'Selangor',
    deliveryAddress:'Unit 5, Private Building, Private Street',recipientName:'Private person',
    recipientPhone:'0123456789',latitude:3.12,longitude:101.7,items:[{quantity:1},{quantity:2}]});
  assert.equal(value.deliveryArea,'Kajang · 43000');
  assert.equal(value.itemCount,3);
  assert.equal(value.deliveryState,'Selangor');
  assert.equal(value.deliveryAddress,'Unit 5, Private Building, Private Street');
  for (const key of ['recipientName','recipientPhone','latitude','longitude']) assert.equal(key in value,false);
});
test('legacy Malaysian addresses recover the locality beside the postcode', () => {
  for (const address of [
    'WQMX+JV, 43000 Kajang, Selangor, Malaysia',
    'WQMX+JV, 43000 Kajang, Selangor, Malaysia, Kajang, 43000, Selangor, Malaysia',
  ]) assert.deepEqual(addressArea({address}),{locality:'Kajang',postcode:'43000',state:'Selangor'});
  assert.equal(preview({deliveryAddress:'Unit G2, StreetMall, 63000 Cyberjaya, Selangor'}).deliveryArea,'Cyberjaya · 63000');
  assert.equal(preview({deliveryAddress:'12 Main Street, Kuala Lumpur'}).deliveryArea,'Kuala Lumpur');
});
test('ambiguous, street-like and malformed localities never expose address fragments', () => {
  for (const address of ['Private Building, Selangor, Malaysia','Unit 5, 43000 Jalan Rahsia, Selangor','Private Street']) {
    assert.equal(preview({deliveryAddress:address}).deliveryArea,'Area needs confirmation');
  }
  assert.equal(preview({locality:'Unit 22',deliveryAddress:'Private'}).deliveryArea,'Area needs confirmation');
});
test('valid explicit fields take priority and territory names are normalized', () => {
  assert.deepEqual(addressArea({locality:'Kajang',postcode:'43000',state:'selangor',address:'50000 Kuala Lumpur'}),
    {locality:'Kajang',postcode:'43000',state:'Selangor'});
  assert.equal(addressArea({state:'Wilayah Persekutuan Kuala Lumpur'}).locality,'Kuala Lumpur');
  assert.equal(addressArea({state:'W.P. Putrajaya'}).state,'Putrajaya');
});
