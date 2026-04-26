import SwiftUI

private enum LunarReturnMode: String, CaseIterable, Identifiable {
    case calendar = "Calendario"
    case wheel = "Rueda"
    case overlay = "Superposición"
    case data = "Datos"

    var id: String { rawValue }
}

struct LunarReturnView: View {
    @EnvironmentObject var appState: AppState

    @State private var chartID: UUID?
    @State private var startDate = Date()
    @State private var count = 24
    @State private var placeQuery = ""
    @State private var placeName = "Madrid"
    @State private var latitude = 40.4168
    @State private var longitude = -3.7038
    @State private var timezone = "Europe/Madrid"
    @State private var placeResults: [Place] = []
    @State private var reading: LunarReturnReading?
    @State private var selectedMode: LunarReturnMode = .calendar
    @State private var selectedFocusKey: String? = "LUNA"
    @State private var selectedEventIndex: Int?
    @State private var isCalculating = false
    @State private var isCreatingNote = false
    @State private var statusMessage: String?
    @State private var errorMessage: String?
    @State private var calculationTask: Task<Void, Never>?
    @State private var noteTask: Task<Void, Never>?

    private var charts: [NatalChart] { appState.userStore.savedCharts }
    private var selectedChart: NatalChart? {
        guard let chartID else { return nil }
        return charts.first { $0.id == chartID }
    }
    private var selectedEvent: LunarReturnEvent? {
        guard let reading else { return nil }
        if let selectedEventIndex,
           let match = reading.events.first(where: { $0.index == selectedEventIndex }) {
            return match
        }
        return reading.events.first
    }

    var body: some View {
        Group {
            if charts.isEmpty {
                emptyState
            } else {
                workspace
            }
        }
        .background(Color.appBackground)
        .navigationTitle("Revolución Lunar")
        .onAppear {
            ensureInitialSelection()
            syncLocationFromSelectedChart()
        }
        .onChange(of: charts) { _, _ in
            ensureInitialSelection()
        }
        .onChange(of: chartID) { _, _ in
            syncLocationFromSelectedChart()
        }
        .onDisappear {
            calculationTask?.cancel()
            noteTask?.cancel()
        }
    }

    private var workspace: some View {
        VStack(spacing: 0) {
            controls
            Divider()
            if isCalculating {
                ProgressView("Calculando revoluciones lunares…")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if let reading {
                resultView(reading)
            } else {
                readyState
            }
        }
    }

    private var controls: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .bottom, spacing: 14) {
                VStack(alignment: .leading, spacing: 5) {
                    Text("Carta natal")
                        .font(.caption.weight(.semibold))
                        .foregroundColor(.secondary)
                    Picker("Carta natal", selection: $chartID) {
                        ForEach(charts) { chart in
                            Text(lrDisplayName(chart)).tag(Optional(chart.id))
                        }
                    }
                    .labelsHidden()
                    .frame(width: 220)
                }

                VStack(alignment: .leading, spacing: 5) {
                    Text("Fecha base")
                        .font(.caption.weight(.semibold))
                        .foregroundColor(.secondary)
                    DatePicker(
                        "",
                        selection: $startDate,
                        displayedComponents: [.date]
                    )
                    .labelsHidden()
                    .frame(width: 170)
                }

                VStack(alignment: .leading, spacing: 5) {
                    Text("Retornos")
                        .font(.caption.weight(.semibold))
                        .foregroundColor(.secondary)
                    Stepper(value: $count, in: 1...48) {
                        Text(String(count))
                            .font(.body.monospacedDigit())
                            .frame(width: 40, alignment: .leading)
                    }
                    .frame(width: 120)
                }

                locationPicker
                Spacer()
                Button {
                    calculate()
                } label: {
                    Label("Calcular", systemImage: "moon.stars")
                }
                .buttonStyle(.borderedProminent)
                .tint(.appAccentFill)
                .disabled(selectedChart == nil || isCalculating)
            }

            if !placeResults.isEmpty {
                placeResultsList
            }
            feedback
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 14)
        .background(Color.appPanel)
    }

    private var locationPicker: some View {
        VStack(alignment: .leading, spacing: 5) {
            Text("Lugar del retorno")
                .font(.caption.weight(.semibold))
                .foregroundColor(.secondary)
            HStack(spacing: 8) {
                TextField("Ciudad, país…", text: $placeQuery)
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 260)
                    .onChange(of: placeQuery) { _, query in
                        Task { await searchPlaces(query) }
                    }
                if !placeQuery.isEmpty {
                    Button {
                        placeQuery = ""
                        placeResults = []
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                    }
                    .buttonStyle(.plain)
                    .foregroundColor(.secondary)
                }
            }
        }
    }

    private var placeResultsList: some View {
        VStack(alignment: .leading, spacing: 0) {
            ForEach(placeResults) { place in
                Button {
                    selectPlace(place)
                } label: {
                    HStack {
                        Text(place.displayName)
                        Spacer()
                        Text(place.timezone)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 7)
                }
                .buttonStyle(.plain)
                .background(Color.appPanel)
                Divider()
            }
        }
        .frame(maxWidth: 560)
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(Color.appBorder, lineWidth: 1)
        )
    }

    private var feedback: some View {
        VStack(alignment: .leading, spacing: 6) {
            if let statusMessage {
                Label(statusMessage, systemImage: "checkmark.circle.fill")
                    .font(.caption)
                    .foregroundColor(.appSecondaryAccent)
            }
            if let errorMessage {
                Label(errorMessage, systemImage: "exclamationmark.triangle.fill")
                    .font(.caption)
                    .foregroundColor(.red)
            }
            Text("\(placeName) · \(timezone) · \(String(format: "%.4f", latitude)), \(String(format: "%.4f", longitude))")
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }

    private func resultView(_ reading: LunarReturnReading) -> some View {
        VStack(spacing: 0) {
            resultHeader(reading)
            Divider()
            Picker("Vista", selection: $selectedMode) {
                ForEach(LunarReturnMode.allCases) { mode in
                    Text(mode.rawValue).tag(mode)
                }
            }
            .pickerStyle(.segmented)
            .frame(maxWidth: 560)
            .padding(12)
            Divider()

            switch selectedMode {
            case .calendar:
                calendarPanel(reading)
            case .wheel:
                wheelPanel(reading)
            case .overlay:
                overlayPanel(reading)
            case .data:
                dataPanel(reading)
            }
        }
    }

    private func resultHeader(_ reading: LunarReturnReading) -> some View {
        HStack(alignment: .top, spacing: 16) {
            VStack(alignment: .leading, spacing: 6) {
                Text("Revolución Lunar — \(lrDisplayName(reading.natalChart))")
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundColor(.appPrimaryText)
                    .lineLimit(1)
                HStack(spacing: 12) {
                    Label(baseDateLabel(reading.startDate), systemImage: "calendar")
                    Label(reading.placeName, systemImage: "mappin")
                    Label(reading.coverageSummary, systemImage: "waveform.path.ecg")
                }
                .font(.caption)
                .foregroundColor(.secondary)
                .lineLimit(1)
            }
            Spacer()
            Button {
                createJoplinNote(reading)
            } label: {
                if isCreatingNote {
                    ProgressView().controlSize(.small)
                } else {
                    Label("Crear nota Joplin", systemImage: "note.text.badge.plus")
                }
            }
            .buttonStyle(.bordered)
            .disabled(isCreatingNote || selectedEvent == nil)
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 12)
        .background(Color.appSurface)
    }

    private func calendarPanel(_ reading: LunarReturnReading) -> some View {
        ScrollView {
            VStack(spacing: 14) {
                summaryCard(reading)
                VStack(spacing: 0) {
                    calendarHeaderRow
                    Divider()
                    ForEach(reading.events) { event in
                        Button {
                            selectedEventIndex = event.index
                            selectedMode = .data
                        } label: {
                            calendarRow(event, isSelected: event.index == selectedEvent?.index)
                        }
                        .buttonStyle(.plain)
                        Divider()
                    }
                }
                .appCard(padding: 0)
            }
            .padding(18)
        }
    }

    private var calendarHeaderRow: some View {
        HStack(spacing: 10) {
            headerCell("#", width: 30, alignment: .leading)
            headerCell("Fecha local", width: 130, alignment: .leading)
            headerCell("Luna", width: 130, alignment: .leading)
            headerCell("Casa", width: 52, alignment: .leading)
            headerCell("ASC retorno", width: 130, alignment: .leading)
            headerCell("Intensidad", width: 100, alignment: .leading)
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(Color.appSurface)
    }

    private func headerCell(_ title: String, width: CGFloat, alignment: Alignment) -> some View {
        Text(title)
            .font(.caption.weight(.semibold))
            .foregroundColor(.secondary)
            .frame(width: width, alignment: alignment)
    }

    private func calendarRow(_ event: LunarReturnEvent, isSelected: Bool) -> some View {
        HStack(spacing: 10) {
            rowCell("#\(event.index)", width: 30, alignment: .leading, secondary: false)
            rowCell(event.exactLocalDateTime, width: 130, alignment: .leading, secondary: false)
            rowCell(event.moon.formatted, width: 130, alignment: .leading, secondary: true)
            rowCell("\(event.moon.house)", width: 52, alignment: .leading, secondary: true)
            rowCell(event.returnChart.ascendant.formatted, width: 130, alignment: .leading, secondary: true)
            HStack(spacing: 4) {
                Text(RevolutionTemplates.intensityStars(event.intensityScore))
                    .font(.caption.monospacedDigit())
                    .foregroundColor(event.intensityScore >= 4 ? .appWarning : .secondary)
            }
            .frame(width: 100, alignment: .leading)
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(isSelected ? Color.appAccentFill.opacity(0.12) : Color.appPanel)
    }

    private func rowCell(_ value: String, width: CGFloat, alignment: Alignment, secondary: Bool) -> some View {
        Text(value)
            .font(.subheadline.monospacedDigit())
            .foregroundColor(secondary ? .secondary : .appPrimaryText)
            .frame(width: width, alignment: alignment)
    }

    private func wheelPanel(_ reading: LunarReturnReading) -> some View {
        ScrollView {
            VStack(spacing: 14) {
                eventSelector(reading)
                if let selectedEvent {
                    NatalWheelView(chart: selectedEvent.returnChart, selectedKey: $selectedFocusKey)
                        .frame(minHeight: 460)
                    selectedEventCard(selectedEvent)
                }
            }
            .padding(18)
        }
    }

    private func overlayPanel(_ reading: LunarReturnReading) -> some View {
        ScrollView {
            VStack(spacing: 14) {
                eventSelector(reading)
                if let selectedEvent {
                    LunarReturnOverlayWheelView(
                        natalChart: reading.natalChart,
                        event: selectedEvent
                    )
                    .frame(minHeight: 520)
                    selectedEventCard(selectedEvent)
                }
            }
            .padding(18)
        }
    }

    private func dataPanel(_ reading: LunarReturnReading) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                eventSelector(reading)
                if let selectedEvent {
                    narrativeCard(selectedEvent)
                    selectedEventCard(selectedEvent)
                    aspectsCard(selectedEvent)
                    placementsCard(selectedEvent)
                    technicalCard(selectedEvent)
                }
            }
            .padding(18)
        }
    }

    private func eventSelector(_ reading: LunarReturnReading) -> some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(reading.events) { event in
                    Button {
                        selectedEventIndex = event.index
                    } label: {
                        Text("#\(event.index)")
                            .font(.caption.weight(.semibold))
                            .foregroundColor(selectedEvent?.index == event.index ? .appAccentForeground : .appPrimaryText)
                            .frame(width: 38, height: 28)
                            .background(selectedEvent?.index == event.index ? Color.appAccentFill : Color.appPanel)
                            .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                            .overlay(
                                RoundedRectangle(cornerRadius: 6, style: .continuous)
                                    .stroke(Color.appBorder.opacity(0.7), lineWidth: 1)
                            )
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 2)
        }
    }

    private func summaryCard(_ reading: LunarReturnReading) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Resumen del ciclo")
                .appSectionHeader()
            lunarRow("Luna natal", "\(reading.natalMoon.formatted) · Casa \(reading.natalMoon.house)")
            if let average = reading.statistics.averageIntervalDays {
                lunarRow("Intervalo medio", String(format: "%.2f días", average))
            }
            if let house = reading.statistics.mostFrequentMoonHouse {
                lunarRow("Casa más frecuente", "Casa \(house)")
            }
            lunarRow("Intensidad media", RevolutionTemplates.intensityStars(Int(reading.statistics.averageIntensity.rounded())))
            lunarRow("Retornos", "\(reading.events.count)")
        }
        .appCard()
    }

    private func narrativeCard(_ event: LunarReturnEvent) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 10) {
                Image(systemName: "moon.stars.fill")
                    .font(.system(size: 22))
                    .foregroundColor(.appAccentFill)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Retorno #\(event.index) — \(event.intensityLabel)")
                        .font(.headline)
                        .foregroundColor(.appPrimaryText)
                    Text(RevolutionTemplates.intensityStars(event.intensityScore))
                        .font(.subheadline)
                        .foregroundColor(event.intensityScore >= 4 ? .appWarning : .secondary)
                }
            }
            Text(event.miniNarrative)
                .font(.subheadline).foregroundColor(.appPrimaryText)
                .fixedSize(horizontal: false, vertical: true)
            Divider().opacity(0.4)
            Text("Foco emocional")
                .font(.caption.weight(.semibold)).foregroundColor(.secondary)
            Text(event.moonFocusText)
                .font(.subheadline).foregroundColor(.appPrimaryText)
                .fixedSize(horizontal: false, vertical: true)
            Divider().opacity(0.4)
            Text("Tono del mes")
                .font(.caption.weight(.semibold)).foregroundColor(.secondary)
            Text(event.ascToneText)
                .font(.subheadline).foregroundColor(.appPrimaryText)
                .fixedSize(horizontal: false, vertical: true)
        }
        .appCard()
    }

    private func selectedEventCard(_ event: LunarReturnEvent) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Datos del retorno")
                .appSectionHeader()
            lunarRow("Retorno", "#\(event.index)")
            lunarRow("Fecha local", event.exactLocalDateTime)
            lunarRow("Fecha UTC", event.exactUTCDateTime)
            lunarRow("Luna", "\(event.moon.formatted) · Casa \(event.moon.house)")
            lunarRow("ASC retorno", "\(event.returnChart.ascendant.formatted) · Casa natal \(event.natalHouseForReturnAsc)")
            lunarRow("MC retorno", "\(event.returnChart.mc.formatted) · Casa natal \(event.natalHouseForReturnMC)")
            lunarRow("Intensidad", "\(RevolutionTemplates.intensityStars(event.intensityScore)) (\(event.intensityLabel))")
        }
        .appCard()
    }

    @State private var showTechnical = false

    private func technicalCard(_ event: LunarReturnEvent) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Button {
                withAnimation(.easeInOut(duration: 0.2)) { showTechnical.toggle() }
            } label: {
                HStack {
                    Text("Datos técnicos")
                        .appSectionHeader()
                    Spacer()
                    Image(systemName: showTechnical ? "chevron.up" : "chevron.down")
                        .font(.caption).foregroundColor(.secondary)
                }
            }
            .buttonStyle(.plain)
            if showTechnical {
                lunarRow("Latitud lunar", String(format: "%.4f°", event.moon.latitude))
                lunarRow("Velocidad", String(format: "%.4f°/día", event.moon.speed))
                lunarRow("Distancia", String(format: "%.6f UA", event.moon.distance))
                lunarRow("Precisión", String(format: "%.2f seg. arco", event.moon.precisionArcseconds))
                lunarRow("Edad", "\(String(format: "%.2f", event.ageYears)) años")
            }
        }
        .appCard()
    }

    private func aspectsCard(_ event: LunarReturnEvent) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Aspectos dominantes")
                .appSectionHeader()
            if event.dominantAspects.isEmpty {
                Text("No se encontraron aspectos principales para este retorno.")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            } else {
                ForEach(event.dominantAspects) { aspect in
                    HStack {
                        Text("\(aspect.labelA) \(aspect.aspLabel) \(aspect.labelB)")
                        Spacer()
                        Text(String(format: "%.2f°", aspect.orb))
                            .font(.caption.monospacedDigit())
                            .foregroundColor(.secondary)
                    }
                    .font(.subheadline)
                }
            }
        }
        .appCard()
    }

    private func placementsCard(_ event: LunarReturnEvent) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Planetas del retorno en casas natales")
                .appSectionHeader()
            ForEach(event.returnPlanetsInNatalHouses) { placement in
                HStack {
                    Text(placement.planetLabel)
                        .frame(width: 110, alignment: .leading)
                    Text("Casa natal \(placement.natalHouse)")
                    Spacer()
                    Text("Casa retorno \(placement.returnHouse)")
                        .foregroundColor(.secondary)
                }
                .font(.subheadline)
            }
        }
        .appCard()
    }

    private func lunarRow(_ title: String, _ value: String) -> some View {
        HStack(alignment: .firstTextBaseline) {
            Text(title)
                .frame(width: 130, alignment: .leading)
                .foregroundColor(.secondary)
            Text(value)
                .foregroundColor(.appPrimaryText)
            Spacer()
        }
        .font(.subheadline)
    }

    private var readyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "moon.circle")
                .font(.system(size: 44))
                .foregroundColor(.secondary)
            Text("Revolución Lunar")
                .font(.headline).foregroundColor(.appPrimaryText)
            Text("La revolución lunar marca el ritmo emocional mes a mes. Cada retorno de la Luna a su posición natal abre un nuevo ciclo de ~27.3 días. Elige carta, fecha base y lugar para calcular.")
                .font(.subheadline).foregroundColor(.secondary)
                .multilineTextAlignment(.center).frame(maxWidth: 420)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "moonphase.first.quarter.inverse")
                .font(.system(size: 48))
                .foregroundColor(.secondary)
            Text("Necesitas una carta guardada")
                .font(.headline).foregroundColor(.secondary)
            Text("Guarda una carta natal para calcular su revolución lunar.")
                .font(.subheadline).foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func ensureInitialSelection() {
        guard let first = charts.first else {
            chartID = nil
            reading = nil
            selectedEventIndex = nil
            return
        }
        if chartID == nil || !charts.contains(where: { $0.id == chartID }) {
            chartID = first.id
        }
    }

    private func syncLocationFromSelectedChart() {
        guard let chart = selectedChart else { return }
        placeName = chart.placeName.isEmpty ? placeName : chart.placeName
        latitude = chart.latitude
        longitude = chart.longitude
        timezone = chart.timezone.isEmpty ? timezone : chart.timezone
        placeQuery = chart.placeName
        reading = nil
        selectedEventIndex = nil
    }

    private func searchPlaces(_ query: String) async {
        guard query.count > 1 else {
            placeResults = []
            return
        }
        placeResults = await appState.placesService.search(query: query)
    }

    private func selectPlace(_ place: Place) {
        placeName = place.name
        latitude = place.latitude
        longitude = place.longitude
        timezone = place.timezone
        placeQuery = place.displayName
        placeResults = []
        reading = nil
        selectedEventIndex = nil
    }

    private func calculate() {
        guard let selectedChart else { return }
        calculationTask?.cancel()
        statusMessage = nil
        errorMessage = nil
        isCalculating = true
        let request = LunarReturnRequest(
            natalChart: selectedChart,
            startDate: startDate,
            count: count,
            placeName: placeName,
            latitude: latitude,
            longitude: longitude,
            timezone: timezone
        )

        calculationTask = Task {
            do {
                let worker = Task.detached(priority: .userInitiated) {
                    try LunarReturnEngine.calculate(request: request)
                }
                let result = try await withTaskCancellationHandler {
                    try await worker.value
                } onCancel: {
                    worker.cancel()
                }
                guard !Task.isCancelled else { return }
                reading = result
                selectedEventIndex = result.events.first?.index
                selectedFocusKey = "LUNA"
            } catch {
                guard !Task.isCancelled else { return }
                errorMessage = error.localizedDescription
            }
            if !Task.isCancelled {
                isCalculating = false
            }
        }
    }

    private func createJoplinNote(_ reading: LunarReturnReading) {
        guard let selectedEvent else { return }
        noteTask?.cancel()
        statusMessage = nil
        errorMessage = nil
        isCreatingNote = true
        let settings = appState.joplinSettings
        noteTask = Task {
            do {
                let service = JoplinClipperService(settings: settings)
                try await service.createNote(
                    title: "Revolución Lunar - \(lrDisplayName(reading.natalChart))",
                    body: LunarReturnNoteBuilder.markdown(reading: reading, selectedEvent: selectedEvent)
                )
                guard !Task.isCancelled else { return }
                statusMessage = "Nota creada en Joplin."
            } catch {
                guard !Task.isCancelled else { return }
                errorMessage = error.localizedDescription
            }
            isCreatingNote = false
        }
    }

    private func baseDateLabel(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.timeZone = TimeZone.current
        formatter.locale = Locale(identifier: "es_ES")
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: date)
    }
}

private struct LunarReturnOverlayWheelView: View {
    let natalChart: NatalChart
    let event: LunarReturnEvent

    var body: some View {
        GeometryReader { proxy in
            let side = min(proxy.size.width, proxy.size.height)
            let center = CGPoint(x: proxy.size.width / 2, y: proxy.size.height / 2)
            let natalRadius = side * 0.43
            let returnRadius = side * 0.31

            ZStack {
                Canvas { context, _ in
                    drawBase(context: &context, center: center, natalRadius: natalRadius, returnRadius: returnRadius)
                }

                ForEach(0..<12, id: \.self) { index in
                    let longitude = Double(index * 30 + 15)
                    Text(SIGN_LABELS[index].split(separator: " ").first.map(String.init) ?? "")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .position(point(for: longitude, center: center, radius: natalRadius - 18))
                }

                ForEach(natalChart.bodies) { body in
                    wheelLabel(
                        text: symbol(for: body.label),
                        marker: "N",
                        color: .appAccentFill,
                        position: point(for: body.longitude, center: center, radius: natalRadius + 2)
                    )
                }

                ForEach(event.returnChart.bodies) { body in
                    wheelLabel(
                        text: symbol(for: body.label),
                        marker: "RL",
                        color: .appSecondaryAccent,
                        position: point(for: body.longitude, center: center, radius: returnRadius)
                    )
                }

                VStack(spacing: 4) {
                    Text("N")
                        .foregroundColor(.appAccentFill)
                    Text("RL")
                        .foregroundColor(.appSecondaryAccent)
                }
                .font(.caption.weight(.bold))
                .padding(7)
                .background(Color.appPanel)
                .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
            }
        }
        .background(Color.appSurface)
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(Color.appBorder, lineWidth: 1)
        )
    }

    private func wheelLabel(text: String, marker: String, color: Color, position: CGPoint) -> some View {
        ZStack(alignment: .topTrailing) {
            Text(text)
                .font(.caption.weight(.bold))
                .foregroundColor(.appPrimaryText)
                .frame(width: 26, height: 24)
                .background(Color.appPanel)
                .clipShape(RoundedRectangle(cornerRadius: 5, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 5, style: .continuous)
                        .stroke(color.opacity(0.8), lineWidth: 1)
                )
            Text(marker)
                .font(.system(size: 7, weight: .bold))
                .foregroundColor(.appAccentForeground)
                .frame(width: marker.count > 1 ? 15 : 11, height: 11)
                .background(color)
                .clipShape(Capsule())
                .offset(x: 5, y: -4)
        }
        .position(position)
    }

    private func drawBase(
        context: inout GraphicsContext,
        center: CGPoint,
        natalRadius: CGFloat,
        returnRadius: CGFloat
    ) {
        for radius in [natalRadius, returnRadius, natalRadius * 0.58] {
            context.stroke(
                Path(ellipseIn: CGRect(x: center.x - radius, y: center.y - radius, width: radius * 2, height: radius * 2)),
                with: .color(Color.appBorder),
                lineWidth: 1
            )
        }

        for index in 0..<12 {
            let longitude = Double(index * 30)
            var path = Path()
            path.move(to: point(for: longitude, center: center, radius: natalRadius * 0.58))
            path.addLine(to: point(for: longitude, center: center, radius: natalRadius))
            context.stroke(path, with: .color(Color.appBorder.opacity(0.55)), lineWidth: 1)
        }

        for cusp in event.returnChart.cusps {
            var path = Path()
            path.move(to: point(for: cusp, center: center, radius: returnRadius * 0.45))
            path.addLine(to: point(for: cusp, center: center, radius: returnRadius))
            context.stroke(path, with: .color(Color.appSecondaryAccent.opacity(0.35)), lineWidth: 1)
        }
    }

    private func point(for longitude: Double, center: CGPoint, radius: CGFloat) -> CGPoint {
        let radians = (longitude - 90) * .pi / 180
        return CGPoint(
            x: center.x + cos(radians) * radius,
            y: center.y + sin(radians) * radius
        )
    }

    private func symbol(for label: String) -> String {
        label.split(separator: " ").first.map(String.init) ?? label
    }
}

enum LunarReturnNoteBuilder {
    static func markdown(reading: LunarReturnReading, selectedEvent: LunarReturnEvent) -> String {
        var lines: [String] = [
            "# Revolución Lunar - \(lrDisplayName(reading.natalChart))",
            "",
            "## Datos",
            "- Carta natal: \(lrDisplayName(reading.natalChart)) · \(reading.natalChart.birthDate) \(reading.natalChart.birthTime) · \(reading.natalChart.placeName)",
            "- Lugar del retorno: \(reading.placeName)",
            "- Zona: \(reading.timezone)",
            "- Fecha base: \(noteDate(reading.startDate))",
            "- Luna natal: \(reading.natalMoon.formatted) · Casa \(reading.natalMoon.house)",
            "- Retornos calculados: \(reading.events.count)",
            "- Intensidad media: \(RevolutionTemplates.intensityStars(Int(reading.statistics.averageIntensity.rounded())))",
            "",
            "## Retorno seleccionado — #\(selectedEvent.index)",
            "",
            "**\(selectedEvent.intensityLabel)** \(RevolutionTemplates.intensityStars(selectedEvent.intensityScore))",
            "",
            selectedEvent.miniNarrative,
            "",
            "### Foco emocional",
            selectedEvent.moonFocusText,
            "",
            "### Tono del mes",
            selectedEvent.ascToneText,
            "",
            "### Datos del retorno",
            "- Fecha local: \(selectedEvent.exactLocalDateTime)",
            "- Fecha UTC: \(selectedEvent.exactUTCDateTime)",
            "- Luna: \(selectedEvent.moon.formatted) · Casa \(selectedEvent.moon.house)",
            "- ASC retorno: \(selectedEvent.returnChart.ascendant.formatted) (\(selectedEvent.ascSignLabel)) · Casa natal \(selectedEvent.natalHouseForReturnAsc)",
            "- MC retorno: \(selectedEvent.returnChart.mc.formatted) · Casa natal \(selectedEvent.natalHouseForReturnMC)",
            "",
            "## Tabla de retornos",
            "| # | Fecha | Luna | Casa | ASC retorno | Intensidad |",
            "| --- | --- | --- | --- | --- | --- |",
        ]

        for event in reading.events {
            lines.append(
                "| \(event.index) | \(event.exactLocalDateTime) | \(event.moon.formatted) | \(event.moon.house) | \(event.returnChart.ascendant.formatted) | \(RevolutionTemplates.intensityStars(event.intensityScore)) |"
            )
        }

        lines += [
            "",
            "## Aspectos dominantes",
        ]

        for aspect in selectedEvent.dominantAspects.prefix(10) {
            lines.append("- \(aspect.labelA) \(aspect.aspLabel) \(aspect.labelB), orbe \(String(format: "%.2f°", aspect.orb))")
        }

        lines += ["", "## Planetas del retorno en casas natales"]
        for placement in selectedEvent.returnPlanetsInNatalHouses {
            lines.append("- \(placement.planetLabel): casa natal \(placement.natalHouse), casa retorno \(placement.returnHouse), \(placement.formatted)")
        }

        return lines.joined(separator: "\n")
    }

    private static func noteDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.timeZone = TimeZone.current
        formatter.locale = Locale(identifier: "es_ES")
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: date)
    }
}

private func lrDisplayName(_ chart: NatalChart) -> String {
    chart.name.isEmpty ? chart.birthDate : chart.name
}
