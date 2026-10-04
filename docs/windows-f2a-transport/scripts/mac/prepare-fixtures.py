"""Prepare documented F2 inputs, never reference outputs. Stdlib only."""
from pathlib import Path
import json

ROOT = Path(__file__).resolve().parents[2]
DEST = ROOT / "fixtures/inputs/f2"


def main():
    DEST.mkdir(parents=True, exist_ok=True)
    charts = [json.loads((ROOT / f"fixtures/mac/f1/natal-{key}.json").read_text(encoding="utf-8"))
              for key in ("eduardo", "buenosAires", "reykjavik")]
    requests = json.loads((ROOT / "fixtures/windows/f3/requests.json").read_text(encoding="utf-8"))["requests"]
    probe = next(c for c in json.loads((ROOT / "fixtures/mac/f1/time-reference.compact.json").read_text(encoding="utf-8"))["cases"]
                 if c["id"] == "madrid-1940-7")
    war = {k: charts[0][k] for k in ("latitude", "longitude", "placeName", "houseSystem")}
    war.update(id="44444444-4444-4444-4444-444444444444", name="Control horario Madrid 1940 (no biografía)",
               birthDate=probe["input"]["birthDate"], birthTime=probe["input"]["birthTime"], timezone=probe["input"]["timezoneName"])
    cases = []
    commands = ["natal", "transits", "progressions", "primary-directions", "solar-arc", "profections", "firdaria",
                "zodiacal-releasing", "solar-return", "lunar-return", "cross-personal", "astrocartography", "monthly"]
    chart_ids = [(key, chart["id"]) for key, chart in zip(("eduardo", "buenosAires", "reykjavik"), charts)]
    chart_ids.append(("madrid-war1940-control", war["id"]))
    for key, identifier in chart_ids:
        for command in commands:
            argv = [command, "--chart", identifier, "--date", "2026-10-04", "--format", "json", "--output", "stdout",
                    "--narrative", "none", "--no-network", "--user-db", "{userDb}"]
            if command == "transits":
                argv += ["--from", "2026-10-04", "--to", "2027-04-04"]
            elif command == "monthly":
                argv += ["--month", "2026-10"]
            identifier_case = f"{command}-{key}"
            cases.append({"id": identifier_case, "transport": "cli", "expected": f"outputs/{identifier_case}.json",
                          "argv": argv, "comparison": {"rules": [], "arrays": []}})
    cases.insert(0, {"id": "natal-war1940-control", "transport": "rpc", "expected": "outputs/natal-war1940-control.json",
                     "request": {"method": "natal.compute", "params": war}, "comparison": {"rules": [], "arrays": []}})
    for method in ("horary.compute", "rectification.run"):
        source = next(r for r in requests if r["method"] == method)
        key = method.replace(".", "-")
        cases.append({"id": key, "transport": "rpc", "expected": f"outputs/{key}.json",
                      "request": {"method": method, "params": source["params"]}, "comparison": {"rules": [], "arrays": []}})
    cases.append({"id": "synastry-eduardo-buenosAires", "transport": "rpc", "expected": "outputs/synastry-eduardo-buenosAires.json",
                  "request": {"method": "synastry", "params": {"chartA": charts[0], "chartB": charts[1]}},
                  "comparison": {"rules": [], "arrays": []}})
    document = {"schemaVersion": 1, "kind": "input-template-not-reference", "provenance": {"platform": "macOS", "ephemerisBackend": "swiss-files"},
                "inputs": {"charts": charts, "warControl": {"request": war, "sourceProbe": probe,
                           "meaning": "Temporal control F1 Madrid 1940; coordinates reused from Eduardo; not a birth biography"},
                           "referenceDate": "2026-10-04T00:00:00Z", "transitRange": {"from": "2026-10-04T00:00:00Z", "to": "2027-04-04T00:00:00Z"},
                           "sources": ["fixtures/mac/f1/natal-eduardo.json", "fixtures/mac/f1/natal-buenosAires.json", "fixtures/mac/f1/natal-reykjavik.json",
                                       "fixtures/mac/f1/time-reference.compact.json#cases/madrid-1940-7", "fixtures/windows/f3/requests.json (inputs only)"]},
                "cases": cases}
    path = DEST / "manifest-template.json"
    if path.exists():
        raise SystemExit("Template already exists; preserve reviewed comparison policies. Delete explicitly before regeneration.")
    path.write_text(json.dumps(document, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    print(f"Prepared {len(cases)} cases in {path}; no Mac outputs generated")


if __name__ == "__main__":
    main()
