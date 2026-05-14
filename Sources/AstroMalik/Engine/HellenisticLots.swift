import Foundation

enum HellenisticLotError: LocalizedError, Equatable {
    case missingBody(String)

    var errorDescription: String? {
        switch self {
        case .missingBody(let key):
            return "La carta no contiene el cuerpo necesario para calcular el lote: \(key)."
        }
    }
}

struct HellenisticLotsResult: Codable, Equatable {
    var fortune: HellenisticLotPoint
    var spirit: HellenisticLotPoint
}

enum HellenisticLots {
    static func extended(chart: Chart) throws -> [NatalLot] {
        try LotsEngine().lots(chart: chart)
    }

    static func all(chart: Chart) throws -> HellenisticLotsResult {
        HellenisticLotsResult(
            fortune: try fortune(chart: chart),
            spirit: try spirit(chart: chart)
        )
    }

    static func lot(_ lot: ZRLot, chart: Chart) throws -> HellenisticLotPoint {
        switch lot {
        case .fortune:
            return try fortune(chart: chart)
        case .spirit:
            return try spirit(chart: chart)
        }
    }

    static func fortune(chart: Chart) throws -> HellenisticLotPoint {
        let sect = SectEngine.sect(of: chart)
        let sun = try bodyLongitude(AstroPlanetKey.sol.key, in: chart)
        let moon = try bodyLongitude(AstroPlanetKey.luna.key, in: chart)
        let asc = chart.ascendant.longitude
        let longitude = sect.isDiurnal
            ? normalized(asc + moon - sun)
            : normalized(asc + sun - moon)
        return lotPoint(
            key: ZRLot.fortune.rawValue,
            name: ZRLot.fortune.label,
            longitude: longitude,
            sect: sect
        )
    }

    static func spirit(chart: Chart) throws -> HellenisticLotPoint {
        let sect = SectEngine.sect(of: chart)
        let sun = try bodyLongitude(AstroPlanetKey.sol.key, in: chart)
        let moon = try bodyLongitude(AstroPlanetKey.luna.key, in: chart)
        let asc = chart.ascendant.longitude
        let longitude = sect.isDiurnal
            ? normalized(asc + sun - moon)
            : normalized(asc + moon - sun)
        return lotPoint(
            key: ZRLot.spirit.rawValue,
            name: ZRLot.spirit.label,
            longitude: longitude,
            sect: sect
        )
    }

    private static func bodyLongitude(_ key: String, in chart: Chart) throws -> Double {
        guard let body = chart.bodies.first(where: { $0.key == key }) else {
            throw HellenisticLotError.missingBody(key)
        }
        return body.longitude
    }

    private static func lotPoint(
        key: String,
        name: String,
        longitude: Double,
        sect: SectInfo
    ) -> HellenisticLotPoint {
        let index = signIndex(for: longitude)
        return HellenisticLotPoint(
            key: key,
            name: name,
            longitude: longitude,
            formatted: AstroEngine.degToSign(longitude),
            signIndex: index,
            signKey: SIGN_KEYS[index],
            signLabel: SIGN_LABELS[index],
            sect: sect
        )
    }

    private static func signIndex(for longitude: Double) -> Int {
        max(0, min(11, Int(normalized(longitude) / 30.0)))
    }

    private static func normalized(_ degree: Double) -> Double {
        var value = degree.truncatingRemainder(dividingBy: 360.0)
        if value < 0 { value += 360.0 }
        return value
    }
}
