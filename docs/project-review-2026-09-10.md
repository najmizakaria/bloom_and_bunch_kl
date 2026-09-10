# Project review — 10 September 2026

## Changes

- Email login now clears the authentication pages immediately after success; signup and Google login/signup have navigation regression coverage. Cancelled Google sign-in stays on the form.
- Google initialization is awaited once, with retry after initialization failure. Firebase sign-out still runs if Google sign-out fails.
- AuthGate retains its auth/profile streams and displays retry/sign-out actions for unavailable profiles instead of an endless spinner.
- Home retains its bouquet subscription when changing Ready to Send / Pre-Order. Browse and Orders retain subscriptions while filtering too.
- Removed the urgency/planning card from Home.
- Added a cart button and item badge to Orders.
- Applied brown, white and neutral brown surface colors across customer, florist, rider and admin screens. Status labels/icons remain visible.
- Updated WhatsApp/phone to 60148376919 and the store address to Unit G2, StreetMall Cyberjaya, Cyberjaya, 63000 Cyberjaya, Selangor.
- Login/signup footers wrap to avoid horizontal overflow.
- Vehicle choices and Firestore rules already restrict applications to Motorcycle and Car; Bicycle was already absent.

## Rider approval investigation

Deployed reviewRiderApplication logs on 9 September at 10:28–10:29 UTC show Firestore PERMISSION_DENIED after successful authentication. This was a server identity permission problem. The current runtime account, 467512389115-compute@developer.gserviceaccount.com, now has roles/datastore.user. Later logged calls had no corresponding error entries. No IAM changes were needed or made during this review.

Local emulator tests pass for approval, administrator-only access, concurrent duplicate approvals, conflicting decisions and unauthenticated calls. No real pending rider application was approved as a test. A fresh signed-in admin/device check is still needed to confirm the reported live scenario end to end.

## Verification

- Flutter analysis: no issues in the final source.
- Flutter tests: 11 passed, including five new authentication navigation tests.
- Firebase emulator suite: all 18 passed; none skipped. Coverage includes checkout stock races, reservations, cancellation, delivery assignment, rider review, Firestore and Storage access rules.
- Corrected the Storage test project ID to demo-bloom so Storage role checks use the same emulated database as the test data.
- Release web compilation and Wasm dry-run compilation passed.
- Git diff whitespace check passed.

Changes are local; no deployment was performed. Real Google account/device authentication, phone/WhatsApp launching and production rider approval were not exercised interactively.

## Content still needing owner input

The Profile Terms of Use and Privacy Policy dialogs still contain placeholder text. Final policy content was not supplied, so it has not been invented as part of this bug fix.
