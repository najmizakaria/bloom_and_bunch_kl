# MVP API catalog

Design/reference only; no endpoints were changed. Names below describe the
existing callable Functions. Handler validation is the source of truth for
optional/legacy fields. Future request limits and quotas remain proposals.

## Transport and common policy

Use the Firebase Functions client SDK in region `asia-southeast1`. Production
callable URLs use this shape:

`https://asia-southeast1-<project-id>.cloudfunctions.net/<function-name>`

These use the Firebase callable protocol, not a custom REST API. An HTTP client
must POST a JSON envelope with a `data` object and a Firebase ID token in
`Authorization: Bearer <token>`. The SDK handles token attachment and callable
result/error decoding. App Check token enforcement is separately configurable.
Never send an admin SDK credential from a client.

All callables require authentication and reject suspended accounts. Each handler
also enforces its own role/ownership/state requirements. IDs and numbers must pass
server validators. Server errors use callable codes such as `unauthenticated`,
`permission-denied`, `invalid-argument`, `failed-precondition`, `aborted`,
`not-found`, `unavailable`, and `internal`.

The proposed shared boundary would add a request-size bound compatible with the
existing 250 KB cart contract, an account quota, `resource-exhausted` retry details,
and structured request IDs/latency/outcome logs without private payloads. None of
these proposed features is implemented by this design task.

## Customer checkout and account

| Function | Input summary | Result / authorization |
| --- | --- | --- |
| `deliveryAvailability` | `fulfillmentType`, `bouquetId` for pre-order | Valid store dates and timing policy; authenticated |
| `quoteCheckout` | `items[]`, `address`, `messageCards` | Quote ID, integer sen totals, delivery groups, policy/timing; customer |
| `saveCart` | `cart`, `revision`, `mutationId` | New revision; customer; rejects competing edits |
| `placeOrder` | `checkoutId`, `addressId`, confirmed `address`, `items[]`, `messageCards`, `expectedTotal` in MYR, `quoteId`, optional `cartSync` | `orderIds[]`; customer; atomic inventory/capacity/receipt commit |
| `saveAddress` | Optional `addressId`, validated `address` including default flag | Address `id`; own account |
| `setDefaultAddress` | `addressId` | Address `id`; own account |
| `deleteAddress` | `addressId` | Address `id`; own account |
| `saveRecipe` | Custom stems, wrapping/ribbon and bounded recipe inputs | Recipe `id`; customer |
| `submitOrderFeedback` | `orderId`, rating 1–5, optional bounded `comment` | `saved`; owning customer after completion |
| `reportOrderIssue` | `orderId`, supported `reason`, optional bounded `comment` | `saved`; authorized customer/rider for the order |
| `getAssignedRiderContact` | `orderId` | Approved rider `name`/normalized `phone`; owning customer during assigned active delivery |
| `updateNotificationSettings` | `enabled`, optional device `token` (required to enable) | `enabled`; own account |
| `unregisterNotificationDevice` | `token` | `removed`; only removes a token owned by caller |
| `deleteAccount` | No business payload; recent Auth login required | `deleted`; blocked while qualifying work is active |

`placeOrder` requires the exact quoted payload and selected saved address.
Persist its checkout ID across app restarts and uncertain network outcomes.
Replay with the same fingerprint returns the original IDs; changed content fails.
A quote does not reserve stock, and successful order creation does not imply
payment settlement.

## Fulfillment, catalog and support

| Function | Input summary | Result / authorization |
| --- | --- | --- |
| `transitionOrder` | `orderId`, `action` | Current/resulting `status`; role and state dependent |
| `listAvailableDeliveries` | Optional `cursor: {phase, orderId}` | Up to 20 `deliveries`, `activeDeliveryId`, `contactReady`, `nextCursor`; rider |
| `publishRiderLocation` | `latitude`, `longitude` or `stop: true` | `saved`; rider with assigned out-for-delivery order for updates |
| `saveBouquet` | Optional `bouquetId`, `bouquet`, `expectedReadyStock` for edit | Product `id`; florist/admin with stock conflict check |
| `saveCommerceProduct` | `kind: addons/card_designs`, `id`, `product`, `revision` | `saved`; florist/admin; optimistic revision check |
| `resolveOrderIssue` | `orderId`, bounded `response` | `saved`; store staff; resolution does not complete delivery |
| `confirmManualPayment` | `orderId` | `saved`; store staff; coordinates related current-schema checkout orders |
| `reviewRiderApplication` | `applicantId`, `decision: approved/rejected` | Resulting `status`; admin |
| `listRiders` | Optional `after` ID | Safe `riders` display identities, `next`; admin |
| `syncDeliveryJobs` | No business payload | `eligible`, `excluded`, `removedStale`; admin repair operation |

Order transition actions:

| Action | Actor | Main guard |
| --- | --- | --- |
| `prepare` | Florist/admin | Order requires preparation and is in an eligible state |
| `ready` | Florist/admin | Preparation started; materials available; consumes once |
| `cancel` | Florist/admin | Eligible pre-delivery state; guarded material/stock release |
| `accept` | Approved rider | Due, eligible, unassigned order; active-job and payment guards |
| `deliver` | Assigned rider | Active delivery; no open blocking issue |
| `confirmReceived` | Owning customer | Awaiting confirmation; no open blocking issue |

The rider listing may return fewer than 20 records with a next cursor because it
filters ineligible records within a bounded scan. Use the returned cursor as-is.
The repair operation currently scans broadly; replacing it with bounded resumable
work is a proposed operational improvement before a large backlog.

## Sandbox payment

| Function | Input summary | Result / authorization |
| --- | --- | --- |
| `createToyyibpayPayment` | `paymentId` or owned `orderId`, optional `payerPhone` | Sanitized payment view; owning customer |
| `checkToyyibpayPayment` | `paymentId` or owned `orderId` | Server-reconciled payment view; owning customer |
| `adminCheckPayment` | `paymentId` | Server-reconciled payment view; admin |

The view includes `paymentId`, `status`, `totalSen`, `orderIds`, optional
`paymentUrl`, `expiresAt` in epoch milliseconds, and `sandbox: true`.
Ambiguous remote bill creation is held for review instead of repeated blindly.

`POST /toyyibpayCallback` is a provider HTTP callback, not a customer callable.
It verifies callback authenticity, stored bill/reference mapping and provider
transactions before settlement. Other methods receive 405. Invalid/unverified
callbacks receive an error; do not treat the browser return URL as proof of payment.

## Administration

| Function | Input summary | Result / authorization |
| --- | --- | --- |
| `adminSummary` | None | Operational counts and separated manual/sandbox revenue; admin |
| `adminInventoryAlerts` | Optional `after` | Bounded inventory scan, low-stock alerts, `next`; admin |
| `adminOrders` | Optional status/payment/fulfillment/mode, `dateField`, `from`/`to` epoch ms, exact-ID `search`, `after` | Up to 20 orders and `next`; admin |
| `adminPeople` | Optional `after` | Staff directory page and `next`; admin |
| `adminCreateStaff` | `requestId`, `name`, `email`, `phone`, temporary `password`, `role` | `uid`; admin; florist/rider roles only |
| `adminUpdateStaff` | `uid`, boolean `suspended`, optional role/contact approval fields | `saved`; admin with active-work restrictions |
| `adminRiders` | Optional `after` | Rider operations directory, reviewed contact versions, location view, `next`; admin |
| `adminSaveRiderContact` | `uid`, `name`, `phone`, `confirmed`, `contactVersion` | `saved`; admin; rejects stale review |
| `saveAdminPreferences` | `orders`, `riders` booleans | `saved`; owning admin |
| `adminStorePolicy` | None | Effective policy and editability; admin |
| `saveAdminStorePolicy` | Allowed `policy` fields | `saved`; admin; audited, validated update |

Date filters use an inclusive `from` and exclusive `to`. Admin order search is
exact ID search, not name/address/full-text search. Payment mode/credentials are
deployment configuration; the policy editing endpoint cannot activate them.

## Read APIs and background work

Catalog, own cart/receipt/address/favorites, order history/details and allowed
operations records are read with Firestore SDK queries under Security Rules.
They are not missing REST endpoints. Keep queries bounded and match ownership
constraints; rules do not filter unauthorized records out of a broad query.

Existing background Functions include payment reconciliation/expiry, scheduled
delivery release, order/admin alerts, audit events, push delivery and account
deletion completion. Clients cannot invoke these as customer APIs.

For future compatibility, add optional fields with safe defaults. A breaking
request/response change needs a new version or coordinated client retirement.
Preserve retry semantics and error codes while extracting existing handlers.
