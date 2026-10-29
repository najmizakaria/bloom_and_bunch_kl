# Repair schema and write ownership

The existing Firestore database is Standard edition. Firebase Authentication supplies the UID; users/{uid} supplies approved roles. These additions do not change database edition or introduce cross-customer reads.

| Path | Fields/types | Writer / reader |
| --- | --- | --- |
| users/{uid} | notificationsEnabled: optional bool; deletionPending: server-controlled optional bool; defaultAddressId: optional string | Owner reads own profile and updates permitted name/phone/activeRole/preference fields. Address/deletion callables coordinate pointers and locks. |
| users/{uid}/addresses/{id} | label/address/recipientName/recipientPhone/note strings; latitude/longitude optional paired numbers; isDefault bool | Owner reads; authenticated address callables write transactionally under that user's profile lock. |
| users/{uid}/checkouts/{id} | fingerprint string; orderIds string list; createdAt timestamp | placeOrder only. No direct client read/write. Confirmed address participates in the fingerprint. |
| account_deletions/{uid} | status pending/completed; requestedAt/completedAt timestamps | Recent-auth deletion callable and retry trigger only. Denied to clients. Retained for cleanup idempotence and to prevent deleted-profile recreation. |
| notification_devices/{sha256(token)} | uid/token strings; updatedAt timestamp | Notification callables only; private server reads. Maximum 20 active devices per user. Unregister/disable may delete only owned devices. |
| notification_events/{sha256(eventId)} | status sending/pending/sent; leaseUntil/sentAt timestamps | Status trigger only. Private processing/deduplication markers. FCM delivery is at least once; collapse IDs mitigate repeated display. |
| bouquets/{id} | Existing bounded product schema; recipeStems map, each integral count 1..100, at most 30 types and 150 total | Staff management callable checks referenced flowers and expected ready stock. Existing staff flag/stock actions remain subject to rules validation. |
| orders/{id} | Existing immutable customer delivery snapshot and validated items | placeOrder/transitionOrder and trusted cleanup write. Cleanup removes account identifiers and recipient/address/coordinate/card-note data from historical orders. |

The local cart is separate from Firestore: shared_preferences stores each user's items, quantities, checkout ID and frozen uncertain request. It is hidden on sign-out and erased after successful account deletion. Persistence must complete before a new checkout is sent; user-generation guards prevent late work from switching cart ownership.
