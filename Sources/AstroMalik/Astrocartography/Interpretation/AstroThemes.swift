import Foundation

extension AstroBody {
    /// Plain Spanish name, without the map symbol.
    var spanishName: String {
        switch self {
        case .sun: return "Sol"
        case .moon: return "Luna"
        case .mercury: return "Mercurio"
        case .venus: return "Venus"
        case .mars: return "Marte"
        case .jupiter: return "Júpiter"
        case .saturn: return "Saturno"
        case .uranus: return "Urano"
        case .neptune: return "Neptuno"
        case .pluto: return "Plutón"
        }
    }
}

extension AstroAngle {
    var spanishName: String {
        switch self {
        case .asc: return "Ascendente"
        case .dsc: return "Descendente"
        case .mc: return "Medio Cielo"
        case .ic: return "Fondo del Cielo"
        }
    }
}

/// A theme is a curated set of lines that tradition associates with an area of
/// life. It is a way to filter and sort lines, NOT a measurement: membership
/// carries no weight, and no score or intensity is derived from it.
enum AstroTheme: String, CaseIterable, Identifiable, Sendable {
    case career, relationships, home, identity, growth, intensity

    var id: String { rawValue }

    var title: String {
        switch self {
        case .career: return "Profesión y proyección"
        case .relationships: return "Pareja y vínculos"
        case .home: return "Hogar y raíces"
        case .identity: return "Identidad y presencia"
        case .growth: return "Crecimiento y oportunidades"
        case .intensity: return "Intensidad y transformación"
        }
    }

    /// Why these lines belong to the theme, in plain words for the user.
    var explanation: String {
        switch self {
        case .career: return "Las 10 líneas del Medio Cielo (MC): vida pública, vocación y reputación."
        case .relationships: return "Las 10 líneas del Descendente (DSC), que hablan de los otros, más las 3 de Venus restantes: pareja, socios y acuerdos."
        case .home: return "Las 10 líneas del Fondo del Cielo (IC), más las 3 de la Luna restantes: hogar, familia y base emocional."
        case .identity: return "Las 10 líneas del Ascendente (ASC): cuerpo, carácter y modo de llegar a un lugar."
        case .growth: return "Las 4 líneas de Júpiter y las del Sol en ASC y MC: confianza, expansión y oportunidades."
        case .intensity: return "Todas las líneas de Marte, Saturno, Urano y Plutón: planetas de esfuerzo, cambio y transformación."
        }
    }

    func contains(_ line: AstroLineID) -> Bool {
        switch self {
        case .career: return line.angle == .mc
        case .relationships: return line.angle == .dsc || line.body == .venus
        case .home: return line.angle == .ic || line.body == .moon
        case .identity: return line.angle == .asc
        case .growth:
            return line.body == .jupiter || (line.body == .sun && (line.angle == .asc || line.angle == .mc))
        case .intensity: return [.mars, .saturn, .uranus, .pluto].contains(line.body)
        }
    }

    var lines: [AstroLineID] {
        AstroBody.allCases.flatMap { body in
            AstroAngle.allCases.map { AstroLineID(body: body, angle: $0) }
        }.filter(contains)
    }
}
