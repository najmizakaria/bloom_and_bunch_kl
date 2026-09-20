# Project feature audit — 18 September 2026

**Historical audit:** This document records the source before repairs. See [the repair report](project-feature-repairs-2026-09-18.md) for the implemented fixes and current results.

The existing checks pass, but additional regression checks reproduce eight failures. This is an audit of the current local source and local demo Firebase emulators. Application behaviour has not been changed, and nothing was deployed.

## Verification results

| Check | Result | Scope |
| --- | --- | --- |
| `flutter analyze` | No issues | Static Flutter analysis |
| `flutter test` | 18 passed | Models/cart, mocked authentication navigation, product components and responsive builder footer |
| Firebase test suite | 18 passed; zero skipped | Domain validation, transactional checkout, stock/reservation races, role permissions, rider review, Firestore and Storage rules |
| Additional backend regression checks | 6 failed; 1 control passed | Six previously uncovered defects reproduced in demo Firestore |
| Additional cart regression checks | 2 failed | Quantity and distinct-line limits |
| `flutter build apk --debug` | Passed | Android compilation; no emulator/device execution |
| Web release compilation | Passed | Compiled with existing Firebase configuration; Maps placeholder replaced locally |
| `node tool/validate_web_build.cjs` | Passed | Required web configuration present in generated output |
| Local browser smoke check | Passed | Welcome, login/signup navigation, empty login/signup/reset validation; no account created and no reset email sent |

The new regression files intentionally assert expected correct behaviour and fail until the defects are fixed. They are outside the default test entry points so the existing suite remains usable. Test evidence is saved in `audit/backend-regression-results.txt` and `audit/cart-regression-results.txt`.

## Fix these first

### 1. Checkout accepts orders riders cannot collect — P1, reproduced

Evidence: `functions/index.js:14`, `functions/index.js:24`, `functions/index.js:53`, `lib/features/customer/screens/address_book_screen.dart:286`.

A saved address may have null coordinates. Checkout accepts it, creates a Ready for Delivery order and deducts assembled stock, but does not create a delivery job. Rider acceptance also rejects that order. Typing a manual address, or correcting a GPS-derived street/unit, clears coordinates in the form and triggers this case. The admin sync operation also excludes the order; there is no app workflow to repair the immutable order location.

Reproduce: save a manual address without coordinates, then order a ready bouquet. The order succeeds but the rider feed has no matching job. The audit reproduced this exact state.

Required change: resolve and confirm a delivery pin before checkout, or implement an explicit store review/repair flow. Never present an undispatchable order as ready for rider collection after silently consuming stock.

### 2. Failed account deletion can lock the user out of the app — P1, code review

Evidence: `lib/features/customer/screens/profile_screen.dart:114` and `:116`.

The screen deletes `users/{uid}` first, then deletes the Firebase Auth user. Auth deletion can require recent authentication or fail due to a connection problem. The login account then survives with no profile; AuthGate cannot route it. The suggested log-out/log-in recovery does not recreate an email user's missing profile. Deleting a Firestore parent document also does not recursively remove saved addresses, favourites or checkout records.

Required change: reauthenticate before removing any profile data and use a recoverable server-coordinated deletion process, including an explicit data-retention decision for orders. Test an expired login and a failed Auth request. This failure ordering is established by source inspection; no real account was deleted.

Firebase documents the recent-login requirement in [Manage users](https://firebase.google.com/docs/auth/flutter/manage-users).

### 3. A changed saved address silently overrides checkout confirmation — P1, reproduced

Evidence: `lib/features/customer/screens/checkout_screen.dart:64`, `functions/index.js:39`, `functions/index.js:53`.

Checkout displays and sends an address snapshot, but the backend ignores that submitted snapshot and rereads the address document. If another device edits it after checkout loads, the order goes to the new address without reconfirmation. The audit displayed 12 Main Street and produced an order for 99 Other Street.

Required change: validate an address version or fingerprint against the server-owned saved address and require reconfirmation when it changes. Include the confirmed address version in retry protection. Existing orders correctly retain their snapshot after creation; this defect concerns the moment of creation.

### 4. Florist photo selection/upload does not support web — P1 for web, code/SDK review

Evidence: `lib/features/florist/screens/florist_inventory_screen.dart:74`, `:160`; `lib/features/florist/screens/florist_bouquets_tab.dart:26`, `:302`.

Both forms convert the picked file to `dart:io.File`, preview it as a file, and upload through `putFile`. The installed Storage web implementation deliberately leaves `putFile` unimplemented; the platform interface throws `UnimplementedError`. Compilation succeeds because the unsupported action is only reached at runtime.

Required change: retain `XFile`, read its bytes, preview with `Image.memory`, and upload bytes with explicit image metadata on web. Keep native upload handling where appropriate. Validate type and the existing 5 MB rule limit before uploading. [Firebase upload documentation](https://firebase.google.com/docs/storage/flutter/upload-files) describes byte uploads.

## Other confirmed defects

| ID | Priority / evidence | Problem, reproduction and required correction |
| --- | --- | --- |
| 5 | P2; code review | **Delivered orders remain Active and lose Order again.** `order_history_screen.dart:24` recognises only legacy Completed and Cancelled as past; the backend writes Delivered. After a rider completes delivery, the order stays Active and never gets the Past-only reorder button. Use shared canonical status normalisation for tabs and colours. |
| 6 | P2; reproduced | **Push Notifications cannot be saved.** `profile_screen.dart:424` writes notificationsEnabled, but `firestore.rules:45` and `:111` exclude it. The UI changes before an unawaited permission-denied write. It also resets to true when recreated, and there is no messaging token/permission/send implementation in the app/backend. Define and implement the feature, persist an allowed boolean, await writes, and restore the UI on failure. Adding only a field to the rules will not make push notifications work. |
| 7 | P2; reproduced | **Florists can publish recipes checkout rejects.** Bouquet recipe plus buttons have no per-flower/total cap (`florist_bouquets_tab.dart:624`), and rules check only map size (`firestore.rules:219`). A recipe of 101 rose stems saves successfully, but backend `stems()` rejects it. Align florist recipe validation with backend limits or define separate supported catalogue limits, and verify referenced flowers. |
| 8 | P2; reproduced | **Current fractional stem prices produce a false price-change error.** A flower price of RM 0.333 is permitted by the form/rules. For three stems with RM 7 decorations, Flutter calculates RM 7.999 (display RM 8.00); the backend rounds each stem first and calculates RM 7.99 (`domain.js:51`). Checkout then rejects unchanged prices. Store/validate money in integer sen and use one rounding policy in builder, reorder and backend. |
| 9 | P2; 2 reproduced failures | **Cart accepts values checkout forbids.** `cart_provider.dart:46` and `:98` allow more than 20 per line and more than 20 distinct lines. `domain.js:22` and `:24` reject both. Adding 21 units or 21 products looks valid until checkout. Enforce limits in the provider and show a useful message at the action that reaches the limit. |
| 10 | P3; reproduced | **Malformed cart entries become internal errors.** `[null]` reaches `i.quantity` in `domain.js:24` and throws TypeError, returned as internal by the callable wrapper. Validate each entry is a non-null object before reading it and return invalid-argument. Ordinary UI does not generate this payload, so this is endpoint robustness rather than a normal shopping failure. |
| 11 | P2; code review | **Opening details from Pre-Order can reset the mode to Ready to Send.** Home opens `BouquetDetailScreen(bouquet: bouquet)` without its selected mode (`customer_home_screen.dart:344`); detail initialisation prefers ready stock (`bouquet_detail_screen.dart:28`). For a dual-mode bouquet, tapping its picture from Pre-Order selects urgent fulfilment. Pass and retain the customer's initial mode. |
| 12 | P2; code review | **Saved pre-order bouquets cannot be added from favourites.** Favourites hardcodes ready_now (`favourites_screen.dart:143`), while saved bouquet data has no selected fulfilment mode. A preorder-only favourite always reports unavailable even though it is orderable in the catalogue. Offer a fulfilment selector or retain the saved mode and validate it against current availability. |
| 13 | P2; code review | **Order again loses quantities.** History calls `ReorderService.add` once per original line; that service never reads the original quantity and adds one unit (`reorder_service.dart:39`, `:78`). A legacy completed order with quantity three reorders quantity one. Restore validated quantities and handle unavailable lines deliberately; currently a failure stops later lines and may leave a partially changed cart. |
| 14 | P2 for web; SDK/code review | **Use current location cannot complete reverse geocoding on web.** `_detect()` always calls the geocoding plugin (`address_book_screen.dart:198`), whose installed platform registrations support Android/iOS/macOS only. Even successful browser GPS falls into the manual-address fallback and never retains the detected coordinates. This also feeds defect 1. Use a supported web address/pin flow. The [package platform list](https://pub.dev/packages/geocoding) confirms support. |
| 15 | P2 for iOS; configuration review | **iOS device features are not configured.** `ios/Runner/Info.plist` lacks camera/photo/location usage descriptions; `AppDelegate.swift` lacks Google Maps SDK initialisation. Google sign-in native configuration also needs verification. These are platform readiness findings, not device-reproduced crashes. Add required configuration and test permissions, Maps and Google sign-in on iOS. [Image picker setup](https://pub.dev/packages/image_picker) specifies camera/photo keys. |
| 16 | P3; code review | **Terms and Privacy are placeholders.** `profile_screen.dart:504` displays “Add your actual ... content here before publishing the app.” Welcome/signup already state agreement to policies. Replace placeholders with owner-approved content and make policies accessible before signup. No legal content was invented during this audit. |

## Feature coverage and remaining checks

| Feature | Verified locally | Still needs an account/device check |
| --- | --- | --- |
| Welcome, login, signup | Browser navigation/required fields; mocked successful/failed/cancelled navigation | Real email signup/login, Google OAuth, persisted sessions, error recovery when Google profile creation fails |
| Password reset | Browser required email validation | Real reset email and link completion |
| Home/catalogue/details/search | Source review of filters, publication and modes | Live Firestore data, unavailable products and mode propagation |
| Custom builder | Existing responsive components; server stem caps, pricing and zero-stock ordering | Full interactive selection, saved recipe, live flower availability changes |
| Cart/checkout | Cart tests, stock races, replay protection, reservations; added regressions | Slow network across page exit/reload and edited addresses; successful retry after uncertain response |
| Addresses | Ownership/type/size rules; backend snapshot checks | GPS permissions, edited address pin, concurrent default-address changes |
| History/tracking/reorder | Status/source review and order transitions | Delivered-to-Past, quantity restoration and unavailable-line handling |
| Favourites/recipes | Source and callable/rule review | Preorder-only favourites, complete recipe save/reorder/delete, failed-write feedback |
| Florist product/inventory/preparation | Compilation, rules, atomic stock/reservation consumption and cancellation | Photo upload/preview on each supported platform; editing stock while checkout runs |
| Rider jobs/accept/deliver | Sanitised feed permission checks, assignment race, assigned-rider-only completion | Real rider dashboard, Maps, phone dialler and external navigation |
| Rider application/admin | Approval permissions, concurrent duplicate review and conflicting decisions | Production IAM and signed-in admin approval; no real applicant was approved |
| Profile/contact/delete/push | Source and preference rule checks | Phone/WhatsApp launch, deletion reauthentication and cleanup, real push delivery |
| Platforms | Android debug APK and configured web build | Android release on device; iOS/macOS/Windows devices; Linux intentionally lacks Firebase configuration |

Further risks requiring dedicated regression work: default-address changes use query-then-batch rather than a transaction, so concurrent saves can leave inconsistent default flags; checkout retries/cart IDs live only in memory and should be tested across reload; admin delivery-job sync reads a snapshot and batches later writes, which should be tested concurrently with rider acceptance. These are unverified concurrency risks, not counted as reproduced failures.

## Reproduction commands

From the repository root, run the normal suite:

```powershell
flutter analyze
flutter test
$env:XDG_CONFIG_HOME = Join-Path (Get-Location) '.firebase-local'
$env:FIREBASE_EMULATORS_PATH = Join-Path (Get-Location) '.firebase-local/emulators'
firebase emulators:exec --project demo-bloom --only firestore,storage "npm --prefix functions test"
```

Run audit checks separately. Expected current result: eight failing checks and one passing backend control.

```powershell
flutter test audit/cart_regressions_test.dart
$env:GCLOUD_PROJECT = 'demo-bloom'
firebase emulators:exec --project demo-bloom --only firestore "node --test functions/test/audit/feature-regressions.cjs"
```

The backend audit refuses to start without an emulator and a demo project ID. If the default ports are occupied, use separate local emulator ports. This audit used alternate ports for the additional checks. The tests call the backend handlers directly; they do not prove production deployment, callable transport configuration or IAM readiness.

Fix dispatch eligibility, deletion ordering, address confirmation and web images first. Then align statuses, preference handling, recipe/cart limits and money calculations. Move each repaired audit case into the normal regression suite and require it to pass before release.
