import Foundation

// MARK: - Primary Directions Service

/// API unificada que combina PrimaryDirectionCalculator + PrimaryDirectionCorpusStore.
/// Punto de entrada único para la capa de ViewModel/View.
///
/// Patrón: el servicio es nonisolated Sendable.
/// El caller ejecuta `compute()` dentro de Task.detached para no bloquear MainActor.
final class PrimaryDirectionsService: Sendable {

    private let calculator: PrimaryDirectionCalculator
    private let corpusStore: PrimaryDirectionCorpusStore?

    init(corpusStore: PrimaryDirectionCorpusStore? = nil) {
        self.calculator = PrimaryDirectionCalculator()
        self.corpusStore = corpusStore
    }

    // MARK: - Main API

    /// Calcula direcciones primarias y enriquece con corpus.
    /// - Parameters:
    ///   - chart: Carta natal
    ///   - jd: Día juliano del nacimiento
    ///   - birthDate: Fecha de nacimiento (para cálculo de edad)
    ///   - config: Configuración (método, clave, aspectos, etc.)
    /// - Returns: Resultado completo con direcciones, interpretaciones y metadatos
    func compute(
        chart: NatalChart,
        jd: Double,
        birthDate: Date,
        config: PrimaryDirectionCalculator.Config
    ) -> PrimaryDirectionsResult {

        // 1. Calcular direcciones
        let directions = calculator.calculate(
            chart: chart,
            jd: jd,
            birthDate: birthDate,
            config: config
        )

        // 2. Enriquecer con corpus (si disponible)
        let interpretations: [PrimaryDirectionInterpretation]
        if let store = corpusStore {
            interpretations = store.buildInterpretations(for: directions)
        } else {
            interpretations = []
        }

        // 3. Construir mapa de interpretaciones por dirección
        let interpMap = Dictionary(
            grouping: interpretations,
            by: \.directionId
        ).mapValues { $0.first! }

        // 4. Construir resultado enriquecido
        let enriched = directions.map { dir in
            EnrichedPrimaryDirection(
                direction: dir,
                interpretation: interpMap[dir.id]
            )
        }

        // 5. Construir resumen temporal (timeline)
        let timeline = Self.buildTimelineEntries(from: enriched)

        // 6. Metadatos
        let metadata = PrimaryDirectionsMetadata(
            totalDirections: directions.count,
            interpretedCount: interpretations.count,
            method: config.method,
            key: config.key,
            aspectPlane: config.aspectPlane,
            maxYears: config.maxYears,
            corpusCoverage: corpusStore?.stats().coveragePercent ?? 0
        )

        return PrimaryDirectionsResult(
            enrichedDirections: enriched,
            timeline: timeline,
            metadata: metadata
        )
    }

    // MARK: - Timeline Builder

    /// Agrupa direcciones por período de vida para la vista de timeline.
    static func buildTimelineEntries(
        from enriched: [EnrichedPrimaryDirection]
    ) -> [PrimaryDirectionTimelineEntry] {
        // Agrupar por décadas (0-10, 10-20, 20-30, etc.)
        let grouped = Dictionary(grouping: enriched) { dir in
            Int(dir.direction.estimatedAge / 10) * 10
        }

        return grouped.sorted { $0.key < $1.key }.map { decade, dirs in
            let sortedDirs = dirs.sorted { abs($0.direction.arc) < abs($1.direction.arc) }

            // Determinar el tono general de la década
            let beneficCount = sortedDirs.filter { $0.direction.aspect.polarity == "benefico" }.count
            let maleficCount = sortedDirs.filter { $0.direction.aspect.polarity == "malefico" }.count
            let tone: PrimaryDirectionTimelineTone
            if beneficCount > maleficCount * 2 { tone = .favorable }
            else if maleficCount > beneficCount * 2 { tone = .challenging }
            else { tone = .mixed }

            return PrimaryDirectionTimelineEntry(
                decadeStart: decade,
                decadeEnd: decade + 10,
                directions: sortedDirs,
                overallTone: tone,
                keyDirection: sortedDirs.first
            )
        }
    }
}

// MARK: - Result Models

/// Resultado completo de la computación de direcciones primarias.
struct PrimaryDirectionsResult: Sendable {
    let enrichedDirections: [EnrichedPrimaryDirection]
    let timeline: [PrimaryDirectionTimelineEntry]
    let metadata: PrimaryDirectionsMetadata

    /// Filtra direcciones por rango de edad.
    func forAgeRange(_ range: ClosedRange<Double>) -> [EnrichedPrimaryDirection] {
        enrichedDirections.filter { range.contains($0.direction.estimatedAge) }
    }

    /// Filtra por aspecto.
    func forAspect(_ aspect: PDaspect) -> [EnrichedPrimaryDirection] {
        enrichedDirections.filter { $0.direction.aspect == aspect }
    }

    /// Filtra por significador.
    func forSignificator(_ sig: String) -> [EnrichedPrimaryDirection] {
        enrichedDirections.filter { $0.direction.significator == sig }
    }

    /// Las más relevantes para la edad actual.
    func nearestToAge(_ age: Double, count: Int = 5) -> [EnrichedPrimaryDirection] {
        enrichedDirections
            .sorted { abs($0.direction.estimatedAge - age) < abs($1.direction.estimatedAge - age) }
            .prefix(count)
            .map { $0 }
    }
}

/// Dirección primaria enriquecida con su interpretación del corpus.
struct EnrichedPrimaryDirection: Identifiable, Sendable {
    var id: UUID { direction.id }
    let direction: PrimaryDirection
    let interpretation: PrimaryDirectionInterpretation?

    var hasInterpretation: Bool { interpretation != nil }

    /// Resumen formateado para display.
    var displaySummary: String {
        "\(direction.promissorLabel) \(direction.aspect.label) \(direction.significatorLabel)"
    }

    /// Edad formateada.
    var ageFormatted: String {
        let years = Int(direction.estimatedAge)
        let months = Int((direction.estimatedAge - Double(years)) * 12)
        if months == 0 { return "\(years) años" }
        return "\(years) años, \(months) meses"
    }

    /// Arco formateado.
    var arcFormatted: String {
        let degrees = Int(abs(direction.arc))
        let minutes = Int((abs(direction.arc) - Double(degrees)) * 60)
        let seconds = Int(((abs(direction.arc) - Double(degrees)) * 60 - Double(minutes)) * 60)
        return "\(degrees)°\(String(format: "%02d", minutes))'\(String(format: "%02d", seconds))\""
    }
}

/// Entrada en el timeline agrupada por década.
struct PrimaryDirectionTimelineEntry: Identifiable, Sendable {
    var id: Int { decadeStart }
    let decadeStart: Int
    let decadeEnd: Int
    let directions: [EnrichedPrimaryDirection]
    let overallTone: PrimaryDirectionTimelineTone
    let keyDirection: EnrichedPrimaryDirection?

    var label: String { "\(decadeStart)-\(decadeEnd) años" }
}

enum PrimaryDirectionTimelineTone: String, Sendable {
    case favorable = "favorable"
    case challenging = "desafiante"
    case mixed = "mixto"

    var emoji: String {
        switch self {
        case .favorable: return "🟢"
        case .challenging: return "🔴"
        case .mixed: return "🟡"
        }
    }
}

/// Metadatos de la computación.
struct PrimaryDirectionsMetadata: Sendable {
    let totalDirections: Int
    let interpretedCount: Int
    let method: PrimaryDirectionMethod
    let key: PrimaryDirectionKey
    let aspectPlane: PDAspectPlane
    let maxYears: Double
    let corpusCoverage: Double
}
