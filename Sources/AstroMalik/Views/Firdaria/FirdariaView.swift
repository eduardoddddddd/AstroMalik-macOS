import SwiftUI

struct FirdariaView: View {
    @EnvironmentObject var appState: AppState

    let chart: NatalChart?

    @State private var selectedChartID: UUID?
    @State private var targetDate = Date()
    @State private var selectedMajorID: String?
    @State private var selectedMinorID: String?
    @State private var isCreatingNote = false
    @State private var statusMessage: String?
    @State private var errorMessage: String?
    @State private var noteTask: Task<Void, Never>?

    private let engine = FirdariaEngine()

    private var charts: [NatalChart] {
        var seen = Set<UUID>()
        var result: [NatalChart] = []
        if let active = appState.activeNatalChart, seen.insert(active.id).inserted { result.append(active) }
        if let chart, seen.insert(chart.id).inserted { result.append(chart) }
        for saved in appState.userStore.savedCharts where seen.insert(saved.id).inserted { result.append(saved) }
        return result
    }

    private var selectedChart: NatalChart? {
        if let selectedChartID,
           let selected = charts.first(where: { $0.id == selectedChartID }) {
            return selected
        }
        return appState.activeNatalChart ?? chart ?? charts.first
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                if let selectedChart {
                    controls(chart: selectedChart)
                    Divider()
                    content(chart: selectedChart)
                } else {
                    noChartPlaceholder
                }
            }
            .background(Color.appBackground)
            .navigationTitle("Firdaria")
        }
        .frame(minWidth: 920, minHeight: 620)
        .onAppear(perform: ensureInitialSelection)
        .onChange(of: charts) { _, _ in ensureInitialSelection() }
        .onChange(of: selectedChartID) { _, _ in
            guard let selectedChart else { return }
            appState.activeNatalChart = selectedChart
            syncSelectionToDate(chart: selectedChart)
        }
        .onChange(of: targetDate) { _, _ in
            guard let selectedChart else { return }
            syncSelectionToDate(chart: selectedChart)
        }
        .onDisappear { noteTask?.cancel() }
    }

    private func controls(chart: NatalChart) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .bottom, spacing: 14) {
                VStack(alignment: .leading, spacing: 5) {
                    Text("Persona")
                        .font(.caption.weight(.semibold))
                        .foregroundColor(.secondary)
                    Picker("Persona", selection: $selectedChartID) {
                        ForEach(charts) { item in
                            Text(chartDisplayName(item)).tag(Optional(item.id))
                        }
                    }
                    .labelsHidden()
                    .frame(minWidth: 250, idealWidth: 300)
                }

                VStack(alignment: .leading, spacing: 5) {
                    Text("Fecha consultada")
                        .font(.caption.weight(.semibold))
                        .foregroundColor(.secondary)
                    DatePicker("Fecha consultada", selection: $targetDate, displayedComponents: .date)
                        .labelsHidden()
                        .datePickerStyle(.compact)
                }

                Button {
                    targetDate = Date()
                } label: {
                    Label("Hoy", systemImage: "calendar.badge.clock")
                }
                .buttonStyle(.bordered)

                Button {
                    syncSelectionToDate(chart: chart)
                } label: {
                    Label("Periodo activo", systemImage: "scope")
                }
                .buttonStyle(.bordered)

                Spacer()

                if let statusMessage {
                    Text(statusMessage)
                        .font(.caption)
                        .foregroundColor(.appSecondaryAccent)
                }

                Button {
                    createJoplinNote(chart: chart)
                } label: {
                    Label(isCreatingNote ? "Creando…" : "Joplin", systemImage: "square.and.pencil")
                }
                .buttonStyle(.borderedProminent)
                .tint(.appAccentFill)
                .disabled(isCreatingNote)

                PDFExportButton(
                    chartName: chart.name.isEmpty ? "Carta natal" : chart.name,
                    reportType: "Firdaria",
                    generate: { pageSize in
                        let data = FirdariaLongReportBuilder.build(chart: chart, asOf: targetDate)
                        return try await ReportService().generate(request: FirdariaLongReportBuilder.makeRequest(data: data).withPageSize(pageSize))
                    }
                )
                .environmentObject(appState)
            }

            HStack(spacing: 8) {
                Label(chart.placeName.isEmpty ? chart.timezone : chart.placeName, systemImage: "mappin.and.ellipse")
                Text("·")
                Text("Nacimiento: \(chart.birthDate) \(chart.birthTime)")
                Text("·")
                Text("TZ: \(chart.timezone)")
            }
            .font(.caption)
            .foregroundColor(.secondary)
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 12)
        .background(Color.appPanel)
    }

    private func content(chart: NatalChart) -> some View {
        let timeline = engine.firdariaTimeline(chart: chart, at: targetDate)
        let current = engine.currentFirdaria(chart: chart, at: targetDate)
        let nextChanges = engine.upcomingMinorChanges(chart: chart, at: targetDate, limit: 6)
        let selectedMajor = selectedMajor(in: timeline, current: current.major)
        let selectedMinor = selectedMinor(for: selectedMajor, sect: timeline.sect, current: current.minor)

        return ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                if let errorMessage { errorBanner(errorMessage) }

                hero(chart: chart, timeline: timeline, current: current)
                firdariaExplorer(
                    timeline: timeline,
                    current: current,
                    selectedMajor: selectedMajor,
                    selectedMinor: selectedMinor,
                    chart: chart
                )
                upcomingSection(nextChanges, chart: chart)
                sectHeader(timeline.sect)
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
            Text("La Firdaria persa requiere una persona/carta natal para ordenar sus períodos y subperíodos con fechas exactas.")
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

    private func errorBanner(_ message: String) -> some View {
        Text(message)
            .font(.caption)
            .foregroundColor(.appWarning)
            .padding(10)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.appWarning.opacity(0.12))
            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
    }

    private func hero(
        chart: NatalChart,
        timeline: FirdariaTimeline,
        current: (major: FirdariaPeriod, minor: FirdariaPeriod?)
    ) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top, spacing: 14) {
                VStack(alignment: .leading, spacing: 4) {
                    Label("Mapa firdárico de \(chart.name.isEmpty ? "esta persona" : chart.name)", systemImage: "hourglass.circle.fill")
                        .font(.title2.weight(.semibold))
                        .foregroundColor(.appPrimaryText)
                    Text("Ciclo \(timeline.cycleIndex + 1) · \(displayDate(timeline.cycleStartDate, chart: chart)) → \(displayDate(timeline.cycleEndDate, chart: chart)) · carta \(timeline.sect.label.lowercased())")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 3) {
                    Text(displayDateTime(targetDate, chart: chart))
                        .font(.subheadline.monospacedDigit().weight(.medium))
                        .foregroundColor(.appPrimaryText)
                    Text("fecha consultada")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }

            LazyVGrid(columns: [GridItem(.adaptive(minimum: 220), spacing: 10)], spacing: 10) {
                currentTile(title: "Mayor activo", period: current.major, referenceDate: targetDate, chart: chart)
                currentTile(title: "Menor activo", period: current.minor, referenceDate: targetDate, chart: chart)
                infoTile("Edad firdárica", value: ageText(at: targetDate, from: timeline.birthDate, chart: chart))
                infoTile("Siguiente cambio", value: nextChangeSummary(chart: chart))
            }
        }
        .appCard()
    }

    private func currentTile(title: String, period: FirdariaPeriod?, referenceDate: Date, chart: NatalChart) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.caption2)
                .foregroundColor(.secondary)
            if let period {
                HStack(spacing: 8) {
                    Text(period.ruler.symbol)
                        .font(.title2.weight(.semibold))
                        .foregroundColor(Color(hex: period.ruler.colorHex))
                    Text(period.ruler.label)
                        .font(.headline)
                        .foregroundColor(.appPrimaryText)
                }
                Text(clearRange(period, chart: chart))
                    .font(.caption.monospacedDigit())
                    .foregroundColor(.secondary)
                ProgressView(value: progress(for: period, at: referenceDate))
                    .tint(Color(hex: period.ruler.colorHex))
            } else {
                Text("Sin subperíodo: los Nodos no se subdividen")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
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

    private func firdariaExplorer(
        timeline: FirdariaTimeline,
        current: (major: FirdariaPeriod, minor: FirdariaPeriod?),
        selectedMajor: FirdariaPeriod,
        selectedMinor: FirdariaPeriod?,
        chart: NatalChart
    ) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Label("Explorador de períodos", systemImage: "list.bullet.rectangle.portrait")
                    .appSectionHeader()
                Spacer()
                Text("Selecciona un mayor; sus menores aparecen a la derecha")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            timelineStrip(timeline: timeline, currentMajor: current.major, selectedMajor: selectedMajor, chart: chart)

            HStack(alignment: .top, spacing: 14) {
                ScrollView {
                    VStack(spacing: 8) {
                        ForEach(timeline.majorPeriods) { period in
                            majorPeriodButton(period, currentMajorID: current.major.id, selectedMajorID: selectedMajor.id, chart: chart)
                        }
                    }
                    .padding(.trailing, 2)
                }
                .frame(width: 330)
                .frame(minHeight: 420, maxHeight: 560)

                periodDetail(major: selectedMajor, selectedMinor: selectedMinor, current: current, timeline: timeline, chart: chart)
                    .frame(maxWidth: .infinity, alignment: .topLeading)
            }
        }
        .appCard()
    }

    private func timelineStrip(
        timeline: FirdariaTimeline,
        currentMajor: FirdariaPeriod,
        selectedMajor: FirdariaPeriod,
        chart: NatalChart
    ) -> some View {
        GeometryReader { geometry in
            HStack(spacing: 2) {
                ForEach(timeline.majorPeriods) { period in
                    let width = max(28, geometry.size.width * (period.nominalYears / 75.0))
                    Button {
                        selectedMajorID = period.id
                        selectedMinorID = nil
                    } label: {
                        VStack(alignment: .leading, spacing: 4) {
                            HStack(spacing: 3) {
                                Text(period.ruler.symbol)
                                    .font(.headline)
                                if period.id == currentMajor.id { stripBadge("AHORA") }
                            }
                            Text(period.ruler.shortLabel)
                                .font(.caption2.weight(.semibold))
                                .lineLimit(1)
                            Spacer(minLength: 0)
                            Text("\(displayDate(period.startDate, chart: chart))")
                                .font(.caption2.monospacedDigit())
                                .lineLimit(1)
                        }
                        .padding(6)
                        .frame(width: width, height: 86, alignment: .leading)
                        .foregroundColor(.white)
                        .background(Color(hex: period.ruler.colorHex).opacity(period.id == selectedMajor.id ? 0.98 : 0.64))
                        .clipShape(RoundedRectangle(cornerRadius: 7, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: 7, style: .continuous)
                                .stroke(period.id == currentMajor.id ? Color.white : Color.clear, lineWidth: 2)
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .frame(height: 92)
    }

    private func stripBadge(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 8, weight: .black))
            .foregroundColor(.white)
            .padding(.horizontal, 4)
            .padding(.vertical, 1)
            .background(Color.black.opacity(0.28))
            .clipShape(Capsule())
    }

    private func majorPeriodButton(_ period: FirdariaPeriod, currentMajorID: String, selectedMajorID: String, chart: NatalChart) -> some View {
        let selected = period.id == selectedMajorID
        let current = period.id == currentMajorID
        return Button {
            self.selectedMajorID = period.id
            self.selectedMinorID = nil
        } label: {
            HStack(alignment: .center, spacing: 10) {
                Text(period.ruler.symbol)
                    .font(.title3.weight(.semibold))
                    .foregroundColor(Color(hex: period.ruler.colorHex))
                    .frame(width: 30)
                VStack(alignment: .leading, spacing: 3) {
                    HStack(spacing: 6) {
                        Text(period.ruler.label)
                            .font(.subheadline.weight(.semibold))
                            .foregroundColor(.appPrimaryText)
                        if current { smallBadge("ACTUAL", color: .appSecondaryAccent) }
                    }
                    Text(clearRange(period, chart: chart))
                        .font(.caption.monospacedDigit())
                        .foregroundColor(.secondary)
                    Text("Edad \(ageRangeText(period, from: engine.firdariaTimeline(chart: chart, at: targetDate).birthDate, chart: chart))")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
                Spacer()
                Image(systemName: selected ? "checkmark.circle.fill" : "chevron.right")
                    .foregroundColor(selected ? .appSecondaryAccent : .secondary)
            }
            .padding(10)
            .background(selected ? Color.appSecondaryAccent.opacity(0.12) : Color.appSurface)
            .clipShape(RoundedRectangle(cornerRadius: 9, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 9, style: .continuous)
                    .stroke(selected ? Color.appSecondaryAccent.opacity(0.65) : Color.clear, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }

    private func periodDetail(
        major: FirdariaPeriod,
        selectedMinor: FirdariaPeriod?,
        current: (major: FirdariaPeriod, minor: FirdariaPeriod?),
        timeline: FirdariaTimeline,
        chart: NatalChart
    ) -> some View {
        let minors = engine.minorPeriods(for: major, sect: timeline.sect)
        return VStack(alignment: .leading, spacing: 14) {
            periodHeader(major, title: "Período mayor seleccionado", currentID: current.major.id, birth: timeline.birthDate, chart: chart)

            if minors.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Label("Sin firdar menor", systemImage: "moonphase.new.moon")
                        .font(.headline)
                        .foregroundColor(.appPrimaryText)
                    Text("Los períodos de los Nodos se leen como bisagra kármica del ciclo; no se reparten en siete subperíodos planetarios.")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                .padding(12)
                .background(Color.appSurface)
                .clipShape(RoundedRectangle(cornerRadius: 9, style: .continuous))
            } else {
                HStack(alignment: .top, spacing: 12) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Subperíodos menores")
                            .font(.headline)
                            .foregroundColor(.appPrimaryText)
                        ForEach(minors) { minor in
                            minorPeriodButton(minor, currentMinorID: current.minor?.id, selectedMinorID: selectedMinor?.id, birth: timeline.birthDate, chart: chart)
                        }
                    }
                    .frame(minWidth: 300, idealWidth: 340, maxWidth: 380)

                    if let selectedMinor {
                        periodHeader(selectedMinor, title: "Menor seleccionado", currentID: current.minor?.id, birth: timeline.birthDate, chart: chart)
                            .frame(maxWidth: .infinity)
                    } else {
                        VStack(alignment: .leading, spacing: 8) {
                            Label("Elige un menor", systemImage: "cursorarrow.click.2")
                                .font(.headline)
                                .foregroundColor(.appPrimaryText)
                            Text("Pulsa cualquier subperíodo para ver sus fechas limpias, edad de inicio/fin y saltar la consulta a ese tramo.")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                        .padding(12)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color.appSurface)
                        .clipShape(RoundedRectangle(cornerRadius: 9, style: .continuous))
                    }
                }
            }
        }
    }

    private func periodHeader(_ period: FirdariaPeriod, title: String, currentID: String?, birth: Date, chart: NatalChart) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .center, spacing: 12) {
                Text(period.ruler.symbol)
                    .font(.system(size: 48, weight: .semibold))
                    .foregroundColor(Color(hex: period.ruler.colorHex))
                    .frame(width: 60)
                VStack(alignment: .leading, spacing: 3) {
                    HStack(spacing: 8) {
                        Text(title)
                            .font(.caption.weight(.semibold))
                            .foregroundColor(.secondary)
                        if period.id == currentID { smallBadge("ACTUAL", color: .appSecondaryAccent) }
                    }
                    Text(period.ruler.label)
                        .font(.title2.weight(.semibold))
                        .foregroundColor(.appPrimaryText)
                    Text(period.kind == .major ? "Duración nominal: \(String(format: "%.0f", period.nominalYears)) años" : "Duración: \(durationText(period, chart: chart))")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                Spacer()
            }

            LazyVGrid(columns: [GridItem(.adaptive(minimum: 190), spacing: 10)], spacing: 10) {
                dateBlock("Empieza", date: period.startDate, chart: chart)
                dateBlock("Termina", date: period.endDate, chart: chart)
                infoTile("Edad", value: ageRangeText(period, from: birth, chart: chart))
                infoTile("Queda / estado", value: statusText(period, at: targetDate, chart: chart))
            }

            ProgressView(value: progress(for: period, at: targetDate))
                .tint(Color(hex: period.ruler.colorHex))

            HStack(spacing: 8) {
                Button("Ir al inicio") { targetDate = period.startDate }
                Button("Ir a la mitad") { targetDate = midpoint(of: period) }
                Button("Ir al final") { targetDate = period.endDate.addingTimeInterval(-60) }
            }
            .buttonStyle(.bordered)
        }
        .padding(12)
        .background(Color.appSurface)
        .clipShape(RoundedRectangle(cornerRadius: 9, style: .continuous))
    }

    private func dateBlock(_ title: String, date: Date, chart: NatalChart) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.caption2)
                .foregroundColor(.secondary)
            Text(displayLongDate(date, chart: chart))
                .font(.subheadline.weight(.semibold))
                .foregroundColor(.appPrimaryText)
            Text(displayDateTime(date, chart: chart))
                .font(.caption.monospacedDigit())
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(10)
        .background(Color.appPanel.opacity(0.55))
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
    }

    private func minorPeriodButton(_ period: FirdariaPeriod, currentMinorID: String?, selectedMinorID: String?, birth: Date, chart: NatalChart) -> some View {
        let selected = period.id == selectedMinorID
        let current = period.id == currentMinorID
        return Button {
            self.selectedMinorID = period.id
        } label: {
            HStack(alignment: .center, spacing: 9) {
                Circle()
                    .fill(Color(hex: period.ruler.colorHex))
                    .frame(width: 10, height: 10)
                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 6) {
                        Text(period.ruler.label)
                            .font(.subheadline.weight(.medium))
                            .foregroundColor(.appPrimaryText)
                        if current { smallBadge("ACTUAL", color: .appSecondaryAccent) }
                    }
                    Text(clearRange(period, chart: chart))
                        .font(.caption.monospacedDigit())
                        .foregroundColor(.secondary)
                    Text("Edad \(ageRangeText(period, from: birth, chart: chart))")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
                Spacer()
            }
            .padding(9)
            .background(selected ? Color(hex: period.ruler.colorHex).opacity(0.13) : Color.appPanel.opacity(0.55))
            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        }
        .buttonStyle(.plain)
    }

    private func upcomingSection(_ changes: [FirdariaMinorChange], chart: NatalChart) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Label("Próximos cambios de firdar menor", systemImage: "sparkles")
                .appSectionHeader()
            if changes.isEmpty {
                Text("No hay cambios próximos calculables.")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            } else {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 260), spacing: 10)], spacing: 10) {
                    ForEach(changes) { change in
                        Button {
                            targetDate = change.date
                            selectedMajorID = change.period.id.replacingOccurrences(of: "minor", with: "major")
                            selectedMinorID = change.period.id
                        } label: {
                            HStack(spacing: 10) {
                                Text(change.period.ruler.symbol)
                                    .font(.title3)
                                    .foregroundColor(Color(hex: change.period.ruler.colorHex))
                                    .frame(width: 28)
                                VStack(alignment: .leading, spacing: 3) {
                                    Text("Entra \(change.period.ruler.label)")
                                        .font(.subheadline.weight(.medium))
                                        .foregroundColor(.appPrimaryText)
                                    Text("\(displayDateTime(change.date, chart: chart)) → \(displayDateTime(change.period.endDate, chart: chart))")
                                        .font(.caption.monospacedDigit())
                                        .foregroundColor(.secondary)
                                }
                                Spacer()
                            }
                            .padding(10)
                            .background(Color.appSurface)
                            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
        .appCard()
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

    private func createJoplinNote(chart: NatalChart) {
        noteTask?.cancel()
        isCreatingNote = true
        statusMessage = nil
        errorMessage = nil

        let settings = appState.joplinSettings
        let timeline = engine.firdariaTimeline(chart: chart, at: targetDate)
        let current = engine.currentFirdaria(chart: chart, at: targetDate)
        let changes = engine.upcomingMinorChanges(chart: chart, at: targetDate, limit: 6)
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

    private func ensureInitialSelection() {
        if selectedChartID == nil || selectedChart == nil {
            selectedChartID = (appState.activeNatalChart ?? chart ?? charts.first)?.id
        }
        if let selectedChart {
            syncSelectionToDate(chart: selectedChart)
        }
    }

    private func syncSelectionToDate(chart: NatalChart) {
        let current = engine.currentFirdaria(chart: chart, at: targetDate)
        selectedMajorID = current.major.id
        selectedMinorID = current.minor?.id
    }

    private func selectedMajor(in timeline: FirdariaTimeline, current: FirdariaPeriod) -> FirdariaPeriod {
        if let selectedMajorID,
           let period = timeline.majorPeriods.first(where: { $0.id == selectedMajorID }) {
            return period
        }
        return timeline.majorPeriods.first(where: { $0.id == current.id }) ?? current
    }

    private func selectedMinor(for major: FirdariaPeriod, sect: SectInfo, current: FirdariaPeriod?) -> FirdariaPeriod? {
        let minors = engine.minorPeriods(for: major, sect: sect)
        if let selectedMinorID,
           let period = minors.first(where: { $0.id == selectedMinorID }) {
            return period
        }
        if let current, minors.contains(where: { $0.id == current.id }) { return current }
        return nil
    }

    private func chartDisplayName(_ chart: NatalChart) -> String {
        let name = chart.name.isEmpty ? "Sin nombre" : chart.name
        return chart.placeName.isEmpty ? name : "\(name) · \(chart.placeName)"
    }

    private func nextChangeSummary(chart: NatalChart) -> String {
        guard let change = engine.upcomingMinorChanges(chart: chart, at: targetDate, limit: 1).first else { return "—" }
        return "\(change.period.ruler.shortLabel) · \(displayDate(change.date, chart: chart))"
    }

    private func clearRange(_ period: FirdariaPeriod, chart: NatalChart) -> String {
        "\(displayDate(period.startDate, chart: chart)) → \(displayDate(period.endDate, chart: chart))"
    }

    private func statusText(_ period: FirdariaPeriod, at date: Date, chart: NatalChart) -> String {
        if date < period.startDate { return "Empieza en \(distanceText(from: date, to: period.startDate, chart: chart))" }
        if date >= period.endDate { return "Finalizado" }
        return "Quedan \(distanceText(from: date, to: period.endDate, chart: chart))"
    }

    private func durationText(_ period: FirdariaPeriod, chart: NatalChart) -> String {
        distanceText(from: period.startDate, to: period.endDate, chart: chart)
    }

    private func ageRangeText(_ period: FirdariaPeriod, from birth: Date, chart: NatalChart) -> String {
        "\(ageText(at: period.startDate, from: birth, chart: chart)) → \(ageText(at: period.endDate, from: birth, chart: chart))"
    }

    private func ageText(at date: Date, from birth: Date, chart: NatalChart) -> String {
        let comps = calendar(for: chart).dateComponents([.year, .month, .day], from: birth, to: maxDate(date, birth))
        let y = max(0, comps.year ?? 0)
        let m = max(0, comps.month ?? 0)
        let d = max(0, comps.day ?? 0)
        if y == 0 && m == 0 { return "\(d)d" }
        if y == 0 { return "\(m)m \(d)d" }
        return "\(y)a \(m)m"
    }

    private func distanceText(from start: Date, to end: Date, chart: NatalChart) -> String {
        let safeStart = minDate(start, end)
        let comps = calendar(for: chart).dateComponents([.year, .month, .day, .hour], from: safeStart, to: end)
        var parts: [String] = []
        if let y = comps.year, y > 0 { parts.append("\(y)a") }
        if let m = comps.month, m > 0 { parts.append("\(m)m") }
        if let d = comps.day, d > 0 { parts.append("\(d)d") }
        if parts.isEmpty, let h = comps.hour, h > 0 { parts.append("\(h)h") }
        return parts.isEmpty ? "menos de 1h" : parts.prefix(3).joined(separator: " ")
    }

    private func progress(for period: FirdariaPeriod, at date: Date) -> Double {
        guard period.endDate > period.startDate else { return 0 }
        if date <= period.startDate { return 0 }
        if date >= period.endDate { return 1 }
        return date.timeIntervalSince(period.startDate) / period.endDate.timeIntervalSince(period.startDate)
    }

    private func midpoint(of period: FirdariaPeriod) -> Date {
        period.startDate.addingTimeInterval(period.endDate.timeIntervalSince(period.startDate) / 2)
    }

    private func minDate(_ lhs: Date, _ rhs: Date) -> Date { lhs <= rhs ? lhs : rhs }
    private func maxDate(_ lhs: Date, _ rhs: Date) -> Date { lhs >= rhs ? lhs : rhs }

    private func smallBadge(_ text: String, color: Color) -> some View {
        Text(text)
            .font(.caption2.weight(.bold))
            .foregroundColor(color)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(color.opacity(0.14))
            .clipShape(Capsule())
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
        formatter(chart: chart, format: "yyyy-MM-dd HH:mm zzz").string(from: date)
    }

    private func displayLongDate(_ date: Date, chart: NatalChart) -> String {
        formatter(chart: chart, format: "EEEE d MMMM yyyy").string(from: date)
    }

    private func formatter(chart: NatalChart, format: String) -> DateFormatter {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "es_ES")
        formatter.timeZone = TimeZone(identifier: chart.timezone) ?? TimeZone.current
        formatter.dateFormat = format
        return formatter
    }
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
