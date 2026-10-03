#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/../.."
BASE=edd8912847723707aaf52f538b5f5b5a669c4f82
# A documentation-only descendant is allowed; changed engine/test inputs are not.
git merge-base --is-ancestor "$BASE" HEAD || { echo 'Not based on the pinned commit'; exit 2; }
git diff --quiet "$BASE" -- Package.swift Package.resolved Info.plist Sources Tests scripts Resources || { echo 'Engine/test/build inputs differ from pinned baseline'; exit 2; }
TARGET=Tests/AstroMalikTests/PrimaryDirectionsGoldenTests.swift
git diff --quiet -- "$TARGET" || { echo 'Test source has changes; refusing to overwrite'; exit 2; }
OUT="$PWD/docs/windows-f1-reference"
BACKUP="$(mktemp "$OUT/.golden-backup.XXXXXX")"
cp "$TARGET" "$BACKUP"
cleanup() {
    cp "$BACKUP" "$TARGET"
    rm -f "$BACKUP"
}
trap cleanup EXIT
cat "$OUT/ReferenceExporter.swift" >> "$TARGET"
export DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer
export F1_REFERENCE_DIR="$OUT"
export F1_SWIFT_VERSION="$(swift --version | tr '\n' ' ')"
swift test -j 4 --filter PrimaryDirectionsGoldenTests.testExportF1MacReferences
