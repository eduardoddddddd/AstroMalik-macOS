# F1 — macOS validation of windows-portability

## Inputs and minimal Mac corrections

- Original engine: `edd8912847723707aaf52f538b5f5b5a669c4f82`.
- Published baseline references: `windows-f1-mac-reference`, `0c7aa75c2c2c93714ff31b3faddadac1435e640d`.
- Windows portability inputs: `eb1fb5a1f4c232ff8712ebaff8d7c2e476359a28`, then `bdb125f5a5564bc0007b8848bb672cff79b1cea0` (return display-name helper relocation).
- Isolated Mac checkout: `/Users/eduardoariasbravo/.codex/worktrees/windows-portability-mac-validation/AstroMalik-macOS`.

Mac-only integration fixes are limited to:

1. Delete the one-comment `Views/MonthlySummaryNoteBuilder.swift` placeholder. Its basename collided with the extracted `Services/MonthlySummaryNoteBuilder.swift`, producing multiple producers for the Swift object file.
2. Delete the equivalent `Views/TransitsNoteBuilder.swift` placeholder for the same reason.
3. Handle the new `.request` credential source in SettingsView's exhaustive switch, displaying `Sesión actual`.

No mathematical engine, Swiss C library, saved golden values or Windows conditional calculation path was modified by these fixes. The main Mac checkout and the baseline-reference branch were not changed.

## Verification

All Swift build/test/package commands use `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer`; the global Command Line Tools selection is unchanged.

- Debug build: PASS,23.70s.
- Full tests: **522 tests,1 intentional golden-regeneration skip,0 failures**,32.913s execution.
- PrimaryDirectionsGoldenTests: **7 tests,0 failures**.
- Additional exact reference comparison: **160 time cases,45 transition records,3 natal JSON objects**, all identical to the published original-engine baseline (metadata intentionally differs).
- `PrimaryDirectionsGolden.json` was **not regenerated** and remains byte-identical to the original commit: SHA256 `ce6ee220938b7d58fc2a06e3e709a66da196ce57ba5c1c3f5875a2b9bb67a16a`.
- See `validation.json` for release/package result, executable timestamp, hash and codesign verification.

Environment: macOS27.0.1(26A434),Apple Swift6.3.1,Xcode26.4.1. Foundation tzdata2026b. The original golden setup uses Swiss Ephemeris2.10.03 with Moshier fallback; the candidate uses the same backend.

The additional reference check temporarily appended the baseline exporter to the existing golden test file to reuse its private fixture/natal constructor, wrote **separate** comparison JSON, and restored the test source. It did not invoke the golden-regeneration test or modify the golden resource.

These results establish parity for the tested Mac paths, not a claim that every possible behavior is covered or that Windows execution was tested in this checkout. Windows validation remains with its own task.

## Reproduce the normal Mac checks

```bash
export DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer
swift build -j 4
swift test -j 4
scripts/package_app.sh
codesign --verify --deep --strict AstroMalik.app
stat -f '%Sm %z %N' -t '%Y-%m-%dT%H:%M:%S%z' AstroMalik.app/Contents/MacOS/AstroMalik
git diff --exit-code edd8912847723707aaf52f538b5f5b5a669c4f82 -- Tests/AstroMalikTests/PrimaryDirectionsGolden.json
```

Full local command logs and parity exports are retained in this checkout's `docs/windows-f1-mac-validation/`; only this concise report and validation metadata are added to the portability fix commit. Baseline full references, exporter and logs remain on `windows-f1-mac-reference`.

Per the latest user instruction, Joplin is no longer used or checked. F1 documentation stays in the repositories. No merge, PR or cross-chat message was performed by this validation task.
