import Foundation

enum RectificationValidationError: LocalizedError, Equatable {
    case unsupportedSessionSchema(Int)
    case unsupportedConfigSchema(Int)
    case missingName
    case invalidBirthData(String)
    case invalidCoordinates
    case invalidSearchRange(String)
    case invalidQuestionnaire(String)
    case insufficientEvents(required: Int, actual: Int)
    case invalidEvent(id: UUID, reason: String)
    case invalidConfig(String)

    var errorDescription: String? {
        switch self {
        case .unsupportedSessionSchema(let version):
            return "La versión de sesión de rectificación no es compatible: \(version)."
        case .unsupportedConfigSchema(let version):
            return "La versión de configuración de rectificación no es compatible: \(version)."
        case .missingName:
            return "La sesión de rectificación necesita un nombre."
        case .invalidBirthData(let reason):
            return "Los datos natales no son válidos: \(reason)"
        case .invalidCoordinates:
            return "Las coordenadas deben estar entre ±90° de latitud y ±180° de longitud."
        case .invalidSearchRange(let reason):
            return "El rango de búsqueda no es válido: \(reason)"
        case .invalidQuestionnaire(let reason):
            return "El cuestionario de Ascendente no es válido: \(reason)"
        case .insufficientEvents(let required, let actual):
            return "Se necesitan al menos \(required) eventos; se recibieron \(actual)."
        case .invalidEvent(_, let reason):
            return "Uno de los eventos no es válido: \(reason)"
        case .invalidConfig(let reason):
            return "La configuración de rectificación no es válida: \(reason)"
        }
    }
}

extension RectificationSession {
    func validate(config: RectificationConfig, now: Date = Date()) throws {
        guard schemaVersion == Self.currentSchemaVersion else {
            throw RectificationValidationError.unsupportedSessionSchema(schemaVersion)
        }
        try config.validate()

        guard !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw RectificationValidationError.missingName
        }
        guard (-90...90).contains(latitude), (-180...180).contains(longitude) else {
            throw RectificationValidationError.invalidCoordinates
        }
        let localBirthDate: Date
        do {
            localBirthDate = try localDateFromBirthData(
                birthDate: birthDate,
                birthTime: reportedBirthTime,
                timezoneName: timezone
            )
        } catch {
            throw RectificationValidationError.invalidBirthData(error.localizedDescription)
        }
        try searchRange.validate()
        try ascendantQuestionnaire?.validate()

        let qualifyingEvents = events.filter { $0.precision.qualifiesForMinimumDataset }
        guard qualifyingEvents.count >= config.minimumEventsForAnalysis else {
            throw RectificationValidationError.insufficientEvents(
                required: config.minimumEventsForAnalysis,
                actual: qualifyingEvents.count
            )
        }
        for event in events {
            try event.validate(birthDate: localBirthDate, now: now)
        }
    }
}

extension RectificationSearchRange {
    func validate() throws {
        do {
            _ = try parseLocalTime(centerTime)
        } catch {
            throw RectificationValidationError.invalidSearchRange("la hora central no es válida")
        }
        guard (0...1_440).contains(minutesBefore), (0...1_440).contains(minutesAfter) else {
            throw RectificationValidationError.invalidSearchRange("los márgenes deben estar entre 0 y 1440 minutos")
        }
        guard includeFullDayFallback || minutesBefore + minutesAfter > 0 else {
            throw RectificationValidationError.invalidSearchRange("el rango no puede estar vacío")
        }
        guard coarseStepSeconds > 0, fineStepSeconds > 0 else {
            throw RectificationValidationError.invalidSearchRange("los pasos deben ser mayores que cero")
        }
        guard fineStepSeconds <= coarseStepSeconds else {
            throw RectificationValidationError.invalidSearchRange("el paso fino no puede superar al paso grueso")
        }
        guard coarseCandidateEstimate <= 10_000 else {
            throw RectificationValidationError.invalidSearchRange("la primera pasada excedería 10.000 candidatas")
        }
    }
}

extension RectificationEvent {
    func validate() throws {
        guard !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw RectificationValidationError.invalidEvent(id: id, reason: "falta el título")
        }
        guard (1...5).contains(importance) else {
            throw RectificationValidationError.invalidEvent(id: id, reason: "la importancia debe estar entre 1 y 5")
        }
        if precision == .dateRange, dateEnd == nil {
            throw RectificationValidationError.invalidEvent(id: id, reason: "un rango necesita fecha final")
        }
        if let dateEnd, dateEnd < dateStart {
            throw RectificationValidationError.invalidEvent(id: id, reason: "la fecha final es anterior a la inicial")
        }
    }

    func validate(birthDate: Date, now: Date) throws {
        try validate()
        guard dateStart > birthDate else {
            throw RectificationValidationError.invalidEvent(id: id, reason: "el evento debe ser posterior al nacimiento")
        }
        guard dateStart <= now, dateEnd.map({ $0 <= now }) ?? true else {
            throw RectificationValidationError.invalidEvent(id: id, reason: "los eventos futuros no sirven como evidencia de rectificación")
        }
    }
}

extension RectificationConfig {
    func validate() throws {
        guard schemaVersion == Self.currentSchemaVersion else {
            throw RectificationValidationError.unsupportedConfigSchema(schemaVersion)
        }
        guard !enabledTechniques.isEmpty else {
            throw RectificationValidationError.invalidConfig("activa al menos una técnica")
        }
        guard orbMultiplier > 0, orbMultiplier <= 3 else {
            throw RectificationValidationError.invalidConfig("el multiplicador de orbe debe estar entre 0 y 3")
        }
        guard (1...50).contains(minimumEventsForAnalysis) else {
            throw RectificationValidationError.invalidConfig("el mínimo de eventos debe estar entre 1 y 50")
        }
        guard (1...180).contains(clusterWindowMinutes) else {
            throw RectificationValidationError.invalidConfig("la ventana de cluster debe estar entre 1 y 180 minutos")
        }
        guard overfittingPenaltyStrength.map({ (0...1).contains($0) }) ?? true else {
            throw RectificationValidationError.invalidConfig("la penalización anti-overfitting debe estar entre 0 y 1")
        }
        for technique in enabledTechniques {
            guard let weight = techniqueWeights[technique], weight > 0 else {
                throw RectificationValidationError.invalidConfig("falta un peso positivo para \(technique.rawValue)")
            }
        }
    }
}

extension AscendantQuestionnaire {
    func validate() throws {
        for (questionID, optionID) in answers {
            guard let question = AscendantQuestionnaireCatalog.questions.first(where: { $0.id == questionID }) else {
                throw RectificationValidationError.invalidQuestionnaire("pregunta desconocida: \(questionID)")
            }
            guard question.options.contains(where: { $0.id == optionID }) else {
                throw RectificationValidationError.invalidQuestionnaire("respuesta desconocida para \(questionID)")
            }
        }
    }
}
