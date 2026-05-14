import Foundation

final class ReceptionEngine {
    func receptions(chart: Chart) -> [MutualReception] {
        let bodies = ExtendedAstro.bodies(in: chart, keys: ExtendedAstro.traditionalPlanetKeys)
        var result: [MutualReception] = []
        for i in 0..<bodies.count {
            for j in (i + 1)..<bodies.count {
                let a = bodies[i]
                let b = bodies[j]
                if inDomicile(a, of: b) && inDomicile(b, of: a) {
                    result.append(make(.domicile, a: a, b: b, detail: "\(a.label) está en domicilio de \(b.label) y \(b.label) en domicilio de \(a.label)."))
                }
                if inExaltation(a, of: b) && inExaltation(b, of: a) {
                    result.append(make(.exaltation, a: a, b: b, detail: "\(a.label) está en exaltación de \(b.label) y \(b.label) en exaltación de \(a.label)."))
                }
                let domicileExaltation = inDomicile(a, of: b) && inExaltation(b, of: a)
                let exaltationDomicile = inExaltation(a, of: b) && inDomicile(b, of: a)
                if domicileExaltation || exaltationDomicile {
                    let detail = domicileExaltation
                        ? "\(a.label) está en domicilio de \(b.label); \(b.label) está en exaltación de \(a.label)."
                        : "\(a.label) está en exaltación de \(b.label); \(b.label) está en domicilio de \(a.label)."
                    result.append(make(.mixed, a: a, b: b, detail: detail))
                }
            }
        }
        return result.sorted { lhs, rhs in
            if lhs.kind.rawValue != rhs.kind.rawValue { return lhs.kind.rawValue < rhs.kind.rawValue }
            return lhs.id < rhs.id
        }
    }

    private func inDomicile(_ guest: PlanetBody, of host: PlanetBody) -> Bool {
        EssentialDignityEngine.domicileRuler(of: ExtendedAstro.signIndex(guest.longitude)) == host.key
    }

    private func inExaltation(_ guest: PlanetBody, of host: PlanetBody) -> Bool {
        EssentialDignityEngine.isInExaltationOf(guestLongitude: guest.longitude, hostPlanet: host.key)
    }

    private func make(_ kind: MutualReceptionKind, a: PlanetBody, b: PlanetBody, detail: String) -> MutualReception {
        let keys = [a.key, b.key].sorted().joined(separator: "-")
        return MutualReception(
            id: "\(kind.rawValue)-\(keys)",
            kind: kind,
            planetAKey: a.key,
            planetALabel: a.label,
            planetBKey: b.key,
            planetBLabel: b.label,
            detail: detail
        )
    }
}
