import Foundation

// MARK: - Primary Direction Projection Method

/// Método de proyección para direcciones primarias.
/// Regiomontanus: círculos de posición (default, coherente con horaria).
enum PrimaryDirectionMethod: String, CaseIterable, Identifiable, Codable {
    case regiomontanus = "Regiomontanus"

    var id: String { rawValue }
}
