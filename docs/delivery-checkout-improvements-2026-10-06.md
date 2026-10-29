# Checkout and rider delivery changes — 6 October 2026

Implemented in the main2 checkout. No commit, push or production deployment was performed for this revision.

## Customer experience

- New checkout quotes and orders charge only the bouquet subtotal. Delivery fees are zero even if an older policy contains a nonzero fee. Ready and made-to-order bouquets still create separate linked deliveries.
- The checkout button says **Place Order**. Loading and unavailable summaries have clear disabled labels instead of showing a misleading RM 0.00 order total.
- Customer checkout, tracking, legal copy and staff screens use neutral ordering language. Payment confirmation remains separate from order submission; no payment gateway or payment-status migration was added.
- **Previous issue reports** is removed from the order interface. The current issue, store response, reporting and feedback remain available. Historical issue records are retained.
- Previously placed orders and their recorded totals are not rewritten.

## Rider experience and enforcement

- The bottom navigation now uses **Available**, **My Delivery**, **History** and **More**. The short Available label fits the bottom bar; the page heading remains Available Deliveries. Existing back controls remain.
- The list reads canonical orders through an authenticated, approved-rider callable. Only other customers' eligible unassigned orders marked **Ready for Delivery** appear, ordered by creation time, oldest first.
- Pending, Awaiting Preparation and Processing orders stay hidden. An order appears only when the store marks it **Ready for Delivery**. Orders with incomplete delivery addresses or invalid coordinates remain unavailable pending correction.
- A rider's own purchases are excluded using the authenticated UID, including accounts with both customer and rider roles. Direct self-assignment attempts are rejected by the backend.
- The first successful transactional acceptance gets the delivery. Two riders cannot claim one order, and one rider cannot claim two different orders concurrently. Riders can choose among ready orders; sorting does not require them to choose the oldest one.
- One active delivery includes **Out for Delivery** and **Awaiting Customer Confirmation**. The owning customer's receipt confirmation completes the delivery and releases the rider. Open issues block receipt confirmation until store resolution. Existing active assignments also block another acceptance, even if they predate the profile lock.
- The lock is server-controlled. Profile edits and approved role switching continue to work; client creation, replacement and removal of the lock are denied, including administrator client writes.
- Unassigned previews contain order ID, approximate area, status and timing only. Recipient name, phone, precise address, delivery note and coordinates unlock after assignment through existing order access rules.
- The list has refresh, retry and pagination controls. It refreshes every 30 seconds while visible in the foreground, and when returning to the tab or app. Pages contain up to 20 eligible previews with a bounded scan; an owner-only page may offer Next before showing eligible deliveries.

## Validation

The initial revision passed 82 Flutter tests, 62 strict backend/security tests and all five authenticated browser journeys. The subsequent ready-only revision passed all 84 Flutter tests, 63 strict backend/security tests (zero failures or skips), the focused rider browser journey, and clean static analysis. Static analysis reported no issues, the four rider widget regressions passed again after the final navigation adjustment, and the optimized web build succeeded. Detailed results are recorded in `audit/delivery-checkout-results-2026-10-06.json`. Tests use isolated local services and synthetic accounts. An optimized web compilation checks that the application builds; it is not a configured Hosting release artifact.

Native GPS permissions, real notifications, production indexes and an installed Android/iOS app still need verification after release. Local tests do not claim that the updated code is already running in production.

## Apply to the live project

Run from `C:\Users\najmi\Documents\FYP02\FYP\bloom_and_bunch_kl` after reviewing these changes:

```powershell
firebase deploy --only "firestore:indexes,firestore:rules" --project bloom-and-bunch-kl
```

Wait until the new order indexes finish building in the Firebase console. The index definitions cover status/creation-time delivery pagination and rider/status active-order checks, including older active records without creation timestamps.

Then deploy the four affected callable endpoints:

```powershell
firebase deploy --only "functions:orders:listAvailableDeliveries,functions:orders:transitionOrder,functions:orders:quoteCheckout,functions:orders:placeOrder" --project bloom-and-bunch-kl
```

The rules update must accompany the backend lock change so profile edits and role switching continue working during active deliveries. Confirm that all four functions are active in `asia-southeast1` before installing the updated client.

For a connected Android device, run `flutter run` from this checkout, or rebuild and install your normal APK release. Existing installed applications do not receive source/UI changes automatically. For the website, use `tool/build_web.ps1` with the existing private environment configuration before any Hosting release; the verification-only `build/web` output should not be published directly.

After release, use real accounts to verify: customer checkout total equals item subtotal; riders cannot see their own orders; preparation orders remain hidden; one rider accepts a ready order; another rider loses that claim; a rider cannot take another order until customer receipt; profile edits still work during an active delivery; and a receipt-confirmed order moves to History. Do not create synthetic production orders merely to reproduce the local test suite.

## Rider error and card spacing follow-up

A read-only `firebase functions:list --project bloom-and-bunch-kl --json` check on 6 October confirmed that `listAvailableDeliveries` is absent, while `placeOrder`, `quoteCheckout` and `transitionOrder` are active in asia-southeast1. The updated rider screen requires the missing callable, so this is a verified live release blocker. The customer's attached screenshots show older address/checkout screens and do not provide the exact rider error text.

The available-delivery error now refers to the delivery list instead of incorrectly saying that the order service is unavailable. It retains Retry and distinguishes connectivity and rider-access failures. Five targeted rider widget tests passed, including a missing-callable error followed by a successful retry.

Completed History cards, current assigned deliveries and available-delivery cards now have an explicit 12 logical pixel bottom margin. The global theme sets card margins to zero, which previously made adjacent cards touch.

Apply the indexes/rules and four-callable release commands above, then rebuild/install the app for the spacing and error-label changes. No production deployment was performed during this follow-up.

## Ready-only availability

The rider Available tab now shows only orders whose exact stored status is **Ready for Delivery**. Pending, Awaiting Preparation and Processing orders do not appear. The client also hides preparation records returned by an older backend during rollout. Ownership exclusion, oldest-first pagination and the one-active-delivery limit continue to apply. A regression checks that a processing order becomes visible after the florist marks it ready, and that older preparation-phase cursors close without returning preparation orders.

If the initial coordinated release above is already installed, this follow-up requires publishing only the updated list callable, then rebuilding/installing the app:

```powershell
firebase deploy --only "functions:orders:listAvailableDeliveries" --project bloom-and-bunch-kl
```
