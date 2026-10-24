# CI browser journey selectors — 23 October 2026

## Failure

Project checks for `e492d20` reached the browser tests and failed in the rider
journeys. The supplied UI dump already contained the ready deliveries. The test
was waiting for an area-only `ListTile` that the current UI no longer renders.

Available jobs now use `DeliveryJobCard`, show the complete delivery address and
open through **View delivery**. Assigned jobs use `RiderDeliveryDetails` and an
**Open map and delivery actions** button. The previous **Drop-off Details**
heading is also absent from the current detail screen.

The first checkout journey still searched for exactly **Kuala Lumpur**, and the
queue journey searched for exactly **Queue fixture area**/**Another ready area**.
Those selectors predate the destination UI changes. The local baseline reproduced
all three failures. The third cause was the admin navigation test still tapping
**Rider history**, although the current shell uses **Riders → Delivery history**.
Admin logout is under account settings rather than a **More** tab. Failed checkout
completion also prevents the later history check from finding its confirmed row.

## Changes

- Select available delivery cards by their model's order ID and tap the scoped
  **View delivery** control. Scroll to the actual control before tapping.
- Check hidden own/preparation fixtures by order ID and by address substring,
  so full-address formatting does not make the negative assertions vacuous.
- Locate the assigned delivery by order ID, open its current action button, and
  assert the actual detail screen plus recipient/address content.
- Navigate the real admin sidebar/drawer and Delivery history tab; verify logout
  through **Admin account → Settings & log out**. Scroll to the completion/logout
  controls before interacting with them.
- Verify the completed history record has a server receipt timestamp and that its
  current status and Malaysia-time value are rendered, across the table/card UI.
- Return the available queue to its top before checking the active-delivery
  banner; the current list intentionally retains its scroll position across tabs.
- Keep delivery acceptance, the active-delivery block and customer confirmation
  checks. No production UI, backend behavior, timeout or test skip was changed.
- Upgrade both `actions/upload-artifact` uses from v5 to v6. The warning is
  separate from the test assertion failures. The [official v6 release notes](https://github.com/actions/upload-artifact/releases/tag/v6.0.0)
  confirm that v6 uses Node.js 24 by default. The application Functions runtime
  remains Node 22.

A new push is needed to run these changes in GitHub Actions. Re-running the old
commit runs the old test selectors and workflow.

## Verification

- The unmodified browser suite reproduced the three supplied failures locally.
- All five corrected browser journeys passed against fresh Auth, Firestore,
  Storage and Functions emulators; the runner exited with code 0. Chrome
  155.0.8059.85 was paired with ChromeDriver 155.0.8059.79.
- `flutter analyze --no-pub` reported no issues. Workflow YAML parsed successfully
  and both artifact upload steps were checked for v6. `git diff --check` passed.
- No test was skipped, no timeout was increased, and no production code changed.
  No commit, push, deployment or remote GitHub rerun was performed.

Ignored local evidence: `tmp/ci-journey-before.log`, `tmp/ci-journey-final.log`,
and `tmp/ci-journey-final-analyze.log`. A fresh GitHub run is still needed to
establish the result on its Linux runner.
