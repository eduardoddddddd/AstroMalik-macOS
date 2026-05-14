import SwiftUI

struct ZRView: View {
    @EnvironmentObject var appState: AppState

    let chart: NatalChart?

    @State private var selectedLot: ZRLot = .fortune
    @State private var targetDate = Date()
    @State private var isCreatingNote = false
    @State private var statusMessage: String?
    @State private var errorMessage: String?
    @State private var noteTask: Task<Void, Never>?

    private let engine = ZodiacalReleasingEngine()

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
            .navigationTitle("Zodiacal Releasing")
        }
        .frame(minWidth: 820, minHeight: 600)
        .onDisappear { noteTask?.cancel() }
    }

    private func controls(chart: NatalChart) -> some View {
        HStack(spacing: 12) {
            Label(chart.name.isEmpty ? "Carta activa" : chart.name, systemImage: "person.crop.circle")
                .font(.subheadline.weight(.medium))
                .foregroundColor(.appPrimaryText)

            Divider().frame(height: 20)

            Picker("Lote", selection: $selectedLot) {
                ForEach(ZRLot.allCases) { lot in
                    Text(lot.label).tag(lot)
                }
            }
            .pickerStyle(.segmented)
            .frame(maxWidth: 260)

            DatePicker("Fecha", selection: $targetDate, displayedComponents: .date)
                .datePickerStyle(.compact)

            Spacer()

            if let statusMessage {
                Text(statusMessage)
                    .font(.caption)
                    .foregroundColor(.appSecondaryAccent)
            }

            Button {
                createJoplinNote(chart: chart)
            } label: {
                Label(isCreatingNote ? "Creando…" : "Exportar a Joplin", systemImage: "square.and.pencil")
            }
            .buttonStyle(.borderedProminent)
            .tint(.appAccentFill)
            .disabled(isCreatingNote)

            PDFExportButton(
                chartName: chart.name.isEmpty ? "Carta natal" : chart.name,
                reportType: "Zodiacal Releasing",
                generate: { pageSize in
                    let data = ZodiacalReleasingLongReportBuilder.build(chart: chart, asOf: targetDate)
                    return try await ReportService().generate(request: ZodiacalReleasingLongReportBuilder.makeRequest(data: data).withPageSize(pageSize))
                }
            )
            .environmentObject(appState)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
    }

    private func content(chart: NatalChart) -> some View {
        let timeline = engine.zr(chart: chart, lot: selectedLot, depth: 2)
        let effectiveDate = maxDate(targetDate, timeline.birthDate)
        let currentL1 = timeline.currentL1(at: effectiveDate)
        let currentL2 = timeline.currentL2(at: effectiveDate)
        let nextEvents = timeline.upcomingHighlightedEvents(after: effectiveDate, limit: 5)

        return ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                if let errorMessage {
                    Text(errorMessage)
                        .font(.caption)
                        .foregroundColor(.appWarning)
                        .padding(10)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color.appWarning.opacity(0.12))
                        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                }

                header(timeline: timeline, chart: chart, currentL1: currentL1, currentL2: currentL2, effectiveDate: effectiveDate)
                upcomingEventsSection(nextEvents, chart: chart)
                timelineSection(timeline: timeline, currentL1: currentL1, currentL2: currentL2, chart: chart)
            }
            .padding(18)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private var noChartPlaceholder: some View {
        VStack(spacing: 14) {
            Image(systemName: "arrow.triangle.branch")
                .font(.system(size: 50))
                .foregroundColor(.secondary)
            Text("Selecciona una carta")
                .font(.title3.weight(.semibold))
                .foregroundColor(.appPrimaryText)
            Text("Zodiacal Releasing requiere una carta natal con Sol, Luna, Ascendente y secta para calcular Fortuna y Espíritu.")
                .multilineTextAlignment(.center)
                .foregroundColor(.secondary)
                .frame(maxWidth: 560)
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

    private func header(
        timeline: ZRTimeline,
        chart: NatalChart,
        currentL1: ZRPeriod?,
        currentL2: ZRPeriod?,
        effectiveDate: Date
    ) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top, spacing: 12) {
                VStack(alignment: .leading, spacing: 5) {
                    Label("\(timeline.lot.noteLabel): \(timeline.lotPoint.formatted)", systemImage: "point.topleft.down.curvedto.point.bottomright.up")
                        .font(.title2.weight(.semibold))
                        .foregroundColor(.appPrimaryText)
                    Text("Secta: \(timeline.sect.label) · signo inicial \(timeline.lotPoint.signLabel)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 4) {
                    Text(displayDate(effectiveDate, chart: chart))
                        .font(.subheadline.monospacedDigit().weight(.medium))
                        .foregroundColor(.appPrimaryText)
                    Text("Fecha consultada")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }

            LazyVGrid(columns: [GridItem(.adaptive(minimum: 220), spacing: 10)], spacing: 10) {
                currentTile(title: "Capítulo L1 actual", period: currentL1, chart: chart, effectiveDate: effectiveDate)
                currentTile(title: "Sub-período L2 actual", period: currentL2, chart: chart, effectiveDate: effectiveDate)
                infoTile("Duración restante", value: remainingText(for: currentL2 ?? currentL1, from: effectiveDate, chart: chart))
                infoTile("Regla LB", value: "Cáncer/Capricornio saltan al opuesto del inicio L1")
            }
        }
        .appCard()
    }

    private func currentTile(title: String, period: ZRPeriod?, chart: NatalChart, effectiveDate: Date) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(title)
                .font(.caption2)
                .foregroundColor(.secondary)
            if let period {
                HStack(spacing: 6) {
                    Text(period.signLabel)
                        .font(.headline)
                        .foregroundColor(.appPrimaryText)
                    periodBadges(period)
                }
                Text("\(displayDate(period.startDate, chart: chart)) → \(displayDate(period.endDate, chart: chart))")
                    .font(.caption.monospacedDigit())
                    .foregroundColor(.secondary)
                Text(remainingText(for: period, from: effectiveDate, chart: chart))
                    .font(.caption)
                    .foregroundColor(.appSecondaryAccent)
            } else {
                Text("Fuera del rango calculado")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(10)
        .background(Color.appSurface)
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
    }

    private func infoTile(_ title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(title)
                .font(.caption2)
                .foregroundColor(.secondary)
            Text(value)
                .font(.subheadline.weight(.medium))
                .foregroundColor(.appPrimaryText)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(10)
        .background(Color.appSurface)
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
    }

    private func upcomingEventsSection(_ events: [ZREvent], chart: NatalChart) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Label("Próximos 5 eventos destacados", systemImage: "sparkles")
                .appSectionHeader()
            if events.isEmpty {
                Text("No hay próximos cambios L1, LB o peaks dentro del rango calculado.")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            } else {
                ForEach(events) { event in
                    HStack(alignment: .top, spacing: 10) {
                        eventBadge(event.kind)
                        VStack(alignment: .leading, spacing: 3) {
                            Text(event.title)
                                .font(.subheadline.weight(.medium))
                                .foregroundColor(.appPrimaryText)
                            Text("\(displayDateTime(event.date, chart: chart)) · \(event.detail)")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        Spacer()
                    }
                    .padding(10)
                    .background(Color.appSurface)
                    .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                }
            }
        }
        .appCard()
    }

    private func timelineSection(timeline: ZRTimeline, currentL1: ZRPeriod?, currentL2: ZRPeriod?, chart: NatalChart) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Label("Cronología L1 → L2", systemImage: "list.bullet.indent")
                    .appSectionHeader()
                Spacer()
                Text("Profundidad UI: L1 + L2")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            VStack(spacing: 8) {
                ForEach(timeline.periods) { l1 in
                    DisclosureGroup {
                        VStack(spacing: 6) {
                            ForEach(l1.children) { l2 in
                                periodRow(l2, currentID: currentL2?.id, chart: chart, indent: 18)
                            }
                        }
                        .padding(.top, 8)
                    } label: {
                        periodRow(l1, currentID: currentL1?.id, chart: chart, indent: 0)
                    }
                    .padding(12)
                    .background(Color.appSurface)
                    .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                }
            }
        }
        .appCard()
    }

    private func periodRow(_ period: ZRPeriod, currentID: String?, chart: NatalChart, indent: CGFloat) -> some View {
        HStack(alignment: .center, spacing: 10) {
            Text(period.level.label)
                .font(.caption.weight(.bold))
                .foregroundColor(.appAccentForeground)
                .padding(.horizontal, 6)
                .padding(.vertical, 3)
                .background(Color.appAccentFill)
                .clipShape(Capsule())
                .padding(.leading, indent)

            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 6) {
                    Text(period.signLabel)
                        .font(period.level == .l1 ? .headline : .subheadline.weight(.medium))
                        .foregroundColor(.appPrimaryText)
                    if period.id == currentID {
                        smallBadge("ACTUAL", color: .appSecondaryAccent)
                    }
                    periodBadges(period)
                }
                Text("\(displayDateTime(period.startDate, chart: chart)) → \(displayDateTime(period.endDate, chart: chart)) · \(nominalText(period))")
                    .font(.caption.monospacedDigit())
                    .foregroundColor(.secondary)
            }
            Spacer()
        }
        .padding(period.level == .l1 ? 0 : 8)
        .background(period.level == .l2 && period.id == currentID ? Color.appSecondaryAccent.opacity(0.10) : Color.clear)
        .clipShape(RoundedRectangle(cornerRadius: 7, style: .continuous))
    }

    @ViewBuilder
    private func periodBadges(_ period: ZRPeriod) -> some View {
        if period.isPeak {
            smallBadge("PEAK", color: .appAccentFill)
        }
        if let angularity = period.angularity {
            smallBadge(angularity.badge, color: angularity == .angular ? .appSecondaryAccent : .secondary)
        }
        if period.hasLoosingOfBond {
            smallBadge("LB", color: .appWarning)
        }
    }

    private func smallBadge(_ text: String, color: Color) -> some View {
        Text(text)
            .font(.caption2.weight(.bold))
            .foregroundColor(color)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(color.opacity(0.14))
            .clipShape(Capsule())
    }

    private func eventBadge(_ kind: ZREventKind) -> some View {
        let color: Color
        switch kind {
        case .levelOneChange:
            color = .appAccentFill
        case .loosingOfBond:
            color = .appWarning
        case .peak:
            color = .appSecondaryAccent
        }
        return Text(kind == .loosingOfBond ? "LB" : (kind == .peak ? "PEAK" : "L1"))
            .font(.caption2.weight(.bold))
            .foregroundColor(color)
            .padding(.horizontal, 7)
            .padding(.vertical, 4)
            .background(color.opacity(0.14))
            .clipShape(Capsule())
    }

    private func createJoplinNote(chart: NatalChart) {
        noteTask?.cancel()
        isCreatingNote = true
        statusMessage = nil
        errorMessage = nil

        let settings = appState.joplinSettings
        let timeline = engine.zr(chart: chart, lot: selectedLot, depth: 2)
        let effectiveDate = maxDate(targetDate, timeline.birthDate)
        let title = ZRNoteBuilder.noteTitle(chart: chart, timeline: timeline, date: effectiveDate)
        let body = ZRNoteBuilder.markdown(chart: chart, timeline: timeline, date: effectiveDate)

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

    private func nominalText(_ period: ZRPeriod) -> String {
        let value = period.nominalUnits.rounded(.towardZero) == period.nominalUnits
            ? String(format: "%.0f", period.nominalUnits)
            : String(format: "%.2f", period.nominalUnits)
        return "\(value) \(period.unitLabel)"
    }

    private func remainingText(for period: ZRPeriod?, from date: Date, chart: NatalChart) -> String {
        guard let period else { return "—" }
        guard date < period.endDate else { return "Finalizado" }
        let start = maxDate(date, period.startDate)
        let components = calendar(for: chart).dateComponents([.year, .month, .day, .hour], from: start, to: period.endDate)
        var chunks: [String] = []
        if let year = components.year, year > 0 { chunks.append("\(year)a") }
        if let month = components.month, month > 0 { chunks.append("\(month)m") }
        if let day = components.day, day > 0 { chunks.append("\(day)d") }
        if chunks.isEmpty, let hour = components.hour, hour > 0 { chunks.append("\(hour)h") }
        return chunks.isEmpty ? "Menos de 1 hora" : chunks.prefix(3).joined(separator: " ")
    }

    private func maxDate(_ lhs: Date, _ rhs: Date) -> Date {
        lhs >= rhs ? lhs : rhs
    }

    private func calendar(for chart: NatalChart) -> Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: chart.timezone) ?? TimeZone.current
        return calendar
    }

    private func displayDate(_ date: Date, chart: NatalChart) -> String {
        formatter(chart: chart, format: "yyyy-MM-dd").string(from: date)
    }

    private func displayDateTime(_ date: Date, chart: NatalChart) -> String {
        formatter(chart: chart, format: "yyyy-MM-dd HH:mm").string(from: date)
    }

    private func formatter(chart: NatalChart, format: String) -> DateFormatter {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "es_ES")
        formatter.timeZone = TimeZone(identifier: chart.timezone) ?? TimeZone.current
        formatter.dateFormat = format
        return formatter
    }
}

enum ZRNoteBuilder {
    static func noteTitle(chart: NatalChart, timeline: ZRTimeline, date: Date) -> String {
        "Zodiacal Releasing \(timeline.lot.label) — \(chart.name) — \(displayDate(date, chart: chart))"
    }

    static func markdown(chart: NatalChart, timeline: ZRTimeline, date: Date) -> String {
        let effectiveDate = max(date, timeline.birthDate)
        let currentL1 = timeline.currentL1(at: effectiveDate)
        let currentL2 = timeline.currentL2(at: effectiveDate)
        let nextEvents = timeline.upcomingHighlightedEvents(after: effectiveDate, limit: 5)
        var lines: [String] = [
            "# Zodiacal Releasing — \(timeline.lot.noteLabel) — \(chart.name)",
            "",
            "Consulta de Zodiacal Releasing según la especificación de períodos de Valens usada por AstroMalik.",
            "",
            "## Lote y secta",
            "- Lote: \(timeline.lot.noteLabel)",
            "- Posición: \(timeline.lotPoint.formatted) (\(timeline.lotPoint.signLabel))",
            "- Secta: \(timeline.sect.label)",
            "- Fecha consultada: \(displayDate(effectiveDate, chart: chart))",
            "",
            "## Períodos actuales",
        ]

        if let currentL1 {
            lines.append("- L1: \(currentL1.signLabel), \(displayDateTime(currentL1.startDate, chart: chart)) → \(displayDateTime(currentL1.endDate, chart: chart))")
        } else {
            lines.append("- L1: fuera del rango calculado")
        }
        if let currentL2 {
            let badges = badgeSummary(currentL2)
            lines.append("- L2: \(currentL2.signLabel), \(displayDateTime(currentL2.startDate, chart: chart)) → \(displayDateTime(currentL2.endDate, chart: chart))\(badges.isEmpty ? "" : " · \(badges)")")
        } else {
            lines.append("- L2: fuera del rango calculado")
        }

        lines += ["", "## Próximos eventos destacados"]
        if nextEvents.isEmpty {
            lines.append("No hay próximos cambios L1, LB o peaks dentro del rango calculado.")
        } else {
            for event in nextEvents {
                lines.append("- \(displayDateTime(event.date, chart: chart)): **\(event.kind.label)** — \(event.title). \(event.detail)")
            }
        }

        lines += ["", "## Timeline L1 → L2"]
        for l1 in timeline.periods {
            lines.append("- **L1 \(l1.signLabel)**: \(displayDateTime(l1.startDate, chart: chart)) → \(displayDateTime(l1.endDate, chart: chart)) (\(Int(l1.nominalUnits)) años)")
            for l2 in l1.children {
                let badges = badgeSummary(l2)
                lines.append("  - L2 \(l2.signLabel): \(displayDateTime(l2.startDate, chart: chart)) → \(displayDateTime(l2.endDate, chart: chart))\(badges.isEmpty ? "" : " · \(badges)")")
            }
        }

        lines += [
            "",
            "---",
            "*Generado por AstroMalik — \(generatedAt(chart: chart))*",
        ]
        return lines.joined(separator: "\n")
    }

    private static func badgeSummary(_ period: ZRPeriod) -> String {
        var badges: [String] = []
        if period.isPeak { badges.append("PEAK") }
        if let angularity = period.angularity { badges.append(angularity.badge) }
        if period.hasLoosingOfBond { badges.append("LB") }
        return badges.joined(separator: ", ")
    }

    private static func displayDate(_ date: Date, chart: NatalChart) -> String {
        formatter(chart: chart, format: "yyyy-MM-dd").string(from: date)
    }

    private static func displayDateTime(_ date: Date, chart: NatalChart) -> String {
        formatter(chart: chart, format: "yyyy-MM-dd HH:mm").string(from: date)
    }

    private static func generatedAt(chart: NatalChart) -> String {
        formatter(chart: chart, format: "yyyy-MM-dd HH:mm").string(from: Date())
    }

    private static func formatter(chart: NatalChart, format: String) -> DateFormatter {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "es_ES")
        formatter.timeZone = TimeZone(identifier: chart.timezone) ?? TimeZone.current
        formatter.dateFormat = format
        return formatter
    }
}
