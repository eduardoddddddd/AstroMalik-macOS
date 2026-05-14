import SwiftUI

struct SolarArcDirectionsView: View {
    @EnvironmentObject private var appState: AppState
    let chart: NatalChart?

    @StateObject private var vm = SolarArcViewModel()
    @State private var isExporting = false
    @State private var noteStatus: String?
    @State private var noteError: String?

    var body: some View {
        Group {
            if let chart, !chart.isPlaceholder {
                content(chart: chart)
                    .onAppear { loadIfNeeded(chart) }
                    .onChange(of: chart.id) { _, _ in vm.load(chart: chart) }
            } else {
                emptyChartState
            }
        }
        .alert("Error", isPresented: Binding(
            get: { vm.error != nil || noteError != nil },
            set: { if !$0 { vm.error = nil; noteError = nil } }
        )) {
            Button("OK") { vm.error = nil; noteError = nil }
        } message: {
            Text(vm.error ?? noteError ?? "")
        }
    }

    private func content(chart: NatalChart) -> some View {
        let enriched = vm.enrichedDirections
        let timeline = PrimaryDirectionsService.buildTimelineEntries(from: enriched)

        return VStack(spacing: 0) {
            header(chart: chart)

            if vm.isCalculating {
                loadingView
            } else {
                PrimaryDirectionsTimelineView(
                    directions: enriched,
                    timeline: timeline,
                    ageDomain: vm.visibleAgeDomain,
                    selectedDirection: $vm.selectedDirection
                )
                .frame(height: 210)
                .background(Color.appBackground)
                .overlay(alignment: .bottom) { Divider() }

                HSplitView {
                    professionalList(enriched: enriched)
                        .frame(minWidth: 420, idealWidth: 540)
                    detailPanel
                }
            }

            if let noteStatus {
                HStack {
                    Label(noteStatus, systemImage: "checkmark.circle.fill")
                        .font(.caption)
                        .foregroundStyle(Color.appSecondaryAccent)
                    Spacer()
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(Color.appPanel)
                .overlay(alignment: .top) { Divider() }
            }
        }
    }

    private func header(chart: NatalChart) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .bottom, spacing: 12) {
                VStack(alignment: .leading, spacing: 5) {
                    Text("Carta")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                    Text(chart.name.isEmpty ? chart.birthDate : chart.name)
                        .font(.body.weight(.medium))
                }
                Spacer()
                headerButton("±2 años", systemImage: "scope") { vm.setCurrentWindow(years: 2) }
                headerButton("Recalcular", systemImage: "arrow.clockwise") { vm.recalculate() }
                headerButton("Exportar a Joplin", systemImage: "note.text.badge.plus", isBusy: isExporting) {
                    exportToJoplin(chart: chart)
                }
                .disabled(vm.filteredDirections.isEmpty || isExporting)
                PDFExportButton(
                    chartName: chart.name.isEmpty ? "Carta natal" : chart.name,
                    reportType: "Arco solar",
                    disabled: vm.filteredDirections.isEmpty || vm.isCalculating,
                    generate: { pageSize in
                        let currentAge = SolarArcViewModel.currentAge(for: chart)
                        let targetDate = Calendar.current.date(byAdding: .day, value: Int(currentAge * 365.25), to: Date()) ?? Date()
                        let engine = SolarArcEngine()
                        let arc = engine.solarArcAmount(chart: chart, age: currentAge, mode: vm.mode) ?? 0
                        let data = SolarArcLongReportBuilder.build(
                            chart: chart,
                            mode: vm.mode,
                            targetDate: targetDate,
                            currentSolarArc: arc,
                            directions: vm.filteredDirections
                        )
                        return try await ReportService().generate(request: SolarArcLongReportBuilder.makeRequest(data: data).withPageSize(pageSize))
                    }
                )
                .environmentObject(appState)
            }

            HStack(spacing: 10) {
                Picker("Modo", selection: $vm.mode) {
                    ForEach(SolarArcMode.allCases) { mode in
                        Text(mode.label).tag(mode)
                    }
                }
                .pickerStyle(.segmented)
                .frame(width: 330)

                numericField("Desde", value: $vm.ageStart)
                numericField("Hasta", value: $vm.ageEnd)
                numericField("Orbe", value: $vm.orb)

                Picker("Preset", selection: $vm.activePreset) {
                    ForEach(PDFilterPreset.allCases) { preset in
                        Text(preset.rawValue).tag(Optional(preset))
                    }
                    Text("Personalizado").tag(Optional<PDFilterPreset>.none)
                }
                .frame(width: 150)

                Picker("Peso mínimo", selection: $vm.minimumWeight) {
                    ForEach([PDWeight.minor, .moderate, .major, .critical], id: \.self) { weight in
                        Text(weight.filterLabel).tag(weight)
                    }
                }
                .frame(width: 132)
            }

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    summaryChip("\(vm.filteredDirections.count)/\(vm.directions.count) visibles", tone: .secondary)
                    summaryChip("Preset: \(vm.presetDisplayName)", tone: vm.activePreset == nil ? Color.appAccentFill : .secondary)
                    summaryChip("\(vm.visibleCriticalCount) críticas", tone: vm.visibleCriticalCount == 0 ? .secondary : Color.appWarning)
                    summaryChip("\(String(format: "%.2f", vm.ageStart))-\(String(format: "%.2f", vm.ageEnd)) años", tone: .secondary)
                    summaryChip(vm.mode.label, tone: Color.appSecondaryAccent)
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .background(Color.appSurface)
        .overlay(alignment: .bottom) { Divider() }
    }

    private func professionalList(enriched: [EnrichedPrimaryDirection]) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text("Arco Solar")
                    .font(.headline)
                Spacer()
                Text("\(enriched.count)")
                    .font(.caption.monospaced())
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(Color.appSurface)
            Divider()
            if enriched.isEmpty {
                filteredEmptyState
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(Color.appBackground)
            } else {
                PrimaryDirectionsTableView(directions: enriched, selection: $vm.selectedDirection)
            }
        }
        .background(Color.appBackground)
    }

    @ViewBuilder
    private var detailPanel: some View {
        if let selected = vm.selectedDirection,
           let direction = vm.filteredDirections.first(where: { $0.id == selected.id }) {
            SolarArcDirectionDetailView(direction: direction)
        } else {
            VStack(spacing: 10) {
                Image(systemName: "cursorarrow.click")
                    .font(.system(size: 32))
                    .foregroundStyle(.tertiary)
                Text("Selecciona una dirección por arco solar")
                    .font(.callout)
                    .foregroundStyle(.tertiary)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color.appBackground)
        }
    }

    private var loadingView: some View {
        VStack(spacing: 18) {
            ProgressView().controlSize(.large)
            Text("Calculando direcciones por arco solar…")
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.appBackground)
    }

    private var emptyChartState: some View {
        VStack(spacing: 16) {
            Image(systemName: "sun.max.trianglebadge.exclamationmark")
                .font(.system(size: 48))
                .foregroundStyle(Color.appAccentFill.opacity(0.5))
            Text("Sin carta activa")
                .font(.title3.bold())
            Text("Abre una carta natal para calcular sus direcciones por arco solar.")
                .font(.callout)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.appBackground)
    }

    private var filteredEmptyState: some View {
        VStack(spacing: 14) {
            Image(systemName: "line.3.horizontal.decrease.circle")
                .font(.system(size: 40))
                .foregroundStyle(Color.appAccentFill.opacity(0.75))
            Text("Ningún arco solar coincide")
                .font(.title3.bold())
            Text("Amplía la ventana de edad o baja el peso mínimo.")
                .font(.callout)
                .foregroundStyle(.secondary)
        }
    }

    private func loadIfNeeded(_ chart: NatalChart) {
        if vm.currentChart?.id != chart.id {
            vm.load(chart: chart)
        }
    }

    private func exportToJoplin(chart: NatalChart) {
        isExporting = true
        noteStatus = nil
        noteError = nil
        let settings = appState.joplinSettings
        let body = SolarArcNoteBuilder.filteredReportMarkdown(
            chart: chart,
            mode: vm.mode,
            ageStart: min(vm.ageStart, vm.ageEnd),
            ageEnd: max(vm.ageStart, vm.ageEnd),
            minimumWeight: vm.minimumWeight,
            preset: vm.activePreset,
            directions: vm.filteredDirections
        )
        let title = SolarArcNoteBuilder.noteTitle(
            chart: chart,
            ageStart: min(vm.ageStart, vm.ageEnd),
            ageEnd: max(vm.ageStart, vm.ageEnd)
        )

        Task {
            defer { isExporting = false }
            do {
                let service = JoplinClipperService(settings: settings)
                try await service.createNote(title: title, body: body)
                guard !Task.isCancelled else { return }
                noteStatus = "Informe de arco solar creado en Joplin."
            } catch {
                guard !Task.isCancelled else { return }
                noteError = error.localizedDescription
            }
        }
    }

    private func headerButton(_ title: String, systemImage: String, isBusy: Bool = false, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            if isBusy {
                ProgressView().controlSize(.small)
            } else {
                Label(title, systemImage: systemImage)
            }
        }
        .buttonStyle(.bordered)
    }

    private func numericField(_ label: String, value: Binding<Double>) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(label)
                .font(.caption2.weight(.semibold))
                .foregroundStyle(.secondary)
            TextField(label, value: value, format: .number.precision(.fractionLength(0...2)))
                .textFieldStyle(.roundedBorder)
                .frame(width: 68)
        }
    }

    private func summaryChip(_ text: String, tone: Color) -> some View {
        Text(text)
            .font(.caption.monospaced())
            .foregroundStyle(tone)
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(tone.opacity(0.08), in: Capsule())
    }
}

private struct SolarArcDirectionDetailView: View {
    let direction: SolarArcDirection

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                VStack(alignment: .leading, spacing: 8) {
                    Text(direction.displaySummary)
                        .font(.title3.bold())
                    HStack(spacing: 8) {
                        badge(direction.weight.label, tone: weightTone(direction.weight))
                        badge(direction.polarity.label, tone: Color.appSecondaryAccent)
                        badge(direction.mode.label, tone: .secondary)
                    }
                }

                Divider()

                gridRow("Fecha exacta", date(direction.exactDate))
                gridRow("Edad", direction.ageFormatted)
                gridRow("Arco solar", direction.arcFormatted)
                gridRow("Aspecto", direction.aspect.label)
                gridRow("Punto dirigido", "\(direction.directedPointLabel) · \(AstroEngine.degToSign(direction.directedLongitude))")
                gridRow("Natal receptor", "\(direction.natalPointLabel) · \(AstroEngine.degToSign(direction.natalLongitude))")

                Text("El cálculo mantiene fijos los puntos natales y dirige únicamente el punto seleccionado por el arco solar. No mezcla aspectos dirigido-dirigido.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .padding(12)
                    .background(Color.appPanel, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
            }
            .padding(20)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .background(Color.appBackground)
    }

    private func gridRow(_ label: String, _ value: String) -> some View {
        HStack(alignment: .firstTextBaseline) {
            Text(label)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
                .frame(width: 120, alignment: .leading)
            Text(value)
                .font(.body)
            Spacer()
        }
    }

    private func badge(_ text: String, tone: Color) -> some View {
        Text(text)
            .font(.caption.weight(.semibold))
            .foregroundStyle(tone)
            .padding(.horizontal, 9)
            .padding(.vertical, 4)
            .background(tone.opacity(0.10), in: Capsule())
    }

    private func weightTone(_ weight: PDWeight) -> Color {
        switch weight {
        case .critical: return Color.appWarning
        case .major: return Color.appAccentFill
        case .moderate: return .secondary
        case .minor: return Color.secondary.opacity(0.7)
        }
    }

    private func date(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "es_ES")
        formatter.timeZone = TimeZone.current
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: date)
    }
}
