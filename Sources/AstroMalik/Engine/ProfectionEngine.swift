import Foundation

enum ProfectionError: LocalizedError, Equatable {
    case invalidBirthData
    case dateBeforeBirth

    var errorDescription: String? {
        switch self {
        case .invalidBirthData:
            return "La carta natal no contiene fecha/hora válidas para calcular profecciones."
        case .dateBeforeBirth:
            return "La fecha de profección es anterior al nacimiento."
        }
    }
}

final class ProfectionEngine {
    private static let tropicalYearDays = 365.2422
    private static let profectionMonthDays = tropicalYearDays / 12.0
    private static let dailyHouseDays = 28.0

    private let corpusStore: CorpusStore

    init(corpusStore: CorpusStore) {
        self.corpusStore = corpusStore
    }

    func profections(for chart: NatalChart, at date: Date) async throws -> ProfectionResult {
        let timing = try annualTiming(for: chart, at: date)
        let annualWholeSign = wholeSignHouse(for: chart.ascendant.longitude, age: timing.age)
        let annual = makePeriod(
            chart: chart,
            kind: .annual,
            sequence: timing.age,
            age: timing.age,
            profectionStep: timing.age,
            startDate: timing.annualStart,
            endDate: timing.annualEnd
        )

        let monthly = makeMonthlyPeriods(chart: chart, timing: timing, at: date)
        let daily = makeDailyWeek(chart: chart, timing: timing, at: date)
        let activations = try await yearlyActivations(chart: chart, annual: annual, timing: timing)

        assert(annual.house == annualWholeSign.house)
        return ProfectionResult(
            annual: annual,
            monthly: monthly,
            daily: daily,
            activations: activations
        )
    }

    private func makeMonthlyPeriods(
        chart: NatalChart,
        timing: AnnualTiming,
        at date: Date
    ) -> [ProfectionPeriod] {
        let elapsed = max(0, date.timeIntervalSince(timing.annualStart) / 86_400.0)
        let currentIndex = max(0, Int(floor(elapsed / Self.profectionMonthDays)))
        return (0..<4).map { offset in
            let index = currentIndex + offset
            let start = timing.annualStart.addingTimeInterval(Double(index) * Self.profectionMonthDays * 86_400.0)
            let end = timing.annualStart.addingTimeInterval(Double(index + 1) * Self.profectionMonthDays * 86_400.0)
            return makePeriod(
                chart: chart,
                kind: .monthly,
                sequence: index,
                age: timing.age,
                profectionStep: timing.age + index,
                startDate: start,
                endDate: min(end, timing.annualEnd)
            )
        }
    }

    private func makeDailyWeek(
        chart: NatalChart,
        timing: AnnualTiming,
        at date: Date
    ) -> [ProfectionPeriod] {
        let calendar = calendar(for: chart)
        let startOfDay = calendar.startOfDay(for: date)
        return (0..<7).compactMap { offset in
            guard let day = calendar.date(byAdding: .day, value: offset, to: startOfDay) else { return nil }
            let elapsed = max(0, day.timeIntervalSince(timing.annualStart) / 86_400.0)
            let index = max(0, Int(floor(elapsed / Self.dailyHouseDays)))
            let periodStart = timing.annualStart.addingTimeInterval(Double(index) * Self.dailyHouseDays * 86_400.0)
            let periodEnd = timing.annualStart.addingTimeInterval(Double(index + 1) * Self.dailyHouseDays * 86_400.0)
            return makePeriod(
                chart: chart,
                kind: .daily,
                sequence: index,
                age: timing.age,
                profectionStep: timing.age + index,
                startDate: maxDate(periodStart, day),
                endDate: min(periodEnd, timing.annualEnd)
            )
        }
    }

    private func makePeriod(
        chart: NatalChart,
        kind: ProfectionPeriodKind,
        sequence: Int,
        age: Int,
        profectionStep: Int,
        startDate: Date,
        endDate: Date
    ) -> ProfectionPeriod {
        let wholeSign = wholeSignHouse(for: chart.ascendant.longitude, age: profectionStep)
        let house = wholeSign.house
        let signIndex = wholeSign.signIndex
        let cusp = Double(signIndex) * 30.0
        let signKey = SIGN_KEYS[signIndex]
        let signLabel = SIGN_LABELS[signIndex]
        let lordKey = EssentialDignityEngine.domicileRuler(of: signIndex)
        let lordLabel = planetLabel(for: lordKey)
        let planets = chart.bodies
            .filter { zodiacSignIndex(for: $0.longitude) == signIndex }
            .map(ProfectionPlanet.init(body:))
            .sorted { $0.longitude < $1.longitude }
        let lordAspects = natalAspectsByLord(chart: chart, lordKey: lordKey, lordLabel: lordLabel)

        return ProfectionPeriod(
            id: "\(kind.rawValue)-\(age)-\(sequence)-\(house)",
            kind: kind,
            sequence: sequence,
            age: age,
            house: house,
            signKey: signKey,
            signLabel: signLabel,
            cuspLongitude: cusp,
            cuspFormatted: AstroEngine.degToSign(cusp),
            lordKey: lordKey,
            lordLabel: lordLabel,
            startDate: startDate,
            endDate: endDate,
            natalPlanetsInHouse: planets,
            natalAspectsByLord: lordAspects
        )
    }

    private func natalAspectsByLord(
        chart: NatalChart,
        lordKey: String,
        lordLabel: String
    ) -> [ProfectionNatalAspect] {
        let rawPlanets = Dictionary(uniqueKeysWithValues: chart.bodies.map { body in
            (body.key, AstroEngine.RawPlanet(
                key: body.key,
                label: body.label,
                deg: body.longitude,
                speed: body.retrograde ? -1 : 1,
                retro: body.retrograde
            ))
        })
        return AstroEngine.computeNatalAspects(planets: rawPlanets).compactMap { aspect in
            if aspect.keyA == lordKey {
                return ProfectionNatalAspect(
                    lotyKey: lordKey,
                    lotyLabel: lordLabel,
                    planetKey: aspect.keyB,
                    planetLabel: aspect.labelB,
                    aspectKey: aspect.aspKey,
                    aspectLabel: aspect.aspLabel,
                    orb: aspect.orb
                )
            }
            if aspect.keyB == lordKey {
                return ProfectionNatalAspect(
                    lotyKey: lordKey,
                    lotyLabel: lordLabel,
                    planetKey: aspect.keyA,
                    planetLabel: aspect.labelA,
                    aspectKey: aspect.aspKey,
                    aspectLabel: aspect.aspLabel,
                    orb: aspect.orb
                )
            }
            return nil
        }
        .sorted { lhs, rhs in
            if lhs.orb != rhs.orb { return lhs.orb < rhs.orb }
            return lhs.planetKey < rhs.planetKey
        }
    }

    private func yearlyActivations(
        chart: NatalChart,
        annual: ProfectionPeriod,
        timing: AnnualTiming
    ) async throws -> [TransitEvent] {
        let natalPlanetKeys = Set(chart.bodies.map(\.key))
        let calendar = calendar(for: chart)
        let fromDate = calendar.startOfDay(for: timing.annualStart)
        let toDate = calendar.date(byAdding: .day, value: -1, to: calendar.startOfDay(for: timing.annualEnd))
            ?? timing.annualEnd

        let events = try await computeTransitPeriod(
            natalChart: chart,
            fromDate: fromDate,
            toDate: toDate,
            timezone: chart.timezone,
            excludeMoon: false,
            corpusStore: corpusStore
        )

        return events.filter { event in
            (event.transitKey == annual.lordKey && natalPlanetKeys.contains(event.natalKey))
                || event.natalKey == annual.lordKey
        }
        .sorted { lhs, rhs in
            if lhs.priorityBand.rank != rhs.priorityBand.rank { return lhs.priorityBand.rank > rhs.priorityBand.rank }
            if lhs.priorityScore != rhs.priorityScore { return lhs.priorityScore > rhs.priorityScore }
            if lhs.minOrb != rhs.minOrb { return lhs.minOrb < rhs.minOrb }
            return lhs.exactDate < rhs.exactDate
        }
    }

    private func annualTiming(for chart: NatalChart, at date: Date) throws -> AnnualTiming {
        let calendar = calendar(for: chart)
        let birth = try birthComponents(for: chart)
        guard let birthDate = calendar.date(from: birth) else { throw ProfectionError.invalidBirthData }
        guard date >= birthDate else { throw ProfectionError.dateBeforeBirth }

        let dateComponents = calendar.dateComponents([.year], from: date)
        guard let currentYear = dateComponents.year,
              let birthYear = birth.year else { throw ProfectionError.invalidBirthData }

        var birthdayThisYear = birth
        birthdayThisYear.year = currentYear
        guard let birthdayDate = calendar.date(from: birthdayThisYear) else {
            throw ProfectionError.invalidBirthData
        }

        let age = currentYear - birthYear - (date < birthdayDate ? 1 : 0)
        guard age >= 0 else { throw ProfectionError.dateBeforeBirth }

        var annualStartComponents = birth
        annualStartComponents.year = birthYear + age
        var annualEndComponents = birth
        annualEndComponents.year = birthYear + age + 1
        guard let annualStart = calendar.date(from: annualStartComponents),
              let annualEnd = calendar.date(from: annualEndComponents) else {
            throw ProfectionError.invalidBirthData
        }

        return AnnualTiming(age: age, annualStart: annualStart, annualEnd: annualEnd)
    }

    private func birthComponents(for chart: NatalChart) throws -> DateComponents {
        let dateParts = chart.birthDate.split(separator: "-").compactMap { Int($0) }
        let timeParts = chart.birthTime.split(separator: ":").compactMap { Int($0) }
        guard dateParts.count == 3, timeParts.count >= 2 else { throw ProfectionError.invalidBirthData }

        return DateComponents(
            timeZone: TimeZone(identifier: chart.timezone) ?? TimeZone(secondsFromGMT: 0),
            year: dateParts[0],
            month: dateParts[1],
            day: dateParts[2],
            hour: timeParts[0],
            minute: timeParts[1],
            second: 0
        )
    }

    private func calendar(for chart: NatalChart) -> Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: chart.timezone) ?? TimeZone(secondsFromGMT: 0) ?? .gmt
        return calendar
    }

    private func wholeSignHouse(for ascLongitude: Double, age: Int) -> (house: Int, signIndex: Int) {
        let ascSign = zodiacSignIndex(for: ascLongitude)
        let house = ((age % 12) + 12) % 12 + 1
        let signIndex = (ascSign + ((age % 12) + 12) % 12) % 12
        return (house, signIndex)
    }

    private func zodiacSignIndex(for longitude: Double) -> Int {
        max(0, min(11, Int(normalized(longitude) / 30.0)))
    }

    private func planetLabel(for key: String) -> String {
        if let planet = PLANET_LIST.first(where: { $0.key == key }) {
            return planet.label
        }
        return key
    }

    private func normalized(_ degree: Double) -> Double {
        var value = degree.truncatingRemainder(dividingBy: 360)
        if value < 0 { value += 360 }
        return value
    }

    private func maxDate(_ lhs: Date, _ rhs: Date) -> Date {
        lhs >= rhs ? lhs : rhs
    }
}

private struct AnnualTiming {
    var age: Int
    var annualStart: Date
    var annualEnd: Date
}

private extension ProfectionPlanet {
    init(body: PlanetBody) {
        self.init(
            key: body.key,
            label: body.label,
            longitude: body.longitude,
            formatted: body.formatted,
            house: body.house,
            retrograde: body.retrograde
        )
    }
}
