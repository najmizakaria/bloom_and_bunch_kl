# Add-ons, message cards, scheduled delivery and account carts

Implemented in the shared Flutter customer app and trusted Firebase backend.

## Customer flow

Home quick selection and bouquet details open **Make it extra special**. Browse
and favourites use bouquet details. The custom builder and saved-recipe/reorder
flows use the same options screen. The options remain a draft until confirmed.

Customers choose optional add-ons. Pre-order and custom bouquets require an
available delivery date before entering the cart. Ready bouquets can use the
earliest dispatch or select a later delivery date. Selected add-ons enter as
separate cart lines, with their own quantities and inventory. Compatible product
lines merge only when their fulfillment mode and selected date match. Different
dates never merge.

The cart offers one optional message card per delivery group: design dropdown,
message, editable sender name and live preview. The sender defaults to the signed
in account name. Recipient details remain in the address book. Designs, images
and prices are staff-configured; a zero-priced design is supported. Messages are
limited to 1,000 characters and sender names to 120 characters. Cards are not
part of the bouquet recipe. The custom builder no longer collects a card note.
Historical order notes are retained for compatibility.

Editing a delivery date moves its add-ons and card together. Combining two
deliveries with cards requires the customer to remove one card first. Removing
the last bouquet in a delivery offers to remove its add-ons or move them to
another delivery. Standalone add-on deliveries are rejected by the backend.

## Calendar

The backend applies the existing store opening days, holiday list, cutoff and
daily capacity in Asia/Kuala_Lumpur. The default calendar includes all seven days,
so Saturday and Sunday are bookable and count toward preparation. Existing saved
Admin store operations calendars override the defaults; select all seven days
there to enable weekends for an already-configured store.
Pre-orders have a minimum lead of two
operating-date advances: ordering on Monday before cutoff leaves
Tuesday for preparation and enables Wednesday onward. Longer product lead times
are honoured. Custom bouquets use the same two-operating-day minimum. After
cutoff, the starting date moves to the next operating date before adding lead.

The default booking window is 90 calendar days and can be changed to 7–365 days
in Admin > Store operations. Selecting a date is not a stock/capacity hold.
Checkout revalidates dates, catalogue prices, card availability, stock, area and
capacity. Requested delivery dates and estimated dispatch fields are stored
separately; the existing notice does not promise an arrival time.

## Backend and staff

- `addons`: published products with category, image URL, price, stock and edit
  revision. Stock is deducted transactionally and restored once on unpaid expiry
  or applicable staff cancellation. Stock changes invalidate stale staff edits.
- `card_designs`: published designs with name, image URL, configurable price and
  edit revision. Quotes resolve all prices from these records.
- `users/{uid}/cart/current`: owner-readable, server-written cart, cards, pending
  request and revision. Updates compare revisions and use mutation IDs for safe
  retries. Conflicts require review/reload; prices in drafts are estimates.
- `users/{uid}/receipts/{checkoutId}`: immutable combined checkout snapshot of
  all line items, delivery groups, card charges and total. The receipt screen
  obtains current payment state from the customer's order stream.
- `orders`: schema version 3 adds delivery-group key, scheduled date and card
  snapshot. Items sharing a selected date are grouped into one operational order.
  Preparation requirements are calculated for that group's planned bouquets.
- Existing sandbox payment processing uses one bill for every order in the
  checkout. Manual payment confirmation also covers the linked active groups.

Products > Add-ons and Products > Cards are available to florist/admin staff.
Products can be published/hidden without deleting historical snapshots. Catalogue
rows show product photos. The editor previews existing and selected images and
offers Choose/Replace/Remove image. Selected JPEG, PNG or WebP files up to 5 MB
upload on Save into `addons/` or `card_designs/` in Firebase Storage. Upload errors
keep the form open; a successful upload is reused if saving the catalogue record
needs a retry. An expandable image-link field remains available for existing
HTTPS URLs. Storage rules restrict uploads to active florist/admin staff.
Both catalogues use the flower-management card layout, spacing, typography and
bottom-right Add button. Add-on cards have bounded stock steppers; both types
have Published switches and edit buttons. Quick changes use the existing staff
callable with revision checks, and disable controls while saving.
Demo seeding includes teddy, chocolates, topper and four card designs,
with empty image URLs. Demo fixtures are never seeded to the live project.

Florist/admin details show the selected card and add-ons to pack. Scheduled
orders are omitted from rider availability and cannot be accepted early, even
through a direct callable. A 15-minute scheduler publishes due ready deliveries;
the rider callable checks the date independently. The existing payment hold
continues to apply.

Account deletion removes cart/receipt subcollections and clears saved card
messages/signatures from historical orders. Existing replay fingerprints and
legacy pending checkout requests remain supported. The server clears a matching
account cart both when creating an order and when recovering an already-created
checkout.

## Verification and rollout

Validation includes all 147 Flutter tests, 114 passing backend tests with
zero emulator skips, strict Flutter analysis and a successful demo web build.
The authenticated browser journey exercises the real calendar, teddy add-on,
card design/message/signature, account-cart restoration in a second provider,
mixed checkout and combined receipt. A focused regression also checks that
switching accounts during a pending write cannot copy the old checkout.
Local emulator data is disposable `demo-bloom`
data; the verified emulator edition is Standard. The production database edition
could not be read because the Firebase CLI session requires reauthentication.
The installed Node 24 runtime ran the local backend tests; deployed Functions
continue to target the project's configured Node 22 runtime.

Deploy Functions, Firestore and Storage rules with the matching Flutter release. Publish
the actual add-on products/card designs and images in the staff catalogue. Check
store holidays, cutoff, booking window and capacity before allowing bookings.
Older clients that do not choose dates cannot submit new planned orders; existing
confirmed orders and exact checkout retries continue to work. Validate the final
Android/iOS release against the deployed backend; device installation and live
deployment are separate from the local implementation checks.
