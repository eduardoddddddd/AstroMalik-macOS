import Foundation
import Combine
import CryptoKit

struct AstroChartInput: Equatable, Sendable {
    let id: UUID
    let date: String
    let time: String
    let timezone: String
    let fingerprint: String
    let houseSystem: String
    let natalBodies: [AstroNatalBody]
    let natalCusps: [Double]
    let natalAsc: Double
    let natalMC: Double

    init(_ chart: NatalChart) {
        id = chart.id; date = chart.birthDate; time = chart.birthTime; timezone = chart.timezone
        fingerprint = (try? AstroNatalFingerprint.make(chart)) ?? ""
        houseSystem = chart.houseSystem
        natalBodies = chart.bodies.compactMap { p in AstroBody(rawValue: p.key).map { AstroNatalBody(body: $0, longitudeDegrees: p.longitude) } }
        natalCusps = chart.cusps; natalAsc = chart.ascendant.longitude; natalMC = chart.mc.longitude
    }
    func relocationSource(instant: AstroNatalInstant) throws -> AstroRelocationSource {
        try AstroRelocationSource(natalChartID: id, instant: instant, houseSystem: houseSystem, bodies: natalBodies)
    }
    func request() throws -> AstrocartographyRequest {
        let jd = try julianDayFromLocal(birthDate: date, birthTime: time, timezoneName: timezone).jd
        return try AstrocartographyRequest(instant: AstroNatalInstant(julianDay: jd),
                                           geometryToleranceKm: AstroMercatorGeometry.coreBudgetKm)
    }
}

struct AstroMapPresentation: Equatable, Sendable {
    let result: AstrocartographyResult
    let lines: [AstroVisualLine]
    let revision: String
}

@MainActor
final class AstrocartographyViewModel: ObservableObject {
    enum State: Equatable {
        case empty, working, ready, cancelled, failed(String)
    }
    typealias ServiceFactory = @Sendable () async throws -> AstrocartographyCalculationService
    @Published private(set) var state: State = .empty
    @Published private(set) var presentation: AstroMapPresentation?
    @Published var selectedLine: AstroLineID?
    @Published var selectedPlace: GeoCoordinate? {
        didSet {
            guard oldValue != selectedPlace else { return }
            invalidatePlace()
            selectedPlaceName = "Coordenadas seleccionadas"; selectedPlaceOrigin = .map
            selectedPlaceTimeZone = try! AstroDestinationTimeZone()
            editingSavedPlaceID = nil
        }
    }
    @Published var selectedPlaceName = "Coordenadas seleccionadas"
    @Published private(set) var selectedPlaceOrigin: AstroPlaceOrigin = .manual
    @Published private(set) var selectedPlaceTimeZone = try! AstroDestinationTimeZone()
    @Published private(set) var placeState: State = .empty
    @Published private(set) var placeCalculation: AstroLocationCalculation?
    @Published private(set) var comparisons: [AstroPlaceComparison] = []
    @Published var proximityPolicy = try! AstroProximityPolicy()
    @Published private(set) var searchResults: [AstroPlace] = []
    @Published private(set) var searchWarning: String?
    @Published private(set) var searching = false
    @Published private(set) var savedPlaces: [AstroSavedPlace] = []
    @Published private(set) var storageWarning: String?
    @Published private(set) var locationRevision = ""
    private var editingSavedPlaceID: UUID?
    @Published var bodies = Set(AstroBody.allCases)
    @Published var angles = Set(AstroAngle.allCases)
    typealias LocationFactory = @Sendable () async throws -> AstroLocationCalculationService
    typealias Search = @Sendable (String, Bool) async throws -> AstroPlaceSearchResult
    private let locationFactory: LocationFactory
    private let placeSearch: Search
    /// Offline editorial text (F5). A failed load is shown as per-line fallback.
    let readingCatalog: AstroReadingCatalog
    private var locationService: AstroLocationCalculationService?
    private var placeGeneration = UUID()
    private var placeWork: Task<AstroLocationCalculation, Error>?
    private var searchGeneration = UUID()
    private var loadedInput: AstroChartInput?
    private let factory: ServiceFactory
    private var service: AstrocartographyCalculationService?
    private var generation = UUID()
    private var activeWork: Task<AstroMapPresentation, Error>?

    init(factory: @escaping ServiceFactory = { try await AstrocartographyViewModel.makeService() },
         locationFactory: @escaping LocationFactory = { try await AstrocartographyViewModel.makeLocationService() },
         placeSearch: @escaping Search = { query, online in try await AstroPlaceSearchService().search(query: query, online: online) },
         readingCatalog: AstroReadingCatalog = .bundled()) {
        self.factory = factory; self.locationFactory = locationFactory; self.placeSearch = placeSearch
        self.readingCatalog = readingCatalog
    }

    /// Reading of the selected line; independent of any place or distance.
    var selectedLineReading: AstroReadingLookup? {
        selectedLine.map { readingCatalog.lookup($0) }
    }

    /// Readings for lines near the selected place. Derived on demand from the
    /// stored analysis: no recomputation of distances, relocation or curves.
    func placeReadings(onlyVisible: Bool, includeDistant: Bool = false) -> AstroPlaceReadingSet? {
        guard placeState == .ready, let analysis = placeCalculation?.analysis else { return nil }
        return AstroPlaceReadingBuilder.build(analysis: analysis, policy: proximityPolicy, catalog: readingCatalog,
                                              bodies: bodies, angles: angles, onlyVisible: onlyVisible,
                                              includeDistant: includeDistant)
    }

    func placeReadings(for comparison: AstroPlaceComparison) -> AstroPlaceReadingSet {
        AstroPlaceReadingBuilder.build(analysis: comparison.calculation.analysis, policy: proximityPolicy,
                                       catalog: readingCatalog, bodies: bodies, angles: angles)
    }

    var visibleLines: [AstroVisualLine] {
        presentation?.lines.filter { bodies.contains($0.id.body) && angles.contains($0.id.angle) } ?? []
    }

    func reconcileSelection() {
        if let selectedLine, !visibleLines.contains(where: { $0.id == selectedLine }) { self.selectedLine = nil }
    }

    /// SwiftUI's task lifetime cancels the caller; token checks also prevent
    /// an obsolete factory/preparation completion from publishing over a new chart.
    func load(_ input: AstroChartInput?) async {
        activeWork?.cancel(); activeWork = nil
        let token = UUID(); generation = token
        presentation = nil; selectedLine = nil; selectedPlace = nil
        invalidatePlace(); comparisons = []; savedPlaces = []; storageWarning = nil; loadedInput = input
        guard let input else {
            state = .empty
            return
        }
        state = .working
        do {
            let request = try input.request()
            let calculator: AstrocartographyCalculationService
            if let service { calculator = service } else {
                calculator = try await factory()
                try Task.checkCancellation()
                guard generation == token else { return }
                service = calculator
            }
            try Task.checkCancellation()
            guard generation == token else { return }
            let work = Task {
                let result = try await calculator.calculate(request: request)
                let task = Task.detached {
                    let lines = try result.lines.map { try AstroMercatorGeometry.prepare($0) }
                    return AstroMapPresentation(result: result, lines: lines, revision: token.uuidString)
                }
                return try await withTaskCancellationHandler { try await task.value } onCancel: { task.cancel() }
            }
            activeWork = work
            let prepared = try await withTaskCancellationHandler { try await work.value } onCancel: { work.cancel() }
            try Task.checkCancellation()
            guard generation == token else { return }
            activeWork = nil; presentation = prepared; state = .ready
        } catch {
            guard generation == token else { return }
            activeWork = nil
            state = error is CancellationError ? .cancelled : .failed(error.localizedDescription)
        }
    }

    func cancel() {
        activeWork?.cancel(); activeWork = nil
        generation = UUID(); presentation = nil; selectedLine = nil; selectedPlace = nil
        invalidatePlace(); comparisons = []; loadedInput = nil
        searchGeneration = UUID(); searching = false
        state = .cancelled
        // Cancellation of the view task is the generation-safe service cancellation;
        // do not enqueue an unscoped service.cancel that could cancel a newer load.
    }

    var selectedDestination: AstroPlace? {
        guard let coordinate = selectedPlace else { return nil }
        let name = selectedPlaceName.trimmingCharacters(in: .whitespacesAndNewlines)
        return AstroPlace(name: name.isEmpty ? "Coordenadas seleccionadas" : name, coordinate: coordinate,
                          origin: selectedPlaceOrigin, timeZone: selectedPlaceTimeZone)
    }
    var visibleProximities: [AstroLineProximity] {
        guard let analysis = placeCalculation?.analysis else { return [] }
        return AstroLocationAnalyzer.filtered(analysis, bodies: bodies, angles: angles)
    }
    func select(_ place: AstroPlace) {
        if selectedPlace == place.coordinate, selectedPlaceTimeZone != place.timeZone { invalidatePlace() }
        selectedPlace = place.coordinate
        selectedPlaceName = place.name; selectedPlaceOrigin = place.origin; selectedPlaceTimeZone = place.timeZone
        editingSavedPlaceID = nil
    }
    private func invalidatePlace() {
        placeGeneration = UUID(); placeWork?.cancel(); placeWork = nil
        placeCalculation = nil; placeState = .empty
    }
    func analyzePlace() async {
        invalidatePlace()
        guard let input = loadedInput, let curves = presentation?.result, let place = selectedDestination else { return }
        let token = UUID(); placeGeneration = token; placeState = .working
        do {
            let service: AstroLocationCalculationService
            if let locationService { service = locationService } else {
                service = try await locationFactory()
                try Task.checkCancellation()
                guard placeGeneration == token else { return }
                locationService = service
                locationRevision = service.revision
            }
            var source: AstroRelocationSource?, sourceError: String?
            do { source = try input.relocationSource(instant: curves.snapshot.request.instant) }
            catch { sourceError = error.localizedDescription }
            let request = AstroLocationCalculationRequest(curves: curves, source: source, sourceError: sourceError,
                destination: place.coordinate, timeZone: place.timeZone)
            let work = Task { try await service.calculate(request) }; placeWork = work
            let calculation = try await withTaskCancellationHandler { try await work.value } onCancel: { work.cancel() }
            try Task.checkCancellation()
            guard placeGeneration == token, loadedInput == input, selectedPlace == place.coordinate else { return }
            placeWork = nil; placeCalculation = calculation; placeState = .ready
        } catch {
            guard placeGeneration == token else { return }
            placeWork = nil; placeState = error is CancellationError ? .cancelled : .failed(error.localizedDescription)
        }
    }
    func search(query: String, online: Bool) async {
        let token = UUID(); searchGeneration = token
        searchResults = []; searchWarning = nil; searching = true
        do {
            let result = try await placeSearch(query, online)
            try Task.checkCancellation()
            guard searchGeneration == token else { return }
            searchResults = result.places; searchWarning = result.warning; searching = false
        } catch {
            guard searchGeneration == token else { return }
            searching = false
            if !(error is CancellationError) { searchWarning = error.localizedDescription }
        }
    }
    func addComparison() {
        guard let place = selectedDestination, let calculation = placeCalculation, placeState == .ready else { return }
        comparisons.removeAll { $0.place.coordinate == place.coordinate }
        comparisons.append(AstroPlaceComparison(id: UUID(), place: place, calculation: calculation))
        if comparisons.count > 6 { comparisons.removeFirst() }
    }
    func removeComparison(_ id: UUID) { comparisons.removeAll { $0.id == id } }
    func recover(_ saved: AstroSavedPlace) {
        guard saved.natalChartID == loadedInput?.id else { return }
        select(saved.intent.place); editingSavedPlaceID = saved.id
        bodies = Set(saved.intent.bodies); angles = Set(saved.intent.angles); proximityPolicy = saved.intent.proximityPolicy
        // Recompute through the real-input cache. Never publish a stored result
        // before checking current natal/resource revisions or task generation.
    }
    func reloadSavedPlaces(from store: UserStore) {
        guard let input = loadedInput, !locationRevision.isEmpty else { return }
        do {
            let loaded = try store.loadAstroPlaces(chartID: input.id, fingerprint: input.fingerprint, revision: locationRevision)
            savedPlaces = loaded.places; storageWarning = loaded.warnings.isEmpty ? nil : loaded.warnings.joined(separator: "\n")
        } catch { storageWarning = error.localizedDescription }
    }
    func saveSelectedPlace(to store: UserStore) {
        guard let input = loadedInput, let place = selectedDestination, let calculation = placeCalculation,
              placeState == .ready, !locationRevision.isEmpty else { return }
        do {
            editingSavedPlaceID = try store.saveAstroPlace(id: editingSavedPlaceID ?? UUID(), chartID: input.id, fingerprint: input.fingerprint,
                intent: AstroSavedPlaceIntent(place: place, bodies: AstroBody.allCases.filter { bodies.contains($0) },
                    angles: AstroAngle.allCases.filter { angles.contains($0) }, proximityPolicy: proximityPolicy),
                calculation: calculation, revision: locationRevision)
            reloadSavedPlaces(from: store)
        } catch { storageWarning = error.localizedDescription }
    }
    func deleteSavedPlace(_ saved: AstroSavedPlace, from store: UserStore) {
        do {
            try store.deleteAstroPlace(id: saved.id, chartID: saved.natalChartID)
            if editingSavedPlaceID == saved.id { editingSavedPlaceID = nil }
            reloadSavedPlaces(from: store)
        } catch { storageWarning = error.localizedDescription }
    }
    func prepareSavedPlaces(from store: UserStore) async {
        guard loadedInput != nil else { return }
        let token = generation
        do {
            if locationService == nil {
                let newService = try await locationFactory()
                try Task.checkCancellation()
                guard generation == token else { return }
                locationService = newService; locationRevision = newService.revision
            }
            guard generation == token else { return }
            reloadSavedPlaces(from: store)
        } catch {
            guard generation == token, !(error is CancellationError) else { return }
            storageWarning = error.localizedDescription
        }
    }
    nonisolated static func makeLocationService() async throws -> AstroLocationCalculationService {
        try await Task.detached {
            guard let url = AppResources.bundle.url(forResource: "sepl_18", withExtension: "se1", subdirectory: "ephe") else {
                throw AstrocartographyError.ephemerisFailure("No se encuentran efemérides para relocalizar.")
            }
            let directory = url.deletingLastPathComponent()
            return try AstroLocationCalculationService(calculator: AstroLocationCalculator(relocator: AstroRelocationEngine(ephemerisDirectory: directory.path)),
                revision: "\(try resourceRevision(directory: directory))/\(AstroLocationAnalyzer.algorithmVersion)/\(AstroRelocationEngine.algorithmVersion)")
        }.value
    }

    nonisolated static func makeService() async throws -> AstrocartographyCalculationService {
        try await Task.detached {
            guard let url = AppResources.bundle.url(forResource: "sepl_18", withExtension: "se1", subdirectory: "ephe") else {
                throw AstrocartographyError.ephemerisFailure("No se encuentran las efemérides locales empaquetadas.")
            }
            let directory = url.deletingLastPathComponent()
            let revision = try resourceRevision(directory: directory)
            return try AstrocartographyCalculationService(
                calculator: AstrocartographyEngine(ephemeris: SwissAstrocartographyEphemeris(ephemerisDirectory: directory.path)),
                ephemerisRevision: revision)
        }.value
    }

    /// Content digest, not just path/mtime. Bundled resources are immutable during
    /// a workspace lifetime; recreate the model after an external resource update.
    nonisolated static func resourceRevision(directory: URL) throws -> String {
        var hash = SHA256()
        for file in try FileManager.default.contentsOfDirectory(at: directory, includingPropertiesForKeys: nil)
            .filter({ $0.pathExtension == "se1" }).sorted(by: { $0.lastPathComponent < $1.lastPathComponent }) {
            try Task.checkCancellation()
            hash.update(data: Data(file.lastPathComponent.utf8))
            hash.update(data: try Data(contentsOf: file))
        }
        let digest = hash.finalize().map { String(format: "%02x", $0) }.joined()
        return "Swiss/\(try SwissAstrocartographyEphemeris.libraryVersion())/\(directory.path)/\(digest)/flags=\(SwissAstrocartographyEphemeris.requestedFlags)/\(SwissAstrocartographyEphemeris.algorithmVersion)"
    }
}

struct AstroPlaceComparison: Equatable, Identifiable, Sendable {
    let id: UUID
    let place: AstroPlace
    let calculation: AstroLocationCalculation
}
