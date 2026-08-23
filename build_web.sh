#!/bin/bash
set -e
export $(grep -v '^#' .env | xargs)
flutter build web
sed -i "s|%%MAPS_API_KEY_WEB%%|$MAPS_API_KEY_WEB|g" build/web/index.html