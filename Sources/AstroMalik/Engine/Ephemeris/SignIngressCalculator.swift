import Foundation
import CSwissEph

// MARK: - Sign Ingress Calculator

enum SignIngressCalculator {
    private struct IngressPlanet {
        let id: Int32
        let key: String
        let label: String
    }

    private static let allPlanets: [IngressPlanet] = PLANET_LIST.map {
        IngressPlanet(id: $0.id, key: $0.key, label: $0.label)
    }

    static func findIngresses(
        from startJD: Double,
        to endJD: Double,
        timezone: String,
        includeMoon: Bool = false
    ) async throws -> [CelestialEvent] {
        guard startJD < endJD else { return [] }
        let planets = allPlanets.filter { includeMoon || $0.key != "LUNA" }
        var events: [CelestialEvent] = []
        for planet in planets {
            try Task.checkCancellation()
            events.append(contentsOf: try await findIngresses(for: planet, from: startJD, to: endJD, timezone: timezone))
        }
        return events.sorted { $0.dateUTC < $1.dateUTC }
    }

    private static func findIngresses(
        for planet: IngressPlanet,
        from startJD: Double,
        to endJD: Double,
        timezone: String
    ) async throws -> [CelestialEvent] {
        var events: [CelestialEvent] = []
        var previousJD = startJD
        var previousPosition = try EphemerisUtilities.planetPosition(jd: previousJD, planetID: planet.id, bodyName: planet.label)
        var jd = min(startJD + 1.0, endJD)

        while jd <= endJD + 1e-9 {
            try Task.checkCancellation()
            let currentJD = min(jd, endJD)
            let currentPosition = try EphemerisUtilities.planetPosition(jd: currentJD, planetID: planet.id, bodyName: planet.label)
            let previousSign = EphemerisUtilities.signIndex(for: previousPosition.longitude)
            let currentSign = EphemerisUtilities.signIndex(for: currentPosition.longitude)

            if previousSign != currentSign {
                let direct = currentPosition.speed >= 0
                let targetLongitude = boundaryLongitude(previousSign: previousSign, currentSign: currentSign, direct: direct)
                let exactJD = try bisectAngularCrossing(
                    startJD: previousJD,
                    endJD: currentJD,
                    target: targetLongitude,
                    angularFunction: {
                        try EphemerisUtilities.planetPosition(jd: $0, planetID: planet.id, bodyName: planet.label).longitude
                    }
                )
                guard exactJD >= startJD - 1e-8, exactJD <= endJD + 1e-8 else { continue }
                let exactPosition = try EphemerisUtilities.planetPosition(jd: exactJD, planetID: planet.id, bodyName: planet.label)
                let destinationLongitude = direct
                    ? EphemerisUtilities.normalizedDegree(targetLongitude)
                    : EphemerisUtilities.normalizedDegree(targetLongitude - 0.000001)
                events.append(try makeIngressEvent(
                    planet: planet,
                    jd: exactJD,
                    longitude: exactPosition.longitude,
                    destinationLongitude: destinationLongitude,
                    direct: exactPosition.speed >= 0,
                    timezone: timezone
                ))
            }

            if currentJD >= endJD { break }
            previousJD = currentJD
            previousPosition = currentPosition
            jd += 1.0
        }
        return events
    }

    private static func boundaryLongitude(previousSign: Int, currentSign: Int, direct: Bool) -> Double {
        if direct {
            return Double(currentSign * 30)
        }
        return Double(previousSign * 30)
    }

    private static func makeIngressEvent(
        planet: IngressPlanet,
        jd: Double,
        longitude: Double,
        destinationLongitude: Double,
        direct: Bool,
        timezone: String
    ) throws -> CelestialEvent {
        let signLabel = EphemerisUtilities.signLabel(for: destinationLongitude)
        let signKey = EphemerisUtilities.signKey(for: destinationLongitude)
        let local = try EphemerisUtilities.localDateTimeString(fromJD: jd, timezone: timezone)
        let time = try EphemerisUtilities.localTimeString(fromJD: jd, timezone: timezone)
        let direction = direct ? "directo" : "retrógrado"
        return CelestialEvent(
            kind: .signIngress,
            dateUTC: EphemerisUtilities.isoUTCString(fromJD: jd),
            dateLocal: local,
            longitude: EphemerisUtilities.rounded(EphemerisUtilities.normalizedDegree(longitude), places: 6),
            signKey: signKey,
            signLabel: signLabel,
            formatted: "\(signLabel) 00°00'",
            planetKeyA: planet.key,
            planetLabelA: planet.label,
            ingressDirection: direction,
            title: "\(planet.label) ingresa en \(signLabel)",
            subtitle: "\(direction.capitalized) — \(time)",
            importance: importance(for: planet.key)
        )
    }

    private static func importance(for planetKey: String) -> EventImportance {
        switch planetKey {
        case "SOL", "JUPITER", "SATURNO", "URANO", "NEPTUNO", "PLUTON":
            return .moderate
        default:
            return .minor
        }
    }
}
