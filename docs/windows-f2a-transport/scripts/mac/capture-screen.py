"""Capture a real, already verified Mac application window; no mockups."""
import argparse
from datetime import datetime, timezone
import hashlib
import json
from pathlib import Path
import platform
import struct
import subprocess


def main():
    p = argparse.ArgumentParser(description=__doc__)
    p.add_argument("--inventory", type=Path, required=True)
    p.add_argument("--output", type=Path, required=True)
    p.add_argument("--screen", required=True)
    p.add_argument("--window-id", type=int, required=True)
    p.add_argument("--mac-commit", required=True)
    p.add_argument("--observed-state", required=True, help="Human/agent checked labels, chart/date, empty-state or data status")
    p.add_argument("--theme", choices=("light", "dark", "system"), required=True)
    args = p.parse_args()
    if platform.system() != "Darwin":
        raise SystemExit("Authentic Mac screenshots require Darwin")
    inventory = json.loads(args.inventory.read_text(encoding="utf-8"))
    screen = next(s for s in inventory["screens"] if s["id"] == args.screen)
    args.output.mkdir(parents=True, exist_ok=True)
    png = args.output / f"{args.screen}.png"
    metadata = args.output / f"{args.screen}.json"
    if png.exists() or metadata.exists():
        raise SystemExit("Existing capture refused; preserve evidence or choose fresh output directory")
    subprocess.run(["screencapture", "-x", "-l", str(args.window_id), str(png)], check=True)
    data = png.read_bytes()
    if data[:8] != b"\x89PNG\r\n\x1a\n" or len(data) < 24:
        raise SystemExit("Not a real PNG; check Screen Recording permission")
    width, height = struct.unpack(">II", data[16:24])
    if width < 900 or height < 600:
        raise SystemExit("Unexpected window dimensions; inspect the captured window")
    record = {"kind": "authentic-mac-window-capture", "screen": screen, "macCommit": args.mac_commit,
              "capturedAt": datetime.now(timezone.utc).isoformat(), "operatingSystem": platform.platform(),
              "windowID": args.window_id, "observedState": args.observed_state, "theme": args.theme,
              "width": width, "height": height, "sha256": hashlib.sha256(data).hexdigest()}
    metadata.write_text(json.dumps(record, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    print(f"Captured actual window: {png}; {width}×{height}; verify image visually before acceptance")


if __name__ == "__main__":
    main()
