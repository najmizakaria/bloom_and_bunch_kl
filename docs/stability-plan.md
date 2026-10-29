# Bloom & Bunch — Complete Stability and Workflow Improvement Plan

Last updated: 8 September 2026

## Main objective

Make the existing application run smoothly and consistently for customers, florists, and riders before adding unrelated features.

The repair focuses on five business requirements:

1. Ready to Send means a finished bouquet is physically available now. It skips florist preparation and immediately becomes available for rider collection.
2. Pre-Order means a catalogue bouquet will be assembled in 1–3 business days. It remains orderable without assembled-bouquet stock.
3. Custom Bouquet means the florist will source and assemble the requested stems in 1–3 business days. Customers do not see physical flower stock and are not blocked by it.
4. Orders must be created securely without giving customers permission to edit bouquet or flower inventory.
5. Checkout must reuse the customer profile and saved or detected address instead of asking for the same details every time.

## Final business workflow

### Ready to Send

Customer chooses a published bouquet with Ready to Send enabled and readyStock greater than zero.

Order placement:

- Backend checks the current product and server price.
- Backend atomically decreases readyStock.
- Initial order status is Ready for Delivery.
- No florist preparation action is required.
- The order immediately appears in the rider Ready Jobs list.

### Pre-Order

Customer chooses a published bouquet with Pre-Order enabled.

Order placement:

- Assembled readyStock is ignored.
- Backend reads the recipe saved by the florist.
- Required flower stems become internal material demand.
- Initial order status is Awaiting Preparation.
- The promised lead time is 1–3 business days.
- Florist progresses it from Awaiting Preparation to Processing to Ready for Delivery.

### Custom Bouquet

Customer selects flowers, wrapping, ribbon, and card note.

Order placement:

- Customer may request up to 100 stems of one flower.
- Customer never sees stockQuantity.
- Physical flower stock does not block checkout.
- Server recalculates the price from current flower and decoration prices.
- Selected stem quantities become internal material demand.
- Initial order status is Awaiting Preparation.
- Florist follows the same preparation workflow as a Pre-Order.

### Mixed cart

A cart may contain Ready to Send and planned items together. The backend creates at most two linked orders during one checkout:

- One urgent order containing all Ready to Send items.
- One planned order containing all Pre-Order and Custom items.

This prevents a finished urgent bouquet from waiting 1–3 business days for another item. Both orders share one checkoutGroupId so the customer can understand that they came from the same checkout.

## Status model

Use these exact stored status values:

| Status | Meaning | Who can create or move into it |
| --- | --- | --- |
| Awaiting Preparation | Pre-Order or Custom order waiting for florist | Order backend |
| Processing | Florist has started preparing it | Florist |
| Ready for Delivery | Finished bouquet waiting for a rider | Order backend for Ready to Send, florist for planned orders |
| Out for Delivery | One rider accepted the order | Assigned rider workflow |
| Delivered | Rider completed delivery | Assigned rider |
| Cancelled | Order was cancelled and reservations were released | Controlled cancellation workflow |

Pending and Completed remain readable temporarily for old orders. New orders stop writing these legacy values.

## Data principles

- Store physical stock and customer availability separately.
- Store an immutable product and address snapshot inside each order.
- Let the backend calculate prices and stock changes.
- Use atomic transactions for order placement and rider acceptance.
- Never trust totals, roles, status, stock, or prices sent by the customer.
- Do not write a negative physical stockQuantity.
- Show the florist a projected material balance equal to on-hand stock minus reserved demand. This projected balance may be negative and represents the amount that must be restocked.
- Keep legacy fields during migration, then remove them only after every screen uses the new fields.

---

# Checkpoint 1 — Shared data foundation

Status: Complete and confirmed with flutter analyze.

## Purpose

Give every screen the same vocabulary for fulfillment and order status while keeping old Firestore records readable.

## Files

- lib/core/constants/fulfillment_constants.dart
- lib/models/bouquet_model.dart
- lib/models/order_model.dart

## Changes

BouquetModel supports:

- isPublished
- availableForReadyNow
- readyStock
- availableForPreOrder
- leadTimeBusinessDays
- recipeStems
- backward-compatible readyToSend and stockCount values

OrderModel supports:

- fulfillmentType
- addressId
- requestedDeliveryDate
- leadTimeBusinessDays
- requiresPrepTime
- backward-compatible inference for old Pending orders

## Completion test

- Existing bouquets still load.
- Existing orders still open.
- Florist, customer, and rider screens compile.
- No Firestore migration is required yet.

---

# Checkpoint 2 — Florist bouquet fulfillment settings

Status: Complete and confirmed with flutter analyze.

## Purpose

Let the florist describe the real business meaning of each catalogue bouquet.

## Main screen

- lib/features/florist/screens/florist_bouquets_tab.dart

## Changes

The add and edit form separates:

- Published
- Ready to Send
- Assembled ready stock
- Pre-Order
- 1–3 business-day lead time
- Flower recipe for one bouquet

Ready stock belongs only to Ready to Send. Pre-Order does not depend on assembled stock. Existing legacy bouquet fields continue to be written during the migration.

## Completion test

- Ready stock reaching zero disables Ready to Send.
- Pre-Order remains available at zero ready stock.
- Recipe and lead time persist after reopening the bouquet.
- Archive, restore, and delete still work.

---

# Checkpoint 3 — Functional customer fulfilment selector and cart

Status: Complete and confirmed with flutter analyze.

## Purpose

Make the customer Home selector show genuinely different products.

## Files

- lib/models/cart_item_model.dart
- lib/core/providers/cart_provider.dart
- lib/features/customer/screens/customer_home_screen.dart
- lib/features/customer/screens/cart_screen.dart

## Changes

Ready to Send displays only bouquets that are:

- Published
- Enabled for Ready to Send
- Greater than zero readyStock

Pre-Order displays only bouquets that are:

- Published
- Enabled for Pre-Order

The same bouquet may be offered in both modes. Cart lines retain fulfillmentType and leadTimeBusinessDays, so the two choices remain separate. Customer cards do not show stock quantities.

## Completion test

- Ready-only, Pre-Order-only, and dual-mode bouquets appear under the correct selectors.
- The same bouquet added from both modes produces two distinct cart lines.
- The cart shows the correct fulfillment label and lead time.

---

# Checkpoint 4 — Custom bouquet demand planning

Status: Complete and validated.

## Purpose

Remove the current physical-stock restriction from the custom builder.

## Files

- lib/models/flower_model.dart
- lib/models/cart_item_model.dart
- lib/core/providers/cart_provider.dart
- lib/features/customer/screens/bouquet_builder_screen.dart

## Changes

FlowerModel gains availableForCustomOrder. This controls whether the florist can source a flower and is independent from stockQuantity.

Existing flower records default to available for custom ordering. The builder reads all flowers and filters by availableForCustomOrder instead of stockQuantity.

The builder:

- Displays a 1–3 business-day message.
- Hides physical stock.
- Allows up to 100 stems per flower.
- Uses a 150-stem total safety limit for one bouquet.
- Allows exact quantity entry by tapping the number.
- Retains customStemNames in the cart for readable florist details.
- Does not change inventory when adding to cart.

## Completion test

- A zero-stock flower is still selectable.
- A customer can enter 100 stems for one flower.
- Cart shows Custom Bouquet and the correct lead time.
- Physical inventory remains unchanged.
- Favourites and Order Again still open.

---

# Checkpoint 5 — Secure server-side order placement

Status: Complete and emulator-tested.

## Problem being fixed

checkout_screen.dart currently runs a client Firestore transaction that creates an order and updates bouquets and flowers. Correct security rules should reject these product updates, causing the current permission-denied error.

## Backend design

Initialize Firebase Cloud Functions and add a callable placeOrder function. Use a stable Node.js or TypeScript function implementation rather than the experimental Dart backend.

Add the Flutter cloud_functions dependency and an OrderService that calls placeOrder.

The customer sends only:

- checkoutId for retry protection
- Product document IDs
- Chosen fulfillment types
- Quantities
- Custom flower IDs and quantities
- Wrapper, ribbon, and card note
- Selected address ID or confirmed address snapshot
- Requested delivery date when applicable

The server obtains customerId from Firebase Authentication. It must never accept customerId, totalAmount, orderStatus, role, or stock values from the request.

## Server validation

The callable function will:

1. Require an authenticated user.
2. Reject an empty or malformed cart.
3. Limit item counts, quantities, text lengths, and accepted fulfillment values.
4. Load every referenced bouquet and flower.
5. Verify that each bouquet is published.
6. Verify Ready to Send against availableForReadyNow and readyStock.
7. Verify Pre-Order against availableForPreOrder.
8. Verify custom flowers against availableForCustomOrder.
9. Recalculate every unit price and total from Firestore.
10. Calculate material requirements for Pre-Order recipes and Custom selections.
11. Group Ready to Send separately from planned items.
12. Atomically decrement only readyStock for urgent items.
13. Atomically reserve material demand for planned items.
14. Create one or two linked order documents.
15. Save server timestamps and return the order IDs.

## Retry protection

checkoutId is stored by the backend. If a slow connection causes the same request to be repeated, the backend returns the original result instead of creating duplicate orders or deducting stock twice.

## Order snapshots

Each order item stores:

- Product ID
- Product name
- Image URL
- Fulfillment type
- Server-calculated unit price
- Quantity
- Lead time
- Bouquet recipe or custom stem details
- Wrapper, ribbon, and note when relevant

This preserves the original order even if the florist edits a product later.

## Initial statuses

- Ready-only order: Ready for Delivery
- Pre-Order or Custom order: Awaiting Preparation

## Flutter changes

checkout_screen.dart stops reading and updating product stock. It shows progress, calls OrderService once, translates callable errors into friendly messages, clears the cart only after success, and navigates to the created order or order group.

## Validation

Test with the Firebase Emulator Suite before deployment:

- Ready stock decrements once.
- Pre-Order ignores readyStock.
- Custom can exceed current flower stock.
- Client-altered price is ignored.
- Unpublished or disabled products are rejected.
- Two simultaneous customers cannot buy the final ready bouquet.
- Retrying the same checkoutId does not duplicate the order.

Cloud Functions deployment normally requires the Firebase project to use the Blaze pricing plan. Emulator testing can be completed first.

---

# Checkpoint 6 — Firestore rules, Storage rules, and indexes

Status: Complete and emulator-tested.

## Problem being fixed

The current firebase.json does not configure Firestore rules or Cloud Functions, and no project firestore.rules file was found. The final permissions must match each role and the new backend order path.

## Role helpers

Rules read the signed-in user's role from users/{uid}. The client must never be allowed to change its own role field.

Expected roles:

- customer
- florist
- rider
- admin if the project retains an administrator role

## Firestore permissions

### Users

- A user can read their own profile.
- A user can update safe personal fields.
- A normal user cannot change role, approval state, or other protected fields.
- Florist or admin access is restricted to what the app actually needs.

### Saved addresses and favourites

- Only the owning user can read and write users/{uid}/addresses.
- Only the owning user can read and write favourite subcollections.

### Bouquets and flowers

- Customers may read customer-visible product data.
- Customers cannot create, update, or delete products.
- Only the florist or admin may manage products and inventory.
- Archived and unpublished handling must agree with customer queries because Firestore rules are not filters.

### Orders

- Customers can read only orders where customerId equals their UID.
- Customers cannot directly create orders after Checkpoint 5.
- Customers cannot directly change total, status, rider, stock reservations, or item snapshots.
- Florists can read operational orders and make only allowed preparation transitions.
- Riders can read ready jobs and their assigned jobs.
- Only the assigned rider can complete a delivery.
- Direct updates use an allowed-field list, or privileged transitions move into callable backend functions.

### Rider applications

- Customers can submit and read their own application.
- Only the authorised reviewer can approve it and change the user's role.

### Storage

- Public product images may be read by the app.
- Only florist or admin accounts may upload, replace, or delete product images.
- File type and size are validated.

## Indexes

Add firestore.indexes.json for the real queries, including:

- Customer orders by customerId and createdAt
- Rider ready orders by status and createdAt
- Rider assigned orders by riderId, status, and createdAt
- Florist orders by status and requested delivery date
- Published catalogue queries if server-side filters are retained

## Validation

Use Emulator Suite rule tests for:

- Anonymous access
- Customer isolation
- Role escalation attempts
- Product write attempts
- Invalid status transitions
- Rider assignment races
- Address and favourite ownership

Deploy the function, indexes, and rules only after emulator tests pass. After deployment, the old permission-denied checkout path is no longer used.

---

# Checkpoint 7 — Saved and detected delivery address checkout

Status: Complete and validated.

## Purpose

Stop asking for the same delivery information on every order while preserving an easy way to deliver somewhere new.

## Model changes

SavedAddressModel will include:

- id
- label
- formatted address
- recipient name
- recipient phone
- delivery note
- latitude
- longitude
- isDefault
- source, such as detected or manual
- createdAt and updatedAt

## Address service changes

AddressService will support:

- Load all addresses
- Load the default address
- Save and update an address
- Set exactly one default address in a transaction
- Delete an address
- Select a replacement default when needed

## Address selection screen

AddressBookScreen will work in two modes:

- Management mode from Profile
- Selection mode from Checkout

Selection mode returns the chosen SavedAddressModel to checkout. It also offers Add New Address and Edit.

## Checkout loading order

When checkout opens:

1. Load the signed-in user's name and phone from users/{uid}.
2. Load the default saved address.
3. If a default exists, use its address, recipient, phone, note, and coordinates.
4. If none exists, request current location and reverse-geocode it.
5. Fill missing recipient details from the user profile.
6. Show one compact Deliver to card.
7. Let the customer press Change to choose or add another address.
8. If location permission or reverse geocoding fails, show the manual address form.

The customer confirms the selected address rather than repeatedly typing it.

## Location reliability

Store latitude and longitude with the saved address and order snapshot. The rider map should use these coordinates directly instead of geocoding an address string every time.

The order stores an immutable address snapshot so editing the Address Book later does not change an existing delivery.

## Validation

- Existing default address auto-loads.
- Profile name and phone fill missing fields.
- First-time user can use detected location.
- Permission denial opens manual entry.
- Add New Address can become default.
- Checkout Change returns the selected address.
- The rider map opens at saved coordinates.
- Editing a saved address does not alter old orders.

---

# Checkpoint 8 — Florist preparation, reservations, and shortages

Status: Complete and emulator-tested.

## Purpose

Give the florist a truthful work queue and internal restocking view without exposing shortages to customers.

## Order queues

Florist Orders uses:

- New: Awaiting Preparation
- Preparing: Processing
- Ready: Ready for Delivery
- Completed: Delivered
- Cancelled: optional separate history filter

Ready to Send orders start in Ready for Delivery and therefore never appear in New or Preparing.

## Material requirement calculation

For each planned order:

- Pre-Order requirement = bouquet recipeStems multiplied by item quantity.
- Custom requirement = customStems multiplied by item quantity.
- Store the result as materialRequirements on the order.
- Store flower names and quantities in the snapshot for readable details.

## Reservation model

Each flower tracks:

- stockQuantity: physical on-hand stems
- reservedQuantity: stems committed to open planned orders
- projectedBalance: displayed calculation, stockQuantity minus reservedQuantity
- shortageQuantity: maximum of zero and reservedQuantity minus stockQuantity

The physical value remains non-negative. The projected balance can show a negative number, such as -80, which tells the florist how many stems must be restocked.

## Reservation lifecycle

- Planned order created: increase reservedQuantity.
- Planned order cancelled: release its reservation.
- Florist starts preparation: order becomes Processing.
- Florist marks ready: require enough physical stock, decrease stockQuantity, release reservedQuantity, and set Ready for Delivery in one backend transaction.
- Failed or repeated action must not consume stock twice.

## Florist details

Order details display:

- Fulfillment type
- Promised delivery date
- Recipient and address
- Bouquet and custom stem names
- Required, on-hand, reserved, and shortage quantities
- Wrapper, ribbon, and card note
- Only the next valid action

The florist cannot move backward or skip preparation states.

## Dashboard

Dashboard counts become:

- Awaiting Preparation
- Preparing
- Ready for Delivery
- Due soon
- Overdue
- Flowers requiring restock

## Inventory

Flower inventory keeps physical stock controls and adds:

- Offered for Custom Orders switch
- Reserved demand
- Projected balance
- Shortage warning

Zero physical stock does not automatically disable custom ordering. The florist disables availableForCustomOrder only when the material can no longer be sourced.

## Validation

- Ready to Send bypasses florist preparation.
- Pre-Order and Custom appear in New.
- A 100-stem custom request shows the correct shortage.
- Restocking reduces the displayed shortage.
- Mark Ready is blocked until enough physical stock exists.
- Mark Ready consumes and releases quantities once.
- Order cards sort by promised date and urgency.

---

# Checkpoint 9 — Rider handoff and customer tracking

Status: Complete and emulator-tested.

## Purpose

Complete the order lifecycle after an order becomes ready.

## Rider ready jobs

Rider sees orders where:

- orderStatus is Ready for Delivery
- riderId is absent
- delivery address and coordinates are valid

## Atomic rider acceptance

Accept Delivery must be an atomic backend operation:

1. Confirm the rider is signed in and approved.
2. Re-read the order.
3. Confirm it is still Ready for Delivery and unassigned.
4. Set riderId, riderName if required, acceptedAt, and Out for Delivery.
5. Return a friendly already-accepted error if another rider won the race.

## Completion

Only the assigned rider can mark an order Delivered. Save deliveredAt and the final status in one update.

## Map behavior

Use the order's stored latitude and longitude. Keep address-string geocoding only as fallback for legacy orders.

## Customer tracking

Fix the current status mapping. Ready for Delivery must not be labelled Out for Delivery before a rider accepts it.

Planned-order timeline:

- Order Confirmed
- Preparing
- Ready for Pickup
- Out for Delivery
- Delivered

Ready-to-Send timeline:

- Order Confirmed
- Ready for Pickup
- Out for Delivery
- Delivered

Show rider assignment only when riderId exists.

## Order Again

Order Again reloads current product availability and prices. It keeps fulfillmentType and custom stem names, but it must not blindly trust old prices or automatically place an unavailable Ready to Send item.

## Validation

- Ready to Send appears to riders immediately after checkout.
- Planned order appears only after florist marks it ready.
- Two riders cannot accept the same order.
- Assigned rider sees the active job.
- Another rider cannot complete it.
- Customer tracking changes in real time.
- Delivered order appears in history with the correct label.

---

# Checkpoint 10 — Full regression, cleanup, and release check

Status: Complete. Release deployment is awaiting approval.

## Automated checks

Run:

- dart format on changed Dart files
- flutter analyze
- flutter test
- Firebase Functions tests
- Firestore and Storage rules emulator tests
- flutter build apk

Add focused tests for business behavior rather than duplicating widget implementation.

## Three-account manual test

Use separate test accounts:

- Customer
- Florist
- Approved rider

## Product matrix

Test:

- Ready-only bouquet with stock
- Ready-only bouquet at zero stock
- Pre-Order-only bouquet
- Bouquet enabled for both modes
- Custom flower with positive stock
- Custom flower with zero stock
- Unpublished and archived products
- Disabled custom-order flower

## Checkout matrix

Test:

- Ready-only cart
- Pre-Order-only cart
- Custom-only cart
- Mixed urgent and planned cart
- Quantity greater than remaining ready stock
- Changed product price
- Duplicate tap and slow network retry
- Signed-out session
- Default saved address
- Different saved address
- Detected address
- Manual address fallback

## Role and security matrix

Verify directly:

- Customer cannot edit bouquets, flowers, roles, or other users' orders.
- Florist cannot claim rider jobs.
- Rider cannot edit products or preparation status.
- Unapproved rider cannot claim a job.
- Assigned rider cannot be replaced by a racing update.
- User cannot promote their own role.

## Failure handling

Every main screen should have:

- Loading state
- Empty state
- Retryable error state
- Disabled action while processing
- Friendly Firebase error text
- Mounted checks after asynchronous calls
- Confirmation for destructive actions

## Legacy cleanup

After all new flows pass:

1. Migrate old bouquet fields to the new field names.
2. Migrate old order statuses where possible.
3. Keep readers backward-compatible for one release.
4. Confirm no old client writes remain.
5. Remove readyToSend, stockCount, Pending, Completed, and obsolete requiresPrepTime logic in a later cleanup.
6. Remove unused imports, screens, services, and duplicate status maps.
7. Document the final Firestore schema.

## Release acceptance criteria

The stabilization work is complete when:

- flutter analyze reports no issues.
- APK build succeeds.
- Customers can place all three fulfillment types.
- Ready to Send reaches riders without florist preparation.
- Pre-Order and Custom follow the preparation queue.
- Custom orders never expose or reject based on physical flower stock.
- Checkout uses a saved or detected address.
- No permission-denied error occurs during valid checkout.
- Product stock and reservations remain correct under concurrent actions.
- Every role sees only its allowed data and actions.

---

# Recommended implementation order from the current point

1. Finish Checkpoint 4 validation.
2. Build and emulator-test Checkpoint 5 backend order placement.
3. Add and emulator-test Checkpoint 6 rules before production deployment.
4. Connect the existing Address Book in Checkpoint 7.
5. Add florist demand and shortage workflow in Checkpoint 8.
6. Complete rider and customer status flow in Checkpoint 9.
7. Run Checkpoint 10 and clean legacy code only after all flows pass.

Do not skip from Checkpoint 4 directly to visual polish. Checkpoints 5 and 6 resolve the permission error and establish the secure source of truth required by every later screen.

## Official Firebase references

- Callable Functions: https://firebase.google.com/docs/functions/callable
- Cloud Functions overview: https://firebase.google.com/docs/functions
- Firestore transactions: https://firebase.google.com/docs/firestore/manage-data/transactions
- Firestore rule conditions: https://firebase.google.com/docs/firestore/security/rules-conditions
- Firestore role-based access: https://firebase.google.com/docs/firestore/solutions/role-based-access
- Firestore field restrictions: https://firebase.google.com/docs/firestore/security/rules-fields
