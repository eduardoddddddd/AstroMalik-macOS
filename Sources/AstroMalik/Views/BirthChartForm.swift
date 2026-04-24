import SwiftUI

struct BirthChartForm: View {
    @EnvironmentObject var appState: AppState

    var onChartCalculated: (NatalChart) -> Void

    @State private var name        = ""
    @State private var birthDate   = Date()
    @State private var birthHour   = 12
    @State private var birthMinute = 0
    @State private var timezone    = "Europe/Madrid"
    @State private var placeName   = ""
    @State private var latitude    = 40.4168
    @State private var longitude   = -3.7038
    @State private var placeQuery  = ""
    @State private var placeResults: [Place] = []
    @State private var selectedPlace: Place? = nil

    @State private var isCalculating = false
    @State private var errorMsg: String? = nil
    @State private var lastCalculated: String? = nil
    @State private var lastCalculatedTask: Task<Void, Never>? = nil

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                headerSection
                formLayout
            }
            .padding(28)
            .frame(maxWidth: 1080, alignment: .leading)
        }
        .background(Color.appBackground)
        .navigationTitle("Nueva Carta Natal")
        .onDisappear {
            lastCalculatedTask?.cancel()
            lastCalculatedTask = nil
        }
    }

    // MARK: - Sections

    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Carta Natal")
                .font(.system(size: 30, weight: .semibold))
                .foregroundColor(.appPrimaryText)
            Text("Calcula tu carta natal con interpretaciones en castellano")
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
    }

    private var formLayout: some View {
        ViewThatFits(in: .horizontal) {
            HStack(alignment: .top, spacing: 20) {
                primaryColumn
                    .frame(minWidth: 330, maxWidth: 480, alignment: .topLeading)
                secondaryColumn
                    .frame(minWidth: 330, maxWidth: 520, alignment: .topLeading)
            }

            VStack(alignment: .leading, spacing: 16) {
                primaryColumn
                secondaryColumn
            }
        }
    }

    private var primaryColumn: some View {
        VStack(alignment: .leading, spacing: 16) {
            personalSection
            dateTimeSection
        }
    }

    private var secondaryColumn: some View {
        VStack(alignment: .leading, spacing: 16) {
            locationSection
            actionSection
        }
    }

    private var personalSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            label("Nombre (opcional)")
            TextField("Tu nombre o apodo", text: $name)
                .textFieldStyle(.roundedBorder)
                .frame(maxWidth: .infinity)
        }
        .appCard()
    }

    private var dateTimeSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            label("Fecha y Hora de Nacimiento")
            Grid(alignment: .leading, horizontalSpacing: 18, verticalSpacing: 14) {
                GridRow {
                    dateField
                    timeField
                }
                GridRow {
                    timezoneField
                        .gridCellColumns(2)
                }
            }
        }
        .appCard()
    }

    private var dateField: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Fecha").font(.caption).foregroundColor(.secondary)
            DatePicker("", selection: $birthDate, displayedComponents: .date)
                .labelsHidden()
                .datePickerStyle(.compact)
        }
    }

    private var timeField: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Hora").font(.caption).foregroundColor(.secondary)
            HStack {
                Picker("H", selection: $birthHour) {
                    ForEach(0..<24, id: \.self) { h in
                        Text(String(format: "%02d", h)).tag(h)
                    }
                }
                .frame(width: 70)
                Text(":").font(.title3)
                Picker("M", selection: $birthMinute) {
                    ForEach(0..<60, id: \.self) { m in
                        Text(String(format: "%02d", m)).tag(m)
                    }
                }
                .frame(width: 70)
            }
            .pickerStyle(.menu)
        }
    }

    private var timezoneField: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Zona IANA").font(.caption).foregroundColor(.secondary)
            TextField("Europe/Madrid", text: $timezone)
                .textFieldStyle(.roundedBorder)
                .frame(maxWidth: .infinity)
                .autocorrectionDisabled()
        }
    }

    private var locationSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            label("Lugar de Nacimiento")
            HStack {
                TextField("Ciudad, país…", text: $placeQuery)
                    .textFieldStyle(.roundedBorder)
                    .frame(maxWidth: .infinity)
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
            if !placeResults.isEmpty {
                VStack(alignment: .leading, spacing: 0) {
                    ForEach(placeResults) { place in
                        Button {
                            selectPlace(place)
                        } label: {
                            HStack {
                                Text(place.displayName)
                                    .font(.subheadline)
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
                .background(Color.appBackground)
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .stroke(Color.appBorder, lineWidth: 1)
                )
                .frame(maxWidth: 500)
            }
            if selectedPlace != nil || !placeName.isEmpty {
                HStack(spacing: 16) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Latitud").font(.caption).foregroundColor(.secondary)
                        TextField("Lat", value: $latitude, format: .number.precision(.fractionLength(4)))
                            .textFieldStyle(.roundedBorder)
                            .frame(width: 120)
                    }
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Longitud").font(.caption).foregroundColor(.secondary)
                        TextField("Lon", value: $longitude, format: .number.precision(.fractionLength(4)))
                            .textFieldStyle(.roundedBorder)
                            .frame(width: 120)
                    }
                }
            }
        }
        .appCard()
    }

    private var actionSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            if let err = errorMsg {
                Label(err, systemImage: "exclamationmark.triangle.fill")
                    .foregroundColor(.red)
                    .font(.subheadline)
            }
            if let ok = lastCalculated {
                Label("Carta cargada en el panel: \(ok)", systemImage: "checkmark.circle.fill")
                    .foregroundColor(.appPrimaryText)
                    .font(.subheadline)
                    .transition(.opacity)
            }
            Button {
                Task { await calculate() }
            } label: {
                HStack {
                    if isCalculating {
                        ProgressView().controlSize(.small)
                    }
                    Text("Calcular Carta Natal")
                        .fontWeight(.medium)
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 10)
            }
            .buttonStyle(.borderedProminent)
            .tint(.appAccentFill)
            .disabled(isCalculating)
            .keyboardShortcut(.return, modifiers: [.command])
        }
        .appCard()
    }

    // MARK: - Helpers

    private func label(_ text: String) -> some View {
        Text(text)
            .appSectionHeader()
    }

    private func searchPlaces(_ query: String) async {
        guard query.count > 1 else { placeResults = []; return }
        placeResults = await appState.placesService.search(query: query)
    }

    private func selectPlace(_ place: Place) {
        selectedPlace = place
        placeName = place.name
        latitude = place.latitude
        longitude = place.longitude
        timezone = place.timezone
        placeQuery = place.displayName
        placeResults = []
    }

    private func calculate() async {
        isCalculating = true
        errorMsg = nil
        do {
            let cal = Calendar(identifier: .gregorian)
            let y = cal.component(.year, from: birthDate)
            let m = cal.component(.month, from: birthDate)
            let d = cal.component(.day, from: birthDate)
            let dateStr = String(format: "%04d-%02d-%02d", y, m, d)
            let timeStr = String(format: "%02d:%02d", birthHour, birthMinute)

            let jdResult = try julianDayFromLocal(
                birthDate: dateStr,
                birthTime: timeStr,
                timezoneName: timezone
            )
            var chart = try AstroEngine.computeNatalChart(
                jd: jdResult.jd,
                lat: latitude,
                lon: longitude
            )
            chart = NatalChart(
                id: UUID(),
                name: name.isEmpty ? "Carta \(dateStr)" : name,
                birthDate: dateStr,
                birthTime: timeStr,
                timezone: timezone,
                latitude: latitude,
                longitude: longitude,
                placeName: placeName,
                houseSystem: "Placidus",
                ascendant: chart.ascendant,
                mc: chart.mc,
                cusps: chart.cusps,
                bodies: chart.bodies
            )
            onChartCalculated(chart)
            lastCalculated = chart.name
            let thisChart = chart.name
            lastCalculatedTask?.cancel()
            lastCalculatedTask = Task {
                try? await Task.sleep(nanoseconds: 4_000_000_000)
                guard !Task.isCancelled else { return }
                if lastCalculated == thisChart { lastCalculated = nil }
            }
        } catch {
            errorMsg = error.localizedDescription
        }
        isCalculating = false
    }
}
