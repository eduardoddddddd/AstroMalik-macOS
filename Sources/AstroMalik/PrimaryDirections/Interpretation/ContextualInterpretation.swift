import Foundation

// MARK: - Contextual Interpretation Model

/// Respuesta decodable del LLM (OpenRouter → modelo configurado).
/// El LLM devuelve JSON estructurado con este schema.
/// Phase 4: Capa 2 de interpretación — autónoma, no depende del corpus Capa 1.
struct ContextualInterpretation: Codable, Equatable, Sendable {

    // MARK: - Campos principales

    /// UUID de la dirección primaria que origina esta interpretación.
    let directionId: UUID

    /// Clave corpus de la dirección: "{PROMISSOR}_{SIGNIFICADOR}_{ASPECTO}"
    let clave: String

    /// Síntesis temática en 2-3 frases. El "titular" de la interpretación.
    let tituloPrincipal: String

    /// Interpretación estructural completa (200-400 palabras).
    /// Doctrina morinista aplicada: qué aporta el promissor al significador
    /// en este aspecto, matizado por los factores de la carta natal.
    let textoEstructural: String

    /// Factores moduladores que el LLM tomó en cuenta.
    let factoresConsiderados: [FactorModulador]

    /// Período estimado de activación (edad ± orbe en meses).
    let periodoActivacion: PeriodoActivacion

    /// Áreas de vida primariamente afectadas.
    let areasAfectadas: [AreaVida]

    /// Nivel de intensidad según factores moduladores (1-10).
    let intensidad: Int

    /// Polaridad general: "benefico", "malefico", "neutro", "mixto".
    let polaridad: String

    /// Timestamp de generación (ISO8601).
    let generadoEn: String

    /// Versión del prompt sistema usado (para invalidación de caché).
    let promptVersion: String

    // MARK: - Nested Types

    struct FactorModulador: Codable, Equatable, Sendable {
        /// Nombre del factor: ej. "dignidad_esencial_marte", "sect_diurna"
        let factor: String
        /// Valor observado: ej. "exilio", "diurna", "angular"
        let valor: String
        /// Cómo modula la interpretación: "amplifica", "atenua", "invierte", "neutro"
        let modulacion: String
    }

    struct PeriodoActivacion: Codable, Equatable, Sendable {
        /// Edad exacta calculada (en años decimales).
        let edadExacta: Double
        /// Orbe de activación en meses (típicamente ±6 meses).
        let orbeEnMeses: Int
        /// Fecha estimada de inicio (ISO8601 date).
        let fechaInicio: String?
        /// Fecha estimada de fin (ISO8601 date).
        let fechaFin: String?
    }

    struct AreaVida: Codable, Equatable, Sendable {
        /// Área: "salud", "carrera", "relaciones", "finanzas", "familia", "viajes", etc.
        let area: String
        /// Peso relativo del impacto en esta área (1-3).
        let peso: Int
    }

    // MARK: - Computed

    /// True si la intensidad es alta (≥7).
    var esAltoImpacto: Bool { intensidad >= 7 }

    /// Orbe de activación formateado para display.
    var periodoFormateado: String {
        let años = Int(periodoActivacion.edadExacta)
        let meses = Int((periodoActivacion.edadExacta - Double(años)) * 12)
        let orbe = periodoActivacion.orbeEnMeses
        if meses == 0 {
            return "\(años) años (±\(orbe) meses)"
        }
        return "\(años) años, \(meses) meses (±\(orbe) meses)"
    }

    /// Emoji indicador de polaridad.
    var polaridadEmoji: String {
        switch polaridad {
        case "benefico":  return "🟢"
        case "malefico":  return "🔴"
        case "mixto":     return "🟡"
        default:          return "⚪️"
        }
    }
}

// MARK: - JSON Schema Helper

extension ContextualInterpretation {
    /// Schema JSON que se incluye en el prompt para guiar la respuesta estructurada del LLM.
    static let jsonSchema = """
    {
      "directionId": "<UUID de la dirección>",
      "clave": "<PROMISSOR_SIGNIFICADOR_ASPECTO>",
      "tituloPrincipal": "<síntesis temática 2-3 frases>",
      "textoEstructural": "<interpretación morinista 200-400 palabras>",
      "factoresConsiderados": [
        {"factor": "<nombre>", "valor": "<valor>", "modulacion": "<amplifica|atenua|invierte|neutro>"}
      ],
      "periodoActivacion": {
        "edadExacta": <número decimal>,
        "orbeEnMeses": <entero>,
        "fechaInicio": "<YYYY-MM-DD o null>",
        "fechaFin": "<YYYY-MM-DD o null>"
      },
      "areasAfectadas": [
        {"area": "<nombre>", "peso": <1|2|3>}
      ],
      "intensidad": <1-10>,
      "polaridad": "<benefico|malefico|neutro|mixto>",
      "generadoEn": "<ISO8601>",
      "promptVersion": "<versión>"
    }
    """
}
