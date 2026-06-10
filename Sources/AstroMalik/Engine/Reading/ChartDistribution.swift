import Foundation

// MARK: - ChartDistribution
// Balance elemental, modal, hemisferios, secta y stelliums a partir de NatalChart.
// Cálculo ligero y puro (conteos sobre datos ya residentes), pensado como base
// del capítulo "Retrato inmediato" de la lectura natal.
//
// Nota: NatalExtendedAnalysisResult.distribution ofrece un cálculo equivalente
// dentro del análisis extendido (asíncrono). Esta utilidad existe para que la
// Lectura funcione de forma síncrona sin depender de ese pipeline; si el
// resultado extendido está disponible, el composer puede preferirlo.

/// Elementos clásicos, indexados por signIndex % 4.
enum ChartElement: Int, CaseIterable, Equatable {
    case fire = 0, earth = 1, air = 2, water = 3

    var label: String {
        switch self {
        case .fire:  return "Fuego"
        case .earth: return "Tierra"
        case .air:   return "Aire"
        case .water: return "Agua"
        }
    }

    var symbol: String {
        switch self {
        case .fire:  return "🜂"
        case .earth: return "🜃"
        case .air:   return "🜁"
        case .water: return "🜄"
        }
    }
}

/// Modalidades, indexadas por signIndex % 3.
enum ChartModality: Int, CaseIterable, Equatable {
    case cardinal = 0, fixed = 1, mutable = 2

    var label: String {
        switch self {
        case .cardinal: return "Cardinal"
        case .fixed:    return "Fijo"
        case .mutable:  return "Mutable"
        }
    }
}

struct ChartStellium: Equatable {
    enum Scope: Equatable { case sign(String), house(Int) }
    let scope: Scope
    let planetKeys: [String]
    let planetLabels: [String]
}

struct ChartDistributionResult: Equatable {
    /// Conteo por elemento (orden: fuego, tierra, aire, agua).
    let elementCounts: [ChartElement: Int]
    /// Conteo por modalidad (orden: cardinal, fijo, mutable).
    let modalityCounts: [ChartModality: Int]
    /// Planetas sobre el horizonte (casas 7–12).
    let aboveHorizonCount: Int
    /// Planetas orientales (casas 10–12 y 1–3).
    let easternCount: Int
    let totalBodies: Int
    /// Carta diurna (Sol sobre el horizonte).
    let isDiurnal: Bool
    /// Stelliums detectados (3+ cuerpos en mismo signo o misma casa).
    let stelliums: [ChartStellium]

    var dominantElement: ChartElement? {
        bestBucket(elementCounts)
    }

    var dominantModality: ChartModality? {
        bestBucket(modalityCounts)
    }

    /// Elementos sin ningún planeta.
    var missingElements: [ChartElement] {
        ChartElement.allCases.filter { (elementCounts[$0] ?? 0) == 0 }
    }

    private func bestBucket<K: CaseIterable & Hashable>(_ counts: [K: Int]) -> K? {
        var best: (key: K, count: Int)?
        // Recorremos allCases para que el desempate sea determinista
        // (gana el primero en orden canónico).
        for key in K.allCases {
            let c = counts[key] ?? 0
            if let current = best {
                if c > current.count { best = (key, c) }
            } else {
                best = (key, c)
            }
        }
        guard let best, best.count > 0 else { return nil }
        return best.key
    }
}

enum ChartDistribution {

    /// Calcula la distribución sobre los cuerpos de la carta (10 planetas).
    /// El ASC no se cuenta en elementos/modalidades (decisión doctrinal:
    /// el temperamento se lee sobre los planetas; el ASC matiza aparte).
    static func compute(chart: NatalChart) -> ChartDistributionResult {
        var elementCounts: [ChartElement: Int] = [:]
        var modalityCounts: [ChartModality: Int] = [:]
        var above = 0
        var eastern = 0

        for body in chart.bodies {
            let signIdx = body.signIndex
            if let element = ChartElement(rawValue: signIdx % 4) {
                elementCounts[element, default: 0] += 1
            }
            if let modality = ChartModality(rawValue: signIdx % 3) {
                modalityCounts[modality, default: 0] += 1
            }
            if (7...12).contains(body.house) { above += 1 }
            if [10, 11, 12, 1, 2, 3].contains(body.house) { eastern += 1 }
        }

        let sunHouse = chart.bodies.first(where: { $0.key == "SOL" })?.house ?? 1
        let diurnal = EssentialDignityEngine.isDiurnal(sunHouse: sunHouse)

        return ChartDistributionResult(
            elementCounts: elementCounts,
            modalityCounts: modalityCounts,
            aboveHorizonCount: above,
            easternCount: eastern,
            totalBodies: chart.bodies.count,
            isDiurnal: diurnal,
            stelliums: findStelliums(chart: chart)
        )
    }

    /// Stellium: 3 o más cuerpos en el mismo signo, o 3 o más en la misma casa.
    /// Si un grupo coincide en signo y casa, se reporta solo por signo.
    static func findStelliums(chart: NatalChart) -> [ChartStellium] {
        var result: [ChartStellium] = []

        var bySign: [Int: [PlanetBody]] = [:]
        for body in chart.bodies {
            bySign[body.signIndex, default: []].append(body)
        }
        var signStelliumKeys: Set<String> = []
        for signIdx in bySign.keys.sorted() {
            guard let group = bySign[signIdx], group.count >= 3 else { continue }
            signStelliumKeys.formUnion(group.map(\.key))
            result.append(ChartStellium(
                scope: .sign(SIGN_KEYS[max(0, min(11, signIdx))]),
                planetKeys: group.map(\.key),
                planetLabels: group.map(\.label)
            ))
        }

        var byHouse: [Int: [PlanetBody]] = [:]
        for body in chart.bodies {
            byHouse[body.house, default: []].append(body)
        }
        for house in byHouse.keys.sorted() {
            guard let group = byHouse[house], group.count >= 3 else { continue }
            // Evitar duplicado exacto del stellium por signo.
            let keys = Set(group.map(\.key))
            if keys.isSubset(of: signStelliumKeys) { continue }
            result.append(ChartStellium(
                scope: .house(house),
                planetKeys: group.map(\.key),
                planetLabels: group.map(\.label)
            ))
        }

        return result
    }
}
