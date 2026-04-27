#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

swift build -c release
BIN_DIR="$(swift build -c release --show-bin-path)"

APP_ROOT="$ROOT_DIR/AstroMalik.app"
CONTENTS_DIR="$APP_ROOT/Contents"
MACOS_DIR="$CONTENTS_DIR/MacOS"
RESOURCES_DIR="$CONTENTS_DIR/Resources"

rm -rf "$APP_ROOT"
mkdir -p "$MACOS_DIR" "$RESOURCES_DIR"

cp "$BIN_DIR/AstroMalik" "$MACOS_DIR/AstroMalik"
cp "$ROOT_DIR/Info.plist" "$CONTENTS_DIR/Info.plist"

if [[ -d "$BIN_DIR/AstroMalik_AstroMalik.bundle" ]]; then
  cp -R "$BIN_DIR/AstroMalik_AstroMalik.bundle" "$RESOURCES_DIR/AstroMalik_AstroMalik.bundle"
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

if [[ -n "$ICON_PATH" ]]; then
  cp "$ICON_PATH" "$RESOURCES_DIR/"
fi

codesign --force --deep --sign - "$APP_ROOT"
xattr -dr com.apple.quarantine "$APP_ROOT" || true

echo "App empaquetada en: $APP_ROOT"
