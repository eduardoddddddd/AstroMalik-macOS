import Foundation
import CSwissEph

// MARK: - Lunation Calculator

enum LunationCalculator {
    private static let sampleStepJD = 0.25 // 6 horas
    private static let duplicateToleranceJD = 1.0 / 24.0 // 1 hora

    /// Encuentra Lunas Nuevas y Llenas en el rango.
    static func findLunations(
        from startJD: Double,
        to endJD: Double,
        timezone: String
    ) async throws -> [CelestialEvent] {
        try await findPhaseCrossings(
            from: startJD,
            to: endJD,
            timezone: timezone,
            targets: [
                PhaseTarget(angle: 0, kind: .newMoon, titlePrefix: "🌑 Luna Nueva", label: "Nueva"),
                PhaseTarget(angle: 180, kind: .fullMoon, titlePrefix: "🌕 Luna Llena", label: "Llena")
            ]
        )
    }

    /// Encuentra cuartos creciente y menguante en el rango.
    static func findQuarters(
        from startJD: Double,
        to endJD: Double,
        timezone: String
    ) async throws -> [CelestialEvent] {
        try await findPhaseCrossings(
            from: startJD,
            to: endJD,
            timezone: timezone,
            targets: [
                PhaseTarget(angle: 90, kind: .firstQuarter, titlePrefix: "🌓 Cuarto Creciente", label: "Cuarto creciente"),
                PhaseTarget(angle: 270, kind: .lastQuarter, titlePrefix: "🌗 Cuarto Menguante", label: "Cuarto menguante")
            ]
        )
    }

    /// Fase lunar de 8 fases para un JD dado.
    static func lunarPhase(at jd: Double) throws -> (angle: Double, label: String) {
        let angle = try moonSunPhaseAngle(at: jd)
        let label: String
        switch angle {
        case 0..<22.5, 337.5..<360:
            label = "Nueva"
        case 22.5..<67.5:
            label = "Creciente"
        case 67.5..<112.5:
            label = "Cuarto creciente"
        case 112.5..<157.5:
            label = "Gibosa creciente"
        case 157.5..<202.5:
            label = "Llena"
        case 202.5..<247.5:
            label = "Gibosa menguante"
        case 247.5..<292.5:
            label = "Cuarto menguante"
        default:
            label = "Menguante"
        }
        return (EphemerisUtilities.rounded(angle, places: 6), label)
    }

    // MARK: - Private

    private struct PhaseTarget {
        let angle: Double
        let kind: CelestialEventKind
        let titlePrefix: String
        let label: String
    }

    private static func findPhaseCrossings(
        from startJD: Double,
        to endJD: Double,
        timezone: String,
        targets: [PhaseTarget]
    ) async throws -> [CelestialEvent] {
        guard startJD < endJD else { return [] }

        var events: [CelestialEvent] = []
        var foundJDsByKind: [CelestialEventKind: [Double]] = [:]
        var previousJD = startJD
        var previousAngle = try moonSunPhaseAngle(at: previousJD)
        var jd = min(startJD + sampleStepJD, endJD)

        while jd <= endJD + 1e-9 {
            try Task.checkCancellation()
            let currentJD = min(jd, endJD)
            let currentAngle = try moonSunPhaseAngle(at: currentJD)

            for target in targets {
                guard crossesTarget(previousAngle: previousAngle, currentAngle: currentAngle, target: target.angle) else { continue }

                let exactJD = try bisectAngularCrossing(
                    startJD: previousJD,
                    endJD: currentJD,
                    target: target.angle,
                    angularFunction: { try moonSunPhaseAngle(at: $0) }
                )
                guard exactJD >= startJD - 1e-8, exactJD <= endJD + 1e-8 else { continue }
                let alreadyFound = foundJDsByKind[target.kind, default: []]
                    .contains { abs($0 - exactJD) < duplicateToleranceJD }
                guard !alreadyFound else { continue }

                foundJDsByKind[target.kind, default: []].append(exactJD)
                events.append(try makeEvent(target: target, jd: exactJD, timezone: timezone))
            }

            if currentJD >= endJD { break }
            previousJD = currentJD
            previousAngle = currentAngle
            jd += sampleStepJD
        }

        return events.sorted { $0.dateUTC < $1.dateUTC }
    }

    private static func crossesTarget(previousAngle: Double, currentAngle: Double, target: Double) -> Bool {
        let forwardDelta = EphemerisUtilities.normalizedDegree(currentAngle - previousAngle)
        if forwardDelta < 1e-9 { return false }

        // La elongación Luna-Sol avanza siempre de forma directa durante el ciclo
        // sinódico. No usamos cambio de signo respecto al objetivo porque la
        // distancia angular firmada salta también en el punto opuesto (±180°) y
        // eso duplicaría lunaciones/cuartos falsos.
        if forwardDelta < 180 {
            let distanceToTarget = EphemerisUtilities.normalizedDegree(target - previousAngle)
            return distanceToTarget > 1e-9 && distanceToTarget <= forwardDelta + 1e-9
        }

        // Fallback defensivo para intervalos anormalmente grandes.
        let backwardDelta = EphemerisUtilities.normalizedDegree(previousAngle - currentAngle)
        let distanceToTarget = EphemerisUtilities.normalizedDegree(previousAngle - target)
        return distanceToTarget > 1e-9 && distanceToTarget <= backwardDelta + 1e-9
    }

    private static func makeEvent(
        target: PhaseTarget,
        jd: Double,
        timezone: String
    ) throws -> CelestialEvent {
        let moon = try EphemerisUtilities.planetPosition(jd: jd, planetID: SE_MOON, bodyName: "Luna")
        let longitude = EphemerisUtilities.rounded(moon.longitude, places: 6)
        let signLabel = EphemerisUtilities.signLabel(for: longitude)
        let signKey = EphemerisUtilities.signKey(for: longitude)
        let formatted = AstroEngine.degToSign(longitude)
        let local = try EphemerisUtilities.localDateTimeString(fromJD: jd, timezone: timezone)
        let time = try EphemerisUtilities.localTimeString(fromJD: jd, timezone: timezone)
        return CelestialEvent(
            kind: target.kind,
            dateUTC: EphemerisUtilities.isoUTCString(fromJD: jd),
            dateLocal: local,
            longitude: longitude,
            signKey: signKey,
            signLabel: signLabel,
            formatted: formatted,
            planetKeyA: "LUNA",
            planetLabelA: "☽ Luna",
            planetKeyB: "SOL",
            planetLabelB: "☉ Sol",
            aspectKey: target.kind == .newMoon ? "CONJUNCION" : (target.kind == .fullMoon ? "OPOSICION" : nil),
            aspectLabel: target.kind == .newMoon ? "☌ Conjunción" : (target.kind == .fullMoon ? "☍ Oposición" : nil),
            title: "\(target.titlePrefix) en \(signLabel)",
            subtitle: "\(formatted) — \(time)",
            importance: .major
        )
    }

    private static func moonSunPhaseAngle(at jd: Double) throws -> Double {
        let sun = try EphemerisUtilities.planetPosition(jd: jd, planetID: SE_SUN, bodyName: "Sol")
        let moon = try EphemerisUtilities.planetPosition(jd: jd, planetID: SE_MOON, bodyName: "Luna")
        return EphemerisUtilities.phaseAngle(moonLongitude: moon.longitude, sunLongitude: sun.longitude)
    }
}
