import Foundation

// MARK: - NatalReading
// Documento de lectura natal generado determinísticamente por NatalReadingComposer.
// La vista (Sprint R2) renderiza este modelo capítulo a capítulo;
// ReadingNoteBuilder (Sprint R3) lo serializa a Markdown.
// Ver docs/LECTURA_NATAL_REFACTOR_ARQUITECTURA.md.

/// Documento de lectura natal completo.
struct NatalReading: Equatable {
    let chartId: String
    let chapters: [ReadingChapter]
    /// Viñetas del borrador automático de síntesis (hechos duros).
    let synthesisDraft: [String]
    /// Claves de corpus solicitadas pero ausentes — auditoría del corpus.
    let missingKeys: [String]
}

/// Capítulo de la lectura, con ancla estable para el índice (TOC).
struct ReadingChapter: Identifiable, Equatable {
    let id: ReadingChapterKind
    let title: String
    let subtitle: String?
    let blocks: [ReadingBlock]
}

/// Orden canónico de la lectura. El composer emite los capítulos
/// siempre en este orden; los vacíos se omiten.
enum ReadingChapterKind: String, CaseIterable, Identifiable {
    case portrait   // Retrato inmediato
    case triad      // La tríada
    case ascRuler   // Regente del Ascendente
    case dominants  // Dominantes de la carta
    case aspects    // Aspectos estructurales
    case houses     // Las casas: áreas de vida
    case synthesis  // Síntesis

    var id: String { rawValue }

    var defaultTitle: String {
        switch self {
        case .portrait:  return "Retrato inmediato"
        case .triad:     return "La tríada"
        case .ascRuler:  return "El regente del Ascendente"
        case .dominants: return "Dominantes de la carta"
        case .aspects:   return "Aspectos estructurales"
        case .houses:    return "Las casas: áreas de vida"
        case .synthesis: return "Síntesis"
        }
    }
}

/// Bloque atómico de la lectura.
struct ReadingBlock: Identifiable, Equatable {
    /// Identificador estable, p. ej. "triad.SOL", "aspect.SOL_SATURNO_CONJUNCION".
    let id: String
    let kind: ReadingBlockKind
    let emphasis: ReadingEmphasis

    init(id: String, kind: ReadingBlockKind, emphasis: ReadingEmphasis = .normal) {
        self.id = id
        self.kind = kind
        self.emphasis = emphasis
    }
}

enum ReadingBlockKind: Equatable {
    /// Frase-puente generada por plantilla (lead de capítulo o transición).
    case lead(text: String)
    /// Cabecera técnica de un punto de la carta.
    case pointHeader(PointHeaderData)
    /// Texto del corpus, siempre visible. `paragraphs` ya viene partido.
    case corpus(title: String?, paragraphs: [String], source: String)
    /// Fila de chips técnicos (elementos, modalidades, secta…).
    case chips([ReadingChip])
    /// Aspecto compacto de una línea (los no estructurales).
    case aspectLine(AspectLineData)
    /// Lista agrupada en una o pocas líneas (casas vacías, ocupadas compactas…).
    case groupedList(title: String, items: [String])
}

enum ReadingEmphasis: Int, Comparable, Equatable {
    case secondary = 0
    case normal = 1
    case primary = 2

    static func < (lhs: Self, rhs: Self) -> Bool { lhs.rawValue < rhs.rawValue }
}

/// Cabecera técnica de un punto: nombre, posición, casa, dignidad, retro.
struct PointHeaderData: Equatable {
    /// Clave para enfocar la rueda ("SOL", "ASC"…).
    let key: String
    /// "☉ Sol en Capricornio"
    let title: String
    /// "♑ Capricornio 14°22' · Casa 10"
    let detail: String
    /// ["Angular", "℞", "Domicilio"]
    let badges: [String]
}

struct ReadingChip: Equatable {
    let label: String
    let value: String
    let tint: ChipTint

    enum ChipTint: Equatable {
        case fire, earth, air, water, neutral, accent
    }
}

struct AspectLineData: Equatable {
    let id: String
    /// "☿ Mercurio △ Trígono ♃ Júpiter · 3°41'"
    let text: String
    /// Score de relevancia (ReadingRelevance) — para orden estable.
    let score: Double
}
