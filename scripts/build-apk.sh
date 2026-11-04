#!/bin/bash
# Builds the release APK that talks to the server (the default address in lib/main.dart, or
# the one in API_BASE_URL). The file is build/app/outputs/flutter-apk/app-release.apk.
#
#   scripts/build-apk.sh
#   API_BASE_URL=https://other.example/api/v1 scripts/build-apk.sh
set -euo pipefail

export PATH="$HOME/flutter_new/bin:$PATH"
cd "$(dirname "$0")/.."

# google-services.json made for another application id breaks the Android build, so it is
# set aside while building and put back afterwards.
JSON=android/app/google-services.json
if [ -f "$JSON" ] && ! grep -q '"package_name": "io.github.binn2000.socialhub"' "$JSON"; then
  mv "$JSON" "$JSON.aside"
  trap 'mv "$JSON.aside" "$JSON"' EXIT
fi

if [ -n "${API_BASE_URL:-}" ]; then
  flutter build apk --release --dart-define=API_BASE_URL="$API_BASE_URL"
else
  flutter build apk --release
fi
ls -la build/app/outputs/flutter-apk/app-release.apk
