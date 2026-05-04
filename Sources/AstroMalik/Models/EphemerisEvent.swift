import Foundation

// MARK: - Ephemeris Event Models

/// Tipo unificado de evento celeste para el calendario astrológico.
enum CelestialEventKind: String, Codable, CaseIterable {
    case newMoon
    case fullMoon
    case firstQuarter
    case lastQuarter
    case solarEclipse
    case lunarEclipse
    case stationRetrograde
    case stationDirect
    case signIngress
    case voidOfCourse
    case voidOfCourseEnd
    case mundaneAspect
}

/// Importancia visual/doctrinal de un evento en el calendario.
enum EventImportance: Int, Codable, Comparable {
    case minor = 1
    case moderate = 2
    case major = 3
    case critical = 4

    static func < (lhs: EventImportance, rhs: EventImportance) -> Bool {
        lhs.rawValue < rhs.rawValue
    }
}

/// Evento celeste individual mostrado por el calendario/efemérides.
struct CelestialEvent: Identifiable, Codable, Equatable {
    let id: UUID
    let kind: CelestialEventKind
    let dateUTC: String
    let dateLocal: String
    let longitude: Double?
    let signKey: String?
    let signLabel: String?
    let formatted: String?

    let planetKeyA: String?
    let planetLabelA: String?
    let planetKeyB: String?
    let planetLabelB: String?
    let aspectKey: String?
    let aspectLabel: String?

    let eclipseType: String?
    let eclipseMagnitude: Double?

    let stationSpeed: Double?

    let voidEnds: String?
    let voidDurationMinutes: Int?
    let lastAspectPlanet: String?
    let lastAspectType: String?

    let ingressDirection: String?

    let title: String
    let subtitle: String?
    let importance: EventImportance

    init(
        id: UUID = UUID(),
        kind: CelestialEventKind,
        dateUTC: String,
        dateLocal: String,
        longitude: Double? = nil,
        signKey: String? = nil,
        signLabel: String? = nil,
        formatted: String? = nil,
        planetKeyA: String? = nil,
        planetLabelA: String? = nil,
        planetKeyB: String? = nil,
        planetLabelB: String? = nil,
        aspectKey: String? = nil,
        aspectLabel: String? = nil,
        eclipseType: String? = nil,
        eclipseMagnitude: Double? = nil,
        stationSpeed: Double? = nil,
        voidEnds: String? = nil,
        voidDurationMinutes: Int? = nil,
        lastAspectPlanet: String? = nil,
        lastAspectType: String? = nil,
        ingressDirection: String? = nil,
        title: String,
        subtitle: String? = nil,
        importance: EventImportance
    ) {
        self.id = id
        self.kind = kind
        self.dateUTC = dateUTC
        self.dateLocal = dateLocal
        self.longitude = longitude
        self.signKey = signKey
        self.signLabel = signLabel
        self.formatted = formatted
        self.planetKeyA = planetKeyA
        self.planetLabelA = planetLabelA
        self.planetKeyB = planetKeyB
        self.planetLabelB = planetLabelB
        self.aspectKey = aspectKey
        self.aspectLabel = aspectLabel
        self.eclipseType = eclipseType
        self.eclipseMagnitude = eclipseMagnitude
        self.stationSpeed = stationSpeed
        self.voidEnds = voidEnds
        self.voidDurationMinutes = voidDurationMinutes
        self.lastAspectPlanet = lastAspectPlanet
        self.lastAspectType = lastAspectType
        self.ingressDirection = ingressDirection
        self.title = title
        self.subtitle = subtitle
        self.importance = importance
    }
}

/// Posición diaria para la tabla clásica de efemérides.
struct DailyEphemerisRow: Identifiable, Codable, Equatable {
    let id: UUID
    let date: String
    let positions: [PlanetDailyPosition]
    let lunarPhaseAngle: Double
    let lunarPhaseLabel: String

    init(
        id: UUID = UUID(),
        date: String,
        positions: [PlanetDailyPosition],
        lunarPhaseAngle: Double,
        lunarPhaseLabel: String
    ) {
        self.id = id
        self.date = date
        self.positions = positions
        self.lunarPhaseAngle = lunarPhaseAngle
        self.lunarPhaseLabel = lunarPhaseLabel
    }
}

struct PlanetDailyPosition: Codable, Equatable {
    let planetKey: String
    let longitude: Double
    let formatted: String
    let speed: Double
    let retrograde: Bool
    let signKey: String
}

/// Contenedor mensual del futuro módulo Calendario/Efemérides.
struct EphemerisMonth: Identifiable, Equatable {
    let id: String
    let year: Int
    let month: Int
    let events: [CelestialEvent]
    let dailyRows: [DailyEphemerisRow]

    var eventsByDay: [String: [CelestialEvent]] {
        Dictionary(grouping: events) { event in
            String(event.dateLocal.prefix(10))
        }
    }
}
