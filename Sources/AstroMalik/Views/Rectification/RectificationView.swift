import SwiftUI
import AppKit

private enum RectificationWorkflowStep: Int, CaseIterable, Identifiable {
    case data, questionnaire, events, configuration, result

    var id: Int { rawValue }
    var label: String {
        switch self {
        case .data: return "Datos"
        case .questionnaire: return "Cuestionario"
        case .events: return "Eventos"
        case .configuration: return "Configuración"
        case .result: return "Resultado"
        }
    }
    var icon: String {
        switch self {
        case .data: return "person.text.rectangle"
        case .questionnaire: return "list.clipboard"
        case .events: return "calendar.badge.clock"
        case .configuration: return "slider.horizontal.3"
        case .result: return "chart.bar.xaxis"
        }
    }
}

struct RectificationView: View {
    @EnvironmentObject private var appState: AppState
    @StateObject private var viewModel = RectificationViewModel()
    @State private var selectedChartID: UUID?
    @State private var comparisonAID: UUID?
    @State private var comparisonBID: UUID?
    @State private var workflowStep: RectificationWorkflowStep = .data

    private var charts: [NatalChart] { appState.userStore.savedCharts }

    var body: some View {
        Group {
            if charts.isEmpty {
                ContentUnavailableView(
                    "Necesitas una carta guardada",
                    systemImage: "clock.badge.questionmark",
                    description: Text("Guarda una carta natal antes de iniciar una rectificación.")
                )
            } else {
                mainContent
            }
        }
        .background(Color.appBackground)
        .onAppear { selectInitialChartIfNeeded() }
        .onChange(of: selectedChartID) { _, _ in loadSelectedChart() }
        .onChange(of: viewModel.result) { _, result in
            if result != nil { workflowStep = .result }
        }
    }

    private var mainContent: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                header
                sessionActions
                workflowNavigation
                workflowContent
                workflowFooter
            }
            .padding(24)
            .frame(maxWidth: 1100, alignment: .leading)
        }
    }

    private var workflowNavigation: some View {
        Picker("Paso", selection: $workflowStep) {
            ForEach(RectificationWorkflowStep.allCases) { step in
                Label(step.label, systemImage: step.icon).tag(step)
            }
        }
        .pickerStyle(.segmented)
        .accessibilityLabel("Paso de rectificación")
    }

    @ViewBuilder
    private var workflowContent: some View {
        switch workflowStep {
        case .data:
            if let binding = sessionBinding {
                RectificationDataCard(charts: charts, selectedChartID: $selectedChartID, session: binding)
            }
        case .questionnaire:
            if let binding = sessionBinding { RectificationQuestionnaireCard(session: binding) }
        case .events:
            if let binding = sessionBinding {
                RectificationEventsCard(session: binding, onAdd: viewModel.addEvent) { eventID in
                    if let index = viewModel.session?.events.firstIndex(where: { $0.id == eventID }) {
                        viewModel.removeEvents(at: IndexSet(integer: index))
                    }
                }
            }
        case .configuration:
            RectificationConfigurationCard(config: $viewModel.config)
            analysisControls
        case .result:
            if let result = viewModel.result {
                resultCard(result)
                if let narrative = viewModel.narrative { narrativeCard(narrative) }
            } else {
                ContentUnavailableView(
                    "Aún no hay resultado",
                    systemImage: "chart.bar.xaxis",
                    description: Text("Completa los pasos anteriores y ejecuta el análisis.")
                )
                analysisControls
            }
        }
    }

    private var workflowFooter: some View {
        HStack {
            Button("Anterior", systemImage: "chevron.left") {
                workflowStep = RectificationWorkflowStep(rawValue: max(0, workflowStep.rawValue - 1)) ?? .data
            }
            .disabled(workflowStep == .data)
            Spacer()
            Text("Paso \(workflowStep.rawValue + 1) de \(RectificationWorkflowStep.allCases.count)")
                .font(.caption)
                .foregroundStyle(.secondary)
            Spacer()
            Button("Siguiente", systemImage: "chevron.right") {
                workflowStep = RectificationWorkflowStep(rawValue: min(RectificationWorkflowStep.allCases.count - 1, workflowStep.rawValue + 1)) ?? .result
            }
            .disabled(workflowStep == .result)
        }
    }

    private var sessionActions: some View {
        HStack {
            Button("Guardar sesión", systemImage: "square.and.arrow.down") { viewModel.saveSession() }
                .disabled(viewModel.session == nil)
            Menu("Historial") {
                if viewModel.savedSessions.isEmpty { Text("Sin sesiones guardadas") }
                ForEach(viewModel.savedSessions) { saved in
                    Menu("\(saved.name) · \(saved.updatedAt.formatted(date: .abbreviated, time: .shortened)) · v\(saved.versionCount)") {
                        Button("Abrir") { viewModel.loadSession(id: saved.id) }
                        Button("Eliminar", role: .destructive) { viewModel.deleteSession(id: saved.id) }
                    }
                }
            }
            Button("Exportar JSON") { exportJSON() }.disabled(viewModel.session == nil)
            Button("Importar JSON") { importJSON() }
            if viewModel.result != nil {
                Button("Exportar PDF", systemImage: "doc.richtext") { exportPDF() }
                Button("Crear nota Joplin", systemImage: "note.text.badge.plus") { createJoplinNote() }
            }
            Spacer()
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 6) {
            Label("Rectificación de hora natal", systemImage: "clock.badge.questionmark")
                .font(.title2.weight(.semibold))
            Text("Compara hipótesis horarias con eventos vitales. El resultado es una ayuda profesional, no reemplaza documentación fiable.")
                .foregroundStyle(.secondary)
        }
    }

    private var analysisControls: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Button("Analizar candidatas", systemImage: "waveform.path.ecg") { viewModel.analyze() }
                    .buttonStyle(.borderedProminent)
                    .disabled(viewModel.isAnalyzing || reliableEventCount < viewModel.config.minimumEventsForAnalysis)
                if viewModel.isAnalyzing {
                    Button("Cancelar") { viewModel.cancel() }
                    ProgressView(value: viewModel.progress).frame(width: 220)
                    Text("\(Int(viewModel.progress * 100)) %").font(.caption.monospacedDigit())
                }
            }
            if let error = viewModel.errorMessage {
                Label(error, systemImage: "exclamationmark.triangle").foregroundStyle(Color.appWarning)
            }
            if let message = viewModel.saveMessage {
                Label(message, systemImage: "checkmark.circle.fill").foregroundStyle(Color.appSecondaryAccent)
            }
        }
    }

    private func resultCard(_ result: RectificationAnalysisResult) -> some View {
        GroupBox("Resultado determinista") {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    VStack(alignment: .leading) {
                        Text("Confianza: \(confidenceLabel(result.overallConfidence))").font(.headline)
                        Text("\(result.candidates.count) candidatas finales · \(String(format: "%.2f", result.computeTimeSeconds)) s")
                            .font(.caption).foregroundStyle(.secondary)
                    }
                    Spacer()
                    Button("Guardar candidata principal") { viewModel.saveTopCandidate(in: appState.userStore) }
                        .disabled(result.topCandidate == nil)
                }
                if !result.warnings.isEmpty {
                    ForEach(result.warnings, id: \.self) { Label($0, systemImage: "exclamationmark.triangle") .font(.caption).foregroundStyle(.secondary) }
                }
                RectificationAuditSummaryView(result: result, events: viewModel.session?.events ?? [])
                if !result.clusters.isEmpty {
                    DisclosureGroup("Distribución y clusters") {
                        VStack(alignment: .leading, spacing: 8) {
                            ForEach(Array(result.clusters.prefix(8).enumerated()), id: \.element.id) { index, cluster in
                                HStack {
                                    Text("#\(index + 1) · \(cluster.timeRange)").frame(width: 190, alignment: .leading)
                                    GeometryReader { proxy in
                                        RoundedRectangle(cornerRadius: 3)
                                            .fill(Color.appSecondaryAccent.opacity(0.75))
                                            .frame(width: proxy.size.width * min(1, cluster.averageScore / max(1, result.clusters.first?.averageScore ?? 1)))
                                    }.frame(height: 10)
                                    Text(String(format: "%.1f", cluster.averageScore)).monospacedDigit().frame(width: 45)
                                    Text(cluster.ascendantSign).frame(width: 85, alignment: .leading)
                                }
                            }
                        }.padding(.vertical, 6)
                    }
                }
                if result.candidates.count >= 2 {
                    candidateComparison(result)
                }
                if let diagnostics = result.topCandidate?.overfittingDiagnostics {
                    Label("Score bruto \(String(format: "%.1f", diagnostics.rawScore)); ajuste anti-overfitting −\(String(format: "%.1f", diagnostics.penalty)); evento dominante \(Int(diagnostics.dominantEventShare * 100)) %; técnica dominante \(Int(diagnostics.dominantTechniqueShare * 100)) %.", systemImage: "scale.3d")
                        .font(.caption).foregroundStyle(.secondary)
                }
                ForEach(Array(result.candidates.prefix(8).enumerated()), id: \.element.id) { index, candidate in
                    HStack {
                        Text("#\(index + 1)").font(.caption.monospacedDigit()).frame(width: 28)
                        Text(candidate.birthTime).font(.body.monospacedDigit()).frame(width: 90, alignment: .leading)
                        Text(candidate.ascendantFormatted).frame(minWidth: 180, alignment: .leading)
                        Text("MC \(candidate.mcFormatted)").frame(minWidth: 180, alignment: .leading)
                        Spacer()
                        Text(String(format: "%.1f", candidate.totalScore)).font(.headline.monospacedDigit())
                    }
                    .padding(.vertical, 4)
                    if index < min(7, result.candidates.count - 1) { Divider() }
                }
                if let top = result.topCandidate, !top.evidence.isEmpty {
                    DisclosureGroup("Evidencias principales") {
                        ForEach(top.evidence.prefix(12)) { evidence in
                            VStack(alignment: .leading, spacing: 2) {
                                Text(evidence.factor).font(.subheadline.weight(.medium))
                                Text("\(evidence.technique.label) · \(String(format: "%.1f", evidence.score)) puntos · \(evidence.explanation)")
                                    .font(.caption).foregroundStyle(.secondary)
                            }.padding(.vertical, 3)
                        }
                    }
                }
                Divider()
                HStack {
                    Picker("Proveedor", selection: $viewModel.llmProvider) {
                        ForEach(LLMProvider.allCases) { Text($0.label).tag($0) }
                    }.frame(width: 220)
                    Button("Generar comparación con IA", systemImage: "sparkles") { viewModel.generateNarrative() }
                        .disabled(viewModel.isGeneratingNarrative)
                    if viewModel.isGeneratingNarrative { ProgressView().controlSize(.small) }
                    Text("Acción opcional con red y posible coste.").font(.caption).foregroundStyle(.secondary)
                }
            }
            .padding(8)
        }
    }

    private func narrativeCard(_ narrative: RectificationNarrative) -> some View {
        GroupBox("Comparación narrativa opcional") {
            VStack(alignment: .leading, spacing: 10) {
                Text(narrative.markdown).textSelection(.enabled)
                Divider()
                Text(narrativeTrace(narrative))
                    .font(.caption).foregroundStyle(.secondary)
            }.padding(8)
        }
    }

    private func narrativeTrace(_ narrative: RectificationNarrative) -> String {
        var trace = "\(narrative.provider.label) · \(narrative.model) · \(narrative.inputTokens) entrada / \(narrative.outputTokens) salida"
        if let cost = narrative.estimatedCostUSD {
            trace += " · $\(String(format: "%.4f", cost)) USD"
        }
        return trace
    }

    private var sessionBinding: Binding<RectificationSession>? {
        guard viewModel.session != nil else { return nil }
        return Binding(get: { viewModel.session! }, set: { viewModel.session = $0 })
    }

    private func candidateComparison(_ result: RectificationAnalysisResult) -> some View {
        let firstID = comparisonAID ?? result.candidates.first?.id
        let secondID = comparisonBID ?? result.candidates.dropFirst().first?.id
        let first = result.candidates.first { $0.id == firstID }
        let second = result.candidates.first { $0.id == secondID }
        return DisclosureGroup("Comparación lado a lado") {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    candidatePicker("Candidata A", selection: $comparisonAID, candidates: result.candidates, fallback: firstID)
                    candidatePicker("Candidata B", selection: $comparisonBID, candidates: result.candidates, fallback: secondID)
                }
                if let first, let second {
                    HStack(alignment: .top, spacing: 16) {
                        comparisonColumn(first).frame(maxWidth: .infinity)
                        Divider()
                        comparisonColumn(second).frame(maxWidth: .infinity)
                    }
                }
            }.padding(.vertical, 6)
        }
    }

    private func candidatePicker(_ label: String, selection: Binding<UUID?>, candidates: [RectificationCandidate], fallback: UUID?) -> some View {
        Picker(label, selection: Binding(get: { selection.wrappedValue ?? fallback }, set: { selection.wrappedValue = $0 })) {
            ForEach(candidates.prefix(12)) { Text("\($0.birthTime) · \(String(format: "%.1f", $0.totalScore))").tag(Optional($0.id)) }
        }
    }

    private func comparisonColumn(_ candidate: RectificationCandidate) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(candidate.birthTime).font(.headline.monospacedDigit())
            Text("ASC \(candidate.ascendantFormatted) · MC \(candidate.mcFormatted)")
            Text("Score \(String(format: "%.1f", candidate.totalScore)) · \(candidate.confidenceBand.rawValue)")
            ForEach(candidate.techniqueScores.sorted { $0.value > $1.value }.prefix(6), id: \.key) {
                Text("\($0.key.label): \(String(format: "%.1f", $0.value))").font(.caption)
            }
        }
    }

    private var reliableEventCount: Int {
        viewModel.session?.events.filter { $0.precision.qualifiesForMinimumDataset }.count ?? 0
    }

    private func selectInitialChartIfNeeded() {
        guard selectedChartID == nil else { return }
        selectedChartID = (appState.activeNatalChart ?? charts.first)?.id
        loadSelectedChart()
    }

    private func loadSelectedChart() {
        guard let selectedChartID, let chart = charts.first(where: { $0.id == selectedChartID }) else { return }
        viewModel.load(chart: chart)
    }

    private func confidenceLabel(_ confidence: RectificationConfidenceBand) -> String {
        switch confidence {
        case .high: return "alta"
        case .medium: return "media"
        case .low: return "baja"
        case .inconclusive: return "inconclusa"
        }
    }

    private func exportJSON() {
        do {
            let data = try viewModel.exportArchiveData()
            let panel = NSSavePanel(); panel.allowedContentTypes = [.json]
            panel.nameFieldStringValue = "rectificacion-\(viewModel.session?.name ?? "sesion").json"
            if panel.runModal() == .OK, let url = panel.url { try data.write(to: url, options: .atomic) }
        } catch { viewModel.errorMessage = "Exportación JSON: \(error.localizedDescription)" }
    }

    private func importJSON() {
        let panel = NSOpenPanel(); panel.allowedContentTypes = [.json]; panel.allowsMultipleSelection = false
        guard panel.runModal() == .OK, let url = panel.url else { return }
        do { try viewModel.importArchiveData(Data(contentsOf: url)) }
        catch { viewModel.errorMessage = "Importación JSON: \(error.localizedDescription)" }
    }

    private func exportPDF() {
        guard let session = viewModel.session, let result = viewModel.result else { return }
        Task {
            do {
                _ = try await PDFReportExportCoordinator.export(
                    chartName: session.name, reportType: "rectificacion",
                    joplinSettings: appState.joplinSettings
                ) { pageSize in
                    try await RectificationReportBuilder.generate(session: session, result: result, narrative: viewModel.narrative, pageSize: pageSize)
                }
            } catch { viewModel.errorMessage = "PDF: \(error.localizedDescription)" }
        }
    }

    private func createJoplinNote() {
        guard let session = viewModel.session, let result = viewModel.result else { return }
        Task {
            do {
                try await JoplinClipperService(settings: appState.joplinSettings).createNote(
                    title: "Rectificación — \(session.name)",
                    body: RectificationNoteBuilder.markdown(session: session, result: result, narrative: viewModel.narrative)
                )
                viewModel.saveMessage = "Nota creada en Joplin."
            } catch { viewModel.errorMessage = "Joplin: \(error.localizedDescription)" }
        }
    }
}
