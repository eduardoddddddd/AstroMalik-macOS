#!/usr/bin/env bash
# Run only on the Mac. Paths explicit; no personal database is opened.
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
exec python3 "$SCRIPT_DIR/export-fixtures.py" "$@"

