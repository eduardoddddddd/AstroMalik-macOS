import SwiftUI

struct NatalExtendedAnalysisView: View {
    @EnvironmentObject var appState: AppState

    let chart: NatalChart

    @State private var result: NatalExtendedAnalysisResult?
    @State private var errorMessage: String?
    @State private var isLoading = false
    @State private var isExporting = false
    @State private var statusMessage: String?
    @State private var expanded: Set<String> = Set(NatalExtendedSection.allCases.map(\.rawValue))

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()
            content
        }
        .background(Color.appBackground)
        .task(id: chart.id) { compute() }
    }

    private var header: some View {
        HStack(alignment: .center, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Análisis extendido")
                    .font(.title3.weight(.semibold))
                    .foregroundColor(.appPrimaryText)
                Text("Cálculo natal determinista: lotes, almutén, patrones, distribución, recepciones, antiscia, declinaciones y estrellas fijas.")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            Spacer()
            Button {
                exportToJoplin()
            } label: {
                Label(isExporting ? "Exportando…" : "Exportar a Joplin", systemImage: "square.and.arrow.up")
            }
            .disabled(result == nil || isExporting)
            .buttonStyle(.borderedProminent)

            PDFExportButton(
                chartName: chart.name.isEmpty ? "Carta natal" : chart.name,
                reportType: "Análisis natal extendido",
                disabled: result == nil || isLoading,
                generate: { pageSize in
                    if let result {
                        return try await ExtendedNatalReportBuilder.generate(
                            from: ExtendedNatalReportInput(chart: chart, result: result),
                            pageSize: pageSize
                        )
                    }
                    return try await ExtendedNatalReportBuilder.generate(from: chart, pageSize: pageSize)
                }
            )
            .environmentObject(appState)
        }
        .padding(18)
    }

    @ViewBuilder
    private var content: some View {
        if isLoading {
            ProgressView("Calculando análisis extendido…")
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else if let errorMessage {
            VStack(spacing: 12) {
                Image(systemName: "exclamationmark.triangle")
                    .font(.system(size: 42))
                    .foregroundColor(.appWarning)
                Text(errorMessage)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else if let result {
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    if let statusMessage {
                        Text(statusMessage)
                            .font(.callout)
                            .foregroundColor(statusMessage.contains("Error") ? .appWarning : .appSecondaryAccent)
                            .padding(.horizontal, 4)
                    }
                    lotsSection(result.lots)
                    almutenSection(result.almutenFiguris)
                    rulerSection(result.rulerOfGeniture)
                    aspectPatternsSection(result.aspectPatterns)
                    distributionSection(result.distribution)
                    receptionsSection(result.receptions)
                    antisciaSection(result.antiscia)
                    declinationsSection(result.declinations)
                    fixedStarsSection(result.fixedStars)
                }
                .padding(18)
            }
        } else {
            Text("Sin datos de análisis extendido.")
                .foregroundColor(.secondary)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    private func section<Content: View>(_ section: NatalExtendedSection, @ViewBuilder content: @escaping () -> Content) -> some View {
        DisclosureGroup(isExpanded: binding(for: section)) {
            VStack(alignment: .leading, spacing: 10) { content() }
                .padding(.top, 8)
        } label: {
            Label(section.title, systemImage: section.systemImage)
                .appSectionHeader()
        }
        .appCard()
    }

    private func lotsSection(_ lots: [NatalLot]) -> some View {
        section(.lots) {
            ForEach(lots) { lot in
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text(lot.name).font(.subheadline.weight(.semibold))
                        Spacer()
                        Text("\(lot.formatted) · Casa \(lot.house)")
                            .font(.caption.monospacedDigit())
                            .foregroundColor(.secondary)
                    }
                    Text("Signo: \(lot.signLabel) · Regente/dispositor: \(lot.rulerLabel)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text(lot.formulaComment)
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
                .padding(10)
                .background(Color.appSurface)
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            }
        }
    }

    private func almutenSection(_ almuten: AlmutenFigurisResult) -> some View {
        section(.almuten) {
            metricRow("Almuten Figuris", "\(almuten.winnerLabel) · \(almuten.totalScores.first?.total ?? 0) puntos")
            metricRow("Sicigia prenatal", "\(almuten.prenatalSyzygy.kind.label) · \(almuten.prenatalSyzygy.formatted)")
            Text("Puntuación total")
                .font(.caption.weight(.semibold))
                .foregroundColor(.secondary)
            ForEach(almuten.totalScores) { score in
                metricRow(score.planetLabel, "\(score.total) = \(score.essentialPoints) esenciales + \(score.bonusPoints) bonos")
            }
            if !almuten.bonuses.isEmpty {
                Text("Bonos +12")
                    .font(.caption.weight(.semibold))
                    .foregroundColor(.secondary)
                ForEach(almuten.bonuses) { bonus in
                    metricRow(bonus.planetLabel, "\(bonus.kind): \(bonus.detail)")
                }
            }
        }
    }

    private func rulerSection(_ ruler: RulerOfGeniture) -> some View {
        section(.ruler) {
            metricRow("Secta", ruler.sectLabel)
            metricRow("Luminaria", "\(ruler.luminaryLabel) · \(ruler.luminaryFormatted)")
            metricRow("Regente de la genitura", ruler.rulerLabel)
            metricRow("Dignidades sobre la luminaria", ruler.dignitySummary)
        }
    }

    private func aspectPatternsSection(_ patterns: [AspectPattern]) -> some View {
        section(.patterns) {
            if patterns.isEmpty {
                emptyText("No se detectan configuraciones con el orbe configurado.")
            } else {
                ForEach(patterns) { pattern in
                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Text(pattern.title).font(.subheadline.weight(.semibold))
                            Spacer()
                            Text("Orbe medio \(String(format: "%.2f°", pattern.averageOrb))")
                                .font(.caption.monospacedDigit())
                                .foregroundColor(.secondary)
                        }
                        Text(pattern.planetLabels.joined(separator: ", "))
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .padding(10)
                    .background(Color.appSurface)
                    .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                }
            }
        }
    }

    private func distributionSection(_ distribution: NatalDistribution) -> some View {
        section(.distribution) {
            bucketGroup("Elementos", distribution.elements)
            bucketGroup("Modalidades", distribution.modalities)
            bucketGroup("Hemisferios", distribution.hemispheres)
            bucketGroup("Cuadrantes", distribution.quadrants)
            if !distribution.singletons.isEmpty {
                Text("Singletons")
                    .font(.caption.weight(.semibold))
                    .foregroundColor(.secondary)
                ForEach(distribution.singletons) { singleton in
                    metricRow(singleton.planetLabel, "Único en \(singleton.category.label.lowercased()) \(singleton.bucketName)")
                }
            }
        }
    }

    private func receptionsSection(_ receptions: [MutualReception]) -> some View {
        section(.receptions) {
            if receptions.isEmpty { emptyText("No se detectan recepciones mutuas tradicionales.") }
            ForEach(receptions) { reception in
                metricRow(reception.kind.label, reception.detail)
            }
        }
    }

    private func antisciaSection(_ antiscia: AntisciaResult) -> some View {
        section(.antiscia) {
            if antiscia.contacts.isEmpty { emptyText("No hay contactos de antiscia/contraantiscia dentro de 1°.") }
            ForEach(antiscia.contacts) { contact in
                metricRow(contact.kind.label, "\(contact.sourcePlanetLabel) → \(contact.targetPlanetLabel), \(contact.calculatedFormatted), orbe \(String(format: "%.2f°", contact.orb))")
            }
        }
    }

    private func declinationsSection(_ declinations: DeclinationResult) -> some View {
        section(.declinations) {
            if !declinations.outOfBounds.isEmpty {
                Text("Out of bounds")
                    .font(.caption.weight(.semibold))
                    .foregroundColor(.secondary)
                ForEach(declinations.outOfBounds) { body in
                    metricRow(body.label, body.formatted)
                }
            }
            Text("Paralelos y contraparalelos")
                .font(.caption.weight(.semibold))
                .foregroundColor(.secondary)
            if declinations.pairs.isEmpty { emptyText("No hay pares dentro de 1°.") }
            ForEach(declinations.pairs) { pair in
                metricRow(pair.kind.label, "\(pair.bodyALabel) / \(pair.bodyBLabel), orbe \(String(format: "%.2f°", pair.orb))")
            }
        }
    }

    private func fixedStarsSection(_ fixedStars: FixedStarResult) -> some View {
        section(.fixedStars) {
            metricRow("Precesión aplicada", String(format: "%.3f°", fixedStars.precessionAppliedDegrees))
            if fixedStars.contacts.isEmpty { emptyText("No hay conjunciones a estrellas fijas dentro de 1°.") }
            ForEach(fixedStars.contacts) { contact in
                metricRow(contact.starName, "con \(contact.targetLabel), \(contact.starFormatted), orbe \(String(format: "%.2f°", contact.orb)) · nat. \(contact.nature)")
            }
        }
    }

    private func bucketGroup(_ title: String, _ buckets: [DistributionBucket]) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.caption.weight(.semibold))
                .foregroundColor(.secondary)
            ForEach(buckets) { bucket in
                metricRow(bucket.name, "\(bucket.count): \(bucket.planetLabels.joined(separator: ", "))")
            }
        }
    }

    private func metricRow(_ title: String, _ value: String) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Text(title)
                .frame(width: 170, alignment: .leading)
                .font(.subheadline.weight(.medium))
                .foregroundColor(.appPrimaryText)
            Text(value.isEmpty ? "—" : value)
                .font(.subheadline)
                .foregroundColor(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.vertical, 3)
    }

    private func emptyText(_ text: String) -> some View {
        Text(text)
            .font(.callout)
            .foregroundColor(.secondary)
            .padding(.vertical, 4)
    }

    private func binding(for section: NatalExtendedSection) -> Binding<Bool> {
        Binding(
            get: { expanded.contains(section.rawValue) },
            set: { isExpanded in
                if isExpanded { expanded.insert(section.rawValue) }
                else { expanded.remove(section.rawValue) }
            }
        )
    }

    private func compute() {
        isLoading = true
        errorMessage = nil
        statusMessage = nil
        do {
            result = try NatalExtendedAnalysis.compute(chart: chart)
        } catch {
            result = nil
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }

    private func exportToJoplin() {
        guard let result else { return }
        isExporting = true
        statusMessage = nil
        let title = ExtendedAnalysisNoteBuilder.noteTitle(chart: chart)
        let body = ExtendedAnalysisNoteBuilder.markdown(chart: chart, result: result)
        let settings = appState.joplinSettings
        Task {
            do {
                let service = JoplinClipperService(settings: settings)
                try await service.createNote(title: title, body: body)
                await MainActor.run { statusMessage = "Nota creada en Joplin."; isExporting = false }
            } catch {
                await MainActor.run { statusMessage = "Error al exportar a Joplin: \(error.localizedDescription)"; isExporting = false }
            }
        }
    }
}

private enum NatalExtendedSection: String, CaseIterable {
    case lots, almuten, ruler, patterns, distribution, receptions, antiscia, declinations, fixedStars

    var title: String {
        switch self {
        case .lots: return "1. Lotes helenísticos"
        case .almuten: return "2. Almuten Figuris"
        case .ruler: return "3. Regente de la Genitura"
        case .patterns: return "4. Configuraciones aspectuales"
        case .distribution: return "5. Conteos y distribución"
        case .receptions: return "6. Recepciones mutuas natales"
        case .antiscia: return "7. Antiscia y contraantiscia"
        case .declinations: return "8. Declinaciones y out of bounds"
        case .fixedStars: return "9. Estrellas fijas"
        }
    }

    var systemImage: String {
        switch self {
        case .lots: return "circle.grid.cross"
        case .almuten: return "crown"
        case .ruler: return "key"
        case .patterns: return "line.diagonal"
        case .distribution: return "chart.pie"
        case .receptions: return "arrow.left.arrow.right"
        case .antiscia: return "mirror.side.left"
        case .declinations: return "arrow.up.and.down"
        case .fixedStars: return "sparkles"
        }
    }
}

// ExtendedAnalysisNoteBuilder lives in a platform-neutral core file.

