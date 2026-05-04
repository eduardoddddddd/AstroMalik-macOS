import Foundation
import CSwissEph

// MARK: - Ephemeris Utilities

enum EphemerisError: LocalizedError {
    case invalidBracket
    case invalidTimezone(String)
    case calculationFailed(String, String)

    var errorDescription: String? {
        switch self {
        case .invalidBracket:
            return "El intervalo no acota un cruce celeste."
        case .invalidTimezone(let timezone):
            return "Zona horaria IANA no válida: \(timezone)"
        case .calculationFailed(let body, let message):
            return "Falló el cálculo de \(body): \(message)"
        }
    }
}

enum EphemerisUtilities {
    static func normalizedDegree(_ degree: Double) -> Double {
        var d = degree.truncatingRemainder(dividingBy: 360)
        if d < 0 { d += 360 }
        return d
    }

    /// Diferencia firmada mínima entre `angle` y `target`, en el rango [-180, 180).
    static func signedAngularDistance(_ angle: Double, target: Double) -> Double {
        var d = normalizedDegree(angle - target + 180) - 180
        if d == -180 { d = 180 }
        return d
    }

    static func phaseAngle(moonLongitude: Double, sunLongitude: Double) -> Double {
        normalizedDegree(moonLongitude - sunLongitude)
    }

    static func julianDayToDate(_ jd: Double) -> Date {
        Date(timeIntervalSince1970: (jd - 2_440_587.5) * 86_400)
    }

    static func isoUTCString(fromJD jd: Double) -> String {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        return formatter.string(from: julianDayToDate(jd))
    }

    static func localDateTimeString(fromJD jd: Double, timezone: String) throws -> String {
        guard let tz = TimeZone(identifier: timezone) else {
            throw EphemerisError.invalidTimezone(timezone)
        }
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.timeZone = tz
        formatter.locale = Locale(identifier: "es_ES")
        formatter.dateFormat = "yyyy-MM-dd HH:mm"
        return formatter.string(from: julianDayToDate(jd))
    }

    static func localTimeString(fromJD jd: Double, timezone: String) throws -> String {
        guard let tz = TimeZone(identifier: timezone) else {
            throw EphemerisError.invalidTimezone(timezone)
        }
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.timeZone = tz
        formatter.locale = Locale(identifier: "es_ES")
        formatter.dateFormat = "HH:mm"
        return formatter.string(from: julianDayToDate(jd))
    }

    static func signLabel(for longitude: Double) -> String {
        let idx = signIndex(for: longitude)
        return SIGN_LABELS[max(0, min(11, idx))]
    }

    static func signKey(for longitude: Double) -> String {
        let idx = signIndex(for: longitude)
        return SIGN_KEYS[max(0, min(11, idx))]
    }

    static func signIndex(for longitude: Double) -> Int {
        Int(normalizedDegree(longitude) / 30)
    }

    static func planetPosition(jd: Double, planetID: Int32, bodyName: String) throws -> (longitude: Double, speed: Double) {
        var xx = [Double](repeating: 0, count: 6)
        var serr = [CChar](repeating: 0, count: 256)
        let rc = swe_calc_ut(jd, planetID, SEFLG_SPEED, &xx, &serr)
        if rc < 0 {
            throw EphemerisError.calculationFailed(bodyName, String(cString: serr))
        }
        return (normalizedDegree(xx[0]), xx[3])
    }

    static func rounded(_ value: Double, places: Int = 6) -> Double {
        let factor = pow(10.0, Double(places))
        return (value * factor).rounded() / factor
    }
}
