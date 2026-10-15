# Rider acceptance investigation — 15 October 2026

Reported symptom: a rider accepts a delivery and the order is missing from My Delivery.

The symptom was not reproduced with the current workspace against local demo Firebase emulators. No production orders were modified and no application changes were deployed.

## Verified behavior

- Acceptance assigns the rider and changes the order to Out for Delivery in a transaction. It removes the sanitized available-job record, preserving the full order.
- The browser journey switched to My Delivery, displayed the accepted order, and opened its private address and recipient details. It then blocked another acceptance until delivery and customer receipt confirmation.
- The required production composite index for orders by riderId, orderStatus and descending createdAt is present in the deployed index listing.

## Regression coverage

The previous queue browser test asserted only that the navigation selected My Delivery. It now also waits for the accepted order's actual list tile, opens it, checks the recipient/address, and returns to the workspace.

Validation completed:

- Full Flutter suite: 84 passed.
- Rider queue and delivery confirmation backend tests: 15 passed.
- Firestore rules tests: 10 passed, including assigned-rider access.
- Focused queue browser journey: passed with headless Chrome and local Auth, Firestore, Storage and Functions emulators.
- Flutter analysis of rider screens, FirestorePage and the modified journey: no issues.

The initial rules invocation used the wrong working directory; rerunning from functions passed. Browser execution initially failed because ChromeDriver 153 did not match Chrome 155; a compatible official ChromeDriver was installed under the ignored local browser tooling directory and the journey then passed. The emulators required the installed JDK 21 rather than the default Java launcher.

## Still needed for the reported failure

Obtain the missing order ID and whether the failure occurred on the hosted website or a local Flutter build. These identify the actual assignment/status and running application version. Local success and a present index do not establish that the affected production order or deployed application is healthy.
