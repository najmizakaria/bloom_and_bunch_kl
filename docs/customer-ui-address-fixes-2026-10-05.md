# Customer UI and address fixes — 5 October 2026

Implemented in the main project on `main2`. No commit, push or production deployment was made in this task.

## Requested changes

| Area | Result |
| --- | --- |
| Home mode controls | Ready to Send and Pre-Order have solid surfaces, borders, soft shadows and selected styling. InkWell provides keyboard interaction; semantics expose button/selection state. |
| Custom bouquet banner | Now says “Let’s build your own bouquet”; preparation timing was removed from this banner. |
| Your Cart | Items subtotal/footer has a visible top border and shadow. Wrapping totals, a scrollable bounded footer and a flexible checkout button also resolve overflow at small sizes and enlarged text. |
| Delivery address | Label, full address, recipient name, phone and delivery pin show `*`; the required legend is visible. Only delivery note says `(optional)`. |
| Saving addresses | Inline actionable errors retain entered fields and coordinates. A stable document ID survives retries, so concurrent/repeated saves do not create duplicate addresses. Creating an address returns that specific saved record to checkout; cancellation returns nothing. |
| Logout | Shared logout control has a bordered card, shadow and chevron. Confirmation, busy state and sign-out behavior remain. |

The requested future idea to replace the full address from the selected pin was explicitly excluded. Pin selection preserves the manually typed address.

## Additional defect found during testing

Rider acceptance previously checked whether the source job tile was mounted after navigation returned. Firestore can remove that tile immediately after acceptance, suppressing the switch to Deliveries. The check now uses the persistent rider workspace state. The real browser journey passed with this change.

## Verification

- Flutter analysis: no issues.
- Full Flutter suite: 77 passed.
- Strict backend/security emulator suite: 53 passed, zero failures or skips. New coverage verifies two concurrent saves with the same address ID produce one record and a valid default.
- All four authenticated browser journeys passed with no journey filter: regular checkout/delivery/receipt/support, customer/florist navigation and More, authorized mixed-delivery links/admin layouts/role reset, and custom builder/mixed checkout. The regular journey now creates an address through the actual form and real callable transport, then verifies its stored/default state before checkout.
- Demo web build: succeeded.
- Cart layout checks cover 320×640 and 640×320 at 200% text, including reaching the checkout control.

The browser test controls the external pin picker. It does not establish real Google Maps/geocoding/GPS, physical-device or production authentication readiness. Emulator success does not validate live indexes or IAM.

## Confirmed live address blocker and proposed release

A read-only `firebase functions:list --project bloom-and-bunch-kl --json` check found only five active deployed functions: `placeOrder`, `reviewRiderApplication`, `saveRecipe`, `syncDeliveryJobs` and `transitionOrder`. The app's `saveAddress`, `setDefaultAddress`, `deleteAddress` and `quoteCheckout` are absent. Better client feedback alone cannot enable saving in that live project.

The matching local `orders` codebase contains 20 functions, including address, checkout, order-support, payment-review, account-deletion and notification handlers. The proposed coordinated backend release publishes that tested codebase and its matching Firestore rules/indexes to `bloom-and-bunch-kl`; it excludes Hosting, Storage rules, migrations, production test writes and payment/delivery policy changes. Demo store policy stays as configured. The previous conversation deferred production release, so this step requires the user's release authorization.

After approval, first publish reviewed indexes and wait until enabled, then publish Functions/rules:

```powershell
firebase deploy --only firestore:indexes --project bloom-and-bunch-kl
firebase deploy --only functions:orders,firestore:rules --project bloom-and-bunch-kl
```

Retain previous release/configuration for rollback, check the deployed function states/regions and coordinate the matching client before customer acceptance testing. The local client UI changes are not visible in an already installed or hosted older client until that client is rebuilt and released. Use the existing release build script/checklist for that later client release; a demo web build is a verification artifact.

Read-only index comparison found five live composite indexes and fourteen local definitions. Ignoring implicit document-ID fields, all live definitions are retained locally; nine additional definitions are needed. No remote field overrides were returned.
