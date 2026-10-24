'use strict';
const { createHash, timingSafeEqual } = require('node:crypto');
const d = require('../../domain/domain');
const BASE_URL = 'https://dev.toyyibpay.com';

// The sandbox stores billExternalReferenceNo in a 50-character field. Keep
// the full internal SHA256 ID; send and verify an explicit 200-bit reference.
const externalReference = (payment) => payment.id.slice(0, 50);
const matchesReference = (reference, payment) =>
  typeof reference === 'string' &&
  reference.length > 0 &&
  (reference === externalReference(payment) || reference === payment.id);

function payerPhone(value) {
  if (typeof value !== 'string' || value.length > 30 || !/^[+\d\s()-]+$/.test(value)) {
    d.fail(
      'Enter your phone number on the payment screen, or add it under Profile > Phone Number.',
      'failed-precondition',
    );
  }
  let phone = value.replace(/[\s()+-]/g, '');
  if (phone.startsWith('0060')) phone = '0' + phone.slice(4);
  else if (phone.startsWith('60')) phone = '0' + phone.slice(2);
  if (!/^0[1-9]\d{7,9}$/.test(phone)) {
    d.fail(
      'Enter a valid Malaysian payer phone number, for example 0123456789 or +60123456789.',
      'failed-precondition',
    );
  }
  return phone;
}

function amountSen(value) {
  const text = String(value ?? '');
  if (!/^\d+(?:\.\d{1,2})?$/.test(text)) d.fail('Invalid payment amount.', 'failed-precondition');
  const [whole, fraction = ''] = text.split('.');
  const amount = Number(whole) * 100 + Number(fraction.padEnd(2, '0'));
  if (!Number.isSafeInteger(amount)) d.fail('Invalid payment amount.', 'failed-precondition');
  return amount;
}

function verifyCallback(body, secret) {
  if (
    !secret ||
    !['1', '2', '3'].includes(String(body?.status)) ||
    !/^[a-f0-9]{32}$/i.test(body?.hash ?? '') ||
    typeof body.order_id !== 'string' ||
    typeof body.refno !== 'string'
  )
    return false;
  const expected = createHash('md5')
    .update(secret + body.status + body.order_id + body.refno + 'ok')
    .digest();
  return timingSafeEqual(expected, Buffer.from(body.hash, 'hex'));
}

function verifiedTransaction(rows, payment) {
  if (!Array.isArray(rows))
    d.fail('Payment verification is unavailable. Retry shortly.', 'unavailable');
  return rows.find(
    (row) =>
      String(row.billpaymentStatus) === '1' &&
      matchesReference(row.billExternalReferenceNo, payment) &&
      amountSen(row.billpaymentAmount) === payment.totalSen &&
      typeof row.billpaymentInvoiceNo === 'string' &&
      row.billpaymentInvoiceNo.length > 0,
  );
}

function expiryText(date) {
  return new Date(date.getTime() + 8 * 3600000)
    .toISOString()
    .replace(/^(\d{4})-(\d{2})-(\d{2})T(\d{2}:\d{2}:\d{2}).*$/, '$3-$2-$1 $4');
}

function createGateway({ secret, categoryCode, callbackUrl, returnUrl, fetchImpl = fetch }) {
  async function post(method, fields) {
    let response;
    try {
      response = await fetchImpl(`${BASE_URL}/index.php/api/${method}`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
        body: new URLSearchParams(fields),
        signal: AbortSignal.timeout(15000),
      });
      if (!response.ok) throw Error('Gateway request failed');
      // createBill can return HTTP 200 with HTML or a JSON error object.
      return JSON.parse(await response.text());
    } catch (_) {
      // Never include gateway response bodies or credentials in logs/errors.
      d.fail(
        'Payment provider could not be reached. Check payment status before retrying.',
        'unavailable',
      );
    }
  }
  return {
    async create(payment, payer) {
      const returnPage = new URL(returnUrl);
      returnPage.searchParams.set('payment_id', payment.id);
      const result = await post('createBill', {
        userSecretKey: secret,
        categoryCode,
        billName: 'Bloom and Bunch Order',
        billDescription: 'Sandbox bouquet order payment',
        billPriceSetting: '1',
        billPayorInfo: '1',
        billAmount: String(payment.totalSen),
        billReturnUrl: returnPage.href,
        billCallbackUrl: callbackUrl,
        billExternalReferenceNo: externalReference(payment),
        billTo: payer.name,
        billEmail: payer.email,
        billPhone: payer.phone,
        billPaymentChannel: '0',
        billSplitPayment: '0',
        billExpiryDate: expiryText(payment.expiresAt.toDate()),
      });
      const code = Array.isArray(result) && result.length === 1 ? result[0]?.BillCode : null;
      if (typeof code !== 'string' || !/^[a-zA-Z0-9_-]{1,128}$/.test(code)) {
        d.fail(
          'The payment provider did not confirm a bill. Contact the store before retrying.',
          'unavailable',
        );
      }
      return { billCode: code, paymentUrl: `${BASE_URL}/${code}` };
    },
    transactions: (billCode) => post('getBillTransactions', { billCode, userSecretKey: secret }),
    async deactivate(billCode) {
      const result = await post('inactiveBill', { billCode, secretKey: secret });
      return (
        result?.status === 'success' ||
        (result?.status === 'failed' && result.result === 'Bill is inactive')
      );
    },
  };
}

module.exports = {
  BASE_URL,
  externalReference,
  matchesReference,
  payerPhone,
  amountSen,
  verifyCallback,
  verifiedTransaction,
  expiryText,
  createGateway,
};
