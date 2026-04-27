import Foundation

// MARK: - Primary Direction Key (Arc → Time Conversion)

/// Clave de medida para convertir arco direccional a tiempo.
/// - Naibod: 0°59'08.33"/año (movimiento solar medio). Default.
/// - Ptolemy: 1°/año exacto.
/// - Brahe: movimiento solar real natal (requiere velocidad del Sol natal).
enum PrimaryDirectionKey: String, CaseIterable, Identifiable, Codable {
    case naibod = "Naibod"
    case ptolemy = "Ptolomeo"
    case brahe = "Brahe"

    var id: String { rawValue }

    /// Grados de arco por año para claves fijas.
    /// Para Brahe, se necesita la velocidad solar natal real.
    var degreesPerYear: Double? {
        switch self {
        case .naibod:
            // 0°59'08.33" = 59/60 + 8.33/3600 = 0.98564722...°
            return 59.0 / 60.0 + 8.33 / 3600.0
        case .ptolemy:
            return 1.0
        case .brahe:
            return nil // Requires natal solar speed
        }
    }
}
