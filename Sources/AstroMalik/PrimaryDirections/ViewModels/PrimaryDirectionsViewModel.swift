import Foundation
import SwiftUI

// MARK: - PrimaryDirections ViewModel

/// ViewModel principal para el módulo de Direcciones Primarias.
/// @MainActor — toda la UI state vive aquí, mutación siempre en el main thread.
/// Cálculo pesado delegado a Task.detached; resultado asignado de vuelta en MainActor.
@MainActor
final class PrimaryDirectionsViewModel: ObservableObject {

    // MARK: - Published State

    /// Resultado completo de la última computación.
    @Published private(set) var result: PrimaryDirectionsResult? = nil
    /// Directions filtradas según PDFilters activos.
    @Published private(set) var filteredDirections: [EnrichedPrimaryDirection] = []
    /// Dirección seleccionada para el panel de detalle.
    @Published var selectedDirection: EnrichedPrimaryDirection? = nil {
        didSet {
            guard selectedDirection?.id != oldValue?.id else { return }
            interpretationTask?.cancel()
            isGeneratingInterpretation = false
            contextualInterpretation = nil
            loadCachedInterpretationForSelection()
        }
    }
    /// Interpretación contextual (Capa 2) de la dirección seleccionada.
    @Published private(set) var contextualInterpretation: ContextualInterpretation? = nil
    /// IDs que ya tienen contextual persistida en caché.
    @Published private(set) var cachedContextualDirectionIDs: Set<UUID> = []
    /// Año enfocado en la vista de consulta anual.
    @Published var selectedYear: Int = Calendar.current.component(.year, from: Date())
    /// Espéculo Regiomontano completo de la carta cargada.
    @Published private(set) var fullSpeculum: [SpeculumRow] = []
    /// True mientras se calcula el espéculo completo.
    @Published private(set) var isCalculating = false
    /// True mientras se genera interpretación LLM.
    @Published private(set) var isGeneratingInterpretation = false
    /// Error de cálculo o interpretación para mostrar en la UI.
    @Published var error: String? = nil
    /// Filtros activos.
    @Published var filters: PDFilters {
        didSet {
            if !isApplyingPresetFilters && filters != oldValue {
                markPresetAsCustom()
            }
            applyFilters()
        }
    }
    /// Preset de cálculo activo. `nil` representa filtros personalizados.
    @Published var activePreset: PDFilterPreset? {
        didSet {
            guard activePreset != oldValue else { return }
            settings.filterPreset = activePreset
            guard let preset = activePreset else { return }
            applyPresetFilters(preset)
            reloadCurrentChart()
        }
    }
    /// Configuración de cálculo persistida.
    @Published var settings: PDSettings {
        didSet { settings.persist() }
    }

    // MARK: - Dependencies

    private let service: PrimaryDirectionsService
    private let interpreter: PrimaryDirectionContextualInterpreter?
    /// Carta natal sobre la que se calculan las direcciones.
    private(set) var chart: NatalChart?
    private var julianDay: Double = 0
    private var birthDate: Date = Date()
    /// Task activa de cálculo (para cancelación).
    private var calculationTask: Task<Void, Never>? = nil
    private var interpretationTask: Task<Void, Never>? = nil
    private var isApplyingPresetFilters = false

    // MARK: - Init

    init(
        service: PrimaryDirectionsService,
        interpreter: PrimaryDirectionContextualInterpreter? = nil
    ) {
        let loadedSettings = PDSettings.load()
        self.service = service
        self.interpreter = interpreter
        self.settings = loadedSettings
        self.activePreset = loadedSettings.filterPreset
        self.filters = PDFilters(maxYears: loadedSettings.maxYears, preset: loadedSettings.filterPreset)
    }

    // MARK: - Load Directions

    /// Calcula las direcciones primarias para la carta dada.
    /// El trabajo pesado se ejecuta en Task.detached (off-MainActor).
    func loadDirections(chart: NatalChart, jd: Double, birthDate: Date) {
        self.chart = chart
        self.julianDay = jd
        self.birthDate = birthDate

        calculationTask?.cancel()
        isCalculating = true
        error = nil
        result = nil
        filteredDirections = []
        fullSpeculum = []
        selectedDirection = nil
        contextualInterpretation = nil
        cachedContextualDirectionIDs = []
        selectedYear = Self.currentYear(for: chart)

        let service = self.service          // capture for Sendable boundary
        let config = settings.calculatorConfig

        calculationTask = Task {
            // Compute off main thread
            let computed = await Task.detached(priority: .userInitiated) {
                let result = service.compute(chart: chart, jd: jd, birthDate: birthDate, config: config)
                let speculum = PrimaryDirectionCalculator().computeFullSpeculum(chart: chart, jd: jd)
                return (result, speculum)
            }.value

            guard !Task.isCancelled else { return }

            // Assign back on MainActor (we're already on it — @MainActor func)
            self.result = computed.0
            self.fullSpeculum = computed.1
            self.applyFilters()
            self.refreshCachedContextualAvailability()
            self.isCalculating = false
        }
    }

    // MARK: - Apply Filters

    /// Filtra `result.enrichedDirections` con los PDFilters actuales.
    /// Sincrónico — siempre en MainActor.
    func applyFilters() {
        guard let result else {
            filteredDirections = []
            selectedDirection = nil
            return
        }
        let visible = result.enrichedDirections.filter { filters.matches($0) }
        filteredDirections = visible

        if let selected = selectedDirection, visible.contains(where: { $0.id == selected.id }) {
            refreshCachedContextualAvailability()
            return
        }

        selectedDirection = Self.preferredInitialSelection(from: visible)
        refreshCachedContextualAvailability()
    }

    nonisolated static func preferredInitialSelection(
        from visible: [EnrichedPrimaryDirection]
    ) -> EnrichedPrimaryDirection? {
        visible.first(where: \.hasInterpretation) ?? visible.first
    }

    nonisolated private static func currentYear(for chart: NatalChart) -> Int {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: chart.timezone) ?? .current
        return calendar.component(.year, from: Date())
    }

    var curatedVisibleDirections: [EnrichedPrimaryDirection] {
        filteredDirections.filter(\.hasInterpretation)
    }

    func refreshForUpdatedSettings() {
        syncFiltersToSettings()
        reloadCurrentChart()
    }

    var filtersAreDefault: Bool {
        filters == PDFilters(maxYears: settings.maxYears, preset: activePreset)
    }

    var presetDisplayName: String {
        activePreset?.rawValue ?? "Personalizado"
    }

    var visibleCriticalCount: Int {
        filteredDirections.filter { $0.direction.weight == .critical }.count
    }

    var currentChart: NatalChart? { chart }

    var directionsForSelectedYear: [EnrichedPrimaryDirection] {
        let calendar = Calendar.current
        var startComponents = DateComponents()
        startComponents.year = selectedYear
        startComponents.month = 1
        startComponents.day = 1

        var endComponents = DateComponents()
        endComponents.year = selectedYear
        endComponents.month = 12
        endComponents.day = 31
        endComponents.hour = 23
        endComponents.minute = 59
        endComponents.second = 59

        guard let yearStart = calendar.date(from: startComponents),
              let yearEnd = calendar.date(from: endComponents),
              let windowStart = calendar.date(byAdding: .month, value: -18, to: yearStart),
              let windowEnd = calendar.date(byAdding: .month, value: 18, to: yearEnd) else {
            return []
        }

        return filteredDirections
            .filter { windowStart...windowEnd ~= $0.direction.estimatedDate }
            .sorted { $0.direction.estimatedDate < $1.direction.estimatedDate }
    }

    func reloadCurrentChart() {
        guard let chart else { return }
        loadDirections(chart: chart, jd: julianDay, birthDate: birthDate)
    }

    var visibleAgeDomain: ClosedRange<Double> {
        let lower = max(0, min(filters.ageRange.lowerBound, settings.maxYears))
        let unclampedUpper = min(filters.ageRange.upperBound, settings.maxYears)
        let upper = max(lower + 1, unclampedUpper)
        return lower...upper
    }

    // MARK: - Request Contextual Interpretation (Capa 2)

    /// Solicita al LLM la interpretación morinista de la dirección seleccionada.
    func requestContextualInterpretation(for enriched: EnrichedPrimaryDirection) {
        guard let interpreter, let chart else {
            error = "Intérprete contextual no disponible."
            return
        }
        interpretationTask?.cancel()
        isGeneratingInterpretation = true
        contextualInterpretation = nil

        let direction = enriched.direction
        let context = PDInterpretationContextBuilder.build(chart: chart, direction: direction)

        interpretationTask = Task {
            do {
                let interp = try await interpreter.interpret(
                    direction: direction, context: context
                )
                guard !Task.isCancelled else { return }
                self.contextualInterpretation = interp
                self.cachedContextualDirectionIDs.insert(direction.id)
                self.isGeneratingInterpretation = false
            } catch {
                guard !Task.isCancelled else { return }
                self.isGeneratingInterpretation = false
                self.error = error.localizedDescription
            }
        }
    }

    // MARK: - Invalidate Interpretation Cache

    func invalidateInterpretation(for direction: PrimaryDirection) {
        Task {
            await interpreter?.invalidateCache(for: direction.id)
            self.cachedContextualDirectionIDs.remove(direction.id)
            if selectedDirection?.direction.id == direction.id {
                contextualInterpretation = nil
            }
        }
    }

    private func syncFiltersToSettings() {
        let current = filters.ageRange
        let clampedLower = min(current.lowerBound, max(0, settings.maxYears - 1))
        let clampedUpper = min(current.upperBound, settings.maxYears)
        let nextUpper = max(clampedLower + 1, clampedUpper)
        let desired = clampedLower...nextUpper

        if filtersAreDefault || current == PDFilters().ageRange {
            updateFiltersInternally { $0.ageRange = 0...settings.maxYears }
        } else if current != desired {
            updateFiltersInternally { $0.ageRange = desired }
        }
    }

    private func applyPresetFilters(_ preset: PDFilterPreset) {
        var next = PDFilters(maxYears: settings.maxYears, preset: preset)
        let lower = min(filters.ageRange.lowerBound, max(0, settings.maxYears - 1))
        let upper = max(lower + 1, min(filters.ageRange.upperBound, settings.maxYears))
        next.ageRange = lower...upper
        isApplyingPresetFilters = true
        defer { isApplyingPresetFilters = false }
        filters = next
    }

    private func updateFiltersInternally(_ mutate: (inout PDFilters) -> Void) {
        var next = filters
        mutate(&next)
        guard next != filters else { return }
        isApplyingPresetFilters = true
        defer { isApplyingPresetFilters = false }
        filters = next
    }

    private func markPresetAsCustom() {
        guard activePreset != nil else { return }
        activePreset = nil
    }

    private func refreshCachedContextualAvailability() {
        guard let interpreter else {
            cachedContextualDirectionIDs = []
            return
        }

        let directionIDs = filteredDirections.map(\.direction.id)
        Task {
            let cached = await interpreter.cachedDirectionIDs(for: directionIDs)
            guard !Task.isCancelled else { return }
            self.cachedContextualDirectionIDs = cached
            self.loadCachedInterpretationForSelection()
        }
    }

    private func loadCachedInterpretationForSelection() {
        guard let interpreter, let directionID = selectedDirection?.direction.id else {
            return
        }

        Task {
            let cached = await interpreter.cachedInterpretation(for: directionID)
            guard !Task.isCancelled,
                  self.selectedDirection?.direction.id == directionID else { return }
            self.contextualInterpretation = cached
        }
    }
}

// MARK: - PDFilters

/// Filtros aplicados sobre las direcciones calculadas.
struct PDFilters: Equatable, Sendable {
    var ageRange: ClosedRange<Double> = 0...90
    var aspects: Set<PDaspect> = Set(PDaspect.allCases)
    var directionTypes: Set<PDDirectionType> = Set(PDDirectionType.allCases)
    var aspectPlanes: Set<PDAspectPlane> = Set(PDAspectPlane.allCases)
    var promissors: Set<String> = []         // vacío = todos
    var minimumWeight: PDWeight = .minor
    var onlyWithCorpus: Bool = false

    init(maxYears: Double = 90, preset: PDFilterPreset? = nil) {
        self.ageRange = 0...maxYears
        if let preset {
            self.aspects = preset.aspects
            self.promissors = preset.promissors
            self.minimumWeight = preset.defaultMinimumWeight
        }
    }

    var isDefault: Bool {
        self == PDFilters()
    }

    func matches(_ enriched: EnrichedPrimaryDirection) -> Bool {
        let dir = enriched.direction
        guard ageRange.contains(dir.estimatedAge) else { return false }
        guard aspects.contains(dir.aspect) else { return false }
        guard directionTypes.contains(dir.directionType) else { return false }
        guard aspectPlanes.contains(dir.aspectPlane) else { return false }
        guard dir.weight >= minimumWeight else { return false }
        if !promissors.isEmpty, !promissors.contains(dir.promissor) { return false }
        if onlyWithCorpus, !enriched.hasInterpretation { return false }
        return true
    }

    mutating func reset(maxYears: Double = 90) { self = PDFilters(maxYears: maxYears) }
}

// MARK: - PDSettings

/// Configuración de cálculo persistida en UserDefaults.
struct PDSettings: Equatable, Sendable {
    var method: PrimaryDirectionMethod = .regiomontanus
    var key: PrimaryDirectionKey = .naibod
    var maxYears: Double = 90
    var aspectPlane: PDAspectPlane = .zodiacal
    var filterPreset: PDFilterPreset? = .classical

    private static let keyUD = "PrimaryDirections.Key"
    private static let methodUD = "PrimaryDirections.Method"
    private static let maxYearsUD = "PrimaryDirections.MaxYears"
    private static let planeUD = "PrimaryDirections.AspectPlane"
    private static let planeVersionUD = "PrimaryDirections.AspectPlane.Version"
    private static let filterPresetUD = "PrimaryDirections.FilterPreset"
    private static let customPresetValue = "Personalizado"

    static func load() -> PDSettings {
        var s = PDSettings()
        let ud = UserDefaults.standard
        if let raw = ud.string(forKey: keyUD), let k = PrimaryDirectionKey(rawValue: raw) {
            s.key = k
        }
        if let raw = ud.string(forKey: methodUD), let m = PrimaryDirectionMethod(rawValue: raw) {
            s.method = m
        }
        if ud.integer(forKey: planeVersionUD) < 2 {
            s.aspectPlane = .zodiacal
            ud.set(PDAspectPlane.zodiacal.rawValue, forKey: planeUD)
            ud.set(2, forKey: planeVersionUD)
        } else if let raw = ud.string(forKey: planeUD), let p = PDAspectPlane(rawValue: raw) {
            s.aspectPlane = p
        }
        let years = ud.double(forKey: maxYearsUD)
        if years > 0 { s.maxYears = years }
        if ud.object(forKey: filterPresetUD) == nil {
            s.filterPreset = .classical
        } else if let raw = ud.string(forKey: filterPresetUD) {
            s.filterPreset = raw == customPresetValue ? nil : PDFilterPreset(rawValue: raw)
        }
        return s
    }

    func persist() {
        let ud = UserDefaults.standard
        ud.set(key.rawValue, forKey: Self.keyUD)
        ud.set(method.rawValue, forKey: Self.methodUD)
        ud.set(aspectPlane.rawValue, forKey: Self.planeUD)
        ud.set(2, forKey: Self.planeVersionUD)
        ud.set(maxYears, forKey: Self.maxYearsUD)
        ud.set(filterPreset?.rawValue ?? Self.customPresetValue, forKey: Self.filterPresetUD)
    }

    var calculatorConfig: PrimaryDirectionCalculator.Config {
        let preset = filterPreset
        return PrimaryDirectionCalculator.Config(
            method: method,
            key: key,
            maxYears: maxYears,
            aspects: preset?.orderedAspects ?? PDaspect.allCases,
            promissors: preset?.orderedPromissors ?? [],
            significators: preset?.orderedSignificators ?? [],
            aspectPlane: aspectPlane
        )
    }
}
