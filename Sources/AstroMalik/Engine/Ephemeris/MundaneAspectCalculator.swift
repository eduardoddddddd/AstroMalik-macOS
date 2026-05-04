import Foundation
import CSwissEph

// MARK: - Mundane Aspect Calculator

enum MundaneAspectCalculator {
    private struct MundanePlanet {
        let id: Int32
        let key: String
        let label: String
    }

    private static let planets: [MundanePlanet] = PLANET_LIST.map {
        MundanePlanet(id: $0.id, key: $0.key, label: $0.label)
    }
    private static let slowOrImportant: Set<String> = ["SOL", "MARTE", "JUPITER", "SATURNO", "URANO", "NEPTUNO", "PLUTON"]
    private static let slowPlanets: Set<String> = ["JUPITER", "SATURNO", "URANO", "NEPTUNO", "PLUTON"]
    private static let duplicateToleranceJD = 1.0 / 24.0

    static func findAspects(
        from startJD: Double,
        to endJD: Double,
        timezone: String,
        includeLunar: Bool = false
    ) async throws -> [CelestialEvent] {
        guard startJD < endJD else { return [] }
        let activePlanets = planets.filter { includeLunar || $0.key != "LUNA" }
        let stepJD = includeLunar ? 2.0 / 24.0 : 1.0
        var events: [CelestialEvent] = []

        for i in 0..<activePlanets.count {
            for j in (i + 1)..<activePlanets.count {
                try Task.checkCancellation()
                let a = activePlanets[i]
                let b = activePlanets[j]
                guard includeLunar || isRelevantPair(a.key, b.key) else { continue }
                events.append(contentsOf: try await findAspectsForPair(
                    a: a,
                    b: b,
                    from: startJD,
                    to: endJD,
                    timezone: timezone,
                    stepJD: stepJD
                ))
            }
        }

        return events.sorted { $0.dateUTC < $1.dateUTC }
    }

    private static func findAspectsForPair(
        a: MundanePlanet,
        b: MundanePlanet,
        from startJD: Double,
        to endJD: Double,
        timezone: String,
        stepJD: Double
    ) async throws -> [CelestialEvent] {
        var events: [CelestialEvent] = []
        var found: [String: [Double]] = [:]
        var previousJD = startJD
        var previousAngle = try pairAngle(a: a, b: b, jd: previousJD)
        var jd = min(startJD + stepJD, endJD)

        while jd <= endJD + 1e-9 {
            try Task.checkCancellation()
            let currentJD = min(jd, endJD)
            let currentAngle = try pairAngle(a: a, b: b, jd: currentJD)

            for aspect in ASPECT_DEFS {
                for target in targets(for: aspect.angle) {
                    let previousValue = EphemerisUtilities.signedAngularDistance(previousAngle, target: target)
                    let currentValue = EphemerisUtilities.signedAngularDistance(currentAngle, target: target)
                    guard crossesZero(previousValue, currentValue) else { continue }

                    let exactJD = try bisectAngularCrossing(startJD: previousJD, endJD: currentJD, target: target) {
                        try pairAngle(a: a, b: b, jd: $0)
                    }
                    guard exactJD >= startJD - 1e-8, exactJD <= endJD + 1e-8 else { continue }
                    let key = "\(a.key)-\(b.key)-\(aspect.key)"
                    let alreadyFound = found[key, default: []].contains { abs($0 - exactJD) < duplicateToleranceJD }
                    guard !alreadyFound else { continue }
                    found[key, default: []].append(exactJD)
                    events.append(try makeAspectEvent(a: a, b: b, aspect: aspect, jd: exactJD, timezone: timezone))
                }
            }

            if currentJD >= endJD { break }
            previousJD = currentJD
            previousAngle = currentAngle
            jd += stepJD
        }
        return events
    }

    private static func pairAngle(a: MundanePlanet, b: MundanePlanet, jd: Double) throws -> Double {
        let pa = try EphemerisUtilities.planetPosition(jd: jd, planetID: a.id, bodyName: a.label)
        let pb = try EphemerisUtilities.planetPosition(jd: jd, planetID: b.id, bodyName: b.label)
        return EphemerisUtilities.normalizedDegree(pb.longitude - pa.longitude)
    }

    private static func targets(for aspectAngle: Double) -> [Double] {
        if aspectAngle == 0 || aspectAngle == 180 { return [aspectAngle] }
        return [aspectAngle, 360 - aspectAngle]
    }

    private static func crossesZero(_ a: Double, _ b: Double) -> Bool {
        if abs(a) < 1e-8 || abs(b) < 1e-8 { return true }
        return a * b < 0
    }

    private static func isRelevantPair(_ a: String, _ b: String) -> Bool {
        slowOrImportant.contains(a) || slowOrImportant.contains(b)
    }

    private static func makeAspectEvent(
        a: MundanePlanet,
        b: MundanePlanet,
        aspect: AspectDef,
        jd: Double,
        timezone: String
    ) throws -> CelestialEvent {
        let positionA = try EphemerisUtilities.planetPosition(jd: jd, planetID: a.id, bodyName: a.label)
        let positionB = try EphemerisUtilities.planetPosition(jd: jd, planetID: b.id, bodyName: b.label)
        let longitude = EphemerisUtilities.rounded(positionA.longitude, places: 6)
        let signLabel = EphemerisUtilities.signLabel(for: longitude)
        let signKey = EphemerisUtilities.signKey(for: longitude)
        let local = try EphemerisUtilities.localDateTimeString(fromJD: jd, timezone: timezone)
        let time = try EphemerisUtilities.localTimeString(fromJD: jd, timezone: timezone)
        let retroA = positionA.speed < 0 ? " ℞" : ""
        let retroB = positionB.speed < 0 ? " ℞" : ""

        return CelestialEvent(
            kind: .mundaneAspect,
            dateUTC: EphemerisUtilities.isoUTCString(fromJD: jd),
            dateLocal: local,
            longitude: longitude,
            signKey: signKey,
            signLabel: signLabel,
            formatted: AstroEngine.degToSign(longitude),
            planetKeyA: a.key,
            planetLabelA: a.label + retroA,
            planetKeyB: b.key,
            planetLabelB: b.label + retroB,
            aspectKey: aspect.key,
            aspectLabel: aspect.label,
            title: "\(a.label) \(aspect.label) \(b.label)",
            subtitle: "Exacto — \(time)",
            importance: importance(a.key, b.key)
        )
    }

    private static func importance(_ a: String, _ b: String) -> EventImportance {
        if slowPlanets.contains(a), slowPlanets.contains(b) { return .major }
        if a == "SOL" && slowPlanets.contains(b) || b == "SOL" && slowPlanets.contains(a) { return .moderate }
        if a == "MARTE" && slowPlanets.contains(b) || b == "MARTE" && slowPlanets.contains(a) { return .moderate }
        return .minor
    }
}
