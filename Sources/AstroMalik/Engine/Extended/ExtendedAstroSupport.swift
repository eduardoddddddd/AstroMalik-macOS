import Foundation
import CSwissEph

enum NatalExtendedError: LocalizedError, Equatable {
    case missingBody(String)
    case invalidBirthData
    case swissCalculation(String, String)
    case fixedStarResourceMissing
    case fixedStarResourceInvalid(String)

    var errorDescription: String? {
        switch self {
        case .missingBody(let key): return "Falta el cuerpo natal requerido: \(key)."
        case .invalidBirthData: return "La carta natal no contiene fecha, hora o zona válidas."
        case .swissCalculation(let body, let message): return "Falló el cálculo Swiss Ephemeris de \(body): \(message)"
        case .fixedStarResourceMissing: return "No se encontró el recurso fixed_stars.json."
        case .fixedStarResourceInvalid(let message): return "El recurso fixed_stars.json no es válido: \(message)"
        }
    }
}

enum ExtendedAstro {
    static let traditionalPlanetKeys = ["SOL", "LUNA", "MERCURIO", "VENUS", "MARTE", "JUPITER", "SATURNO"]
    static let tenPlanetKeys = ["SOL", "LUNA", "MERCURIO", "VENUS", "MARTE", "JUPITER", "SATURNO", "URANO", "NEPTUNO", "PLUTON"]
    static let planetAndNodeKeys = tenPlanetKeys + ["NODO_NORTE", "NODO_SUR"]

    static func normalized(_ degree: Double) -> Double {
        var value = degree.truncatingRemainder(dividingBy: 360.0)
        if value < 0 { value += 360.0 }
        return value
    }

    static func angularDistance(_ a: Double, _ b: Double) -> Double {
        var diff = abs(normalized(a) - normalized(b))
        if diff > 180 { diff = 360 - diff }
        return diff
    }

    static func aspectOrb(_ a: Double, _ b: Double, angle: Double) -> Double {
        abs(angularDistance(a, b) - angle)
    }

    static func signIndex(_ longitude: Double) -> Int {
        max(0, min(11, Int(normalized(longitude) / 30.0)))
    }

    static func signKey(_ longitude: Double) -> String { SIGN_KEYS[signIndex(longitude)] }
    static func signLabel(_ longitude: Double) -> String { SIGN_LABELS[signIndex(longitude)] }

    static func element(forSignIndex sign: Int) -> String {
        switch sign {
        case 0, 4, 8: return "Fuego"
        case 1, 5, 9: return "Tierra"
        case 2, 6, 10: return "Aire"
        default: return "Agua"
        }
    }

    static func modality(forSignIndex sign: Int) -> String {
        switch sign {
        case 0, 3, 6, 9: return "Cardinal"
        case 1, 4, 7, 10: return "Fijo"
        default: return "Mutable"
        }
    }

    static func body(_ key: String, in chart: Chart) throws -> PlanetBody {
        guard let body = chart.bodies.first(where: { $0.key == key }) else {
            throw NatalExtendedError.missingBody(key)
        }
        return body
    }

    static func bodyMap(_ chart: Chart) -> [String: PlanetBody] {
        Dictionary(uniqueKeysWithValues: chart.bodies.map { ($0.key, $0) })
    }

    static func bodies(in chart: Chart, keys: [String]) -> [PlanetBody] {
        let map = bodyMap(chart)
        return keys.compactMap { map[$0] }
    }

    static func planetLabel(for key: String) -> String {
        if let fromList = PLANET_LIST.first(where: { $0.key == key })?.label { return fromList }
        switch key {
        case "SOL": return "☉ Sol"
        case "LUNA": return "☽ Luna"
        case "MERCURIO": return "☿ Mercurio"
        case "VENUS": return "♀ Venus"
        case "MARTE": return "♂ Marte"
        case "JUPITER": return "♃ Júpiter"
        case "SATURNO": return "♄ Saturno"
        case "URANO": return "⛢ Urano"
        case "NEPTUNO": return "♆ Neptuno"
        case "PLUTON": return "♇ Plutón"
        case "NODO_NORTE": return "☊ Nodo Norte"
        case "NODO_SUR": return "☋ Nodo Sur"
        case "ASC": return "Ascendente"
        case "MC": return "Medio Cielo"
        case "LOTE_FORTUNA", "PARTE_FORTUNA": return "⊕ Lote de Fortuna"
        default: return key.capitalized
        }
    }

    static func rounded(_ value: Double, places: Int = 4) -> Double {
        let factor = pow(10.0, Double(places))
        return (value * factor).rounded() / factor
    }

    static func birthJulianDay(for chart: Chart) throws -> Double {
        guard !chart.birthDate.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
              !chart.birthTime.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
              !chart.timezone.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw NatalExtendedError.invalidBirthData
        }
        return try julianDayFromLocal(
            birthDate: chart.birthDate,
            birthTime: chart.birthTime,
            timezoneName: chart.timezone
        ).jd
    }

    static func dignityAwards(at longitude: Double, isDiurnal: Bool) -> [DignityAward] {
        EssentialDignityEngine.dignityRulers(at: longitude, isDiurnal: isDiurnal).map { row in
            DignityAward(
                planetKey: row.planet,
                planetLabel: planetLabel(for: row.planet),
                dignity: row.dignity.rawValue,
                points: row.points
            )
        }
    }

    static func formattedDeclination(_ value: Double) -> String {
        let hemisphere = value >= 0 ? "N" : "S"
        let absolute = abs(value)
        let degrees = Int(absolute)
        let minutes = Int(((absolute - Double(degrees)) * 60.0).rounded())
        return "\(hemisphere) \(String(format: "%02d", degrees))°\(String(format: "%02d", minutes))'"
    }

    static func swissLongitude(jd: Double, planetID: Int32, label: String) throws -> Double {
        var xx = [Double](repeating: 0, count: 6)
        var serr = [CChar](repeating: 0, count: 256)
        let rc = swe_calc_ut(jd, planetID, SEFLG_SPEED, &xx, &serr)
        guard rc >= 0 else { throw NatalExtendedError.swissCalculation(label, String(cString: serr)) }
        return normalized(xx[0])
    }
}
