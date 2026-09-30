#!/usr/bin/env python3
"""Conservative lexical guard: direct Swiss calls must stay in the facade.

Not an AST/security proof. Also flags comments mentioning raw function calls;
do not add exemptions merely to silence a new production call.
"""
from pathlib import Path
import re
import sys

ROOT = Path(__file__).resolve().parents[1]
FACADE = ROOT / "Sources/AstroMalik/Engine/Ephemeris/SwissEphemerisAccess.swift"
CALL = re.compile(r"(?:(CSwissEph|SwissEphemerisAccess)\s*\.\s*)?\b(swe_[a-z0-9_]+)\s*\(")


def violations(text):
    return [(text.count("\n", 0, m.start()) + 1, m.group(2))
            for m in CALL.finditer(text) if m.group(1) != "SwissEphemerisAccess"]


def main():
    found = []
    for folder in ("Sources", "Tests"):
        for path in sorted((ROOT / folder).rglob("*.swift")):
            if path == FACADE:
                continue
            for line, name in violations(path.read_text()):
                found.append(f"{path.relative_to(ROOT)}:{line}: raw {name}")
    if found:
        print("\n".join(found), file=sys.stderr)
        return 1
    print("Swiss access guard: OK (Sources + Tests, facade only)")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
