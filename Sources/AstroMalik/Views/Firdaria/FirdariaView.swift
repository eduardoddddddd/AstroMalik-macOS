import SwiftUI

struct FirdariaView: View {
    @EnvironmentObject var appState: AppState

    let chart: NatalChart?

    @State private var targetDate = Date()
    @State private var isCreatingNote = false
    @State private var statusMessage: String?
    @State private var errorMessage: String?
    @State private var noteTask: Task<Void, Never>?

    private let engine = FirdariaEngine()

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
            .navigationTitle("Firdaria")
        }
        .frame(minWidth: 780, minHeight: 560)
        .onDisappear { noteTask?.cancel() }
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
                createJoplinNote(chart: chart)
            } label: {
                Label(isCreatingNote ? "Creando…" : "Exportar a Joplin", systemImage: "square.and.pencil")
            }
            .buttonStyle(.borderedProminent)
            .tint(.appAccentFill)
            .disabled(isCreatingNote)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
    }

    private func content(chart: NatalChart) -> some View {
        let timeline = engine.firdariaPeriods(chart: chart)
        let current = engine.currentFirdaria(chart: chart, at: targetDate)
        let nextChanges = engine.upcomingMinorChanges(chart: chart, at: targetDate, limit: 5)
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

                sectHeader(timeline.sect)
                currentMajorCard(current.major)
                currentMinorCard(current.minor, major: current.major)
                timelineSection(timeline: timeline, currentMajor: current.major)
                upcomingSection(nextChanges)
            }
            .padding(18)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private var noChartPlaceholder: some View {
        VStack(spacing: 14) {
            Image(systemName: "hourglass.badge.plus")
                .font(.system(size: 50))
                .foregroundColor(.secondary)
            Text("Selecciona una carta")
                .font(.title3.weight(.semibold))
                .foregroundColor(.appPrimaryText)
            Text("La Firdaria persa requiere la fecha natal y la secta de la carta para ordenar los períodos.")
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

    private func sectHeader(_ sect: SectInfo) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 10) {
                Image(systemName: sect.iconSystemName)
                    .font(.title2)
                    .foregroundColor(sect.isDiurnal ? Color(hex: "#F59E0B") : Color(hex: "#60A5FA"))
                VStack(alignment: .leading, spacing: 2) {
                    Text("Carta \(sect.label.lowercased())")
                        .font(.title2.weight(.semibold))
                        .foregroundColor(.appPrimaryText)
                    Text("Secta calculada por la casa del Sol: casas 7–12 diurna, casas 1–6 nocturna.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                Spacer()
            }

            LazyVGrid(columns: [GridItem(.adaptive(minimum: 160), spacing: 10)], spacing: 10) {
                sectChip("Luminaria", sect.luminary)
                sectChip("Benéfico de secta", sect.benefic)
                sectChip("Maléfico de secta", sect.malefic)
                sectChip("Benéfico contra secta", sect.contrarySectBenefic)
                sectChip("Maléfico contra secta", sect.contrarySectMalefic)
            }
        }
        .appCard()
    }

    private func sectChip(_ title: String, _ planet: AstroPlanetKey) -> some View {
        HStack(spacing: 8) {
            Text(planet.symbol)
                .font(.title3)
                .foregroundColor(Color(hex: planet.colorHex))
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.caption2)
                    .foregroundColor(.secondary)
                Text(planet.shortLabel)
                    .font(.subheadline.weight(.medium))
                    .foregroundColor(.appPrimaryText)
            }
            Spacer(minLength: 0)
        }
        .padding(10)
        .background(Color.appSurface)
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
    }

    private func currentMajorCard(_ period: FirdariaPeriod) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Label("Período mayor actual", systemImage: "hourglass")
                .appSectionHeader()
            HStack(alignment: .center, spacing: 14) {
                Text(period.ruler.symbol)
                    .font(.system(size: 46, weight: .semibold))
                    .foregroundColor(Color(hex: period.ruler.colorHex))
                VStack(alignment: .leading, spacing: 4) {
                    Text(period.ruler.label)
                        .font(.title2.weight(.semibold))
                        .foregroundColor(.appPrimaryText)
                    Text("\(displayDate(period.startDate)) → \(displayDate(period.endDate))")
                        .font(.caption.monospacedDigit())
                        .foregroundColor(.secondary)
                    Text("Duración nominal: \(String(format: "%.0f", period.nominalYears)) años")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                Spacer()
            }
        }
        .appCard()
    }

    private func currentMinorCard(_ minor: FirdariaPeriod?, major: FirdariaPeriod) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Label("Período menor actual", systemImage: "point.3.connected.trianglepath.dotted")
                .appSectionHeader()
            if let minor {
                HStack(spacing: 12) {
                    Circle()
                        .fill(Color(hex: minor.ruler.colorHex))
                        .frame(width: 12, height: 12)
                    VStack(alignment: .leading, spacing: 4) {
                        Text(minor.ruler.label)
                            .font(.headline)
                            .foregroundColor(.appPrimaryText)
                        Text("\(displayDateTime(minor.startDate)) → \(displayDateTime(minor.endDate))")
                            .font(.caption.monospacedDigit())
                            .foregroundColor(.secondary)
                    }
                    Spacer()
                }
            } else if major.ruler.isNode {
                Text("Los períodos mayores de los Nodos no se subdividen en firdar menor.")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            } else {
                Text("No se detectó sub-período menor para la fecha consultada.")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
        }
        .appCard()
    }

    private func timelineSection(timeline: FirdariaTimeline, currentMajor: FirdariaPeriod) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Label("Timeline del ciclo de 75 años", systemImage: "rectangle.split.3x1")
                    .appSectionHeader()
                Spacer()
                Text("\(displayDate(timeline.cycleStartDate)) → \(displayDate(timeline.cycleEndDate))")
                    .font(.caption.monospacedDigit())
                    .foregroundColor(.secondary)
            }

            GeometryReader { geometry in
                HStack(spacing: 2) {
                    ForEach(timeline.majorPeriods) { period in
                        let width = max(24, geometry.size.width * (period.nominalYears / 75.0))
                        VStack(alignment: .leading, spacing: 4) {
                            Text(period.ruler.symbol)
                                .font(.headline)
                            Text(period.ruler.shortLabel)
                                .font(.caption2.weight(.semibold))
                                .lineLimit(1)
                            Spacer(minLength: 0)
                            Text("\(Int(period.nominalYears))a")
                                .font(.caption2.monospacedDigit())
                        }
                        .padding(6)
                        .frame(width: width, height: 88, alignment: .leading)
                        .foregroundColor(.white)
                        .background(Color(hex: period.ruler.colorHex).opacity(period.id == currentMajor.id ? 0.95 : 0.68))
                        .clipShape(RoundedRectangle(cornerRadius: 7, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: 7, style: .continuous)
                                .stroke(period.id == currentMajor.id ? Color.appPrimaryText : Color.clear, lineWidth: 2)
                        )
                    }
                }
            }
            .frame(height: 96)
        }
        .appCard()
    }

    private func upcomingSection(_ changes: [FirdariaMinorChange]) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Label("Próximos 5 cambios de firdar menor", systemImage: "list.bullet.rectangle")
                .appSectionHeader()
            if changes.isEmpty {
                Text("No hay cambios próximos calculables.")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            } else {
                ForEach(changes) { change in
                    HStack(spacing: 10) {
                        Text(change.period.ruler.symbol)
                            .font(.title3)
                            .foregroundColor(Color(hex: change.period.ruler.colorHex))
                            .frame(width: 28)
                        VStack(alignment: .leading, spacing: 3) {
                            Text(change.period.ruler.label)
                                .font(.subheadline.weight(.medium))
                                .foregroundColor(.appPrimaryText)
                            Text("Empieza \(displayDateTime(change.date)) · termina \(displayDateTime(change.period.endDate))")
                                .font(.caption.monospacedDigit())
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

    private func createJoplinNote(chart: NatalChart) {
        noteTask?.cancel()
        isCreatingNote = true
        statusMessage = nil
        errorMessage = nil

        let settings = appState.joplinSettings
        let timeline = engine.firdariaPeriods(chart: chart)
        let current = engine.currentFirdaria(chart: chart, at: targetDate)
        let changes = engine.upcomingMinorChanges(chart: chart, at: targetDate, limit: 5)
        let title = FirdariaNoteBuilder.noteTitle(chart: chart, date: targetDate)
        let body = FirdariaNoteBuilder.markdown(
            chart: chart,
            date: targetDate,
            timeline: timeline,
            current: current,
            nextChanges: changes
        )

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

    private func displayDate(_ date: Date) -> String {
        Self.dateFormatter.string(from: date)
    }

    private func displayDateTime(_ date: Date) -> String {
        Self.dateTimeFormatter.string(from: date)
    }

    private static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "es_ES")
        formatter.timeZone = .current
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter
    }()

    private static let dateTimeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "es_ES")
        formatter.timeZone = .current
        formatter.dateFormat = "yyyy-MM-dd HH:mm"
        return formatter
    }()
}

enum FirdariaNoteBuilder {
    static func noteTitle(chart: NatalChart, date: Date) -> String {
        "Firdaria — \(chart.name) — \(displayDate(date))"
    }

    static func markdown(
        chart: NatalChart,
        date: Date,
        timeline: FirdariaTimeline,
        current: (major: FirdariaPeriod, minor: FirdariaPeriod?),
        nextChanges: [FirdariaMinorChange]
    ) -> String {
        var lines: [String] = [
            "# Firdaria — \(chart.name)",
            "",
            "Consulta firdárica persa generada desde AstroMalik.",
            "",
            "## Secta",
            "- Carta: \(timeline.sect.label)",
            "- Luminaria de secta: \(timeline.sect.luminary.label)",
            "- Benéfico de secta: \(timeline.sect.benefic.label)",
            "- Maléfico de secta: \(timeline.sect.malefic.label)",
            "- Benéfico contra secta: \(timeline.sect.contrarySectBenefic.label)",
            "- Maléfico contra secta: \(timeline.sect.contrarySectMalefic.label)",
            "",
            "## Fecha consultada",
            "- \(displayDate(date))",
            "",
            "## Período mayor actual",
            "- \(current.major.ruler.label): \(displayDate(current.major.startDate)) → \(displayDate(current.major.endDate))",
            "- Duración nominal: \(String(format: "%.0f", current.major.nominalYears)) años",
            "",
            "## Período menor actual",
        ]

        if let minor = current.minor {
            lines.append("- \(minor.ruler.label): \(displayDateTime(minor.startDate)) → \(displayDateTime(minor.endDate))")
        } else {
            lines.append("- No aplica: los Nodos no reciben sub-períodos menores.")
        }

        lines += ["", "## Timeline de 75 años"]
        for period in timeline.majorPeriods {
            lines.append("- \(period.ruler.label): \(displayDate(period.startDate)) → \(displayDate(period.endDate)) (\(Int(period.nominalYears)) años)")
        }

        lines += ["", "## Próximos cambios de firdar menor"]
        if nextChanges.isEmpty {
            lines.append("No hay próximos cambios calculables.")
        } else {
            for change in nextChanges {
                lines.append("- \(displayDateTime(change.date)): entra \(change.period.ruler.label) hasta \(displayDateTime(change.period.endDate))")
            }
        }

        lines += [
            "",
            "---",
            "*Generado por AstroMalik — \(generatedAt())*",
        ]
        return lines.joined(separator: "\n")
    }

    private static func displayDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "es_ES")
        formatter.timeZone = TimeZone.current
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: date)
    }

    private static func displayDateTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "es_ES")
        formatter.timeZone = TimeZone.current
        formatter.dateFormat = "yyyy-MM-dd HH:mm"
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
