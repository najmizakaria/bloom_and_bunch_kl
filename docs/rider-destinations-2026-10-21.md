# Rider destinations and delivery UX

Available-delivery cards now lead with the buyer's complete delivery address
saved on the order, followed by pickup store, accurately labelled requested/estimated dates, item count and an
explicit View delivery action. Order-creation time is shown only in the preview.
Older dispatch/requested dates receive a warning. The list retains pull-to-refresh,
bounded pagination, periodic foreground refresh and retry controls, and shows the
last successful update time.

Before acceptance, approved riders can see the public pickup address and the
order's delivery address. Recipient names/phone numbers, delivery notes and
destination coordinates remain excluded from the callable and delivery-job
projection. Acceptance races show a delivery-unavailable dialog, then close the
preview and refresh the queue. Existing single-active-delivery, payment and
scheduled-date checks remain server-enforced.

My Delivery and its detail screen put the full written address, recipient contact,
instructions and Navigate/Call recipient actions above the map. They include the
pickup location and an item checklist with separate add-ons. The map is optional
supporting information; map failure does not hide the address or actions. Mark as
Delivered remains fixed at the bottom of the detail screen. Customer receipt
confirmation and open-issue rules are unchanged. No new delivery status, distance
estimate, route calculation or payment-provider integration was added.

## Address compatibility

The address form stores `locality`, `postcode` and `state` separately, alongside
the existing complete address and pin. Native and browser reverse geocoding fill
these fields when available; customers can correct them. All form fields stay
mounted so required fields are validated even when below the viewport.

New orders snapshot the area in `deliveryLocality`, `deliveryPostcode` and
`deliveryState`. The backend retains the coarse-area metadata for compatibility. For legacy orders,
it extracts a locality only from a postcode paired with a place name, or an
unambiguous federal-territory city. Regardless of whether coarse-area extraction
succeeds, the rider now sees the complete address from the order snapshot.
It does not use the buyer's current default address, which may have changed.

Existing checkout fingerprints retain their previous format when no structured
address fields were supplied. New structured-address confirmations participate in
the fingerprint and are checked against the current saved address. Exact retries
remain idempotent. Customer deletion also clears the new order-area fields.

The callable computes improved previews directly from existing orders, without
requiring an order migration. Admin > Rider applications > Sync delivery jobs
rebuilds existing job projections with `previewVersion: 3`. The public pickup
location matches the existing customer store-information page: Bloom & Bunch KL,
Unit G2, StreetMall Cyberjaya, Cyberjaya, 63000 Cyberjaya, Selangor.

## Validation and rollout

- 154 Flutter tests passed, including narrow/large-text rider layouts, MYT date
  labels, acceptance races and the expanded address form.
- 122 backend tests passed with zero skips against demo Auth/Firestore/Storage
  emulators. The Firestore emulator reported Standard edition.
- Strict Flutter analysis passed. A browser preview with demo data was visually
  inspected; `tmp/rider-layout-preview.png` and `tmp/rider-details-preview.png`
  capture the initial list and accepted-delivery layouts before the full-address follow-up.
- The actual web release built successfully with `tool/build_web.ps1`, including
  its Wasm compatibility dry run and Maps/notification configuration validation.
- No production data was changed. Firebase database inspection could not confirm
  the live edition because the CLI credentials require reauthentication.

Release the updated Flutter app with the Functions changes. Reauthenticate the
Firebase CLI if needed, deploy Functions, then run Sync delivery jobs from the
administrator screen to refresh existing stored projections. Native-device
navigation, calls and Maps rendering still require device release verification.
