import SwiftUI

struct AstrocartographyView: View {
    @EnvironmentObject var appState: AppState
    @StateObject private var model = AstrocartographyViewModel()
    @State private var retry = UUID()
    @State private var cameraCommand = UUID()
    @State private var focusPlace = false
    @State private var latitude = ""
    @State private var longitude = ""
    @State private var coordinateError: String?
    @State private var mapError: String?
    @State private var showFilters = true

    private var charts: [NatalChart] {
        guard let active = appState.activeNatalChart else { return appState.userStore.savedCharts }
        return [active] + appState.userStore.savedCharts.filter { $0.id != active.id }
    }
    private var input: AstroChartInput? { appState.activeNatalChart.map(AstroChartInput.init) }
    private struct LoadKey: Equatable { let input: AstroChartInput?; let retry: UUID }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            header
            switch model.state {
            case .empty:
                ContentUnavailableView("Sin carta activa", systemImage: "globe.europe.africa",
                    description: Text("Selecciona una carta guardada arriba o calcula una nueva carta. No se consulta tu ubicación."))
            case .working:
                VStack(spacing: 14) {
                    ProgressView("Calculando diez cuerpos y preparando el mapa…")
                    Button("Cancelar") { model.cancel() }
                }.frame(maxWidth: .infinity, maxHeight: .infinity)
            case .failed(let message):
                ContentUnavailableView {
                    Label("No se pudo calcular", systemImage: "exclamationmark.triangle")
                } description: { Text(message) } actions: { Button("Reintentar") { retry = UUID() } }
            case .cancelled:
                ContentUnavailableView {
                    Label("Cálculo cancelado", systemImage: "stop.circle")
                } actions: { Button("Calcular de nuevo") { retry = UUID() } }
            case .ready:
                if let presentation = model.presentation {
                    HSplitView {
                        map(presentation).frame(minWidth: 340, maxWidth: .infinity, maxHeight: .infinity)
                        controls(presentation).frame(minWidth: 290, idealWidth: 330, maxWidth: 400)
                    }
                }
            }
        }
        .padding(18)
        .background(Color.appBackground)
        .task(id: LoadKey(input: input, retry: retry)) {
            mapError = nil
            await model.load(input)
        }
        .onDisappear { model.cancel() }
        .onChange(of: model.bodies) { _, _ in model.reconcileSelection() }
        .onChange(of: model.angles) { _, _ in model.reconcileSelection() }
        .onChange(of: model.selectedPlace) { _, value in
            if let value {
                latitude = String(format: "%.6f", value.latitude)
                longitude = String(format: "%.6f", value.longitude)
            }
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Label("Astrocartografía", systemImage: "globe.europe.africa").font(.title2.bold())
                Spacer()
                Picker("Carta activa", selection: Binding<UUID?>(
                    get: { appState.activeNatalChart?.id },
                    set: { id in appState.activeNatalChart = charts.first { $0.id == id } }
                )) {
                    Text("Sin carta").tag(Optional<UUID>.none)
                    ForEach(charts) { chart in
                        Text(chart.name.isEmpty ? "Carta · \(chart.birthDate)" : chart.name).tag(Optional(chart.id))
                    }
                }.frame(maxWidth: 330)
                Button("Nueva carta") { appState.selectedNav = .nuevaCarta }
            }
            Text("Cálculo y lista locales, disponibles sin red. El mapa base de Apple puede necesitar conexión; no se garantiza uso offline.")
                .font(.caption).foregroundStyle(.secondary)
        }
    }

    private func map(_ presentation: AstroMapPresentation) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Button("Ver mundo") { focusPlace = false; cameraCommand = UUID() }
                Button("Centrar lugar") { focusPlace = true; cameraCommand = UUID() }.disabled(model.selectedPlace == nil)
                Spacer()
                Text("\(model.visibleLines.count) / 40 líneas").font(.caption.monospacedDigit())
            }
            AstroMapView(lines: model.visibleLines, revision: presentation.revision,
                selectedLine: $model.selectedLine, selectedPlace: $model.selectedPlace,
                cameraCommand: cameraCommand, focusPlace: focusPlace, onMapError: { mapError = $0 })
                .clipShape(RoundedRectangle(cornerRadius: 8))
                .overlay(alignment: .topLeading) {
                    if model.visibleLines.isEmpty {
                        Text("Sin líneas visibles: activa cuerpos y ángulos en los filtros.")
                            .padding(10).background(.regularMaterial).padding(8)
                    }
                }
            if let mapError { Text(mapError).font(.caption).foregroundStyle(.orange) }
            Text("Pulsa una línea para identificarla o un punto para seleccionar coordenadas. Zoom con +/− o trackpad. Alternativa completa en la lista.")
                .font(.caption).foregroundStyle(.secondary)
        }
    }

    private func controls(_ presentation: AstroMapPresentation) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                DisclosureGroup("Filtros y leyenda", isExpanded: $showFilters) {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Button("Todos") { model.bodies = Set(AstroBody.allCases); model.angles = Set(AstroAngle.allCases) }
                            Button("Ninguno") { model.bodies = []; model.angles = [] }
                        }
                        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], alignment: .leading) {
                            ForEach(AstroBody.allCases, id: \.self) { body in
                                Toggle(isOn: membership(body, in: $model.bodies)) {
                                    Text(body.mapLabel).foregroundStyle(Color(nsColor: body.mapColor))
                                }.toggleStyle(.checkbox)
                            }
                        }
                        ForEach(AstroAngle.allCases, id: \.self) { angle in
                            Toggle(isOn: membership(angle, in: $model.angles)) {
                                HStack {
                                    Path { p in p.move(to: .zero); p.addLine(to: CGPoint(x: 30, y: 0)) }
                                        .stroke(style: StrokeStyle(lineWidth: 2, dash: angle.dash))
                                        .frame(width: 30, height: 3).accessibilityHidden(true)
                                    Text(angle.mapLabel).font(.caption)
                                }
                            }.toggleStyle(.checkbox)
                        }
                    }.padding(.top, 8)
                }
                Divider()
                Text("Líneas · selección por teclado").font(.headline)
                Text("Tabulador para entrar; flechas para recorrer. La selección se resalta en el mapa.")
                    .font(.caption).foregroundStyle(.secondary)
                List(selection: $model.selectedLine) {
                    ForEach(model.visibleLines, id: \.id) { line in
                        HStack {
                            Text("\(line.id.body.mapLabel) · \(line.id.angle.rawValue)")
                            Spacer()
                            if line.segments.isEmpty { Text("Sin trazo").font(.caption) }
                            if model.selectedLine == line.id { Image(systemName: "checkmark.circle.fill").accessibilityLabel("Seleccionada") }
                        }.tag(line.id)
                    }
                }.frame(height: 190).accessibilityLabel("Lista alternativa de líneas de astrocartografía")
                lineDetail(presentation)
                Divider()
                Text("Lugar seleccionado · solo coordenadas").font(.headline)
                TextField("Latitud −90…90", text: $latitude).accessibilityLabel("Latitud del lugar")
                TextField("Longitud −180…180", text: $longitude).accessibilityLabel("Longitud del lugar")
                HStack {
                    Button("Seleccionar lugar") { selectPlace() }
                    Button("Quitar") { model.selectedPlace = nil; latitude = ""; longitude = ""; coordinateError = nil }
                }
                if let coordinateError { Text(coordinateError).font(.caption).foregroundStyle(.red) }
                if let place = model.selectedPlace {
                    Text(String(format: "φ %.6f° · λ %.6f° E", place.latitude, place.longitude)).font(.caption.monospaced())
                    if abs(place.latitude) > AstroMercatorGeometry.latitudeLimit {
                        Text("Este lugar queda fuera del dominio visual ±85.051129°. Sus coordenadas se conservan; el mapa se centra en el borde.").font(.caption)
                    }
                }
                Text("No cambia el instante natal. Sin distancias, carta relocada ni guardado de lugares en este MVP.")
                    .font(.caption).foregroundStyle(.secondary)
                Divider()
                diagnostics(presentation)
            }.padding(.horizontal, 8)
        }
    }

    @ViewBuilder private func lineDetail(_ presentation: AstroMapPresentation) -> some View {
        if let id = model.selectedLine,
           let line = presentation.result.lines.first(where: { $0.id == id }),
           let position = presentation.result.snapshot.positions.first(where: { $0.body == id.body }) {
            Text("\(id.body.mapLabel) · \(id.angle.mapLabel)").font(.headline)
            Text(String(format: "AR %.6f° · declinación %.6f°\nFlags Swiss: %d", position.rightAscensionDegrees, position.declinationDegrees, position.returnedFlags))
                .font(.caption.monospaced()).textSelection(.enabled)
            ForEach(Array(line.diagnostics.enumerated()), id: \.offset) { _, diagnostic in
                Text(diagnostic.message).font(.caption)
            }
        } else { Text("Selecciona una línea en el mapa o la lista para ver sus datos y límites.").font(.caption).foregroundStyle(.secondary) }
    }

    private func diagnostics(_ presentation: AstroMapPresentation) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Datos y precisión").font(.headline)
            Text(String(format: "JD %.9f · UTC ≈ UT1\nGST %.6f°", presentation.result.snapshot.request.instant.julianDay,
                        presentation.result.snapshot.greenwichSiderealDegrees)).font(.caption.monospaced()).textSelection(.enabled)
            Text("Swiss \(presentation.result.snapshot.provenance.libraryVersion) · \(AstrocartographyEngine.algorithmVersion)").font(.caption)
            Text("Líneas geocéntricas aparentes, horizonte geométrico del centro. Sin refracción ni paralaje topocéntrico. MC/IC no implican visibilidad.").font(.caption)
            Text("Presupuesto del trazado ideal: 0.9 km geográfico + 0.1 km Mercator, esfera R = 6371.0088 km. No es exactitud de efemérides, hora natal, terreno ni píxeles. Recorte visual ±85.051129°.").font(.caption)
            ForEach(Array(presentation.result.snapshot.provenance.diagnostics.enumerated()), id: \.offset) { _, diagnostic in
                Label(diagnostic.message, systemImage: "exclamationmark.triangle").font(.caption)
            }
            Text("Uso exploratorio de una tradición simbólica; no demuestra efectos causales ni garantiza resultados vitales.")
                .font(.caption).foregroundStyle(.secondary)
        }
    }

    private func membership<T: Hashable>(_ value: T, in binding: Binding<Set<T>>) -> Binding<Bool> {
        Binding(get: { binding.wrappedValue.contains(value) }, set: { enabled in
            if enabled { binding.wrappedValue.insert(value) } else { binding.wrappedValue.remove(value) }
        })
    }
    private func selectPlace() {
        do {
            guard let lat = Double(latitude.replacingOccurrences(of: ",", with: ".")),
                  let lon = Double(longitude.replacingOccurrences(of: ",", with: ".")) else {
                throw AstrocartographyError.invalidValue("coordenadas numéricas")
            }
            model.selectedPlace = try GeoCoordinate(latitude: lat, longitude: lon)
            coordinateError = nil
        } catch { coordinateError = "Introduce latitud entre −90 y 90 y longitud entre −180 y 180." }
    }
}
