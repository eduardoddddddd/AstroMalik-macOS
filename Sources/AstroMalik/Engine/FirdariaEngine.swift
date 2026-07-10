import Foundation

enum FirdariaError: LocalizedError, Equatable {
    case invalidBirthData

    var errorDescription: String? {
        switch self {
        case .invalidBirthData:
            return "La carta natal no contiene fecha/hora válidas para calcular firdaria."
        }
    }
}

final class FirdariaEngine {
    static let cycleYears = 75

    private let diurnalOrder: [(AstroPlanetKey, Int)] = [
        (.sol, 10), (.venus, 8), (.mercurio, 13), (.luna, 9),
        (.saturno, 11), (.jupiter, 12), (.marte, 7),
        (.nodoNorte, 3), (.nodoSur, 2),
    ]

    private let nocturnalOrder: [(AstroPlanetKey, Int)] = [
        (.luna, 9), (.saturno, 11), (.jupiter, 12), (.marte, 7),
        (.sol, 10), (.venus, 8), (.mercurio, 13),
        (.nodoNorte, 3), (.nodoSur, 2),
    ]

    func firdariaPeriods(chart: Chart) -> FirdariaTimeline {
        let sect = SectEngine.sect(of: chart)
        let calendar = calendar(for: chart)
        let birth = (try? birthDate(for: chart, calendar: calendar)) ?? chart.createdAt
        return makeTimeline(chart: chart, sect: sect, birth: birth, cycleIndex: 0)
    }

    func firdariaTimeline(chart: Chart, at date: Date) -> FirdariaTimeline {
        let sect = SectEngine.sect(of: chart)
        let calendar = calendar(for: chart)
        let birth = (try? birthDate(for: chart, calendar: calendar)) ?? chart.createdAt
        let cycleIndex = cycleIndex(for: date, birth: birth, calendar: calendar)
        return makeTimeline(chart: chart, sect: sect, birth: birth, cycleIndex: cycleIndex)
    }

    func currentFirdaria(chart: Chart, at date: Date) -> (major: FirdariaPeriod, minor: FirdariaPeriod?) {
        let sect = SectEngine.sect(of: chart)
        let calendar = calendar(for: chart)
        let birth = (try? birthDate(for: chart, calendar: calendar)) ?? chart.createdAt
        let cycleIndex = cycleIndex(for: date, birth: birth, calendar: calendar)
        let timeline = makeTimeline(chart: chart, sect: sect, birth: birth, cycleIndex: cycleIndex)
        let effectiveDate = max(date, birth)
        let major = period(containing: effectiveDate, in: timeline.majorPeriods) ?? timeline.majorPeriods[0]
        let minor = minorPeriods(for: major, sect: sect).first { contains($0, date: effectiveDate) }
        return (major, minor)
    }

    func upcomingMinorChanges(chart: Chart, at date: Date, limit: Int = 5) -> [FirdariaMinorChange] {
        let sect = SectEngine.sect(of: chart)
        let calendar = calendar(for: chart)
        let birth = (try? birthDate(for: chart, calendar: calendar)) ?? chart.createdAt
        let initialCycle = cycleIndex(for: date, birth: birth, calendar: calendar)
        var changes: [FirdariaMinorChange] = []

        for cycle in initialCycle...(initialCycle + 2) where changes.count < limit {
            let timeline = makeTimeline(chart: chart, sect: sect, birth: birth, cycleIndex: cycle)
            for major in timeline.majorPeriods where changes.count < limit {
                let minors = minorPeriods(for: major, sect: sect)
                for minor in minors where minor.startDate > date {
                    changes.append(FirdariaMinorChange(
                        id: "minor-change-\(minor.id)",
                        date: minor.startDate,
                        period: minor
                    ))
                    if changes.count == limit { break }
                }
            }
        }
        return changes.sorted { $0.date < $1.date }.prefix(limit).map { $0 }
    }

    func minorPeriods(for major: FirdariaPeriod, sect: SectInfo) -> [FirdariaPeriod] {
        guard !major.ruler.isNode else { return [] }
        let rulers = minorRulers(startingWith: major.ruler, sect: sect)
        guard !rulers.isEmpty else { return [] }
        let duration = major.endDate.timeIntervalSince(major.startDate) / Double(rulers.count)
        return rulers.enumerated().map { index, ruler in
            let start = major.startDate.addingTimeInterval(Double(index) * duration)
            let end = index == rulers.count - 1
                ? major.endDate
                : major.startDate.addingTimeInterval(Double(index + 1) * duration)
            return FirdariaPeriod(
                id: "minor-\(major.cycleIndex)-\(major.sequenceIndex)-\(index)-\(ruler.key)",
                kind: .minor,
                ruler: ruler,
                cycleIndex: major.cycleIndex,
                sequenceIndex: index,
                startDate: start,
                endDate: end,
                nominalYears: major.nominalYears / Double(rulers.count)
            )
        }
    }

    private func makeTimeline(chart: Chart, sect: SectInfo, birth: Date, cycleIndex: Int) -> FirdariaTimeline {
        let calendar = calendar(for: chart)
        let cycleStart = calendar.date(byAdding: .year, value: cycleIndex * Self.cycleYears, to: birth) ?? birth
        let cycleEnd = calendar.date(byAdding: .year, value: Self.cycleYears, to: cycleStart)
            ?? cycleStart.addingTimeInterval(Double(Self.cycleYears) * 365.2422 * 86_400)
        let order = order(for: sect)
        var start = cycleStart
        let majorPeriods = order.enumerated().map { index, item in
            let end = calendar.date(byAdding: .year, value: item.1, to: start)
                ?? start.addingTimeInterval(Double(item.1) * 365.2422 * 86_400)
            defer { start = end }
            return FirdariaPeriod(
                id: "major-\(cycleIndex)-\(index)-\(item.0.key)",
                kind: .major,
                ruler: item.0,
                cycleIndex: cycleIndex,
                sequenceIndex: index,
                startDate: start,
                endDate: end,
                nominalYears: Double(item.1)
            )
        }
        return FirdariaTimeline(
            sect: sect,
            birthDate: birth,
            cycleIndex: cycleIndex,
            cycleStartDate: cycleStart,
            cycleEndDate: cycleEnd,
            majorPeriods: majorPeriods
        )
    }

    private func order(for sect: SectInfo) -> [(AstroPlanetKey, Int)] {
        sect.isDiurnal ? diurnalOrder : nocturnalOrder
    }

    private func minorRulers(startingWith ruler: AstroPlanetKey, sect: SectInfo) -> [AstroPlanetKey] {
        let classic = order(for: sect).map(\.0).filter { !$0.isNode }
        guard let startIndex = classic.firstIndex(of: ruler) else { return [] }
        return (0..<classic.count).map { classic[(startIndex + $0) % classic.count] }
    }

    private func period(containing date: Date, in periods: [FirdariaPeriod]) -> FirdariaPeriod? {
        periods.first { contains($0, date: date) }
    }

    private func contains(_ period: FirdariaPeriod, date: Date) -> Bool {
        date >= period.startDate && date < period.endDate
    }

    private func cycleIndex(for date: Date, birth: Date, calendar: Calendar) -> Int {
        guard date >= birth else { return 0 }
        let years = calendar.dateComponents([.year], from: birth, to: date).year ?? 0
        return max(0, years / Self.cycleYears)
    }

    private func birthDate(for chart: Chart, calendar: Calendar) throws -> Date {
        do {
            return try localDateFromBirthData(
                birthDate: chart.birthDate,
                birthTime: chart.birthTime,
                timezoneName: calendar.timeZone.identifier
            )
        } catch {
            throw FirdariaError.invalidBirthData
        }
    }

    private func calendar(for chart: Chart) -> Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: chart.timezone) ?? TimeZone(secondsFromGMT: 0) ?? .gmt
        return calendar
    }
}
