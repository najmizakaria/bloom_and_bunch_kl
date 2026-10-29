# ToyyibPay sandbox payment

Sandbox checkout was activated on the existing Firebase project on 16 October 2026. The checked-in defaults remain demo mode; the ignored backend environment selects sandbox payment for this deployment. The provider adapter is restricted to `https://dev.toyyibpay.com` and FPX simulation. This is not a live-payment integration. See [activation record and test steps](toyyibpay-sandbox-activation-2026-10-16.md).

## Before enabling

1. Register at <https://dev.toyyibpay.com/> and create a category named `Bloom and Bunch Orders`.
2. Obtain the sandbox Category Code and User Secret Key. Do not place the secret in Flutter, the repository, chat, build arguments or client `.env` files.
3. Store the secret using Firebase Secret Manager when ready:

   ```powershell
   firebase functions:secrets:set TOYYIBPAY_SANDBOX_SECRET_KEY --project bloom-and-bunch-kl
   ```

   Enter the key interactively. This command is documented here, not executed by the implementation.

4. Copy `functions/.env.example` to the ignored `functions/.env.bloom-and-bunch-kl`, and set:

   ```dotenv
   TOYYIBPAY_ENABLED=true
   STORE_ORDER_MODE=toyyibpay_sandbox
   TOYYIBPAY_SANDBOX_CATEGORY_CODE=YOUR_SANDBOX_CATEGORY_CODE
   TOYYIBPAY_RETURN_URL=https://YOUR_HOSTING_DOMAIN/payment-return.html
   ```

5. `STORE_ORDER_MODE=toyyibpay_sandbox` selects sandbox checkout for this deployment, overriding the default `mode` in `functions/store-policy.json`. For the current flower-only payment scope, delivery is free: keep `deliveryFeeSen: 0`, `serviceArea: null`, and `dailyDeliveryCapacity: 0`. Sandbox checkout does not require a delivery radius or daily capacity; the existing saved-address/pin step remains. Coverage and capacity limits are optional for sandbox and still apply if configured. The checked-in default remains demo mode for isolated tests and fresh installations.
6. Deploy compatible Functions and the Flutter web/mobile client together. The public `web/payment-return.html` file is copied into web output by Flutter. The callback endpoint is:

   ```text
   https://asia-southeast1-bloom-and-bunch-kl.cloudfunctions.net/toyyibpayCallback
   ```

   The backend supplies this URL when creating each bill. ToyyibPay cannot call a localhost callback; real sandbox callback testing requires the HTTPS endpoint to be deployed. The Blaze plan supports the intended server-side integration; Secret Manager and the scheduled expiry job can incur usage charges.

## Implemented flow

- `placeOrder` retains existing server pricing, saved-address validation and checkout idempotency. It reserves stock and creates one backend-only `payments/{id}` record for the entire checkout, including mixed deliveries.
- The payment ID is a hash of the authenticated customer UID and checkout ID. Orders reference this ID. A client cannot select the payable total or another customer's bill.
- The internal payment ID is 64 hex characters. The sandbox was observed truncating `billExternalReferenceNo` to 50 characters, so bills explicitly use the first 50 characters (200 bits) as the provider reference. Verification accepts only that exact reference or the full original ID, along with the stored bill, successful status, amount and invoice. Signed callbacks resolve the unique stored bill before comparing the reference; duplicate bill mappings fail closed. New bills include the full internal ID as `payment_id` in the merchant return URL so the native handoff does not depend on the shortened provider `order_id`. Older bills without this parameter can still be checked from order details.
- New online orders retain their normal delivery/preparation status but are explicitly held by `paymentStatus`. Callables reject preparation, dispatch, rider acceptance and delivery until paid. Both the sanitized job writer and available-delivery feed exclude unpaid online orders. Florist details and customer tracking show the hold.
- `createToyyibpayPayment` authorizes ownership, claims bill creation transactionally and calls the sandbox API once. Subsequent clicks return the same bill. The customer explicitly opens the resulting payment link, preserving browser popup permission.
- `checkToyyibpayPayment` verifies the provider's transactions. Customers can reopen the screen from order tracking after app/browser restart. Resuming the app also checks status.
- If sign-up or Google sign-in left the profile phone empty or malformed, status checking requests a payer phone on the payment screen. The customer supplies their own contact number; it is normalized for the provider without silently using the recipient's phone or editing the saved profile. Missing/invalid phone validation runs before the bill-creation claim, so correcting the number can retry the same unpaid checkout safely.
- `toyyibpayCallback` requires POST and validates ToyyibPay's documented MD5 signature with a timing-safe comparison. It additionally checks the stored bill code and queries ToyyibPay. Settlement requires a successful transaction with the exact external reference, amount and transaction identifier.
- Settlement updates all checkout orders atomically. Paid status cannot be downgraded by duplicate, pending or failed callbacks. The browser return page never confirms payment using URL query parameters.
- `expireToyyibpayPayments` runs every five minutes. Reservations last 30 minutes, plus a five-minute grace period before cleanup. Before releasing stock for an existing bill, the server deactivates it and checks transactions again. Pending bank transactions retain their stock. Ready stock, planned material reservations and reserved delivery capacity are restored once, and orders become Cancelled.
- Payment records are covered by the existing default-deny Firestore rule. Direct client reads and writes are denied; clients receive only sanitized callable responses. No new client rule or composite index is required. The expiry query uses the automatically indexed `nextCheckAt` field.

## Deliberate recovery limits

ToyyibPay does not document an idempotency key for `createBill`. If the remote call times out or the process fails before saving the result, the system cannot know whether a bill exists. It records `creation_unknown` (or retains `creating` after a crash), prevents another bill and keeps stock reserved for store review. After the deadline the scheduled job marks these `needs_review`. Do not retry by creating another checkout for the same purchase.

An administrator must reconcile uncertain bills with the sandbox dashboard and stored external reference before releasing reservations or attaching a verified bill. An automated dashboard repair tool is not included. A late verified payment after inventory release is marked `needs_review`; cancelled orders are not fulfilled automatically. Refunds and live payments are not implemented. Gateway downtime retains reservations and retries expiry later.

The return page hands a valid `order_id` (our payment ID) to the installed app using `bloombunch://payment-return?payment_id=...`. Android uses a package-targeted browser intent; iOS has the same custom URL scheme configured. Browser policies can require tapping **Open app**. The fallback page never loops and also lets website customers return to their original tab. Missing or malformed payment IDs require opening order details manually.

The native listener starts before Firebase initialization and retains a cold-start link until sign-in. It clears stale payment routes, checks the payment through the authenticated callable, and opens order tracking only after the backend reports `paid`. Pending returns retry status briefly and retain a manual check button; failed, expired, unauthorized and review responses never show success. Neither `status_id` nor `refno` from the browser is trusted. Rebuild/reinstall the mobile app with `flutter run` after this change: hot reload cannot install native intent filters or plugins. iOS configuration needs validation on an Apple device. Keep the sandbox key stable while bills are pending, and keep the payment flag enabled until pending bills are reconciled.

Android link smoke test (replace the example with a real payment ID from an owned checkout for successful verification):

```powershell
adb shell am start -a android.intent.action.VIEW -c android.intent.category.BROWSABLE -d "bloombunch://payment-return?payment_id=YOUR_64_CHARACTER_PAYMENT_ID" com.example.bloom_and_bunch_kl
```

References: [app_links setup](https://pub.dev/packages/app_links), [Flutter plugin deep-link flag](https://docs.flutter.dev/release/breaking-changes/deep-links-flag-change), [Chrome Android intents and user-gesture requirements](https://developer.chrome.com/docs/android/intents).

## Validation and sandbox acceptance

Unit tests mock HTTP responses, callback signatures and transaction data. Firestore emulator tests cover checkout grouping, racing bill creation, ambiguous creation, verified settlement, forged data, ownership, fulfillment gates, expiry, duplicate cleanup, late payment review and direct-client denial. Flutter tests cover allowed sandbox URLs, the payment screen, explicit bank opening, pending-to-paid verification and recovery after errors.

Before calling the integration connected, use real sandbox credentials to verify successful, failed, cancelled and pending bank simulations; callback delivery; return-page behavior; app restart recovery; expiry; and concurrent attempts. Mock and emulator tests cannot establish the behavior of your ToyyibPay account.

Reference: <https://toyyibpay.com/apireference/>.
