import Foundation

struct LunarReturnRequest: Codable, Equatable {
    var natalChart: NatalChart
    var startDate: Date
    var count: Int
    var placeName: String
    var latitude: Double
    var longitude: Double
    var timezone: String
}

struct LunarReturnReading: Identifiable, Codable, Equatable {
    var id: String {
        "\(natalChart.id.uuidString)-\(Int(startDate.timeIntervalSince1970))-\(count)"
    }

    var natalChart: NatalChart
    var natalMoon: LunarReturnNatalMoon
    var startDate: Date
    var count: Int
    var placeName: String
    var latitude: Double
    var longitude: Double
    var timezone: String
    var events: [LunarReturnEvent]
    var statistics: LunarReturnStatistics

    var coverageSummary: String {
        "\(events.count) retornos lunares"
    }
}

struct LunarReturnNatalMoon: Codable, Equatable {
    var longitude: Double
    var formatted: String
    var house: Int
}

struct LunarReturnEvent: Identifiable, Codable, Equatable {
    var id: Int { index }
    var index: Int
    var exactJD: Double
    var exactLocalDateTime: String
    var exactUTCDateTime: String
    var returnChart: NatalChart
    var ageDays: Double
    var ageYears: Double
    var moon: LunarReturnMoonData
    var natalHouseForReturnAsc: Int
    var natalHouseForReturnMC: Int
    var dominantAspects: [NatalAspect]
    var returnPlanetsInNatalHouses: [LunarReturnNatalHousePlacement]

    // MARK: - Interpretive Fields
    var intensityScore: Int
    var intensityLabel: String
    var ascSignKey: String
    var ascSignLabel: String
    var moonFocusText: String
    var ascToneText: String
    var miniNarrative: String
}

struct LunarReturnMoonData: Codable, Equatable {
    var longitude: Double
    var latitude: Double
    var distance: Double
    var speed: Double
    var formatted: String
    var house: Int
    var precisionArcseconds: Double
    var signKey: String
}

struct LunarReturnNatalHousePlacement: Identifiable, Codable, Equatable {
    var id: String { planetKey }
    var planetKey: String
    var planetLabel: String
    var natalHouse: Int
    var returnHouse: Int
    var formatted: String
}

struct LunarReturnStatistics: Codable, Equatable {
    var averageIntervalDays: Double?
    var shortestIntervalDays: Double?
    var longestIntervalDays: Double?
    var mostFrequentMoonHouse: Int?
    var meanPrecisionArcseconds: Double
    var minPrecisionArcseconds: Double
    var maxSpeed: Double
    var minSpeed: Double
    var maxDistance: Double
    var minDistance: Double
    var averageIntensity: Double
}
