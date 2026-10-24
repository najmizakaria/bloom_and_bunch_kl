# Database schema: MVP design

Design only. No database, rules, indexes, or application code were changed.
The existing application uses Firestore documents and subcollections, rather
than SQL tables. This describes its main persistence contracts and proposed
additions. Backend validators remain the exact field-level authority.

The live database edition/location could not be inspected because the local
Firebase credentials expired. Verify them before implementing database changes.

## Conventions

- Firebase Auth UID identifies an account. Random document IDs identify orders.
- Firestore timestamps represent instants; `YYYY-MM-DD` strings represent store
  dates in `Asia/Kuala_Lumpur`. Never apply the device timezone to a store date.
- Domain calculations and quotes use integer MYR sen. Existing product/order
  display fields also store decimal MYR; convert through the money helper.
  A future integer-only persistence migration must retain legacy readers.
- Orders snapshot prices, item names/recipes, delivery details and cards. Later
  catalog edits must not rewrite historical receipts.
- New orders use `schemaVersion: 3`, `deliveryWorkflowVersion: 2`. Legacy records
  need defaults and explicit compatibility tests.
- References are document IDs. Firestore has no automatic foreign keys or
  cascades; handlers validate related documents and coordinate deletion.

## Collections and ownership

| Path | Main fields | Access / purpose |
| --- | --- | --- |
| `users/{uid}` | `uid`, `name`, `email`, `phone`, `role`, `roles[]`, `activeRole`, `accountSuspended`, `deletionPending`, `activeDeliveryId`, `defaultAddressId`, timestamps | Owner reads; restricted profile edits; server grants roles |
| `users/{uid}/addresses/{id}` | `label`, `recipientName`, `recipientPhone`, `address`, `note`, `latitude`, `longitude`, `isDefault`, optional area fields | Owner reads; callable writes coordinate defaults |
| `users/{uid}/cart/current` | `checkoutId`, `items[]`, `messageCards`, `pendingRequest`, `revision`, `mutationId`, `fingerprint`, `updatedAt` | Owner reads; compare-and-set server writes |
| `users/{uid}/checkouts/{checkoutId}` | `fingerprint`, `orderIds[]`, `createdAt` | Server-only replay record |
| `users/{uid}/receipts/{checkoutId}` | `checkoutId`, `orderIds[]`, `groups[]`, `subtotalSen`, `cardFeeSen`, `totalSen`, `orderMode`, `paymentId`, `createdAt` | Owner reads; immutable checkout snapshot |
| `users/{uid}/favourite_bouquets/{bouquetId}` | `name`, `imageUrl`, `price`, `savedAt` | Owner CRUD under validation |
| `users/{uid}/favourite_recipes/{recipeId}` | Saved custom recipe snapshot | Owner reads/deletes; server creates |
| `flowers/{id}` | `name`, `category`, `pricePerStem`, `stockQuantity`, `reservedQuantity`, `availableForCustomOrder`, `imageUrl` | Authenticated reads; constrained staff stock edits |
| `bouquets/{id}` | `name`, `description`, `category`, `price`, `imageUrl`, publication flags, `readyStock`, `recipeStems`, `leadTimeBusinessDays`, timestamps | Catalog reads; trusted catalog/stock mutations |
| `addons/{id}` | `name`, `category`, `price`, `stockQuantity`, `imageUrl`, `isPublished`, `revision` | Authenticated reads; server staff writes |
| `card_designs/{id}` | `name`, `price`, `imageUrl`, `isPublished`, `revision` | Authenticated reads; server staff writes |
| `orders/{id}` | Detailed below | Owning customer, authorized staff, assigned rider; server writes |
| `orders/{id}/events/{eventId}` | `status`, `createdAt`, transition metadata where applicable | Order-authorized reads; server writes |
| `orders/{id}/issues/{issueId}` | Report/resolution history and bounded comments | Order-authorized reads; server writes |
| `delivery_jobs/{orderId}` | `orderId`, `orderStatus`, `riderId`, delivery preview, dates, validity flags, timestamps | Approved rider queue; server projection |
| `delivery_capacity/{date}` | `acceptedGroups`, `updatedAt` | Server-only exact capacity accounting |
| `payments/{paymentId}` | Customer/checkout/order references, `totalSen`, `status`, bill/reference metadata, `expiresAt`, `nextCheckAt`, `capacityReserved`, timestamps | Server-only; callable returns sanitized view |
| `rider_applications/{uid}` | `uid`, `name`, `phone`, `vehicleType`, `reason`, `status`, submission/review timestamps, contact revision/source | Applicant submits pending record; admin/server reviews |
| `rider_locations/{uid}` | `latitude`, `longitude`, `updatedAt` | Trusted updates during assigned delivery; controlled admin view |
| `store_settings/operations` | Operating weekdays/hours, holidays, capacity, area, booking window, payment instructions | Server-controlled store overrides |
| `admin_preferences/{uid}` | `orders`, `riders`, `updatedAt` | Owning administrator reads; server writes |
| `admin_alerts/{id}` | Operational alert snapshot | Admin reads; server writes |
| `admin_audit/{id}` | `actorId`, `action`, `target`, bounded details, `createdAt` | Admin reads; server writes |
| `notification_devices/{tokenHash}` | `uid`, `token`, `updatedAt` | Server-only; bounded registered devices |
| `notification_events/{id}` | Notification delivery marker/lease | Server-only retry coordination |
| `admin_notification_events/{id}` | Admin push marker/lease | Server-only retry coordination |
| `account_deletions/{uid}` | `status`, `requestedAt`, `completedAt` | Server-only resumable deletion work |

## Order document

| Group | Fields and types |
| --- | --- |
| Identity | `schemaVersion: int`, `deliveryWorkflowVersion: int`, `customerId: string`, `checkoutGroupId: string`, `riderId: string?`, optional `floristId` |
| Items | `items: array<snapshot>`; fulfillment type, quantity, product/recipe references, server-priced snapshots |
| Money | `totalAmount`, `subtotalAmount`, `deliveryFee`, `cardFee`: MYR numbers; `quoteId: string` |
| Fulfillment | `orderStatus: string`, `fulfillmentType: ready_now/pre_order/custom`, `requiresPrepTime: bool`, `leadTimeBusinessDays: int` |
| Materials | `materialRequirements: map<flowerId,int>`, `materialState: not_required/reserved/consumed/released` for current workflow |
| Delivery | Recipient/address/contact snapshot, `addressId`, `latitude/longitude`, locality/postcode/state, `deliveryGroupKey`, `deliveryTimeSlot` |
| Dates | `estimatedDispatchDate: date string`, `scheduledDeliveryDate: date string?`, `requestedDeliveryDate: Timestamp` |
| Payment | `orderMode: demo/manual/toyyibpay_sandbox`, `paymentStatus`, `paymentInstructions`, optional `paymentId`/`paidAt` |
| Card | `messageCard: snapshot?`, bounded message text and selected design |
| Lifecycle | `createdAt`, `updatedAt`, optional preparation/ready/delivery/customer acceptance/cancellation timestamps |
| Support | Bounded current `support` map, bounded `feedback` map; retained issue history is a subcollection |

Checkout groups items sharing a delivery date. One checkout may create several
orders and one payment/receipt. Do not use an order ID as the checkout replay key.

Current validation bounds include 20 cart lines, quantity at most 20 per line,
30 flower types and 150 stems per custom bouquet, and 100 saved addresses. Address,
feedback, issue, image URL and card text lengths are validated at their handlers.
`reservedQuantity` can exceed on-hand stock for planned sourcing; marking an order
ready must verify enough on-hand stock before consuming reserved materials.

## Index and query design

Existing composite definitions live in `firestore.indexes.json`. Main patterns:

| Query | Filter/order |
| --- | --- |
| Customer history | Customer ID, creation timestamp and document ID cursor |
| Rider active/history | Rider ID, status, timestamps as required by screen |
| Staff preparation | Status / fulfillment with creation timestamp |
| Scheduled release | Ready status, scheduled date, document ID |
| Admin orders | Optional status/payment/mode/fulfillment/date filters; ordered date + ID |
| Sales aggregate | Paid status, order mode, paid timestamp, summed amount |
| Payment reconciliation | Next check timestamp; bill-code lookup for callback |

Deploy required indexes and wait for readiness before releasing dependent
queries. The emulator is not proof that production composite indexes exist.
Avoid unbounded listeners and offset pagination. Keep history in subcollections
rather than appending an ever-growing array to an order.

## Proposed quota record (not implemented)

`api_rate_limits/{sha256(uid)}` would hold `tokens: number`, `updatedAt: Timestamp`,
and `expiresAt: Timestamp`. A transaction would admit a request only when a token
is available. A starting policy to evaluate is burst 120, refill two per second,
shared across callable endpoints for an account. Tune it against actual cart,
tracking and staff activity before enabling it.

Use a distinct record per account, never one global quota counter. Deny all client
access, remove the record on account deletion, and configure TTL for inactive
records. Exempt non-query fields from indexes, especially sequential timestamps.
TTL is eventual cleanup, not the mechanism that refills or enforces a quota.
Hashing account IDs is pseudonymization, not anonymization. Edge-level abuse
protection is still needed for anonymous traffic and distributed attackers.

## Deletion and retention

The existing deletion workflow requires recent authentication, blocks active
orders/deliveries, removes private subcollections/device/location/application
records and anonymizes historical order/payment references. It is resumable.
Retain checkout replay records for the entire supported retry window; removing
them casually can permit duplicate checkout attempts. Do not TTL orders/payments
without an approved business retention policy and recovery plan.

Before public release, define backup frequency, retention, restore ownership and
recovery objectives, then demonstrate a restore into an isolated project.
