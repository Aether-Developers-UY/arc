#!/usr/bin/env bash
# Builds the web app for Cloudflare (Workers Builds). The build machine has
# no Flutter, so this installs the same version used in development.
#
#   API_URL=https://servidor/api bash arc_app/scripts/build_web.sh
#
# Output: arc_app/build/web (wrangler.jsonc serves it).
set -euo pipefail

FLUTTER_VERSION="3.44.1"
cd "$(dirname "$0")/.."

if ! command -v flutter >/dev/null 2>&1; then
  echo "Installing Flutter $FLUTTER_VERSION..."
  git clone --depth 1 --branch "$FLUTTER_VERSION" https://github.com/flutter/flutter.git "$HOME/flutter"
  export PATH="$HOME/flutter/bin:$PATH"
fi

flutter config --no-analytics >/dev/null
flutter --version

if [ -n "${API_URL:-}" ]; then
  echo "Backend: $API_URL"
  flutter build web --release --dart-define=API_URL="$API_URL"
else
  echo "WARNING: API_URL is not set; the app will look for the backend on localhost."
  flutter build web --release
fi
