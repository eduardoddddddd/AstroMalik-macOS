import Foundation

// MARK: - Primary Direction Contextual Interpreter

/// Actor que orquesta la interpretación contextual de direcciones primarias.
/// Capa 2 del sistema de interpretación — autónoma, no depende del corpus Capa 1.
///
/// Pipeline por dirección:
///   1. Construye el user prompt con los factores moduladores de la carta natal
///   2. Llama a OpenRouterClient con el system prompt morinista
///   3. Decodifica el JSON estructurado en ContextualInterpretation
///   4. Persiste en primary_directions_interpretations (user.db) via SQLite
///
/// Concurrencia: actor aislado para serializar acceso al cache en memoria y DB.
actor PrimaryDirectionContextualInterpreter {

    // MARK: - Dependencies

    private let openRouterClient: OpenRouterClient
    private let db: SQLiteDB?               // user.db (read-write) para caché persistente
    private let systemPrompt: String
    private let decoder = JSONDecoder()
    private let promptVersion = "1.0.0"     // Sincronizar con VERSION en pd_contextual_prompt.md

    // Cache en memoria para evitar re-llamadas dentro de la misma sesión
    private var memoryCache: [String: ContextualInterpretation] = [:]

    // MARK: - Init

    init(openRouterClient: OpenRouterClient, db: SQLiteDB? = nil) {
        self.openRouterClient = openRouterClient
        self.db = db
        self.systemPrompt = Self.loadSystemPrompt()
    }

    // MARK: - Public API

    /// Interpreta una dirección primaria enriquecida con contexto natal.
    /// Si hay caché válida (misma promptVersion), la devuelve sin llamar al LLM.
    ///
    /// - Parameters:
    ///   - direction: La dirección primaria a interpretar.
    ///   - context: Contexto natal para construir los factores moduladores.
    /// - Returns: Interpretación contextual generada por el LLM.
    func interpret(
        direction: PrimaryDirection,
        context: PDInterpretationContext
    ) async throws -> ContextualInterpretation {
        let cacheKey = "\(direction.id)-\(promptVersion)"

        // 1. Cache en memoria
        if let cached = memoryCache[cacheKey] { return cached }

        // 2. Cache persistente en SQLite
        if let persisted = loadFromDB(directionId: direction.id, promptVersion: promptVersion) {
            memoryCache[cacheKey] = persisted
            return persisted
        }

        // 3. Llamada al LLM
        let userPrompt = buildUserPrompt(direction: direction, context: context)
        let rawJSON = try await openRouterClient.complete(
            systemPrompt: systemPrompt,
            userPrompt: userPrompt
        )

        let interpretation = try decodeInterpretation(rawJSON: rawJSON, direction: direction)

        // 4. Persistir y cachear
        saveToMemoryCache(interpretation, key: cacheKey)
        saveToDB(interpretation)

        return interpretation
    }

    /// Interpreta un batch de direcciones de forma concurrente.
    /// Devuelve solo las que se pudieron interpretar (errores individuales no abortan el batch).
    func interpretBatch(
        directions: [PrimaryDirection],
        context: PDInterpretationContext,
        maxConcurrent: Int = 3
    ) async -> [ContextualInterpretation] {
        var results: [ContextualInterpretation] = []

        // Procesar en lotes de maxConcurrent para no saturar la API
        let chunks = directions.chunked(into: maxConcurrent)
        for chunk in chunks {
            await withTaskGroup(of: ContextualInterpretation?.self) { group in
                for direction in chunk {
                    group.addTask {
                        try? await self.interpret(direction: direction, context: context)
                    }
                }
                for await result in group {
                    if let r = result { results.append(r) }
                }
            }
        }
        return results
    }

    /// Invalida la caché para una dirección específica.
    /// Usar cuando el usuario cambia el método de cálculo o la clave.
    func invalidateCache(for directionId: UUID) {
        memoryCache = memoryCache.filter { !$0.key.hasPrefix(directionId.uuidString) }
        deleteFromDB(directionId: directionId)
    }

    /// Invalida toda la caché (cuando el prompt version cambia).
    func invalidateAllCache() {
        memoryCache.removeAll()
        deleteAllFromDB()
    }

    func hasPersistentCache() -> Bool {
        db != nil
    }

    func cachedInterpretation(for directionId: UUID) -> ContextualInterpretation? {
        let cacheKey = "\(directionId.uuidString)-\(promptVersion)"
        if let cached = memoryCache[cacheKey] {
            return cached
        }
        guard let persisted = loadFromDB(directionId: directionId, promptVersion: promptVersion) else {
            return nil
        }
        memoryCache[cacheKey] = persisted
        return persisted
    }

    func cachedDirectionIDs(for directionIDs: [UUID]) -> Set<UUID> {
        var cached: Set<UUID> = []
        for directionId in directionIDs {
            if cachedInterpretation(for: directionId) != nil {
                cached.insert(directionId)
            }
        }
        return cached
    }

    // MARK: - User Prompt Builder

    /// Construye el user prompt con todos los factores moduladores disponibles.
    /// El LLM solo interpreta con los datos que recibe; no inventa los faltantes.
    nonisolated func buildUserPrompt(
        direction: PrimaryDirection,
        context: PDInterpretationContext
    ) -> String {
        var lines: [String] = []

        lines.append("## Dirección a interpretar")
        lines.append("- ID: \(direction.id.uuidString)")
        lines.append("- Clave: \(direction.promissor)_\(direction.significator)_\(direction.aspect.rawValue.uppercased())")
        lines.append("- Promissor: \(direction.promissorLabel)")
        lines.append("- Significador: \(direction.significatorLabel)")
        lines.append("- Aspecto: \(direction.aspect.label) (\(direction.aspectAngle)°)")
        lines.append("- Tipo: \(direction.directionType == .direct ? "Directa" : "Conversa")")
        lines.append("- Plano: \(direction.aspectPlane == .zodiacal ? "Zodiacal" : "Mundano")")
        lines.append("- Método: \(direction.method.rawValue)")
        lines.append("- Clave temporal: \(direction.key == .naibod ? "Naibod" : direction.key == .ptolemy ? "Ptolemy" : "Brahe")")
        lines.append("- Arco: \(String(format: "%.4f", direction.arc))°")
        lines.append("- Edad de activación: \(String(format: "%.2f", direction.estimatedAge)) años")

        lines.append("\n## Datos técnicos del espéculo")
        lines.append("- RA promissor: \(String(format: "%.4f", direction.technicalData.promissorRA))°")
        lines.append("- Declinación promissor: \(String(format: "%.4f", direction.technicalData.promissorDeclination))°")
        lines.append("- RA significador: \(String(format: "%.4f", direction.technicalData.significatorRA))°")
        lines.append("- Polo del significador: \(String(format: "%.4f", direction.technicalData.significatorPole))°")
        lines.append("- Oblicuidad: \(String(format: "%.4f", direction.technicalData.obliquity))°")
        lines.append("- RAMC: \(String(format: "%.4f", direction.technicalData.ramc))°")
        lines.append("- Latitud geográfica: \(String(format: "%.4f", direction.technicalData.geoLatitude))°")

        lines.append("\n## Factores moduladores de la carta natal")

        // Factor 1: Dignidad esencial del promissor
        if let dignity = context.promissorDignity {
            lines.append("- Dignidad esencial del promissor: \(dignity)")
        } else {
            lines.append("- Dignidad esencial del promissor: factor no disponible")
        }

        // Factor 2: Casa natal del promissor
        if let house = context.promissorNatalHouse {
            lines.append("- Casa natal del promissor: Casa \(house)")
        } else {
            lines.append("- Casa natal del promissor: factor no disponible")
        }

        // Factor 3: Aspecto natal entre promissor y significador
        if let natalAspect = context.natalAspectBetweenPromissorAndSignificator {
            lines.append("- Aspecto natal promissor-significador: \(natalAspect)")
        } else {
            lines.append("- Aspecto natal promissor-significador: ninguno")
        }

        // Factor 4: Sect
        lines.append("- Sect de la carta: \(context.isNocturnal ? "Nocturna (Sol bajo horizonte)" : "Diurna (Sol sobre horizonte)")")
        lines.append("- Sect del promissor: \(context.promissorInSect ? "En sect" : "Fuera de sect")")

        // Factor 5: Condición del significador natal
        if let sigCondition = context.significatorCondition {
            lines.append("- Condición del significador: \(sigCondition)")
        } else {
            lines.append("- Condición del significador: factor no disponible")
        }

        // Factor 6: Datos del nativo
        if let age = context.nativeCurrentAge {
            lines.append("- Edad actual del nativo: \(String(format: "%.1f", age)) años")
        }
        if let birthYear = context.birthYear {
            lines.append("- Año de nacimiento: \(birthYear)")
        }

        lines.append("\n## Instrucción")
        lines.append("Interpreta esta dirección aplicando los 6 factores moduladores morinistas.")
        lines.append("Responde SOLO con el JSON del schema, sin texto adicional.")
        lines.append("promptVersion debe ser exactamente: \"\(promptVersion)\"")

        return lines.joined(separator: "\n")
    }

    // MARK: - Decoding

    private func decodeInterpretation(
        rawJSON: String,
        direction: PrimaryDirection
    ) throws -> ContextualInterpretation {
        // El LLM podría devolver markdown wrapping; intentar extraer el JSON
        let cleanJSON = extractJSON(from: rawJSON)

        guard let data = cleanJSON.data(using: .utf8) else {
            throw OpenRouterError.decodingError("No se pudo convertir la respuesta a Data")
        }

        do {
            return try decoder.decode(ContextualInterpretation.self, from: data)
        } catch {
            throw OpenRouterError.decodingError(error.localizedDescription)
        }
    }

    /// Extrae JSON de una respuesta que podría venir envuelta en markdown.
    private func extractJSON(from text: String) -> String {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        // Si el LLM devuelve ```json ... ```, extraer el contenido
        if trimmed.hasPrefix("```") {
            let lines = trimmed.components(separatedBy: "\n")
            let content = lines.dropFirst().dropLast().joined(separator: "\n")
            return content.trimmingCharacters(in: .whitespacesAndNewlines)
        }
        return trimmed
    }

    // MARK: - Cache Memory

    private func saveToMemoryCache(_ interpretation: ContextualInterpretation, key: String) {
        memoryCache[key] = interpretation
    }

    // MARK: - SQLite Persistence

    private func loadFromDB(directionId: UUID, promptVersion: String) -> ContextualInterpretation? {
        guard let db else { return nil }
        let sql = """
            SELECT json_payload FROM primary_directions_interpretations
            WHERE direction_id = ? AND prompt_version = ?
            ORDER BY created_at DESC LIMIT 1
        """
        guard let row = try? db.queryOne(sql, args: [
            .text(directionId.uuidString),
            .text(promptVersion)
        ]),
        let jsonString = row["json_payload"]?.string,
        let data = jsonString.data(using: .utf8),
        let interp = try? decoder.decode(ContextualInterpretation.self, from: data)
        else { return nil }
        return interp
    }

    private func saveToDB(_ interpretation: ContextualInterpretation) {
        guard let db else { return }
        guard let data = try? JSONEncoder().encode(interpretation),
              let json = String(data: data, encoding: .utf8) else { return }
        let sql = """
            INSERT OR REPLACE INTO primary_directions_interpretations
            (direction_id, clave, prompt_version, json_payload, created_at)
            VALUES (?, ?, ?, ?, datetime('now'))
        """
        _ = try? db.run(sql, args: [
            .text(interpretation.directionId.uuidString),
            .text(interpretation.clave),
            .text(interpretation.promptVersion),
            .text(json)
        ])
    }

    private func deleteFromDB(directionId: UUID) {
        guard let db else { return }
        _ = try? db.run(
            "DELETE FROM primary_directions_interpretations WHERE direction_id = ?",
            args: [.text(directionId.uuidString)]
        )
    }

    private func deleteAllFromDB() {
        guard let db else { return }
        _ = try? db.execute("DELETE FROM primary_directions_interpretations")
    }

    // MARK: - System Prompt Loader

    private static func loadSystemPrompt() -> String {
        // Intentar cargar desde el bundle (fichero pd_contextual_prompt.md)
        if let url = Bundle.main.url(forResource: "pd_contextual_prompt", withExtension: "md"),
           let content = try? String(contentsOf: url, encoding: .utf8) {
            return content
        }
        // Fallback: prompt embebido mínimo para no romper en tests
        return """
        Eres un intérprete de direcciones primarias bajo doctrina morinista.
        Responde EXCLUSIVAMENTE con JSON estructurado. promptVersion: "1.0.0".
        """
    }
}

// MARK: - Interpretation Context

/// Contexto natal que el intérprete necesita para evaluar los 6 factores moduladores.
/// Se construye a partir de NatalChart antes de llamar al intérprete.
struct PDInterpretationContext: Sendable {
    /// Dignidad esencial del promissor: "domicilio", "exaltacion", "triplicidad",
    /// "termino", "faz", "peregrine", "detrimento", "caida"
    let promissorDignity: String?
    /// Casa natal del promissor (1-12).
    let promissorNatalHouse: Int?
    /// Descripción del aspecto natal entre promissor y significador (nil si no existe).
    let natalAspectBetweenPromissorAndSignificator: String?
    /// True si la carta es nocturna (Sol bajo horizonte).
    let isNocturnal: Bool
    /// True si el promissor está en su sect.
    let promissorInSect: Bool
    /// Descripción de la condición del significador natal.
    let significatorCondition: String?
    /// Edad actual del nativo (para contextualizar el período de activación).
    let nativeCurrentAge: Double?
    /// Año de nacimiento del nativo.
    let birthYear: Int?
}

// MARK: - Array Extension

private extension Array {
    func chunked(into size: Int) -> [[Element]] {
        guard size > 0 else { return [self] }
        return stride(from: 0, to: count, by: size).map {
            Array(self[$0..<Swift.min($0 + size, count)])
        }
    }
}
