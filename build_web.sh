#!/bin/bash
set -euo pipefail

if [[ ! -f .env ]]; then
  echo "Missing .env file." >&2
  exit 1
fi

set -a
source .env
set +a

: "${FIREBASE_API_KEY_WEB:?FIREBASE_API_KEY_WEB is missing from .env}"
: "${MAPS_API_KEY_WEB:?MAPS_API_KEY_WEB is missing from .env}"

flutter build web \
  --dart-define="FIREBASE_API_KEY_WEB=${FIREBASE_API_KEY_WEB}" \
  --dart-define="FCM_VAPID_KEY_WEB=${FCM_VAPID_KEY_WEB:-}"

node tool/configure_web.cjs
node tool/validate_web_build.cjs
