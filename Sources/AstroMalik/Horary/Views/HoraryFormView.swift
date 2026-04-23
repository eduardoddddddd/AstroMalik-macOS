import SwiftUI

private enum HoraryHousePreset: String, CaseIterable, Identifiable {
    case trabajo = "Trabajo nuevo / posición / empresa"
    case mudanza = "Mudanza / hogar / inmueble"
    case pareja = "Pareja / sociedad / acuerdo"
    case noticias = "Noticias / mensaje / hermanos"
    case dinero = "Dinero propio / posesiones"
    case salud = "Salud / empleados / rutinas"
    case viaje = "Viaje largo / extranjero / estudios"
    case hijos = "Hijos / creatividad / placer"
    case amistades = "Amistades / esperanzas / grupos"
    case enemigos = "Enemigos ocultos / encierros"
    case padre = "Padre / final / inmueble paterno"
    case herencia = "Herencia / muerte / dinero ajeno"
    case otra = "Otra (eliges casa libre)"

    var id: String { rawValue }

    var house: Int? {
        switch self {
        case .trabajo: return 10
        case .mudanza: return 4
        case .pareja: return 7
        case .noticias: return 3
        case .dinero: return 2
        case .salud: return 6
        case .viaje: return 9
        case .hijos: return 5
        case .amistades: return 11
        case .enemigos: return 12
        case .padre: return 4
        case .herencia: return 8
        case .otra: return nil
        }
    }
}

struct HoraryFormView: View {
    @EnvironmentObject var appState: AppState
    var onQueryCalculated: (SavedHoraryQuery) -> Void

    @State private var question = ""
    @State private var askedAt = Date()
    @State private var timezone = "Europe/Madrid"
    @State private var placeName = "Órgiva, Granada, España"
    @State private var latitude = 36.8988
    @State private var longitude = -3.4205
    @State private var placeQuery = ""
    @State private var placeResults: [Place] = []
    @State private var preset: HoraryHousePreset = .trabajo
    @State private var questionHouse = 10
    @State private var includeFortune = true

    @State private var isCalculating = false
    @State private var errorMsg: String? = nil
    @State private var lastCalculated: String? = nil

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                headerSection
                Divider()
                questionSection
                Divider()
                dateTimeSection
                Divider()
                locationSection
                Divider()
                houseSection
                Divider()
                actionSection
            }
            .padding(28)
        }
        .background(Color.appBackground)
        .onChange(of: preset) { _, newPreset in
            if let house = newPreset.house {
                questionHouse = house
            }
        }
    }

    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Consulta Horaria")
                .font(.system(size: 28, weight: .light))
                .foregroundColor(.appPrimaryText)
            Text("Calcula el juicio horario en Python y léelo en el panel principal de AstroMalik.")
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
    }

    private var questionSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            label("Pregunta")
            TextEditor(text: $question)
                .frame(minHeight: 110)
                .padding(10)
                .background(Color.appInputBackground.opacity(0.92))
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color.appBorder.opacity(0.8), lineWidth: 1)
                )
            Text("Sé preciso: la formulación de la pregunta condiciona el juicio.")
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }

    private var dateTimeSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            label("Fecha y Hora de la Pregunta")
            HStack(spacing: 20) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Fecha").font(.caption).foregroundColor(.secondary)
                    DatePicker("", selection: $askedAt, displayedComponents: .date)
                        .labelsHidden()
                        .datePickerStyle(.compact)
                }
                VStack(alignment: .leading, spacing: 6) {
                    Text("Hora").font(.caption).foregroundColor(.secondary)
                    DatePicker("", selection: $askedAt, displayedComponents: .hourAndMinute)
                        .labelsHidden()
                        .datePickerStyle(.compact)
                }
                VStack(alignment: .leading, spacing: 6) {
                    Text("Zona IANA").font(.caption).foregroundColor(.secondary)
                    TextField("Europe/Madrid", text: $timezone)
                        .textFieldStyle(.roundedBorder)
                        .frame(width: 220)
                        .autocorrectionDisabled()
                }
            }
        }
    }

    private var locationSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            label("Lugar de la Pregunta")
            HStack {
                TextField("Ciudad, país…", text: $placeQuery)
                    .textFieldStyle(.roundedBorder)
                    .frame(maxWidth: 320)
                    .onChange(of: placeQuery) { _, q in
                        Task { await searchPlaces(q) }
                    }
                if !placeQuery.isEmpty {
                    Button("✕") {
                        placeQuery = ""
                        placeResults = []
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
                .cornerRadius(8)
                .shadow(radius: 4)
                .frame(maxWidth: 520)
            }
            HStack(spacing: 16) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Lugar").font(.caption).foregroundColor(.secondary)
                    TextField("Órgiva, Granada, España", text: $placeName)
                        .textFieldStyle(.roundedBorder)
                        .frame(width: 320)
                }
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

    private var houseSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            label("Asunto y Casa")
            Picker("Preset", selection: $preset) {
                ForEach(HoraryHousePreset.allCases) { item in
                    Text(item.rawValue).tag(item)
                }
            }
            .pickerStyle(.menu)
            .frame(maxWidth: 440, alignment: .leading)

            if preset == .otra {
                Picker("Casa", selection: $questionHouse) {
                    ForEach(1...12, id: \.self) { house in
                        Text("Casa \(house)").tag(house)
                    }
                }
                .pickerStyle(.segmented)
                .frame(maxWidth: 560)
            } else {
                Text("Casa seleccionada: \(questionHouse)")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }

            Toggle("Incluir Parte de Fortuna", isOn: $includeFortune)
                .toggleStyle(.switch)
                .controlSize(.small)
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
                Label("Consulta cargada en el panel: \(ok)", systemImage: "checkmark.circle.fill")
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
                    Text("Calcular Consulta Horaria")
                        .fontWeight(.medium)
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 10)
            }
            .buttonStyle(.borderedProminent)
            .tint(.appAccentFill)
            .disabled(isCalculating)
        }
    }

    private func label(_ text: String) -> some View {
        Text(text)
            .font(.headline)
            .foregroundColor(.appPrimaryText)
    }

    private func searchPlaces(_ query: String) async {
        guard query.count > 1 else {
            placeResults = []
            return
        }
        placeResults = await appState.placesService.search(query: query)
    }

    private func selectPlace(_ place: Place) {
        placeName = place.displayName
        latitude = place.latitude
        longitude = place.longitude
        timezone = place.timezone
        placeQuery = place.displayName
        placeResults = []
    }

    private func calculate() async {
        let trimmedQuestion = question.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedQuestion.isEmpty else {
            errorMsg = "Escribe una pregunta antes de calcular."
            return
        }
        guard TimeZone(identifier: timezone) != nil else {
            errorMsg = "La zona horaria IANA no es válida."
            return
        }

        isCalculating = true
        errorMsg = nil

        do {
            let request = HoraryRequest(
                question: trimmedQuestion,
                datetimeLocal: try buildLocalISOString(from: askedAt, timezoneName: timezone),
                timezone: timezone,
                latitude: latitude,
                longitude: longitude,
                placeName: resolvedPlaceName,
                questionHouse: questionHouse,
                includeFortune: includeFortune
            )
            let response = try await HoraryEngine.calculate(request)
            let query = try SavedHoraryQuery(request: request, response: response)
            try appState.horaryStore.save(query)
            appState.registerHorary(query)
            onQueryCalculated(query)
            lastCalculated = trimmedQuestion
        } catch {
            errorMsg = error.localizedDescription
        }

        isCalculating = false
    }

    private var resolvedPlaceName: String {
        let trimmedPlaceName = placeName.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmedPlaceName.isEmpty { return trimmedPlaceName }
        let trimmedQuery = placeQuery.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmedQuery.isEmpty { return trimmedQuery }
        return "Lugar sin nombre"
    }

    private func buildLocalISOString(from date: Date, timezoneName: String) throws -> String {
        guard let timezone = TimeZone(identifier: timezoneName) else {
            throw JulianDayError.invalidTimezone(timezoneName)
        }
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timezone
        let comps = calendar.dateComponents([.year, .month, .day, .hour, .minute, .second], from: date)
        return String(
            format: "%04d-%02d-%02dT%02d:%02d:%02d",
            comps.year ?? 0,
            comps.month ?? 0,
            comps.day ?? 0,
            comps.hour ?? 0,
            comps.minute ?? 0,
            comps.second ?? 0
        )
    }
}
