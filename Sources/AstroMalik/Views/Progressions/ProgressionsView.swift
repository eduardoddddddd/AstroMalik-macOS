import SwiftUI

struct ProgressionsView: View {
    @EnvironmentObject var appState: AppState

    let chart: NatalChart?

    @State private var targetDate = Date()
    @State private var ascendantMode: ASCMode = .naibod
    @State private var snapshot: ProgressionSnapshot?
    @State private var aspects: [ProgressedAspect] = []
    @State private var isLoading = false
    @State private var isCreatingNote = false
    @State private var errorMessage: String?
    @State private var statusMessage: String?
    @State private var calculationTask: Task<Void, Never>?
    @State private var noteTask: Task<Void, Never>?

    private let engine = SecondaryProgressionEngine()

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
            .navigationTitle("Progresiones secundarias")
        }
        .frame(minWidth: 820, minHeight: 600)
        .task(id: taskKey) {
            recalculate()
        }
        .onDisappear {
            calculationTask?.cancel()
            noteTask?.cancel()
        }
    }

    private var taskKey: String {
        "\(chart?.id.uuidString ?? "sin-carta")-\(Self.isoDay(targetDate))-\(ascendantMode.rawValue)"
    }

    private func controls(chart: NatalChart) -> some View {
        HStack(spacing: 12) {
            Label(chart.name.isEmpty ? "Carta activa" : chart.name, systemImage: "person.crop.circle")
                .font(.subheadline.weight(.medium))
                .foregroundColor(.appPrimaryText)

            Divider().frame(height: 20)

            DatePicker("Fecha", selection: $targetDate, displayedComponents: .date)
                .datePickerStyle(.compact)

            Picker("Ángulos", selection: $ascendantMode) {
                ForEach(ASCMode.allCases) { mode in
                    Text(mode.label).tag(mode)
                }
            }
            .pickerStyle(.segmented)
            .frame(maxWidth: 300)
            .help(ascendantMode.explanation)

            Spacer()

            if let statusMessage {
                Text(statusMessage)
                    .font(.caption)
                    .foregroundColor(.appSecondaryAccent)
            }

            Button {
                recalculate(force: true)
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
            .disabled(snapshot == nil || isLoading || isCreatingNote)

            PDFExportButton(
                chartName: chart.name.isEmpty ? "Carta natal" : chart.name,
                reportType: "Progresiones secundarias",
                disabled: snapshot == nil || isLoading,
                generate: { pageSize in
                    guard let snapshot else { throw PDFReportExportViewError.missingData("No hay progresiones calculadas.") }
                    let data = ProgressionsLongReportBuilder.build(chart: chart, snapshot: snapshot, yearlyAspects: aspects)
                    return try await ReportService().generate(request: ProgressionsLongReportBuilder.makeRequest(data: data).withPageSize(pageSize))
                }
            )
            .environmentObject(appState)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
    }

    @ViewBuilder
    private func content(chart _: NatalChart) -> some View {
        if isLoading {
            ProgressView("Calculando progresiones secundarias…")
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else if let errorMessage {
            errorView(errorMessage)
        } else if let snapshot {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    header(snapshot)
                    lunarSection(snapshot)
                    aspectsSection(aspects)
                    highlightedSection(snapshot.highlightedChanges)
                }
                .padding(18)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        } else {
            VStack(spacing: 10) {
                Image(systemName: "moonphase.waxing.crescent")
                    .font(.system(size: 44))
                    .foregroundColor(.secondary)
                Text("Pulsa Recalcular para calcular progresiones secundarias.")
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
            Text("Las progresiones secundarias necesitan una carta natal activa con fecha, hora y lugar de nacimiento.")
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

    private func header(_ snapshot: ProgressionSnapshot) -> some View {
        let sun = snapshot.progressedSun
        let moon = snapshot.progressedMoon
        return VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Edad progresada: \(String(format: "%.2f", snapshot.ageYears)) años")
                        .font(.title2.weight(.semibold))
                        .foregroundColor(.appPrimaryText)
                    Text("JD progresado \(String(format: "%.5f", snapshot.progressedJulianDay)) · método \(snapshot.ascendantMode.label)")
                        .font(.caption.monospacedDigit())
                        .foregroundColor(.secondary)
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 4) {
                    Text(snapshot.lunarPhase.label)
                        .font(.title3.weight(.semibold))
                        .foregroundColor(.appAccentFill)
                    Text("Fase lunar progresada · \(String(format: "%.1f", snapshot.lunarPhase.angle))°")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }

            LazyVGrid(columns: [GridItem(.adaptive(minimum: 190), spacing: 10)], spacing: 10) {
                infoTile("Sol progresado", value: positionSummary(sun))
                infoTile("Luna progresada", value: positionSummary(moon))
                infoTile("ASC progresado", value: "\(snapshot.ascendant.formatted) · regente \(snapshot.ascendantRulerLabel)")
                infoTile("MC progresado", value: snapshot.mc.formatted)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .appCard()
    }

    private func lunarSection(_ snapshot: ProgressionSnapshot) -> some View {
        section("Luna progresada", systemImage: "moon.stars") {
            HStack(alignment: .top, spacing: 14) {
                ingressList("Próximos ingresos por signo", ingresses: snapshot.nextLunarSignIngresses)
                ingressList("Próximos ingresos por casa", ingresses: snapshot.nextLunarHouseIngresses)
                phaseList(snapshot.nextLunarPhaseTransitions)
            }
        }
    }

    private func aspectsSection(_ aspects: [ProgressedAspect]) -> some View {
        section("Aspectos del año", systemImage: "point.3.connected.trianglepath.dotted") {
            if aspects.isEmpty {
                emptyText("No se detectaron aspectos exactos progresados en el próximo año.")
            } else {
                Table(aspects) {
                    TableColumn("Fecha") { aspect in
                        Text(aspect.exactDate)
                            .font(.caption.monospacedDigit())
                    }
                    .width(96)

                    TableColumn("Tipo") { aspect in
                        Text(aspect.kind.label)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .width(110)

                    TableColumn("Aspecto") { aspect in
                        HStack(spacing: 6) {
                            Text(stars(aspect.priority))
                                .font(.caption)
                                .foregroundColor(.appSecondaryAccent)
                            Text(aspect.title)
                                .font(.subheadline)
                            if aspect.progressedRetrograde {
                                Text("℞").foregroundColor(.orange).font(.caption)
                            }
                        }
                    }
                    .width(min: 310)

                    TableColumn("Orbe") { aspect in
                        Text(String(format: "%.3f°", aspect.orb))
                            .font(.caption.monospacedDigit())
                            .foregroundColor(.secondary)
                    }
                    .width(70)
                }
                .frame(minHeight: min(CGFloat(aspects.count) * 28 + 44, 360))
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            }
        }
    }

    private func highlightedSection(_ changes: [ProgressedIngress]) -> some View {
        section("Cambios destacados ±5 años", systemImage: "sparkles") {
            if changes.isEmpty {
                emptyText("No se detectaron cambios de signo, estaciones ni cambios de fase lunar en la ventana ±5 años.")
            } else {
                VStack(spacing: 8) {
                    ForEach(changes) { change in
                        HStack(alignment: .top, spacing: 10) {
                            Text(change.dateLabel)
                                .font(.caption.monospacedDigit())
                                .foregroundColor(.secondary)
                                .frame(width: 86, alignment: .leading)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(change.description)
                                    .font(.subheadline.weight(.medium))
                                    .foregroundColor(.appPrimaryText)
                                Text("\(change.kind.label): \(change.fromValue) → \(change.toValue)")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            Spacer()
                            Text(stars(change.priority))
                                .font(.caption)
                                .foregroundColor(.appSecondaryAccent)
                        }
                        .padding(10)
                        .background(Color.appPanel)
                        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                    }
                }
            }
        }
    }

    private func ingressList(_ title: String, ingresses: [ProgressedIngress]) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.subheadline.weight(.semibold))
                .foregroundColor(.appPrimaryText)
            if ingresses.isEmpty {
                emptyText("Sin ingresos próximos.")
            } else {
                ForEach(ingresses) { ingress in
                    VStack(alignment: .leading, spacing: 2) {
                        Text("\(ingress.dateLabel) · \(ingress.toValue)")
                            .font(.caption.weight(.semibold))
                            .foregroundColor(.appPrimaryText)
                        Text(ingress.fromValue + " → " + ingress.toValue)
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(8)
                    .background(Color.appPanel)
                    .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .topLeading)
    }

    private func phaseList(_ phases: [ProgressedLunarPhase]) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Próximas fases")
                .font(.subheadline.weight(.semibold))
                .foregroundColor(.appPrimaryText)
            if phases.isEmpty {
                emptyText("Sin transiciones próximas.")
            } else {
                ForEach(phases) { phase in
                    VStack(alignment: .leading, spacing: 2) {
                        Text("\(phase.dateLabel ?? "—") · \(phase.label)")
                            .font(.caption.weight(.semibold))
                            .foregroundColor(.appPrimaryText)
                        Text("Ángulo Sol→Luna \(String(format: "%.0f", phase.angle))°")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(8)
                    .background(Color.appPanel)
                    .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .topLeading)
    }

    private func section<Content: View>(_ title: String, systemImage: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Label(title, systemImage: systemImage)
                .font(.headline)
                .foregroundColor(.appPrimaryText)
            content()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .appCard()
    }

    private func infoTile(_ title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
            Text(value)
                .font(.subheadline.weight(.medium))
                .foregroundColor(.appPrimaryText)
                .lineLimit(2)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(10)
        .background(Color.appPanel)
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
    }

    private func emptyText(_ text: String) -> some View {
        Text(text)
            .font(.subheadline)
            .foregroundColor(.secondary)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(10)
            .background(Color.appPanel)
            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
    }

    private func errorView(_ message: String) -> some View {
        VStack(spacing: 12) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 44))
                .foregroundColor(.orange)
            Text(message)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
            Button("Reintentar") { recalculate(force: true) }
                .buttonStyle(.borderedProminent)
                .tint(.appAccentFill)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(24)
    }

    private func positionSummary(_ body: ProgressedBody?) -> String {
        guard let body else { return "—" }
        return "\(body.formatted) · Casa \(body.house)"
    }

    private func stars(_ priority: Int) -> String {
        String(repeating: "★", count: max(1, min(5, priority)))
    }

    private func recalculate(force _: Bool = false) {
        guard let chart else { return }
        calculationTask?.cancel()
        isLoading = true
        errorMessage = nil
        statusMessage = nil
        let selectedDate = targetDate
        let selectedMode = ascendantMode
        calculationTask = Task {
            let localEngine = SecondaryProgressionEngine()
            let result = localEngine.progressions(chart: chart, at: selectedDate, ascendantMode: selectedMode)
            let endDate = Calendar.current.date(byAdding: .year, value: 1, to: selectedDate) ?? selectedDate
            let yearAspects = localEngine.progressedAspects(chart: chart, from: selectedDate, to: endDate)
            if Task.isCancelled { return }
            await MainActor.run {
                snapshot = result
                aspects = yearAspects
                isLoading = false
                statusMessage = "Actualizado"
            }
        }
    }

    private func createJoplinNote(chart: NatalChart) {
        guard let snapshot else { return }
        noteTask?.cancel()
        isCreatingNote = true
        statusMessage = nil
        let noteAspects = aspects
        noteTask = Task { @MainActor in
            do {
                let title = ProgressionsNoteBuilder.noteTitle(snapshot: snapshot)
                let body = ProgressionsNoteBuilder.markdown(chart: chart, snapshot: snapshot, aspects: noteAspects)
                try await JoplinClipperService(settings: appState.joplinSettings).createNote(title: title, body: body)
                statusMessage = "Nota creada en Joplin"
            } catch {
                errorMessage = error.localizedDescription
            }
            isCreatingNote = false
        }
    }

    private static func isoDay(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.timeZone = TimeZone.current
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: date)
    }
}

enum ProgressionsNoteBuilder {
    static func noteTitle(snapshot: ProgressionSnapshot) -> String {
        "Progresiones secundarias — \(snapshot.chartName) — \(displayDate(snapshot.targetDate))"
    }

    static func markdown(chart: NatalChart, snapshot: ProgressionSnapshot, aspects: [ProgressedAspect]) -> String {
        var lines: [String] = [
            "# Progresiones secundarias — \(chart.name)",
            "",
            "Consulta generada desde AstroMalik.",
            "",
            "## Resumen",
            "- Carta: \(chart.name)",
            "- Fecha objetivo: \(displayDate(snapshot.targetDate))",
            "- Edad decimal: \(String(format: "%.3f", snapshot.ageYears)) años",
            "- JD natal: \(String(format: "%.5f", snapshot.natalJulianDay))",
            "- JD progresado: \(String(format: "%.5f", snapshot.progressedJulianDay))",
            "- Método ASC/MC: \(snapshot.ascendantMode.label)",
            "- Fase lunar progresada: \(snapshot.lunarPhase.label) (\(String(format: "%.1f", snapshot.lunarPhase.angle))°)",
            "- Regente ASC progresado: \(snapshot.ascendantRulerLabel)",
            "",
            "## Posiciones progresadas",
            "| Punto | Posición | Casa | Declinación |",
            "|---|---|---:|---:|",
        ]
        for body in snapshot.bodies {
            lines.append("| \(body.label)\(body.retrograde ? " ℞" : "") | \(body.formatted) | \(body.house) | \(String(format: "%.2f", body.declination))° |")
        }
        lines.append("| Ascendente | \(snapshot.ascendant.formatted) | 1 | — |")
        lines.append("| Medio Cielo | \(snapshot.mc.formatted) | 10 | — |")

        appendIngressSection("Luna progresada — ingresos por signo", snapshot.nextLunarSignIngresses, lines: &lines)
        appendIngressSection("Luna progresada — ingresos por casa", snapshot.nextLunarHouseIngresses, lines: &lines)

        lines += ["", "## Próximas fases lunares"]
        if snapshot.nextLunarPhaseTransitions.isEmpty {
            lines.append("No se detectaron transiciones próximas.")
        } else {
            for phase in snapshot.nextLunarPhaseTransitions {
                lines.append("- \(phase.dateLabel ?? "—"): \(phase.label) (\(String(format: "%.0f", phase.angle))°)")
            }
        }

        lines += ["", "## Aspectos del año"]
        if aspects.isEmpty {
            lines.append("No se detectaron aspectos exactos progresados en el próximo año.")
        } else {
            for aspect in aspects {
                lines.append("- \(aspect.exactDate): **\(aspect.kind.label)** — \(aspect.title) · prioridad \(aspect.priority)/5")
            }
        }

        appendIngressSection("Cambios destacados ±5 años", snapshot.highlightedChanges, lines: &lines)
        lines += ["", "---", "*Generado por AstroMalik — \(generatedAt())*", ""]
        return lines.joined(separator: "\n")
    }

    private static func appendIngressSection(_ title: String, _ ingresses: [ProgressedIngress], lines: inout [String]) {
        lines += ["", "## \(title)"]
        if ingresses.isEmpty {
            lines.append("No se detectaron eventos.")
        } else {
            for ingress in ingresses {
                lines.append("- \(ingress.dateLabel): \(ingress.description) (\(ingress.fromValue) → \(ingress.toValue))")
            }
        }
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
