import Foundation
import CSwissEph

// MARK: - Void of Course Moon Calculator

enum VoidOfCourseCalculator {
    private struct AspectHit {
        let jd: Double
        let planetKey: String
        let planetLabel: String
        let aspectKey: String
        let aspectLabel: String
    }

    private static let planets = PLANET_LIST
        .filter { $0.key != "LUNA" }
        .map { (id: $0.id, key: $0.key, label: $0.label) }

    private static let searchBackJD = 3.0
    private static let stepJD = 2.0 / 24.0

    static func findVoidPeriods(
        from startJD: Double,
        to endJD: Double,
        timezone: String
    ) async throws -> [CelestialEvent] {
        guard startJD < endJD else { return [] }
        let ingresses = try await lunarIngresses(from: startJD, to: endJD)
        var events: [CelestialEvent] = []

        for ingressJD in ingresses {
            try Task.checkCancellation()
            let lastAspect = try findLastLunarAspect(before: ingressJD, lowerLimitJD: max(startJD - searchBackJD, ingressJD - searchBackJD))
            let startVoidJD = lastAspect?.jd ?? max(startJD, ingressJD - searchBackJD)
            guard startVoidJD < ingressJD else { continue }

            if startVoidJD >= startJD && startVoidJD <= endJD {
                events.append(try makeVoidStartEvent(
                    startJD: startVoidJD,
                    endJD: ingressJD,
                    lastAspect: lastAspect,
                    timezone: timezone
                ))
            }
            if ingressJD >= startJD && ingressJD <= endJD {
                events.append(try makeVoidEndEvent(jd: ingressJD, timezone: timezone))
            }
        }

        return events.sorted { $0.dateUTC < $1.dateUTC }
    }

    private static func lunarIngresses(from startJD: Double, to endJD: Double) async throws -> [Double] {
        var ingresses: [Double] = []
        var previousJD = startJD
        var previousPosition = try EphemerisUtilities.planetPosition(jd: previousJD, planetID: SE_MOON, bodyName: "Luna")
        var jd = min(startJD + 0.25, endJD)

        while jd <= endJD + 1e-9 {
            try Task.checkCancellation()
            let currentJD = min(jd, endJD)
            let currentPosition = try EphemerisUtilities.planetPosition(jd: currentJD, planetID: SE_MOON, bodyName: "Luna")
            let previousSign = EphemerisUtilities.signIndex(for: previousPosition.longitude)
            let currentSign = EphemerisUtilities.signIndex(for: currentPosition.longitude)
            if previousSign != currentSign {
                let target = Double(currentSign * 30)
                let exactJD = try bisectAngularCrossing(
                    startJD: previousJD,
                    endJD: currentJD,
                    target: target,
                    angularFunction: {
                        try EphemerisUtilities.planetPosition(jd: $0, planetID: SE_MOON, bodyName: "Luna").longitude
                    }
                )
                ingresses.append(exactJD)
            }
            if currentJD >= endJD { break }
            previousJD = currentJD
            previousPosition = currentPosition
            jd += 0.25
        }
        return ingresses
    }

    private static func findLastLunarAspect(before ingressJD: Double, lowerLimitJD: Double) throws -> AspectHit? {
        var latest: AspectHit? = nil
        for planet in planets {
            for aspect in ASPECT_DEFS {
                if let hit = try findLastAspectWithPlanet(planet: planet, aspect: aspect, before: ingressJD, lowerLimitJD: lowerLimitJD),
                   latest == nil || hit.jd > latest!.jd {
                    latest = hit
                }
            }
        }
        return latest
    }

    private static func findLastAspectWithPlanet(
        planet: (id: Int32, key: String, label: String),
        aspect: AspectDef,
        before ingressJD: Double,
        lowerLimitJD: Double
    ) throws -> AspectHit? {
        var highJD = ingressJD - 1e-6
        var highValue = try aspectDistance(jd: highJD, planetID: planet.id, target: aspect.angle)

        while highJD > lowerLimitJD {
            let lowJD = max(lowerLimitJD, highJD - stepJD)
            let lowValue = try aspectDistance(jd: lowJD, planetID: planet.id, target: aspect.angle)
            if crossesZero(lowValue, highValue) {
                let exactJD = try bisectScalarCrossing(startJD: lowJD, endJD: highJD, target: 0) {
                    try aspectDistance(jd: $0, planetID: planet.id, target: aspect.angle)
                }
                return AspectHit(jd: exactJD, planetKey: planet.key, planetLabel: planet.label, aspectKey: aspect.key, aspectLabel: aspect.label)
            }
            highJD = lowJD
            highValue = lowValue
        }
        return nil
    }

    private static func aspectDistance(jd: Double, planetID: Int32, target: Double) throws -> Double {
        let moon = try EphemerisUtilities.planetPosition(jd: jd, planetID: SE_MOON, bodyName: "Luna")
        let planet = try EphemerisUtilities.planetPosition(jd: jd, planetID: planetID, bodyName: "Planeta")
        let diff = angularSeparation(moon.longitude, planet.longitude)
        return diff - target
    }

    private static func angularSeparation(_ a: Double, _ b: Double) -> Double {
        let raw = abs(EphemerisUtilities.normalizedDegree(a - b))
        return raw > 180 ? 360 - raw : raw
    }

    private static func crossesZero(_ a: Double, _ b: Double) -> Bool {
        if abs(a) < 1e-8 || abs(b) < 1e-8 { return true }
        return a * b < 0
    }

    private static func makeVoidStartEvent(
        startJD: Double,
        endJD: Double,
        lastAspect: AspectHit?,
        timezone: String
    ) throws -> CelestialEvent {
        let moon = try EphemerisUtilities.planetPosition(jd: startJD, planetID: SE_MOON, bodyName: "Luna")
        let signLabel = EphemerisUtilities.signLabel(for: moon.longitude)
        let signKey = EphemerisUtilities.signKey(for: moon.longitude)
        let local = try EphemerisUtilities.localDateTimeString(fromJD: startJD, timezone: timezone)
        let time = try EphemerisUtilities.localTimeString(fromJD: startJD, timezone: timezone)
        let endISO = EphemerisUtilities.isoUTCString(fromJD: endJD)
        let minutes = max(1, Int(((endJD - startJD) * 1_440).rounded()))
        let last = lastAspect.map { "Último aspecto: \($0.aspectLabel) con \($0.planetLabel)" } ?? "Último aspecto no localizado en 72h"

        return CelestialEvent(
            kind: .voidOfCourse,
            dateUTC: EphemerisUtilities.isoUTCString(fromJD: startJD),
            dateLocal: local,
            longitude: EphemerisUtilities.rounded(moon.longitude, places: 6),
            signKey: signKey,
            signLabel: signLabel,
            formatted: AstroEngine.degToSign(moon.longitude),
            planetKeyA: "LUNA",
            planetLabelA: "☽ Luna",
            aspectKey: lastAspect?.aspectKey,
            aspectLabel: lastAspect?.aspectLabel,
            voidEnds: endISO,
            voidDurationMinutes: minutes,
            lastAspectPlanet: lastAspect?.planetLabel,
            lastAspectType: lastAspect?.aspectLabel,
            title: "☽ Luna vacía de curso en \(signLabel)",
            subtitle: "\(last) — inicia \(time)",
            importance: .moderate
        )
    }

    private static func makeVoidEndEvent(jd: Double, timezone: String) throws -> CelestialEvent {
        let moon = try EphemerisUtilities.planetPosition(jd: jd, planetID: SE_MOON, bodyName: "Luna")
        let signLabel = EphemerisUtilities.signLabel(for: moon.longitude)
        let signKey = EphemerisUtilities.signKey(for: moon.longitude)
        let local = try EphemerisUtilities.localDateTimeString(fromJD: jd, timezone: timezone)
        let time = try EphemerisUtilities.localTimeString(fromJD: jd, timezone: timezone)
        return CelestialEvent(
            kind: .voidOfCourseEnd,
            dateUTC: EphemerisUtilities.isoUTCString(fromJD: jd),
            dateLocal: local,
            longitude: EphemerisUtilities.rounded(moon.longitude, places: 6),
            signKey: signKey,
            signLabel: signLabel,
            formatted: "\(signLabel) 00°00'",
            planetKeyA: "LUNA",
            planetLabelA: "☽ Luna",
            title: "☽ Fin de Luna vacía: ingreso en \(signLabel)",
            subtitle: "Ingreso lunar — \(time)",
            importance: .minor
        )
    }
}
