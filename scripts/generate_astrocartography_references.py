#!/usr/bin/env python3
"""Reproduce F0 references with installed pyswisseph, not the Swift adapter.

No package installation, HTTP calls or application calculation. Both bindings
share Swiss algorithms: this is a binding/convention reference, not an independent
astronomical theory. Analytic spherical cases remain the independent line oracle.
"""
from pathlib import Path
import json
import swisseph as swe

ROOT = Path(__file__).resolve().parents[1]
EPHE = ROOT / "Sources/AstroMalik/Resources/ephe"
OUT = ROOT / "Tests/AstroMalikTests/Astrocartography/Fixtures/phase0-swiss-python-reference.json"
BODIES = [("SOL", swe.SUN), ("LUNA", swe.MOON), ("MERCURIO", swe.MERCURY),
          ("VENUS", swe.VENUS), ("MARTE", swe.MARS), ("JUPITER", swe.JUPITER),
          ("SATURNO", swe.SATURN), ("URANO", swe.URANUS),
          ("NEPTUNO", swe.NEPTUNE), ("PLUTON", swe.PLUTO)]
DATES = [(1800, 1, 1, 0), (2000, 1, 1, 12), (2026, 3, 20, 12), (2999, 12, 31, 12)]


def main():
    swe.set_ephe_path(str(EPHE))
    flags = swe.FLG_SWIEPH | swe.FLG_EQUATORIAL
    cases = []
    for year, month, day, hour in DATES:
        jd = swe.julday(year, month, day, hour, swe.GREG_CAL)
        positions = []
        fallback_bodies = []
        for key, body in BODIES:
            values, returned = swe.calc_ut(jd, body, flags)
            if returned & swe.FLG_SWIEPH == 0:
                fallback_bodies.append(key)
            positions.append({"body": key, "rightAscensionDegrees": values[0],
                              "declinationDegrees": values[1], "returnedFlags": returned})
        cases.append({"gregorianUTApprox": f"{year:04}-{month:02}-{day:02} {hour:02}:00:00",
                      "julianDay": jd, "greenwichSiderealDegrees": swe.sidtime(jd) * 15,
                      "positions": positions, "fallbackBodies": fallback_bodies})
    data = {"source": "pyswisseph independent binding, same Swiss algorithms",
            "swissVersion": swe.version, "bindingVersion": swe.__version__,
            "requestedFlags": flags, "convention": "geocentric-apparent-of-date-geometric-center-v1",
            "timeScale": "utcApproximatedAsUT1", "ephemerisResource": "Sources/AstroMalik/Resources/ephe",
            "fallbackPolicy": "Record actual returned flags and explicit per-case fallbackBodies; F1 must emit warnings, not silently claim Swiss file precision.",
            "cases": cases}
    OUT.write_text(json.dumps(data, ensure_ascii=False, indent=2, allow_nan=False) + "\n")
    print(f"Wrote {len(cases)} cases / {len(cases) * len(BODIES)} positions to {OUT.relative_to(ROOT)}")


if __name__ == "__main__":
    main()
