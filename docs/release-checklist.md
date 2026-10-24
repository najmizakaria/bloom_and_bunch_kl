# Release checklist

## Before testing

- Confirm the supported platform scope. Android/web compilation does not establish iOS readiness.
- Use the demo emulator environment and seeded role accounts from README.
- Run Flutter analysis, Flutter tests, the strict emulator backend suite and the browser journey. CI must report zero skipped required tests.

```powershell
flutter analyze --no-pub
flutter test --no-pub
firebase emulators:exec --project demo-bloom --only auth,firestore,storage "npm --prefix functions run test:emulators"
firebase emulators:exec --project demo-bloom --only auth,firestore,storage,functions "node tool/run_app_journey.cjs"
```

The browser journey requires a running ChromeDriver on port 4444. Do not run it against real accounts or production data.

## Business configuration

- Review `functions/store-policy.json` with the store: mode, area/radius, fees per delivery, capacity, weekdays, opening/cutoff hours, holidays and manual payment instructions.
- Confirm policy text, cancellation/refund handling, support ownership and handling of an absent recipient/no available rider.
- Understand that support resolution records a response; it does not automatically cancel, reassign, refund or charge an order.
- Run `node tool/validate_release.cjs` (Android) or `node tool/validate_release.cjs --web` for public-release configuration checks. It intentionally rejects the checked-in demo policy.

## Native release

- Confirm the permanent application ID before changing `com.example.bloom_and_bunch_kl`; changing it affects the installed-app identity and Firebase/OAuth registration.
- Supply ignored `android/key.properties`: storeFile, storePassword, keyAlias, keyPassword. Paths are relative to the android directory or absolute. Keep the keystore backed up securely outside Git.
- Release builds require the release signing file; debug signing is no longer a release fallback.
- Verify icons/name, Android permission prompts, Maps, Google sign-in, notification permission and background delivery on an installed signed build.
- On a Mac: configure existing iOS build keys and Apple signing, install pods, configure Crashlytics symbol upload, APNs and capabilities, then test the real app. No iOS build/device success is implied by Windows checks.
- If monitoring is enabled, verify a staging crash/error and a known usage event. Default native SDK collection is disabled in the manifests; Dart enables collection only for configured monitoring builds.

## Coordinated backend/client release

- Review actual Firebase role accounts and the prototype rules against store permissions.
- New client checkout requires quoteCheckout; deploy compatible Functions, rules and indexes before the matching client. Old quote-less checkout is accepted only in demo mode; coordinate upgrades before switching to manual mode.
- Back up the previous code/configuration and retain the last known compatible client. Do not roll back only rules or only Functions while leaving an incompatible client live.
- Wait for new indexes to finish building before releasing the client.
- App Check: test registered providers before enforcing tokens. Client activation and server/console enforcement must be coordinated.
- Deployment commands are deliberately separate from verification. This implementation did not deploy anything.

## Real-device acceptance

1. Complete ready, planned, custom and mixed-cart journeys with separate customer/florist/rider accounts.
2. Verify total, fee, payment arrangement and estimated dispatch comprehension before placing an order.
3. Race last-stock orders and rider acceptance; retry after a lost response and app restart.
4. Test GPS denied, manual address/pin, invalid area, changed address and old cached data.
5. Test foreground/background/terminated notifications and account switches.
6. Pick/upload images on each supported platform; test file rejection and lost connectivity.
7. Report a customer/rider issue, respond as staff, submit delivered-order feedback, and verify another account cannot access it.
8. Test 200% text, small screens, screen readers and web keyboard navigation.
9. Profile realistic catalogue/order history, document device/network/build conditions and observe loading/scrolling.
10. Run the user study kit and record real results and limitations; never report automated passes as user satisfaction.
