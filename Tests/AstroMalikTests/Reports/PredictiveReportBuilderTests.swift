import XCTest
@testable import AstroMalik

extension Reports {
    func testPredictiveReportBuildersRenderSixHTMLTemplates() async throws {
        let chart = Self.predictiveSampleChart()
        let event = Self.predictiveTransit(priority: .critical)
        let ingress = TransitHouseIngress(
            transitKey: "JUPITER",
            transitLabel: "♃ Júpiter",
            house: 10,
            date: "2026-06-10",
            fromHouse: 9,
            score: 7.5,
            stars: 4,
            text: "Apertura pública y profesional."
        )
        let month = Self.predictiveMonth(event: Self.predictiveCelestialEvent(kind: .newMoon, title: "Luna Nueva"))
        let service = ReportService()

        let requests: [(String, () async throws -> String)] = [
            ("transits", {
                try await service.renderHTML(request: TransitsReportBuilder.makeRequest(
                    chart: chart,
                    events: [event],
                    houseIngresses: [ingress],
                    from: Self.predictiveDate("2026-06-01"),
                    to: Self.predictiveDate("2026-06-30"),
                    generatedAt: Self.predictiveDate("2026-05-14")
                ))
            }),
            ("solar_return", {
                try await service.renderHTML(request: SolarReturnReportBuilder.makeRequest(
                    reading: Self.predictiveSolarReturn(chart: chart),
                    generatedAt: Self.predictiveDate("2026-05-14")
                ))
            }),
            ("lunar_return", {
                try await service.renderHTML(request: LunarReturnReportBuilder.makeRequest(
                    reading: Self.predictiveLunarReturn(chart: chart),
                    generatedAt: Self.predictiveDate("2026-05-14")
                ))
            }),
            ("calendar", {
                try await service.renderHTML(request: CalendarReportBuilder.makeRequest(
                    month: month,
                    chartForCover: chart,
                    generatedAt: Self.predictiveDate("2026-05-14")
                ))
            }),
            ("monthly_summary", {
                try await service.renderHTML(request: MonthlySummaryReportBuilder.makeRequest(
                    summary: Self.predictiveMonthlySummary(chart: chart, event: event),
                    natalChart: chart,
                    generatedAt: Self.predictiveDate("2026-05-14")
                ))
            }),
            ("profections", {
                try await service.renderHTML(request: ProfectionsReportBuilder.makeRequest(
                    result: Self.predictiveProfections(chart: chart, activation: event),
                    natalChart: chart,
                    generatedAt: Self.predictiveDate("2026-05-14")
                ))
            }),
        ]

        for (name, render) in requests {
            let html = try await render()
            XCTAssertTrue(html.contains("<!doctype html>"), name)
            XCTAssertTrue(html.contains("<main class=\"report-body\">"), name)
            XCTAssertTrue(html.contains("Carta Predictiva"), name)
            XCTAssertTrue(html.contains("Tabla de contenidos"), name)
        }
    }

    func testTransitsReportContainsPriorityTimelineCorpusAndHouseIngresses() async throws {
        let chart = Self.predictiveSampleChart()
        let request = TransitsReportBuilder.makeRequest(
            chart: chart,
            events: [Self.predictiveTransit(priority: .critical), Self.predictiveTransit(priority: .medium, exact: "2026-06-18")],
            houseIngresses: [TransitHouseIngress(transitKey: "SATURNO", transitLabel: "♄ Saturno", house: 4, date: "2026-06-21", fromHouse: 3, score: 6, stars: 3)],
            from: Self.predictiveDate("2026-06-01"),
            to: Self.predictiveDate("2026-06-30")
        )
        let html = try await ReportService().renderHTML(request: request)

        XCTAssertTrue(html.contains("Resumen del período"))
        XCTAssertTrue(html.contains("Timeline SVG"))
        XCTAssertTrue(html.contains("data-transit-event="))
        XCTAssertTrue(html.contains("Eventos por banda de prioridad"))
        XCTAssertTrue(html.contains("Texto corpus por evento priorizado"))
        XCTAssertTrue(html.contains("Ingresos por casa"))
        XCTAssertTrue(html.contains("Orbe exacto menor de 0.5°"))
    }

    func testSolarLunarCalendarMonthlyAndProfectionsContainRequiredSections() async throws {
        let chart = Self.predictiveSampleChart()
        let service = ReportService()

        let solar = try await service.renderHTML(request: SolarReturnReportBuilder.makeRequest(reading: Self.predictiveSolarReturn(chart: chart)))
        XCTAssertTrue(solar.contains("Carta de revolución solar"))
        XCTAssertTrue(solar.contains("ASC y MC en casas natales"))
        XCTAssertTrue(solar.contains("Planetas natales en casas RS"))
        XCTAssertTrue(solar.contains("Lectura guiada del año"))

        let lunar = try await service.renderHTML(request: LunarReturnReportBuilder.makeRequest(reading: Self.predictiveLunarReturn(chart: chart)))
        XCTAssertTrue(lunar.contains("Carta del retorno"))
        XCTAssertTrue(lunar.contains("Casas activadas"))
        XCTAssertTrue(lunar.contains("Métricas técnicas"))
        XCTAssertTrue(lunar.contains("Intensidad diaria"))

        let calendar = try await service.renderHTML(request: CalendarReportBuilder.makeRequest(month: Self.predictiveMonth(event: Self.predictiveCelestialEvent(kind: .solarEclipse, title: "Eclipse solar")), chartForCover: chart))
        XCTAssertTrue(calendar.contains("Lunaciones"))
        XCTAssertTrue(calendar.contains("Eclipses"))
        XCTAssertTrue(calendar.contains("Luna vacía de curso"))
        XCTAssertTrue(calendar.contains("Tabla diaria de efemérides"))

        let monthly = try await service.renderHTML(request: MonthlySummaryReportBuilder.makeRequest(summary: Self.predictiveMonthlySummary(chart: chart, event: Self.predictiveTransit(priority: .high)), natalChart: chart))
        XCTAssertTrue(monthly.contains("Lunaciones y eclipses en casas natales"))
        XCTAssertTrue(monthly.contains("Activaciones de planetas natales"))
        XCTAssertTrue(monthly.contains("Tránsitos principales"))
        XCTAssertTrue(monthly.contains("Ingresos por casa"))

        let profections = try await service.renderHTML(request: ProfectionsReportBuilder.makeRequest(result: Self.predictiveProfections(chart: chart, activation: Self.predictiveTransit(priority: .high)), natalChart: chart))
        XCTAssertTrue(profections.contains("Casa profeccionada del año"))
        XCTAssertTrue(profections.contains("Lord of the Year"))
        XCTAssertTrue(profections.contains("Aspectos natales del LotY"))
        XCTAssertTrue(profections.contains("Activaciones del año"))
    }

    func testPredictiveReportSmokeRendersSixPDFMagicBytes() async throws {
        let chart = Self.predictiveSampleChart()
        let transit = Self.predictiveTransit(priority: .critical)
        let service = ReportService()
        let outputDirectory = FileManager.default.temporaryDirectory.appendingPathComponent("AstroMalik-10D-Smoke", isDirectory: true)
        try? FileManager.default.removeItem(at: outputDirectory)
        try FileManager.default.createDirectory(at: outputDirectory, withIntermediateDirectories: true)

        let pdfs: [(String, Data)] = [
            ("transits", try await service.generate(request: TransitsReportBuilder.makeRequest(chart: chart, events: [transit], houseIngresses: [], from: Self.predictiveDate("2026-06-01"), to: Self.predictiveDate("2026-06-30")))),
            ("solar_return", try await service.generate(request: SolarReturnReportBuilder.makeRequest(reading: Self.predictiveSolarReturn(chart: chart)))),
            ("lunar_return", try await service.generate(request: LunarReturnReportBuilder.makeRequest(reading: Self.predictiveLunarReturn(chart: chart)))),
            ("calendar", try await service.generate(request: CalendarReportBuilder.makeRequest(month: Self.predictiveMonth(event: Self.predictiveCelestialEvent(kind: .fullMoon, title: "Luna Llena")), chartForCover: chart))),
            ("monthly_summary", try await service.generate(request: MonthlySummaryReportBuilder.makeRequest(summary: Self.predictiveMonthlySummary(chart: chart, event: transit), natalChart: chart))),
            ("profections", try await service.generate(request: ProfectionsReportBuilder.makeRequest(result: Self.predictiveProfections(chart: chart, activation: transit), natalChart: chart))),
        ]

        for (name, data) in pdfs {
            let url = outputDirectory.appendingPathComponent("\(name).pdf")
            try data.write(to: url, options: .atomic)
            XCTAssertEqual(String(decoding: data.prefix(5), as: UTF8.self), "%PDF-", name)
            XCTAssertGreaterThan(data.count, 1_000, name)
        }
    }
}

private extension Reports {
    static func predictiveSampleChart(name: String = "Carta Predictiva") -> NatalChart {
        let values: [(String, Double, Int)] = [
            ("SOL", 80, 3), ("LUNA", 145, 5), ("MERCURIO", 72, 3), ("VENUS", 112, 4), ("MARTE", 210, 7),
            ("JUPITER", 250, 9), ("SATURNO", 315, 11), ("URANO", 35, 2), ("NEPTUNO", 355, 12), ("PLUTON", 285, 10),
        ]
        let labels = Dictionary(uniqueKeysWithValues: PLANET_LIST.map { ($0.key, $0.label) })
        let bodies = values.map { key, longitude, house in
            PlanetBody(key: key, label: labels[key] ?? key, longitude: longitude, formatted: AstroEngine.degToSign(longitude), house: house, retrograde: key == "SATURNO")
        }
        return NatalChart(
            name: name,
            birthDate: "1976-10-11",
            birthTime: "20:33",
            timezone: "Europe/Madrid",
            latitude: 40.4168,
            longitude: -3.7038,
            placeName: "Madrid, España",
            houseSystem: "Placidus",
            ascendant: AngularPoint(longitude: 65, formatted: AstroEngine.degToSign(65)),
            mc: AngularPoint(longitude: 335, formatted: AstroEngine.degToSign(335)),
            cusps: stride(from: 45.0, to: 405.0, by: 30.0).map { $0.truncatingRemainder(dividingBy: 360) },
            bodies: bodies,
            createdAt: predictiveDate("1976-10-11")
        )
    }

    static func predictiveTransit(priority: TransitPriorityBand, exact: String = "2026-06-12") -> TransitEvent {
        TransitEvent(
            transitKey: "SATURNO",
            transitLabel: "♄ Saturno",
            natalKey: "SOL",
            natalLabel: "☉ Sol",
            aspectKey: "CUADRADO",
            aspectLabel: "□ Cuadratura",
            color: "#8C3A2A",
            fromDate: "2026-06-01",
            toDate: "2026-06-24",
            exactDate: exact,
            activeDays: 23,
            minOrb: 0.32,
            retrogradeOnExact: false,
            score: 8.4,
            stars: 4,
            technicalScore: 8.8,
            personalRelevance: 1.6,
            temporalImpact: 1.5,
            priorityScore: priority == .critical ? 20 : 9,
            priorityBand: priority,
            metricReasons: ["Toca Sol/Luna", "Orbe exacto menor de 0.5°"],
            text: "Saturno tensiona el Sol natal: foco, límites, maduración y decisiones sostenibles.",
            source: "fixture",
            samples: [TransitIntensitySample(date: exact, orb: 0.32, intensity: 0.9)]
        )
    }

    static func predictiveSolarReturn(chart: NatalChart) -> SolarReturnReading {
        let solar = predictiveSampleChart(name: "RS 2026 — Carta Predictiva")
        return SolarReturnReading(
            natalChart: chart,
            solarChart: solar,
            year: 2026,
            exactJD: 2_461_000.5,
            exactLocalDateTime: "2026-10-11 08:40",
            exactUTCDateTime: "2026-10-11 06:40",
            placeName: "Madrid, España",
            latitude: 40.4168,
            longitude: -3.7038,
            timezone: "Europe/Madrid",
            natalHouseForSolarAsc: 1,
            natalHouseForSolarMC: 10,
            solarPlanetsInNatalHouses: solar.bodies.map { SolarReturnNatalHousePlacement(planetKey: $0.key, planetLabel: $0.label, natalHouse: $0.house, solarHouse: $0.house, formatted: $0.formatted) },
            dominantAspects: [NatalAspect(keyA: "SOL", labelA: "☉ Sol", keyB: "LUNA", labelB: "☽ Luna", aspLabel: "△ Trígono", aspKey: "TRIGONO", orb: 1.2, corpusClave: "SOL_LUNA_TRIGONO")],
            interpretations: [],
            yearThemeTitle: "Año de identidad y dirección",
            yearThemeText: "El ASC de revolución cae en casa natal 1 y abre un ciclo de presencia y definición personal.",
            yearToneText: "Géminis acelera contactos, aprendizaje y movilidad.",
            ascSignKey: "GEMINIS",
            ascSignLabel: "♊ Géminis",
            rulerKey: "MERCURIO",
            rulerLabel: "☿ Mercurio",
            rulerNatalHouse: 3,
            rulerText: "El regente en casa 3 enfatiza escritura, mensajes y acuerdos.",
            moonHouse: 5,
            moonFormatted: "♌ Leo 25°00'",
            moonText: "La Luna en casa 5 pide expresión creativa mensualizada.",
            angularPlanets: [SolarReturnAngularPlanet(planetKey: "SOL", planetLabel: "☉ Sol", solarHouse: 1, natalHouse: 1, formatted: "♊ Géminis 20°00'")],
            natalRepetitions: [SolarReturnRepetition(planetKey: "SOL", planetLabel: "☉ Sol", house: 3, formatted: "♊ Géminis 20°00'")]
        )
    }

    static func predictiveLunarReturn(chart: NatalChart) -> LunarReturnReading {
        let returnChart = predictiveSampleChart(name: "RL junio 2026 — Carta Predictiva")
        let event = LunarReturnEvent(
            index: 1,
            exactJD: 2_461_100.5,
            exactLocalDateTime: "2026-06-17 22:10",
            exactUTCDateTime: "2026-06-17 20:10",
            returnChart: returnChart,
            ageDays: 18_000,
            ageYears: 49.3,
            moon: LunarReturnMoonData(longitude: 145, latitude: 1.2, distance: 0.0025, speed: 13.2, formatted: "♌ Leo 25°00'", house: 5, precisionArcseconds: 12, signKey: "LEO"),
            natalHouseForReturnAsc: 2,
            natalHouseForReturnMC: 11,
            dominantAspects: [NatalAspect(keyA: "LUNA", labelA: "☽ Luna", keyB: "MARTE", labelB: "♂ Marte", aspLabel: "□ Cuadratura", aspKey: "CUADRADO", orb: 2.1, corpusClave: "LUNA_MARTE_CUADRADO")],
            returnPlanetsInNatalHouses: returnChart.bodies.map { LunarReturnNatalHousePlacement(planetKey: $0.key, planetLabel: $0.label, natalHouse: $0.house, returnHouse: $0.house, formatted: $0.formatted) },
            intensityScore: 8,
            intensityLabel: "Alta",
            ascSignKey: "CANCER",
            ascSignLabel: "♋ Cáncer",
            moonFocusText: "La casa 5 activa deseo, escena, creación y vínculo con hijos/proyectos.",
            ascToneText: "Cáncer vuelve el mes sensible a memoria, cuidado y pertenencia.",
            miniNarrative: "Mes lunar de exposición creativa con necesidad de dosificar intensidad emocional."
        )
        return LunarReturnReading(
            natalChart: chart,
            natalMoon: LunarReturnNatalMoon(longitude: 145, formatted: "♌ Leo 25°00'", house: 5),
            startDate: predictiveDate("2026-06-01"),
            count: 1,
            placeName: "Madrid, España",
            latitude: 40.4168,
            longitude: -3.7038,
            timezone: "Europe/Madrid",
            events: [event],
            statistics: LunarReturnStatistics(averageIntervalDays: 27.3, shortestIntervalDays: 27.1, longestIntervalDays: 27.5, mostFrequentMoonHouse: 5, meanPrecisionArcseconds: 12, minPrecisionArcseconds: 8, maxSpeed: 13.2, minSpeed: 12.5, maxDistance: 0.0027, minDistance: 0.0023, averageIntensity: 8)
        )
    }

    static func predictiveMonth(event: CelestialEvent) -> EphemerisMonth {
        let events = [
            event,
            predictiveCelestialEvent(kind: .voidOfCourse, title: "Luna vacía de curso"),
            predictiveCelestialEvent(kind: .mundaneAspect, title: "Venus trígono Júpiter"),
            predictiveCelestialEvent(kind: .signIngress, title: "Sol ingresa en Cáncer"),
        ]
        return EphemerisMonth(id: "2026-06", year: 2026, month: 6, events: events, dailyRows: [DailyEphemerisRow(date: "2026-06-01", positions: predictiveDailyPositions(), lunarPhaseAngle: 90, lunarPhaseLabel: "Creciente")])
    }

    static func predictiveCelestialEvent(kind: CelestialEventKind, title: String) -> CelestialEvent {
        CelestialEvent(
            kind: kind,
            dateUTC: "2026-06-01 12:00",
            dateLocal: "2026-06-01 14:00",
            longitude: 80,
            signKey: "GEMINIS",
            signLabel: "♊ Géminis",
            formatted: "♊ Géminis 20°00'",
            planetKeyA: "VENUS",
            planetLabelA: "♀ Venus",
            planetKeyB: "JUPITER",
            planetLabelB: "♃ Júpiter",
            aspectKey: "TRIGONO",
            aspectLabel: "△ Trígono",
            eclipseType: kind == .solarEclipse ? "Solar parcial" : nil,
            eclipseMagnitude: kind == .solarEclipse ? 0.72 : nil,
            stationSpeed: nil,
            voidEnds: nil,
            voidDurationMinutes: nil,
            lastAspectPlanet: nil,
            lastAspectType: nil,
            ingressDirection: nil,
            title: title,
            subtitle: "Evento determinista de prueba",
            importance: .major
        )
    }

    static func predictiveMonthlySummary(chart: NatalChart, event: TransitEvent) -> MonthlySummary {
        let lunation = predictiveCelestialEvent(kind: .newMoon, title: "Luna Nueva natalizada")
        let eclipse = predictiveCelestialEvent(kind: .solarEclipse, title: "Eclipse solar natalizado")
        let station = predictiveCelestialEvent(kind: .stationDirect, title: "Mercurio directo")
        return MonthlySummary(
            id: "2026-06-\(chart.id.uuidString)",
            year: 2026,
            month: 6,
            chartName: chart.name,
            lunationHits: [LunationNatalHit(event: lunation, natalHouse: 3, conjunctPlanet: PlanetConjunction(planetKey: "SOL", planetLabel: "☉ Sol", orb: 1.1), narrative: "Lunación sobre la comunicación natal.")],
            eclipseHits: [EclipseNatalHit(event: eclipse, natalHouse: 10, conjunctPlanets: [PlanetConjunction(planetKey: "MC", planetLabel: "MC", orb: 0.7)], isAngular: true, narrative: "Eclipse angular con visibilidad profesional.")],
            stationHits: [StationNatalHit(event: station, natalPlanetKey: "MERCURIO", natalPlanetLabel: "☿ Mercurio", natalHouse: 3, orb: 0.4, narrative: "La estación reactiva decisiones y documentos.")],
            activeTransits: [event],
            houseIngresses: [TransitHouseIngress(transitKey: "JUPITER", transitLabel: "♃ Júpiter", house: 10, date: "2026-06-10", fromHouse: 9, score: 7, stars: 4, text: "Ingreso orientado a reputación.")],
            climateSummary: "Junio cruza lunaciones comunicativas con un eclipse angular y tránsitos de maduración."
        )
    }

    static func predictiveProfections(chart: NatalChart, activation: TransitEvent) -> ProfectionResult {
        let start = predictiveDate("2026-10-11")
        let monthEnd = Calendar(identifier: .gregorian).date(byAdding: .month, value: 1, to: start)!
        let annual = ProfectionPeriod(
            id: "annual-49-2",
            kind: .annual,
            sequence: 49,
            age: 49,
            house: 2,
            signKey: "CANCER",
            signLabel: "♋ Cáncer",
            cuspLongitude: 90,
            cuspFormatted: "♋ Cáncer 00°00'",
            lordKey: "LUNA",
            lordLabel: "☽ Luna",
            startDate: start,
            endDate: Calendar(identifier: .gregorian).date(byAdding: .year, value: 1, to: start)!,
            natalPlanetsInHouse: [ProfectionPlanet(key: "LUNA", label: "☽ Luna", longitude: 145, formatted: "♌ Leo 25°00'", house: 2, retrograde: false)],
            natalAspectsByLord: [ProfectionNatalAspect(lotyKey: "LUNA", lotyLabel: "☽ Luna", planetKey: "SOL", planetLabel: "☉ Sol", aspectKey: "SEXTIL", aspectLabel: "⚹ Sextil", orb: 2.0)]
        )
        let monthly = ProfectionPeriod(id: "monthly-0", kind: .monthly, sequence: 0, age: 49, house: 2, signKey: "CANCER", signLabel: "♋ Cáncer", cuspLongitude: 90, cuspFormatted: "♋ Cáncer 00°00'", lordKey: "LUNA", lordLabel: "☽ Luna", startDate: start, endDate: monthEnd, natalPlanetsInHouse: [], natalAspectsByLord: [])
        let daily = ProfectionPeriod(id: "daily-0", kind: .daily, sequence: 0, age: 49, house: 2, signKey: "CANCER", signLabel: "♋ Cáncer", cuspLongitude: 90, cuspFormatted: "♋ Cáncer 00°00'", lordKey: "LUNA", lordLabel: "☽ Luna", startDate: start, endDate: Calendar(identifier: .gregorian).date(byAdding: .day, value: 7, to: start)!, natalPlanetsInHouse: [], natalAspectsByLord: [])
        return ProfectionResult(annual: annual, monthly: [monthly], daily: [daily], activations: [activation])
    }

    static func predictiveDailyPositions() -> [PlanetDailyPosition] {
        (PLANET_LIST + [(Int32(0), "☊ Nodo Norte", "NODO_NORTE")]).enumerated().map { index, item in
            let longitude = Double(index * 25)
            return PlanetDailyPosition(planetKey: item.key, longitude: longitude, formatted: AstroEngine.degToSign(longitude), speed: item.key == "MERCURIO" ? -0.2 : 1.0, retrograde: item.key == "MERCURIO", signKey: SIGN_KEYS[SVGChartSupport.signIndex(for: longitude)])
        }
    }

    static func predictiveDate(_ iso: String) -> Date {
        SVGChartSupport.isoDayFormatter().date(from: iso)!
    }
}
