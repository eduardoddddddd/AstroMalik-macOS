import Foundation

enum ZRLot: String, Codable, CaseIterable, Identifiable, Hashable {
    case fortune
    case spirit

    var id: String { rawValue }

    var label: String {
        switch self {
        case .fortune: return "Fortuna"
        case .spirit: return "Espíritu"
        }
    }

    var symbol: String {
        switch self {
        case .fortune: return "⊕"
        case .spirit: return "☉"
        }
    }

    var noteLabel: String {
        switch self {
        case .fortune: return "Lote de Fortuna"
        case .spirit: return "Lote de Espíritu"
        }
    }
}

final class ZodiacalReleasingEngine {
    static let signYears: [Int] = [
        15, // Aries
        8,  // Tauro
        20, // Géminis
        25, // Cáncer
        19, // Leo
        20, // Virgo
        8,  // Libra
        15, // Escorpio
        12, // Sagitario
        27, // Capricornio
        30, // Acuario
        12, // Piscis
    ]

    private static let secondsPerDay: TimeInterval = 86_400
    private static let schoolMonthDays: TimeInterval = 30

    func zr(chart: Chart, lot: ZRLot, depth: Int = 2) -> ZRTimeline {
        let sect = SectEngine.sect(of: chart)
        let lotPoint = (try? HellenisticLots.lot(lot, chart: chart)) ?? fallbackLotPoint(lot: lot, chart: chart, sect: sect)
        let calendar = calendar(for: chart)
        let birth = (try? birthDate(for: chart, calendar: calendar)) ?? chart.createdAt
        let resolvedDepth = min(4, max(1, depth))
        var highlightedEvents: [ZREvent] = []
        var periods: [ZRPeriod] = []
        var cursor = birth

        for sequence in 0..<12 {
            let signIndex = wrapped(lotPoint.signIndex + sequence)
            let years = Self.signYears[signIndex]
            let end = calendar.date(byAdding: .year, value: years, to: cursor)
                ?? cursor.addingTimeInterval(Double(years) * 365.2422 * Self.secondsPerDay)

            var events: [ZREvent] = []
            if sequence > 0 {
                let event = ZREvent(
                    id: "zr-l1-change-\(lot.rawValue)-\(sequence)-\(SIGN_KEYS[signIndex])",
                    kind: .levelOneChange,
                    level: .l1,
                    date: cursor,
                    title: "Entra L1 en \(SIGN_LABELS[signIndex])",
                    detail: "Nuevo capítulo mayor de \(lot.noteLabel).",
                    signIndex: signIndex,
                    signKey: SIGN_KEYS[signIndex],
                    signLabel: SIGN_LABELS[signIndex],
                    parentSignIndex: nil
                )
                events.append(event)
                highlightedEvents.append(event)
            }

            var period = makePeriod(
                lot: lot,
                level: .l1,
                sequence: sequence,
                signIndex: signIndex,
                start: cursor,
                end: end,
                nominalUnits: Double(years),
                unitLabel: ZRLevel.l1.unitLabel,
                angularity: nil,
                isPeak: false,
                events: events,
                children: []
            )

            if resolvedDepth >= 2 {
                period.children = subperiods(
                    lot: lot,
                    parent: period,
                    childLevel: .l2,
                    maxDepth: resolvedDepth,
                    l1SignIndex: signIndex,
                    highlightedEvents: &highlightedEvents
                )
            }

            periods.append(period)
            cursor = end
        }

        highlightedEvents.sort { lhs, rhs in
            if lhs.date != rhs.date { return lhs.date < rhs.date }
            return lhs.kind.rawValue < rhs.kind.rawValue
        }

        return ZRTimeline(
            lot: lot,
            lotPoint: lotPoint,
            sect: sect,
            birthDate: birth,
            generatedAt: Date(),
            depth: resolvedDepth,
            periods: periods,
            highlightedEvents: highlightedEvents
        )
    }

    private func subperiods(
        lot: ZRLot,
        parent: ZRPeriod,
        childLevel: ZRLevel,
        maxDepth: Int,
        l1SignIndex: Int,
        highlightedEvents: inout [ZREvent]
    ) -> [ZRPeriod] {
        guard childLevel.rawValue <= maxDepth else { return [] }

        let unitSeconds = secondsPerUnit(for: childLevel)
        var periods: [ZRPeriod] = []
        var cursor = parent.startDate
        var signIndex = parent.signIndex
        var sequence = 0

        while cursor < parent.endDate {
            let nominal = Double(Self.signYears[signIndex])
            let proposedEnd = cursor.addingTimeInterval(nominal * unitSeconds)
            let end = minDate(proposedEnd, parent.endDate)
            let angularity = angularity(of: signIndex, relativeTo: l1SignIndex)
            let isPeak = childLevel == .l2 && angularity == .angular
            var events: [ZREvent] = []

            if isPeak {
                let event = ZREvent(
                    id: "zr-peak-\(lot.rawValue)-\(parent.id)-\(sequence)-\(SIGN_KEYS[signIndex])",
                    kind: .peak,
                    level: childLevel,
                    date: cursor,
                    title: "Peak \(childLevel.label) en \(SIGN_LABELS[signIndex])",
                    detail: "\(SIGN_LABELS[signIndex]) está angular respecto al capítulo L1 \(parent.signLabel).",
                    signIndex: signIndex,
                    signKey: SIGN_KEYS[signIndex],
                    signLabel: SIGN_LABELS[signIndex],
                    parentSignIndex: l1SignIndex
                )
                events.append(event)
                highlightedEvents.append(event)
            }

            let shouldLoosenBond = childLevel == .l2
                && isLoosingSign(signIndex)
                && end < parent.endDate
            if shouldLoosenBond {
                let jumpSign = opposite(of: l1SignIndex)
                let event = ZREvent(
                    id: "zr-lb-\(lot.rawValue)-\(parent.id)-\(sequence)-\(SIGN_KEYS[signIndex])",
                    kind: .loosingOfBond,
                    level: childLevel,
                    date: end,
                    title: "Loosing of the Bond",
                    detail: "Al terminar \(SIGN_LABELS[signIndex]) el siguiente L2 salta a \(SIGN_LABELS[jumpSign]), opuesto al inicio L1 \(parent.signLabel).",
                    signIndex: signIndex,
                    signKey: SIGN_KEYS[signIndex],
                    signLabel: SIGN_LABELS[signIndex],
                    parentSignIndex: l1SignIndex
                )
                events.append(event)
                highlightedEvents.append(event)
            }

            var period = makePeriod(
                lot: lot,
                level: childLevel,
                sequence: sequence,
                signIndex: signIndex,
                start: cursor,
                end: end,
                nominalUnits: nominal,
                unitLabel: childLevel.unitLabel,
                angularity: angularity,
                isPeak: isPeak,
                events: events,
                children: []
            )

            if let nextLevel = ZRLevel(rawValue: childLevel.rawValue + 1), nextLevel.rawValue <= maxDepth {
                period.children = subperiods(
                    lot: lot,
                    parent: period,
                    childLevel: nextLevel,
                    maxDepth: maxDepth,
                    l1SignIndex: l1SignIndex,
                    highlightedEvents: &highlightedEvents
                )
            }

            periods.append(period)
            cursor = end
            if shouldLoosenBond {
                signIndex = opposite(of: l1SignIndex)
            } else {
                signIndex = wrapped(signIndex + 1)
            }
            sequence += 1
        }

        return periods
    }

    private func makePeriod(
        lot: ZRLot,
        level: ZRLevel,
        sequence: Int,
        signIndex: Int,
        start: Date,
        end: Date,
        nominalUnits: Double,
        unitLabel: String,
        angularity: ZRAngularity?,
        isPeak: Bool,
        events: [ZREvent],
        children: [ZRPeriod]
    ) -> ZRPeriod {
        ZRPeriod(
            id: "zr-\(lot.rawValue)-\(level.label)-\(sequence)-\(SIGN_KEYS[signIndex])-\(Int(start.timeIntervalSince1970))",
            level: level,
            sequenceIndex: sequence,
            signIndex: signIndex,
            signKey: SIGN_KEYS[signIndex],
            signLabel: SIGN_LABELS[signIndex],
            startDate: start,
            endDate: end,
            nominalUnits: nominalUnits,
            unitLabel: unitLabel,
            angularity: angularity,
            isPeak: isPeak,
            events: events,
            children: children
        )
    }

    private func secondsPerUnit(for level: ZRLevel) -> TimeInterval {
        switch level {
        case .l1:
            return 365.2422 * Self.secondsPerDay
        case .l2:
            return Self.schoolMonthDays * Self.secondsPerDay
        case .l3:
            return Self.secondsPerDay
        case .l4:
            return 3_600
        }
    }

    private func angularity(of signIndex: Int, relativeTo rootSignIndex: Int) -> ZRAngularity {
        let offset = wrapped(signIndex - rootSignIndex)
        switch offset % 3 {
        case 0: return .angular
        case 1: return .succedent
        default: return .cadent
        }
    }

    private func isLoosingSign(_ signIndex: Int) -> Bool {
        signIndex == 3 || signIndex == 9 // Cáncer o Capricornio
    }

    private func opposite(of signIndex: Int) -> Int {
        wrapped(signIndex + 6)
    }

    private func wrapped(_ signIndex: Int) -> Int {
        ((signIndex % 12) + 12) % 12
    }

    private func minDate(_ lhs: Date, _ rhs: Date) -> Date {
        lhs <= rhs ? lhs : rhs
    }

    private func birthDate(for chart: Chart, calendar: Calendar) throws -> Date {
        do {
            return try localDateFromBirthData(
                birthDate: chart.birthDate,
                birthTime: chart.birthTime,
                timezoneName: calendar.timeZone.identifier
            )
        } catch {
            throw ZodiacalReleasingError.invalidBirthData
        }
    }

    private func calendar(for chart: Chart) -> Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: chart.timezone) ?? TimeZone(secondsFromGMT: 0) ?? .gmt
        return calendar
    }

    private func fallbackLotPoint(lot: ZRLot, chart: Chart, sect: SectInfo) -> HellenisticLotPoint {
        let longitude = normalized(chart.ascendant.longitude)
        let index = max(0, min(11, Int(longitude / 30.0)))
        return HellenisticLotPoint(
            key: lot.rawValue,
            name: lot.label,
            longitude: longitude,
            formatted: AstroEngine.degToSign(longitude),
            signIndex: index,
            signKey: SIGN_KEYS[index],
            signLabel: SIGN_LABELS[index],
            sect: sect
        )
    }

    private func normalized(_ degree: Double) -> Double {
        var value = degree.truncatingRemainder(dividingBy: 360.0)
        if value < 0 { value += 360.0 }
        return value
    }
}

enum ZodiacalReleasingError: LocalizedError, Equatable {
    case invalidBirthData

    var errorDescription: String? {
        switch self {
        case .invalidBirthData:
            return "La carta natal no contiene fecha/hora válidas para calcular Zodiacal Releasing."
        }
    }
}
