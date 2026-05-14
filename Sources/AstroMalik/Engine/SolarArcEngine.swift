import Foundation
import CSwissEph

// MARK: - Solar Arc Engine

enum SolarArcMode: String, Codable, CaseIterable, Identifiable, Sendable {
    case real
    case naibod

    var id: String { rawValue }

    var label: String {
        switch self {
        case .real: return "Sol progresado real"
        case .naibod: return "Naibod"
        }
    }
}

final class SolarArcEngine: Sendable {
    static let naibodArcPerYear = 59.0 / 60.0 + 8.33 / 3600.0

    private let secondsPerYear = 365.25 * 24 * 3600.0

    func solarArc(
        chart: Chart,
        from ageStart: Double,
        to ageEnd: Double,
        mode: SolarArcMode = .real,
        orb: Double = 1.0
    ) -> [SolarArcDirection] {
        guard ageEnd >= ageStart,
              let birthContext = birthContext(for: chart) else { return [] }

        let start = max(0, ageStart)
        let end = max(start, ageEnd)
        let points = natalPoints(for: chart)
        guard points.count > 1 else { return [] }

        let startArc = solarArcAmount(natalJD: birthContext.jd, natalSun: birthContext.natalSun, age: start, mode: mode)
        var endArc = solarArcAmount(natalJD: birthContext.jd, natalSun: birthContext.natalSun, age: end, mode: mode)
        if endArc < startArc { endArc += 360 }

        var directions: [SolarArcDirection] = []
        for directed in points {
            for natal in points where natal.key != directed.key {
                for aspect in PDaspect.allCases {
                    for targetArc in exactArcTargets(
                        directedLongitude: directed.longitude,
                        natalLongitude: natal.longitude,
                        aspect: aspect
                    ) {
                        let unwrappedTarget = unwrap(targetArc, near: startArc, lowerBound: startArc)
                        guard unwrappedTarget >= startArc - orb,
                              unwrappedTarget <= endArc + orb else { continue }

                        let exactAge: Double
                        switch mode {
                        case .naibod:
                            exactAge = unwrappedTarget / Self.naibodArcPerYear
                        case .real:
                            guard let solved = solveRealAge(
                                natalJD: birthContext.jd,
                                natalSun: birthContext.natalSun,
                                targetArc: unwrappedTarget,
                                lowerAge: start,
                                upperAge: end
                            ) else { continue }
                            exactAge = solved
                        }

                        guard exactAge >= start - 0.0001,
                              exactAge <= end + 0.0001 else { continue }

                        let arc = solarArcAmount(natalJD: birthContext.jd, natalSun: birthContext.natalSun, age: exactAge, mode: mode)
                        let directedLongitude = normalizedDegree(directed.longitude + arc)
                        let date = birthContext.birthDate.addingTimeInterval(exactAge * secondsPerYear)
                        let weight = PrimaryDirectionCalculator().computeWeight(
                            promissor: directed.key,
                            significator: natal.key,
                            aspect: aspect
                        )

                        directions.append(SolarArcDirection(
                            directedPoint: directed.key,
                            directedPointLabel: directed.label,
                            directedNatalLongitude: normalizedDegree(directed.longitude),
                            directedLongitude: directedLongitude,
                            natalPoint: natal.key,
                            natalPointLabel: natal.label,
                            natalLongitude: normalizedDegree(natal.longitude),
                            aspect: aspect,
                            aspectAngle: aspect.angle,
                            solarArc: normalizedDegree(arc),
                            exactAge: max(0, exactAge),
                            exactDate: date,
                            orb: 0,
                            polarity: .applying,
                            mode: mode,
                            weight: weight
                        ))
                    }
                }
            }
        }

        return unique(directions).sorted {
            if abs($0.exactAge - $1.exactAge) > 0.0001 { return $0.exactAge < $1.exactAge }
            if $0.weight != $1.weight { return $0.weight > $1.weight }
            return $0.summaryKey < $1.summaryKey
        }
    }

    func solarArcAmount(chart: NatalChart, age: Double, mode: SolarArcMode = .real) -> Double? {
        guard let context = birthContext(for: chart) else { return nil }
        return solarArcAmount(natalJD: context.jd, natalSun: context.natalSun, age: age, mode: mode)
    }

    private func solarArcAmount(natalJD: Double, natalSun: Double, age: Double, mode: SolarArcMode) -> Double {
        switch mode {
        case .naibod:
            return normalizedDegree(age * Self.naibodArcPerYear)
        case .real:
            let progressedSun = sunLongitude(jd: natalJD + age) ?? natalSun
            return normalizedDegree(progressedSun - natalSun)
        }
    }

    private func solveRealAge(
        natalJD: Double,
        natalSun: Double,
        targetArc: Double,
        lowerAge: Double,
        upperAge: Double
    ) -> Double? {
        var low = lowerAge
        var high = upperAge
        func unwrappedArc(_ age: Double) -> Double {
            var arc = solarArcAmount(natalJD: natalJD, natalSun: natalSun, age: age, mode: .real)
            while arc < targetArc - 180 { arc += 360 }
            while arc > targetArc + 180 { arc -= 360 }
            return arc
        }

        let lowValue = unwrappedArc(low) - targetArc
        let highValue = unwrappedArc(high) - targetArc
        guard lowValue <= 0, highValue >= 0 else { return nil }

        for _ in 0..<48 {
            let mid = (low + high) / 2
            if unwrappedArc(mid) < targetArc {
                low = mid
            } else {
                high = mid
            }
        }
        return (low + high) / 2
    }

    private func birthContext(for chart: NatalChart) -> (jd: Double, birthDate: Date, natalSun: Double)? {
        guard let jdResult = try? julianDayFromLocal(
            birthDate: chart.birthDate,
            birthTime: chart.birthTime,
            timezoneName: chart.timezone
        ) else { return nil }

        let natalSun = chart.bodies.first { $0.key == "SOL" }?.longitude
            ?? (try? AstroEngine.calcPlanets(jd: jdResult.jd)["SOL"]?.deg) ?? nil
        guard let natalSun else { return nil }

        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: chart.timezone) ?? .current
        let dateParts = chart.birthDate.split(separator: "-").compactMap { Int($0) }
        let timeParts = chart.birthTime.split(separator: ":").compactMap { Int($0) }
        var comps = DateComponents()
        if dateParts.count == 3 {
            comps.year = dateParts[0]
            comps.month = dateParts[1]
            comps.day = dateParts[2]
        }
        if timeParts.count >= 2 {
            comps.hour = timeParts[0]
            comps.minute = timeParts[1]
        }
        guard let birthDate = calendar.date(from: comps) else { return nil }
        return (jdResult.jd, birthDate, normalizedDegree(natalSun))
    }

    private func natalPoints(for chart: NatalChart) -> [SolarArcPoint] {
        var points = chart.bodies.map {
            SolarArcPoint(key: $0.key, label: $0.label, longitude: normalizedDegree($0.longitude))
        }
        points.append(SolarArcPoint(key: "ASC", label: "ASC", longitude: normalizedDegree(chart.ascendant.longitude)))
        points.append(SolarArcPoint(key: "MC", label: "MC", longitude: normalizedDegree(chart.mc.longitude)))
        points.append(SolarArcPoint(key: "DSC", label: "DSC", longitude: normalizedDegree(chart.ascendant.longitude + 180)))
        points.append(SolarArcPoint(key: "IC", label: "IC", longitude: normalizedDegree(chart.mc.longitude + 180)))
        return points
    }

    private func exactArcTargets(directedLongitude: Double, natalLongitude: Double, aspect: PDaspect) -> [Double] {
        let base = natalLongitude - directedLongitude
        switch aspect {
        case .conjunction:
            return [normalizedDegree(base)]
        case .opposition:
            return [normalizedDegree(base + 180)]
        case .sextile, .square, .trine:
            return [normalizedDegree(base + aspect.angle), normalizedDegree(base - aspect.angle)]
        }
    }

    private func unwrap(_ arc: Double, near startArc: Double, lowerBound: Double) -> Double {
        var candidate = arc
        while candidate < lowerBound - 0.0001 { candidate += 360 }
        while candidate - startArc > 360 { candidate -= 360 }
        return candidate
    }

    private func sunLongitude(jd: Double) -> Double? {
        var xx = [Double](repeating: 0, count: 6)
        var serr = [CChar](repeating: 0, count: 256)
        let rc = swe_calc_ut(jd, SE_SUN, SEFLG_SPEED, &xx, &serr)
        guard rc >= 0 else { return nil }
        return normalizedDegree(xx[0])
    }

    private func unique(_ directions: [SolarArcDirection]) -> [SolarArcDirection] {
        var seen = Set<String>()
        var result: [SolarArcDirection] = []
        for direction in directions {
            let key = direction.summaryKey
            if seen.insert(key).inserted { result.append(direction) }
        }
        return result
    }

    private func normalizedDegree(_ degree: Double) -> Double {
        var d = degree.truncatingRemainder(dividingBy: 360)
        if d < 0 { d += 360 }
        return d
    }
}

private extension SolarArcDirection {
    var summaryKey: String {
        "\(directedPoint)|\(natalPoint)|\(aspect.rawValue)|\(String(format: "%.4f", exactAge))"
    }
}
