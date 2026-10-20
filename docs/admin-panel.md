# Integrated administration

The admin workspace has four destinations: Dashboard, Riders, Staff and Settings.
It uses the existing customer, florist, delivery, payment and support workflows.

## Admin layout

Workspace content is centred within a 1440px content area, with 24px desktop
padding and 16px mobile padding. The overview retains all eleven metrics in a
five-column desktop grid (5 + 5 + 1), with identical card dimensions and 16px
gaps. Smaller widths use three, two or one column; larger text increases the
shared card height to keep labels and values readable.

Rider and staff directories use compact desktop tables and spaced mobile cards.
Delivery history shares the Riders workspace header, wraps its filters, and
shows a compact summary with full IDs available through Copy and the complete
timeline available through View. Pagination scrolls directly after the records.
Role, access, delivery and location badges include text labels; an idle rider is
not labelled offline. A missing phone or recorded timestamp is shown explicitly.
The main navigation remains Dashboard, Riders, Staff and Settings.

## What changed

- Server-authorized, paginated order filters and exact order-ID search. Date
  filters distinguish order creation from payment receipt and use Malaysia time.
- Manual receipts and ToyyibPay sandbox receipts are reported separately using
  `paidAt`. Demo/unpaid records are not revenue. Old payments without a recorded
  receipt date are excluded rather than assigned an invented date.
- Preparation, ready-for-collection, delivery, receipt-confirmation, payment,
  support and rider-application queues link to their existing workflows.
- Admin inventory reuses florist flowers and bouquets. Stock alerts subtract
  reservations from physical stems. Each alert page scans at most 100 flowers;
  its count describes that page, not the entire catalogue.
- Legacy `products` records are preserved. A dashboard notice identifies their
  presence. They are not automatically converted into sellable stock.
- Staff creation uses an admin callable with a retry identifier and durable
  claim. It does not sign out the administrator. Only florist/rider accounts can
  be created here. Administrator accounts are protected from this management UI.
- Staff suspensions are enforced by the callable wrapper, Firestore/Storage role
  checks, Auth account disabling/revocation and the app's role gate. Active rider
  deliveries and florist preparation must be completed before suspension or role
  replacement. Only accounts created through staff management can have their
  primary staff role replaced; existing customer/rider entitlements are retained.
- Rider identities/locations come through admin-authorized callables; private
  `users` profiles remain owner-only. Multi-role riders are included.
- Rider location sharing is opt-in, foreground-only and only available while
  delivering the assigned order. It stops when the app loses foreground focus,
  delivery ends, the rider opts out or the session is disposed. The server
  validates the assignment, rate-limits writes and deletes coordinates when the
  rider marks delivery complete. Locations older than two minutes are stale.
- Admin alert preferences are persisted. Order/support/stock and rider events
  populate the inbox; push additionally requires device permission and the
  shared push preference. Push messages contain no customer contact information.
- Store opening days, cutoff, closures, delivery coverage, capacity and manual
  instructions are validated by the server and used by new checkout quotes.
  Payment mode, fees and gateway credentials remain deployment configuration.
- Staff/access changes, rider decisions, store configuration, payment checks and
  order changes are recorded in backend-only administrative activity records.
- Maps load on demand with a graceful failure state. Local web runs read the
  Maps key supplied with `--dart-define-from-file=.env`.

## Run locally

For the standard demo emulator ports configured in `firebase.json`:

```powershell
firebase emulators:start --only auth,firestore,storage,functions --project demo-bloom
```

In another terminal, populate synthetic data:

```powershell
$env:GCLOUD_PROJECT='demo-bloom'
$env:FIREBASE_AUTH_EMULATOR_HOST='127.0.0.1:9099'
$env:FIRESTORE_EMULATOR_HOST='127.0.0.1:18080'
node tool/seed_demo.cjs
flutter run -d edge --dart-define=APP_ENV=demo --dart-define-from-file=.env
```

The synthetic admin is `admin@demo.bloom.test`, password `DemoPass123!`.
Never use real credentials with the emulators. `APP_ENV=demo` does not contact
the live Firebase database. Emulator ports can be overridden with
`AUTH_EMULATOR_PORT`, `FIRESTORE_EMULATOR_PORT`, `FUNCTIONS_EMULATOR_PORT` and
`STORAGE_EMULATOR_PORT` Dart defines.

## Verify

```powershell
flutter analyze --no-pub
flutter test --no-pub
firebase emulators:exec --only auth,firestore,storage --project demo-bloom "npm --prefix functions run test:emulators"
```

The emulator suite requires a demo project and all three emulator hosts; it
fails if integration/security tests are skipped. New cases cover privileged
access, private profiles, staff retries/suspension, receipt totals, combined
filters/pagination, multi-role riders, active-delivery location validation,
inventory reservations, store validation and protected administrative records.

Manual verification should cover desktop and narrow layouts, staff creation and
login, suspension with an existing session, florist/customer stock changes,
payment verification, order preparation and rider acceptance, location consent,
delivery completion and customer receipt, support resolution, alerts and history.
Provider settlement, native location permission and real push delivery require
staging/device checks; emulators do not establish those external behaviours.

## Deployment

Editing the local implementation does not update the live Firebase project. The new
callables, event handlers, rules and indexes must be deployed together before
using the updated client against the live project. Confirm the deployed database
edition and staging results before release. The existing app uses the native
Firestore SDK and the local verification uses the Standard edition emulator.

A release uses an authenticated Firebase CLI session:

```powershell
firebase deploy --project bloom-and-bunch-kl --only functions:orders --non-interactive --force
firebase deploy --project bloom-and-bunch-kl --only firestore:rules,firestore:indexes,storage --non-interactive
```

The functions command accepts retry policies for the admin event handlers. Check
the function diff before using `--force`, because it also accepts removal of
functions that are absent from the local codebase. Reauthenticate with
`firebase login --reauth` only when the CLI session has expired.

The approved production admin deployment was completed on 20 October 2026.
Missing callables previously appeared in Flutter web as `internal [0]`. The
admin client now displays readable connection and access guidance with Retry.
The sales aggregation index includes `orderMode`, `paymentStatus`, `paidAt` and
`totalAmount`; the summed field must be indexed as well as the filters.

Wait for the added indexes to finish building. Then run the normal web build and
validation process (`powershell -File tool/build_web.ps1`) before any Hosting
deployment. A plain `flutter run -d edge` is insufficient for production config;
use `flutter run -d edge --dart-define-from-file=.env` for local production-mode
debugging.

Do not widen profile rules to solve rider-directory errors. The corresponding
admin callable and its deployment are the intended access path.
