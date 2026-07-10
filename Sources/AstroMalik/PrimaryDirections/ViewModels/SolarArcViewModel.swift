import Foundation
import SwiftUI

@MainActor
final class SolarArcViewModel: ObservableObject {
    @Published private(set) var directions: [SolarArcDirection] = []
    @Published private(set) var filteredDirections: [SolarArcDirection] = []
    @Published var selectedDirection: EnrichedPrimaryDirection?
    @Published var ageStart: Double = 0
    @Published var ageEnd: Double = 90
    @Published var mode: SolarArcMode = .real
    @Published var orb: Double = 1.0
    @Published var activePreset: PDFilterPreset? = .classical {
        didSet { applyFilters() }
    }
    @Published var minimumWeight: PDWeight = PDFilterPreset.classical.defaultMinimumWeight {
        didSet { applyFilters() }
    }
    @Published private(set) var isCalculating = false
    @Published var error: String?

    private let engine = SolarArcEngine()
    private var chart: NatalChart?
    private var calculationTask: Task<Void, Never>?

    var currentChart: NatalChart? { chart }

    var enrichedDirections: [EnrichedPrimaryDirection] {
        filteredDirections.map { EnrichedPrimaryDirection(direction: $0.primaryDirectionAdapter, interpretation: nil) }
    }

    var visibleAgeDomain: ClosedRange<Double> {
        let lower = max(0, min(ageStart, ageEnd))
        let upper = max(lower + 1, max(ageStart, ageEnd))
        return lower...upper
    }

    var visibleCriticalCount: Int {
        filteredDirections.filter { $0.weight == .critical }.count
    }

    var presetDisplayName: String { activePreset?.rawValue ?? "Personalizado" }

    func load(chart: NatalChart) {
        self.chart = chart
        let current = Self.currentAge(for: chart)
        ageStart = max(0, current - 2)
        ageEnd = current + 2
        recalculate()
    }

    func recalculate() {
        guard let chart else { return }
        calculationTask?.cancel()
        isCalculating = true
        error = nil
        selectedDirection = nil

        let start = min(ageStart, ageEnd)
        let end = max(ageStart, ageEnd)
        let mode = mode
        let orb = max(0, orb)
        let engine = self.engine

        calculationTask = Task {
            let computed = await Task.detached(priority: .userInitiated) {
                engine.solarArc(chart: chart, from: start, to: end, mode: mode, orb: orb)
            }.value
            guard !Task.isCancelled else { return }
            self.directions = computed
            self.applyFilters()
            self.isCalculating = false
        }
    }

    func applyFilters() {
        let preset = activePreset
        let filtered = directions.filter { direction in
            guard direction.weight >= minimumWeight else { return false }
            guard preset?.aspects.contains(direction.aspect) ?? true else { return false }
            if let promissors = preset?.promissors, !promissors.isEmpty,
               !promissors.contains(direction.directedPoint) { return false }
            return true
        }
        filteredDirections = filtered
        let enriched = filtered.map { EnrichedPrimaryDirection(direction: $0.primaryDirectionAdapter, interpretation: nil) }
        if let selected = selectedDirection, enriched.contains(where: { $0.id == selected.id }) {
            return
        }
        selectedDirection = enriched.first
    }

    func setCurrentWindow(years: Double = 2) {
        guard let chart else { return }
        let current = Self.currentAge(for: chart)
        ageStart = max(0, current - years)
        ageEnd = current + years
        recalculate()
    }

    nonisolated static func currentAge(for chart: NatalChart, now: Date = Date()) -> Double {
        guard let birth = try? localDateFromBirthData(
            birthDate: chart.birthDate,
            birthTime: chart.birthTime,
            timezoneName: chart.timezone
        ) else { return 49 }
        return max(0, now.timeIntervalSince(birth) / (365.25 * 24 * 3600))
    }
}

extension SolarArcDirection {
    var primaryDirectionAdapter: PrimaryDirection {
        PrimaryDirection(
            id: id,
            promissor: directedPoint,
            promissorLabel: directedPointLabel,
            significator: natalPoint,
            significatorLabel: natalPointLabel,
            aspect: aspect,
            aspectAngle: aspectAngle,
            directionType: .direct,
            aspectPlane: .ecliptic,
            arc: solarArc,
            estimatedAge: exactAge,
            estimatedDate: exactDate,
            method: .regiomontanus,
            key: mode == .naibod ? .naibod : .ptolemy,
            technicalData: PDTechnicalData(
                promissorRA: directedLongitude,
                promissorDeclination: 0,
                significatorRA: natalLongitude,
                significatorDeclination: 0,
                significatorPole: 0,
                obliquity: 0,
                ramc: 0,
                geoLatitude: 0
            ),
            weight: weight
        )
    }

    var displaySummary: String {
        "\(directedPointLabel) dirigido \(aspect.label) \(natalPointLabel) natal"
    }

    var ageFormatted: String {
        let years = Int(exactAge)
        let months = Int((exactAge - Double(years)) * 12)
        if months == 0 { return "\(years) años" }
        return "\(years) años, \(months) meses"
    }

    var arcFormatted: String {
        let degrees = Int(abs(solarArc))
        let minutes = Int((abs(solarArc) - Double(degrees)) * 60)
        let seconds = Int(((abs(solarArc) - Double(degrees)) * 60 - Double(minutes)) * 60)
        return "\(degrees)°\(String(format: "%02d", minutes))'\(String(format: "%02d", seconds))\""
    }
}
