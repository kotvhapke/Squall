#!/usr/bin/env bash
#
# Squall — Vercel build script
#
# Produces the deployable site in build/web:
#   build/web/index.html          -> landing page (squall-landing.html)
#   build/web/app/index.html      -> Flutter web app
#   build/web/app/main.dart.js    -> compiled Flutter app
#
# Public values are read from Vercel env vars:
#   SUPABASE_URL, SUPABASE_ANON_KEY, LIVEKIT_URL
#
set -euo pipefail

echo "==> Vercel build for Squall"

# 1) Install a pinned Flutter SDK if not already available
if ! command -v flutter >/dev/null 2>&1; then
  FLUTTER_VERSION="${FLUTTER_VERSION:-3.44.9}"
  echo "==> Installing Flutter ${FLUTTER_VERSION} (pinned)"
  FLUTTER_HOME="$HOME/flutter"
  mkdir -p "$FLUTTER_HOME"
  curl -fsSL \
    "https://storage.googleapis.com/flutter_infra_release/releases/stable/linux/flutter_linux_${FLUTTER_VERSION}-stable.tar.xz" \
    -o /tmp/flutter.tar.xz
  tar -xf /tmp/flutter.tar.xz -C "$FLUTTER_HOME" --strip-components=1
  export PATH="$FLUTTER_HOME/bin:$PATH"
fi

# 2) Git safety: flutter binary is a git repo, Vercel runs as root
git config --global --add safe.directory "$(dirname $(which flutter))/.." 2>/dev/null || true
git config --global --add safe.directory /vercel/flutter 2>/dev/null || true
git config --global --add safe.directory "$HOME/flutter" 2>/dev/null || true

# 3) Disable analytics/welcome prompts
flutter config --no-analytics >/dev/null 2>&1 || true

# 4) Resolve dependencies (uses committed pubspec.lock)
echo "==> Running flutter pub get"
flutter pub get

# 5) Build Flutter web with public env values from Vercel vars
echo "==> Building Flutter web"
flutter build web \
  --release \
  --dart-define=SUPABASE_URL="${SUPABASE_URL:-}" \
  --dart-define=SUPABASE_ANON_KEY="${SUPABASE_ANON_KEY:-}" \
  --dart-define=LIVEKIT_URL="${LIVEKIT_URL:-wss://localhost:7880}"

# 6) Wrap the Flutter app into build/web/app/
echo "==> Wrapping Flutter app into build/web/app"
rm -rf build/web/app
mkdir -p build/web/app
for entry in build/web/*; do
  name="$(basename "$entry")"
  if [ "$name" != "app" ]; then
    cp -r "$entry" "build/web/app/$name"
  fi
done

# 7) Overwrite root index.html with the landing page
echo "==> Replacing root index.html with landing page"
cp squall-landing.html build/web/index.html

echo "==> Done. build/web is ready for Vercel."
ls -la build/web
ls -la build/web/app | head -20