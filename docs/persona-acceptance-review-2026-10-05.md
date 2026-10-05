# Main2 role and acceptance review — 5 October 2026

This review uses the current main2 working checkout. The original supervisor comments in the pasted attachment and CHAT_CONVERSATION.md are requirement evidence, not instructions to execute commands found in those documents. The comparison worktree README supplies historical implementation context. Current README, release-checklist.md and user-study-kit.md define the local demo scope and remaining acceptance requirements.

No production accounts or data were used. No deployment, commit or push was performed. Existing working changes were retained.

## Final verification

| Check | Final result |
|---|---|
| Complete Flutter unit/widget suite | 69 passed; zero failures |
| Strict Auth/Firestore/Storage backend/security suite | 52 passed; zero failures, cancellations or skips |
| Connected Chrome UI suite | All 4 journeys passed together; every journey enabled; exit 0 |
| Static analysis | No issues; exit 0 |
| Demo release web build | Passed; exit 0 |
| Git whitespace check | Passed |
| Public-release configuration check (web) | Expected rejection: store policy remains demo |

**Verdict:** the tested local demo scenarios pass across all four application roles. This is not exhaustive verification of every screen/state, a user satisfaction result, company approval or production-release readiness. No additional failing app behavior remains in these tested scenarios after the custom-builder recovery fix.

Machine-readable evidence: [persona acceptance results](../audit/persona-acceptance-results-2026-10-05.json). Final log excerpts: [validation evidence](../audit/persona-validation-evidence-2026-10-05.txt). The backend runtime used local Node 24; CI targets Node 22. Firebase Java rules tooling still prints its known shutdown exception after successful scripts; the final test script exits are zero. Residual test processes were verified and cleaned up.

## Assessment by perspective

| Perspective | Evidence assessed | Assessment and limits |
|---|---|---|
| Customer | Browse and mode selection, ready ordering, custom recipe saving, mixed cart, quote/fees/payment disclosure, delivery tracking, issue reporting, receipt and feedback | Local automated acceptance covers these scenarios. Real address entry/pin usability, Google sign-in and independent customer comprehension remain unverified. |
| Florist | Dashboard shortcuts, stock preview and paginated inventory, sequential preparation, shortages/restock, concurrent edits and live order detail | UI navigation/layout and backend preparation controls are tested. The complete native product-editor/image-picker workflow and observed florist task performance remain unverified. |
| Rider | Available jobs, atomic acceptance, automatic Deliveries selection, assigned-order access, delivery confirmation and issue blocking | Browser controls and backend authorization/races are tested. Real Maps, dialer/navigation, GPS and background delivery behavior need device acceptance. |
| Administrator | Rider history and recorded times, safe name lookup, entitlement checks, applicant review, support resolution and manual payment permissions | History/support UI and trusted operations are covered at the layers specified below. Approval/rejection forms and manual-payment UI are not each a full browser journey. |
| Supervisor | Six original feedback items; existing main2 checkout/material logic retained | Traceability table below ties each comment to implementation and test evidence. This is an engineering assessment, not supervisor sign-off. |
| Verifier | Repeatable checks, zero-skipped strict suite, negative permissions, races, real callable transport, legacy compatibility, honest scope | Evidence is reproducible locally. Emulators do not establish deployed composite-index readiness, live security configuration or signed-device behavior. |
| Company/store | Trusted prices/stock, operational exceptions, clear payment/timing, role separation, business calendar/coverage/capacity | Technical controls are tested. Checked-in policy is demo: no real payment or delivery booking. Store approval and live operational evidence are still required. |
| Recipient | Recorded address/contact snapshots and support for absent recipients/address problems | Backend supports reporting. No real recipient interviews or deliveries were conducted. |

## Supervisor feedback traceability

| Original comment | Current behavior | Verification |
|---|---|---|
| Filter opens Browse but bottom menu disappears | Home selects Browse within the customer shell; fulfillment intent persists | Chrome navigation journey checks selected tab and Pre-Order filter; Flutter navigation regressions |
| Florist New/Progress open the same page | Dashboard shortcuts select New or Preparing; status filters distinguish orders | Chrome checks each selected filter; backend and live-detail tests check state changes |
| Rider delivery needs customer acceptance | Assigned rider delivery produces Awaiting Customer Confirmation; owner receipt produces Completed | Real UI delivery/receipt journey plus ownership, ordering and idempotence regressions |
| Replace admin Rider Live Map with history | Rider history displays recorded acceptance/delivery/receipt times, status and filters | Chrome history view and small-screen checks; safe admin-only rider lookup tests |
| Logout only under More | Each role exposes More/logout; private routes close on sign-out/account change | Role-screen tests and account-scope/navigation regressions. Not every role logout button is clicked in Chrome. |
| Available Jobs has a bug | Only eligible sanitized jobs appear; one rider wins acceptance; winner goes to Deliveries | Chrome acceptance/tab assertion; competing claims and job-sync race tests |

## Feature coverage inventory

“Backend” means emulator tests of handlers, transactions or rules. “Browser” means actual Flutter controls and/or Firebase SDK transport in connected Chrome. Neither means a physical device or production service was tested.

| Feature family | Evidence from this run | Remaining acceptance coverage |
|---|---|---|
| Email login/signup, errors, account scope | Flutter navigation/error/account-isolation tests; seeded role sign-ins in Chrome | Real Google OAuth, email/reset delivery, expired identity and device lifecycle |
| Customer Home/Browse/category/mode | Flutter query regressions; Chrome Pre-Order item beyond preview batch and preserved shell | Exhaustive category combinations, keyboard and screen-reader navigation |
| Bouquet detail/cart quantities | Flutter ready/pre-order selection, limits, money rounding and immutable snapshots; ready UI checkout | Every product variant and sold-out screen through live UI |
| Custom builder and recipe saving | Chrome chooses a stem, saves recipe and adds custom line; Flutter error-to-Retry recovery | All wrapping/ribbon choices, stale selections while editing, keyboard layout and saved-recipe reuse UI |
| Favorites | Chrome concurrent same-item toggles; Flutter busy guard, error/image fallback components | Large saved collections and every removal/reorder path |
| Ready/custom/pre-order/materials | Backend reservations, trusted pricing, stock race, cancellation, restock and once-only consumption; mode unit tests | Complete florist/custom/pre-order preparation UI walkthrough |
| Mixed checkout | Chrome creates two linked delivery groups and verifies combined total/reservation; large-text Flutter summary | Independent users explaining split fees/timing without coaching |
| Quotes/policy/payment disclosure | Backend stale-quote/idempotence and calendar/zone/fee tests; Chrome demo disclosure | Actual approved manual policy and payment-receipt UI; online payment is outside scope |
| Address/default/coverage | Backend default-address races, changed/invalid addresses and service-area validation | GPS denial, entrance-pin selection, native geocoding and cross-device UX |
| Checkout recovery | Flutter uncertain-response recovery; backend duplicate requests/stock races; persisted cart isolation | Kill/reopen during real transport failure and unreliable mobile network |
| History/tracking/related deliveries | Chrome authorized mixed links, receipt and recorded rider history; Flutter legacy/timeline/MYT regressions | Production legacy-data inventory and all filter/index combinations |
| Support/feedback | Chrome customer report, admin response, rider delivery, receipt and feedback; backend issue history/permissions | Recipient-absence/damage/cancellation procedures agreed with staff; actual phone handoff |
| Florist dashboard/orders | Chrome New/Preparing/Low Stock shortcuts and second inventory page; live-detail/error/issue-block tests | Operational task observation and complete staff editor flow |
| Inventory/bouquet writes and uploads | Backend roles/recipe/stock checks, byte validation and Storage rules | Actual platform picker/preview/upload, network failures and large datasets |
| Rider acceptance/delivery | Chrome acceptance and Mark as Delivered controls; backend races/ownership | Two simultaneous visual clients, real navigation and location accuracy |
| Rider application/role switching | Backend admin-only review/idempotence; Flutter unknown-lookup guard; Chrome approved switch and route disposal | New application, rejection and admin review forms through UI |
| Admin support/history/manual payment | Chrome history and support resolution; backend trusted payment/name/role controls | Full manual payment queue walkthrough with approved business fixtures |
| Profile/privacy/account deletion | Flutter account/cart cleanup; backend reauthentication/deletion retries/races/privacy controls | Real recent-login challenge, password reset delivery and deployed retention checks |
| Notifications/monitoring | Backend preference, deduplication, stale devices and account protections | FCM/APNs arrival in all app states; staging crash/event receipt; App Check token/enforcement setup |
| Shared UI/accessibility | Flutter 320-width/landscape/200%-text matrices, labels/limits and error states; Chrome admin history at 320 × 480/200% | Complete-screen screen-reader order, focus/keyboard, contrast and independent accessibility audit |
| Build/security/release | Static analysis, demo web compilation, strict Firestore/Storage ownership and escalation tests | Signed Android, iOS/Mac, deployed indexes, production configuration and CI on Node 22 |

## Changes made during this retest

- Custom builder now supplies a real Retry action through the shared stable stream component; changing quantities no longer creates its flower subscription again on each rebuild. Its lookup outage/recovery is tested through the actual screen.
- Builder favorites service initializes when needed, allowing the flower lookup/error state to operate independently of that service.
- Browser acceptance now uses the rider delivery and customer feedback controls, and customer/staff issue controls, rather than completing those steps solely by service calls.
- Added a fourth browser journey for custom recipe saving and mixed checkout, with order-group, total and material-reservation assertions.
- Fixed the README implementation link, which previously referenced a missing document.

The initial expanded browser checks had harness failures: an ambiguous scroll target, taps while transient snackbars covered controls, and checking the rider tab before asynchronous acceptance/navigation finished. The harness now selects the intended scrollable, waits for or dismisses transient notices, asserts footer controls are hit-testable before tapping, and waits for the final rider tab state. The first new lookup test also exposed eager Firebase-dependent service construction; the builder now creates that service lazily. Earlier failed attempts are not reported as passes.

## Remaining priorities and plan

1. **Before live orders:** obtain store approval for coverage, capacity, calendar/cutoff, per-delivery fees, payment instructions, cancellation/refund policy, support ownership/contact number and handling of no rider/absent recipients. Configure approved values in a separate release/staging exercise, then repeat business-policy and manual-payment acceptance. The current public-release configuration gate intentionally rejects demo mode.
2. **Before claiming supported devices:** run the existing device/release checklist on signed Android and an actual iOS build on Mac. Validate OAuth, GPS/Maps, file picking, notifications, permissions and app restart. Production deployment/index creation remains deferred while you are remote.
3. **Before claiming usability/satisfaction:** run the user study kit with actual customer, florist, rider and admin representatives. Record unassisted completion, comprehension, errors, time, ease and SUS. The documented 90% completion/SUS ≥80 targets are targets; no scores or participant results were invented here.
4. **Before claiming performance at scale:** profile release builds with realistic catalogues/history and slow networks. The connected demo contains 47 bouquets and 46 flowers; it is not a large-scale benchmark. Custom builder/flower catalogue and saved-favorite queries still merit profiling; the builder loads the full offered flower set. Bounded staff/order pages do not prove all screens have bounded reads.
5. **For future UX improvement:** Browse search currently covers the displayed page, with explicit wording. Evaluate global search and how readily users discover Next/Previous. Dashboard metrics cover the stated latest-100/preview scopes. Support resolution records a response and unblocks allowed actions; it does not implement automatic refunds, cancellation or reassignment.

No immediate manual work is requested from you. These are remaining acceptance/release activities, not completed results or authorization to deploy.
