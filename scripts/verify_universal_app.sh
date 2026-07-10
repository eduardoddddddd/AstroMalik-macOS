#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
APP_ROOT="${1:-$ROOT_DIR/dist/AstroMalik.app}"
CLI_PATH="${2:-$ROOT_DIR/dist/astromalik-cli}"
APP_BINARY="$APP_ROOT/Contents/MacOS/AstroMalik"

fail() { echo "❌ $*" >&2; exit 1; }

[[ -x "$APP_BINARY" ]] || fail "No existe el ejecutable de la app: $APP_BINARY"
[[ -x "$CLI_PATH" ]] || fail "No existe el CLI universal: $CLI_PATH"
[[ -f "$APP_ROOT/Contents/Info.plist" ]] || fail "Falta Info.plist"
[[ -d "$APP_ROOT/Contents/Resources/AstroMalik_AstroMalik.bundle" ]] || fail "Falta el bundle de recursos"

lipo "$APP_BINARY" -verify_arch arm64 x86_64 || fail "La app no contiene arm64 y x86_64"
lipo "$CLI_PATH" -verify_arch arm64 x86_64 || fail "El CLI no contiene arm64 y x86_64"
plutil -lint "$APP_ROOT/Contents/Info.plist" >/dev/null
codesign --verify --deep --strict "$APP_ROOT"
codesign --verify --strict "$CLI_PATH"

echo "✅ App: $(lipo -archs "$APP_BINARY")"
echo "✅ CLI: $(lipo -archs "$CLI_PATH")"
echo "✅ Info.plist, recursos y firma ad-hoc verificados"
