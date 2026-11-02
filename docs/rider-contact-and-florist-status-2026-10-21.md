# Rider contacts and florist delivery status

Florist Orders now includes **Delivering**, backed by `Out for Delivery`.
The list and live order detail show the assigned rider name. Orders move from
Ready to Delivering to Awaiting receipt to Completed through the existing
server transitions. Preparation warnings on list cards stop once preparation
has finished.

## Edit existing rider contacts

Open **Admin → Riders → Directory & locations → rider actions → Edit delivery
contact**. Enter the rider name and phone number, then select **Save contact**.
No separate phone approval or review checkbox is required. Riders without an
active delivery also have this action. A contact can be edited during a delivery.

The directory shows whether contact details are available. A profile phone can
prefill the edit form. The server stores the contact in `rider_applications/{uid}`
with the editing admin, timestamp, source and revision. Existing application
fields are preserved. Audit events do not include phone numbers. Stale saves
are rejected and require refreshing the directory.

## Acceptance and calling

New acceptance requires an approved rider application with a nonempty rider name
and phone number. Numbers such as `676766767` and international formats are
accepted as entered, without a Malaysian prefix or fixed digit count. Numbers
are limited to 30 characters and safe dialer characters. This is checked in the
assignment transaction. The feed explains when contact details are missing. An
already accepted job remains usable and retryable while its contact is repaired.

Admin-created rider accounts and managed staff changed to riders receive their
entered delivery contact without separate phone approval. Normal rider
application approval remains required and preserves the entered number. Phone
ownership and reachability are not verified.

The owning customer can fetch only the currently assigned rider contact, during
Out for Delivery or Awaiting Customer Confirmation. Reassignment changes the
contact returned, and completion removes access. The contact dialog offers a
phone dialer and Copy number. Unavailable-contact errors omit transport codes.

## Release

Deploy the updated functions before distributing the updated app:

```powershell
npx -y firebase-tools@latest deploy --only functions:orders
```

Rebuild/restart the mobile app or local web server. For hosted web, run
`tool/build_web.ps1` and deploy hosting through the existing release process.
No live rider records are automatically approved or changed by this release.

Verification: 158 Flutter tests passed, strict analysis passed, and 124 backend
tests passed with zero skips against demo Auth/Firestore/Storage emulators. The
web release build and web configuration validation also passed. Tests
cover missing/pending/rejected/malformed contacts, explicit review, stale saves,
permissions, admin creation, acceptance, customer calling, assignment changes,
completion, and florist delivery filters.
