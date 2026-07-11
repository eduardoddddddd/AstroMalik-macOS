import SwiftUI

struct RectificationAuditSummaryView: View {
    let result: RectificationAnalysisResult
    let events: [RectificationEvent]

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            if !result.resolvedHouseSystemEvaluations.isEmpty {
                houseSystemComparison
            }
            eventCoverage
        }
    }

    private var houseSystemComparison: some View {
        DisclosureGroup("Comparación de sistemas de casas") {
            VStack(alignment: .leading, spacing: 6) {
                ForEach(result.resolvedHouseSystemEvaluations) { evaluation in
                    HStack {
                        Text(evaluation.houseSystem.label)
                            .frame(minWidth: 150, alignment: .leading)
                        Text(evaluation.topBirthTime)
                            .monospacedDigit()
                            .frame(width: 90, alignment: .leading)
                        ProgressView(value: evaluation.topScore, total: 100)
                        Text(String(format: "%.1f", evaluation.topScore))
                            .monospacedDigit()
                            .frame(width: 45)
                        Text(confidenceLabel(evaluation.confidence))
                            .foregroundStyle(.secondary)
                            .frame(width: 85, alignment: .leading)
                    }
                }
            }
            .padding(.vertical, 6)
        }
    }

    private var eventCoverage: some View {
        DisclosureGroup("Cobertura por evento") {
            VStack(alignment: .leading, spacing: 8) {
                ForEach(events) { event in
                    let techniques = techniquesCovering(event.id)
                    VStack(alignment: .leading, spacing: 3) {
                        HStack {
                            Image(systemName: techniques.isEmpty ? "exclamationmark.circle" : "checkmark.circle")
                                .foregroundStyle(techniques.isEmpty ? Color.appWarning : Color.appSecondaryAccent)
                            Text(event.title).font(.subheadline.weight(.medium))
                            Spacer()
                            Text("\(result.eventCoverage[event.id, default: 0]) técnicas")
                                .font(.caption.monospacedDigit())
                        }
                        Text(techniques.isEmpty ? "Sin evidencia técnica" : techniques.map(\.label).joined(separator: " · "))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.vertical, 2)
                }
            }
            .padding(.vertical, 6)
        }
    }

    private func techniquesCovering(_ eventID: UUID) -> [RectificationTechnique] {
        Array(Set(result.topCandidate?.evidence.filter { $0.eventID == eventID }.map(\.technique) ?? []))
            .sorted { $0.label < $1.label }
    }

    private func confidenceLabel(_ confidence: RectificationConfidenceBand) -> String {
        switch confidence {
        case .high: return "Alta"
        case .medium: return "Media"
        case .low: return "Baja"
        case .inconclusive: return "Inconclusa"
        }
    }
}
