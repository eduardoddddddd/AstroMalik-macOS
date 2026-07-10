import Foundation

enum RectificationCandidateGeneratorError: LocalizedError {
    case noCandidates

    var errorDescription: String? { "No se pudo generar ninguna hora candidata válida." }
}

struct RectificationCandidateGenerator {
    func coarseCandidates(
        session: RectificationSession,
        config: RectificationConfig
    ) async throws -> [RectificationCandidate] {
        let times: [Date]
        if session.searchRange.includeFullDayFallback {
            let bounds = try allowedBounds(session: session)
            times = strideDates(
                from: bounds.lowerBound,
                through: bounds.upperBound,
                step: session.searchRange.coarseStepSeconds
            )
        } else {
            let center = try localDateFromBirthData(
                birthDate: session.birthDate,
                birthTime: session.searchRange.centerTime,
                timezoneName: session.timezone
            )
            times = strideDates(
                from: center.addingTimeInterval(-Double(session.searchRange.minutesBefore * 60)),
                through: center.addingTimeInterval(Double(session.searchRange.minutesAfter * 60)),
                step: session.searchRange.coarseStepSeconds
            )
        }
        return try await candidates(for: times, session: session, config: config)
    }

    func fineCandidates(
        around centers: [RectificationCandidate],
        session: RectificationSession,
        config: RectificationConfig
    ) async throws -> [RectificationCandidate] {
        let radius = max(session.searchRange.coarseStepSeconds, session.searchRange.fineStepSeconds)
        let bounds = try allowedBounds(session: session)
        var unique: [Int: Date] = [:]
        for candidate in centers {
            let center = try localDateFromBirthData(
                birthDate: session.birthDate,
                birthTime: candidate.birthTime,
                timezoneName: session.timezone
            )
            for date in strideDates(
                from: center.addingTimeInterval(-Double(radius)),
                through: center.addingTimeInterval(Double(radius)),
                step: session.searchRange.fineStepSeconds
            ) {
                if bounds.contains(date) {
                    unique[Int(date.timeIntervalSince1970.rounded())] = date
                }
            }
        }
        return try await candidates(for: unique.values.sorted(), session: session, config: config)
    }

    private func candidates(
        for dates: [Date],
        session: RectificationSession,
        config: RectificationConfig
    ) async throws -> [RectificationCandidate] {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: session.timezone) ?? .gmt
        var output: [RectificationCandidate] = []
        output.reserveCapacity(dates.count)
        for date in dates {
            try Task.checkCancellation()
            let comps = calendar.dateComponents([.year, .month, .day, .hour, .minute, .second], from: date)
            guard let year = comps.year, let month = comps.month, let day = comps.day,
                  let hour = comps.hour, let minute = comps.minute, let second = comps.second else { continue }
            let dateString = String(format: "%04d-%02d-%02d", year, month, day)
            let timeString = LocalTimeComponents(hour: hour, minute: minute, second: second)
                .formatted(includeSeconds: true)
            let jd = try julianDayFromLocal(
                birthDate: dateString,
                birthTime: timeString,
                timezoneName: session.timezone
            ).jd
            var chart = try AstroEngine.computeNatalChart(
                jd: jd,
                lat: session.latitude,
                lon: session.longitude,
                houseSystem: config.houseSystem.swissEphemerisCode
            )
            chart.name = session.name
            chart.birthDate = dateString
            chart.birthTime = timeString
            chart.timezone = session.timezone
            chart.placeName = session.placeName
            chart.houseSystem = config.houseSystem.rawValue
            output.append(RectificationCandidate(
                id: UUID(),
                birthTime: timeString,
                chart: chart,
                ascendantLongitude: chart.ascendant.longitude,
                mcLongitude: chart.mc.longitude,
                ascendantFormatted: chart.ascendant.formatted,
                mcFormatted: chart.mc.formatted,
                totalScore: 0,
                confidenceBand: .inconclusive,
                techniqueScores: [:],
                eventScores: [:],
                evidence: [],
                warnings: []
            ))
        }
        guard !output.isEmpty else { throw RectificationCandidateGeneratorError.noCandidates }
        return output.sorted { $0.birthTime < $1.birthTime }
    }

    private func strideDates(from start: Date, through end: Date, step: Int) -> [Date] {
        guard step > 0, end >= start else { return [] }
        var dates: [Date] = []
        var cursor = start
        while cursor <= end {
            dates.append(cursor)
            cursor = cursor.addingTimeInterval(Double(step))
        }
        return dates
    }

    private func allowedBounds(session: RectificationSession) throws -> ClosedRange<Date> {
        if session.searchRange.includeFullDayFallback {
            let start = try localDateFromBirthData(
                birthDate: session.birthDate,
                birthTime: "00:00:00",
                timezoneName: session.timezone
            )
            var calendar = Calendar(identifier: .gregorian)
            calendar.timeZone = TimeZone(identifier: session.timezone) ?? .gmt
            guard let nextDay = calendar.date(byAdding: .day, value: 1, to: start) else {
                throw RectificationCandidateGeneratorError.noCandidates
            }
            return start...nextDay.addingTimeInterval(-1)
        }
        let center = try localDateFromBirthData(
            birthDate: session.birthDate,
            birthTime: session.searchRange.centerTime,
            timezoneName: session.timezone
        )
        let lower = center.addingTimeInterval(-Double(session.searchRange.minutesBefore * 60))
        let upper = center.addingTimeInterval(Double(session.searchRange.minutesAfter * 60))
        return lower...upper
    }
}
