import SwiftUI

struct PrimaryDirectionsView: View {
    @EnvironmentObject private var appState: AppState
    @ObservedObject var vm: PrimaryDirectionsViewModel

    @State private var showFilters = false
    @State private var showSettings = false
    @State private var isCreatingSelectedNote = false
    @State private var isCreatingReportNote = false
    @State private var noteStatus: String?
    @State private var noteError: String?

    private var charts: [NatalChart] { appState.userStore.savedCharts }

    var body: some View {
        Group {
            if vm.isCalculating {
                loadingView
            } else if let result = vm.result, !result.enrichedDirections.isEmpty {
                mainLayout(result: result)
            } else {
                emptyState
            }
        }
        .sheet(isPresented: $showFilters) {
            PrimaryDirectionFiltersView(filters: $vm.filters, maxYears: vm.settings.maxYears)
        }
        .sheet(isPresented: $showSettings, onDismiss: {
            vm.refreshForUpdatedSettings()
        }) {
            PDSettingsSheet(settings: $vm.settings)
        }
        .alert("Error", isPresented: Binding(
            get: { vm.error != nil || noteError != nil },
            set: { if !$0 { vm.error = nil; noteError = nil } }
        )) {
            Button("OK") {
                vm.error = nil
                noteError = nil
            }
        } message: {
            Text(vm.error ?? noteError ?? "")
        }
    }

    private func mainLayout(result: PrimaryDirectionsResult) -> some View {
        let visibleTimeline = PrimaryDirectionsService.buildTimelineEntries(from: vm.filteredDirections)

        return VStack(spacing: 0) {
            header(result: result)
            honestyBanner(metadata: result.metadata)
            PrimaryDirectionsTimelineView(
                directions: vm.filteredDirections,
                timeline: visibleTimeline,
                ageDomain: vm.visibleAgeDomain,
                selectedDirection: $vm.selectedDirection
            )
            .frame(height: 210)
            .background(Color.appBackground)
            .overlay(alignment: .bottom) { Divider() }

            HSplitView {
                directionsListPanel
                    .frame(minWidth: 320, idealWidth: 380)
                detailPanel
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
        .animation(.easeInOut(duration: 0.18), value: vm.selectedDirection?.id)
    }

    private func header(result: PrimaryDirectionsResult) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .center, spacing: 14) {
                chartPicker
                Spacer()
                headerButton("Filtros", systemImage: vm.filtersAreDefault ? "line.3.horizontal.decrease.circle" : "line.3.horizontal.decrease.circle.fill") {
                    showFilters = true
                }
                headerButton("Ajustes", systemImage: "gearshape") {
                    showSettings = true
                }
                headerButton("Nota seleccionada", systemImage: "note.text.badge.plus", isBusy: isCreatingSelectedNote) {
                    createSelectedDirectionNote()
                }
                .disabled(vm.selectedDirection == nil || isCreatingReportNote)
                headerButton("Informe filtrado", systemImage: "doc.text") {
                    createFilteredReportNote()
                }
                .disabled(vm.filteredDirections.isEmpty || isCreatingSelectedNote || isCreatingReportNote)
            }

            HStack(spacing: 8) {
                summaryChip("\(vm.filteredDirections.count)/\(result.metadata.totalDirections) visibles", tone: .secondary)
                summaryChip("\(vm.filteredDirections.filter(\.hasInterpretation).count) con corpus", tone: .secondary)
                summaryChip("\(vm.filteredDirections.filter { vm.cachedContextualDirectionIDs.contains($0.id) }.count) con contextual", tone: .secondary)
                summaryChip(vm.settings.aspectPlane == .mundane ? "Plano mundano" : "Plano zodiacal", tone: .secondary)
                summaryChip(vm.settings.key.rawValue, tone: .secondary)
                summaryChip("\(Int(vm.visibleAgeDomain.lowerBound))-\(Int(vm.visibleAgeDomain.upperBound)) años", tone: .secondary)
            }

            HStack(spacing: 8) {
                statusBadge(appState.openRouterAvailability.badgeLabel, tone: availabilityTone(appState.openRouterAvailability))
                statusBadge(appState.openRouterAvailability.sourceLabel, tone: .secondary)
                if appState.hasPersistentPDInterpretationCache {
                    statusBadge("Caché disponible", tone: Color.appSecondaryAccent)
                }
                if !vm.filtersAreDefault {
                    statusBadge("Filtros activos", tone: Color.appAccentFill)
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .background(Color.appSurface)
        .overlay(alignment: .bottom) { Divider() }
    }

    private var chartPicker: some View {
        VStack(alignment: .leading, spacing: 5) {
            Text("Carta")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)

            if charts.count > 1 {
                Picker("Carta", selection: selectedChartIDBinding) {
                    ForEach(charts) { chart in
                        Text(chartDisplayName(chart)).tag(Optional(chart.id))
                    }
                }
                .labelsHidden()
                .frame(width: 280)
            } else if let chart = vm.currentChart {
                Text(chartDisplayName(chart))
                    .font(.body.weight(.medium))
            } else {
                Text("Sin carta activa")
                    .font(.body)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var directionsListPanel: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text("Direcciones visibles")
                    .font(.headline)
                Spacer()
                if !vm.filteredDirections.isEmpty {
                    Text("\(vm.filteredDirections.count)")
                        .font(.caption.monospaced())
                        .foregroundStyle(.secondary)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(Color.appSurface)

            Divider()

            if vm.filteredDirections.isEmpty {
                filteredEmptyState
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(Color.appBackground)
            } else {
                List(vm.filteredDirections) { enriched in
                    PDVisibleDirectionRow(
                        enriched: enriched,
                        isSelected: vm.selectedDirection?.id == enriched.id,
                        hasCachedContextual: vm.cachedContextualDirectionIDs.contains(enriched.id)
                    )
                    .contentShape(Rectangle())
                    .listRowInsets(EdgeInsets(top: 8, leading: 12, bottom: 8, trailing: 12))
                    .listRowSeparator(.visible)
                    .background(Color.clear)
                    .onTapGesture {
                        vm.selectedDirection = enriched
                    }
                }
                .listStyle(.inset)
            }
        }
        .background(Color.appBackground)
    }

    @ViewBuilder
    private var detailPanel: some View {
        if vm.filteredDirections.isEmpty {
            filteredEmptyState
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color.appBackground)
        } else if let selected = vm.selectedDirection {
            PrimaryDirectionDetailView(
                enriched: selected,
                contextualInterpretation: vm.contextualInterpretation,
                isGeneratingInterpretation: vm.isGeneratingInterpretation,
                contextualAvailability: appState.openRouterAvailability.badgeLabel,
                onRequestInterpretation: {
                    vm.requestContextualInterpretation(for: selected)
                },
                onInvalidateInterpretation: {
                    vm.invalidateInterpretation(for: selected.direction)
                }
            )
        } else {
            noSelectionHint
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color.appBackground)
        }
    }

    private func honestyBanner(metadata: PrimaryDirectionsMetadata) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "books.vertical.fill")
                .foregroundStyle(Color.appAccentFill)
            VStack(alignment: .leading, spacing: 4) {
                Text("Corpus en curación manual")
                    .font(.subheadline.weight(.semibold))
                Text("La Capa 1 solo muestra textos verificados y atribuidos. Cobertura actual del corpus: \(String(format: "%.1f", metadata.corpusCoverage))%.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(Color.appPanel)
        .overlay(alignment: .bottom) { Divider() }
    }

    private var loadingView: some View {
        VStack(spacing: 18) {
            ProgressView()
                .controlSize(.large)
            Text("Calculando espéculo de direcciones…")
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.appBackground)
    }

    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "arrow.triangle.swap")
                .font(.system(size: 48))
                .foregroundStyle(Color.appAccentFill.opacity(0.5))
            Text("Sin direcciones calculadas")
                .font(.title3.bold())
            Text("Abre una carta natal y calcula sus direcciones primarias para ver el timeline, la lista visible y el detalle contextual.")
                .font(.callout)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 420)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.appBackground)
    }

    private var noSelectionHint: some View {
        VStack(spacing: 10) {
            Image(systemName: "cursorarrow.click")
                .font(.system(size: 32))
                .foregroundStyle(.tertiary)
            Text("Selecciona una dirección en la lista o en el timeline")
                .font(.callout)
                .foregroundStyle(.tertiary)
        }
    }

    private var filteredEmptyState: some View {
        VStack(spacing: 14) {
            Image(systemName: "line.3.horizontal.decrease.circle")
                .font(.system(size: 40))
                .foregroundStyle(Color.appAccentFill.opacity(0.75))
            Text("Ninguna dirección coincide con los filtros")
                .font(.title3.bold())
            Text("Amplía el rango de edad o restablece los filtros para recuperar el conjunto visible.")
                .font(.callout)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 380)
            Button("Restablecer filtros") {
                vm.filters.reset(maxYears: vm.settings.maxYears)
            }
            .buttonStyle(.borderedProminent)
            .tint(Color.appAccentFill)
        }
    }

    private func createSelectedDirectionNote() {
        guard let chart = vm.currentChart, let selected = vm.selectedDirection else { return }
        noteStatus = nil
        noteError = nil
        isCreatingSelectedNote = true
        let settings = appState.joplinSettings
        let contextual = vm.contextualInterpretation

        Task {
            defer { isCreatingSelectedNote = false }
            do {
                let service = JoplinClipperService(settings: settings)
                try await service.createNote(
                    title: "Dirección Primaria - \(chartDisplayName(chart))",
                    body: PrimaryDirectionsNoteBuilder.singleDirectionMarkdown(
                        chart: chart,
                        enriched: selected,
                        contextual: contextual
                    )
                )
                guard !Task.isCancelled else { return }
                noteStatus = "Nota de dirección creada en Joplin."
            } catch {
                guard !Task.isCancelled else { return }
                noteError = error.localizedDescription
            }
        }
    }

    private func createFilteredReportNote() {
        guard let chart = vm.currentChart else { return }
        noteStatus = nil
        noteError = nil
        isCreatingReportNote = true
        let settings = appState.joplinSettings
        let filtered = vm.filteredDirections
        let selected = vm.selectedDirection
        let cachedIDs = vm.cachedContextualDirectionIDs
        let pdSettings = vm.settings

        Task {
            defer { isCreatingReportNote = false }
            do {
                let service = JoplinClipperService(settings: settings)
                try await service.createNote(
                    title: "Informe Direcciones Primarias - \(chartDisplayName(chart))",
                    body: PrimaryDirectionsNoteBuilder.filteredReportMarkdown(
                        chart: chart,
                        settings: pdSettings,
                        visibleDirections: filtered,
                        selectedDirection: selected,
                        cachedContextualIDs: cachedIDs
                    )
                )
                guard !Task.isCancelled else { return }
                noteStatus = "Informe filtrado creado en Joplin."
            } catch {
                guard !Task.isCancelled else { return }
                noteError = error.localizedDescription
            }
        }
    }

    private var selectedChartIDBinding: Binding<UUID?> {
        Binding(
            get: { vm.currentChart?.id },
            set: { newValue in
                guard let newValue,
                      let chart = charts.first(where: { $0.id == newValue }) else { return }
                appState.showPrimaryDirections(for: chart)
            }
        )
    }

    private func headerButton(
        _ title: String,
        systemImage: String,
        isBusy: Bool = false,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            if isBusy {
                ProgressView()
                    .controlSize(.small)
            } else {
                Label(title, systemImage: systemImage)
            }
        }
        .buttonStyle(.bordered)
    }

    private func summaryChip(_ text: String, tone: Color) -> some View {
        Text(text)
            .font(.caption.monospaced())
            .foregroundStyle(tone)
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(tone.opacity(0.08), in: Capsule())
    }

    private func statusBadge(_ text: String, tone: Color) -> some View {
        Label(text, systemImage: "circle.fill")
            .font(.caption)
            .foregroundStyle(tone)
            .labelStyle(.titleAndIcon)
    }

    private func availabilityTone(_ availability: OpenRouterAvailability) -> Color {
        switch availability {
        case .notConfigured:
            return .secondary
        case .ready:
            return Color.appSecondaryAccent
        case .invalid:
            return Color.appWarning
        }
    }

    private func chartDisplayName(_ chart: NatalChart) -> String {
        chart.name.isEmpty ? chart.birthDate : chart.name
    }
}

private struct PDVisibleDirectionRow: View {
    let enriched: EnrichedPrimaryDirection
    let isSelected: Bool
    let hasCachedContextual: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .firstTextBaseline) {
                Text(enriched.displaySummary)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.primary)
                    .lineLimit(2)
                Spacer()
                Text(enriched.ageFormatted)
                    .font(.caption.monospaced())
                    .foregroundStyle(Color.appAccentFill)
            }

            HStack(spacing: 8) {
                rowBadge(enriched.direction.directionType == .direct ? "Directa" : "Conversa", tone: .secondary)
                rowBadge(enriched.direction.aspectPlane == .mundane ? "Mundano" : "Zodiacal", tone: .secondary)
                rowBadge(enriched.hasInterpretation ? "Corpus" : "Sin corpus", tone: enriched.hasInterpretation ? Color.appSecondaryAccent : .secondary)
                rowBadge(hasCachedContextual ? "Contextual" : "Sin contextual", tone: hasCachedContextual ? Color.appAccentFill : .secondary)
            }

            Text("Arco \(enriched.arcFormatted)")
                .font(.caption.monospaced())
                .foregroundStyle(.secondary)
        }
        .padding(10)
        .background(isSelected ? Color.appAccentFill.opacity(0.08) : Color.appSurface, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .stroke(isSelected ? Color.appAccentFill.opacity(0.35) : Color.appBorder.opacity(0.5), lineWidth: 1)
        )
    }

    private func rowBadge(_ text: String, tone: Color) -> some View {
        Text(text)
            .font(.caption2)
            .foregroundStyle(tone)
            .padding(.horizontal, 7)
            .padding(.vertical, 3)
            .background(tone.opacity(0.08), in: Capsule())
    }
}

private struct PDSettingsSheet: View {
    @Binding var settings: PDSettings
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Form {
                Section("Método de proyección") {
                    Picker("Método", selection: $settings.method) {
                        ForEach([PrimaryDirectionMethod.regiomontanus], id: \.self) { method in
                            Text(method.rawValue).tag(method)
                        }
                    }
                    .pickerStyle(.radioGroup)

                    Label("Regiomontanus es el único método soportado actualmente en la app. Placidus queda fuera hasta tener motor real.", systemImage: "info.circle")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Section("Clave temporal") {
                    Picker("Clave", selection: $settings.key) {
                        ForEach([PrimaryDirectionKey.naibod, .ptolemy, .brahe], id: \.self) { key in
                            Text(key.rawValue).tag(key)
                        }
                    }
                    .pickerStyle(.radioGroup)
                }

                Section("Plano del aspecto") {
                    Picker("Plano", selection: $settings.aspectPlane) {
                        Text("Mundano (Regiomontanus)").tag(PDAspectPlane.mundane)
                        Text("Zodiacal").tag(PDAspectPlane.zodiacal)
                    }
                    .pickerStyle(.radioGroup)
                }

                Section("Rango de cálculo") {
                    HStack {
                        Text("Años máximos")
                        Spacer()
                        Stepper(
                            "\(Int(settings.maxYears)) años",
                            value: $settings.maxYears,
                            in: 10...120,
                            step: 5
                        )
                    }
                }
            }
            .formStyle(.grouped)
            .navigationTitle("Configuración — Direcciones Primarias")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Listo") { dismiss() }
                }
            }
            .frame(minWidth: 440, minHeight: 380)
        }
    }
}
