import Foundation

final class AntisciaEngine {
    func antiscia(chart: Chart, orb: Double = NatalExtendedAnalysisConfiguration.default.antisciaOrb) -> AntisciaResult {
        let bodies = ExtendedAstro.bodies(in: chart, keys: ExtendedAstro.tenPlanetKeys)
        var points: [AntisciaPoint] = []
        for body in bodies {
            let antiscion = Self.antiscionLongitude(body.longitude)
            let contra = Self.contraAntiscionLongitude(body.longitude)
            points.append(AntisciaPoint(
                planetKey: body.key,
                planetLabel: body.label,
                kind: .antiscion,
                longitude: ExtendedAstro.rounded(antiscion, places: 6),
                formatted: AstroEngine.degToSign(antiscion)
            ))
            points.append(AntisciaPoint(
                planetKey: body.key,
                planetLabel: body.label,
                kind: .contraAntiscion,
                longitude: ExtendedAstro.rounded(contra, places: 6),
                formatted: AstroEngine.degToSign(contra)
            ))
        }

        var contacts: [AntisciaContact] = []
        for i in 0..<bodies.count {
            for j in (i + 1)..<bodies.count {
                let a = bodies[i]
                let b = bodies[j]
                if let contact = contact(kind: .antiscion, source: a, target: b, orb: orb) {
                    contacts.append(contact)
                }
                if let contact = contact(kind: .contraAntiscion, source: a, target: b, orb: orb) {
                    contacts.append(contact)
                }
            }
        }

        return AntisciaResult(
            points: points.sorted { $0.id < $1.id },
            contacts: contacts.sorted { $0.orb == $1.orb ? $0.id < $1.id : $0.orb < $1.orb }
        )
    }

    static func antiscionLongitude(_ longitude: Double) -> Double {
        ExtendedAstro.normalized(180.0 - longitude)
    }

    static func contraAntiscionLongitude(_ longitude: Double) -> Double {
        ExtendedAstro.normalized(360.0 - longitude)
    }

    private func contact(kind: AntisciaContactKind, source: PlanetBody, target: PlanetBody, orb: Double) -> AntisciaContact? {
        let calculated = kind == .antiscion
            ? Self.antiscionLongitude(source.longitude)
            : Self.contraAntiscionLongitude(source.longitude)
        let distance = ExtendedAstro.angularDistance(calculated, target.longitude)
        guard distance <= orb else { return nil }
        return AntisciaContact(
            id: "\(kind.rawValue)-\(source.key)-\(target.key)",
            kind: kind,
            sourcePlanetKey: source.key,
            sourcePlanetLabel: source.label,
            targetPlanetKey: target.key,
            targetPlanetLabel: target.label,
            calculatedLongitude: ExtendedAstro.rounded(calculated, places: 6),
            calculatedFormatted: AstroEngine.degToSign(calculated),
            orb: ExtendedAstro.rounded(distance, places: 3)
        )
    }
}
