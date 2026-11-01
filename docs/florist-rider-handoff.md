# Florist packing and rider handoff

New orders, including ready-made bouquets, start at Awaiting Preparation.
Ready-made stock is reserved at checkout as before. The florist starts preparation,
checks the bouquet, add-ons and card, then marks the order **Ready to ship**.
The stored value remains `Ready for Delivery` for existing records and queries.
Packing a ready-made order does not deduct its bouquet stock again.

For an order without a payment hold, with a valid address/pin, no open issue and a
due delivery date, marking ready publishes its rider job in the same transaction. The rider
screen listens to the private `delivery_queue/current` revision and refreshes the
existing server-filtered list. It retains manual refresh and 30-second polling
when live updates disconnect. Future bookings stay unavailable until their date
in Malaysia time, including weekends.

Riders can accept available jobs. Florist/admin order details also provide Assign
rider, Reassign rider and Unassign rider. The paged rider directory shows approved,
non-suspended accounts with approved contact details and no active delivery; it
does not establish that a rider is online. The buyer cannot deliver their own order.
If no rider is eligible, the order remains ready to ship.

Both acceptance and staff assignment enter **Rider assigned**, not Out for Delivery.
The assigned rider must **Confirm collection** to start delivery. Collection is
blocked by payment holds, open issues and future scheduled dates. The existing
delivery and customer-receipt confirmation steps then apply. Rider locks cover
assignment, transit and awaiting receipt; account deletion is blocked during those
stages. Old Out for Delivery records keep their recorded status and can finish
without an invented collection timestamp.

Only staff can change an assignment before collection. Reassignment and unassignment
require a reason, the expected rider and assignment revision. The order, old/new
rider locks, job availability and audit record change atomically. Request fingerprints
make exact retries safe; revisions reject stale requests even after an order returns
to an unassigned state. Staff notes and actors are stored in
`orders/{id}/assignment_events`, readable only by staff. Customer account deletion
also removes those notes. Assigned riders and customers receive existing opt-in
status notifications; replaced riders are notified of the assignment change.

## Release

Deploy matching Functions, Firestore rules and the Flutter application together.
The added callable is `listAssignableRiders`; `transitionOrder` adds `assign`,
`unassign` and `collect` actions. Assignment requests include `riderId` (assign only),
`expectedRiderId`, `expectedAssignmentRevision`, `requestId` and `reason`.
New handoffs use delivery workflow version 3. Existing indexes support the changed
status values; the approved-rider directory uses status and document-ID pagination.

Older rider clients do not query Rider assigned or provide collection confirmation.
Update those clients before using the new handoff workflow. No historical order
migration, automatic rider selection or online-presence tracking is introduced.
Validate opt-in push delivery on release devices after deployment; emulator tests
mock messaging and do not establish real FCM/APNs delivery.
