import Foundation

// MARK: - Primary Direction Projection Method

/// Método de proyección para direcciones primarias.
/// Regiomontanus: círculos de posición (default, coherente con horaria).
/// Placidus: semi-arco (under the pole).
enum PrimaryDirectionMethod: String, CaseIterable, Identifiable, Codable {
    case regiomontanus = "Regiomontanus"
    case placidus = "Placidus"

    var id: String { rawValue }
}
