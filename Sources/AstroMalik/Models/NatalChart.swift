import Foundation

// MARK: - Core Models

struct NatalChart: Identifiable, Codable, Equatable {
    let id: UUID
    var name: String
    var birthDate: String          // YYYY-MM-DD
    var birthTime: String          // HH:mm o HH:mm:ss
    var timezone: String           // IANA (ej. "Europe/Madrid")
    var latitude: Double
    var longitude: Double
    var placeName: String
    var houseSystem: String
    var ascendant: AngularPoint
    var mc: AngularPoint
    var cusps: [Double]            // 12 cúspides en grados
    var bodies: [PlanetBody]
    var createdAt: Date

    init(
        id: UUID = UUID(),
        name: String,
        birthDate: String,
        birthTime: String,
        timezone: String,
        latitude: Double,
        longitude: Double,
        placeName: String,
        houseSystem: String = "Placidus",
        ascendant: AngularPoint,
        mc: AngularPoint,
        cusps: [Double],
        bodies: [PlanetBody],
        createdAt: Date = Date()
    ) {
        self.id = id
        self.name = name
        self.birthDate = birthDate
        self.birthTime = birthTime
        self.timezone = timezone
        self.latitude = latitude
        self.longitude = longitude
        self.placeName = placeName
        self.houseSystem = houseSystem
        self.ascendant = ascendant
        self.mc = mc
        self.cusps = cusps
        self.bodies = bodies
        self.createdAt = createdAt
    }
}

struct AngularPoint: Codable, Equatable {
    var longitude: Double       // grados eclípticos 0-360
    var formatted: String       // "♈ Aries 12°34'"
}

struct PlanetBody: Identifiable, Codable, Equatable {
    var id: String { key }
    var key: String             // "SOL", "LUNA", etc.
    var label: String           // "☉ Sol"
    var longitude: Double
    var formatted: String       // "♈ Aries 12°34'"
    var house: Int
    var retrograde: Bool
}

// MARK: - Natal Aspect

struct NatalAspect: Identifiable, Codable, Equatable {
    var id: String { "\(keyA)_\(keyB)_\(aspKey)" }
    var keyA: String
    var labelA: String
    var keyB: String
    var labelB: String
    var aspLabel: String
    var aspKey: String
    var orb: Double
    var corpusClave: String
}

// MARK: - Helpers

extension PlanetBody {
    var signIndex: Int { Int(longitude.truncatingRemainder(dividingBy: 360) / 30) }
}

// MARK: - Placeholder

extension NatalChart {
    /// Carta vacía utilizada como placeholder cuando no hay ninguna carta activa.
    /// Nunca se muestra al usuario; activa el estado "sin carta" en PrimaryDirectionsView.
    static let placeholder = NatalChart(
        id: UUID(uuidString: "00000000-0000-0000-0000-000000000000")!,
        name: "",
        birthDate: "1970-01-01",
        birthTime: "00:00",
        timezone: "UTC",
        latitude: 0,
        longitude: 0,
        placeName: "",
        houseSystem: "Regiomontanus",
        ascendant: AngularPoint(longitude: 0, formatted: ""),
        mc: AngularPoint(longitude: 270, formatted: ""),
        cusps: Array(repeating: 0.0, count: 12),
        bodies: []
    )

    var isPlaceholder: Bool { id.uuidString == "00000000-0000-0000-0000-000000000000" }
}
