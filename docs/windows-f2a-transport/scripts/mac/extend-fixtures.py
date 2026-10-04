"""Add F5-consumed RPC calculations and real renderers to F2 input manifest."""
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]


def main():
    path = ROOT / "fixtures/inputs/f2/manifest-template.json"
    manifest = json.loads(path.read_text(encoding="utf-8"))
    existing = {c["id"] for c in manifest["cases"]}
    def add(identifier, method, params):
        if identifier not in existing:
            manifest["cases"].append({"id": identifier, "transport": "rpc", "expected": f"outputs/{identifier}.json",
                                      "request": {"method": method, "params": params}, "comparison": {"rules": [], "arrays": []}})
    keys = ("eduardo", "buenosAires", "reykjavik")
    charts = manifest["inputs"]["charts"]
    for key, chart in zip(keys, charts):
        civil = {k: chart[k] for k in ("id", "name", "birthDate", "birthTime", "timezone", "latitude", "longitude", "placeName", "houseSystem")}
        add("natal-compute-" + key, "natal.compute", civil)
    edu = {"chart": charts[0]}
    add("natal-extended-eduardo", "natal.extended", edu)
    add("natal-wheelSvg-eduardo", "natal.wheelSvg", dict(edu, size=600))
    add("transits-timelineSvg-eduardo", "transits.timelineSvg", dict(edu, **manifest["inputs"]["transitRange"], width=800, height=400))
    add("synastry-doubleWheelSvg-eduardo-buenosAires", "synastry.doubleWheelSvg", {"chartA": charts[0], "chartB": charts[1], "size": 700})
    add("primaryDirections-speculum-eduardo", "primaryDirections.speculum", edu)
    add("astrocartography-lines-eduardo", "astrocartography.lines", edu)
    add("astrocartography-place-madrid-eduardo", "astrocartography.place", dict(edu, latitude=charts[0]["latitude"], longitude=charts[0]["longitude"], timezone=charts[0]["timezone"]))
    add("astrocartography-mapSvg-eduardo", "astrocartography.mapSvg", edu)
    add("ephemeris-day", "ephemeris.day", {"date": "2026-10-04", "timezone": "Europe/Madrid"})
    add("ephemeris-month", "ephemeris.month", {"year": 2026, "month": 10, "timezone": "Europe/Madrid"})
    requests = json.loads((ROOT / "fixtures/windows/f3/requests.json").read_text(encoding="utf-8"))["requests"]
    report = next(r for r in requests if r["method"] == "reports.html")
    add("reports-html-eduardo", "reports.html", report["params"])
    manifest["inputs"]["reportMeaning"] = "Fixed reports.html data payload from F3 request input; expected HTML/SVG must be rendered on Mac. Not a Mac output itself."
    path.write_text(json.dumps(manifest, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    print(f"F2 template now has {len(manifest['cases'])} cases; reviewed policies preserved")


if __name__ == "__main__":
    main()
