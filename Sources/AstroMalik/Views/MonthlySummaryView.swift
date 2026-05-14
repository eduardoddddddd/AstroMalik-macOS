import SwiftUI

struct MonthlySummaryView: View {
    @EnvironmentObject var appState: AppState

    let ephemeris: EphemerisMonth
    let monthTitle: String

    @State private var selectedChartID: UUID?
    @State private var summary: MonthlySummary?
    @State private var cacheKey: String?
    @State private var isLoading = false
    @State private var isCreatingNote = false
    @State private var errorMessage: String?
    @State private var statusMessage: String?
    @State private var summaryTask: Task<Void, Never>?
    @State private var noteTask: Task<Void, Never>?

    private var charts: [NatalChart] {
        var seen = Set<UUID>()
        var result: [NatalChart] = []
        if let active = appState.activeNatalChart, seen.insert(active.id).inserted {
            result.append(active)
        }
        for chart in appState.userStore.savedCharts where seen.insert(chart.id).inserted {
            result.append(chart)
        }
        return result
    }

    private var selectedChart: NatalChart? {
        if let selectedChartID,
           let chart = charts.first(where: { $0.id == selectedChartID }) {
            return chart
        }
        return appState.activeNatalChart ?? charts.first
    }

    private var currentCacheKey: String {
        "\(ephemeris.id)-\(selectedChart?.id.uuidString ?? "sin-carta")"
    }

    var body: some View {
        VStack(spacing: 0) {
            if charts.isEmpty {
                noChartPlaceholder
            } else {
                controls
                Divider()
                content
            }
        }
        .background(Color.appBackground)
        .onAppear {
            ensureSelectedChart()
            loadSummaryIfNeeded(force: false)
        }
        .onChange(of: selectedChartID) { _, _ in
            loadSummaryIfNeeded(force: true)
        }
        .onChange(of: ephemeris.id) { _, _ in
            loadSummaryIfNeeded(force: true)
        }
        .onDisappear {
            summaryTask?.cancel()
            noteTask?.cancel()
        }
    }

    private var controls: some View {
        HStack(spacing: 12) {
            if charts.count > 1 {
                Text("Carta")
                    .font(.caption)
                    .foregroundColor(.secondary)
                Picker("Carta", selection: $selectedChartID) {
                    ForEach(charts) { chart in
                        Text(chart.name).tag(Optional(chart.id))
                    }
                }
                .frame(width: 240)
            } else if let selectedChart {
                Label(selectedChart.name, systemImage: "person.crop.circle")
                    .font(.subheadline)
                    .foregroundColor(.appPrimaryText)
            }

            Spacer()

            if let statusMessage {
                Text(statusMessage)
                    .font(.caption)
                    .foregroundColor(.appSecondaryAccent)
            }

            Button {
                loadSummaryIfNeeded(force: true)
            } label: {
                Label("Recalcular", systemImage: "arrow.clockwise")
            }
            .buttonStyle(.bordered)
            .disabled(isLoading)

            Button {
                if let summary { createJoplinNote(summary) }
            } label: {
                Label(isCreatingNote ? "Creando…" : "Joplin", systemImage: "square.and.pencil")
            }
            .buttonStyle(.borderedProminent)
            .disabled(summary == nil || isCreatingNote)

            PDFExportButton(
                chartName: selectedChart?.name.isEmpty == false ? selectedChart?.name ?? "Carta natal" : "Carta natal",
                reportType: "Resumen mensual \(monthTitle)",
                disabled: summary == nil || selectedChart == nil || isLoading,
                generate: { pageSize in
                    guard let summary, let selectedChart else {
                        throw PDFReportExportViewError.missingData("No hay resumen mensual personalizado calculado.")
                    }
                    let request = MonthlySummaryReportBuilder.makeRequest(summary: summary, natalChart: selectedChart)
                    return try await ReportService().generate(request: request.withPageSize(pageSize))
                }
            )
            .environmentObject(appState)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
    }

    @ViewBuilder
    private var content: some View {
        if isLoading {
            ProgressView("Calculando resumen predictivo…")
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else if let errorMessage {
            errorView(errorMessage)
        } else if let summary {
            summaryScroll(summary)
        } else {
            VStack(spacing: 10) {
                Image(systemName: "sparkles.rectangle.stack")
                    .font(.system(size: 42))
                    .foregroundColor(.secondary)
                Text("Pulsa Recalcular para generar el resumen personalizado.")
                    .foregroundColor(.secondary)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    private var noChartPlaceholder: some View {
        VStack(spacing: 14) {
            Image(systemName: "person.crop.circle.badge.exclamationmark")
                .font(.system(size: 48))
                .foregroundColor(.secondary)
            Text("Resumen predictivo personalizado")
                .font(.title3.weight(.semibold))
            Text("Guarda o activa una carta natal para cruzar lunaciones, eclipses, estaciones y tránsitos con casas y planetas natales.")
                .multilineTextAlignment(.center)
                .foregroundColor(.secondary)
                .frame(maxWidth: 520)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(24)
    }

    private func summaryScroll(_ summary: MonthlySummary) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                header(summary)
                climateCard(summary)
                lunationsSection(summary.lunationHits)
                eclipsesSection(summary.eclipseHits)
                stationsSection(summary.stationHits)
                transitsSection(summary.activeTransits)
                ingressesSection(summary.houseIngresses)
            }
            .padding(18)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private func header(_ summary: MonthlySummary) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Resumen predictivo — \(monthTitle)")
                .font(.title2.weight(.semibold))
                .foregroundColor(.appPrimaryText)
            Text("Para \(summary.chartName)")
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
    }

    private func climateCard(_ summary: MonthlySummary) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: "thermometer.medium")
                .font(.title2)
                .foregroundColor(climateColor(summary))
            VStack(alignment: .leading, spacing: 6) {
                Text("Clima general del mes")
                    .appSectionHeader()
                Text(summary.climateSummary)
                    .font(.body)
                    .lineSpacing(4)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .appCard()
        .background(climateColor(summary).opacity(0.06))
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
    }

    private func lunationsSection(_ hits: [LunationNatalHit]) -> some View {
        section("Lunaciones del mes", systemImage: "moonphase.new.moon") {
            if hits.isEmpty {
                emptySectionText("No se detectaron lunaciones principales en el mes.")
            } else {
                ForEach(hits) { hit in
                    eventCard(icon: hit.event.kind == .newMoon ? "🌑" : "🌕", title: hit.event.title, subtitle: "Casa natal \(hit.natalHouse) · \(hit.event.dateLocal)") {
                        Text(hit.narrative).font(.body).lineSpacing(4)
                        if let conjunction = hit.conjunctPlanet {
                            badge("\(conjunction.planetLabel) · \(String(format: "%.1f", conjunction.orb))°")
                        }
                    }
                }
            }
        }
    }

    private func eclipsesSection(_ hits: [EclipseNatalHit]) -> some View {
        guard !hits.isEmpty else { return AnyView(EmptyView()) }
        return AnyView(section("Eclipses", systemImage: "circle.lefthalf.filled") {
            ForEach(hits) { hit in
                eventCard(icon: hit.event.kind == .solarEclipse ? "🌞" : "🌚", title: hit.event.title, subtitle: "Casa natal \(hit.natalHouse) · \(hit.event.dateLocal)") {
                    Text(hit.narrative).font(.body).lineSpacing(4)
                    HStack(spacing: 6) {
                        if hit.isAngular { badge("Eje angular") }
                        ForEach(hit.conjunctPlanets, id: \.self) { conjunction in
                            badge("\(conjunction.planetLabel) · \(String(format: "%.1f", conjunction.orb))°")
                        }
                    }
                }
            }
        })
    }

    private func stationsSection(_ hits: [StationNatalHit]) -> some View {
        guard !hits.isEmpty else { return AnyView(EmptyView()) }
        return AnyView(section("Estaciones planetarias sobre tu carta", systemImage: "scope") {
            ForEach(hits) { hit in
                eventCard(icon: "🪐", title: hit.event.title, subtitle: "\(hit.natalPlanetLabel) natal · casa \(hit.natalHouse) · \(hit.event.dateLocal)") {
                    Text(hit.narrative).font(.body).lineSpacing(4)
                    badge("Orbe \(String(format: "%.1f", hit.orb))°")
                }
            }
        })
    }

    private func transitsSection(_ transits: [TransitEvent]) -> some View {
        section("Tránsitos activos este mes", systemImage: "point.3.connected.trianglepath.dotted") {
            if transits.isEmpty {
                emptySectionText("No hay tránsitos activos destacados en el resumen mensual.")
            } else {
                ForEach(transits) { transit in
                    eventCard(icon: "", title: "\(transit.transitLabel) \(transit.aspectLabel) \(transit.natalLabel)", subtitle: "\(transit.fromDate) → \(transit.toDate)") {
                        HStack(spacing: 8) {
                            Circle().fill(Color(hex: transit.color)).frame(width: 8, height: 8)
                            Text("\(transit.priorityStarsDisplay) \(transit.priorityLabel) · \(String(format: "%.1f", transit.priorityScore))")
                                .font(.caption.monospacedDigit().weight(.semibold))
                                .foregroundColor(priorityColor(transit.priorityBand))
                            if transit.retrogradeOnExact {
                                Text("℞").foregroundColor(.orange).font(.caption)
                            }
                        }
                        if !transit.compactReason.isEmpty {
                            Text(transit.compactReason)
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        if let text = transit.text, !text.isEmpty {
                            Text(text)
                                .font(.body)
                                .lineLimit(5)
                                .lineSpacing(4)
                        }
                    }
                }
            }
        }
    }

    private func ingressesSection(_ ingresses: [TransitHouseIngress]) -> some View {
        section("Ingresos por casa natal", systemImage: "arrow.right.circle") {
            if ingresses.isEmpty {
                emptySectionText("No hay ingresos por casa natal de planetas lentos en este mes.")
            } else {
                ForEach(ingresses) { ingress in
                    eventCard(icon: "", title: "\(ingress.transitLabel) ingresa en casa \(ingress.house)", subtitle: "\(ingress.date) · desde casa \(ingress.fromHouse)") {
                        Text(String(repeating: "★", count: ingress.stars))
                            .font(.caption.monospacedDigit())
                            .foregroundColor(starColor(ingress.stars))
                        if let text = ingress.text, !text.isEmpty {
                            Text(text)
                                .font(.body)
                                .lineLimit(5)
                                .lineSpacing(4)
                        }
                    }
                }
            }
        }
    }

    private func section<Content: View>(
        _ title: String,
        systemImage: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Label(title, systemImage: systemImage)
                .appSectionHeader()
            VStack(alignment: .leading, spacing: 10) {
                content()
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func eventCard<Content: View>(
        icon: String,
        title: String,
        subtitle: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        HStack(alignment: .top, spacing: 10) {
            if !icon.isEmpty {
                Text(icon).font(.title3)
            }
            VStack(alignment: .leading, spacing: 6) {
                Text(title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundColor(.appPrimaryText)
                Text(subtitle)
                    .font(.caption.monospacedDigit())
                    .foregroundColor(.secondary)
                content()
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .appCard(padding: 12)
    }

    private func badge(_ text: String) -> some View {
        Text(text)
            .font(.caption.weight(.medium))
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(Color.appChipBackground)
            .clipShape(RoundedRectangle(cornerRadius: 7, style: .continuous))
    }

    private func emptySectionText(_ text: String) -> some View {
        Text(text)
            .font(.subheadline)
            .foregroundColor(.secondary)
            .appCard(padding: 12)
    }

    private func errorView(_ message: String) -> some View {
        VStack(spacing: 12) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 42))
                .foregroundColor(.appWarning)
            Text(message)
                .multilineTextAlignment(.center)
                .foregroundColor(.secondary)
            Button("Reintentar") { loadSummaryIfNeeded(force: true) }
                .buttonStyle(.borderedProminent)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
    }

    private func ensureSelectedChart() {
        if let selectedChartID, charts.contains(where: { $0.id == selectedChartID }) {
            return
        }
        selectedChartID = (appState.activeNatalChart ?? charts.first)?.id
    }

    private func loadSummaryIfNeeded(force: Bool) {
        ensureSelectedChart()
        guard let chart = selectedChart else { return }
        let key = currentCacheKey
        if !force, cacheKey == key, summary != nil { return }

        summaryTask?.cancel()
        isLoading = true
        errorMessage = nil
        statusMessage = nil
        let ephemeris = ephemeris
        let store = appState.corpusStore

        summaryTask = Task {
            do {
                guard let bounds = MonthlySummaryEngine.monthBounds(year: ephemeris.year, month: ephemeris.month) else {
                    throw TransitError.dateCalculationFailed
                }
                let transits = try await computeTransitPeriod(
                    natalChart: chart,
                    fromDate: bounds.start,
                    toDate: bounds.end,
                    timezone: chart.timezone,
                    excludeMoon: true,
                    corpusStore: store
                )
                let ingresses = try detectHouseIngresses(
                    natalChart: chart,
                    fromDate: bounds.start,
                    toDate: bounds.end,
                    excludeMoon: true,
                    corpusStore: store
                )
                guard !Task.isCancelled else { return }
                summary = MonthlySummaryEngine.generateSummary(
                    ephemeris: ephemeris,
                    natalChart: chart,
                    transits: transits,
                    ingresses: ingresses
                )
                cacheKey = key
            } catch is CancellationError {
                if !Task.isCancelled { errorMessage = "Cálculo de resumen cancelado." }
            } catch {
                guard !Task.isCancelled else { return }
                errorMessage = error.localizedDescription
            }
            if !Task.isCancelled { isLoading = false }
        }
    }

    private func createJoplinNote(_ summary: MonthlySummary) {
        noteTask?.cancel()
        isCreatingNote = true
        statusMessage = nil
        errorMessage = nil
        let settings = appState.joplinSettings
        let title = "Resumen Predictivo — \(monthTitle) — \(summary.chartName)"
        let body = MonthlySummaryNoteBuilder.markdown(summary: summary, monthTitle: monthTitle)
        noteTask = Task {
            do {
                let service = JoplinClipperService(settings: settings)
                try await service.createNote(title: title, body: body)
                guard !Task.isCancelled else { return }
                statusMessage = "Resumen creado en Joplin."
            } catch {
                guard !Task.isCancelled else { return }
                errorMessage = error.localizedDescription
            }
            if !Task.isCancelled { isCreatingNote = false }
        }
    }

    private func climateColor(_ summary: MonthlySummary) -> Color {
        if !summary.eclipseHits.isEmpty || summary.activeTransits.contains(where: { $0.priorityBand == .critical }) {
            return Color(hex: "#d97706")
        }
        if !summary.stationHits.isEmpty || summary.activeTransits.contains(where: { $0.priorityBand == .high }) {
            return Color(hex: "#2563eb")
        }
        return Color.appSecondaryAccent
    }

    private func starColor(_ stars: Int) -> Color {
        switch stars {
        case 5: return Color(hex: "#d97706")
        case 4: return Color(hex: "#2563eb")
        case 3: return Color(hex: "#15803d")
        default: return .secondary
        }
    }

    private func priorityColor(_ band: TransitPriorityBand) -> Color {
        switch band {
        case .critical: return Color(hex: "#d97706")
        case .high: return Color(hex: "#2563eb")
        case .medium: return Color(hex: "#15803d")
        case .low: return .secondary
        }
    }
}
