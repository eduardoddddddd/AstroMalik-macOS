import Foundation

// MARK: - Primary Direction Model

/// Una dirección primaria calculada entre un prómissor y un significador.
struct PrimaryDirection: Identifiable, Codable, Equatable {
    let id: UUID

    /// Prómissor: planeta o punto que "promete" el evento.
    let promissor: String               // "SOL","LUNA","MERCURIO",...,"ASC","MC","DSC","IC"
    let promissorLabel: String           // "☉ Sol", etc.

    /// Significador: punto sensible que recibe la dirección.
    let significator: String             // "ASC","MC","SOL","LUNA","PARTFORTUNA" o planeta
    let significatorLabel: String

    /// Aspecto formado.
    let aspect: PDaspect
    let aspectAngle: Double              // 0, 60, 90, 120, 180 grados

    /// Tipo de dirección.
    let directionType: PDDirectionType

    /// Plano del aspecto.
    let aspectPlane: PDAspectPlane

    /// Arco direccional en grados ecuatoriales.
    let arc: Double

    /// Edad estimada del evento (arco / clave).
    let estimatedAge: Double

    /// Fecha estimada del evento.
    let estimatedDate: Date

    /// Método de proyección usado.
    let method: PrimaryDirectionMethod

    /// Clave usada.
    let key: PrimaryDirectionKey

    /// Datos técnicos para debug/display.
    let technicalData: PDTechnicalData

    init(
        id: UUID = UUID(),
        promissor: String,
        promissorLabel: String,
        significator: String,
        significatorLabel: String,
        aspect: PDaspect,
        aspectAngle: Double,
        directionType: PDDirectionType,
        aspectPlane: PDAspectPlane,
        arc: Double,
        estimatedAge: Double,
        estimatedDate: Date,
        method: PrimaryDirectionMethod,
        key: PrimaryDirectionKey,
        technicalData: PDTechnicalData
    ) {
        self.id = id
        self.promissor = promissor
        self.promissorLabel = promissorLabel
        self.significator = significator
        self.significatorLabel = significatorLabel
        self.aspect = aspect
        self.aspectAngle = aspectAngle
        self.directionType = directionType
        self.aspectPlane = aspectPlane
        self.arc = arc
        self.estimatedAge = estimatedAge
        self.estimatedDate = estimatedDate
        self.method = method
        self.key = key
        self.technicalData = technicalData
    }
}

// MARK: - Supporting Enums

enum PDaspect: String, CaseIterable, Codable, Equatable {
    case conjunction = "conjuncion"
    case sextile = "sextil"
    case square = "cuadratura"
    case trine = "trigono"
    case opposition = "oposicion"

    var angle: Double {
        switch self {
        case .conjunction: return 0
        case .sextile: return 60
        case .square: return 90
        case .trine: return 120
        case .opposition: return 180
        }
    }

    var label: String {
        switch self {
        case .conjunction: return "☌ Conjunción"
        case .sextile: return "⚹ Sextil"
        case .square: return "□ Cuadratura"
        case .trine: return "△ Trígono"
        case .opposition: return "☍ Oposición"
        }
    }

    /// Polaridad general del aspecto (sin considerar naturaleza del planeta).
    var polarity: String {
        switch self {
        case .conjunction: return "neutro"
        case .sextile, .trine: return "benefico"
        case .square, .opposition: return "malefico"
        }
    }
}

enum PDDirectionType: String, CaseIterable, Codable, Equatable {
    case direct = "directa"      // Significador fijo, prómissor avanza
    case converse = "conversa"   // Prómissor fijo, significador retrocede
}

enum PDAspectPlane: String, CaseIterable, Codable, Equatable {
    case zodiacal = "zodiacal"   // Longitud eclíptica
    case mundane = "mundano"     // Distancia ecuatorial / arco diurno
}

// MARK: - Technical Data

/// Datos técnicos del cálculo para display y debug.
/// Todas las unidades documentadas: grados eclípticos (°) vs grados de AR (°eq).
struct PDTechnicalData: Codable, Equatable {
    /// Ascensión recta del prómissor (grados ecuatoriales, 0-360°).
    let promissorRA: Double

    /// Declinación del prómissor (grados, ±90°).
    let promissorDeclination: Double

    /// Ascensión recta del significador (grados ecuatoriales, 0-360°).
    let significatorRA: Double

    /// Declinación del significador (grados, ±90°).
    let significatorDeclination: Double

    /// Polo de Regiomontanus del significador (grados, 0-90°).
    let significatorPole: Double

    /// Oblicuidad de la eclíptica (grados).
    let obliquity: Double

    /// RAMC: Ascensión Recta del Medio Cielo (grados ecuatoriales).
    let ramc: Double

    /// Latitud geográfica del lugar (grados, ±90°).
    let geoLatitude: Double
}

// MARK: - Hyleg Significators

/// Significadores hylegíacos y Parte de Fortuna con secta.
enum PDSignificator: String, CaseIterable {
    case asc = "ASC"
    case mc = "MC"
    case sun = "SOL"
    case moon = "LUNA"
    case partOfFortune = "PARTFORTUNA"

    var label: String {
        switch self {
        case .asc: return "ASC"
        case .mc: return "MC"
        case .sun: return "☉ Sol"
        case .moon: return "☽ Luna"
        case .partOfFortune: return "⊗ Parte de Fortuna"
        }
    }
}
