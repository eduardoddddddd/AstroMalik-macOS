import Foundation

struct Interpretation: Identifiable, Codable, Equatable {
    var id: String { clave }
    var clave: String
    var tipo: InterpretationType
    var titulo: String
    var texto: String
    var fuente: String
    var orden: Int
}

enum InterpretationType: String, Codable, CaseIterable {
    case natalPlanetaSigno = "natal_planeta_signo"
    case natalPlanetaCasa  = "natal_planeta_casa"
    case aspectoNatal      = "aspecto_natal"
    case transito          = "transito"
    case sinastria         = "sinastria"
}
