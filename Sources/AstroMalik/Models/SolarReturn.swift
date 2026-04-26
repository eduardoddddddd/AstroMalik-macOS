import Foundation

struct SolarReturnRequest: Codable, Equatable {
    var natalChart: NatalChart
    var year: Int
    var placeName: String
    var latitude: Double
    var longitude: Double
    var timezone: String
}

struct SolarReturnReading: Identifiable, Codable, Equatable {
    var id: String { "\(natalChart.id.uuidString)-\(year)" }
    var natalChart: NatalChart
    var solarChart: NatalChart
    var year: Int
    var exactJD: Double
    var exactLocalDateTime: String
    var exactUTCDateTime: String
    var placeName: String
    var latitude: Double
    var longitude: Double
    var timezone: String
    var natalHouseForSolarAsc: Int
    var natalHouseForSolarMC: Int
    var solarPlanetsInNatalHouses: [SolarReturnNatalHousePlacement]
    var dominantAspects: [NatalAspect]
    var interpretations: [Interpretation]

    // MARK: - Guided Reading Fields
    var yearThemeTitle: String
    var yearThemeText: String
    var yearToneText: String
    var ascSignKey: String
    var ascSignLabel: String
    var rulerKey: String
    var rulerLabel: String
    var rulerNatalHouse: Int
    var rulerText: String
    var moonHouse: Int
    var moonFormatted: String
    var moonText: String
    var angularPlanets: [SolarReturnAngularPlanet]
    var natalRepetitions: [SolarReturnRepetition]

    var coverageSummary: String {
        "\(interpretations.count) textos del corpus natal"
    }
}

struct SolarReturnNatalHousePlacement: Identifiable, Codable, Equatable {
    var id: String { planetKey }
    var planetKey: String
    var planetLabel: String
    var natalHouse: Int
    var solarHouse: Int
    var formatted: String
}

/// Planeta en casa angular de la revolución solar.
struct SolarReturnAngularPlanet: Identifiable, Codable, Equatable {
    var id: String { planetKey }
    var planetKey: String
    var planetLabel: String
    var solarHouse: Int
    var natalHouse: Int
    var formatted: String
}

/// Cuando un planeta RS cae en la misma casa que en la natal.
struct SolarReturnRepetition: Identifiable, Codable, Equatable {
    var id: String { planetKey }
    var planetKey: String
    var planetLabel: String
    var house: Int
    var formatted: String
}
