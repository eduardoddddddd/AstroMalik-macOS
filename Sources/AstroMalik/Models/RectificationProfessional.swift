import Foundation

enum RectificationSchool: String, Codable, CaseIterable, Identifiable {
    case traditional
    case balanced
    case modern

    var id: String { rawValue }
    var label: String {
        switch self {
        case .traditional: return "Tradicional"
        case .balanced: return "Equilibrada"
        case .modern: return "Moderna"
        }
    }
}

struct AscendantQuestionnaire: Codable, Equatable {
    var answers: [String: String] = [:]

    var scores: [Int: Double] {
        var result = Dictionary(uniqueKeysWithValues: (0..<12).map { ($0, 0.0) })
        for question in AscendantQuestionnaireCatalog.questions {
            guard let optionID = answers[question.id],
                  let option = question.options.first(where: { $0.id == optionID }) else { continue }
            for sign in option.signIndexes { result[sign, default: 0] += 1 }
        }
        return result
    }

    var preliminarySignIndex: Int? {
        guard !answers.isEmpty else { return nil }
        return scores.max { lhs, rhs in lhs.value == rhs.value ? lhs.key > rhs.key : lhs.value < rhs.value }?.key
    }

    var preliminarySignLabel: String? { preliminarySignIndex.map { SIGN_LABELS[$0] } }
    var completion: Double { Double(answers.count) / Double(max(1, AscendantQuestionnaireCatalog.questions.count)) }
}

struct AscendantQuestion: Identifiable, Equatable {
    let id: String
    let prompt: String
    let options: [AscendantQuestionOption]
}

struct AscendantQuestionOption: Identifiable, Equatable {
    let id: String
    let label: String
    let signIndexes: [Int]
}

enum AscendantQuestionnaireCatalog {
    static let questions: [AscendantQuestion] = [
        .init(id: "presence", prompt: "¿Cómo suele percibirte la gente al conocerte?", options: [
            .init(id: "direct", label: "Directo/a y enérgico/a", signIndexes: [0, 4, 8]),
            .init(id: "calm", label: "Sereno/a y estable", signIndexes: [1, 5, 9]),
            .init(id: "curious", label: "Curioso/a y conversador/a", signIndexes: [2, 6, 10]),
            .init(id: "sensitive", label: "Sensible y receptivo/a", signIndexes: [3, 7, 11]),
        ]),
        .init(id: "reaction", prompt: "Ante un entorno nuevo, tu reacción espontánea es…", options: [
            .init(id: "lead", label: "Tomar la iniciativa", signIndexes: [0, 3, 6, 9]),
            .init(id: "observe", label: "Observar antes de actuar", signIndexes: [1, 4, 7, 10]),
            .init(id: "adapt", label: "Adaptarme y probar opciones", signIndexes: [2, 5, 8, 11]),
        ]),
        .init(id: "pace", prompt: "Tu ritmo corporal y cotidiano tiende a ser…", options: [
            .init(id: "fast", label: "Rápido e impulsivo", signIndexes: [0, 2, 8, 10]),
            .init(id: "steady", label: "Constante y medido", signIndexes: [1, 5, 9]),
            .init(id: "variable", label: "Variable según el ambiente", signIndexes: [3, 6, 7, 11]),
        ]),
        .init(id: "focus", prompt: "¿Qué buscas primero para sentir control?", options: [
            .init(id: "action", label: "Libertad de acción", signIndexes: [0, 4, 8]),
            .init(id: "security", label: "Seguridad material", signIndexes: [1, 5, 9]),
            .init(id: "ideas", label: "Información y alternativas", signIndexes: [2, 6, 10]),
            .init(id: "bond", label: "Vínculo y confianza", signIndexes: [3, 7, 11]),
        ]),
        .init(id: "conflict", prompt: "En conflicto tiendes a…", options: [
            .init(id: "confront", label: "Confrontar de inmediato", signIndexes: [0, 4, 7]),
            .init(id: "negotiate", label: "Negociar y razonar", signIndexes: [2, 6, 8, 10]),
            .init(id: "withdraw", label: "Retirarme y procesarlo", signIndexes: [3, 5, 9, 11]),
            .init(id: "resist", label: "Mantener mi posición", signIndexes: [1, 7, 9]),
        ]),
    ]
}

struct RectificationOverfittingDiagnostics: Codable, Equatable {
    var rawScore: Double
    var adjustedScore: Double
    var penalty: Double
    var dominantEventShare: Double
    var dominantTechniqueShare: Double
    var enabledTechniqueCount: Int
}

enum RectificationOverfittingAnalyzer {
    static func diagnostics(
        rawScore: Double,
        eventScores: [UUID: Double],
        techniqueScores: [RectificationTechnique: Double],
        enabledTechniqueCount: Int,
        config: RectificationConfig
    ) -> RectificationOverfittingDiagnostics {
        let eventTotal = eventScores.values.reduce(0, +)
        let techniqueTotal = techniqueScores.values.reduce(0, +)
        let eventShare = eventTotal > 0 ? (eventScores.values.max() ?? 0) / eventTotal : 0
        let techniqueShare = techniqueTotal > 0 ? (techniqueScores.values.max() ?? 0) / techniqueTotal : 0
        guard config.penalizeWeakContacts else {
            return .init(rawScore: rawScore, adjustedScore: rawScore, penalty: 0, dominantEventShare: eventShare, dominantTechniqueShare: techniqueShare, enabledTechniqueCount: enabledTechniqueCount)
        }
        let concentration = max(0, eventShare - 0.55) + max(0, techniqueShare - 0.60)
        let complexity = Double(max(0, enabledTechniqueCount - 6)) * 0.025
        let penaltyRate = min(0.25, (concentration * 0.45 + complexity) * config.resolvedOverfittingPenaltyStrength)
        let penalty = (rawScore * penaltyRate * 100).rounded() / 100
        return .init(rawScore: rawScore, adjustedScore: max(0, ((rawScore - penalty) * 100).rounded() / 100), penalty: penalty, dominantEventShare: eventShare, dominantTechniqueShare: techniqueShare, enabledTechniqueCount: enabledTechniqueCount)
    }
}

extension RectificationConfig {
    mutating func applySchoolPreset(_ school: RectificationSchool) {
        self.school = school
        switch school {
        case .balanced:
            techniqueWeights.merge(Self.default.techniqueWeights) { _, preset in preset }
        case .traditional:
            techniqueWeights.merge([
                .primaryDirections: 1.50, .profections: 1.00, .firdaria: 0.90,
                .zodiacalReleasing: 0.85, .lots: 0.85, .solarReturn: 0.85,
                .transitsToAngles: 0.55, .secondaryProgressions: 0.75,
            ]) { _, preset in preset }
        case .modern:
            techniqueWeights.merge([
                .solarArc: 1.30, .secondaryProgressions: 1.20, .transitsToAngles: 1.05,
                .ascendantSignQuestionnaire: 0.65, .primaryDirections: 1.00,
                .profections: 0.55, .firdaria: 0.45, .zodiacalReleasing: 0.45,
            ]) { _, preset in preset }
        }
    }
}
