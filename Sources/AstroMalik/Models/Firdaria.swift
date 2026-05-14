import Foundation

enum FirdariaPeriodKind: String, Codable, Equatable {
    case major
    case minor
}

struct FirdariaPeriod: Identifiable, Codable, Equatable {
    var id: String
    var kind: FirdariaPeriodKind
    var ruler: AstroPlanetKey
    var cycleIndex: Int
    var sequenceIndex: Int
    var startDate: Date
    var endDate: Date
    var nominalYears: Double

    var isNodePeriod: Bool { ruler.isNode }
}

struct FirdariaTimeline: Codable, Equatable {
    var sect: SectInfo
    var birthDate: Date
    var cycleIndex: Int
    var cycleStartDate: Date
    var cycleEndDate: Date
    var majorPeriods: [FirdariaPeriod]
}

struct FirdariaMinorChange: Identifiable, Codable, Equatable {
    var id: String
    var date: Date
    var period: FirdariaPeriod
}
