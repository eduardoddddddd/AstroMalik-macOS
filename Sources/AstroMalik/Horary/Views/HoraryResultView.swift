import SwiftUI

private struct HoraryTextSection: Identifiable {
    let title: String
    let body: String

    var id: String { title }
}

struct HoraryResultView: View {
    let query: SavedHoraryQuery
    var onBack: (() -> Void)? = nil

    private let sectionOrder = [
        "CABECERA",
        "SIGNIFICADORES",
        "RADICALIDAD",
        "DIGNIDADES DE SIGNIFICADORES",
        "SITUACION POR CASA",
        "PERFECCION",
        "JUICIO FINAL",
    ]

    var body: some View {
        NavigationStack {
            HSplitView {
                leftPanel
                    .frame(minWidth: 360, idealWidth: 420, maxWidth: 520)
                rightPanel
                    .frame(minWidth: 500, idealWidth: 720)
            }
            .background(Color.appBackground)
            .navigationTitle("Horaria — \(query.request.question)")
            .toolbar {
                if let onBack {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Volver") { onBack() }
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var leftPanel: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                headerCard
                Divider()
                significatorsCard
                Divider()
                dignitiesCard
                Divider()
                considerationsCard
                Divider()
                bodiesCard
            }
            .padding(20)
        }
    }

    private var headerCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(query.request.question)
                .font(.title3.weight(.medium))
                .foregroundColor(.appPrimaryText)
            Label(query.request.placeName, systemImage: "mappin")
                .font(.caption)
                .foregroundColor(.secondary)
            Label(query.request.datetimeLocal.replacingOccurrences(of: "T", with: " "), systemImage: "calendar")
                .font(.caption)
                .foregroundColor(.secondary)
            Label(query.request.timezone, systemImage: "globe")
                .font(.caption)
                .foregroundColor(.secondary)
            Divider()
            metaRow("Casa del asunto", "Casa \(query.request.questionHouse) · \(query.chart.header.questionTopic)")
            metaRow("Ascendente", query.chart.angles.asc.formatted)
            metaRow("Medio Cielo", query.chart.angles.mc.formatted)
            metaRow("Hora planetaria", query.chart.planetaryHourRuler)
            metaRow("Secta", query.chart.sect)
            metaRow("Perfección", query.judgement.perfectionKind)
            if let timeEstimate = query.judgement.timeEstimate {
                metaRow("Tiempo estimado", timeEstimate)
            }
        }
    }

    private var significatorsCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            sectionTitle("Significadores")
            bodySummary(name: query.judgement.significators.querent, role: "Consultante")
            bodySummary(name: query.judgement.significators.quesited, role: "Quesited")
            bodySummary(name: query.judgement.significators.moon, role: "Luna")

            if !query.judgement.significators.querentCosignifiers.isEmpty {
                Divider().padding(.vertical, 4)
                Text("Co-significadores del consultante")
                    .font(.caption.weight(.semibold))
                    .foregroundColor(.secondary)
                ForEach(query.judgement.significators.querentCosignifiers, id: \.self) { name in
                    bodySummary(name: name, role: nil)
                }
            }

            if !query.judgement.significators.quesitedCosignifiers.isEmpty {
                Divider().padding(.vertical, 4)
                Text("Co-significadores del quesited")
                    .font(.caption.weight(.semibold))
                    .foregroundColor(.secondary)
                ForEach(query.judgement.significators.quesitedCosignifiers, id: \.self) { name in
                    bodySummary(name: name, role: nil)
                }
            }

            Divider().padding(.vertical, 4)
            metaRow("Ruta", query.judgement.perfectionRoute.kind)
            metaRow("Sig. consultante", query.judgement.perfectionRoute.significatorQuerent)
            metaRow("Sig. quesited", query.judgement.perfectionRoute.significatorQuesited)
            if let intermediary = query.judgement.perfectionRoute.intermediary {
                metaRow("Intermediario", intermediary)
            }
            if let aspectName = query.judgement.perfectionRoute.aspectName {
                metaRow("Aspecto", aspectName)
            }
            metaRow("Usa co-significador", query.judgement.perfectionRoute.usesCosignifier ? "Sí" : "No")
        }
    }

    private var dignitiesCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            sectionTitle("Dignidades")
            ForEach(relevantDignities) { dignity in
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text(dignity.name)
                            .font(.subheadline.weight(.medium))
                        Spacer()
                        Text("Total \(dignity.totalScore)")
                            .font(.caption.monospacedDigit())
                            .foregroundColor(.secondary)
                    }
                    Text("Esencial \(dignity.essentialScore) · Accidental \(dignity.accidentalScore)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    if !dignity.essentialTags.isEmpty {
                        Text(dignity.essentialTags.joined(separator: ", "))
                            .font(.caption2)
                            .foregroundColor(.appSecondaryAccent)
                    }
                    if !dignity.accidentalTags.isEmpty {
                        Text(dignity.accidentalTags.joined(separator: ", "))
                            .font(.caption2)
                            .foregroundColor(.appSecondaryAccent)
                    }
                }
                Divider().opacity(0.35)
            }
        }
    }

    private var considerationsCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            sectionTitle("Consideraciones")
            if query.chart.activeConsiderations.isEmpty {
                Text("No hay consideraciones activas.")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            } else {
                ForEach(query.chart.activeConsiderations) { item in
                    VStack(alignment: .leading, spacing: 3) {
                        HStack {
                            Text(item.key)
                                .font(.caption.weight(.semibold))
                                .foregroundColor(.appPrimaryText)
                            Spacer()
                            Text(item.severity)
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }
                        Text(item.description)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    Divider().opacity(0.35)
                }
            }
        }
    }

    private var bodiesCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionTitle("Cuerpos")
            VStack(spacing: 0) {
                HStack(spacing: 0) {
                    tableHeader("Cuerpo", width: 110)
                    tableHeader("Signo", width: 150)
                    tableHeader("Casa", width: 50)
                    tableHeader("Vel.", width: 70)
                }
                .padding(.bottom, 4)
                Divider()
                ForEach(query.chart.bodies) { body in
                    bodyRow(body)
                    Divider().opacity(0.35)
                }
            }

            if !query.chart.parts.isEmpty {
                Divider().padding(.vertical, 4)
                Text("Partes")
                    .font(.headline)
                    .foregroundColor(.appPrimaryText)
                ForEach(query.chart.parts) { part in
                    bodyRow(part)
                    Divider().opacity(0.35)
                }
            }
        }
    }

    private var rightPanel: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                ForEach(parsedSections) { section in
                    VStack(alignment: .leading, spacing: 8) {
                        Text(section.title)
                            .font(.headline)
                            .foregroundColor(.appPrimaryText)
                        Text(section.body)
                            .font(.body)
                            .lineSpacing(5)
                            .textSelection(.enabled)
                    }
                    .padding(20)
                    .background(Color.appPanel)
                    .cornerRadius(14)
                }
            }
            .padding(20)
        }
    }

    private func metaRow(_ title: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(.caption2)
                .foregroundColor(.secondary)
            Text(value)
                .font(.subheadline)
        }
    }

    private func sectionTitle(_ title: String) -> some View {
        Text(title)
            .font(.headline)
            .foregroundColor(.appPrimaryText)
    }

    private func tableHeader(_ text: String, width: CGFloat) -> some View {
        Text(text)
            .font(.caption.weight(.semibold))
            .foregroundColor(.secondary)
            .frame(width: width, alignment: .leading)
    }

    private func bodyRow(_ body: HoraryBody) -> some View {
        HStack(spacing: 0) {
            Text(body.name + (body.retrograde ? " ℞" : ""))
                .frame(width: 110, alignment: .leading)
                .font(.subheadline)
            Text(body.formatted)
                .frame(width: 150, alignment: .leading)
                .font(.subheadline.monospacedDigit())
            Text("C\(body.house)")
                .frame(width: 50, alignment: .leading)
                .font(.caption)
                .foregroundColor(.secondary)
            Text(String(format: "%.2f", body.speed))
                .frame(width: 70, alignment: .leading)
                .font(.caption.monospacedDigit())
                .foregroundColor(.secondary)
        }
        .padding(.vertical, 5)
    }

    private func bodySummary(name: String, role: String?) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack {
                Text(role.map { "\($0): \(name)" } ?? name)
                    .font(.subheadline.weight(.medium))
                Spacer()
                if let body = query.chart.body(named: name) {
                    Text("Casa \(body.house)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            if let body = query.chart.body(named: name) {
                Text("\(body.formatted) · vel. \(String(format: "%.2f", body.speed))")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
    }

    private var relevantDignities: [HoraryDignity] {
        let names = Set(
            [
                query.judgement.significators.querent,
                query.judgement.significators.quesited,
                query.judgement.significators.moon,
                query.judgement.perfectionRoute.significatorQuerent,
                query.judgement.perfectionRoute.significatorQuesited,
                query.judgement.perfectionRoute.intermediary,
            ].compactMap { $0 } +
            query.judgement.significators.querentCosignifiers +
            query.judgement.significators.quesitedCosignifiers
        )
        return query.chart.dignities.filter { names.contains($0.name) }
    }

    private var parsedSections: [HoraryTextSection] {
        let lines = query.response.judgementText.components(separatedBy: .newlines)
        var sections: [HoraryTextSection] = []
        var currentTitle: String?
        var currentBody: [String] = []

        func flush() {
            guard let title = currentTitle else { return }
            let body = currentBody.joined(separator: "\n").trimmingCharacters(in: .whitespacesAndNewlines)
            sections.append(HoraryTextSection(title: title, body: body))
        }

        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if sectionOrder.contains(trimmed) {
                flush()
                currentTitle = trimmed
                currentBody = []
            } else {
                currentBody.append(line)
            }
        }
        flush()

        if sections.count == sectionOrder.count {
            return sections
        }

        return [
            HoraryTextSection(
                title: "INTERPRETACIÓN",
                body: query.response.judgementText.trimmingCharacters(in: .whitespacesAndNewlines)
            )
        ]
    }
}
