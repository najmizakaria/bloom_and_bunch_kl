# GitHub browser journey repair — 5 October 2026

## Failure identified from the supplied run log

Run 37316248445, commit 4fbe50e, failed before the integration tests started. ChromeDriver supported Chrome 157, but its default browser lookup selected the runner's preinstalled Chrome 154 at `/opt/google/chrome/chrome`. The Firebase emulators and function loading completed successfully. The deprecation annotations were separate from the `SessionNotCreatedException`.

## Changes

- `.github/workflows/checks.yml` uses setup-chrome v2 with the stable channel and its paired ChromeDriver. It uses the action's exact browser and driver output paths, checks their major versions and waits for the driver endpoint before starting tests.
- `tool/run_app_journey.cjs` forwards `CHROME_EXECUTABLE` as Flutter's `--chrome-binary` option. This explicitly controls the browser selected by WebDriver; merely adding a downloaded Chrome to PATH is insufficient.
- Both jobs use Ubuntu 24.04 and Node 24-based v5 checkout/setup-node/setup-java/upload-artifact actions. The Functions runtime and test Node version remain 22.
- Failure artifacts now include the full app-journey output, ChromeDriver output and emulator debug logs. Pipeline failure status is preserved through `tee`.

The setup-chrome output contract and compatible driver installation were checked against its [official documentation](https://github.com/browser-actions/setup-chrome). Flutter's installed WebDriver service confirms that `--chrome-binary` sets the `goog:chromeOptions.binary` capability.

## Verification

Workflow YAML parsed successfully. All eleven run steps passed Bash syntax validation. The Node runner passed `node --check`; `git diff --check` passed. All four emulator/browser journeys passed with an explicitly selected Chrome executable (Chrome 154.0.8037.93 and ChromeDriver 154.0.8037.92). The process exited with code 0. Windows emulator tooling emitted a Java rules-runtime shutdown warning after test completion; it did not fail the run.

## Next step

Commit and push the updated main2 files to start a new GitHub run. Suggested commit title: `fix: align CI Chrome and ChromeDriver versions`.

Re-running the old run executes the old workflow at 4fbe50e and will not include these changes. A fresh successful GitHub run is still required to establish Linux runner success. No commit, push, live deployment or GitHub re-run was performed here.
