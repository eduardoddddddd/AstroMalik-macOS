import SwiftUI

struct PrimaryDirectionsTableView: View {
    let directions: [EnrichedPrimaryDirection]
    @Binding var selection: EnrichedPrimaryDirection?

    @State private var sortOrder = [KeyPathComparator(\EnrichedPrimaryDirection.tableAge)]

    private var selectedID: Binding<UUID?> {
        Binding(
            get: { selection?.id },
            set: { newValue in
                guard let newValue else {
                    selection = nil
                    return
                }
                selection = directions.first { $0.id == newValue }
            }
        )
    }

    private var sortedDirections: [EnrichedPrimaryDirection] {
        directions.sorted(using: sortOrder)
    }

    var body: some View {
        Table(sortedDirections, selection: selectedID, sortOrder: $sortOrder) {
            TableColumn("Edad", value: \.tableAge) { enriched in
                numericCell(enriched.ageCompact)
            }
            .width(min: 60, ideal: 70)

            TableColumn("Fecha", value: \.tableDate) { enriched in
                Text(enriched.direction.estimatedDate, format: .dateTime.year().month(.abbreviated))
                    .font(.caption)
            }
            .width(min: 92, ideal: 112)

            TableColumn("Prómissor", value: \.tablePromissor) { enriched in
                Text(enriched.direction.promissorLabel)
                    .font(.caption)
                    .lineLimit(1)
            }
            .width(min: 110, ideal: 140)

            TableColumn("Aspecto", value: \.tableAspect) { enriched in
                Text(enriched.direction.aspect.label)
                    .font(.caption)
                    .lineLimit(1)
            }
            .width(min: 104, ideal: 130)

            TableColumn("Significador", value: \.tableSignificator) { enriched in
                Text(enriched.direction.significatorLabel)
                    .font(.caption)
                    .lineLimit(1)
            }
            .width(min: 110, ideal: 140)

            TableColumn("Arco", value: \.tableArc) { enriched in
                numericCell(enriched.arcFormatted)
            }
            .width(min: 70, ideal: 84)

            TableColumn("Tipo", value: \.tableDirectionType) { enriched in
                Text(enriched.direction.directionType == .direct ? "Directa" : "Conversa")
                    .font(.caption)
            }
            .width(min: 76, ideal: 88)

            TableColumn("Plano", value: \.tablePlane) { enriched in
                Text(enriched.direction.aspectPlane.displayName)
                    .font(.caption)
            }
            .width(min: 86, ideal: 108)

            TableColumn("Texto", value: \.tableTextState) { enriched in
                Label(
                    enriched.hasInterpretation ? "Corpus" : "Auxiliar",
                    systemImage: enriched.hasInterpretation ? "checkmark.seal.fill" : "text.bubble"
                )
                .font(.caption)
                .foregroundStyle(enriched.hasInterpretation ? Color.appSecondaryAccent : .secondary)
            }
            .width(min: 92, ideal: 110)
        }
        .onChange(of: sortOrder) { _, newOrder in
            guard !newOrder.isEmpty else {
                sortOrder = [KeyPathComparator(\EnrichedPrimaryDirection.tableAge)]
                return
            }
        }
        .accessibilityLabel("Lista profesional de direcciones primarias")
    }

    private func numericCell(_ text: String) -> some View {
        Text(text)
            .font(.caption.monospaced())
            .foregroundStyle(.primary)
    }
}

private extension EnrichedPrimaryDirection {
    var tableAge: Double { direction.estimatedAge }
    var tableDate: Date { direction.estimatedDate }
    var tablePromissor: String { direction.promissorLabel }
    var tableAspect: String { direction.aspect.label }
    var tableSignificator: String { direction.significatorLabel }
    var tableArc: Double { abs(direction.arc) }
    var tableDirectionType: String { direction.directionType.rawValue }
    var tablePlane: String { direction.aspectPlane.displayName }
    var tableTextState: String { hasInterpretation ? "Corpus" : "Auxiliar" }

    var ageCompact: String {
        let years = Int(direction.estimatedAge)
        let months = Int((direction.estimatedAge - Double(years)) * 12)
        return "\(years)a \(months)m"
    }
}
