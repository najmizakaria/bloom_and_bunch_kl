# Bloom & Bunch KL: improvement and user testing plan

Review date: 21 September 2026. Based on current local source, existing tests and historical audit/repair reports. Recommendations below are proposals, not implemented features. No production data or configuration was changed. No participant study or signed-in device walkthrough was performed during this review, so visual polish and user satisfaction are not scored.

The main priority is a trustworthy end-to-end flower-ordering experience: customers understand what they are buying, what they will pay, when it can arrive, and what happens when something goes wrong. More features should follow evidence from this journey.

## Evidence and existing strengths

- Customer, florist, rider and administrator workflows already exist.
- Flutter uses shared theme/components and Provider; the repository separates core services, features and models.
- Server transactions calculate order prices, coordinate stock/reservations, protect retries and assign deliveries.
- Existing tests include stock races, address confirmation, cart persistence/account isolation, role permissions, deletion recovery and notification behavior.
- Flutter checks rerun for this review: **analysis found no issues; all 36 Flutter tests passed** (`flutter analyze --no-pub`, `flutter test --no-pub`).
- Backend suite rerun for this review: **38 passed, 0 failed, 0 skipped**, using demo Auth, Firestore and Storage emulators. The Storage rules runtime printed a shutdown exception after the successful test exit; this is tooling cleanup output, not a failed assertion.
- These backend tests call handlers directly. They do not establish the deployed callable connection, real Google sign-in, device permissions, payment processing or live push delivery. Some notification tests mock the sender.
- Earlier defects should not be presented as still open: consult [the repair report](project-feature-repairs-2026-09-18.md). This report distinguishes new improvement opportunities from repaired behavior.

## Highest-priority findings

| Priority | Evidence in current source | Improvement and acceptance condition |
| --- | --- | --- |
| Before a public pilot | Product details say “immediate delivery” and timing confirmed at checkout (`bouquet_detail_screen.dart`, lines 189 and 215). Checkout shows lead times; the backend uses “As soon as a rider accepts” (`functions/index.js`, line 89). | Define an honest delivery promise and use it consistently. Show an estimated date/window, whether it is confirmed, and the action if no rider accepts. A customer must be able to explain the timing before ordering. |
| Before a public pilot | Checkout displays product totals without an explicit payment method/state or delivery-fee breakdown. Policies explicitly say the app does not process payment. | Choose the store's actual payment process. For a demo, clearly label payment as outside scope. For a pilot using manual payment, show instructions and a staff-verified state. Add an online provider only if required. Show delivery as free, included or charged explicitly. Never label order creation as payment success. |
| Before a public pilot | `deliveryEligible` checks address presence and valid global coordinates, without a KL service-zone or delivery-capacity check. Business-day calculation skips weekends only. | Enforce the store's supported area and operating calendar on the server. Agree cutoffs, holidays, preparation capacity and delivery windows. Reject unsupported locations before stock changes. Valid coordinates alone do not establish deliverability. |
| Next engineering milestone | No `integration_test/` directory, SDK `integration_test` dependency, Flutter emulator connection mode or `.github/workflows/` found. | Add a demo environment and automated UI-to-callable journeys; make required tests run on pull requests and fail if required emulator cases are skipped. |
| Before claiming user satisfaction | No user-study results or satisfaction instrumentation found in the reviewed project. | Run observed tasks with target users, document failures and retest after fixes. Passing automated tests is not evidence that users find the app easy. |
| Before distribution | Android uses `com.example.bloom_and_bunch_kl` and the release build selects debug signing. | Confirm the permanent app identity, configure release signing and update related Firebase/OAuth registration together if identity changes. Install and test the actual signed release artifact. |
| After core journey validation | Home/catalogue and florist order screens subscribe to unbounded collections; customer history retrieves all matching orders. | Measure with realistic data, then paginate history/catalogue and bound active-work queries. Measure reads, loading time and scrolling rather than assuming small demo data predicts production performance. |

## Review against your 15 development steps

| Step | Project-specific improvement | Evidence of completion |
| --- | --- | --- |
| 1. Define the problem | Proposed statement: “Help KL customers order ready or custom bouquets with clear price and delivery expectations, while helping florists and riders coordinate preparation and delivery.” Validate current ordering difficulties with the store. | Interviews document the existing process, common mistakes and time spent; compare the app against that baseline. |
| 2. Identify users | Customer: choose and send a gift. Florist: manage stock and prepare on time. Rider: collect and deliver accurately. Admin: approve riders and resolve exceptions. Recipient is an important stakeholder even without an account. | A role/task/permission matrix, plus research involving actual role representatives. |
| 3. Requirements | Classify must-have, later and out-of-scope features. Prioritize catalogue, ready/custom order, recipient/address, explicit payment arrangement, delivery promise, preparation, delivery completion and support. | Each requirement has an ID, role, acceptance condition and linked test. Defer loyalty, promotions, AI suggestions and other extras until the core works well. |
| 4. User flow | Browse → choose fulfilment → customize if needed → cart → recipient/pin → review timing/fees/payment → submit → confirmation → track → receive → feedback/support. | Users complete it without coaching; back, cancel, denied permissions and uncertain-response paths are also documented. |
| 5. Wireframes | Focus redesign on delivery choices, checkout, tracking and operational exceptions. Keep the shared theme and navigation unless user evidence identifies a problem. | Test low-fidelity screens before implementation; see screen sketches below. |
| 6. Technology | Keep Flutter, Firebase and Provider. The reviewed problems do not justify a framework migration. Start device validation with Android and web; only claim iOS support after native build/device checks. | Core flows pass on every declared supported platform. Use existing tools before buying or installing more. |
| 7. Database | Preserve order/address/product snapshots and retry protection. If approved features require them, add payment state distinct from fulfilment state, fee totals, delivery promise, timestamped order events, support issues and owner-linked feedback. | Server controls trusted totals/transitions; indexes and ownership tests accompany schema changes. Define data retention and migration behavior before production changes. |
| 8. Architecture | Document Flutter → Auth → Firestore/Storage reads and permitted writes; Flutter → callable Functions for sensitive operations; order changes → notification trigger → FCM. Inject service interfaces into screens to support UI tests. | A diagram and one traced request demonstrate how auth, errors and retries move through the system. An online payment extension would require a server-verified webhook, not a trusted client flag. |
| 9. Project setup | Replace the default README and package description. Document setup, roles, seed data, architecture and test commands. Add explicit demo/staging/production environments and CI; pin known working tool versions. | Another developer can run the project and all required tests from the documented steps. Existing `.env` assets must contain only client-safe configuration, never payment/admin secrets. |
| 10. Core features first | Complete ready-bouquet purchase through delivery, then custom/pre-order, then mixed fulfilment and exceptions. | A repeatable demonstration works across customer, florist and rider accounts with consistent totals/statuses. |
| 11. Validation/security/errors | Preserve server price/role/stock checks. Add supported-zone/calendar validation, useful recovery actions and startup error handling. Evaluate App Check as abuse protection after validating the intended platforms. | Negative tests prove unauthorized operations fail without side effects. Permission/network failures explain the next action. App Check complements authentication and authorization. |
| 12. Testing | Retain current unit/widget/backend suites, add complete app journeys, accessibility checks and real-device integration tests. | Critical scenarios below pass, with actual/expected results and supporting evidence. |
| 13. Bugs/performance | Profile before refactoring. Measure cold start, catalogue images, scrolling, order updates and database reads at realistic size. Split the dense backend file by domain as it changes. | Record device, build, network and dataset alongside measurements; verify improvements against the same conditions. |
| 14. Deployment | Complete release signing/identity, icons, native permissions, Maps/OAuth/push configuration and factual store-approved policies. Coordinate the client with compatible Functions/rules/indexes. | A signed build is installed and tested, with rollback instructions and a release checklist matching the repaired code. |
| 15. Maintenance | Add crash reporting and a small event funnel, monitor failed checkouts/old unassigned jobs, and collect feedback after delivery. Assign an owner to respond to complaints. | Review operational failures and feedback weekly, prioritize repeated issues and retest changes. |

Firebase documents [App Check's complementary role](https://firebase.google.com/docs/app-check). Flutter documents [Android signing and release setup](https://docs.flutter.dev/deployment/android). These are implementation references, not evidence that the project already has those protections/configurations.

## Proposed screen sketches

These are information-layout sketches, not claims about a rendered UI. Dates, fees and windows must come from the store's actual rules; do not fill them with unsupported promises.

```text
WELCOME / BROWSE
Bloom & Bunch KL                 Cart (2)
Deliver to [area / Check coverage]
[Search bouquets or occasion]
[Ready to send] [Pre-order] [Create]
[Budget] [Occasion] [Availability]
[Photo] Name · RM price · honest timing
Home | Browse | Create | Orders | Profile

BOUQUET DETAILS
< Back                         Favourite
[Product photo]
Name · price · size / stem information
( ) Ready: stock available; dispatch estimate
( ) Pre-order: earliest available date
Delivery area / fee information
[Add to cart]

CUSTOM BUILDER
Flowers → Wrapping → Message → Review
[Flower choices and stem quantities]
Selected stems · preparation estimate
Price updates as choices change
[Back]                     [Next / Add]

CART
Delivery 1: ready items / estimate
  Product · quantity · price · remove
Delivery 2: planned items / estimate
  Product · quantity · price · remove
Explain split deliveries and any extra fees
[Continue to checkout]

ADDRESS
Recipient name / phone
Street / unit / postcode / note
[Find address] [Use location (optional)]
[Map pin: confirm entrance]
Coverage result and useful recovery
[Save and use address]

CHECKOUT
Recipient and address              Change
Delivery 1: items / date-window / fee
Delivery 2: items / date-window / fee
Payment method and what happens next
Items subtotal / delivery / total
[Place order · RM total]
Pending response: Checking your order…
Uncertain response: [Check existing order]

CONFIRMATION / TRACKING
Order reference · order accepted
Payment status separate from delivery
Estimated window / last update
Confirmed → Preparing → With rider → Delivered
Split-order links if applicable
[Contact store] [Report a problem]
After delivery: [Rate experience] [Order again]

FLORIST / RIDER / ADMIN
Florist: due orders → shortages → prepare → ready
Rider: available job → accept → pickup → navigate
       → delivered OR delivery issue
Admin: pending applications + operational exceptions
       → review context → resolve / record reason
```

Retain existing useful affordances such as the persistent detail-page add button, labelled bottom navigation and explicit rider completion confirmation. Test screen-reader reading order, text enlargement and touch targets across entire screens, not just isolated components. Flutter provides an [Accessibility Guideline API and platform testing guidance](https://docs.flutter.dev/ui/accessibility/accessibility-testing).

## Test plan: highest-value scenarios

Use separate seeded customer, florist, rider A, rider B and admin accounts in a demo environment. Preserve current regression tests; the scenarios below extend them through actual UI and service connections. Test IDs are proposed requirement-traceability identifiers, not existing automated tests.

| ID | Scenario | Required outcome | Best evidence |
| --- | --- | --- | --- |
| E01 | Customer orders ready stock; rider accepts and delivers | Correct order snapshot and total; stock deducted once; customer sees delivery completion | App integration run plus database assertions |
| E02 | Custom order includes an unavailable-on-hand but sourceable flower | Reservation and shortage visible; cannot mark ready before stock permits it; materials consumed once | Customer/florist/rider journey |
| E03 | Cart combines ready and planned bouquets | Split deliveries understood before submission; confirmation links both orders; charges clear | UI integration plus observed comprehension task |
| E04 | Two customers buy the last bouquet | Exactly one successful order; loser sees a useful stock message | Existing race regression plus client recovery test |
| E05 | Tap submit twice, disconnect after commit, kill and reopen app | Retry resolves the original group; no duplicate order/stock deduction; pending-state copy is understandable | Fault injection and persistent backend assertions |
| E06 | Address changes on another device, GPS denied, invalid pin or unsupported area | Reconfirmation/fallback works; invalid order creates no stock or reservation side effects | Existing address regression plus device tests; service-zone case after implementation |
| E07 | Two riders accept one job | One assignee; loser refreshes; only assigned rider can complete | Existing server race plus two client sessions |
| E08 | Sign out/switch user during checkout, notification or private screen | Other account's cart, address and order never appear | Existing isolation regressions plus device lifecycle tests |
| E09 | Wrong password, reset link, Google cancellation, expired login/deletion retry | Clear recovery; real identity flow succeeds; deletion cannot strand active work | Mock tests plus staging account checks |
| E10 | Push foreground/background/terminated; opt out; notification tap after account change | Correct account/order opens when allowed; disabled recipients receive no new targeted message | Actual device and transport checks |
| E11 | Florist picks/uploads allowed and rejected files | Preview/upload succeeds on supported platforms; rejection is actionable; unauthorized upload fails | Current image/rules tests plus native/browser picker |
| E12 | Recipient absent, incorrect entrance, no rider, cancellation or damaged flowers | User can reach support; staff can resolve the agreed exception path; history records outcome | Operational UAT, then automation once workflow exists |
| E13 | Small screen, 200% text, keyboard open, screen reader and web keyboard | No hidden critical button/overflow; controls labelled; error discoverable without color alone | Accessibility assertions and manual assistive-technology run |
| E14 | Realistic catalogue/history, slow internet, restart and reconnection | Defined loading/retry behavior; no misleading success; responsive scrolling and bounded reads | Profile/release measurements with dataset and network recorded |
| E15 | Payment fails/cancels/retries, webhook repeated or delayed | Payment state verified server-side; no double charge; stock/reservation policy respected | Required only if an online payment workflow is implemented |

Add `integration_test` and an explicit demo bootstrap before claiming these are automated. Connect the app's Auth, Firestore, Functions and Storage clients consistently; do not point only some services at emulators. Use a test host appropriate to the target device. Real OAuth, Maps, FCM/APNs and OS permission behavior still need staging/device tests. Flutter's [integration testing guide](https://docs.flutter.dev/testing/integration-tests) and Firebase's [emulator overview](https://firebase.google.com/docs/emulator-suite) describe these testing layers.

Minimum practical device matrix: one lower-spec physical Android phone, one current Android phone/emulator, narrow and wide web layouts, and an iPhone only if iOS is in the supported release scope. Include fresh install, returning session, denied permissions, unreliable network and app restart. Use the intended release/profile build for performance; debug measurements are not a production baseline.

Current backend rerun command:

```powershell
$env:XDG_CONFIG_HOME = Join-Path (Get-Location) '.firebase-local'
$env:FIREBASE_EMULATORS_PATH = Join-Path (Get-Location) '.firebase-local/emulators'
firebase emulators:exec --project demo-bloom --only auth,firestore,storage "npm --prefix functions test"
```

Update the older release checklist: its emulator command omits Auth, while the repair report's full validation command includes it. CI must explicitly verify zero skipped required integration cases; `npm test` alone can skip emulator-dependent tests.

## User satisfaction: practical FYP study

Start with a small formative round: approximately 5–8 target customers and, where available, 1–2 representatives of each operational role. This is a practical issue-discovery sample, not statistical proof of population-wide satisfaction. Include different technical confidence levels and potential gift purchasers, not only developer classmates. If a role is represented by a proxy, disclose it.

First interview the store about its present ordering process. Record how staff confirm availability, price, recipient details, delivery timing and payment. This establishes a baseline for the claimed problem and prevents measuring the app against an invented business process.

Run 20–30 minute individual sessions with consenting participants and test data. Explain that the system is being evaluated, not the person. Use neutral tasks without naming the button to click; do not guide them unless they are stuck, and record any assistance.

| Participant | Task prompt |
| --- | --- |
| Customer | “Choose a birthday bouquet within RM100 and show me how you would find out when it could arrive.” |
| Customer | “Send a custom bouquet to a friend at this test address with this card message.” |
| Customer | “Your connection dropped after submitting. Find out whether your order exists.” |
| Customer | “Your bouquet has not arrived when expected. Show how you would get help.” |
| Florist | “Identify what needs preparing next and what materials are short.” |
| Rider | “Accept a delivery, find the correct entrance and record the outcome.” |
| Admin | “Review this applicant and identify orders that need store intervention.” |

After each task, ask: “How easy or difficult was that task?” on a consistent 1–7 scale, then “What made it difficult?” After the session, use the standard 10-item SUS unchanged for perceived usability. Ask separately about confidence in delivery timing and price clarity; these are project-specific questions and must not be presented as validated SUS items.

For a real delivery pilot, ask overall satisfaction on a 1–5 scale after delivery, plus an optional comment. Separate app usability from bouquet quality and delivery punctuality. A prototype session can measure satisfaction with the prototype; it cannot establish satisfaction with a real delivery service.

| Measure | Calculation / collection | Proposed project target |
| --- | --- | --- |
| Unassisted task completion | Successful attempts without help / all attempts | At least 90% for core tasks after iteration |
| Critical failures | Duplicate orders, wrong recipient, stock corruption, unauthorized access or irrecoverable blockage | Zero in the tested critical scenarios |
| Delivery/price comprehension | Ask participant to explain timing, split delivery and total before submitting | Every tested participant understands before committing |
| Task time | Time from task start to completion; report median and spread, separate first-use/returning | Improve from baseline; set a numeric target only after the first round |
| SUS | Standard scoring, 0–100 scale | Aim for 80 or above as a project goal |
| CSAT | Number choosing 4 or 5 / all responses × 100 | Aim for 80% or above in the pilot |
| Qualitative issues | Observe hesitations, backtracking, mistaken expectations and comments | Fix severe/repeated problems, then retest |

These are proposed acceptance goals, not measured results or universal standards. SUS is not a percentage; 80 does not mean 80% of users are satisfied. Standard scoring subtracts 1 from odd-item answers, subtracts even-item answers from 5, sums the adjusted values, then multiplies by 2.5. [MeasuringU explains SUS scoring and interpretation](https://measuringu.com/sus/).

For each task record participant code, role, device, task, success/assisted/failure, duration, errors, ease rating and observations. Report raw counts alongside percentages (for example, 7/8), the sample characteristics and study limitations. Do not average customers and operational roles into one unexplained result. Retesting returning participants involves a learning effect; distinguish them from new participants.

Map each finding to a change and follow-up result: “Participants misunderstood ready-to-send → clarified estimate and rider dependency → repeat task showed improved comprehension.” For an FYP, that chain provides stronger evidence than a long feature list or a satisfaction score without observed behavior.

## Maintenance and suggested order of work

1. Agree delivery area, timing/capacity, fee and payment rules with the store; correct contradictory copy and label prototype limitations.
2. Add the demo app environment, complete one UI-to-backend ordering journey and enforce existing checks in CI.
3. Run the first observed user round; fix checkout, address and recovery problems found there.
4. Complete real device checks for sign-in, Maps, images, notifications and release lifecycle; test operational exceptions.
5. Run a second study and a small delivery pilot; publish results with limitations. Complete signing/configuration and store-approved service policies before broader release.

Keep the maintenance event set small: product viewed, cart added, checkout started, checkout confirmed/failed, order delivered and feedback submitted. Use error categories and non-sensitive identifiers; do not place addresses, phone numbers or card messages into analytics. Track checkout drop-off, unassigned-order age, preparation delays and support reasons. Add Crashlytics for supported native targets and an appropriate error-reporting path for web. Tools cannot replace observation or an operational owner who acts on the findings.
