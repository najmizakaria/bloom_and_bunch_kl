# Customer calls to florist and assigned rider

Order tracking offers **Call Florist** and **Call Rider** with explicit recipient labels. Each opens a contact dialog showing the name and a selectable phone number. The dialog's Call button opens the device's phone dialer; it does not place a call automatically. If a browser/device has no dialer, the number remains available to copy.

- Before assignment, Call Rider is disabled and a small note says **Rider not assigned yet**.
- Rider calling is available for `Out for Delivery` and `Awaiting Customer Confirmation`.
- Completed, cancelled and legacy delivered orders retain florist support without rider calling.
- A lookup failure retains the florist option and permits retry. A changed assignment during lookup discards the previous rider's result.
- The profile's former **Call Store** label is now **Call Florist**.

## Delivery contact source and validation

The approved `rider_applications/{riderId}.phone` is the delivery contact. This avoids silently overwriting or depending on the rider's general profile phone, which can differ or be blank. Application submission validates Malaysian local/international formats and stores canonical `+60` format. Admin approval independently validates and normalizes that application number before granting the rider role. Existing approved applications with valid local or international formatting remain usable without migration. An invalid/missing approved contact returns a generic unavailable message and the customer can call the florist. These checks validate format, not phone ownership; OTP verification is not implemented.

Application details remain private under existing Firestore rules. There are no new public profile reads and no rider phone copied into orders, delivery jobs or analytics.

## Backend access

`getAssignedRiderContact` is an authenticated callable in `asia-southeast1`. It accepts only the order ID as its lookup key and uses a read transaction to verify:

1. The authenticated account is the order's owning customer and is not being deleted.
2. The order has an assigned rider and is in an allowed active state.
3. The current assigned account still has the rider role, is not being deleted, and has an approved application with a valid contact.

It returns only the approved rider name and normalized phone. Arbitrary client-supplied rider IDs have no effect. Missing or foreign orders return permission denied; inactive/unavailable contacts return failed precondition. No Firestore rule or index changes are required.

Deploy `getAssignedRiderContact` and the updated `reviewRiderApplication` before publishing the matching client:

```powershell
firebase deploy --only "functions:orders:getAssignedRiderContact,functions:orders:reviewRiderApplication" --project bloom-and-bunch-kl --non-interactive
```

## Acceptance check

Use two customer accounts and an approved rider with a valid application phone. Before acceptance, verify the unassigned note. After the rider accepts a paid ready order, the owning customer can open that rider's contact and phone dialer. Another customer must not obtain the contact through the callable. After customer receipt confirmation or cancellation, rider contact lookup must fail and the rider button must disappear. Verify the no-dialer fallback on the website. Real calls are initiated by the user in the phone dialer; automated tests use fake launchers and do not place calls.

The local-only demo seed includes an approved contact for `demo_rider`; its existing emulator/project guards remain in place. Seed only a fresh local demo session, since reseeding resets demo inventory and fixtures.

## Verification and deployment

On 16 October 2026, 30 backend/emulator tests passed for contact ownership, active states, reassignment, phone validation, approval, role checks, assignment races and existing Firestore protections. Seven focused Flutter contact tests passed, including no-dialer fallback and an assignment change during lookup; existing application/layout regressions also passed. Flutter analysis reported no issues. Android and configured web builds succeeded. The two selected Functions and Hosting were deployed, and the updated Android app was installed on the connected phone without clearing app data. Public checks confirmed that unauthenticated contact lookup returns 401 and the hosted Flutter bundle matches the tested build. Automated verification did not place a real phone call.
