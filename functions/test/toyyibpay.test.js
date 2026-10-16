'use strict';
const {test} = require('node:test');
const assert = require('node:assert/strict');
const {createHash} = require('node:crypto');
const api = require('../toyyibpay');

test('payer phone accepts local/international formatting and rejects missing or invalid contact', () => {
  for (const value of ['0123456789', '+60 12-345 6789', '60123456789', '0060123456789', '(012) 345-6789']) {
    assert.equal(api.payerPhone(value), '0123456789');
  }
  for (const value of ['', null, undefined, 123456789, 'abc0123456789', '123', '0000000000']) {
    assert.throws(() => api.payerPhone(value), e => e.code === 'failed-precondition' && /phone/i.test(e.message));
  }
});

test('callback requires the documented signature and rejects malformed input', () => {
  const body = {status: '1', order_id: 'checkout', refno: 'ref'};
  body.hash = createHash('md5').update('test-secret1checkoutrefok').digest('hex');
  assert.equal(api.verifyCallback(body, 'test-secret'), true);
  for (const mutation of [{status: '3'}, {order_id: 'other'}, {refno: 'other'}, {hash: 'z'.repeat(32)}, {hash: ''}]) {
    assert.equal(api.verifyCallback({...body, ...mutation}, 'test-secret'), false);
  }
  assert.equal(api.verifyCallback(body, ''), false);
});

test('verification requires successful status, exact external reference, amount and transaction ID', () => {
  const row = {billpaymentStatus: '1', billExternalReferenceNo: 'checkout', billpaymentAmount: '50.05', billpaymentInvoiceNo: 'TX1'};
  const payment = {id: 'checkout', totalSen: 5005};
  assert.equal(api.verifiedTransaction([row], payment), row);
  for (const mutation of [{billpaymentStatus: '2'}, {billExternalReferenceNo: 'other'}, {billpaymentAmount: '50.04'}, {billpaymentInvoiceNo: ''}]) {
    assert.equal(api.verifiedTransaction([{...row, ...mutation}], payment), undefined);
  }
  assert.throws(() => api.verifiedTransaction({}, payment));
  assert.equal(api.amountSen('0.10'), 10);
  assert.equal(api.amountSen('50'), 5000);
  assert.throws(() => api.amountSen('1e3'));
  assert.throws(() => api.amountSen('50.001'));
});

test('bill creation uses sandbox, fixed cents, FPX, MYT expiry and server-owned reference', async () => {
  let request;
  const gateway = api.createGateway({secret: 'test-secret', categoryCode: 'category',
    callbackUrl: 'https://example.test/callback', returnUrl: 'https://example.test/return',
    fetchImpl: async (url, options) => { request = {url, fields: Object.fromEntries(options.body)};
      return {ok: true, text: async () => '[{"BillCode":"testBill"}]'}; },
  });
  const result = await gateway.create({id: 'checkout', totalSen: 5005,
    expiresAt: {toDate: () => new Date('2026-10-16T02:30:00Z')}}, {name: 'Test', email: 'test@example.test', phone: '0123456789'});
  assert.equal(request.url, 'https://dev.toyyibpay.com/index.php/api/createBill');
  assert.equal(request.fields.billAmount, '5005');
  assert.equal(request.fields.billPriceSetting, '1');
  assert.equal(request.fields.billPaymentChannel, '0');
  assert.equal(request.fields.billExpiryDate, '16-10-2026 10:30:00');
  assert.equal(request.fields.billExternalReferenceNo, 'checkout');
  assert.equal(result.paymentUrl, 'https://dev.toyyibpay.com/testBill');
});

test('real SHA256 payment IDs use an exact 50-character provider reference and retain the full return ID', async () => {
  const id = createHash('sha256').update('realistic-checkout').digest('hex');
  const payment = {id, totalSen: 2500, expiresAt: {toDate: () => new Date()}};
  const row = {billpaymentStatus: '1', billExternalReferenceNo: id.slice(0, 50),
    billpaymentAmount: '25.00', billpaymentInvoiceNo: 'TP-test'};
  assert.equal(api.verifiedTransaction([row], payment), row);
  assert.equal(api.verifiedTransaction([{...row, billExternalReferenceNo: id.slice(0, 49)}], payment), undefined);
  assert.equal(api.verifiedTransaction([{...row, billExternalReferenceNo: 'b'.repeat(50)}], payment), undefined);
  let fields;
  const gateway = api.createGateway({secret: 'test', categoryCode: 'category',
    callbackUrl: 'https://example.test/callback', returnUrl: 'https://example.test/return?existing=1',
    fetchImpl: async (_, options) => {
      fields = Object.fromEntries(options.body);
      return {ok: true, text: async () => '[{"BillCode":"bill"}]'};
    },
  });
  await gateway.create(payment, {});
  assert.equal(fields.billExternalReferenceNo, id.slice(0, 50));
  assert.equal(new URL(fields.billReturnUrl).searchParams.get('payment_id'), id);
  assert.equal(new URL(fields.billReturnUrl).searchParams.get('existing'), '1');
});

test('HTTP 200 errors, invalid bill codes, network failures and invalid transaction responses fail closed', async () => {
  for (const body of ['[KEY-DID-NOT-EXIST]', '{"status":"error","msg":"secret details"}', '[{"BillCode":"https://bad.test"}]']) {
    const gateway = api.createGateway({returnUrl: 'https://example.test/return', fetchImpl: async () => ({ok: true, text: async () => body})});
    await assert.rejects(() => gateway.create({id: 'id', totalSen: 100, expiresAt: {toDate: () => new Date()}}, {}), error =>
      error.code === 'unavailable' && !error.message.includes('secret details'));
  }
  const offline = api.createGateway({fetchImpl: async () => { throw Error('network'); }});
  await assert.rejects(() => offline.transactions('bill'), error => error.code === 'unavailable');
});
