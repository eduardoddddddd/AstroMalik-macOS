import Foundation

/// Resumen predictivo mensual personalizado: cruza el cielo general del mes con una carta natal concreta.
struct MonthlySummary: Identifiable, Equatable {
    let id: String
    let year: Int
    let month: Int
    let chartName: String
    let lunationHits: [LunationNatalHit]
    let eclipseHits: [EclipseNatalHit]
    let stationHits: [StationNatalHit]
    let activeTransits: [TransitEvent]
    let houseIngresses: [TransitHouseIngress]
    let climateSummary: String
}

/// Luna Nueva o Luna Llena localizada en una casa natal, con posible activación planetaria directa.
struct LunationNatalHit: Identifiable, Equatable {
    let id: UUID
    let event: CelestialEvent
    let natalHouse: Int
    let conjunctPlanet: PlanetConjunction?
    let narrative: String

    init(
        id: UUID = UUID(),
        event: CelestialEvent,
        natalHouse: Int,
        conjunctPlanet: PlanetConjunction?,
        narrative: String
    ) {
        self.id = id
        self.event = event
        self.natalHouse = natalHouse
        self.conjunctPlanet = conjunctPlanet
        self.narrative = narrative
    }
}

/// Conjunción de un evento celeste mensual con un planeta natal.
struct PlanetConjunction: Equatable, Hashable {
    let planetKey: String
    let planetLabel: String
    let orb: Double
}

/// Eclipse mensual localizado sobre la carta natal.
struct EclipseNatalHit: Identifiable, Equatable {
    let id: UUID
    let event: CelestialEvent
    let natalHouse: Int
    let conjunctPlanets: [PlanetConjunction]
    let isAngular: Bool
    let narrative: String

    init(
        id: UUID = UUID(),
        event: CelestialEvent,
        natalHouse: Int,
        conjunctPlanets: [PlanetConjunction],
        isAngular: Bool,
        narrative: String
    ) {
        self.id = id
        self.event = event
        self.natalHouse = natalHouse
        self.conjunctPlanets = conjunctPlanets
        self.isAngular = isAngular
        self.narrative = narrative
    }
}

/// Estación planetaria mensual que cae sobre un planeta natal.
struct StationNatalHit: Identifiable, Equatable {
    let id: UUID
    let event: CelestialEvent
    let natalPlanetKey: String
    let natalPlanetLabel: String
    let natalHouse: Int
    let orb: Double
    let narrative: String

    init(
        id: UUID = UUID(),
        event: CelestialEvent,
        natalPlanetKey: String,
        natalPlanetLabel: String,
        natalHouse: Int,
        orb: Double,
        narrative: String
    ) {
        self.id = id
        self.event = event
        self.natalPlanetKey = natalPlanetKey
        self.natalPlanetLabel = natalPlanetLabel
        self.natalHouse = natalHouse
        self.orb = orb
        self.narrative = narrative
    }
}
