import Foundation

// MARK: - Essential Dignity Engine
// Tablas ptolemaicas tradicionales (Tetrabiblos + Bonatti + Lilly).
// Motor puro de cálculo — sin dependencias, sin estado, todo static.
// Fuentes:
//   - Domicilios/Exaltaciones: Ptolomeo, Tetrabiblos I.17-20
//   - Triplicidades: Doroteo de Sidón (adaptado Lilly CA pp. 104-106)
//   - Términos: Términos Egipcios (Bonatti/Lilly CA p. 104)
//   - Decanatos/Caras: Bonatti, Liber Astronomiae Tract. II

enum EssentialDignity: String, Sendable {
    case domicile        = "domicilio"
    case exaltation      = "exaltacion"
    case triplicity      = "triplicidad"
    case term            = "termino"
    case face            = "faz"
    case peregrine       = "peregrino"
    case detriment       = "exilio"
    case fall            = "caida"
}

struct EssentialDignityScore: Sendable {
    let dignity: EssentialDignity
    let score: Int          // +5 domicilio, +4 exaltación, +3 triplicidad, +2 término, +1 faz, -5 exilio, -4 caída
    let ruler: String?      // Planeta que confiere la dignidad (triplicidad/término/faz)
}

// MARK: - Engine

enum EssentialDignityEngine {

    // MARK: - Primary API

    /// Calcula la dignidad esencial más alta de un planeta en un grado dado.
    /// Retorna el array de dignidades aplicables ordenadas por score.
    static func dignities(planet: String, longitude: Double) -> [EssentialDignityScore] {
        let sign = signIndex(longitude)
        let degInSign = Int(longitude.truncatingRemainder(dividingBy: 360)
                             .truncatingRemainder(dividingBy: 30))

        var results: [EssentialDignityScore] = []

        // 1. Domicilio (+5)
        if domicileRuler(of: sign) == planet {
            results.append(.init(dignity: .domicile, score: 5, ruler: planet))
        }
        // 2. Exilio (-5) — opuesto al domicilio
        if detrimentSign(of: planet) == sign {
            results.append(.init(dignity: .detriment, score: -5, ruler: nil))
        }
        // 3. Exaltación (+4)
        if let (exSign, _) = exaltation(of: planet), exSign == sign {
            results.append(.init(dignity: .exaltation, score: 4, ruler: planet))
        }
        // 4. Caída (-4) — opuesto a exaltación
        if let (exSign, _) = exaltation(of: planet) {
            let fallSign = (exSign + 6) % 12
            if fallSign == sign {
                results.append(.init(dignity: .fall, score: -4, ruler: nil))
            }
        }
        // 5. Triplicidad (+3)
        if let triRuler = triplicityRuler(sign: sign, planet: planet) {
            results.append(.init(dignity: .triplicity, score: 3, ruler: triRuler))
        }
        // 6. Término (+2) — Términos Egipcios
        if let termRuler = egyptianTermRuler(sign: sign, degreeInSign: degInSign),
           termRuler == planet {
            results.append(.init(dignity: .term, score: 2, ruler: termRuler))
        }
        // 7. Faz/Decanato (+1)
        if let faceRuler = faceRuler(sign: sign, degreeInSign: degInSign),
           faceRuler == planet {
            results.append(.init(dignity: .face, score: 1, ruler: faceRuler))
        }
        // 8. Peregrino (0) — si no tiene ninguna dignidad positiva ni debilidad
        if results.isEmpty {
            results.append(.init(dignity: .peregrine, score: 0, ruler: nil))
        }

        return results.sorted { abs($0.score) > abs($1.score) }
    }

    /// Dignidad principal (la de mayor score absoluto).
    static func primaryDignity(planet: String, longitude: Double) -> EssentialDignityScore {
        dignities(planet: planet, longitude: longitude).first
            ?? .init(dignity: .peregrine, score: 0, ruler: nil)
    }

    /// Descripción textual concisa para incluir en el prompt LLM.
    static func description(planet: String, longitude: Double) -> String {
        let d = primaryDignity(planet: planet, longitude: longitude)
        return d.dignity.rawValue
    }

    /// True si el planeta está en sect (carta diurna vs nocturna).
    /// Sect diurna: Sol, Saturno, Júpiter. Sect nocturna: Luna, Marte, Venus.
    /// Mercurio es de ambas sects.
    static func isInSect(planet: String, isDiurnal: Bool) -> Bool {
        switch planet {
        case "SOL", "SATURNO", "JUPITER":   return isDiurnal
        case "LUNA", "MARTE", "VENUS":      return !isDiurnal
        case "MERCURIO":                     return true
        default:                             return false  // Urano, Neptuno, Plutón — sin sect clásica
        }
    }

    /// True si la carta es diurna (Sol en casas 7-12, sobre el horizonte).
    static func isDiurnal(sunHouse: Int) -> Bool {
        // Casas 7, 8, 9, 10, 11, 12 = sobre el horizonte (diurna)
        return sunHouse >= 7
    }

    /// Retorna el planet que rige el signo en el que está un planeta dado.
    static func dispositor(of planet: String, inChart bodies: [String: Double]) -> String? {
        guard let lon = bodies[planet] else { return nil }
        let sign = signIndex(lon)
        return domicileRuler(of: sign)
    }

    // MARK: - Domicilios (Ptolomeo, Tetrabiblos I.17)
    // Signos: 0=Aries, 1=Tauro, 2=Géminis, 3=Cáncer, 4=Leo, 5=Virgo,
    //         6=Libra, 7=Escorpio, 8=Sagitario, 9=Capricornio, 10=Acuario, 11=Piscis

    static func domicileRuler(of sign: Int) -> String {
        switch sign {
        case 0:  return "MARTE"       // Aries
        case 1:  return "VENUS"       // Tauro
        case 2:  return "MERCURIO"    // Géminis
        case 3:  return "LUNA"        // Cáncer
        case 4:  return "SOL"         // Leo
        case 5:  return "MERCURIO"    // Virgo
        case 6:  return "VENUS"       // Libra
        case 7:  return "MARTE"       // Escorpio
        case 8:  return "JUPITER"     // Sagitario
        case 9:  return "SATURNO"     // Capricornio
        case 10: return "SATURNO"     // Acuario
        case 11: return "JUPITER"     // Piscis
        default: return "SOL"
        }
    }

    /// Signo de exilio de un planeta (opuesto a su domicilio).
    static func detrimentSign(of planet: String) -> Int? {
        // Para planetas con dos domicilios, ambos opuestos son exilios
        switch planet {
        case "SOL":      return 6   // Libra (opuesto Leo)
        case "LUNA":     return 9   // Capricornio (opuesto Cáncer)
        case "MERCURIO": return nil // Tiene Géminis y Virgo — exilios en Sagitario y Piscis
        case "VENUS":    return nil // Tauro y Libra — exilios en Escorpio y Aries
        case "MARTE":    return nil // Aries y Escorpio — exilios en Libra y Tauro
        case "JUPITER":  return nil // Sagitario y Piscis — exilios en Géminis y Virgo
        case "SATURNO":  return nil // Capricornio y Acuario — exilios en Cáncer y Leo
        default: return nil
        }
    }

    /// Comprueba exilio para planetas de dos domicilios.
    private static func isInDetriment(planet: String, sign: Int) -> Bool {
        switch planet {
        case "SOL":      return sign == 6
        case "LUNA":     return sign == 9
        case "MERCURIO": return sign == 8 || sign == 11
        case "VENUS":    return sign == 7 || sign == 0
        case "MARTE":    return sign == 6 || sign == 1
        case "JUPITER":  return sign == 2 || sign == 5
        case "SATURNO":  return sign == 3 || sign == 4
        default: return false
        }
    }

    // MARK: - Exaltaciones (Ptolomeo, Tetrabiblos I.19)
    // (signIndex, degreeExact) — el grado exacto es el punto de mayor poder

    static func exaltation(of planet: String) -> (sign: Int, degree: Int)? {
        switch planet {
        case "SOL":      return (0, 19)   // Aries 19°
        case "LUNA":     return (1, 3)    // Tauro 3°
        case "MERCURIO": return (5, 15)   // Virgo 15°
        case "VENUS":    return (11, 27)  // Piscis 27°
        case "MARTE":    return (9, 28)   // Capricornio 28°
        case "JUPITER":  return (3, 15)   // Cáncer 15°
        case "SATURNO":  return (6, 21)   // Libra 21°
        default: return nil
        }
    }

    // MARK: - Triplicidades (Doroteo/Lilly CA pp. 104-106)
    // Regente diurno y nocturno para cada triplicidad de fuego/tierra/aire/agua.
    // Retorna el regente si coincide con el planeta dado.

    private static func triplicityRuler(sign: Int, planet: String) -> String? {
        // Fuego (Aries, Leo, Sagitario): diurno=Sol, nocturno=Júpiter, cooperante=Saturno
        // Tierra (Tauro, Virgo, Capricornio): diurno=Venus, nocturno=Luna, cooperante=Marte
        // Aire (Géminis, Libra, Acuario): diurno=Saturno, nocturno=Mercurio, cooperante=Júpiter
        // Agua (Cáncer, Escorpio, Piscis): diurno=Venus, nocturno=Marte, cooperante=Luna
        let triplRulers: [String]
        switch sign {
        case 0, 4, 8:   triplRulers = ["SOL", "JUPITER", "SATURNO"]         // Fuego
        case 1, 5, 9:   triplRulers = ["VENUS", "LUNA", "MARTE"]            // Tierra
        case 2, 6, 10:  triplRulers = ["SATURNO", "MERCURIO", "JUPITER"]    // Aire
        case 3, 7, 11:  triplRulers = ["VENUS", "MARTE", "LUNA"]            // Agua
        default: triplRulers = []
        }
        return triplRulers.contains(planet) ? planet : nil
    }

    // MARK: - Términos Egipcios (Bonatti / Lilly CA p. 104)
    // Cada signo se divide en 5 términos de longitud variable.
    // Estructura: (ruler, endDegree) — el planeta rige hasta ese grado (exclusivo).

    private static let egyptianTerms: [[( ruler: String, endDeg: Int)]] = [
        // 0 Aries:      Júpiter 0-6, Venus 6-12, Mercurio 12-20, Marte 20-25, Saturno 25-30
        [("JUPITER",6),("VENUS",12),("MERCURIO",20),("MARTE",25),("SATURNO",30)],
        // 1 Tauro:      Venus 0-8, Mercurio 8-14, Júpiter 14-22, Saturno 22-27, Marte 27-30
        [("VENUS",8),("MERCURIO",14),("JUPITER",22),("SATURNO",27),("MARTE",30)],
        // 2 Géminis:    Mercurio 0-6, Júpiter 6-12, Venus 12-17, Marte 17-24, Saturno 24-30
        [("MERCURIO",6),("JUPITER",12),("VENUS",17),("MARTE",24),("SATURNO",30)],
        // 3 Cáncer:     Marte 0-7, Venus 7-13, Mercurio 13-19, Júpiter 19-26, Saturno 26-30
        [("MARTE",7),("VENUS",13),("MERCURIO",19),("JUPITER",26),("SATURNO",30)],
        // 4 Leo:        Júpiter 0-6, Venus 6-11, Saturno 11-18, Mercurio 18-24, Marte 24-30
        [("JUPITER",6),("VENUS",11),("SATURNO",18),("MERCURIO",24),("MARTE",30)],
        // 5 Virgo:      Mercurio 0-7, Venus 7-17, Júpiter 17-21, Marte 21-28, Saturno 28-30
        [("MERCURIO",7),("VENUS",17),("JUPITER",21),("MARTE",28),("SATURNO",30)],
        // 6 Libra:      Saturno 0-6, Mercurio 6-14, Júpiter 14-21, Venus 21-28, Marte 28-30
        [("SATURNO",6),("MERCURIO",14),("JUPITER",21),("VENUS",28),("MARTE",30)],
        // 7 Escorpio:   Marte 0-7, Venus 7-11, Mercurio 11-19, Júpiter 19-24, Saturno 24-30
        [("MARTE",7),("VENUS",11),("MERCURIO",19),("JUPITER",24),("SATURNO",30)],
        // 8 Sagitario:  Júpiter 0-12, Venus 12-17, Mercurio 17-21, Saturno 21-26, Marte 26-30
        [("JUPITER",12),("VENUS",17),("MERCURIO",21),("SATURNO",26),("MARTE",30)],
        // 9 Capricornio: Mercurio 0-7, Júpiter 7-14, Venus 14-22, Saturno 22-26, Marte 26-30
        [("MERCURIO",7),("JUPITER",14),("VENUS",22),("SATURNO",26),("MARTE",30)],
        // 10 Acuario:   Saturno 0-6, Mercurio 6-12, Venus 12-20, Júpiter 20-25, Marte 25-30
        [("SATURNO",6),("MERCURIO",12),("VENUS",20),("JUPITER",25),("MARTE",30)],
        // 11 Piscis:    Venus 0-8, Júpiter 8-14, Mercurio 14-20, Marte 20-26, Saturno 26-30
        [("VENUS",8),("JUPITER",14),("MERCURIO",20),("MARTE",26),("SATURNO",30)],
    ]

    private static func egyptianTermRuler(sign: Int, degreeInSign: Int) -> String? {
        guard sign >= 0, sign < 12 else { return nil }
        for term in egyptianTerms[sign] {
            if degreeInSign < term.endDeg { return term.ruler }
        }
        return nil
    }

    // MARK: - Decanatos/Caras (Chaldean/Bonatti)
    // 36 decanatos de 10° cada uno, en orden caldeo: Marte, Sol, Venus, Mercurio, Luna, Saturno, Júpiter...
    // El orden empieza en Aries 0-10° = Marte.

    private static let chaldeanOrder = ["MARTE","SOL","VENUS","MERCURIO","LUNA","SATURNO","JUPITER"]

    private static func faceRuler(sign: Int, degreeInSign: Int) -> String? {
        let decanIndex = sign * 3 + degreeInSign / 10
        return chaldeanOrder[decanIndex % 7]
    }

    // MARK: - Helpers

    static func signIndex(_ longitude: Double) -> Int {
        Int(longitude.truncatingRemainder(dividingBy: 360) / 30)
    }

    static func signName(_ index: Int) -> String {
        let names = ["Aries","Tauro","Géminis","Cáncer","Leo","Virgo",
                     "Libra","Escorpio","Sagitario","Capricornio","Acuario","Piscis"]
        return names[max(0, min(11, index))]
    }

    // MARK: - Mutual Reception

    /// True si planeta A está en el domicilio de B, y B en el domicilio de A.
    static func mutualReceptionByDomicile(
        planetA: String, lonA: Double,
        planetB: String, lonB: Double
    ) -> Bool {
        let signA = signIndex(lonA)
        let signB = signIndex(lonB)
        return domicileRuler(of: signA) == planetB && domicileRuler(of: signB) == planetA
    }
}
