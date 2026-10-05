# Smoothness fixes on main2 — 5 October 2026

Implemented the thirteen findings from the [original audit](smoothness-audit-and-fix-plan-2026-10-05.md) in the existing main2 checkout. Existing checkout, inventory reservations, server authorization and manual-payment behavior are preserved. No deployment, commit or push was performed.

| Finding | Result |
|---|---|
| F1 — historical completion | Order models retain workflow version and recorded customer receipt time. Customer progress, florist details, admin history and the timeline distinguish legacy completion from actual receipt confirmation. No historical timestamp is invented. |
| F2 — stale staff details | Florist and rider routes watch the live order document. Loading, error/retry and unavailable states hide stale actions. External status/support changes update the screen; open issues pause transitions. Subscriptions end when routes close. Local handlers no longer assume a requested status was committed. |
| F3 — responsive layouts | Florist heading/total/items wrap, progress columns flex and action height is intrinsic. Rider map fallback can scroll at large text sizes. Admin filters scroll within a bounded header and dropdown items grow with text. Staff stock controls wrap. |
| F4 — filter intent | All/Ready/Pre-Order are explicit modes shared by Home and Browse. Mode/category/query survive shell navigation; opening a Pre-Order product retains Pre-Order in its details. |
| F5 — preview/query correctness | Category and availability filters run before the server limit, including legacy readyToSend compatibility. Home labels its bounded preview and offers Browse all. Browse uses forward/back cursor pages of 40 with one lookahead, rather than increasing the subscription limit. Search clearly applies to the current page; an empty page does not claim the entire catalogue is empty. New indexes cover category/mode queries. |
| F6 — inventory shortcut | Low Stock and its attention action select Flowers inside the existing Catalogue workspace. |
| F7 — date/statistic honesty | The card says “Created today (MYT), among latest 100” and “of these orders are completed.” It no longer claims to count all completions occurring today. Malaysian dates do not depend on the computer timezone. |
| F8 — bounded subscriptions | Florist workspace tabs initialize on first visit and retain state. Product tabs track visits. Dashboard subscriptions are stable and capped at 100 records, with inventory preview scope shown explicitly. Flowers and staff bouquets use live cursor pages of 20 plus one lookahead and real refresh/retry controls. |
| F9 — recovery | Home, Browse, favourites and inventory have working retry controls. Rider applications show loading/error states and cannot submit while lookup is unknown. Favourites streams remain stable while actions rebuild the UI. |
| F10 — role routes | Approved application and More role switches guard repeated actions, display busy/error feedback and return to the navigator root after success. |
| F11 — accepted delivery | Acceptance returns the accepted order ID to the rider workspace, which selects Deliveries. Private recipient data remains protected by server assignment. |
| F12 — mixed deliveries | Related deliveries use the viewed order’s customer ID. Customer and admin views retain the existing read rules, with an explicit retry state for failed related queries. |
| F13 — favourites | Saved bouquets use the shared image loading/error fallback. Per-item pending controls suppress rapid taps. The service coalesces simultaneous operations on the same user/product and toggles in a Firestore transaction. |

## Compatibility and scope

Publication and stock checks remain client-side compatibility checks after bounded category/availability queries: older products may omit isPublished or use stockCount instead of readyStock. Requiring modern fields in every query would hide those records. Preview/page wording deliberately avoids claiming a whole category is empty, and Next reaches further records. No data migration or new search service is required.

The dashboard’s low-stock count is an explicitly labelled preview of the first 100 flowers; Flowers gives access to all cursor pages. The renamed order statistic is scoped to creation date and the latest 100 orders. This cleanup does not introduce an aggregate reporting backend.

## Validation

Final validation on the completed working checkout:

| Check | Result |
|---|---|
| Flutter static analysis | No issues |
| Complete Flutter suite | 68 passed, including 23 new smoothness regressions |
| Strict Auth/Firestore/Storage backend and rules suite | 52 passed; zero failures, cancellations or skips |
| Connected Chrome browser journeys | All 3 passed, with every journey enabled |
| Demo release web build | Passed; no deployment |
| Git whitespace check | Passed |

The former failing audit checks now live in test/smoothness_regressions_test.dart and run in normal CI; the audit path forwards to that suite. Machine-readable results are saved in audit/smoothness-fix-results-2026-10-05.json.

Browser coverage verifies real checkout/stock changes, acceptance selecting Deliveries, delivery/receipt/feedback, Pre-Order intent and labels beyond the original preview batch, Low Stock opening Flowers, a second inventory page, customer/admin mixed-delivery links, simultaneous favourite toggles, admin history at 320 × 480 with 200% text, approved-application route disposal, and switching back to customer. The role-route assertion waits for its exit animation.

Chrome exposed an additional shared pagination-footer overflow after its controls wrapped; the footer now scrolls within a bounded height. Short-view error/Retry controls are also covered. This fixes the remaining browser layout defect rather than weakening the assertion.

The local backend runtime is Node 24; repository CI targets Node 22. The Java rules tooling reported its existing shutdown exception after successful emulator scripts; only verified test processes left by those runs were stopped.

Added coverage includes two live florist views, disposal, error/retry, unknown rider application lookup, rapid favourite taps, broken images, MYT midnight and screen layout matrices at 100%/200% text. Connected demo fixtures contain 47 bouquets and 46 flower records, including a planned bouquet beyond the original unfiltered Home batch, paginated inventory and mixed historical deliveries. Browser journeys also exercise real callable checkout, acceptance navigation, customer receipt, staff shortcuts, authorized related links and approved role switching.

No frame-time, memory or production read-volume benchmark was performed. Bounded queries and lazy initialization are verified code changes, not a measured speed claim. Live OAuth, push arrival, external dialer/navigation, Google Maps credentials and native device lifecycle remain outside local emulator evidence.

## Deferred release work

Production deployment and external/device checks remain deferred as requested while you are remote. The added catalogue indexes need to accompany a future release. There is no manual action required from you during this local implementation run.
