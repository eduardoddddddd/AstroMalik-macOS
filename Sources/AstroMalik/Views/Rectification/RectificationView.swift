import SwiftUI
import AppKit

struct RectificationView: View {
    @EnvironmentObject private var appState: AppState
    @StateObject private var viewModel = RectificationViewModel()
    @State private var selectedChartID: UUID?

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
    }

    private var mainContent: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                header
                sessionActions
                chartAndRangeCard
                eventsCard
                analysisControls
                if let result = viewModel.result { resultCard(result) }
                if let narrative = viewModel.narrative { narrativeCard(narrative) }
            }
            .padding(24)
            .frame(maxWidth: 1100, alignment: .leading)
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

    private var chartAndRangeCard: some View {
        GroupBox("Carta y rango") {
            VStack(alignment: .leading, spacing: 12) {
                Picker("Carta", selection: $selectedChartID) {
                    ForEach(charts) { chart in
                        Text(chart.name.isEmpty ? chart.birthDate : chart.name).tag(Optional(chart.id))
                    }
                }
                .frame(maxWidth: 420)

                if let binding = sessionBinding {
                    HStack(spacing: 14) {
                        TextField("Hora central", text: binding.searchRange.centerTime)
                            .frame(width: 110)
                        Stepper("Antes: \(binding.wrappedValue.searchRange.minutesBefore) min", value: binding.searchRange.minutesBefore, in: 0...720, step: 15)
                        Stepper("Después: \(binding.wrappedValue.searchRange.minutesAfter) min", value: binding.searchRange.minutesAfter, in: 0...720, step: 15)
                    }
                    HStack {
                        Stepper("Paso grueso: \(binding.wrappedValue.searchRange.coarseStepSeconds / 60) min", value: binding.searchRange.coarseStepSeconds, in: 60...900, step: 60)
                        Stepper("Paso fino: \(binding.wrappedValue.searchRange.fineStepSeconds) s", value: binding.searchRange.fineStepSeconds, in: 30...300, step: 30)
                    }
                    Toggle("Buscar en las 24 horas", isOn: binding.searchRange.includeFullDayFallback)
                    Text("Estimación primera pasada: \(binding.wrappedValue.searchRange.coarseCandidateEstimate) candidatas")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .padding(8)
        }
    }

    private var eventsCard: some View {
        GroupBox("Cronología vital") {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    datasetQuality
                    Spacer()
                    Button("Añadir evento", systemImage: "plus") { viewModel.addEvent() }
                }
                if let binding = sessionBinding, !binding.wrappedValue.events.isEmpty {
                    ForEach(binding.events) { $event in
                        HStack(alignment: .top, spacing: 8) {
                            TextField("Título", text: $event.title).frame(minWidth: 140)
                            Picker("Tipo", selection: $event.type) {
                                ForEach(RectificationEventType.allCases) { type in Text(type.label).tag(type) }
                            }.labelsHidden().frame(width: 165)
                            DatePicker("", selection: $event.dateStart, displayedComponents: .date).labelsHidden()
                            Picker("Precisión", selection: $event.precision) {
                                ForEach(RectificationEventPrecision.allCases) { precision in Text(precisionLabel(precision)).tag(precision) }
                            }.labelsHidden().frame(width: 140)
                            Stepper("\(event.importance)/5", value: $event.importance, in: 1...5).frame(width: 95)
                            Button(role: .destructive) {
                                if let index = binding.wrappedValue.events.firstIndex(where: { $0.id == event.id }) {
                                    viewModel.removeEvents(at: IndexSet(integer: index))
                                }
                            } label: { Image(systemName: "trash") }
                            .buttonStyle(.borderless)
                        }
                    }
                } else {
                    Text("Añade al menos tres eventos con fecha de día, semana o mes; seis o más mejoran la discriminación.")
                        .foregroundStyle(.secondary)
                }
            }
            .padding(8)
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

    private var datasetQuality: some View {
        let count = reliableEventCount
        return Label(count >= 6 ? "Dataset bueno (\(count))" : count >= 3 ? "Dataset aceptable (\(count))" : "Dataset insuficiente (\(count)/3)", systemImage: count >= 6 ? "checkmark.circle.fill" : "info.circle")
            .foregroundStyle(count >= 3 ? Color.appSecondaryAccent : Color.appWarning)
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

    private func precisionLabel(_ precision: RectificationEventPrecision) -> String {
        switch precision {
        case .exactDay: return "Día exacto"
        case .approximateWeek: return "Semana"
        case .approximateMonth: return "Mes"
        case .approximateQuarter: return "Trimestre"
        case .approximateYear: return "Año"
        case .dateRange: return "Rango"
        }
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
