# Localhost rider map

A browser check using the configured web Maps key on localhost:8080 returned
`RefererNotAllowedMapError`. The SDK downloads successfully, but Google rejects
the website when a map is created. No cloud key restrictions were changed.

## Required Google Cloud setting

1. Open Google Cloud → APIs & Services → Credentials in project
   `bloom-and-bunch-kl`.
2. Open the API key used by `MAPS_API_KEY_WEB` in the local `.env`.
3. Under Website restrictions, add `http://localhost:8080/*`. If using the IP
   address as well, add `http://127.0.0.1:8080/*`. Keep the existing production
   websites and API restrictions.
4. Save, allow the change to propagate, and reload the web app.

Google documents this error at
https://developers.google.com/maps/documentation/javascript/error-messages#referer-not-allowed-map-error.

## App changes

The Maps loader now reports authorization failures that arrive after the SDK's
initial callback. `MapAccess` listens for that failure, removes the unusable map,
and offers a retry. The rider screen also offers Open Google Maps using its
existing navigation action. Other map screens retain their written-address
fallback. Pending SDK requests are shared, a partially loaded namespace is not
mistaken for readiness, and network failure/timeout can be retried.

Restart the Flutter web server to load the updated Dart and HTML code. No
Functions deployment is needed for these frontend changes. Rebuild hosted web
with `tool/build_web.ps1` before deploying hosting.

Checks: six loader tests and 31 focused Flutter tests passed, including late
authorization failure, network retry, timeout, rider layout and large text.
Strict analysis passed. A temporary rider screen with a public demo location
also compiled for web and displayed the new fallback in a real browser after
Google rejected authorization. The temporary test server and pages were removed.
The embedded Google map remains blocked until the cloud website restriction is
updated; no successful tile loading is claimed.
