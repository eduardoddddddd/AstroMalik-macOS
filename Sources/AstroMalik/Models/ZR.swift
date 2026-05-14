import Foundation

// MARK: - Zodiacal Releasing Models

enum ZRLevel: Int, Codable, CaseIterable, Identifiable, Hashable {
    case l1 = 1
    case l2 = 2
    case l3 = 3
    case l4 = 4

    var id: Int { rawValue }

    var label: String {
        switch self {
        case .l1: return "L1"
        case .l2: return "L2"
        case .l3: return "L3"
        case .l4: return "L4"
        }
    }

    var unitLabel: String {
        switch self {
        case .l1: return "años"
        case .l2: return "meses"
        case .l3: return "días"
        case .l4: return "horas"
        }
    }
}

enum ZRAngularity: String, Codable, CaseIterable, Identifiable, Hashable {
    case angular
    case succedent
    case cadent

    var id: String { rawValue }

    var label: String {
        switch self {
        case .angular: return "Angular"
        case .succedent: return "Sucedente"
        case .cadent: return "Cadente"
        }
    }

    var badge: String { rawValue.uppercased() }
}

enum ZREventKind: String, Codable, CaseIterable, Identifiable, Hashable {
    case levelOneChange
    case loosingOfBond
    case peak

    var id: String { rawValue }

    var label: String {
        switch self {
        case .levelOneChange: return "Cambio L1"
        case .loosingOfBond: return "Loosing of the Bond"
        case .peak: return "Peak"
        }
    }
}

struct HellenisticLotPoint: Identifiable, Codable, Equatable {
    var id: String { key }
    var key: String
    var name: String
    var longitude: Double
    var formatted: String
    var signIndex: Int
    var signKey: String
    var signLabel: String
    var sect: SectInfo
}

struct ZRTimeline: Codable, Equatable {
    var lot: ZRLot
    var lotPoint: HellenisticLotPoint
    var sect: SectInfo
    var birthDate: Date
    var generatedAt: Date
    var depth: Int
    var periods: [ZRPeriod]
    var highlightedEvents: [ZREvent]
}

struct ZRPeriod: Identifiable, Codable, Equatable, Hashable {
    var id: String
    var level: ZRLevel
    var sequenceIndex: Int
    var signIndex: Int
    var signKey: String
    var signLabel: String
    var startDate: Date
    var endDate: Date
    var nominalUnits: Double
    var unitLabel: String
    var angularity: ZRAngularity?
    var isPeak: Bool
    var events: [ZREvent]
    var children: [ZRPeriod]

    var hasLoosingOfBond: Bool {
        events.contains { $0.kind == .loosingOfBond }
    }

    var duration: TimeInterval {
        endDate.timeIntervalSince(startDate)
    }
}

struct ZREvent: Identifiable, Codable, Equatable, Hashable {
    var id: String
    var kind: ZREventKind
    var level: ZRLevel
    var date: Date
    var title: String
    var detail: String
    var signIndex: Int?
    var signKey: String?
    var signLabel: String?
    var parentSignIndex: Int?
}

extension ZRTimeline {
    func currentL1(at date: Date) -> ZRPeriod? {
        periods.first { $0.contains(date) }
    }

    func currentL2(at date: Date) -> ZRPeriod? {
        currentL1(at: date)?.children.first { $0.contains(date) }
    }

    func upcomingHighlightedEvents(after date: Date, limit: Int = 5) -> [ZREvent] {
        highlightedEvents
            .filter { $0.date > date }
            .sorted { lhs, rhs in
                if lhs.date != rhs.date { return lhs.date < rhs.date }
                return lhs.kind.rawValue < rhs.kind.rawValue
            }
            .prefix(limit)
            .map { $0 }
    }
}

extension ZRPeriod {
    func contains(_ date: Date) -> Bool {
        date >= startDate && date < endDate
    }

    func flattened(includeSelf: Bool = true) -> [ZRPeriod] {
        let descendants = children.flatMap { $0.flattened(includeSelf: true) }
        return includeSelf ? [self] + descendants : descendants
    }
}
