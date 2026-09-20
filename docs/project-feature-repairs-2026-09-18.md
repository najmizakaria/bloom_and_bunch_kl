# Feature repairs — 18–19 September 2026

The known audit defects have been repaired in local source. All eight previously failing regressions are included in the passing normal suites. Nothing has been deployed and no production account, order or stock was changed.

## Changes against the original audit

| Audit ID | Implemented behavior | Verification |
| --- | --- | --- |
| 1 | Checkout requires a usable delivery pin before creating an order or deducting stock. The address form supports typed-address geocoding and a draggable/tappable entrance pin. | Backend regression verifies stock remains unchanged for missing pins. Valid checkout creates the rider job. Device/map permission checks remain. |
| 2 | Deletion requires fresh reauthentication, refuses active orders/deliveries, records a resumable job, deletes Auth first, then recursively cleans profile subcollections and device registrations. Historical orders are anonymised. | Demo Auth failure/retry, expired identity, active-order rejection, recursive cleanup and rule lockout checks pass. Local cart deletion is tested, including late sign-out. |
| 3 | The backend compares the confirmed address snapshot with the saved address and includes it in retry fingerprints. | Changed-address regression passes. |
| 4 | Both florist forms preview bytes and upload with putData and actual JPEG/PNG/WebP metadata, enforcing the 5 MB limit. | Image byte/type/size tests and web compilation pass. Real picker/upload still needs a signed-in device/browser check. |
| 5 | Shared status normalisation places Delivered, legacy Completed and Cancelled in Past. | Status tests pass; delivered orders expose the existing reorder UI. |
| 6 | Notification preferences are awaited and restored from the profile. Permission/token registration, token refresh, sign-out cleanup, private device ownership, status messages and event retry/deduplication are implemented. Payloads carry account scope. | Server preference, opt-out, ownership, expired-token and repeated-event tests pass with a mocked sender. Live FCM/APNs transport is unverified. |
| 7 | Bouquet save validates 30 flower types, 100 stems per type, 150 total, referenced flowers and stale ready stock. The form and rules enforce compatible caps. Rule evaluation stays within Firestore's expression budget. | Valid, excessive-total, invalid-type and 30/31-type rule checks; server role/recipe/stale-stock tests pass. |
| 8 | Complete custom bouquets round once; cart totals use integer sen. Builder, reorder and backend share that policy. | Fractional stem checkout and custom reorder tests pass. |
| 9 | The cart enforces 20 lines and 20 units per line; UI callers show rejection rather than false success. | Cart boundary tests and widget feedback regression pass. |
| 10 | Non-object/null cart entries return invalid-argument. | Backend malformed-entry regression passes. |
| 11 | Home passes its selected fulfillment mode into details; details retain a supported Pre-Order preference. | Dual-mode detail widget regression passes. |
| 12 | Saved bouquets open current details with fulfillment selection rather than hardcoding ready_now. | Pre-order-only detail/add widget regression passes. |
| 13 | Reordering preserves original quantities, current prices and mode; history attempts each line and reports partial availability. | Ready/pre-order and fractional custom quantity regressions pass. |
| 14 | Web geocoding uses Maps JS; native platforms use the installed plugin. Reverse-geocoding failure retains the GPS fix. Editing a street requires a new pin. | Web release compiles; real GPS/geocoder permissions remain unverified. |
| 15 | iOS usage descriptions, Maps initialisation, Google sign-in build keys, config retrieval and a configuration/build script are added. Missing keys block configuration instead of producing an apparently ready iOS build. | Firebase iOS config retrieved and parsed locally; the configuration guard and OAuth-ID extraction were verified with mocked settings. MAPS_API_KEY_IOS is absent; no Mac/iOS device build was possible here. |
| 16 | Readable service/data-use pages replace placeholders and are linked before signup. They describe current behavior and existing store contact information. | Pre-auth policy widget regression passes. Owner must approve business-specific payment/cancellation/refund terms. |

Additional fixes: address defaults use transactions with a shared profile lock; direct client address writes/default-pointer changes are denied. Home address selection persists as the checkout default. Stock edits detect concurrent changes. Cart contents, quantities, checkout IDs and uncertain checkout requests survive restart under separate user scopes. Uncertain retries freeze edits until confirmation; sign-in changes abort old checkout/reorder work and close private pushed routes. A widget regression verifies both account switches and sign-out. Admin job synchronization rechecks each order transactionally, preventing stale jobs after rider acceptance, and removes legacy jobs for assigned or missing orders. Checkout, rider transitions and recipe saves also write the shared profile lock; concurrent-deletion tests prove that new active orders/deliveries retain their account and private recipes cannot be orphaned. Explicit two-field active-order indexes support the deletion queries without requiring a legacy createdAt field. Failed Google profile creation signs out rather than leaving a signed-in unroutable session. Phone and favourites writes have awaited error feedback.

## Validation

| Check | Result |
| --- | --- |
| Flutter analysis | No issues |
| Flutter tests | 36 passed |
| Backend/domain/Auth/Firestore/Storage tests | 38 passed, zero skipped |
| Android debug APK | Compiled; device execution unverified |
| Configured web release and validator | Compiled and validated |

Evidence is in audit/repair-analysis-results.txt, audit/repair-flutter-results.txt, audit/repair-backend-results.txt, audit/repair-android-results.txt and audit/repair-web-results.txt. Initial failure evidence is retained separately. Backend handlers are tested directly; production callable transport and deployment permissions are not established by these tests. Notification sending is mocked: no live push was sent.

The Java Storage rules runtime sometimes prints a null-pointer error while the emulator is shutting down, after all assertions and a successful script exit. Leftover audit emulator processes are cleaned up separately. This is a local tooling shutdown problem, not an application assertion failure.

## Release work requiring external configuration or review

1. Deploy the updated Functions, Firestore rules and indexes before distributing the matching client. New address, product, deletion and notification callables must exist together with the client. Rules alone would prevent address writes by older clients. Coordinate that release; existing older clients need upgrading.
2. Set MAPS_API_KEY_IOS in the ignored .env using a key enabled/restricted for the existing iOS bundle. Then run node tool/configure_ios.cjs or bash tool/build_ios.sh on a Mac. OAuth IDs are read from the ignored GoogleService-Info.plist, or explicit .env overrides. Generated AppKeys.xcconfig is ignored and required by Debug/Release configurations.
3. Verify Apple signing, Push Notifications/background remote notification capabilities and APNs credentials before real iOS messaging tests. For web push, provide the project's public FCM_VAPID_KEY_WEB if required by the browser/push service. Firebase documents these platform requirements in [Flutter FCM setup](https://firebase.google.com/docs/cloud-messaging/flutter/get-started).
4. Owner review of the factual policy pages is required before release; the app has no automated payment/refund workflow and the store's full business terms were not supplied.
5. Test real Android/iOS/browser permissions, image picking/upload, Maps, Google OAuth and background push delivery. Compilation and mocks cannot prove those integrations. Previously created orders with missing coordinates still require store review; no production data migration was performed.

Firestore rules are a tested prototype enforcing ownership, approved roles, deletion locks, bounded recipe/profile schemas and server-coordinated writes. Review them against the store's actual operational roles before broadly sharing the app.

## Run the repaired checks

From the project root:

~~~powershell
flutter analyze
flutter test
$env:XDG_CONFIG_HOME = Join-Path (Get-Location) '.firebase-local'
$env:FIREBASE_EMULATORS_PATH = Join-Path (Get-Location) '.firebase-local/emulators'
firebase emulators:exec --project demo-bloom --only auth,firestore,storage "npm --prefix functions test"
powershell -NoProfile -File tool/build_web.ps1
flutter build apk --debug
~~~

The two new backend suites refuse to run against a non-demo project. When no emulator is configured, integration cases are skipped; use the full emulator command to obtain the stated zero-skipped result. The initial audit files are historical copies; maintained regressions are under test/ and functions/test/.
