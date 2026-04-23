import Foundation
import CSwissEph

// MARK: - Julian Day Conversion
// Porta jd_local.py: hora local IANA → Julian Day UT para pyswisseph

enum JulianDayError: LocalizedError {
    case invalidTimezone(String)
    case invalidDate(String)
    case invalidTime(String)

    var errorDescription: String? {
        switch self {
        case .invalidTimezone(let tz): return "Zona horaria IANA no válida: \(tz)"
        case .invalidDate(let d):      return "Fecha inválida: \(d)"
        case .invalidTime(let t):      return "Hora fuera de rango: \(t)"
        }
    }
}

struct JulianDayResult {
    let jd: Double
    let timezoneIANA: String
    let localISO: String
    let utcISO: String
    let utFractionalHours: Double
}

/// Convierte una fecha/hora local (con zona IANA) a Julian Day UT (Universal Time).
/// Equivale a `julday_from_local_iana` en `jd_local.py`.
func julianDayFromLocal(
    birthDate: String,
    birthTime: String,
    timezoneName: String
) throws -> JulianDayResult {

    guard let tz = TimeZone(identifier: timezoneName) else {
        throw JulianDayError.invalidTimezone(timezoneName)
    }

    let dateParts = birthDate.split(separator: "-").compactMap { Int($0) }
    guard dateParts.count == 3 else { throw JulianDayError.invalidDate(birthDate) }
    let (year, month, day) = (dateParts[0], dateParts[1], dateParts[2])

    let timeParts = birthTime.split(separator: ":").compactMap { Int($0) }
    guard timeParts.count >= 2 else { throw JulianDayError.invalidTime(birthTime) }
    let (hh, mm) = (timeParts[0], timeParts[1])
    guard (0...23).contains(hh), (0...59).contains(mm) else {
        throw JulianDayError.invalidTime(birthTime)
    }

    var cal = Calendar(identifier: .gregorian)
    cal.timeZone = tz
    var comps = DateComponents()
    comps.year = year; comps.month = month; comps.day = day
    comps.hour = hh; comps.minute = mm; comps.second = 0
    guard let localDate = cal.date(from: comps) else {
        throw JulianDayError.invalidDate("\(birthDate) \(birthTime) \(timezoneName)")
    }

    let utcCal = Calendar(identifier: .gregorian)
    let utcComps = utcCal.dateComponents(in: TimeZone(identifier: "UTC")!, from: localDate)

    let utHour = Double(utcComps.hour ?? 0)
        + Double(utcComps.minute ?? 0) / 60.0
        + Double(utcComps.second ?? 0) / 3600.0

    let utYear  = Int32(utcComps.year ?? year)
    let utMonth = Int32(utcComps.month ?? month)
    let utDay   = Int32(utcComps.day ?? day)

    let jd = swe_julday(utYear, utMonth, utDay, utHour, SE_GREG_CAL)

    let isoFormatter = ISO8601DateFormatter()
    isoFormatter.timeZone = tz
    let localISO = isoFormatter.string(from: localDate)
    isoFormatter.timeZone = TimeZone(identifier: "UTC")
    let utcISO = isoFormatter.string(from: localDate)

    return JulianDayResult(
        jd: jd,
        timezoneIANA: timezoneName,
        localISO: localISO,
        utcISO: utcISO,
        utFractionalHours: (utHour * 1_000_000).rounded() / 1_000_000
    )
}
