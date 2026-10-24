# Project feature audit and fix plan

**Implementation update:** all thirteen findings have now been addressed on main2. See [the fix report](smoothness-fixes-2026-10-05.md) for current behavior and validation. The results below describe the original audit before those fixes.

Inspected the current main2 checkout on 5 October 2026. Deployment and manual release work are deferred as requested. This audit adds diagnostic checks and this plan; it does not change app behavior, production data or deployment configuration.

## Test results and scope

| Check | Result in this audit |
|---|---|
| Flutter analysis | No issues |
| Normal Flutter suite | 45 passed |
| Strict Auth/Firestore/Storage backend suite | 52 passed, zero failures/skips |
| New targeted smoothness regressions | 3 defects reproduced; checks intentionally fail until fixed |
| Browser journeys and demo web build | Passed in the preceding implementation run; not repeated in this audit |

The passing normal suite does not cover every screen, historical data case or accessibility layout. The targeted checks expose gaps in that coverage. No frame-time, memory or production read-volume benchmark was performed; performance observations below are based on query and widget lifecycle inspection. Local Functions tests use installed Node 24; the project/CI targets Node 22. Live OAuth, Maps, push delivery and native device behavior remain outside the local emulator evidence. Those checks are deferred, not assigned to you now.

Run the new diagnostic checks explicitly:

```powershell
flutter test --no-pub audit/smoothness_regressions_test.dart
```

The original checks have now moved into `test/smoothness_regressions_test.dart` and run in CI. The `audit/` entry point forwards to the passing regression suite. The stale-status check was rerun separately after correcting a duplicate-text finder and fails because the outdated action remains visible.

## Highest priority: reproduced defects

### F1 — Historical Completed orders imply unrecorded customer confirmation

`DeliveryProgress` takes only status and fulfillment type. Any `Completed` value renders “Receipt confirmed — order completed,” even when the old order has no customer receipt timestamp. Florist details likewise describe all Completed orders as customer-confirmed. The current backend preserves legacy records correctly, but these screens cannot distinguish them.

Evidence: the new legacy-completion widget regression fails because the receipt claim is rendered twice (heading and stage). Relevant sources: `lib/core/widgets/delivery_progress.dart`, `lib/core/constants/fulfillment_constants.dart`, `lib/models/order_model.dart`, and the customer/florist order details.

Fix: carry workflow version and recorded receipt time through the model/presentation. Describe legacy Completed records as completed under the older workflow when no receipt evidence exists. Reserve “customer confirmed” and the corresponding completed stage for records with actual evidence. Apply this to tracking, cards and staff detail descriptions. Do not migrate dates or invent confirmation.

Acceptance: legacy Delivered, legacy Completed without receipt evidence, and new Completed with a server receipt timestamp have distinct honest labels. Actual server confirmation and retry behavior remain unchanged.

### F2 — Florist order details retain a stale status/action

The florist screen sets `_currentStatus` only in `initState` and local button handlers. It does not listen to its order document or synchronize updated widget data. Replacing Processing with Ready for Delivery on the same widget leaves “Mark Ready for Delivery” visible. The rider detail route also receives a fixed order snapshot, so changes made by another session are not reflected while that route stays open.

Evidence: the new widget regression updates the florist order and fails because the old action remains. Server authorization and sequential transitions still protect the data; the defect is stale display/action availability.

Fix: keep each opened order detail subscribed to the order by ID. Use the latest document for status, recipient details, support and enabled actions. Handle deletion/permission failure with a recovery state. Use the server result or live document after an action rather than assuming the requested status. Ensure the stream is cancelled on route disposal. As a minimum, synchronize incoming widget data with `didUpdateWidget`; this alone does not solve a route that never receives updates.

Acceptance: two staff sessions see changes without reopening; rider details update after customer receipt or issue changes; an obsolete action disappears immediately; slow/retried actions cannot show a false success state.

### F3 — Florist detail overflows on narrow screens with large text

At 320 × 640 with a 200% text scale, the regression reproduces horizontal RenderFlex overflows in three rows:

- Order heading/status badge: 114 px overflow, current source line 324.
- Empty-items information row: 638 px overflow, current source line 292.
- Order total row: 421 px overflow, current source line 660.

Fix: allow the heading and badge to wrap or stack; constrain the empty-state message with Expanded; stack/wrap the total when required; use a minimum-height action instead of a fixed 50 px height where large text needs space. Review long recipient names, addresses, item descriptions and the admin history filter area using the same viewport matrix. Admin filter overflow is a review risk, not a reproduced defect from this test.

Acceptance: 320/360/390 widths, portrait/short landscape heights and 100%/200% text show all information and tappable actions without overflow. Preserve normal desktop layout.

## Further findings from code inspection

These have direct code evidence but have not all been reproduced through authenticated browser interaction in this audit.

| ID / priority | Trigger and consequence | Planned fix / acceptance |
|---|---|---|
| F4 / P2 | Home Pre-Order → search/Browse passes only `readyOnly=false`. Browse interprets this as all modes and can show ready-only products. | Replace the boolean with an explicit All/Ready/Pre-Order mode. Preserve category, mode, query and shell navigation. A ready-only bouquet must be excluded after opening Browse from Pre-Order. |
| F5 / P2 | Home reads the first 20 bouquet documents, then filters locally. Matching published products outside that batch can yield a false “No bouquets…” message. | Apply supported mode/category/published filters before limiting, with appropriate indexes. Keep Home as an honest preview with a Browse-all action; do not imply the entire category is empty from one batch. Test more than 20 products with matches beyond the first batch. |
| F6 / P2 | Florist Low Stock and its attention card call the same Products callback as other catalogue actions. Products opens on Bouquets, while the affected items are flowers. | Pass the intended product tab, select Flowers, and optionally apply a low-stock filter. The shortcut must reveal the affected inventory directly. |
| F7 / P2 | “Completed today” first filters orders by `createdAt`, then checks status. An order created yesterday and completed today is excluded. “Today” also uses device time rather than fixed MYT. | Use actual recorded completion/receipt times and MYT boundaries, or rename the existing statistic to its true meaning. Keep the latest-100 scope honest. Add yesterday-created/today-completed and UTC/MYT boundary fixtures. |
| F8 / P2 | Florist IndexedStack constructs all tabs immediately. Hidden Orders/Products/Profile screens can start listeners; bouquet/flower inventory streams read whole collections. Several streams are created during build. | Lazily initialize visited tabs while preserving their state; retain stable subscriptions; page inventory/catalogue data where appropriate. Profile initial reads, active listeners and frame timing with realistic data before claiming a speed improvement. |
| F9 / P2 | Browse, favourites and inventory errors often show “retry” text with no action. Become Rider does not check loading/error before rendering the application form, so a failed status lookup can look like a new application. | Add explicit loading/error/empty/data states and actual retry controls. Block submissions while status is unknown. Reconnect without leaving the page or duplicating requests. |
| F10 / P2 | Approved Become Rider changes activeRole while the application screen is still a pushed route. AuthGate changes the underlying dashboard, but the pushed page is not popped. The button also lacks error/busy handling. | After successful role switching, close stale pushed routes to the root; prevent repeated switches and report failures. Test dashboard switching from both More and the approved application route. |
| F11 / P2 | Successful rider acceptance pops back to Available jobs instead of opening Deliveries or the newly assigned order. A rider can be left looking at an empty list after “Full details unlocked.” | Return an acceptance result to the workspace and select Deliveries/open the accepted order. Preserve the sanitized feed and transactional assignment. |
| F12 / P2 | Tracking related deliveries uses the currently logged-in UID as customerId. When admin opens a customer's mixed order, the related customer delivery is omitted. | Query by the viewed order's customerId when the viewer is authorized; keep owner/assigned-rider/staff read rules. Handle query errors explicitly. Test customer and admin views of a mixed checkout. |
| F13 / P3 | Saved bouquet images lack an image error fallback; favourite toggles use read-then-set/delete without a busy guard. Failed images and rapid clicks can produce poor or surprising feedback. | Add shared image loading/error fallbacks and per-item pending state; use a safe transactional/explicit desired-state update where necessary. Test a broken URL and rapid double taps. |

Sources for F4–F13: `customer_home_screen.dart`, `bouquet_catalogue_screen.dart`, `florist_dashboard_screen.dart`, `florist_main_navigation_screen.dart`, `florist_products_screen.dart`, inventory/bouquet tabs, `become_rider_screen.dart`, `rider_available_job_screen.dart`, `order_tracking_screen.dart`, `favourites_screen.dart` and `favourites_service.dart`.

## Implementation sequence

1. **Correct status presentation and staff details:** F1/F2. Preserve the working server transactions and private delivery-job feed. Convert the two reproduced status checks into passing normal regressions; add multi-session detail tests.
2. **Fix responsive detail layouts:** F3. Expand the screen matrix to admin history, staff inventory dialogs and rider details. Add screen-level tests rather than testing only isolated components.
3. **Finish navigation and filter intent:** F4/F6/F10/F11/F12. Extend the authenticated journey to check exact product modes, Flowers shortcut, role changes from pushed screens, accepted-job navigation and mixed deliveries for authorized staff.
4. **Correct preview/statistics semantics:** F5/F7. Seed large catalogues and date-boundary order histories in demo emulators. Verify filters precede pagination and historical timestamps remain untouched.
5. **Improve loading and resource use:** F8/F9/F13. Introduce stable/lazy subscriptions, inventory pages, real retry buttons, image fallbacks and duplicate-click guards. Measure with seeded data; avoid adding a search service or rewriting working checkout logic merely for this cleanup.

These phases are local implementation work. They do not require you to operate the production console now.

## Coverage map and next acceptance checks

| Feature group | Current evidence | Next useful checks |
|---|---|---|
| Email/Google navigation, profile failures, account scope | Flutter auth/navigation/session tests; profile role validation | Approved-role switch from a pushed page; failed application lookup; live OAuth remains deferred |
| Home/Browse/custom builder/favourites | Component/builder/price/reorder tests; prior Browse browser journey | Explicit Pre-Order mode; catalogue beyond 20/40; broken images; rapid toggles |
| Cart/addresses/checkout | Persistence, recovery, quantity/line limits, default-address races, quote validation and stock tests | User-facing retry with disconnect/reconnect; ready/planned/custom/mixed UI journeys and address-change confirmation |
| Florist catalogue/inventory/preparation | Recipe, inventory-write, reservation, stale-stock and image validation; prior card-filter journey | Low Stock → Flowers; long/large-text forms; live multi-session order details; hidden listeners |
| Rider application/available/assigned/history | Approval permissions, race-safe assignment, sanitized reads, sequential delivery and safe names | Accepted job opens its details; role route reset; live support/receipt changes; native dialer/navigation remain deferred |
| Customer progress/receipt/legacy data | Sequential/idempotent server confirmations, timeline components and prior receipt browser journey | F1 legacy evidence labels; multi-session details; owner/admin mixed-delivery links |
| Admin history/support/manual payments | Role/rule/callable tests, issue history and prior history journey | Large rider/history pagination; combined date/status/open-issue filters; 200% text; long response text |
| Feedback/deletion/notifications | Ownership/feedback retries, cleanup/retry, deletion races, token/preferences/deduplication tests | UI retry/back navigation; live push arrival and device lifecycle remain deferred |

The plan focuses on existing features. It does not add live rider tracking, chat, courier integration, new payment processing or fabricated historical records.
