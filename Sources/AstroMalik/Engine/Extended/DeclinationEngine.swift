import Foundation
import CSwissEph

final class DeclinationEngine {
    private let outOfBoundsLimit = 23.0 + 26.0 / 60.0

    func declinations(
        chart: Chart,
        orb: Double = NatalExtendedAnalysisConfiguration.default.declinationOrb
    ) throws -> DeclinationResult {
        let jd = try ExtendedAstro.birthJulianDay(for: chart)
        var bodies: [BodyDeclination] = []
        for key in ExtendedAstro.planetAndNodeKeys {
            guard let declination = try declination(for: key, jd: jd) else { continue }
            let out = abs(declination) > outOfBoundsLimit
            bodies.append(BodyDeclination(
                key: key,
                label: ExtendedAstro.planetLabel(for: key),
                declination: ExtendedAstro.rounded(declination, places: 5),
                formatted: ExtendedAstro.formattedDeclination(declination),
                outOfBounds: out
            ))
        }

        var pairs: [DeclinationPair] = []
        for i in 0..<bodies.count {
            for j in (i + 1)..<bodies.count {
                let a = bodies[i]
                let b = bodies[j]
                let declOrb = abs(abs(a.declination) - abs(b.declination))
                guard declOrb <= orb else { continue }
                if a.declination.sign == b.declination.sign {
                    pairs.append(makePair(.parallel, a: a, b: b, orb: declOrb))
                } else {
                    pairs.append(makePair(.contraParallel, a: a, b: b, orb: declOrb))
                }
            }
        }

        return DeclinationResult(
            bodies: bodies,
            pairs: pairs.sorted { $0.orb == $1.orb ? $0.id < $1.id : $0.orb < $1.orb },
            outOfBounds: bodies.filter(\.outOfBounds)
        )
    }

    private func declination(for key: String, jd: Double) throws -> Double? {
        if key == "NODO_SUR" {
            guard let north = try declination(for: "NODO_NORTE", jd: jd) else { return nil }
            return -north
        }
        guard let planetID = planetID(for: key) else { return nil }
        var xx = [Double](repeating: 0, count: 6)
        var serr = [CChar](repeating: 0, count: 256)
        let flags = SEFLG_SPEED | SEFLG_EQUATORIAL
        let rc = swe_calc_ut(jd, planetID, flags, &xx, &serr)
        guard rc >= 0 else { throw NatalExtendedError.swissCalculation(key, String(cString: serr)) }
        return xx[1]
    }

    private func planetID(for key: String) -> Int32? {
        switch key {
        case "SOL": return SE_SUN
        case "LUNA": return SE_MOON
        case "MERCURIO": return SE_MERCURY
        case "VENUS": return SE_VENUS
        case "MARTE": return SE_MARS
        case "JUPITER": return SE_JUPITER
        case "SATURNO": return SE_SATURN
        case "URANO": return SE_URANUS
        case "NEPTUNO": return SE_NEPTUNE
        case "PLUTON": return SE_PLUTO
        case "NODO_NORTE": return SE_TRUE_NODE
        default: return nil
        }
    }

    private func makePair(_ kind: DeclinationAspectKind, a: BodyDeclination, b: BodyDeclination, orb: Double) -> DeclinationPair {
        DeclinationPair(
            id: "\(kind.rawValue)-\(a.key)-\(b.key)",
            kind: kind,
            bodyAKey: a.key,
            bodyALabel: a.label,
            bodyBKey: b.key,
            bodyBLabel: b.label,
            orb: ExtendedAstro.rounded(orb, places: 3)
        )
    }
}
