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

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                headerSection
                Divider()
                personalSection
                Divider()
                dateTimeSection
                Divider()
                locationSection
                Divider()
                actionSection
            }
            .padding(28)
        }
        .background(Color.appBackground)
        .navigationTitle("Nueva Carta Natal")
    }

    // MARK: - Sections

    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Carta Natal")
                .font(.system(size: 28, weight: .light))
                .foregroundColor(.appPrimaryText)
            Text("Calcula tu carta natal con interpretaciones en castellano")
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
    }

    private var personalSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            label("Nombre (opcional)")
            TextField("Tu nombre o apodo", text: $name)
                .textFieldStyle(.roundedBorder)
                .frame(maxWidth: 360)
        }
    }

    private var dateTimeSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            label("Fecha y Hora de Nacimiento")
            HStack(spacing: 20) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Fecha").font(.caption).foregroundColor(.secondary)
                    DatePicker("", selection: $birthDate, displayedComponents: .date)
                        .labelsHidden()
                        .datePickerStyle(.compact)
                }
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
                VStack(alignment: .leading, spacing: 6) {
                    Text("Zona IANA").font(.caption).foregroundColor(.secondary)
                    TextField("Europe/Madrid", text: $timezone)
                        .textFieldStyle(.roundedBorder)
                        .frame(width: 200)
                        .autocorrectionDisabled()
                }
            }
        }
    }

    private var locationSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            label("Lugar de Nacimiento")
            HStack {
                TextField("Ciudad, país…", text: $placeQuery)
                    .textFieldStyle(.roundedBorder)
                    .frame(maxWidth: 300)
                    .onChange(of: placeQuery) { _, q in
                        Task { await searchPlaces(q) }
                    }
                if !placeQuery.isEmpty {
                    Button("✕") { placeQuery = ""; placeResults = [] }
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
                .cornerRadius(8)
                .shadow(radius: 4)
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
    }

    // MARK: - Helpers

    private func label(_ text: String) -> some View {
        Text(text)
            .font(.headline)
            .foregroundColor(.appPrimaryText)
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
            // Mensaje efímero: se borra a los 4s
            let thisChart = chart.name
            DispatchQueue.main.asyncAfter(deadline: .now() + 4) {
                if lastCalculated == thisChart { lastCalculated = nil }
            }
        } catch {
            errorMsg = error.localizedDescription
        }
        isCalculating = false
    }
}
