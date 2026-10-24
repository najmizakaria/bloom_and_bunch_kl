#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
node tool/configure_ios.cjs
flutter build ios "$@"
