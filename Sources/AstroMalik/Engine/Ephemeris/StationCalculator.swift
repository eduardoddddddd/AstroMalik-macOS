import Foundation
import CSwissEph

// MARK: - Station Calculator

enum StationCalculator {
    private struct StationPlanet {
        let id: Int32
        let key: String
        let label: String
    }

    private static let planets: [StationPlanet] = [
        StationPlanet(id: SE_MERCURY, key: "MERCURIO", label: "☿ Mercurio"),
        StationPlanet(id: SE_VENUS, key: "VENUS", label: "♀ Venus"),
        StationPlanet(id: SE_MARS, key: "MARTE", label: "♂ Marte"),
        StationPlanet(id: SE_JUPITER, key: "JUPITER", label: "♃ Júpiter"),
        StationPlanet(id: SE_SATURN, key: "SATURNO", label: "♄ Saturno"),
        StationPlanet(id: SE_URANUS, key: "URANO", label: "⛢ Urano"),
        StationPlanet(id: SE_NEPTUNE, key: "NEPTUNO", label: "♆ Neptuno"),
        StationPlanet(id: SE_PLUTO, key: "PLUTON", label: "♇ Plutón"),
    ]

    static func findStations(
        from startJD: Double,
        to endJD: Double,
        timezone: String
    ) async throws -> [CelestialEvent] {
        guard startJD < endJD else { return [] }
        var events: [CelestialEvent] = []
        for planet in planets {
            try Task.checkCancellation()
            events.append(contentsOf: try await findStations(for: planet, from: startJD, to: endJD, timezone: timezone))
        }
        return events.sorted { $0.dateUTC < $1.dateUTC }
    }

    private static func findStations(
        for planet: StationPlanet,
        from startJD: Double,
        to endJD: Double,
        timezone: String
    ) async throws -> [CelestialEvent] {
        var events: [CelestialEvent] = []
        var previousJD = startJD
        var previousSpeed = try speed(for: planet, jd: previousJD)
        var jd = min(startJD + 1.0, endJD)

        while jd <= endJD + 1e-9 {
            try Task.checkCancellation()
            let currentJD = min(jd, endJD)
            let currentSpeed = try speed(for: planet, jd: currentJD)

            if crossesZero(previousSpeed, currentSpeed) {
                let exactJD = try bisectScalarCrossing(
                    startJD: previousJD,
                    endJD: currentJD,
                    target: 0,
                    scalarFunction: { try speed(for: planet, jd: $0) }
                )
                guard exactJD >= startJD - 1e-8, exactJD <= endJD + 1e-8 else { continue }
                let before = try speed(for: planet, jd: max(startJD, exactJD - 0.01))
                let after = try speed(for: planet, jd: min(endJD, exactJD + 0.01))
                events.append(try makeStationEvent(
                    planet: planet,
                    jd: exactJD,
                    beforeSpeed: before,
                    afterSpeed: after,
                    timezone: timezone
                ))
            }

            if currentJD >= endJD { break }
            previousJD = currentJD
            previousSpeed = currentSpeed
            jd += 1.0
        }
        return events
    }

    private static func crossesZero(_ a: Double, _ b: Double) -> Bool {
        if abs(a) < 1e-12 || abs(b) < 1e-12 { return true }
        return a * b < 0
    }

    private static func speed(for planet: StationPlanet, jd: Double) throws -> Double {
        try EphemerisUtilities.planetPosition(jd: jd, planetID: planet.id, bodyName: planet.label).speed
    }

    private static func makeStationEvent(
        planet: StationPlanet,
        jd: Double,
        beforeSpeed: Double,
        afterSpeed: Double,
        timezone: String
    ) throws -> CelestialEvent {
        let position = try EphemerisUtilities.planetPosition(jd: jd, planetID: planet.id, bodyName: planet.label)
        let longitude = EphemerisUtilities.rounded(position.longitude, places: 6)
        let speedValue = EphemerisUtilities.rounded(position.speed, places: 8)
        let signLabel = EphemerisUtilities.signLabel(for: longitude)
        let signKey = EphemerisUtilities.signKey(for: longitude)
        let formatted = AstroEngine.degToSign(longitude)
        let local = try EphemerisUtilities.localDateTimeString(fromJD: jd, timezone: timezone)
        let time = try EphemerisUtilities.localTimeString(fromJD: jd, timezone: timezone)
        let kind: CelestialEventKind = beforeSpeed > afterSpeed ? .stationRetrograde : .stationDirect
        let stationLabel = kind == .stationRetrograde ? "estación retrógrada" : "estación directa"
        let stationCode = kind == .stationRetrograde ? "SR" : "SD"

        return CelestialEvent(
            kind: kind,
            dateUTC: EphemerisUtilities.isoUTCString(fromJD: jd),
            dateLocal: local,
            longitude: longitude,
            signKey: signKey,
            signLabel: signLabel,
            formatted: formatted,
            planetKeyA: planet.key,
            planetLabelA: planet.label,
            stationSpeed: speedValue,
            title: "\(planet.label) \(stationLabel) en \(signLabel)",
            subtitle: "\(stationCode) — \(formatted) — \(time)",
            importance: .major
        )
    }
}
