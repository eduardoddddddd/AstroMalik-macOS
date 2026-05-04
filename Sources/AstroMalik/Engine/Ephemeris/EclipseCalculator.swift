import Foundation
import CSwissEph

// MARK: - Eclipse Calculator

enum EclipseCalculator {
    private static let searchMarginJD = 1.0 / 24.0
    private static let allSolarTypes = SE_ECL_CENTRAL | SE_ECL_NONCENTRAL | SE_ECL_TOTAL | SE_ECL_ANNULAR | SE_ECL_PARTIAL | SE_ECL_ANNULAR_TOTAL
    private static let allLunarTypes = SE_ECL_TOTAL | SE_ECL_PARTIAL | SE_ECL_PENUMBRAL

    static func findEclipses(
        from startJD: Double,
        to endJD: Double,
        timezone: String
    ) async throws -> [CelestialEvent] {
        guard startJD < endJD else { return [] }
        // Swiss Ephemeris mantiene estado global interno; evitar llamadas
        // concurrentes aquí previene crashes intermitentes al buscar eclipses.
        let solar = try await findSolarEclipses(from: startJD, to: endJD, timezone: timezone)
        let lunar = try await findLunarEclipses(from: startJD, to: endJD, timezone: timezone)
        return (solar + lunar).sorted { $0.dateUTC < $1.dateUTC }
    }

    private static func findSolarEclipses(
        from startJD: Double,
        to endJD: Double,
        timezone: String
    ) async throws -> [CelestialEvent] {
        var events: [CelestialEvent] = []
        var searchJD = startJD - searchMarginJD

        while searchJD <= endJD {
            try Task.checkCancellation()
            var tret = [Double](repeating: 0, count: 10)
            var serr = [CChar](repeating: 0, count: 256)
            let flags = swe_sol_eclipse_when_glob(
                searchJD,
                SEFLG_SWIEPH,
                allSolarTypes,
                &tret,
                0,
                &serr
            )
            guard flags >= 0 else {
                throw EphemerisError.calculationFailed("Eclipse solar", String(cString: serr))
            }

            let maximumJD = tret[0]
            if maximumJD > endJD + searchMarginJD { break }
            if maximumJD >= startJD - searchMarginJD {
                events.append(try makeEclipseEvent(
                    kind: .solarEclipse,
                    jd: maximumJD,
                    bodyID: SE_SUN,
                    bodyName: "Sol",
                    flags: flags,
                    timezone: timezone
                ))
            }
            searchJD = maximumJD + 1.0
        }
        return events
    }

    private static func findLunarEclipses(
        from startJD: Double,
        to endJD: Double,
        timezone: String
    ) async throws -> [CelestialEvent] {
        var events: [CelestialEvent] = []
        var searchJD = startJD - searchMarginJD

        while searchJD <= endJD {
            try Task.checkCancellation()
            var tret = [Double](repeating: 0, count: 10)
            var serr = [CChar](repeating: 0, count: 256)
            let flags = swe_lun_eclipse_when(
                searchJD,
                SEFLG_SWIEPH,
                allLunarTypes,
                &tret,
                0,
                &serr
            )
            guard flags >= 0 else {
                throw EphemerisError.calculationFailed("Eclipse lunar", String(cString: serr))
            }

            let maximumJD = tret[0]
            if maximumJD > endJD + searchMarginJD { break }
            if maximumJD >= startJD - searchMarginJD {
                events.append(try makeEclipseEvent(
                    kind: .lunarEclipse,
                    jd: maximumJD,
                    bodyID: SE_MOON,
                    bodyName: "Luna",
                    flags: flags,
                    timezone: timezone
                ))
            }
            searchJD = maximumJD + 1.0
        }
        return events
    }

    private static func makeEclipseEvent(
        kind: CelestialEventKind,
        jd: Double,
        bodyID: Int32,
        bodyName: String,
        flags: Int32,
        timezone: String
    ) throws -> CelestialEvent {
        let position = try EphemerisUtilities.planetPosition(jd: jd, planetID: bodyID, bodyName: bodyName)
        let longitude = EphemerisUtilities.rounded(position.longitude, places: 6)
        let signLabel = EphemerisUtilities.signLabel(for: longitude)
        let signKey = EphemerisUtilities.signKey(for: longitude)
        let formatted = AstroEngine.degToSign(longitude)
        let local = try EphemerisUtilities.localDateTimeString(fromJD: jd, timezone: timezone)
        let time = try EphemerisUtilities.localTimeString(fromJD: jd, timezone: timezone)
        let type = eclipseType(flags: flags, kind: kind)
        let magnitude = try eclipseMagnitude(kind: kind, jd: jd)
        let titleKind = kind == .solarEclipse ? "Eclipse Solar" : "Eclipse Lunar"
        let emoji = kind == .solarEclipse ? "🌑" : "🌕"
        let capitalizedType = type.prefix(1).uppercased() + type.dropFirst()

        return CelestialEvent(
            kind: kind,
            dateUTC: EphemerisUtilities.isoUTCString(fromJD: jd),
            dateLocal: local,
            longitude: longitude,
            signKey: signKey,
            signLabel: signLabel,
            formatted: formatted,
            planetKeyA: bodyID == SE_SUN ? "SOL" : "LUNA",
            planetLabelA: bodyID == SE_SUN ? "☉ Sol" : "☽ Luna",
            eclipseType: type,
            eclipseMagnitude: magnitude,
            title: "\(emoji) \(titleKind) \(capitalizedType) en \(signLabel)",
            subtitle: "\(formatted) — \(time)",
            importance: .critical
        )
    }

    private static func eclipseType(flags: Int32, kind: CelestialEventKind) -> String {
        if flags & SE_ECL_TOTAL != 0 { return "total" }
        if flags & SE_ECL_ANNULAR != 0 { return "anular" }
        if flags & SE_ECL_ANNULAR_TOTAL != 0 { return "híbrido" }
        if flags & SE_ECL_PARTIAL != 0 { return "parcial" }
        if kind == .lunarEclipse, flags & SE_ECL_PENUMBRAL != 0 { return "penumbral" }
        return "desconocido"
    }

    private static func eclipseMagnitude(kind: CelestialEventKind, jd: Double) throws -> Double? {
        var attr = [Double](repeating: 0, count: 20)
        var geopos = [Double](repeating: 0, count: 3)
        var serr = [CChar](repeating: 0, count: 256)
        let rc: Int32
        if kind == .solarEclipse {
            rc = swe_sol_eclipse_how(jd, SEFLG_SWIEPH, &geopos, &attr, &serr)
        } else {
            rc = swe_lun_eclipse_how(jd, SEFLG_SWIEPH, &geopos, &attr, &serr)
        }
        guard rc >= 0 else { return nil }
        return EphemerisUtilities.rounded(attr[0], places: 4)
    }
}
