import Foundation
import CSwissEph

// MARK: - Ephemeris Engine

enum EphemerisEngine {

    /// Calcula todos los eventos celestes y la tabla diaria para un mes.
    ///
    /// Importante: las llamadas a Swiss Ephemeris se ejecutan secuencialmente.
    /// CSwissEph mantiene estado global interno y ya se observó que paralelizar
    /// búsquedas de eclipses puede provocar crashes en tests.
    static func computeMonth(
        year: Int,
        month: Int,
        timezone: String
    ) async throws -> EphemerisMonth {
        let (startJD, endJD) = jdRangeForMonth(year: year, month: month)

        var events: [CelestialEvent] = []
        events.append(contentsOf: try await LunationCalculator.findLunations(from: startJD, to: endJD, timezone: timezone))
        events.append(contentsOf: try await LunationCalculator.findQuarters(from: startJD, to: endJD, timezone: timezone))
        events.append(contentsOf: try await EclipseCalculator.findEclipses(from: startJD, to: endJD, timezone: timezone))
        events.append(contentsOf: try await StationCalculator.findStations(from: startJD, to: endJD, timezone: timezone))
        events.append(contentsOf: try await SignIngressCalculator.findIngresses(from: startJD, to: endJD, timezone: timezone))
        events.append(contentsOf: try await VoidOfCourseCalculator.findVoidPeriods(from: startJD, to: endJD, timezone: timezone))
        events.append(contentsOf: try await MundaneAspectCalculator.findAspects(from: startJD, to: endJD, timezone: timezone))

        let dailyRows = try await computeDailyRows(from: startJD, to: endJD, timezone: timezone)

        return EphemerisMonth(
            id: String(format: "%04d-%02d", year, month),
            year: year,
            month: month,
            events: events.sorted { $0.dateUTC < $1.dateUTC },
            dailyRows: dailyRows
        )
    }

    /// Efeméride diaria: posiciones a las 00:00 UTC de cada día del rango.
    static func computeDailyRows(
        from startJD: Double,
        to endJD: Double,
        timezone: String
    ) async throws -> [DailyEphemerisRow] {
        guard startJD < endJD else { return [] }
        var rows: [DailyEphemerisRow] = []
        var jd = startJD.rounded(.towardZero)
        if jd < startJD { jd += 1 }

        while jd < endJD - 1e-9 {
            try Task.checkCancellation()
            rows.append(try dailyRow(at: jd, timezone: timezone))
            jd += 1
        }
        return rows
    }

    static func jdRangeForMonth(year: Int, month: Int) -> (Double, Double) {
        let startJD = swe_julday(Int32(year), Int32(month), 1, 0, SE_GREG_CAL)
        let nextMonth = month == 12 ? 1 : month + 1
        let nextYear = month == 12 ? year + 1 : year
        let endJD = swe_julday(Int32(nextYear), Int32(nextMonth), 1, 0, SE_GREG_CAL)
        return (startJD, endJD)
    }

    // MARK: - Private

    private static func dailyRow(at jd: Double, timezone: String) throws -> DailyEphemerisRow {
        let planets = try AstroEngine.calcPlanets(jd: jd)
        let nodes = try AstroEngine.calcLunarNodes(jd: jd)
        var positions: [PlanetDailyPosition] = []

        for planet in PLANET_LIST {
            guard let raw = planets[planet.key] else { continue }
            positions.append(PlanetDailyPosition(
                planetKey: raw.key,
                longitude: EphemerisUtilities.rounded(raw.deg, places: 6),
                formatted: compactDegree(raw.deg) + (raw.retro ? " ℞" : ""),
                speed: EphemerisUtilities.rounded(raw.speed, places: 8),
                retrograde: raw.retro,
                signKey: AstroEngine.degToSignKey(raw.deg)
            ))
        }

        positions.append(PlanetDailyPosition(
            planetKey: nodes.north.key,
            longitude: EphemerisUtilities.rounded(nodes.north.deg, places: 6),
            formatted: compactDegree(nodes.north.deg) + (nodes.north.retro ? " ℞" : ""),
            speed: EphemerisUtilities.rounded(nodes.north.speed, places: 8),
            retrograde: nodes.north.retro,
            signKey: AstroEngine.degToSignKey(nodes.north.deg)
        ))

        let phase = try LunationCalculator.lunarPhase(at: jd)
        return DailyEphemerisRow(
            date: utcDateString(fromJD: jd),
            positions: positions,
            lunarPhaseAngle: phase.angle,
            lunarPhaseLabel: phase.label
        )
    }

    private static func utcDateString(fromJD jd: Double) -> String {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: EphemerisUtilities.julianDayToDate(jd))
    }

    private static func compactDegree(_ longitude: Double) -> String {
        let normalized = EphemerisUtilities.normalizedDegree(longitude)
        let sign = EphemerisUtilities.signLabel(for: normalized).split(separator: " ").first.map(String.init) ?? ""
        let inSign = normalized.truncatingRemainder(dividingBy: 30)
        let degrees = Int(inSign)
        let minutes = Int(((inSign - Double(degrees)) * 60).rounded(.down))
        return "\(sign) \(String(format: "%02d", degrees))°\(String(format: "%02d", minutes))'"
    }
}
