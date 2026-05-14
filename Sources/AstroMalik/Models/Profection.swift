import Foundation

struct ProfectionResult: Codable, Equatable {
    var annual: ProfectionPeriod
    var monthly: [ProfectionPeriod]
    var daily: [ProfectionPeriod]
    var activations: [TransitEvent]
}

enum ProfectionPeriodKind: String, Codable, Equatable {
    case annual
    case monthly
    case daily
}

struct ProfectionPeriod: Identifiable, Codable, Equatable {
    var id: String
    var kind: ProfectionPeriodKind
    var sequence: Int
    var age: Int
    var house: Int
    var signKey: String
    var signLabel: String
    var cuspLongitude: Double
    var cuspFormatted: String
    var lordKey: String
    var lordLabel: String
    var startDate: Date
    var endDate: Date
    var natalPlanetsInHouse: [ProfectionPlanet]
    var natalAspectsByLord: [ProfectionNatalAspect]
}

struct ProfectionPlanet: Identifiable, Codable, Equatable, Hashable {
    var id: String { key }
    var key: String
    var label: String
    var longitude: Double
    var formatted: String
    var house: Int
    var retrograde: Bool
}

struct ProfectionNatalAspect: Identifiable, Codable, Equatable, Hashable {
    var id: String { "\(lotyKey)-\(aspectKey)-\(planetKey)-\(orb)" }
    var lotyKey: String
    var lotyLabel: String
    var planetKey: String
    var planetLabel: String
    var aspectKey: String
    var aspectLabel: String
    var orb: Double
}
