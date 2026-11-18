#!/bin/bash
set -euo pipefail

cd "$(dirname "$0")"
flutter build web
node tool/configure_web.cjs
