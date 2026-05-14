import SwiftUI

struct ProfectionsView: View {
    @EnvironmentObject var appState: AppState

    let chart: NatalChart?

    @State private var targetDate = Date()
    @State private var result: ProfectionResult?
    @State private var isLoading = false
    @State private var isCreatingNote = false
    @State private var errorMessage: String?
    @State private var statusMessage: String?
    @State private var calculationTask: Task<Void, Never>?
    @State private var noteTask: Task<Void, Never>?

    private var activationRows: [TransitEvent] {
        (result?.activations ?? []).sorted { lhs, rhs in
            if lhs.exactDate != rhs.exactDate { return lhs.exactDate < rhs.exactDate }
            if lhs.priorityBand.rank != rhs.priorityBand.rank { return lhs.priorityBand.rank > rhs.priorityBand.rank }
            if lhs.priorityScore != rhs.priorityScore { return lhs.priorityScore > rhs.priorityScore }
            return lhs.minOrb < rhs.minOrb
        }
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                if let chart {
                    controls(chart: chart)
                    Divider()
                    content(chart: chart)
                } else {
                    noChartPlaceholder
                }
            }
            .background(Color.appBackground)
            .navigationTitle("Profecciones")
        }
        .frame(minWidth: 760, minHeight: 560)
        .task(id: taskKey) {
            loadProfections()
        }
        .onDisappear {
            calculationTask?.cancel()
            noteTask?.cancel()
        }
    }

    private var taskKey: String {
        "\(chart?.id.uuidString ?? "sin-carta")-\(Self.isoDay(targetDate))"
    }

    private func controls(chart: NatalChart) -> some View {
        HStack(spacing: 12) {
            Label(chart.name.isEmpty ? "Carta activa" : chart.name, systemImage: "person.crop.circle")
                .font(.subheadline.weight(.medium))
                .foregroundColor(.appPrimaryText)

            Divider().frame(height: 20)

            DatePicker("Fecha", selection: $targetDate, displayedComponents: .date)
                .datePickerStyle(.compact)

            Spacer()

            if let statusMessage {
                Text(statusMessage)
                    .font(.caption)
                    .foregroundColor(.appSecondaryAccent)
            }

            Button {
                loadProfections(force: true)
            } label: {
                Label("Recalcular", systemImage: "arrow.clockwise")
            }
            .buttonStyle(.bordered)
            .disabled(isLoading)

            Button {
                createJoplinNote(chart: chart)
            } label: {
                Label(isCreatingNote ? "Creando…" : "Exportar a Joplin", systemImage: "square.and.pencil")
            }
            .buttonStyle(.borderedProminent)
            .tint(.appAccentFill)
            .disabled(result == nil || isLoading || isCreatingNote)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
    }

    @ViewBuilder
    private func content(chart _: NatalChart) -> some View {
        if isLoading {
            ProgressView("Calculando profecciones…")
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else if let errorMessage {
            errorView(errorMessage)
        } else if let result {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    annualCard(result.annual)
                    monthlySection(result.monthly)
                    dailySection(result.daily)
                    activationsSection(activationRows)
                }
                .padding(18)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        } else {
            VStack(spacing: 10) {
                Image(systemName: "sparkles.rectangle.stack")
                    .font(.system(size: 42))
                    .foregroundColor(.secondary)
                Text("Pulsa Recalcular para calcular la profección anual.")
                    .foregroundColor(.secondary)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    private var noChartPlaceholder: some View {
        VStack(spacing: 14) {
            Image(systemName: "person.crop.circle.badge.exclamationmark")
                .font(.system(size: 50))
                .foregroundColor(.secondary)
            Text("Selecciona una carta")
                .font(.title3.weight(.semibold))
                .foregroundColor(.appPrimaryText)
            Text("Las profecciones anuales requieren una carta natal activa para tomar cúspides, regentes y planetas natales.")
                .multilineTextAlignment(.center)
                .foregroundColor(.secondary)
                .frame(maxWidth: 520)
            Button {
                appState.selectedNav = .cartas
                appState.showDefaultDetail(for: .cartas)
            } label: {
                Label("Seleccionar carta", systemImage: "tray.full")
            }
            .buttonStyle(.borderedProminent)
            .tint(.appAccentFill)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(24)
    }

    private func annualCard(_ annual: ProfectionPeriod) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Año profeccional \(annual.age)")
                        .font(.title2.weight(.semibold))
                        .foregroundColor(.appPrimaryText)
                    Text("\(Self.displayDate(annual.startDate)) → \(Self.displayDate(annual.endDate))")
                        .font(.caption.monospacedDigit())
                        .foregroundColor(.secondary)
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 4) {
                    Text("Casa \(annual.house)")
                        .font(.title3.weight(.semibold))
                        .foregroundColor(.appAccentFill)
                    Text(annual.signLabel)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
            }

            HStack(alignment: .top, spacing: 18) {
                infoBlock("Signo profeccionado", annual.cuspFormatted)
                infoBlock("Lord of the Year", annual.lordLabel)
                infoBlock("Planetas en casa", planetSummary(annual.natalPlanetsInHouse))
            }

            if !annual.natalAspectsByLord.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Planetas natales aspectados por el LotY")
                        .font(.headline)
                    FlowLayout(spacing: 6) {
                        ForEach(annual.natalAspectsByLord) { aspect in
                            Text("\(aspect.lotyLabel) \(aspect.aspectLabel) \(aspect.planetLabel) · \(String(format: "%.1f", aspect.orb))°")
                                .font(.caption)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(Color.appChipBackground)
                                .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                        }
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .appCard()
    }

    private func monthlySection(_ periods: [ProfectionPeriod]) -> some View {
        section("Mensual", systemImage: "calendar") {
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 185), spacing: 10)], spacing: 10) {
                ForEach(periods) { period in
                    periodCard(period, title: period.sequence == periods.first?.sequence ? "Mes vigente" : "Próximo mes")
                }
            }
        }
    }

    private func dailySection(_ periods: [ProfectionPeriod]) -> some View {
        section("Diaria — semana actual", systemImage: "calendar.day.timeline.leading") {
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 150), spacing: 10)], spacing: 10) {
                ForEach(periods) { period in
                    periodCard(period, title: Self.displayDate(period.startDate))
                }
            }
        }
    }

    private func activationsSection(_ events: [TransitEvent]) -> some View {
        section("Activaciones del año", systemImage: "point.3.connected.trianglepath.dotted") {
            if events.isEmpty {
                Text("No se detectaron tránsitos del LotY a planetas natales ni aspectos al LotY natal en el año profeccional.")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(12)
                    .background(Color.appPanel)
                    .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            } else {
                Table(events) {
                    TableColumn("Fecha") { event in
                        Text(event.exactDate)
                            .font(.caption.monospacedDigit())
                    }
                    .width(90)

                    TableColumn("Activación") { event in
                        HStack(spacing: 7) {
                            Circle().fill(Color(hex: event.color)).frame(width: 8, height: 8)
                            Text("\(event.transitLabel) \(event.aspectLabel) \(event.natalLabel)")
                                .font(.subheadline)
                            if event.retrogradeOnExact {
                                Text("℞").foregroundColor(.orange).font(.caption)
                            }
                        }
                    }
                    .width(min: 220)

                    TableColumn("Prioridad") { event in
                        Text("\(event.priorityStarsDisplay) \(event.priorityLabel)")
                            .font(.caption.monospacedDigit().weight(.semibold))
                            .foregroundColor(priorityColor(event.priorityBand))
                    }
                    .width(120)

                    TableColumn("Orbe") { event in
                        Text(String(format: "%.2f°", event.minOrb))
                            .font(.caption.monospacedDigit())
                            .foregroundColor(.secondary)
                    }
                    .width(60)

                    TableColumn("Motivo") { event in
                        Text(event.compactReason)
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .lineLimit(1)
                    }
                    .width(min: 220)
                }
                .frame(minHeight: 260)
                .tableStyle(.inset(alternatesRowBackgrounds: true))
            }
        }
    }

    private func periodCard(_ period: ProfectionPeriod, title: String) -> some View {
        VStack(alignment: .leading, spacing: 7) {
            Text(title)
                .font(.caption.weight(.semibold))
                .foregroundColor(.secondary)
            Text("Casa \(period.house)")
                .font(.headline)
                .foregroundColor(.appPrimaryText)
            Text(period.signLabel)
                .font(.subheadline)
                .foregroundColor(.appAccentFill)
            Text(period.lordLabel)
                .font(.caption)
                .foregroundColor(.secondary)
            Text("\(Self.displayDate(period.startDate)) → \(Self.displayDate(period.endDate))")
                .font(.caption2.monospacedDigit())
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(Color.appPanel)
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(Color.appBorder.opacity(0.7), lineWidth: 1)
        )
    }

    private func section<Content: View>(
        _ title: String,
        systemImage: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Label(title, systemImage: systemImage)
                .appSectionHeader()
            content()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func infoBlock(_ title: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(title)
                .font(.caption2)
                .foregroundColor(.secondary)
            Text(value)
                .font(.subheadline.weight(.medium))
                .foregroundColor(.appPrimaryText)
                .lineLimit(3)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func errorView(_ message: String) -> some View {
        VStack(spacing: 8) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundColor(.orange)
                .font(.title2)
            Text(message)
                .foregroundColor(.secondary)
                .font(.subheadline)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(24)
    }

    private func loadProfections(force _: Bool = false) {
        guard let chart else { return }
        calculationTask?.cancel()
        isLoading = true
        errorMessage = nil
        statusMessage = nil
        let date = targetDate
        let store = appState.corpusStore

        calculationTask = Task {
            do {
                let engine = ProfectionEngine(corpusStore: store)
                let computed = try await engine.profections(for: chart, at: date)
                guard !Task.isCancelled else { return }
                result = computed
            } catch {
                guard !Task.isCancelled else { return }
                errorMessage = error.localizedDescription
            }
            if !Task.isCancelled {
                isLoading = false
            }
        }
    }

    private func createJoplinNote(chart: NatalChart) {
        guard let result else { return }
        noteTask?.cancel()
        isCreatingNote = true
        statusMessage = nil
        errorMessage = nil

        let settings = appState.joplinSettings
        let title = ProfectionsNoteBuilder.noteTitle(chart: chart, result: result, date: targetDate)
        let body = ProfectionsNoteBuilder.markdown(chart: chart, result: result, date: targetDate)

        noteTask = Task {
            do {
                let service = JoplinClipperService(settings: settings)
                try await service.createNote(title: title, body: body)
                guard !Task.isCancelled else { return }
                statusMessage = "Nota creada en Joplin."
            } catch {
                guard !Task.isCancelled else { return }
                errorMessage = error.localizedDescription
            }
            if !Task.isCancelled {
                isCreatingNote = false
            }
        }
    }

    private func planetSummary(_ planets: [ProfectionPlanet]) -> String {
        planets.isEmpty ? "—" : planets.map(\.label).joined(separator: ", ")
    }

    private func priorityColor(_ band: TransitPriorityBand) -> Color {
        switch band {
        case .critical: return Color(hex: "#d97706")
        case .high: return Color(hex: "#2563eb")
        case .medium: return Color(hex: "#15803d")
        case .low: return .secondary
        }
    }

    private static func displayDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "es_ES")
        formatter.timeZone = TimeZone.current
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: date)
    }

    private static func isoDay(_ date: Date) -> String {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withFullDate]
        formatter.timeZone = TimeZone.current
        return formatter.string(from: date)
    }
}

enum ProfectionsNoteBuilder {
    static func noteTitle(chart: NatalChart, result: ProfectionResult, date: Date) -> String {
        "Profección anual \(result.annual.age) — \(chart.name) — \(displayDate(date))"
    }

    static func markdown(chart: NatalChart, result: ProfectionResult, date: Date) -> String {
        var lines: [String] = [
            "# Profección anual — \(chart.name)",
            "",
            "Fecha consultada: \(displayDate(date))",
            "",
            "## Año profeccional",
            "- Edad: \(result.annual.age)",
            "- Casa activada: \(result.annual.house)",
            "- Signo profeccionado: \(result.annual.signLabel) (\(result.annual.cuspFormatted))",
            "- Lord of the Year: \(result.annual.lordLabel)",
            "- Periodo: \(displayDate(result.annual.startDate)) → \(displayDate(result.annual.endDate))",
            "- Planetas natales en la casa: \(result.annual.natalPlanetsInHouse.isEmpty ? "—" : result.annual.natalPlanetsInHouse.map(\.label).joined(separator: ", "))",
            "",
        ]

        lines.append("## Aspectos natales del LotY")
        if result.annual.natalAspectsByLord.isEmpty {
            lines.append("No se detectaron aspectos natales mayores del LotY a otros planetas.")
        } else {
            for aspect in result.annual.natalAspectsByLord {
                lines.append("- \(aspect.lotyLabel) \(aspect.aspectLabel) \(aspect.planetLabel), orbe \(String(format: "%.2f", aspect.orb))°")
            }
        }

        lines.append("")
        lines.append("## Profección mensual")
        for period in result.monthly {
            lines.append("- Casa \(period.house), \(period.signLabel), regente \(period.lordLabel): \(displayDate(period.startDate)) → \(displayDate(period.endDate))")
        }

        lines.append("")
        lines.append("## Profección diaria — semana actual")
        for period in result.daily {
            lines.append("- \(displayDate(period.startDate)): Casa \(period.house), \(period.signLabel), regente \(period.lordLabel)")
        }

        lines.append("")
        lines.append("## Activaciones del año")
        if result.activations.isEmpty {
            lines.append("No se detectaron activaciones por tránsito para el LotY en el año profeccional.")
        } else {
            for event in result.activations.sorted(by: activationSort).prefix(80) {
                lines.append("- \(event.exactDate): \(event.priorityStarsDisplay) **\(event.transitLabel) \(event.aspectLabel) \(event.natalLabel)** · prioridad \(event.priorityLabel), orbe \(String(format: "%.2f", event.minOrb))°")
                if !event.metricReasons.isEmpty {
                    lines.append("  Motivos: \(event.metricReasons.joined(separator: ", "))")
                }
                if let text = event.text, !text.isEmpty {
                    lines.append("  \(text)")
                }
            }
            if result.activations.count > 80 {
                lines.append("- … \(result.activations.count - 80) activaciones adicionales omitidas para mantener la nota legible.")
            }
        }

        lines += [
            "",
            "---",
            "*Generado por AstroMalik — \(generatedAt())*",
        ]
        return lines.joined(separator: "\n")
    }

    private static func activationSort(_ lhs: TransitEvent, _ rhs: TransitEvent) -> Bool {
        if lhs.exactDate != rhs.exactDate { return lhs.exactDate < rhs.exactDate }
        if lhs.priorityBand.rank != rhs.priorityBand.rank { return lhs.priorityBand.rank > rhs.priorityBand.rank }
        if lhs.priorityScore != rhs.priorityScore { return lhs.priorityScore > rhs.priorityScore }
        return lhs.minOrb < rhs.minOrb
    }

    private static func displayDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "es_ES")
        formatter.timeZone = TimeZone.current
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: date)
    }

    private static func generatedAt() -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "es_ES")
        formatter.timeZone = TimeZone.current
        formatter.dateFormat = "yyyy-MM-dd HH:mm"
        return formatter.string(from: Date())
    }
}

private struct FlowLayout: Layout {
    var spacing: CGFloat = 6

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let maxWidth = proposal.width ?? 420
        var x: CGFloat = 0
        var y: CGFloat = 0
        var lineHeight: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x > 0 && x + size.width > maxWidth {
                x = 0
                y += lineHeight + spacing
                lineHeight = 0
            }
            x += size.width + spacing
            lineHeight = max(lineHeight, size.height)
        }
        return CGSize(width: maxWidth, height: y + lineHeight)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var x = bounds.minX
        var y = bounds.minY
        var lineHeight: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x > bounds.minX && x + size.width > bounds.maxX {
                x = bounds.minX
                y += lineHeight + spacing
                lineHeight = 0
            }
            subview.place(at: CGPoint(x: x, y: y), proposal: ProposedViewSize(size))
            x += size.width + spacing
            lineHeight = max(lineHeight, size.height)
        }
    }
}
