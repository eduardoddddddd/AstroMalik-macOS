import Foundation

// MARK: - ReadingRelevance
// Scoring determinista de relevancia para la lectura natal.
// Decide qué aspectos son "estructurales" (texto completo en la lectura)
// y cuál es el planeta dominante de la carta.
// Receta documentada en docs/LECTURA_NATAL_REFACTOR_ARQUITECTURA.md §3.3.

enum ReadingRelevance {

    static let angularHouses: Set<Int> = [1, 4, 7, 10]

    /// Puntúa un aspecto natal. Factores aditivos:
    ///  +3.0 si involucra una luminaria (Sol o Luna)
    ///  +2.0 si involucra al regente del Ascendente
    ///  +2.0 si alguno de los dos cuerpos es angular (casas 1, 4, 7, 10)
    ///  +2.0 si el orbe es partil (≤ 1°); +1.0 si ≤ 3°
    ///  +1.0 si es aspecto duro (conjunción, cuadratura, oposición)
    ///  +1.0 si involucra al almutén figuris (cuando hay análisis extendido)
    static func aspectScore(
        _ aspect: NatalAspect,
        chart: NatalChart,
        ascRulerKey: String?,
        almutenKey: String? = nil
    ) -> Double {
        var score = 0.0
        let keys = [aspect.keyA, aspect.keyB]

        // Luminarias
        if keys.contains("SOL") || keys.contains("LUNA") {
            score += 3.0
        }
        // Regente del ASC
        if let ascRulerKey, keys.contains(ascRulerKey) {
            score += 2.0
        }
        // Angularidad
        let houses = keys.compactMap { key in
            chart.bodies.first(where: { $0.key == key })?.house
        }
        if houses.contains(where: { angularHouses.contains($0) }) {
            score += 2.0
        }
        // Orbe
        if aspect.orb <= 1.0 {
            score += 2.0
        } else if aspect.orb <= 3.0 {
            score += 1.0
        }
        // Aspecto duro
        if ["CONJUNCION", "CUADRADO", "OPOSICION"].contains(aspect.aspKey) {
            score += 1.0
        }
        // Almutén
        if let almutenKey, keys.contains(almutenKey) {
            score += 1.0
        }
        return score
    }

    /// Ordena aspectos por score descendente; desempate por orbe ascendente
    /// y después por id (orden total determinista).
    static func rankedAspects(
        _ aspects: [NatalAspect],
        chart: NatalChart,
        ascRulerKey: String?,
        almutenKey: String? = nil
    ) -> [(aspect: NatalAspect, score: Double)] {
        aspects
            .map { ($0, aspectScore($0, chart: chart, ascRulerKey: ascRulerKey, almutenKey: almutenKey)) }
            .sorted { lhs, rhs in
                if lhs.1 != rhs.1 { return lhs.1 > rhs.1 }
                if lhs.0.orb != rhs.0.orb { return lhs.0.orb < rhs.0.orb }
                return lhs.0.id < rhs.0.id
            }
    }

    /// Planeta dominante de la carta:
    ///  angularidad (casas 1/10: +3; 4/7: +2)
    ///  + dignidad esencial positiva (score del EssentialDignityEngine, solo tradicionales)
    ///  + 1 por cada aspecto a una luminaria (sin contar al propio cuerpo si es luminaria).
    /// Desempate determinista por orden de PLANET_LIST.
    static func dominantPlanet(
        chart: NatalChart,
        aspects: [NatalAspect],
        isDiurnal: Bool
    ) -> String? {
        guard !chart.bodies.isEmpty else { return nil }
        let traditional: Set<String> = ["SOL", "LUNA", "MERCURIO", "VENUS", "MARTE", "JUPITER", "SATURNO"]

        var best: (key: String, score: Int)?
        for planet in PLANET_LIST {
            guard let body = chart.bodies.first(where: { $0.key == planet.key }) else { continue }
            var score = 0
            // Angularidad
            switch body.house {
            case 1, 10: score += 3
            case 4, 7:  score += 2
            default:    break
            }
            // Dignidad esencial (solo los siete tradicionales)
            if traditional.contains(body.key) {
                let primary = EssentialDignityEngine.primaryDignity(
                    planet: body.key,
                    longitude: body.longitude,
                    isDiurnal: isDiurnal
                )
                score += max(0, primary.score)
            }
            // Aspectos a luminarias
            for aspect in aspects {
                let pair = [aspect.keyA, aspect.keyB]
                guard pair.contains(body.key) else { continue }
                let other = aspect.keyA == body.key ? aspect.keyB : aspect.keyA
                if other == "SOL" || other == "LUNA" {
                    score += 1
                }
            }
            if let current = best {
                if score > current.score { best = (body.key, score) }
            } else {
                best = (body.key, score)
            }
        }
        return best?.key
    }
}
