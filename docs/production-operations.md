# Production implementation and operations plan

This is the initial production roadmap. The subsequent behavior-preserving backend
refactor is documented in [backend-refactor.md](backend-refactor.md); the feature
and operational changes below remain proposals. No deployment was performed and
the checked-in application retains its existing demo configuration.

## Minimal implementation sequence

1. Keep the working customer-to-delivery journey and existing Flutter/Firebase
   stack. Establish a green baseline using analysis, unit/widget tests, strict
   emulator tests and authenticated browser journeys.
2. Extract the shared callable boundary behind the same endpoint names. Add
   compatible payload bounds, privacy-safe structured logs and correlated request
   IDs. Preserve existing domain errors and transaction behavior.
3. Add transactional per-account request admission, client retry-delay messaging,
   deny-by-default quota storage, eventual TTL cleanup and account-deletion cleanup.
   Test concurrent admission, refill, store failure and cross-account isolation.
4. Bound repair/deletion/scheduled work with resumable cursors where scans can
   exceed a function execution budget. Add durable queues only where background
   volume justifies the additional infrastructure.
5. Prepare staging with reviewed store operations, configured monitoring/App Check,
   backups and sandbox payment recovery drills. Measure capacity and cost.
6. Release to a limited real audience after business/payment/device readiness is
   established. Expand traffic while watching latency, failures and contention.

These steps are proposed, not completed implementation claims.

## Proposed request boundary

Authenticate before database work; bound request size before domain processing;
consume a distributed account quota; check suspension; then run the authorized
handler. Every domain handler retains ownership, entitlement and transaction
checks. Public provider callbacks need their own authentication and admission
policy rather than customer Auth checks.

On quota-store failure, reject with `unavailable` before executing a business
action. On exhaustion, return `resource-exhausted` and a bounded retry delay.
Account quotas complement App Check and platform protections; they do not prevent
all bot, distributed, anonymous or direct-Firestore abuse.

Logs should contain operation, server-generated request ID, outcome code and
duration. Avoid raw payloads, exceptions containing provider responses, addresses,
phone numbers, passwords, tokens and card notes. Correlate an internal error with
its request ID. Set log retention and sampling to fit the traffic/cost budget.

## Runtime and environment

Functions target Node 22; retain lockfiles and the repository's validated Flutter
toolchain. Use one environment per Firebase project. Demo tests must target the
`demo-bloom` emulators; real user data must never enter test fixtures.

The existing function `maxInstances: 10` is a per-function cost/concurrency guard,
not a global request rate limit or capacity proof. Tune memory, concurrency,
timeouts, minimum instances and maximum instances against measured bottlenecks.
Budget external provider latency separately from Firestore transaction time.

Keep payment secrets in Secret Manager and use workload/service identities for
deployment. Client Firebase/Maps configuration is not a server secret; apply
appropriate key restrictions. Restrict service-account roles and document who
can deploy, read sensitive data, restore backups and change business settings.

## Validation before implementation rollout

| Risk | Required verification |
| --- | --- |
| Overselling | Concurrent last-stock purchases produce one success |
| Duplicate checkout | Lost response/restart/retry returns original orders and receipt |
| Quota races | Concurrent app instances cannot spend the same token |
| Quota outage | Business handler does not execute after failed admission |
| Permission regression | Customer, other customer, florist, rider, admin and anonymous negative cases |
| Preparation/assignment races | Exactly-once material effects and one accepting rider |
| Payment ambiguity | Bill-create timeout, delayed callback, late settlement, provider outage, manual review |
| Scheduled delivery | Cutoff/holiday/Malaysia-midnight handling and no early collection |
| Account deletion | Active work blocked; interrupted deletion resumes and removes new private state |
| UI recovery | Preserved checkout ID, stale cart conflict, retry delay, offline/online recovery |
| Database indexes | Staging executes actual queries; required indexes are ready |
| Device integrations | Signed-device Auth, Maps, notifications and payment return |

Existing commands are documented in the README and release checklist:
`flutter analyze --no-pub`, `flutter test --no-pub`, the strict emulator runner,
and the isolated browser journey. A passing test suite is not a load test.

## Capacity model and load test

Agree on the workload before calling the system scalable. A possible planning
scenario is one million registered accounts, 100,000 daily active accounts,
10,000 concurrent browsing sessions and a much smaller checkout peak. These are
illustrative assumptions, not existing measurements or accepted commitments.

Measure at least catalog reads, authenticated quote creation, checkout writes,
same-product contention, live order listeners, rider acceptance and admin reports.
Use production-like staging data with a distinct tenant/project and fake provider
adapter. Ramp traffic gradually. Do not load-test the real store or sandbox bank
without permission from the provider.

Candidate acceptance targets to agree on: p95 catalog response under 500 ms,
quote under 1.5 s, checkout commit under 2 s excluding interactive payment, less
than 0.5% unexpected errors, zero oversells and zero duplicate financial effects.
Record geography, network, device, cold/warm state, traffic profile and achieved
throughput. Latency targets do not establish correctness, and correctness tests
do not establish throughput.

Track reads/writes, indexed-document size, storage, function runtime, instance
count, logging and provider usage per successful checkout. Approve cost limits
before increasing instance caps. Popular SKU and shared daily-capacity documents
are the first exact-state contention candidates; profile them specifically.

## Monitoring and incident response

Define availability against core customer journeys. Alert on sustained failures,
checkout latency, transaction aborts, payment records needing review, stuck
fulfillment, scheduled-job lag, notification failure and unusual cost growth.
Separate expected validation errors from backend failures. Review quota denials
to distinguish automation from overly tight limits for legitimate customers.

Assign owners for payment reconciliation, stock correction, delivery issues and
infrastructure incidents. Document retry/replay tools that preserve invariants.
An operational resolution must not quietly claim a refund or completed delivery.

## Deployment and recovery

Deploy compatible backend/rules/indexes before dependent clients; wait for indexes
to become ready. Roll out App Check to compatible clients before enforcing it.
Keep previous artifacts and a coordinated rollback plan; database snapshots and
external payment state cannot be reversed by rolling back application code.

Define recovery point/time objectives with the business, enable reviewed backups
and exercise restoration into an isolated environment. Reconcile restored payment
records against provider truth before allowing fulfillment. Maintain a manual
store support path for delayed payments/deliveries during an incident.

Before live ordering, confirm delivery area, operating calendar, capacity,
customer support, cancellation/refund procedures and approved payment method.
ToyyibPay sandbox support does not establish live payment readiness. Complete the
existing [release checklist](release-checklist.md), including real-device checks.

The Firebase login must be refreshed before the deployed database edition,
location, IAM, App Check, indexes and runtime configuration can be verified.
