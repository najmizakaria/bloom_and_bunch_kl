(() => {
  'use strict';
  const params = new URLSearchParams(window.location.search);
  // New bills preserve the full internal ID in our own return URL. ToyyibPay
  // truncates its order_id/external reference to 50 characters.
  // status_id is deliberately ignored: only the backend can confirm payment.
  const ids = params.has('payment_id') ? params.getAll('payment_id') : params.getAll('order_id');
  const id = ids.length === 1 && /^[a-f0-9]{64}$/.test(ids[0]) ? ids[0] : null;
  const button = document.getElementById('open-app');
  const message = document.getElementById('return-message');
  if (!id) {
    message.textContent = 'Open the app and check payment from your order details.';
    button.hidden = true;
    return;
  }
  const query = '?payment_id=' + encodeURIComponent(id);
  const schemeUrl = 'bloombunch://payment-return' + query;
  const android = /Android/i.test(navigator.userAgent);
  const mobile = android || /iPhone|iPad|iPod/i.test(navigator.userAgent);
  const fallback = new URL(window.location.href);
  fallback.searchParams.set('manual', '1');
  button.href = android
    ? 'intent://payment-return' + query + '#Intent;scheme=bloombunch;' +
      'package=com.example.bloom_and_bunch_kl;S.browser_fallback_url=' +
      encodeURIComponent(fallback.href) + ';end'
    : schemeUrl;
  if (!mobile) {
    message.textContent = 'On your phone, tap Open app to verify payment. On the website, return to your original tab.';
  } else if (!params.has('manual')) {
    // Browsers may require a user gesture; the button remains as a fallback.
    window.location.replace(button.href);
  }
})();
