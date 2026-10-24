const {test} = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const vm = require('node:vm');
const code = fs.readFileSync('web/payment-return.js', 'utf8');
const id = 'a'.repeat(64);
function page(query, userAgent = 'Android') {
  const button = {}, message = {}, redirects = [];
  const url = new URL('https://bloom-and-bunch-kl.web.app/payment-return.html' + query);
  vm.runInNewContext(code, {URL, URLSearchParams,
    navigator: {userAgent},
    document: {getElementById: key => key === 'open-app' ? button : message},
    window: {location: {search: url.search, href: url.href, replace: uri => redirects.push(uri)}},
  });
  return {button, message, redirects};
}
test('Android return targets installed package and preserves only payment ID', () => {
  const {button, redirects} = page('?order_id=' + id + '&status_id=1&refno=untrusted');
  assert.ok(button.href.startsWith('intent://payment-return?payment_id=' + id + '#Intent;'));
  assert.ok(button.href.includes('package=com.example.bloom_and_bunch_kl;'));
  assert.equal(redirects[0], button.href);
  const appPart = button.href.split('#Intent')[0];
  assert.ok(!appPart.includes('status_id'));
  assert.ok(!appPart.includes('refno'));
});
test('new bills retain the full internal payment ID despite the shortened provider reference', () => {
  const {button, redirects} = page('?payment_id=' + id + '&order_id=' + id.slice(0, 50) + '&status_id=1');
  assert.ok(button.href.startsWith('intent://payment-return?payment_id=' + id + '#Intent;'));
  assert.equal(redirects[0], button.href);
  assert.equal(page('?payment_id=invalid&order_id=' + id).redirects.length, 0);
});
test('iOS custom scheme; desktop offers manual link without redirect', () => {
  assert.equal(page('?order_id=' + id, 'iPhone').redirects[0], 'bloombunch://payment-return?payment_id=' + id);
  assert.equal(page('?order_id=' + id, 'Desktop').redirects.length, 0);
});
test('browser fallback never loops; manual Open app remains available', () => {
  const result = page('?order_id=' + id + '&manual=1');
  assert.equal(result.redirects.length, 0);
  assert.ok(result.button.href.startsWith('intent://'));
});
test('missing, duplicated or injected IDs cannot navigate', () => {
  for (const query of ['', '?order_id=../orders', '?status_id=1', '?order_id=' + id + '&order_id=' + id,
    '?order_id=' + encodeURIComponent(id + ';package=evil')]) {
    const result = page(query);
    assert.equal(result.button.hidden, true);
    assert.equal(result.redirects.length, 0);
  }
});
