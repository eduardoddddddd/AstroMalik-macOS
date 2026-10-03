import Foundation

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
