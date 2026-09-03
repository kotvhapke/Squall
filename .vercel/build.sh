#!/usr/bin/env bash
#
# Squall — Vercel build script (Linux/macOS CI)
#
# Produces the deployable site in build/web:
#   build/web/index.html          -> landing page (squall-landing.html)
#   build/web/app/index.html      -> Flutter web app
#   build/web/app/main.dart.js    -> compiled Flutter app
#
# Public values are read from Vercel env vars (see README/vercel docs):
#   SUPABASE_URL, SUPABASE_ANON_KEY, LIVEKIT_URL
#
set -euo pipefail

# 1) Install a pinned Flutter SDK if not already available
if ! command -v flutter >/dev/null 2>&1; then
  echo "==> Installing Flutter $FLUTTER_VERSION (pinned)"
  FLUTTER_VERSION="${FLUTTER_VERSION:-3.44.9}"
  FLUTTER_URL="https://storage.googleapis.com/flutter_infra_release/releases/stable/linux/flutter_linux_${FLUTTER_VERSION}-stable.tar.xz"
  mkdir -p /opt/flutter
  curl -fsSL "$FLUTTER_URL" -o /tmp/flutter.tar.xz
  tar -xf /tmp/flutter.tar.xz -C /opt/flutter --strip-components=1
  export PATH="/opt/flutter/bin:$PATH"
  flutter --version
fi

# 2) Resolve dependencies (use the committed pubspec.lock)
flutter pub get

# 3) Build Flutter web with public env values
flutter build web \
  --release \
  --dart-define=SUPABASE_URL="${SUPABASE_URL:-}" \
  --dart-define=SUPABASE_ANON_KEY="${SUPABASE_ANON_KEY:-}" \
  --dart-define=LIVEKIT_URL="${LIVEKIT_URL:-wss://localhost:7880}"

# 4) Copy compiled Flutter app into build/web/app/ (Flutter writes to build/web)
#    Flutter already outputs to build/web, so we wrap it in /app/.
rm -rf build/web/app
mkdir -p build/web/app

# Move every Flutter artifact except our soon-to-be landing index.html.
# Simpler and deterministic: copy everything that exists right now.
for entry in build/web/*; do
  name="$(basename "$entry")"
  if [ "$name" != "app" ]; then
    cp -r "$entry" "build/web/app/$name"
  fi
done

# 5) Overwrite root index.html with the landing page
cp squall-landing.html build/web/index.html

echo "==> Done. build/web is ready for Vercel."
ls -la build/web
ls -la build/web/app | head -20