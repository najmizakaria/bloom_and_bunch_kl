# Sandbox activation — 16 October 2026

ToyyibPay sandbox checkout is enabled on Firebase project `bloom-and-bunch-kl`. It charges for flower items only. Delivery fees are zero, coverage is unrestricted, and daily delivery capacity is not enforced. The existing saved-address and map-pin step remains.

The saved Secret Manager version was checked without printing its value. A read-only request to ToyyibPay confirmed that the secret matches the active sandbox Category Code `47y7rh02`. No test order, bill, or bank payment was created during deployment verification.

## Deployed

- Website: <https://bloom-and-bunch-kl.web.app>
- Payment return page: <https://bloom-and-bunch-kl.web.app/payment-return.html>
- Payment creation, status checking, signed callback and scheduled reservation-expiry functions.
- Checkout quote/order functions and unpaid-order guards in preparation, rider acceptance and job synchronization.
- Account cleanup functions with payment-owner anonymisation.

Activation uses the ignored `functions/.env.bloom-and-bunch-kl` with `TOYYIBPAY_ENABLED=true` and `STORE_ORDER_MODE=toyyibpay_sandbox`. The secret remains in Firebase Secret Manager, outside the Flutter build and repository. Keep these environment settings when redeploying. Checked-in demo defaults are retained for isolated testing.

## Verification

- 20 focused backend, gateway and policy tests passed against local demo emulators, including free-delivery checkout with no coverage/capacity setup.
- Production-connected Flutter web build and its key/Maps/notification configuration validation passed.
- Deployment reported all selected Functions and Hosting releases successful.
- Runtime metadata confirmed checkout, payment and fulfillment-guard functions are ACTIVE with sandbox enabled; payment functions reference the expected Secret Manager secret.
- Public payment creation/status endpoints rejected unauthenticated calls with HTTP 401.
- The callback rejected a forged signature with HTTP 403.
- The hosted payment return page returned HTTP 200 with the expected content.

These checks do not establish that a bank simulation has succeeded. The first authenticated checkout and successful/failed/pending bank simulations still need to be exercised with the user's account.

## Test now

1. Open the website and refresh it, or restart the current Flutter app with `flutter run`.
2. Sign in as a customer and start a new flower checkout. Refresh an old cart's summary if prompted.
3. Select the saved address, review the item-only total, and choose `Continue to sandbox payment`.
4. On Order payment, choose `Continue to payment`, then `Open ToyyibPay sandbox`.
5. Use the sandbox bank simulator and continue back to the merchant. On an updated native app the return page opens the app; if the browser blocks automatic opening, tap `Open app`. Website customers can return to the original tab and choose `Check payment status`.
6. The native return checks the backend and opens order tracking after successful verification. It unlocks preparation/dispatch and covers every delivery in a mixed checkout with one payment. A pending return retries briefly and retains a manual status button.

Failed/pending attempts must not unlock fulfillment. Retry the same bill; do not create another checkout to retry an uncertain payment. See the setup guide for expiry and manual-review limits.

## Payer contact and profile editor fixes

Sign-up and Google sign-in can leave the profile phone empty. Payment status now tells the UI when a payer number is required, and the payment screen collects it directly. Local and +60 formatting are normalized before bill creation. Missing contact validation occurs before claiming a bill, so the same unpaid order can be retried. The saved profile and recipient phone are not silently changed.

The profile phone editor also had a separate closing-animation crash: its caller disposed the text controller as soon as the dialog future completed, before the route finished animating. The controller now belongs to the dialog's State and is disposed when that route is actually removed. Saving disables repeat actions, shows errors inside the dialog and retains edits for retry. An isolated reproduction failed with the old code; all five dedicated dialog regressions and the full 95-test Flutter suite pass with the fix.

An Android app already running an older build must be stopped and restarted from the updated code, or rebuilt/reinstalled. Publishing the website does not update an installed native app.

## Native payment return

The merchant return page now hands the payment ID to the installed app. Android uses a package-targeted browser intent and the registered `bloombunch://payment-return` scheme. It attempts automatic opening and keeps an **Open app** button for browsers requiring a tap. A browser fallback parameter prevents redirect loops. Website customers retain the original-tab/manual-check path. iOS URL-scheme configuration is included but has not been built or tested on an Apple device.

The link listener starts before Firebase setup, queues cold links until authentication, and waits for the sign-in route to finish before opening payment. Browser success parameters are ignored. Only an owned backend-verified `paid` response opens order tracking, including all orders covered by the checkout. Pending returns check briefly again; failures retain the retry control.

Validation: the full Flutter suite passed 100 tests, followed by all 11 focused payment/link tests after the final sign-in timing fix. Four JavaScript return-page tests passed; Flutter analysis reported no issues. Android debug builds and configured web builds succeeded. A test link with a nonexistent payment ID resolved to the installed Android MainActivity on a connected phone (cold start, status `ok`); no order, bill, or payment was created for this smoke test. The final Android build was installed with `adb install -r`, preserving app data. A new bank simulation remains the acceptance test for provider-to-browser-to-app behavior on the user's chosen browser.

Hosting deployment completed successfully. Public checks confirmed HTTP 200 for the return page and script, and matching SHA-256 hashes for the hosted return script and Flutter app against the tested build. Existing unauthenticated payment calls still return 401, and a forged callback returns 403. The final installed Android build handled a second cold return link without logged Flutter/Android runtime errors; its normal launcher screen was then reopened.

## Successful bank payments stuck pending: reference mismatch

Read-only inspection found two RM25.00 provider transactions with successful status `1` while their Firestore payments/orders remained pending. Both provider references were exactly the first 50 characters of our 64-character payment IDs. The adapter required all 64 characters, and callbacks also tried to use the shortened reference as a Firestore document ID. Short mock IDs in earlier tests did not expose the mismatch.

The adapter now sends an explicit 50-character provider reference while retaining the full internal ID. Verification checks the exact expected reference, successful status, amount and invoice for the server-stored bill. Signed callbacks resolve one matching bill and reject duplicate mappings or a mismatched reference. New return URLs carry the full internal ID separately. A regression using actual SHA256-length IDs failed before the fix and passed afterward. All 25 focused backend/emulator tests and five return-script tests passed, including both manual and callback settlement, forged/mismatched data, duplicate callbacks/mappings, ownership, expiry and inventory reservation protections. No Flutter code or web-versus-native checkout selection was changed for this fix.

All four payment Functions and Hosting were deployed successfully. Reconciliation re-read ToyyibPay transactions and used the deployed signed-callback handler; no payment/order fields were edited directly. The latest RM25.00 order (`EwgPtQ9sWRohLrCan4jt`) is now `paymentStatus: paid` and remains `Ready for Delivery`. An older successful RM25.00 order (`GJxJhw77d9Tw2NJHjEzn`) had already been cancelled by expiry before the new deployment; its payment is now `needs_review`, retaining the verified transaction without fulfilling a cancelled order or reusing released stock. Another bank transaction still reports provider status `4`, so its order remains pending. An earlier unpaid checkout remains cancelled/expired. Public smoke checks still reject unauthenticated calls (401) and forged callbacks (403), and the published return script matches the tested source.
