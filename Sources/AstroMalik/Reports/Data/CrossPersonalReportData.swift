import Foundation

/// Modelo de datos del informe PDF cross-personal. Está pensado para
/// alimentar la plantilla `cross_personal.html`. Mezcla narrativa
/// (HTML ya convertido desde Markdown de Anthropic) y datos
/// estructurados (tablas y listas) para que el lector tenga a la vez
/// la lectura y la evidencia.
struct CrossPersonalReportData: Codable, Equatable, Sendable {
    let header: ReportHeaderData
    let cover: ReportCoverData
    let includeTOC: Bool
    let generatedDate: String
    let referenceLabel: String
    let scopeLabel: String

    /// Narrativa redactada (Anthropic) ya convertida a HTML, partida en
    /// secciones por encabezado. Cualquier sección puede ser nil; la
    /// plantilla cae en el bloque de datos estructurados cuando falta.
    let narrative: CrossPersonalNarrativeSections

    /// Resumen condensado de la firma natal.
    let signature: CrossPersonalSignatureCard

    /// Tablas de soporte por capa.
    let annualSignals: [CrossPersonalSignalRow]
    let mediumSignals: [CrossPersonalSignalRow]
    let shortSignals: [CrossPersonalSignalRow]
    let lunarSignals: [CrossPersonalSignalRow]

    /// Tabla de top topics ordenada por score descendente.
    let topics: [CrossPersonalTopicRow]

    /// Apéndice técnico (modelo, tokens, coste, fecha) opcional.
    let trazabilityRows: [ReportMetricRow]
}

struct CrossPersonalNarrativeSections: Codable, Equatable, Sendable {
    /// HTML de la síntesis ejecutiva (o vacío si no hubo redacción).
    let executiveSummary: String
    let firmaNatal: String
    let yearInProgress: String
    let mediumTerm: String
    let shortTerm: String
    let lunarLayer: String
    let convergences: String
    let closing: String

    /// Si la redacción no se generó (modo "solo datos"), todas las
    /// secciones serán cadenas vacías; la plantilla detecta el caso y
    /// muestra una nota explicativa.
    var hasContent: Bool {
        ![executiveSummary, firmaNatal, yearInProgress, mediumTerm, shortTerm, lunarLayer, convergences, closing]
            .allSatisfy { $0.isEmpty }
    }

    static let empty = CrossPersonalNarrativeSections(
        executiveSummary: "",
        firmaNatal: "",
        yearInProgress: "",
        mediumTerm: "",
        shortTerm: "",
        lunarLayer: "",
        convergences: "",
        closing: ""
    )
}

struct CrossPersonalSignatureCard: Codable, Equatable, Sendable {
    let sunLabel: String
    let moonLabel: String
    let ascLabel: String
    let mcLabel: String
    let sectLabel: String
    let ascRulerLabel: String
    let almutenLabel: String
    let genitureRulerLabel: String
    let prominentLots: [String]
    let aspectPatterns: [String]
    let elementBalance: String
    let modalityBalance: String
    let fixedStarsTop: [String]
}

struct CrossPersonalSignalRow: Codable, Equatable, Sendable {
    let source: String
    let subject: String
    let summary: String
    let detail: String
    let exactLabel: String
    let weight: String
}

struct CrossPersonalTopicRow: Codable, Equatable, Sendable {
    let rank: String
    let title: String
    let subject: String
    let score: String
    let layerCount: String
    let summary: String
}
