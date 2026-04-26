import Foundation
import CSwissEph

enum SolarReturnError: LocalizedError, Equatable {
    case missingNatalSun
    case invalidYear(Int)
    case calculationFailed(String)
    case invalidReturnJD

    var errorDescription: String? {
        switch self {
        case .missingNatalSun:
            return "La carta natal no contiene Sol."
        case .invalidYear(let year):
            return "Año de revolución solar inválido: \(year)."
        case .calculationFailed(let message):
            return "No se pudo calcular la revolución solar: \(message)"
        case .invalidReturnJD:
            return "Swiss Ephemeris devolvió una fecha de retorno solar inválida."
        }
    }
}

enum SolarReturnEngine {
    static func calculate(
        request: SolarReturnRequest,
        corpusStore: CorpusStore
    ) throws -> SolarReturnReading {
        let natalChart = request.natalChart
        let exactJD = try solarReturnJD(natalChart: natalChart, year: request.year)
        var solarChart = try AstroEngine.computeNatalChart(
            jd: exactJD,
            lat: request.latitude,
            lon: request.longitude
        )
        let localDateTime = formatJD(exactJD, timezoneName: request.timezone)
        let utcDateTime = formatJD(exactJD, timezoneName: "UTC")
        let datePart = String(localDateTime.prefix(10))
        let timePart = String(localDateTime.dropFirst(11).prefix(5))
        solarChart = NatalChart(
            id: UUID(),
            name: "Revolución Solar \(request.year) — \(displayName(natalChart))",
            birthDate: datePart,
            birthTime: timePart,
            timezone: request.timezone,
            latitude: request.latitude,
            longitude: request.longitude,
            placeName: request.placeName,
            houseSystem: "Placidus",
            ascendant: solarChart.ascendant,
            mc: solarChart.mc,
            cusps: solarChart.cusps,
            bodies: solarChart.bodies
        )

        let interpretations = corpusStore.buildSolarReturnInterpretations(chart: solarChart)
        let dominantAspects = Array(solarAspects(chart: solarChart).prefix(10))
        let placements = solarChart.bodies.map { body in
            SolarReturnNatalHousePlacement(
                planetKey: body.key,
                planetLabel: body.label,
                natalHouse: AstroEngine.planetHouse(deg: body.longitude, cusps: natalChart.cusps),
                solarHouse: body.house,
                formatted: body.formatted
            )
        }

        // MARK: - Guided Reading Analysis
        let natalHouseForSolarAsc = AstroEngine.planetHouse(
            deg: solarChart.ascendant.longitude,
            cusps: natalChart.cusps
        )
        let natalHouseForSolarMC = AstroEngine.planetHouse(
            deg: solarChart.mc.longitude,
            cusps: natalChart.cusps
        )

        let ascSignKey = AstroEngine.degToSignKey(solarChart.ascendant.longitude)
        let ascSignIndex = Int(solarChart.ascendant.longitude.truncatingRemainder(dividingBy: 360) / 30)
        let ascSignLabel = SIGN_LABELS[max(0, min(11, ascSignIndex))]

        let rulerKey = RevolutionTemplates.classicalRuler(signKey: ascSignKey)
        let rulerBody = solarChart.bodies.first(where: { $0.key == rulerKey })
        let rulerLabel = rulerBody?.label ?? rulerKey
        let rulerNatalHouse = rulerBody.map {
            AstroEngine.planetHouse(deg: $0.longitude, cusps: natalChart.cusps)
        } ?? 1

        let solarMoon = solarChart.bodies.first(where: { $0.key == "LUNA" })
        let moonHouse = solarMoon?.house ?? 1
        let moonFormatted = solarMoon?.formatted ?? "—"

        // Angular planets in RS (houses 1, 4, 7, 10)
        let angularHouses: Set<Int> = [1, 4, 7, 10]
        let angularPlanets = solarChart.bodies
            .filter { angularHouses.contains($0.house) }
            .map { body in
                SolarReturnAngularPlanet(
                    planetKey: body.key,
                    planetLabel: body.label,
                    solarHouse: body.house,
                    natalHouse: AstroEngine.planetHouse(deg: body.longitude, cusps: natalChart.cusps),
                    formatted: body.formatted
                )
            }

        // Natal repetitions: planet RS in same house as natal
        let natalRepetitions = solarChart.bodies.compactMap { solarBody -> SolarReturnRepetition? in
            guard let natalBody = natalChart.bodies.first(where: { $0.key == solarBody.key }) else {
                return nil
            }
            let solarInNatal = AstroEngine.planetHouse(
                deg: solarBody.longitude,
                cusps: natalChart.cusps
            )
            guard solarInNatal == natalBody.house else { return nil }
            return SolarReturnRepetition(
                planetKey: solarBody.key,
                planetLabel: solarBody.label,
                house: solarInNatal,
                formatted: solarBody.formatted
            )
        }

        return SolarReturnReading(
            natalChart: natalChart,
            solarChart: solarChart,
            year: request.year,
            exactJD: exactJD,
            exactLocalDateTime: localDateTime,
            exactUTCDateTime: utcDateTime,
            placeName: request.placeName,
            latitude: request.latitude,
            longitude: request.longitude,
            timezone: request.timezone,
            natalHouseForSolarAsc: natalHouseForSolarAsc,
            natalHouseForSolarMC: natalHouseForSolarMC,
            solarPlanetsInNatalHouses: placements,
            dominantAspects: dominantAspects,
            interpretations: interpretations,
            yearThemeTitle: RevolutionTemplates.yearThemeTitle(natalHouse: natalHouseForSolarAsc),
            yearThemeText: RevolutionTemplates.yearTheme(natalHouse: natalHouseForSolarAsc),
            yearToneText: RevolutionTemplates.yearTone(signKey: ascSignKey),
            ascSignKey: ascSignKey,
            ascSignLabel: ascSignLabel,
            rulerKey: rulerKey,
            rulerLabel: rulerLabel,
            rulerNatalHouse: rulerNatalHouse,
            rulerText: RevolutionTemplates.rulerInNatalHouse(rulerNatalHouse),
            moonHouse: moonHouse,
            moonFormatted: moonFormatted,
            moonText: RevolutionTemplates.solarMoonInHouse(moonHouse),
            angularPlanets: angularPlanets,
            natalRepetitions: natalRepetitions
        )
    }

    static func solarReturnJD(natalChart: NatalChart, year: Int) throws -> Double {
        guard (1800...2399).contains(year) else {
            throw SolarReturnError.invalidYear(year)
        }
        guard let natalSun = natalChart.bodies.first(where: { $0.key == "SOL" }) else {
            throw SolarReturnError.missingNatalSun
        }

        let startJD = swe_julday(Int32(year), 1, 1, 0, SE_GREG_CAL)
        var serr = [CChar](repeating: 0, count: 256)
        let jd = swe_solcross_ut(natalSun.longitude, startJD, SEFLG_SPEED, &serr)
        guard jd > startJD else {
            let message = String(cString: serr).trimmingCharacters(in: .whitespacesAndNewlines)
            if message.isEmpty {
                throw SolarReturnError.invalidReturnJD
            }
            throw SolarReturnError.calculationFailed(message)
        }
        let endJD = swe_julday(Int32(year + 1), 1, 1, 0, SE_GREG_CAL)
        guard jd < endJD else {
            throw SolarReturnError.invalidReturnJD
        }
        return jd
    }

    static func solarAspects(chart: NatalChart) -> [NatalAspect] {
        let rawPlanets = Dictionary(uniqueKeysWithValues: chart.bodies.map { body in
            (body.key, AstroEngine.RawPlanet(
                key: body.key,
                label: body.label,
                deg: body.longitude,
                speed: body.retrograde ? -1 : 1,
                retro: body.retrograde
            ))
        })
        return AstroEngine.computeNatalAspects(planets: rawPlanets)
    }

    private static func formatJD(_ jd: Double, timezoneName: String) -> String {
        let date = Date(timeIntervalSince1970: (jd - 2_440_587.5) * 86_400)
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.timeZone = TimeZone(identifier: timezoneName) ?? TimeZone(secondsFromGMT: 0)
        formatter.locale = Locale(identifier: "es_ES")
        formatter.dateFormat = "yyyy-MM-dd HH:mm"
        return formatter.string(from: date)
    }
}

private func displayName(_ chart: NatalChart) -> String {
    chart.name.isEmpty ? chart.birthDate : chart.name
}
