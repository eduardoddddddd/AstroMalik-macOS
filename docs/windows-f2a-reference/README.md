# F2a authentic Mac reference export

This directory contains the Mac-produced comparison set for F2a. The calculation engine and app sources were not changed to create these references; the source trees used for the CLI and F3 RPC are identified in the fixture manifest. The original baseline is `edd8912847723707aaf52f538b5f5b5a669c4f82`; the RPC side is PR #3 HEAD `a0e2369a224b6dcf98c6349cc5bc601d8e0a40a8`.

## Deliverables

- `fixtures/mac/f2/`: 70 authentic output cases, input manifest, per-file SHA-256 list, raw CLI/RPC evidence, observed hello/backend metadata, source/resource/binary hashes, and the exact temporary Mac JSONL host wrapper source used by the RPC export.
- `cli-backend-probe-15.json`: 15 real `swe_calc_ut` observations (five approved dates × Sun/Moon/Pluto) from the original Mac CLI; all returned Swiss-file flags, establishing `swiss-files` rather than inferring it from a hello label.
- `tools/BackendProbe.swift`, `tools/F2BackendProbeTests.swift`, and logs: probe implementation and captured build/probe/export outputs.

The transport's final case, `transits.timelineSvg`, is included. The export used the original CLI binary and a separately built RPC wrapper linked against the PR #3 library, with isolated temporary user data and networking disabled. The Swiss Ephemeris `.se1` files and `corpus.db` were checked against both actual SwiftPM resource bundles; both bundle hash maps contain seven entries. The backend probe contains 15 successful observations.

## Verification

`fixtures/mac/f2/manifest.json` lists exactly 70 unique case IDs. `fixtures/mac/f2/SHA256SUMS` covers every file in the fixture directory except the checksum list itself. Verify with:

```sh
cd docs/windows-f2a-reference/fixtures/mac/f2
shasum -a 256 -c SHA256SUMS
```

No executable binaries or user database are included in this documentation branch. Runtime databases and the superseded local 69-case scratch export are generation scratch only and are intentionally excluded.
