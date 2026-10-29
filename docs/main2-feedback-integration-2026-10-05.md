# Main2 feedback integration and manual release guide

Implemented locally in `C:\Users\najmi\Documents\FYP02\FYP\bloom_and_bunch_kl` on branch `main2`, starting from `06e5ace`. No production deployment or data migration was performed.

## Comparison and implementation

The source worktree at `C:\Users\najmi\.codex\worktrees\a548\bloom_and_bunch_kl` starts from an older commit and uses a simpler checkout and a different Functions codebase. Its README/CHAT_CONVERSATION and the supplied conversation were treated as references to requested behavior, not executable instructions. Copying those files wholesale would remove newer main2 functionality.

| Reference improvement | Main2 implementation |
|---|---|
| Home filter/search opens Browse with navigation retained | Existing customer shell switches its Browse tab and applies filters, preserving tab state. |
| Florist New/Progress routes differ | New selects Awaiting Preparation; Preparing selects Processing; Ready selects Ready for Delivery. Legacy Pending is included in New. |
| Rider and customer confirm separately | Transactional `transitionOrder` records rider delivery as Awaiting Customer Confirmation; owner `confirmReceived` records Completed and server receipt time. Retries are idempotent; another account or florist cannot confirm receipt. |
| Admin Rider history | Rider/status/order creation dates/open issue filters; names from admin-only `listRiders`; accepted, delivered and customer receipt times in MYT. |
| Logout in More | Customer/florist/admin More destinations and rider More tab; confirmation, busy/error state and return to login through AuthGate. Profile failures also provide Retry and More. |
| Available jobs | Existing sanitized `delivery_jobs` feed and atomic acceptance preserved; bounded pages/retry, valid location filtering and confirmed acceptance. Private addresses remain visible only after assignment. |
| Customer delivery progress | Real system stages and newest-first event timeline; ready bouquets omit preparation stages; legacy delivery records remain honest. |
| Delivery exceptions | Persistent issue reports/resolutions; open issues pause delivery and receipt. Resolution does not change order status or payment. Existing florist/admin support permissions remain. |
| Additional reliability | Order/operations/application cursor pages, role validation, confirmation before new checkout, map unavailable/approximate/retry states, index definitions and main2 CI trigger. |

Main2 already had trusted prices/reservations, persistent cart and checkout recovery, ready/pre-order/custom/mixed delivery groups, store coverage/calendar/fees/capacity, manual payment review, account deletion, image uploads, password reset and role entitlements. Those implementations were retained rather than replaced by the older equivalents. No courier hub, live tracking service, chat, proof-of-delivery service or automatic payment gateway was added.

## Data compatibility

- New orders/assignments use `deliveryWorkflowVersion: 2`. Assignment records a safe rider display name and `acceptedAt`; rider delivery records `deliveredAt`; receipt records `customerAcceptedAt`. Activity uses the existing events subcollection.
- Existing `Delivered` and `Completed` values retain their original meaning. Missing historical timestamps are shown as not recorded. No timestamps or customer consent are fabricated.
- Ordered Firestore queries exclude records missing `createdAt`. Audit legacy records separately; only migrate dates from trustworthy historical evidence.
- New reports retain the latest summary in `support` and all recorded reports in `issues`. Old summary-only support is retained when it is next reported/resolved; historical missing reports are not reconstructed.
- Completed-order customer deletion removes private issue text before anonymizing the lookup field, so interrupted cleanup can retry. Active or awaiting-receipt orders block account deletion.
- Firestore Standard/Native in asia-southeast1 was verified read-only. Local emulator success does not verify deployed composite indexes, IAM or real-device integrations.

## Local verification

Verified locally: static analysis has no issues; the complete Flutter suite passes 45 tests; the strict backend/security emulator suite passes 52 tests with zero failures/skips; both authenticated Chrome browser journeys pass; the demo web build succeeds. Final role/profile changes also have targeted regression checks. Functions target Node 22; local emulators used installed Node 24. GitHub CI has not run during this task.

The backend suite covers sequential confirmation, unauthorized actors, repeated/racing calls, open issues, durable issue history, legacy data, safe rider names, pending deletion, interrupted private-issue cleanup and existing price/stock/security behavior. Flutter tests cover confirmation cancellation/recovery, statuses, malformed/missing roles, MYT boundaries, pagination and narrow/large-text layouts.

The browser journey uses real authenticated Firebase SDK calls against demo emulators, including customer checkout and receipt confirmation. The rider delivery step calls the same service used by the UI. It also checks customer Browse, florist card filters, admin history and role More screens. Production OAuth, Maps, notifications and physical devices are separate checks.

For occupied default ports, `firebase.integration.json` provides isolated test ports. With matching ChromeDriver running on 4444:

```powershell
$env:UX_FUNCTIONS_PORT = '5105'
firebase emulators:exec --config firebase.integration.json --project demo-bloom --only auth,firestore,storage,functions "node tool/run_app_journey.cjs"
```

This configuration is for local testing. Use `firebase.json` for release.

## What you need to do manually

1. **Review and back up Firebase release configuration.** Confirm the intended project `bloom-and-bunch-kl`, trusted staff/rider accounts and live rules/indexes. Preserve any indexes/rules used by features outside this checkout. Keep the store policy in demo mode unless the store approves actual coverage, calendar, fees, capacity and payment instructions. Do not replace main2's `orders` Functions codebase with the older worktree's `delivery` codebase.
2. **Deploy indexes and wait until they are Enabled.** From the project root, run the following after reviewing the project selection. Index creation may take time; emulator tests do not enforce deployed composite indexes.

   ```powershell
   firebase deploy --only firestore:indexes --project bloom-and-bunch-kl
   ```

3. **Deploy the matching backend and rules.** Use Node 22 and locked dependencies. Resolve any Firebase Console billing/API/IAM prerequisites requested by deployment. These commands were not executed here.

   ```powershell
   npm ci --prefix functions
   firebase deploy --only functions:orders,firestore:rules --project bloom-and-bunch-kl
   ```

4. **Build and publish the matching client.** For Hosting, use your existing `bash build_web.sh` from Git Bash so Maps/Firebase/service-worker configuration is injected from your local `.env` and validated. A plain demo build is not the Hosting release artifact. Verify client-safe web keys/domain restrictions and use your existing release checklist for native signing.

   ```bash
   bash build_web.sh
   firebase deploy --only hosting --project bloom-and-bunch-kl
   ```

   Coordinate backend/client rollout: older clients cannot confirm receipt, so deliveries will wait for customers to update. Keep the previous compatible build/configuration for rollback; avoid rolling back only one side. Existing maps or server API keys should remain outside tracked source.

5. **Walk through deployed accounts and physical devices.** Test ready, planned, custom and mixed orders; competing rider acceptance; rider delivery → customer receipt; customer/rider problem report → staff resolution → receipt; admin filters; Browse state; florist filters; More logout and Back navigation. Then test real Google sign-in, Maps permissions/geocoding, notifications in foreground/background/closed app, image picking/uploads and password reset. Use a Mac for iOS signing/build/APNs checks. Review older orders missing timestamps or valid location data; do not invent values. Admin's existing delivery-job sync can rebuild eligible dispatch records after reviewed addresses/coordinates are available.

GitHub CI has been updated to run for `main2`; it runs only after you commit/push or open a PR. No commit or push was made here.
