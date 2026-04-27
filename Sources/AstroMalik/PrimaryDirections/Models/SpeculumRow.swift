import Foundation

// MARK: - Regiomontanus Speculum Row

/// Fila lista para presentar el espéculo Regiomontano completo de una carta.
struct SpeculumRow: Identifiable, Codable, Equatable, Sendable {
    let key: String
    let label: String
    let longitude: Double
    let latitude: Double
    let rightAscension: Double
    let declination: Double
    let meridianDistance: Double
    let zenithDistance: Double
    let pole: Double
    let q: Double
    let w: Double

    var id: String { key }
}
