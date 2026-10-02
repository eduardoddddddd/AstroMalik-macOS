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
    @State private var searchQuery = ""
    @State private var onlineSearch = false
    @State private var searchCommand: UUID?
    @State private var visibleDistancesOnly = false
    @State private var nearThreshold = "100"
    @State private var regionalThreshold = "300"

    private var charts: [NatalChart] {
        guard let active = appState.activeNatalChart else { return appState.userStore.savedCharts }
        return [active] + appState.userStore.savedCharts.filter { $0.id != active.id }
    }
    private var input: AstroChartInput? { appState.activeNatalChart.map(AstroChartInput.init) }
    private struct LoadKey: Equatable { let input: AstroChartInput?; let retry: UUID }
    private struct PlaceLoadKey: Equatable { let coordinate: GeoCoordinate?; let zone: AstroDestinationTimeZone }

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
            await model.prepareSavedPlaces(from: appState.userStore)
        }
        .task(id: PlaceLoadKey(coordinate: model.selectedPlace, zone: model.selectedPlaceTimeZone)) {
            await model.analyzePlace()
            model.reloadSavedPlaces(from: appState.userStore)
        }
        .task(id: searchCommand) {
            guard searchCommand != nil else { return }
            await model.search(query: searchQuery, online: onlineSearch)
        }
        .onDisappear { model.cancel() }
        .onChange(of: model.bodies) { _, _ in model.reconcileSelection() }
        .onChange(of: model.angles) { _, _ in model.reconcileSelection() }
        .onChange(of: model.proximityPolicy) { _, value in
            nearThreshold = String(value.nearKm); regionalThreshold = String(value.regionalKm)
        }
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
                placeSearch
                Text("Lugar seleccionado").font(.headline)
                TextField("Nombre del lugar", text: $model.selectedPlaceName).accessibilityLabel("Nombre del lugar seleccionado")
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
                Text("El destino nunca reinterpreta la hora natal. Catálogo, mapa y coordenadas sin zona verificada usan UTC para presentación.")
                    .font(.caption).foregroundStyle(.secondary)
                placeResults
                comparisonResults
                savedPlaceControls
                Divider()
                diagnostics(presentation)
            }.padding(.horizontal, 8)
        }
    }

    private var placeSearch: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Buscar lugar").font(.headline)
            TextField("Ciudad en catálogo local", text: $searchQuery).onSubmit { searchCommand = UUID() }
            Toggle("Consultar también online (Nominatim)", isOn: $onlineSearch).toggleStyle(.checkbox)
            Text("Online envía solo esta consulta a OpenStreetMap/Nominatim; no la carta natal. Sin activar: catálogo local y coordenadas, sin red.")
                .font(.caption).foregroundStyle(.secondary)
            Button("Buscar") { searchCommand = UUID() }.disabled(searchQuery.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            if model.searching { ProgressView("Buscando…") }
            if let warning = model.searchWarning { Text(warning).font(.caption).foregroundStyle(.orange) }
            ForEach(model.searchResults) { place in
                Button { model.select(place); focusPlace = true; cameraCommand = UUID() } label: {
                    VStack(alignment: .leading) {
                        Text(place.name)
                        Text(String(format: "%.5f°, %.5f° · %@", place.coordinate.latitude, place.coordinate.longitude,
                                    place.origin == .localCatalog ? "catálogo local" : "Nominatim / OSM")).font(.caption)
                    }
                }.buttonStyle(.borderless)
            }
            if searchCommand != nil, !model.searching, model.searchResults.isEmpty {
                Text("Sin coincidencias. Puedes seleccionar coordenadas manualmente.").font(.caption)
            }
        }
    }
    @ViewBuilder private var placeResults: some View {
        switch model.placeState {
        case .working: ProgressView("Distancias y casas relocadas…")
        case .failed(let message): Text(message).font(.caption).foregroundStyle(.red)
        case .cancelled: Text("Análisis del lugar cancelado.").font(.caption)
        case .ready:
            if let calculation = model.placeCalculation {
                Divider()
                Text("Distancias geográficas").font(.headline)
                Toggle("Solo líneas visibles (filtros)", isOn: $visibleDistancesOnly).toggleStyle(.checkbox)
                Text("Global: \(calculation.analysis.proximities.count) líneas definidas; visibles: \(model.visibleProximities.count). Las líneas ocultas siguen contando en global; ramas sin solución única no tienen distancia.")
                    .font(.caption)
                if let global = calculation.analysis.proximities.first {
                    Text(String(format: "Más cercana global: %@ %@ · %.3f km", global.lineID.body.mapLabel, global.lineID.angle.rawValue, global.distanceKm)).font(.caption.bold())
                }
                let distances = visibleDistancesOnly ? model.visibleProximities : calculation.analysis.proximities
                ForEach(distances, id: \.lineID) { proximity in proximityRow(proximity) }
                Text("Esfera R=6371.0088 km. Mínimo continuo sobre curvas completas, no píxeles ni trazado recortado; cota ±tolerancia núcleo + 1 mm frente a interpolación lat/lon. No exactitud natal/efemérides.")
                    .font(.caption).foregroundStyle(.secondary)
                HStack {
                    TextField("Cerca km", text: $nearThreshold).accessibilityLabel("Umbral cercano en kilómetros")
                    TextField("Regional km", text: $regionalThreshold).accessibilityLabel("Umbral regional en kilómetros")
                    Button("Aplicar") { applyProximityPolicy() }
                }
                Text(String(format: "Cerca ≤%.0f km; regional ≤%.0f km. Parámetros de producto, no intensidad científica. * indica que la cota cruza un umbral.",
                            model.proximityPolicy.nearKm, model.proximityPolicy.regionalKm)).font(.caption)
                if let readings = model.placeReadings(onlyVisible: visibleDistancesOnly) {
                    Divider()
                    AstroPlaceReadingsView(set: readings, placeName: model.selectedPlaceName) { model.selectedLine = $0 }
                }
                relocatedDetails(calculation)
                Button("Añadir a comparación (máximo 6)") { model.addComparison() }
            }
        case .empty: EmptyView()
        }
    }
    private func proximityRow(_ proximity: AstroLineProximity) -> some View {
        let visible = model.bodies.contains(proximity.lineID.body) && model.angles.contains(proximity.lineID.angle)
        return Button { model.selectedLine = proximity.lineID } label: {
            VStack(alignment: .leading, spacing: 2) {
                Text(String(format: "%@ %@ · %.3f ± %.6f km · %@%@%@", proximity.lineID.body.mapLabel,
                    proximity.lineID.angle.rawValue, proximity.distanceKm, proximity.estimatedErrorKm,
                    model.proximityPolicy.band(for: proximity.distanceKm).rawValue,
                    model.proximityPolicy.crossesBoundary(proximity) ? " *" : "", visible ? "" : " (oculta)"))
                Text(String(format: "Punto más próximo: %.6f°, %.6f° E", proximity.nearestPoint.latitude, proximity.nearestPoint.longitude)).font(.caption)
            }.textSelection(.enabled)
        }.buttonStyle(.borderless).font(.caption)
    }
    @ViewBuilder private func relocatedDetails(_ calculation: AstroLocationCalculation) -> some View {
        Divider()
        Text("Carta relocada · natal intacta").font(.headline)
        if let relocated = calculation.relocation {
            let chart = relocated.chart
            Text(String(format: "Mismo JD %.9f · %@ · zona %@%@", chart.instant.julianDay, chart.houseSystem,
                        relocated.destinationTimeZone.identifier, relocated.destinationTimeZone.isVerified ? " (verificada)" : " (fallback)"))
                .font(.caption.monospaced()).textSelection(.enabled)
            Text(String(format: "ASC %.6f° · MC %.6f°\nNatal: ASC %.6f° · MC %.6f°", chart.ascendantDegrees, chart.mcDegrees,
                        input?.natalAsc ?? 0, input?.natalMC ?? 0)).font(.caption.monospaced()).textSelection(.enabled)
            ForEach(Array(chart.cuspsDegrees.enumerated()), id: \.offset) { index, cusp in
                Text(String(format: "Casa %d: %.6f° · natal %.6f°", index+1, cusp,
                            (input?.natalCusps.count == 12) ? input!.natalCusps[index] : 0)).font(.caption.monospaced())
            }
            ForEach(chart.bodies, id: \.body) { body in
                Text(String(format: "%@: %.6f° (sin cambio) · casa %d", body.body.mapLabel, body.longitudeDegrees, body.house)).font(.caption.monospaced())
            }
            Text("Swiss \(relocated.provenance.libraryVersion) · \(relocated.provenance.algorithmVersion)").font(.caption)
            ForEach(Array(chart.diagnostics.enumerated()), id: \.offset) { _, diagnostic in Text(diagnostic.message).font(.caption) }
        } else {
            Text(calculation.relocationError ?? "Carta relocada no disponible.").font(.caption).foregroundStyle(.orange)
            Text("Las distancias geográficas siguen siendo válidas; no se usa otro sistema de casas silenciosamente.").font(.caption)
        }
    }
    @ViewBuilder private var comparisonResults: some View {
        if !model.comparisons.isEmpty {
            Divider()
            Text("Comparación de lugares · mismo instante natal").font(.headline)
            ForEach(model.comparisons) { comparison in
                VStack(alignment: .leading, spacing: 4) {
                    Text(comparison.place.name).font(.subheadline.bold())
                    Text(String(format: "%.5f°, %.5f° E · zona %@", comparison.place.coordinate.latitude,
                                comparison.place.coordinate.longitude, comparison.place.timeZone.identifier)).font(.caption)
                    if let nearest = comparison.calculation.analysis.proximities.first {
                        Text(String(format: "Global: %@ %@ · %.3f km", nearest.lineID.body.mapLabel, nearest.lineID.angle.rawValue, nearest.distanceKm)).font(.caption)
                    }
                    if let nearest = AstroLocationAnalyzer.filtered(comparison.calculation.analysis, bodies: model.bodies, angles: model.angles).first {
                        Text(String(format: "Visible: %@ %@ · %.3f km", nearest.lineID.body.mapLabel, nearest.lineID.angle.rawValue, nearest.distanceKm)).font(.caption)
                    } else { Text("Sin líneas visibles; global no cambia.").font(.caption) }
                    comparisonLines(model.placeReadings(for: comparison))
                    if let relocation = comparison.calculation.relocation {
                        Text(String(format: "ASC %.6f° · MC %.6f°", relocation.chart.ascendantDegrees, relocation.chart.mcDegrees)).font(.caption.monospaced())
                    } else { Text(comparison.calculation.relocationError ?? "Sin casas disponibles").font(.caption) }
                    HStack {
                        Button("Consultar todos los datos") { model.select(comparison.place) }
                        Button("Quitar de comparación") { model.removeComparison(comparison.id) }
                    }
                }
            }
            Text("La comparación en memoria se vacía al cambiar/editar carta. Guarda cada lugar si quieres recuperarlo.").font(.caption)
        }
    }
    /// Compact side-by-side view: which lines are near each place and what each
    /// one is about. The full text of any of them opens via "Consultar todos los datos".
    @ViewBuilder private func comparisonLines(_ set: AstroPlaceReadingSet) -> some View {
        if set.items.isEmpty {
            Text(String(format: "Sin líneas a ≤%.0f km (regional).", set.policy.regionalKm)).font(.caption)
        } else {
            ForEach(set.items) { item in
                let title = item.lookup.entry?.title ?? "\(item.proximity.lineID.body.mapLabel) \(item.proximity.lineID.angle.rawValue) · sin lectura"
                Text(String(format: "%@ · %.0f km · %@", item.band.rawValue, item.proximity.distanceKm, title)).font(.caption)
            }
        }
    }
    private var savedPlaceControls: some View {
        VStack(alignment: .leading, spacing: 6) {
            Divider()
            Text("Lugares guardados de esta carta").font(.headline)
            Button("Guardar / actualizar lugar seleccionado") { model.saveSelectedPlace(to: appState.userStore) }
                .disabled(model.placeState != .ready)
            Button("Recargar guardados") { model.reloadSavedPlaces(from: appState.userStore) }
            if let warning = model.storageWarning { Text(warning).font(.caption).foregroundStyle(.orange) }
            ForEach(model.savedPlaces) { saved in
                Text(saved.intent.place.name).font(.subheadline)
                Text(saved.requiresRecalculation ? "Natal/revisión cambió o resultado no disponible: recalcular al recuperar." : "Resultado compatible; al recuperar se verifica y recalcula por caché.").font(.caption)
                HStack {
                    Button("Recuperar") { model.recover(saved) }
                    Button("Eliminar lugar") { model.deleteSavedPlace(saved, from: appState.userStore) }
                }
            }
        }
    }
    private func applyProximityPolicy() {
        do {
            guard let near = Double(nearThreshold.replacingOccurrences(of: ",", with: ".")),
                  let regional = Double(regionalThreshold.replacingOccurrences(of: ",", with: ".")) else {
                throw AstrocartographyError.invalidValue("proximityThresholds")
            }
            model.proximityPolicy = try AstroProximityPolicy(nearKm: near, regionalKm: regional)
            coordinateError = nil
        } catch { coordinateError = "Umbrales: cerca ≥0 km y regional mayor que cerca, ambos finitos." }
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
            if let lookup = model.selectedLineReading { AstroReadingLookupView(lookup: lookup) }
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
            model.select(try AstroPlace(name: model.selectedPlaceName, coordinate: GeoCoordinate(latitude: lat, longitude: lon),
                                        origin: .manual, timeZone: AstroDestinationTimeZone()))
            coordinateError = nil
        } catch { coordinateError = "Introduce latitud entre −90 y 90 y longitud entre −180 y 180." }
    }
}
