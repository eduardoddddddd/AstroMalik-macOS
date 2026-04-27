import SwiftUI

private enum SolarReturnMode: String, CaseIterable, Identifiable {
    case summary = "Resumen"
    case guided = "Lectura"
    case wheel = "Rueda"
    case overlay = "Superposición"
    case texts = "Textos"

    var id: String { rawValue }
}

struct SolarReturnView: View {
    @EnvironmentObject var appState: AppState

    @State private var chartID: UUID?
    @State private var year = Calendar.current.component(.year, from: Date())
    @State private var placeQuery = ""
    @State private var placeName = "Madrid"
    @State private var latitude = 40.4168
    @State private var longitude = -3.7038
    @State private var timezone = "Europe/Madrid"
    @State private var placeResults: [Place] = []
    @State private var reading: SolarReturnReading?
    @State private var selectedMode: SolarReturnMode = .summary
    @State private var selectedFocusKey: String? = "ASC"
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

    var body: some View {
        Group {
            if charts.isEmpty { emptyState } else { workspace }
        }
        .background(Color.appBackground)
        .navigationTitle("Revolución Solar")
        .onAppear(perform: ensureInitialSelection)
        .onChange(of: charts) { _, _ in ensureInitialSelection() }
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
                ProgressView("Calculando revolución solar…")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if let reading {
                resultView(reading)
            } else {
                readyState
            }
        }
    }

    // MARK: - Controls

    private var controls: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .bottom, spacing: 14) {
                VStack(alignment: .leading, spacing: 5) {
                    Text("Carta natal")
                        .font(.caption.weight(.semibold))
                        .foregroundColor(.secondary)
                    Picker("Carta natal", selection: $chartID) {
                        ForEach(charts) { chart in
                            Text(srDisplayName(chart)).tag(Optional(chart.id))
                        }
                    }
                    .labelsHidden()
                    .frame(width: 220)
                }

                VStack(alignment: .leading, spacing: 5) {
                    Text("Año")
                        .font(.caption.weight(.semibold))
                        .foregroundColor(.secondary)
                    Stepper(value: $year, in: 1800...2399) {
                        Text(String(year))
                            .font(.body.monospacedDigit())
                            .frame(width: 52, alignment: .leading)
                    }
                    .frame(width: 140)
                }

                locationPicker
                Spacer()
                Button {
                    calculate()
                } label: {
                    Label("Calcular", systemImage: "sun.max")
                }
                .buttonStyle(.borderedProminent)
                .tint(.appAccentFill)
                .disabled(selectedChart == nil || isCalculating)
            }

            if !placeResults.isEmpty { placeResultsList }
            feedback
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 14)
        .background(Color.appPanel)
    }

    private var locationPicker: some View {
        VStack(alignment: .leading, spacing: 5) {
            Text("Lugar de revolución")
                .font(.caption.weight(.semibold))
                .foregroundColor(.secondary)
            HStack(spacing: 8) {
                TextField("Ciudad, país…", text: $placeQuery)
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 260)
                    .onChange(of: placeQuery) { _, q in
                        Task { await searchPlaces(q) }
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
                Button { selectPlace(place) } label: {
                    HStack {
                        Text(place.displayName)
                        Spacer()
                        Text(place.timezone).font(.caption).foregroundColor(.secondary)
                    }
                    .padding(.horizontal, 12).padding(.vertical, 7)
                }
                .buttonStyle(.plain).background(Color.appPanel)
                Divider()
            }
        }
        .frame(maxWidth: 560)
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 8, style: .continuous).stroke(Color.appBorder, lineWidth: 1))
    }

    private var feedback: some View {
        VStack(alignment: .leading, spacing: 6) {
            if let statusMessage {
                Label(statusMessage, systemImage: "checkmark.circle.fill")
                    .font(.caption).foregroundColor(.appSecondaryAccent)
            }
            if let errorMessage {
                Label(errorMessage, systemImage: "exclamationmark.triangle.fill")
                    .font(.caption).foregroundColor(.red)
            }
            Text("\(placeName) · \(timezone) · \(String(format: "%.4f", latitude)), \(String(format: "%.4f", longitude))")
                .font(.caption).foregroundColor(.secondary)
        }
    }

    // MARK: - Result View

    private func resultView(_ reading: SolarReturnReading) -> some View {
        VStack(spacing: 0) {
            resultHeader(reading)
            Divider()
            Picker("Vista", selection: $selectedMode) {
                ForEach(SolarReturnMode.allCases) { mode in
                    Text(mode.rawValue).tag(mode)
                }
            }
            .pickerStyle(.segmented)
            .frame(maxWidth: 560)
            .padding(12)
            Divider()

            switch selectedMode {
            case .summary:
                summaryPanel(reading)
            case .guided:
                guidedReadingPanel(reading)
            case .wheel:
                ScrollView {
                    VStack(spacing: 14) {
                        NatalWheelView(chart: reading.solarChart, selectedKey: $selectedFocusKey)
                            .frame(minHeight: 460)
                        focusCard(reading)
                    }.padding(18)
                }
            case .overlay:
                ScrollView {
                    SolarReturnOverlayWheelView(reading: reading)
                        .frame(minHeight: 520).padding(18)
                }
            case .texts:
                InterpretacionesView(interpretaciones: reading.interpretations)
            }
        }
    }

    private func resultHeader(_ reading: SolarReturnReading) -> some View {
        HStack(alignment: .top, spacing: 16) {
            VStack(alignment: .leading, spacing: 6) {
                Text("Revolución Solar \(reading.year) — \(srDisplayName(reading.natalChart))")
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundColor(.appPrimaryText).lineLimit(1)
                HStack(spacing: 12) {
                    Label(reading.exactLocalDateTime, systemImage: "clock")
                    Label(reading.placeName, systemImage: "mappin")
                }
                .font(.caption).foregroundColor(.secondary).lineLimit(1)
            }
            Spacer()
            Button { createJoplinNote(reading) } label: {
                if isCreatingNote { ProgressView().controlSize(.small) }
                else { Label("Crear nota Joplin", systemImage: "note.text.badge.plus") }
            }
            .buttonStyle(.bordered).disabled(isCreatingNote)
        }
        .padding(.horizontal, 18).padding(.vertical, 12)
        .background(Color.appSurface)
    }

    // MARK: - Summary Panel (NEW)

    private func summaryPanel(_ reading: SolarReturnReading) -> some View {
        ScrollView {
            VStack(spacing: 16) {
                // Hero card
                VStack(alignment: .leading, spacing: 14) {
                    HStack(spacing: 12) {
                        Image(systemName: "sun.max.fill")
                            .font(.system(size: 28))
                            .foregroundColor(.appAccentFill)
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Tema del año: \(reading.yearThemeTitle)")
                                .font(.title3.weight(.semibold))
                                .foregroundColor(.appPrimaryText)
                            Text("Casa natal \(reading.natalHouseForSolarAsc)")
                                .font(.caption).foregroundColor(.secondary)
                        }
                    }
                    Text(reading.yearThemeText)
                        .font(.subheadline).foregroundColor(.appPrimaryText)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .appCard()

                // Key data
                VStack(alignment: .leading, spacing: 10) {
                    Text("Datos clave").appSectionHeader()
                    solarRow("↗ ASC revolución", "\(reading.solarChart.ascendant.formatted)")
                    solarRow("🏠 En casa natal", "Casa \(reading.natalHouseForSolarAsc)")
                    solarRow("🌙 Luna RS", "\(reading.moonFormatted) · Casa \(reading.moonHouse)")
                    solarRow("♄ Regente ASC", "\(reading.rulerLabel) · Casa natal \(reading.rulerNatalHouse)")
                    solarRow("MC revolución", "\(reading.solarChart.mc.formatted) · Casa natal \(reading.natalHouseForSolarMC)")
                    solarRow("📅 Retorno exacto", reading.exactLocalDateTime)
                    solarRow("UTC", reading.exactUTCDateTime)
                }
                .appCard()

                // Angular planets
                if !reading.angularPlanets.isEmpty {
                    VStack(alignment: .leading, spacing: 10) {
                        Text("Planetas en casas angulares").appSectionHeader()
                        Text("Los protagonistas del año — planetas en las casas de acción (1, 4, 7, 10).")
                            .font(.caption).foregroundColor(.secondary)
                        ForEach(reading.angularPlanets) { planet in
                            HStack {
                                Text(planet.planetLabel)
                                    .frame(width: 110, alignment: .leading)
                                Text("Casa solar \(planet.solarHouse)")
                                Spacer()
                                Text("Casa natal \(planet.natalHouse)")
                                    .foregroundColor(.secondary)
                            }.font(.subheadline)
                        }
                    }
                    .appCard()
                }

                // Natal repetitions
                if !reading.natalRepetitions.isEmpty {
                    VStack(alignment: .leading, spacing: 10) {
                        Text("Repeticiones natal–solar").appSectionHeader()
                        Text("Planetas que caen en la misma casa natal que en tu carta de nacimiento — temas que se reactivan.")
                            .font(.caption).foregroundColor(.secondary)
                        ForEach(reading.natalRepetitions) { rep in
                            HStack {
                                Text(rep.planetLabel)
                                    .frame(width: 110, alignment: .leading)
                                Text("Casa \(rep.house)")
                                Spacer()
                                Text(rep.formatted).font(.caption).foregroundColor(.secondary)
                            }.font(.subheadline)
                        }
                    }
                    .appCard()
                }
            }
            .padding(18)
        }
    }

    // MARK: - Guided Reading Panel (NEW)

    private func guidedReadingPanel(_ reading: SolarReturnReading) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                readingBlock("Tema del año", systemImage: "house.fill",
                             subtitle: "ASC de revolución en casa natal \(reading.natalHouseForSolarAsc)") {
                    Text(reading.yearThemeText)
                        .font(.subheadline).foregroundColor(.appPrimaryText)
                }

                readingBlock("Tono del año", systemImage: "paintbrush.fill",
                             subtitle: "ASC de revolución en \(reading.ascSignLabel)") {
                    Text(reading.yearToneText)
                        .font(.subheadline).foregroundColor(.appPrimaryText)
                }

                readingBlock("Regente del ASC de revolución", systemImage: "key.fill",
                             subtitle: "\(reading.rulerLabel) en casa natal \(reading.rulerNatalHouse)") {
                    Text(reading.rulerText)
                        .font(.subheadline).foregroundColor(.appPrimaryText)
                }

                readingBlock("Luna de revolución", systemImage: "moon.fill",
                             subtitle: "\(reading.moonFormatted) · Casa \(reading.moonHouse)") {
                    Text(reading.moonText)
                        .font(.subheadline).foregroundColor(.appPrimaryText)
                }

                readingBlock("Ejes del año", systemImage: "scope") {
                    summaryRows(reading)
                }

                readingBlock("Planetas en casas natales", systemImage: "arrow.triangle.swap") {
                    ForEach(reading.solarPlanetsInNatalHouses) { placement in
                        HStack {
                            Text(placement.planetLabel).frame(width: 110, alignment: .leading)
                            Text("Casa natal \(placement.natalHouse)")
                            Spacer()
                            Text("Casa solar \(placement.solarHouse)").foregroundColor(.secondary)
                        }.font(.subheadline)
                    }
                }

                readingBlock("Aspectos dominantes", systemImage: "line.diagonal") {
                    ForEach(reading.dominantAspects) { aspect in
                        HStack {
                            Text("\(aspect.labelA) \(aspect.aspLabel) \(aspect.labelB)")
                            Spacer()
                            Text(String(format: "%.2f°", aspect.orb))
                                .font(.caption.monospacedDigit()).foregroundColor(.secondary)
                        }.font(.subheadline)
                    }
                }
            }
            .padding(18)
        }
    }

    private func readingBlock<Content: View>(
        _ title: String,
        systemImage: String,
        subtitle: String? = nil,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Label(title, systemImage: systemImage).appSectionHeader()
            if let subtitle {
                Text(subtitle).font(.caption).foregroundColor(.secondary)
            }
            content()
        }
        .appCard()
    }

    // MARK: - Shared Helpers

    private func focusCard(_ reading: SolarReturnReading) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Resumen técnico").appSectionHeader()
            summaryRows(reading)
        }
        .appCard()
    }

    private func summaryRows(_ reading: SolarReturnReading) -> some View {
        VStack(alignment: .leading, spacing: 7) {
            solarRow("ASC revolución", "\(reading.solarChart.ascendant.formatted) · Casa natal \(reading.natalHouseForSolarAsc)")
            solarRow("MC revolución", "\(reading.solarChart.mc.formatted) · Casa natal \(reading.natalHouseForSolarMC)")
            solarRow("Fecha UTC", reading.exactUTCDateTime)
            solarRow("Lugar", "\(reading.placeName) · \(reading.timezone)")
        }
    }

    private func solarRow(_ title: String, _ value: String) -> some View {
        HStack(alignment: .firstTextBaseline) {
            Text(title).frame(width: 130, alignment: .leading).foregroundColor(.secondary)
            Text(value).foregroundColor(.appPrimaryText)
            Spacer()
        }
        .font(.subheadline)
    }

    // MARK: - Empty States

    private var readyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "sun.max.circle")
                .font(.system(size: 44)).foregroundColor(.secondary)
            Text("Revolución Solar")
                .font(.headline).foregroundColor(.appPrimaryText)
            Text("La revolución solar muestra los temas principales de tu año astrológico, desde tu cumpleaños hasta el siguiente. Elige carta, año y lugar para calcular.")
                .font(.subheadline).foregroundColor(.secondary)
                .multilineTextAlignment(.center).frame(maxWidth: 400)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "sun.max.trianglebadge.exclamationmark")
                .font(.system(size: 48)).foregroundColor(.secondary)
            Text("Necesitas una carta guardada").font(.headline).foregroundColor(.secondary)
            Text("Guarda una carta natal para calcular su revolución solar.")
                .font(.subheadline).foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Actions

    private func ensureInitialSelection() {
        guard let first = charts.first else { chartID = nil; reading = nil; return }
        if chartID == nil || !charts.contains(where: { $0.id == chartID }) { chartID = first.id }
    }

    private func searchPlaces(_ query: String) async {
        guard query.count > 1 else { placeResults = []; return }
        placeResults = await appState.placesService.search(query: query)
    }

    private func selectPlace(_ place: Place) {
        placeName = place.name; latitude = place.latitude; longitude = place.longitude
        timezone = place.timezone; placeQuery = place.displayName; placeResults = []; reading = nil
    }

    private func calculate() {
        guard let selectedChart else { return }
        calculationTask?.cancel(); statusMessage = nil; errorMessage = nil; isCalculating = true
        let request = SolarReturnRequest(
            natalChart: selectedChart, year: year, placeName: placeName,
            latitude: latitude, longitude: longitude, timezone: timezone
        )
        let store = appState.corpusStore
        calculationTask = Task {
            do {
                let worker = Task.detached(priority: .userInitiated) {
                    try SolarReturnEngine.calculate(request: request, corpusStore: store)
                }
                let result = try await withTaskCancellationHandler {
                    try await worker.value
                } onCancel: { worker.cancel() }
                guard !Task.isCancelled else { return }
                reading = result
            } catch {
                guard !Task.isCancelled else { return }
                errorMessage = error.localizedDescription
            }
            if !Task.isCancelled { isCalculating = false }
        }
    }

    private func createJoplinNote(_ reading: SolarReturnReading) {
        noteTask?.cancel(); statusMessage = nil; errorMessage = nil; isCreatingNote = true
        let settings = appState.joplinSettings
        noteTask = Task {
            do {
                let service = JoplinClipperService(settings: settings)
                try await service.createNote(
                    title: "Revolución Solar \(reading.year) - \(srDisplayName(reading.natalChart))",
                    body: SolarReturnNoteBuilder.markdown(reading: reading)
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
}

// MARK: - Overlay Wheel

private struct SolarReturnOverlayWheelView: View {
    let reading: SolarReturnReading

    var body: some View {
        GeometryReader { proxy in
            let side = min(proxy.size.width, proxy.size.height)
            let center = CGPoint(x: proxy.size.width / 2, y: proxy.size.height / 2)
            let natalRadius = side * 0.43
            let solarRadius = side * 0.31

            ZStack {
                Canvas { context, _ in
                    drawBase(context: &context, center: center, natalRadius: natalRadius, solarRadius: solarRadius)
                }
                ForEach(0..<12, id: \.self) { index in
                    let longitude = Double(index * 30 + 15)
                    Text(SIGN_LABELS[index].split(separator: " ").first.map(String.init) ?? "")
                        .font(.caption).foregroundColor(.secondary)
                        .position(point(for: longitude, center: center, radius: natalRadius - 18))
                }
                ForEach(reading.natalChart.bodies) { body in
                    wheelLabel(text: body.symbol, marker: "N", color: .appAccentFill,
                               position: point(for: body.longitude, center: center, radius: natalRadius + 2))
                }
                ForEach(reading.solarChart.bodies) { body in
                    wheelLabel(text: body.symbol, marker: "RS", color: .appSecondaryAccent,
                               position: point(for: body.longitude, center: center, radius: solarRadius))
                }
                VStack(spacing: 4) {
                    Text("N").foregroundColor(.appAccentFill)
                    Text("RS").foregroundColor(.appSecondaryAccent)
                }
                .font(.caption.weight(.bold)).padding(7)
                .background(Color.appPanel)
                .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
            }
        }
        .background(Color.appSurface)
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 8, style: .continuous).stroke(Color.appBorder, lineWidth: 1))
    }

    private func wheelLabel(text: String, marker: String, color: Color, position: CGPoint) -> some View {
        ZStack(alignment: .topTrailing) {
            Text(text).font(.caption.weight(.bold)).foregroundColor(.appPrimaryText)
                .frame(width: 26, height: 24).background(Color.appPanel)
                .clipShape(RoundedRectangle(cornerRadius: 5, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 5, style: .continuous).stroke(color.opacity(0.8), lineWidth: 1))
            Text(marker).font(.system(size: 7, weight: .bold)).foregroundColor(.appAccentForeground)
                .frame(width: marker.count > 1 ? 15 : 11, height: 11).background(color)
                .clipShape(Capsule()).offset(x: 5, y: -4)
        }.position(position)
    }

    private func drawBase(context: inout GraphicsContext, center: CGPoint, natalRadius: CGFloat, solarRadius: CGFloat) {
        for radius in [natalRadius, solarRadius, natalRadius * 0.58] {
            context.stroke(
                Path(ellipseIn: CGRect(x: center.x - radius, y: center.y - radius, width: radius * 2, height: radius * 2)),
                with: .color(Color.appBorder), lineWidth: 1)
        }
        for index in 0..<12 {
            let longitude = Double(index * 30)
            var path = Path()
            path.move(to: point(for: longitude, center: center, radius: natalRadius * 0.58))
            path.addLine(to: point(for: longitude, center: center, radius: natalRadius))
            context.stroke(path, with: .color(Color.appBorder.opacity(0.55)), lineWidth: 1)
        }
        for cusp in reading.solarChart.cusps {
            var path = Path()
            path.move(to: point(for: cusp, center: center, radius: solarRadius * 0.45))
            path.addLine(to: point(for: cusp, center: center, radius: solarRadius))
            context.stroke(path, with: .color(Color.appSecondaryAccent.opacity(0.35)), lineWidth: 1)
        }
    }

    private func point(for longitude: Double, center: CGPoint, radius: CGFloat) -> CGPoint {
        let radians = (longitude - 90) * .pi / 180
        return CGPoint(x: center.x + cos(radians) * radius, y: center.y + sin(radians) * radius)
    }
}

// MARK: - Note Builder

enum SolarReturnNoteBuilder {
    static func markdown(reading: SolarReturnReading) -> String {
        var lines: [String] = [
            "# Revolución Solar \(reading.year) - \(srDisplayName(reading.natalChart))",
            "",
            "## Tema del año",
            "**\(reading.yearThemeTitle)** (ASC RS en casa natal \(reading.natalHouseForSolarAsc))",
            "", reading.yearThemeText,
            "",
            "## Tono del año",
            "ASC RS en \(reading.ascSignLabel)",
            "", reading.yearToneText,
            "",
            "## Regente del ASC de revolución",
            "\(reading.rulerLabel) en casa natal \(reading.rulerNatalHouse)",
            "", reading.rulerText,
            "",
            "## Luna de revolución",
            "\(reading.moonFormatted) · Casa \(reading.moonHouse)",
            "", reading.moonText,
            "",
            "## Datos",
            "- Carta natal: \(srDisplayName(reading.natalChart)) · \(reading.natalChart.birthDate) \(reading.natalChart.birthTime) · \(reading.natalChart.placeName)",
            "- Lugar de revolución: \(reading.placeName)",
            "- Zona: \(reading.timezone)",
            "- Retorno exacto: \(reading.exactLocalDateTime)",
            "- UTC: \(reading.exactUTCDateTime)",
            "- ASC revolución: \(reading.solarChart.ascendant.formatted) · Casa natal \(reading.natalHouseForSolarAsc)",
            "- MC revolución: \(reading.solarChart.mc.formatted) · Casa natal \(reading.natalHouseForSolarMC)",
            "",
            "## Planetas de revolución en casas natales",
        ]

        for placement in reading.solarPlanetsInNatalHouses {
            lines.append("- \(placement.planetLabel): casa natal \(placement.natalHouse), casa solar \(placement.solarHouse), \(placement.formatted)")
        }

        if !reading.interpretations.isEmpty {
            lines += ["", "## Textos principales"]
            for interpretation in reading.interpretations.prefix(8) {
                lines.append("- \(interpretation.titulo): \(interpretation.texto)")
            }
        }

        lines += ["", "## Aspectos dominantes"]
        for aspect in reading.dominantAspects.prefix(8) {
            lines.append("- \(aspect.labelA) \(aspect.aspLabel) \(aspect.labelB), orbe \(String(format: "%.2f°", aspect.orb))")
        }

        if !reading.angularPlanets.isEmpty {
            lines += ["", "## Planetas en casas angulares"]
            for planet in reading.angularPlanets {
                lines.append("- \(planet.planetLabel): casa solar \(planet.solarHouse), casa natal \(planet.natalHouse)")
            }
        }

        if !reading.natalRepetitions.isEmpty {
            lines += ["", "## Repeticiones natal–solar"]
            for rep in reading.natalRepetitions {
                lines.append("- \(rep.planetLabel): casa \(rep.house)")
            }
        }

        return lines.joined(separator: "\n")
    }
}

private func srDisplayName(_ chart: NatalChart) -> String {
    chart.name.isEmpty ? chart.birthDate : chart.name
}

private extension PlanetBody {
    var symbol: String {
        label.split(separator: " ").first.map(String.init) ?? label
    }
}
