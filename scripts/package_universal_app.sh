#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DIST_DIR="${DIST_DIR:-$ROOT_DIR/dist}"
APP_ROOT="$DIST_DIR/AstroMalik.app"
CLI_PATH="$DIST_DIR/astromalik-cli"
CONTENTS_DIR="$APP_ROOT/Contents"
MACOS_DIR="$CONTENTS_DIR/MacOS"
RESOURCES_DIR="$CONTENTS_DIR/Resources"

cd "$ROOT_DIR"
mkdir -p "$DIST_DIR"
rm -rf "$APP_ROOT" "$CLI_PATH" \
  "$DIST_DIR/AstroMalik-macOS-universal.zip" "$DIST_DIR/AstroMalik-macOS-universal.zip.sha256" \
  "$DIST_DIR/astromalik-cli-macOS-universal.zip" "$DIST_DIR/astromalik-cli-macOS-universal.zip.sha256"

echo "▶ Compilando AstroMalik para Apple Silicon (arm64)…"
swift build -c release --arch arm64
ARM_BIN_DIR="$(swift build -c release --arch arm64 --show-bin-path)"

echo "▶ Compilando AstroMalik para Mac Intel (x86_64)…"
swift build -c release --arch x86_64
INTEL_BIN_DIR="$(swift build -c release --arch x86_64 --show-bin-path)"

mkdir -p "$MACOS_DIR" "$RESOURCES_DIR"
lipo -create "$ARM_BIN_DIR/AstroMalik" "$INTEL_BIN_DIR/AstroMalik" -output "$MACOS_DIR/AstroMalik"
lipo -create "$ARM_BIN_DIR/astromalik-cli" "$INTEL_BIN_DIR/astromalik-cli" -output "$CLI_PATH"
chmod +x "$MACOS_DIR/AstroMalik" "$CLI_PATH"

cp "$ROOT_DIR/Info.plist" "$CONTENTS_DIR/Info.plist"

# Los recursos son independientes de la arquitectura; se copian una sola vez.
if [[ -d "$ARM_BIN_DIR/AstroMalik_AstroMalik.bundle" ]]; then
  cp -R "$ARM_BIN_DIR/AstroMalik_AstroMalik.bundle" "$RESOURCES_DIR/AstroMalik_AstroMalik.bundle"
fi

if [[ -d "$ROOT_DIR/Resources/migrations" ]]; then
  mkdir -p "$RESOURCES_DIR/AstroMalik_AstroMalik.bundle/migrations"
  cp "$ROOT_DIR"/Resources/migrations/*.sql "$RESOURCES_DIR/AstroMalik_AstroMalik.bundle/migrations/"
fi

if [[ -f "$ROOT_DIR/Resources/pd_contextual_prompt.md" ]]; then
  cp "$ROOT_DIR/Resources/pd_contextual_prompt.md" "$RESOURCES_DIR/AstroMalik_AstroMalik.bundle/"
fi

ICON_PATH=""
if [[ -f "$ROOT_DIR/AstroMalik.icns" ]]; then
  ICON_PATH="$ROOT_DIR/AstroMalik.icns"
elif find "$ROOT_DIR" -maxdepth 2 -name '*.icns' -print -quit >/dev/null 2>&1; then
  ICON_PATH="$(find "$ROOT_DIR" -maxdepth 2 -name '*.icns' -print -quit)"
fi
if [[ -n "$ICON_PATH" ]]; then cp "$ICON_PATH" "$RESOURCES_DIR/"; fi

# Firma ad-hoc gratuita. No identifica al desarrollador ni sustituye la notarización.
codesign --force --deep --sign - "$APP_ROOT"
codesign --force --sign - "$CLI_PATH"
xattr -dr com.apple.quarantine "$APP_ROOT" "$CLI_PATH" 2>/dev/null || true

"$ROOT_DIR/scripts/verify_universal_app.sh" "$APP_ROOT" "$CLI_PATH"

echo "▶ Creando ZIP de distribución…"
ditto -c -k --sequesterRsrc --keepParent "$APP_ROOT" "$DIST_DIR/AstroMalik-macOS-universal.zip"
ditto -c -k --sequesterRsrc --keepParent "$CLI_PATH" "$DIST_DIR/astromalik-cli-macOS-universal.zip"
(
  cd "$DIST_DIR"
  shasum -a 256 "AstroMalik-macOS-universal.zip" > "AstroMalik-macOS-universal.zip.sha256"
  shasum -a 256 "astromalik-cli-macOS-universal.zip" > "astromalik-cli-macOS-universal.zip.sha256"
)

echo
echo "✅ Aplicación universal: $APP_ROOT"
echo "✅ CLI universal:        $CLI_PATH"
echo "✅ ZIP para compartir:   $DIST_DIR/AstroMalik-macOS-universal.zip"
echo "✅ Checksum SHA-256:      $DIST_DIR/AstroMalik-macOS-universal.zip.sha256"
echo "✅ ZIP del CLI:           $DIST_DIR/astromalik-cli-macOS-universal.zip"
echo "ℹ️  Firma ad-hoc: los usuarios deberán autorizar la primera apertura en macOS."
