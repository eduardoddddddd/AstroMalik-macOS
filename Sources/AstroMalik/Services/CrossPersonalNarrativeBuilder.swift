import Foundation

/// Resultado de una redacción cross-personal vía Anthropic.
struct CrossPersonalNarrative: Codable, Equatable {
    let markdown: String
    let model: String
    let usage: AnthropicUsage
    let estimatedCostUSD: Double
    let generatedAt: Date
    let referenceDate: Date
    let chartName: String
}

/// Errores propios de la redacción cross-personal.
enum CrossPersonalNarrativeError: LocalizedError {
    case missingTemplate
    case anthropic(AnthropicError)
    case encodingFailure(String)

    var errorDescription: String? {
        switch self {
        case .missingTemplate:
            return "No se encontró la plantilla cross_personal_prompt.md en el bundle."
        case .anthropic(let underlying):
            return underlying.errorDescription
        case .encodingFailure(let detail):
            return "Error serializando el estado: \(detail)"
        }
    }
}

/// Alcance narrativo solicitado al LLM. El estado astrológico sigue siendo
/// completo; esta opción sólo acota la redacción final.
enum CrossPersonalNarrativeScope: String, Codable, Equatable, CaseIterable {
    case complete
    case annual
    case monthly
    case weekly

    var instruction: String {
        switch self {
        case .complete:
            return "Informe completo: integra la arquitectura natal y todas las capas temporales disponibles sin recortar el horizonte."
        case .annual:
            return "Informe anual: prioriza profección, revolución solar, firdaria, direcciones primarias/arco solar y tendencias de fondo del año en curso."
        case .monthly:
            return "Informe mensual: prioriza progresiones, tránsitos del mes, activaciones exactas cercanas y lunaciones/eclipses relevantes."
        case .weekly:
            return "Informe semanal: sintetiza la semana práctica; prioriza tránsitos cercanos, lunaciones inmediatas, señales exactas y temas accionables."
        }
    }
}

/// Orquesta la transformación `CrossPersonalState` → JSON resumido →
/// llamada Anthropic → Markdown narrativo.
struct CrossPersonalNarrativeBuilder {
    let client: AnthropicClient
    let templateLoader: () throws -> String

    /// Loader por defecto que lee la plantilla del bundle de recursos.
    static func defaultTemplateLoader() -> () throws -> String {
        return {
            guard let url = AppResources.bundle.url(forResource: "cross_personal_prompt", withExtension: "md") else {
                throw CrossPersonalNarrativeError.missingTemplate
            }
            return try String(contentsOf: url, encoding: .utf8)
        }
    }

    init(
        client: AnthropicClient = AnthropicClient(),
        templateLoader: @escaping () throws -> String = CrossPersonalNarrativeBuilder.defaultTemplateLoader()
    ) {
        self.client = client
        self.templateLoader = templateLoader
    }

    /// Genera el informe redactado. NO persiste — el caller decide qué hacer
    /// con el resultado (mostrarlo en UI, guardar en Joplin, exportar a PDF).
    func build(state: CrossPersonalState) async throws -> CrossPersonalNarrative {
        try await build(state: state, scope: .complete)
    }

    func build(state: CrossPersonalState, scope: CrossPersonalNarrativeScope) async throws -> CrossPersonalNarrative {
        let systemPrompt: String
        do {
            systemPrompt = try templateLoader()
        } catch let error as CrossPersonalNarrativeError {
            throw error
        } catch {
            throw CrossPersonalNarrativeError.missingTemplate
        }

        let payload = try makeUserPayload(state: state, scope: scope)
        let response: AnthropicMessageResponse
        do {
            response = try await client.send(systemPrompt: systemPrompt, userPayload: payload)
        } catch let error as AnthropicError {
            throw CrossPersonalNarrativeError.anthropic(error)
        }

        let cost = response.usage.estimatedCostUSD(model: response.model)
        return CrossPersonalNarrative(
            markdown: response.combinedText,
            model: response.model,
            usage: response.usage,
            estimatedCostUSD: cost,
            generatedAt: Date(),
            referenceDate: state.metadata.referenceDate,
            chartName: state.metadata.chartName
        )
    }

    // MARK: - Serialization

    /// Construye el contenido del mensaje user: cabecera explicativa breve
    /// + JSON con el estado completo. Mantenemos el JSON compacto para
    /// reducir tokens de input sin perder información.
    private func makeUserPayload(state: CrossPersonalState, scope: CrossPersonalNarrativeScope) throws -> String {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.sortedKeys]
        encoder.keyEncodingStrategy = .convertToSnakeCase

        let data: Data
        do {
            data = try encoder.encode(state)
        } catch {
            throw CrossPersonalNarrativeError.encodingFailure(error.localizedDescription)
        }
        guard let jsonString = String(data: data, encoding: .utf8) else {
            throw CrossPersonalNarrativeError.encodingFailure("JSON no codificable a UTF-8")
        }

        let referenceLabel = displayDate(state.metadata.referenceDate)

        return """
        Carta: \(state.metadata.chartName)
        Fecha de referencia: \(referenceLabel)
        Alcance solicitado: \(scope.rawValue)
        Instrucción de alcance: \(scope.instruction)

        Estado astrológico cross-personal (JSON estructurado):
        \(jsonString)
        """
    }

    private func displayDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "es_ES")
        formatter.dateStyle = .long
        formatter.timeStyle = .none
        return formatter.string(from: date)
    }
}

// MARK: - Joplin Markdown wrapper

extension CrossPersonalNarrative {
    /// Markdown final para Joplin con cabecera estandar y nota de
    /// trazabilidad sobre modelo, coste y fecha.
    func joplinMarkdown() -> String {
        let costFormatted = String(format: "%.4f", estimatedCostUSD)
        let dateFormatter = DateFormatter()
        dateFormatter.locale = Locale(identifier: "es_ES")
        dateFormatter.dateStyle = .long
        dateFormatter.timeStyle = .short
        let generatedLabel = dateFormatter.string(from: generatedAt)
        return """
        \(markdown)

        ---

        _Generado por AstroMalik cross-personal_

        - Modelo: `\(model)`
        - Tokens entrada / salida: \(usage.inputTokens) / \(usage.outputTokens)
        - Cache (lectura / creación): \(usage.cacheReadInputTokens ?? 0) / \(usage.cacheCreationInputTokens ?? 0)
        - Coste estimado: $\(costFormatted) USD
        - Fecha: \(generatedLabel)
        """
    }

    /// Título sugerido para la nota Joplin.
    func suggestedJoplinTitle() -> String {
        let dateFormatter = DateFormatter()
        dateFormatter.locale = Locale(identifier: "es_ES")
        dateFormatter.dateFormat = "yyyy-MM-dd"
        let label = dateFormatter.string(from: referenceDate)
        return "Cross personal — \(chartName) — \(label)"
    }
}
