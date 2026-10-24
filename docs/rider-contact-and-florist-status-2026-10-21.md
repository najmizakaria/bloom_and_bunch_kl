# Rider contacts and florist delivery status

Florist Orders now includes **Delivering**, backed by `Out for Delivery`.
The list and live order detail show the assigned rider name. Orders move from
Ready to Delivering to Awaiting receipt to Completed through the existing
server transitions. Preparation warnings on list cards stop once preparation
has finished.

## Review existing rider contacts

Open **Admin → Riders → Directory & locations → rider actions → Review delivery
contact**. Confirm the name and Malaysian phone number with the rider, tick the
review checkbox, and approve. Riders without an active delivery also have this
action. A contact can be repaired while a delivery is active.

The directory shows whether the approved contact is usable. A profile phone can
prefill the review form, but it is never silently treated as an approved contact.
The server stores the reviewed contact in `rider_applications/{uid}` with the
reviewing admin, timestamp, source and revision. Existing application fields are
preserved. Audit events do not include phone numbers. Stale reviews are rejected
and require refreshing the directory.

## Acceptance and calling

New acceptance requires an approved application with a nonempty rider name and
valid Malaysian phone. This is checked in the assignment transaction. The rider
feed reports contact readiness and explains why acceptance is disabled. An
already accepted job remains usable and retryable while its contact is repaired.

Admin-created rider accounts receive an approved normalized contact. Changing a
managed florist to a rider requires explicit contact review in the role dialog.
Normal application approval also validates and normalizes the contact.

The owning customer can fetch only the currently assigned rider contact, during
Out for Delivery or Awaiting Customer Confirmation. Reassignment changes the
contact returned, and completion removes access. The contact dialog offers a
phone dialer and Copy number. Unavailable-contact errors omit transport codes.

## Release

Deploy the updated functions before distributing the updated app:

```powershell
firebase deploy --only functions:orders
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
