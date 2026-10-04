# F1 Windows portability — measured Mac baseline

## Scope and isolation

- Fixed engine commit: `edd8912847723707aaf52f538b5f5b5a669c4f82`.
- Isolated checkout: `/Users/eduardoariasbravo/.codex/worktrees/windows-f1-mac-reference/AstroMalik-macOS`.
- Main checkout was not modified. Its existing `docs/diagnostics/` remains unrelated and untracked.
- No Windows patches received or applied yet. Publication uses the documentation-only branch `windows-f1-mac-reference`; no merge, PR, submodule change, global toolchain change or message to another chat.
- Exporter temporarily extends the existing golden test file to reuse its **exact private fixtures and natal constructor**, then restores the original file. All tracked source files are unchanged at delivery.

## Environment and verified results

| Item | Observed result |
|---|---|
| macOS | 27.0.1, 26A434 |
| Swift | Apple Swift6.3.1, swiftlang6.3.1.1.2, clang2100.0.123.102; reported target arm64-apple-macosx28.0 |
| Xcode | 26.4.1, 17E202 |
| Global developer dir | `/Library/Developer/CommandLineTools`, unchanged |
| Test override | `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer` |
| Original debug build | PASS,56.83s |
| Initial CLT test attempt | Could not compile: no such module XCTest. No tests ran in that attempt. |
| Original full suite with Xcode | PASS,522 tests,1 skipped,0 failures,33.719s execution |
| PrimaryDirectionsGoldenTests in full suite | PASS,7 tests,0 failures |
| Skipped test | Explicit opt-in regeneration of golden baseline, not a validation failure |
| Export test | PASS,160 cases,45 transitions |
| Original package script | PASS; initial release build96.77s; rerun before publication passed (see package.log) |
| Bundle verification | `codesign --verify --deep --strict AstroMalik.app` exit0 |
| App executable | 27,178,096 bytes;mtime2026-10-03T17:31:36.398294+02:00 |
| Engine time-zone database | Foundation `TimeZone.timeZoneDataVersion` **2026b** |
| System zoneinfo file | `/usr/share/zoneinfo/+VERSION` **2026c** — not the same database used by Foundation |
| Swiss Ephemeris | 2.10.03 |
| Golden natal backend | **Moshier**, measured Sun returned flags260; default configure(nil) cannot find sepl_18.se1 in `.:/users/ephe2/:/users/ephe/` |

The original engine was not changed to load bundled Swiss files. Windows parity against these golden references must account for this fallback. Comparing a Swiss-file calculation to these Moshier references is a different experiment.

## Outputs

- `time-reference.compact.json`: complete160-case reference plus45 transition records and provenance.
- `selected-reference.compact.json`: nine representative cases with the same metadata.
- `natal-eduardo.json`: **real existing fixture** Eduardo,1976-10-11,20:33,Europe/Madrid,40.4168,-3.7038,Placidus. UTC **1976-10-11T19:33:00Z**,JD **2443063.314583333**.
- `natal-buenosAires.json` and `natal-reykjavik.json`: existing control fixtures from PrimaryDirectionsGoldenTests. Their fixture names identify controls; do not present them as actual people.
- Natal files use the original NatalChart Codable schema, fixed golden UUIDs and createdAt1970-01-01T00:00:00Z. JD/UTC are in the companion time reference because NatalChart does not contain these fields.
- `validation.json`: machine-readable cross-check summary.
- `ReferenceExporter.swift` and `reproduce-export.sh`: reproducible exporter, with no engine algorithm copies.
- The export script creates a temporary hidden backup of the golden test source and removes it after restoration; no redundant original-source copy is published.
- Logs and `.exit` files record actual commands/results, including the unsuccessful CLT attempt.
- `SHA256SUMS`: hashes for delivered files other than this manifest.

## Coverage and semantics

- Europe/Madrid: all offset transitions in1940–1945 and1974–1978; additional Jan15/Jul15 noon controls for every requested year.
- America/Argentina/Buenos_Aires: existing1985 control; transitions1988–1993 and2007–2009.
- America/New_York: transitions1974–1975,2006–2007 and2024, covering historical and more recent DST-rule periods.
- America/Los_Angeles: transitions2024.
- Synthetic transition probes are clearly marked. **They are not invented birth charts.**
- Transitions were discovered on this Mac by sampling Foundation UTC offsets every6h and bisecting each observed change to1s. This includes non-DST political offset changes; it does not rely solely on nextDaylightSavingTimeTransition.
- Each transition contributes local inputs immediately before and after, plus a midpoint in its skipped/repeated wall-clock interval. Every result is computed by the unchanged `julianDayFromLocal` function.
- 137 inputs accepted,23 nonexistent local-time gaps rejected with JulianDayError.invalidDate.
- All22 ambiguous midpoint folds choose the **first occurrence** on this Mac. This is observed Foundation behavior, not a policy explicitly implemented by the engine. Windows must reproduce it or document a deliberate behavioral change.
- `inputDerivedFromUTC` indicates how a boundary input was selected. It is **not** the expected UTC for an ambiguous input: the engine may select the earlier occurrence. Compare the actual `utc` output.
- Accepted JD outputs cross-check exactly in this dataset against `2440587.5 + UTC Unix seconds/86400`. This checks consistency, not independent historical law.
- These are measured platform-parity fixtures, **not independent historical/legal verification** of the time-zone database.

## Reproduction

Run inside the isolated checkout, not the main checkout:

```bash
export DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer
swift build -j 4
swift test -j 4
./docs/windows-f1-reference/reproduce-export.sh
python3 docs/windows-f1-reference/validate.py
swift test -j 4 --filter PrimaryDirectionsGoldenTests
scripts/package_app.sh
codesign --verify --deep --strict AstroMalik.app
stat -f '%Sm %z %N' -t '%Y-%m-%dT%H:%M:%S%z' AstroMalik.app/Contents/MacOS/AstroMalik
git diff --exit-code
```

The export script checks ancestry and engine/test/build inputs against the pinned commit, allowing documentation-only descendant commits. It refuses to overwrite a modified golden test file. An EXIT trap restores the original file and removes its temporary backup. All delivered JSON files use a real LF final byte (0x0A), not a literal backslash-n suffix. Export metadata records Swift and the Foundation tzdata in use. Keep the OS/tzdata provenance when regenerating, since time-zone databases can change.

## Joplin and pending work

Local Web Clipper ports41184–41194 were unavailable and no Joplin process was found. The configured Joplin bridge health check also returned UNAVAILABLE/Connection failed. **No Joplin note was created.**

Pending: receive Windows patches; verify their Mac build/tests and repackage; only then prepare the requested windows-portability PR, with user authorization for the relevant Git operations. This delivery is the original-engine baseline, not validation of a Windows implementation.
