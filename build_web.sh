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
  --dart-define="FIREBASE_API_KEY_WEB=${FIREBASE_API_KEY_WEB}"

sed -i "s|%%MAPS_API_KEY_WEB%%|${MAPS_API_KEY_WEB}|g" build/web/index.html

if grep -q '%%MAPS_API_KEY_WEB%%' build/web/index.html; then
  echo "Failed to inject MAPS_API_KEY_WEB into build/web/index.html." >&2
  exit 1
fi
