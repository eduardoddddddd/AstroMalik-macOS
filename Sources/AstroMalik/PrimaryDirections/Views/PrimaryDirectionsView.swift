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
    @State private var showHonestyPolicy = false

    private var charts: [NatalChart] { appState.userStore.savedCharts }
    private var selectableCharts: [NatalChart] {
        var available = charts
        if let current = vm.currentChart,
           !available.contains(where: { $0.id == current.id }) {
            available.insert(current, at: 0)
        }
        return available
    }

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
            PDSettingsSheet(settings: $vm.settings, activePreset: $vm.activePreset)
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
                leftTabs
                    .frame(minWidth: 420, idealWidth: 520)
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
            HStack(alignment: .bottom, spacing: 12) {
                chartPicker
                    .frame(minWidth: 260, maxWidth: .infinity, alignment: .leading)

                Spacer()
                headerButton("Filtros", systemImage: vm.filtersAreDefault ? "line.3.horizontal.decrease.circle" : "line.3.horizontal.decrease.circle.fill") {
                    showFilters = true
                }
                headerButton("Ajustes", systemImage: "gearshape") {
                    showSettings = true
                }
                Button {
                    showHonestyPolicy.toggle()
                } label: {
                    Image(systemName: "info.circle")
                }
                .buttonStyle(.borderless)
                .help("Política de honestidad del corpus")
                .popover(isPresented: $showHonestyPolicy, arrowEdge: .bottom) {
                    honestyPolicyPopover(metadata: result.metadata)
                        .frame(width: 360)
                        .padding(14)
                }
            }

            HStack(alignment: .center, spacing: 10) {
                headerButton("Nota seleccionada", systemImage: "note.text.badge.plus", isBusy: isCreatingSelectedNote) {
                    createSelectedDirectionNote()
                }
                .disabled(vm.selectedDirection == nil || isCreatingReportNote)
                headerButton("Informe filtrado", systemImage: "doc.text") {
                    createFilteredReportNote()
                }
                .disabled(vm.filteredDirections.isEmpty || isCreatingSelectedNote || isCreatingReportNote)
                Spacer()
            }

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    presetSegmentedPicker
                    summaryChip("\(vm.filteredDirections.count)/\(result.metadata.totalDirections) visibles", tone: .secondary)
                    summaryChip("Preset: \(vm.presetDisplayName)", tone: vm.activePreset == nil ? Color.appAccentFill : .secondary)
                    summaryChip(
                        "\(vm.visibleCriticalCount) críticas",
                        tone: vm.visibleCriticalCount == 0 ? .secondary : Color.appWarning
                    )
                    summaryChip(
                        "\(vm.curatedVisibleDirections.count) textos curados",
                        tone: vm.curatedVisibleDirections.isEmpty ? .secondary : Color.appSecondaryAccent
                    )
                    summaryChip("Plano \(vm.settings.aspectPlane.displayName.lowercased())", tone: .secondary)
                    summaryChip(vm.settings.key.rawValue, tone: .secondary)
                    summaryChip("\(Int(vm.visibleAgeDomain.lowerBound))-\(Int(vm.visibleAgeDomain.upperBound)) años", tone: .secondary)
                    minimumWeightPicker
                }
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

    private var leftTabs: some View {
        TabView {
            professionalListPanel
                .tabItem { Text("Lista profesional") }

            directionsListPanel
                .tabItem { Text("Cards") }

            CurrentYearView(vm: vm)
                .tabItem { Text("Año en curso") }
        }
    }

    private var professionalListPanel: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text("Lista profesional")
                    .font(.headline)
                Spacer()
                Text("\(vm.filteredDirections.count)")
                    .font(.caption.monospaced())
                    .foregroundStyle(.secondary)
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
                PrimaryDirectionsTableView(
                    directions: vm.filteredDirections,
                    selection: $vm.selectedDirection
                )
            }
        }
        .background(Color.appBackground)
    }

    private var chartPicker: some View {
        VStack(alignment: .leading, spacing: 5) {
            Text("Carta")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)

            let availableCharts = selectableCharts

            if availableCharts.count > 1 {
                Picker("Carta", selection: selectedChartIDBinding) {
                    ForEach(availableCharts) { chart in
                        Text(chartDisplayName(chart)).tag(Optional(chart.id))
                    }
                }
                .labelsHidden()
                .frame(minWidth: 260, idealWidth: 360, maxWidth: 520, alignment: .leading)
            } else if let chart = availableCharts.first ?? vm.currentChart {
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
                Button {
                    vm.filters.onlyWithCorpus.toggle()
                } label: {
                    Image(systemName: vm.filters.onlyWithCorpus ? "checkmark.seal.fill" : "checkmark.seal")
                }
                .buttonStyle(.borderless)
                .help(vm.filters.onlyWithCorpus ? "Mostrar todas las direcciones" : "Mostrar solo textos curados")
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
                if !vm.curatedVisibleDirections.isEmpty {
                    curatedDirectionsSection
                    Divider()
                }

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

    private var curatedDirectionsSection: some View {
        let curated = vm.curatedVisibleDirections

        return VStack(alignment: .leading, spacing: 8) {
            HStack {
                Label("Textos curados cargados", systemImage: "checkmark.seal.fill")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Color.appSecondaryAccent)
                Spacer()
                Text("\(curated.count)")
                    .font(.caption.monospaced())
                    .foregroundStyle(.secondary)
            }

            VStack(spacing: 6) {
                ForEach(curated.prefix(8)) { enriched in
                    Button {
                        vm.selectedDirection = enriched
                    } label: {
                        HStack(alignment: .firstTextBaseline, spacing: 8) {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(enriched.displaySummary)
                                    .font(.caption.weight(.semibold))
                                    .foregroundStyle(.primary)
                                    .lineLimit(2)
                                Text(enriched.ageFormatted)
                                    .font(.caption.monospaced())
                                    .foregroundStyle(Color.appAccentFill)
                            }
                            Spacer()
                            Image(systemName: vm.selectedDirection?.id == enriched.id ? "arrow.right.circle.fill" : "arrow.right.circle")
                                .foregroundStyle(Color.appSecondaryAccent)
                        }
                        .padding(8)
                        .background(
                            vm.selectedDirection?.id == enriched.id
                            ? Color.appSecondaryAccent.opacity(0.12)
                            : Color.appSurface,
                            in: RoundedRectangle(cornerRadius: 6, style: .continuous)
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 6, style: .continuous)
                                .stroke(Color.appSecondaryAccent.opacity(vm.selectedDirection?.id == enriched.id ? 0.35 : 0.16), lineWidth: 1)
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
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
                speculumRows: vm.fullSpeculum,
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

    private func honestyPolicyPopover(metadata: PrimaryDirectionsMetadata) -> some View {
        let curatedCount = vm.curatedVisibleDirections.count
        let referenceMode = vm.settings.aspectPlane == .ecliptic
        let title = referenceMode && curatedCount > 0
            ? "Informe de referencia cargado"
            : "Corpus en curación manual"
        let message = if referenceMode && curatedCount > 0 {
            "\(curatedCount) textos curados de longitud zodiacal están disponibles en el rango visible. Las lecturas se muestran con fuente, referencia y calidad."
        } else if referenceMode {
            "Longitud zodiacal está activa, pero los filtros actuales no incluyen ninguna clave curada. La cobertura total del corpus es \(String(format: "%.1f", metadata.corpusCoverage))%."
        } else {
            "La Capa 1 solo muestra textos verificados y atribuidos. Cobertura actual del corpus: \(String(format: "%.1f", metadata.corpusCoverage))%."
        }

        return HStack(alignment: .top, spacing: 10) {
            Image(systemName: curatedCount > 0 ? "checkmark.seal.fill" : "books.vertical.fill")
                .foregroundStyle(curatedCount > 0 ? Color.appSecondaryAccent : Color.appAccentFill)
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.headline)
                Text(message)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer()
        }
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
                      let chart = selectableCharts.first(where: { $0.id == newValue }) else { return }
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

    private var presetSegmentedPicker: some View {
        Picker("Preset", selection: $vm.activePreset) {
            ForEach(PDFilterPreset.allCases) { preset in
                Text(preset.rawValue).tag(Optional(preset))
            }
        }
        .pickerStyle(.segmented)
        .labelsHidden()
        .frame(width: 265)
        .help("Preset de filtro")
    }

    private var minimumWeightPicker: some View {
        Picker("Peso mínimo", selection: $vm.filters.minimumWeight) {
            ForEach([PDWeight.minor, .moderate, .major, .critical], id: \.self) { weight in
                Text(weight.filterLabel).tag(weight)
            }
        }
        .pickerStyle(.menu)
        .frame(width: 132)
        .help("Peso mínimo")
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
                rowBadge(enriched.direction.aspectPlane.displayName, tone: .secondary)
                rowBadge(corpusBadgeTitle, tone: enriched.hasInterpretation ? Color.appSecondaryAccent : .secondary)
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

    private var corpusBadgeTitle: String {
        if enriched.hasInterpretation {
            return enriched.direction.aspectPlane == .ecliptic ? "Texto curado" : "Corpus"
        }
        return enriched.direction.aspectPlane == .ecliptic ? "Sin texto" : "Sin corpus"
    }

    private func rowBadge(_ text: String, tone: Color) -> some View {
        Text(text)
            .font(.caption)
            .foregroundStyle(tone)
            .padding(.horizontal, 7)
            .padding(.vertical, 3)
            .background(tone.opacity(0.08), in: Capsule())
    }
}

private struct PDSettingsSheet: View {
    @Binding var settings: PDSettings
    @Binding var activePreset: PDFilterPreset?
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Form {
                Section("Preset de filtro") {
                    Picker("Preset", selection: $activePreset) {
                        ForEach(PDFilterPreset.allCases) { preset in
                            Text(preset.rawValue).tag(Optional(preset))
                        }
                        if activePreset == nil {
                            Text("Personalizado").tag(Optional<PDFilterPreset>.none)
                        }
                    }
                    .pickerStyle(.segmented)

                    Text(presetDescription)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Section("Método de proyección") {
                    Text(PrimaryDirectionMethod.regiomontanus.rawValue)
                        .foregroundStyle(.primary)
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
                        Text("Zodiacal por espéculo").tag(PDAspectPlane.zodiacal)
                        Text("Longitud zodiacal (informe de referencia)").tag(PDAspectPlane.ecliptic)
                    }
                    .pickerStyle(.radioGroup)

                    Label("Longitud zodiacal reproduce informes simbólicos tipo ASC/MC/Sol dirigidos a planetas y cúspides por arco eclíptico. Mundano usa el espéculo Regiomontanus clásico.", systemImage: "info.circle")
                        .font(.caption)
                        .foregroundStyle(.secondary)
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

    private var presetDescription: String {
        activePreset?.settingsDescription
            ?? "Personalizado: filtros modificados manualmente. El conjunto visible puede no corresponder a un preset cerrado."
    }
}
