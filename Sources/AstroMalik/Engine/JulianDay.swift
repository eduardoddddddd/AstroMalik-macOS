import Foundation
import CSwissEph

// MARK: - Julian Day Conversion
// Porta jd_local.py: hora local IANA → Julian Day UT para pyswisseph

enum JulianDayError: LocalizedError {
    case invalidTimezone(String)
    case invalidDate(String)
    case invalidTime(String)
    case utcUnavailable

    var errorDescription: String? {
        switch self {
        case .invalidTimezone(let tz): return "Zona horaria IANA no válida: \(tz)"
        case .invalidDate(let d):      return "Fecha inválida: \(d)"
        case .invalidTime(let t):      return "Hora fuera de rango: \(t)"
        case .utcUnavailable:          return "No se pudo resolver la zona horaria UTC del sistema."
        }
    }
}

/// Componentes horarios validados y compartidos por todos los motores.
/// Mantiene compatibilidad con cartas históricas `HH:mm` y permite que la
/// rectificación trabaje con `HH:mm:ss` sin que cada módulo vuelva a parsear.
struct LocalTimeComponents: Equatable, Sendable {
    let hour: Int
    let minute: Int
    let second: Int

    var totalSeconds: Int { hour * 3_600 + minute * 60 + second }

    func formatted(includeSeconds: Bool? = nil) -> String {
        let shouldIncludeSeconds = includeSeconds ?? (second != 0)
        if shouldIncludeSeconds {
            return String(format: "%02d:%02d:%02d", hour, minute, second)
        }
        return String(format: "%02d:%02d", hour, minute)
    }
}

/// Parsea exclusivamente `HH:mm` o `HH:mm:ss`.
func parseLocalTime(_ value: String) throws -> LocalTimeComponents {
    let rawParts = value.split(separator: ":", omittingEmptySubsequences: false)
    guard rawParts.count == 2 || rawParts.count == 3,
          rawParts.allSatisfy({ !$0.isEmpty }),
          rawParts.allSatisfy({ $0.allSatisfy(\.isNumber) }),
          let hour = Int(rawParts[0]),
          let minute = Int(rawParts[1]) else {
        throw JulianDayError.invalidTime(value)
    }
    let second = rawParts.count == 3 ? Int(rawParts[2]) : 0
    guard let second,
          (0...23).contains(hour),
          (0...59).contains(minute),
          (0...59).contains(second) else {
        throw JulianDayError.invalidTime(value)
    }
    return LocalTimeComponents(hour: hour, minute: minute, second: second)
}

/// Construye una fecha local estricta. A diferencia de `Calendar.date(from:)`
/// usado directamente, rechaza fechas u horas que el calendario normalizaría
/// silenciosamente (por ejemplo 31 de febrero o una hora inexistente por DST).
func localDateFromBirthData(
    birthDate: String,
    birthTime: String,
    timezoneName: String
) throws -> Date {
    guard let timezone = TimeZone(identifier: timezoneName) else {
        throw JulianDayError.invalidTimezone(timezoneName)
    }

    let rawDateParts = birthDate.split(separator: "-", omittingEmptySubsequences: false)
    guard rawDateParts.count == 3,
          rawDateParts.allSatisfy({ !$0.isEmpty }),
          rawDateParts.allSatisfy({ $0.allSatisfy(\.isNumber) }),
          let year = Int(rawDateParts[0]),
          let month = Int(rawDateParts[1]),
          let day = Int(rawDateParts[2]) else {
        throw JulianDayError.invalidDate(birthDate)
    }
    let time = try parseLocalTime(birthTime)

    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = timezone
    let requested = DateComponents(
        timeZone: timezone,
        year: year,
        month: month,
        day: day,
        hour: time.hour,
        minute: time.minute,
        second: time.second
    )
    guard let date = calendar.date(from: requested) else {
        throw JulianDayError.invalidDate("\(birthDate) \(birthTime) \(timezoneName)")
    }

    let resolved = calendar.dateComponents([.year, .month, .day, .hour, .minute, .second], from: date)
    guard resolved.year == year,
          resolved.month == month,
          resolved.day == day,
          resolved.hour == time.hour,
          resolved.minute == time.minute,
          resolved.second == time.second else {
        throw JulianDayError.invalidDate("\(birthDate) \(birthTime) \(timezoneName)")
    }
    return date
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
    let localDate = try localDateFromBirthData(
        birthDate: birthDate,
        birthTime: birthTime,
        timezoneName: timezoneName
    )

    var localCalendar = Calendar(identifier: .gregorian)
    localCalendar.timeZone = tz
    let localComponents = localCalendar.dateComponents([.year, .month, .day], from: localDate)
    guard let year = localComponents.year,
          let month = localComponents.month,
          let day = localComponents.day else {
        throw JulianDayError.invalidDate(birthDate)
    }

    let utcCal = Calendar(identifier: .gregorian)
    guard let utc = TimeZone(identifier: "UTC") else {
        throw JulianDayError.utcUnavailable
    }
    let utcComps = utcCal.dateComponents(in: utc, from: localDate)

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
    isoFormatter.timeZone = utc
    let utcISO = isoFormatter.string(from: localDate)

    return JulianDayResult(
        jd: jd,
        timezoneIANA: timezoneName,
        localISO: localISO,
        utcISO: utcISO,
        utFractionalHours: (utHour * 1_000_000).rounded() / 1_000_000
    )
}
