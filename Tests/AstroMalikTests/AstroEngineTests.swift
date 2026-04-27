import XCTest
@testable import AstroMalik

// MARK: - Sanity Check
// Carta de referencia: 1976-10-11 20:33 Europe/Madrid
// Resultado esperado: Saturno en Casa 4, ASC Géminis ~0°

final class AstroEngineTests: XCTestCase {

    override func setUp() {
        super.setUp()
        AstroEngine.configure(ephePath: nil)
    }

    func testJulianDayReference() throws {
        // 1976-10-11 20:33 Madrid → should be around JD 2443068
        let result = try julianDayFromLocal(
            birthDate: "1976-10-11",
            birthTime: "20:33",
            timezoneName: "Europe/Madrid"
        )
        // JD for 1976-10-11 ~19:33 UTC ≈ 2443063.3
        XCTAssertEqual(result.jd, 2443063.3, accuracy: 0.5, "Julian Day fuera de rango esperado")
        XCTAssertEqual(result.timezoneIANA, "Europe/Madrid")
    }

    func testNatalChartReference() throws {
        // Carta de referencia del CONTEXT.md
        let jdResult = try julianDayFromLocal(
            birthDate: "1976-10-11",
            birthTime: "20:33",
            timezoneName: "Europe/Madrid"
        )
        let chart = try AstroEngine.computeNatalChart(
            jd: jdResult.jd,
            lat: 40.4168,  // Madrid
            lon: -3.7038
        )

        // ASC debe ser Géminis (~0°), signIndex = 2
        let ascSignIdx = Int(chart.ascendant.longitude / 30)
        XCTAssertEqual(ascSignIdx, 2, "ASC debe ser Géminis (sign index 2), fue \(SIGN_LABELS[ascSignIdx])")

        // Saturno debe estar en Casa 4
        let saturno = chart.bodies.first { $0.key == "SATURNO" }
        XCTAssertNotNil(saturno, "Saturno no encontrado en la carta")
        XCTAssertEqual(saturno?.house, 4, "Saturno debe estar en Casa 4, está en Casa \(saturno?.house ?? -1)")

        print("✅ ASC: \(chart.ascendant.formatted)")
        print("✅ MC:  \(chart.mc.formatted)")
        for body in chart.bodies {
            let retro = body.retrograde ? " ℞" : ""
            print("  \(body.label)\(retro) → \(body.formatted) Casa \(body.house)")
        }
    }

    func testHousesEx2ReferenceMatchesNatalChartAngles() throws {
        let jdResult = try julianDayFromLocal(
            birthDate: "1976-10-11",
            birthTime: "20:33",
            timezoneName: "Europe/Madrid"
        )
        let houses = try AstroEngine.calcHouses(jd: jdResult.jd, lat: 40.4168, lon: -3.7038)
        let chart = try AstroEngine.computeNatalChart(
            jd: jdResult.jd,
            lat: 40.4168,
            lon: -3.7038
        )

        XCTAssertEqual(houses.asc, chart.ascendant.longitude, accuracy: 0.0001)
        XCTAssertEqual(houses.mc, chart.mc.longitude, accuracy: 0.0001)
        XCTAssertEqual(houses.cusps.count, 12)
    }

    func testNatalAspects() throws {
        let jdResult = try julianDayFromLocal(
            birthDate: "1976-10-11",
            birthTime: "20:33",
            timezoneName: "Europe/Madrid"
        )
        let chart = try AstroEngine.computeNatalChart(
            jd: jdResult.jd, lat: 40.4168, lon: -3.7038
        )
        let rawPlanets = Dictionary(uniqueKeysWithValues: chart.bodies.map { b in
            (b.key, AstroEngine.RawPlanet(
                key: b.key, label: b.label,
                deg: b.longitude, speed: b.retrograde ? -1 : 1, retro: b.retrograde
            ))
        })
        let aspects = AstroEngine.computeNatalAspects(planets: rawPlanets)
        XCTAssertFalse(aspects.isEmpty, "Debe haber aspectos natales")
        print("✅ Aspectos natales encontrados: \(aspects.count)")
        for a in aspects.prefix(5) {
            print("  \(a.labelA) \(a.aspLabel) \(a.labelB) (orbe \(a.orb)°)")
        }
    }

    func testNatalInterpretationsIncludeAscendant() throws {
        let jdResult = try julianDayFromLocal(
            birthDate: "1976-10-11",
            birthTime: "20:33",
            timezoneName: "Europe/Madrid"
        )
        let chart = try AstroEngine.computeNatalChart(
            jd: jdResult.jd, lat: 40.4168, lon: -3.7038
        )

        let testFile = URL(fileURLWithPath: #filePath)
        let repoRoot = testFile
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let corpusURL = repoRoot
            .appendingPathComponent("Sources/AstroMalik/Resources/corpus.db")
        let store = try CorpusStore(path: corpusURL.path)
        let interps = store.buildNatalInterpretations(chart: chart)

        XCTAssertTrue(
            interps.contains { $0.clave == "ASC_GEMINIS" },
            "Debe incluir Ascendente en Géminis desde el corpus"
        )
        XCTAssertTrue(
            interps.contains { $0.clave == "ASC_CASA_1" },
            "Debe incluir Ascendente en Casa 1 desde el corpus"
        )
        XCTAssertTrue(
            interps.contains { $0.clave.contains("_ASC_") },
            "Debe incluir aspectos al Ascendente cuando haya alguno con texto en corpus"
        )
    }

    func testSynastryCorpusCoverage() throws {
        let db = try referenceCorpusDB()
        let rows = try db.query("""
            SELECT clave, texto_largo
            FROM interpretaciones
            WHERE tipo = 'sinastria'
        """)

        XCTAssertEqual(rows.count, 420)
        var pairs: [String: Set<String>] = [:]
        for row in rows {
            guard let clave = row["clave"]?.string else {
                XCTFail("Fila de sinastría sin clave")
                continue
            }
            XCTAssertTrue(clave.hasPrefix("SYN_"))
            XCTAssertFalse((row["texto_largo"]?.string ?? "").trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)

            let parts = clave.split(separator: "_").map(String.init)
            XCTAssertEqual(parts.count, 4)
            guard parts.count == 4 else { continue }
            let pair = "\(parts[1])_\(parts[2])"
            pairs[pair, default: []].insert(parts[3])
            XCTAssertNotEqual(parts[1], parts[2])
        }

        XCTAssertEqual(pairs.count, 84)
        for aspects in pairs.values {
            XCTAssertEqual(aspects, Set(["CONJUNCION", "SEXTIL", "CUADRADO", "TRIGONO", "OPOSICION"]))
        }
    }

    func testSynastryEngineGeneratesBothDirectionsAndCorpusKeys() throws {
        let chartA = try referenceChart()
        var chartB = try referenceChart(
            birthDate: "1988-04-20",
            birthTime: "09:15",
            lat: 48.8566,
            lon: 2.3522
        )
        chartB.name = "Referencia B"

        let aspects = AstroEngine.computeSynastryAspects(chartA: chartA, chartB: chartB)
        XCTAssertFalse(aspects.isEmpty)
        XCTAssertTrue(aspects.contains { $0.direction == .aToB })
        XCTAssertTrue(aspects.contains { $0.direction == .bToA })
        XCTAssertTrue(aspects.allSatisfy { $0.corpusClave.hasPrefix("SYN_") })
        XCTAssertTrue(aspects.allSatisfy { $0.corpusClave == "SYN_\($0.sourcePlanetKey)_\($0.targetPlanetKey)_\($0.aspectKey)" })
    }

    func testSynastryLookupAndReadingAllowsMissingTexts() throws {
        let store = try referenceCorpusStore()
        let lookup = store.lookupSynastry(claves: [
            "SYN_JUPITER_LUNA_CONJUNCION",
            "SYN_SOL_SOL_CONJUNCION",
        ])
        XCTAssertNotNil(lookup["SYN_JUPITER_LUNA_CONJUNCION"])
        XCTAssertNil(lookup["SYN_SOL_SOL_CONJUNCION"])

        let chartA = try referenceChart()
        var chartB = try referenceChart(
            birthDate: "1988-04-20",
            birthTime: "09:15",
            lat: 48.8566,
            lon: 2.3522
        )
        chartB.name = "Referencia B"
        let reading = store.buildSynastryReading(chartA: chartA, chartB: chartB)
        XCTAssertFalse(reading.aspects.isEmpty)
        XCTAssertGreaterThanOrEqual(reading.aspects.count, reading.aspectsWithText.count)
    }

    func testSynastryNoteBuilderIncludesCoverageAndDirections() throws {
        var chartA = try referenceChart()
        chartA.name = "Persona A"
        var chartB = try referenceChart(
            birthDate: "1988-04-20",
            birthTime: "09:15",
            lat: 48.8566,
            lon: 2.3522
        )
        chartB.name = "Persona B"
        let aspect = SynastryAspect(
            direction: .aToB,
            sourcePlanetKey: "JUPITER",
            sourcePlanetLabel: "♃ Júpiter",
            targetPlanetKey: "LUNA",
            targetPlanetLabel: "☽ Luna",
            aspectKey: "CONJUNCION",
            aspectLabel: "☌ Conjunción",
            orb: 0.42,
            corpusClave: "SYN_JUPITER_LUNA_CONJUNCION",
            interpretation: Interpretation(
                clave: "SYN_JUPITER_LUNA_CONJUNCION",
                tipo: .sinastria,
                titulo: "",
                texto: "Texto de prueba.",
                fuente: "Test",
                orden: 0
            )
        )
        let reading = SynastryReading(chartA: chartA, chartB: chartB, aspects: [aspect])
        let markdown = SynastryNoteBuilder.markdown(reading: reading)

        XCTAssertTrue(markdown.contains("# Sinastría - Persona A y Persona B"))
        XCTAssertTrue(markdown.contains("Cobertura: 1 textos de 1 aspectos"))
        XCTAssertTrue(markdown.contains("Persona A sobre Persona B"))
        XCTAssertTrue(markdown.contains("Texto de prueba."))
    }

    func testJoplinClipperCreatesNotebookAndNotePayload() async throws {
        let client = MockJoplinHTTPClient(responses: [
            #"{"items":[],"has_more":false}"#,
            #"{"id":"folder-1","title":"AstroMalik"}"#,
            #"{"id":"note-1"}"#,
        ])
        let service = JoplinClipperService(
            settings: JoplinClipperSettings(
                host: "127.0.0.1",
                port: 41184,
                token: "secret",
                notebook: "AstroMalik"
            ),
            client: client
        )

        try await service.createNote(title: "Sinastría", body: "Contenido")

        XCTAssertEqual(client.requests.count, 3)
        XCTAssertEqual(client.requests[0].url?.path, "/folders")
        XCTAssertEqual(client.requests[1].url?.path, "/folders")
        XCTAssertEqual(client.requests[2].url?.path, "/notes")
        XCTAssertTrue(client.requests[2].url?.query?.contains("token=secret") == true)
        let body = try XCTUnwrap(client.requests[2].httpBody)
        let payload = try JSONSerialization.jsonObject(with: body) as? [String: Any]
        XCTAssertEqual(payload?["title"] as? String, "Sinastría")
        XCTAssertEqual(payload?["body"] as? String, "Contenido")
        XCTAssertEqual(payload?["parent_id"] as? String, "folder-1")
    }

    func testSolarReturnJDIsInsideYearAndMatchesNatalSun() throws {
        let natal = try referenceChart()
        let jd = try SolarReturnEngine.solarReturnJD(natalChart: natal, year: 2026)
        let start = sweJuldayForTest(year: 2026, month: 1, day: 1)
        let end = sweJuldayForTest(year: 2027, month: 1, day: 1)
        XCTAssertGreaterThan(jd, start)
        XCTAssertLessThan(jd, end)

        let solarChart = try AstroEngine.computeNatalChart(jd: jd, lat: 40.4168, lon: -3.7038)
        let natalSun = try XCTUnwrap(natal.bodies.first { $0.key == "SOL" })
        let solarSun = try XCTUnwrap(solarChart.bodies.first { $0.key == "SOL" })
        XCTAssertEqual(angularDiffForTest(natalSun.longitude, solarSun.longitude), 0, accuracy: 0.01)
    }

    func testSolarReturnLocationChangesAnglesButNotExactJD() throws {
        let natal = try referenceChart()
        let store = try referenceCorpusStore()
        let madrid = SolarReturnRequest(
            natalChart: natal,
            year: 2026,
            placeName: "Madrid",
            latitude: 40.4168,
            longitude: -3.7038,
            timezone: "Europe/Madrid"
        )
        let paris = SolarReturnRequest(
            natalChart: natal,
            year: 2026,
            placeName: "Paris",
            latitude: 48.8566,
            longitude: 2.3522,
            timezone: "Europe/Paris"
        )

        let madridReading = try SolarReturnEngine.calculate(request: madrid, corpusStore: store)
        let parisReading = try SolarReturnEngine.calculate(request: paris, corpusStore: store)

        XCTAssertEqual(madridReading.exactJD, parisReading.exactJD, accuracy: 0.000001)
        XCTAssertGreaterThan(
            angularDiffForTest(
                madridReading.solarChart.ascendant.longitude,
                parisReading.solarChart.ascendant.longitude
            ),
            1.0
        )
    }

    func testSolarReturnReadingIncludesNatalCorpusAndNatalHouses() throws {
        let natal = try referenceChart()
        let store = try referenceCorpusStore()
        let request = SolarReturnRequest(
            natalChart: natal,
            year: 2026,
            placeName: "Madrid",
            latitude: 40.4168,
            longitude: -3.7038,
            timezone: "Europe/Madrid"
        )

        let reading = try SolarReturnEngine.calculate(request: request, corpusStore: store)
        XCTAssertFalse(reading.interpretations.isEmpty)
        XCTAssertTrue(reading.interpretations.contains { $0.titulo.contains("de revolución") })
        XCTAssertTrue((1...12).contains(reading.natalHouseForSolarAsc))
        XCTAssertTrue((1...12).contains(reading.natalHouseForSolarMC))
        XCTAssertEqual(reading.solarPlanetsInNatalHouses.count, 10)
    }

    func testSolarReturnThrowsWhenNatalSunIsMissing() throws {
        var natal = try referenceChart()
        natal.bodies.removeAll { $0.key == "SOL" }
        XCTAssertThrowsError(try SolarReturnEngine.solarReturnJD(natalChart: natal, year: 2026)) { error in
            XCTAssertEqual(error as? SolarReturnError, .missingNatalSun)
        }
    }

    func testSolarReturnNoteBuilderIncludesAnnualData() throws {
        let natal = try referenceChart()
        let store = try referenceCorpusStore()
        let request = SolarReturnRequest(
            natalChart: natal,
            year: 2026,
            placeName: "Madrid",
            latitude: 40.4168,
            longitude: -3.7038,
            timezone: "Europe/Madrid"
        )
        let reading = try SolarReturnEngine.calculate(request: request, corpusStore: store)
        let markdown = SolarReturnNoteBuilder.markdown(reading: reading)

        XCTAssertTrue(markdown.contains("# Revolución Solar 2026"))
        XCTAssertTrue(markdown.contains("Retorno exacto"))
        XCTAssertTrue(markdown.contains("ASC revolución"))
        XCTAssertTrue(markdown.contains("Planetas de revolución en casas natales"))
        XCTAssertTrue(markdown.contains("Textos principales"))
    }

    func testJoplinClipperCreatesSolarReturnNotePayload() async throws {
        let client = MockJoplinHTTPClient(responses: [
            #"{"items":[{"id":"folder-1","title":"AstroMalik"}],"has_more":false}"#,
            #"{"id":"note-1"}"#,
        ])
        let service = JoplinClipperService(
            settings: JoplinClipperSettings(
                host: "127.0.0.1",
                port: 41184,
                token: "secret",
                notebook: "AstroMalik"
            ),
            client: client
        )

        try await service.createNote(title: "Revolución Solar 2026", body: "Informe anual")

        XCTAssertEqual(client.requests.count, 2)
        XCTAssertEqual(client.requests[1].url?.path, "/notes")
        let body = try XCTUnwrap(client.requests[1].httpBody)
        let payload = try JSONSerialization.jsonObject(with: body) as? [String: Any]
        XCTAssertEqual(payload?["title"] as? String, "Revolución Solar 2026")
        XCTAssertEqual(payload?["body"] as? String, "Informe anual")
        XCTAssertEqual(payload?["parent_id"] as? String, "folder-1")
    }

    func testLunarReturnSequenceIsOrderedAndAlignedWithNatalMoon() throws {
        let natal = try referenceChart()
        let request = LunarReturnRequest(
            natalChart: natal,
            startDate: utcDate(year: 2026, month: 4, day: 25),
            count: 24,
            placeName: "Madrid",
            latitude: 40.4168,
            longitude: -3.7038,
            timezone: "Europe/Madrid"
        )

        let reading = try LunarReturnEngine.calculate(request: request)
        XCTAssertEqual(reading.events.count, 24)

        guard let natalMoon = natal.bodies.first(where: { $0.key == "LUNA" }) else {
            return XCTFail("La carta de referencia debe contener Luna")
        }

        for pair in zip(reading.events, reading.events.dropFirst()) {
            XCTAssertLessThan(pair.0.exactJD, pair.1.exactJD)
        }
        for event in reading.events {
            XCTAssertEqual(angularDiffForTest(event.moon.longitude, natalMoon.longitude), 0, accuracy: 0.01)
            XCTAssertLessThan(event.moon.precisionArcseconds, 60)
        }

        let intervals = zip(reading.events, reading.events.dropFirst()).map { $1.exactJD - $0.exactJD }
        let average = intervals.reduce(0, +) / Double(intervals.count)
        XCTAssertEqual(average, 27.3, accuracy: 1.0)
    }

    func testLunarReturnLocationChangesAnglesButNotExactJD() throws {
        let natal = try referenceChart()
        let startDate = utcDate(year: 2026, month: 4, day: 25)
        let madrid = LunarReturnRequest(
            natalChart: natal,
            startDate: startDate,
            count: 3,
            placeName: "Madrid",
            latitude: 40.4168,
            longitude: -3.7038,
            timezone: "Europe/Madrid"
        )
        let paris = LunarReturnRequest(
            natalChart: natal,
            startDate: startDate,
            count: 3,
            placeName: "Paris",
            latitude: 48.8566,
            longitude: 2.3522,
            timezone: "Europe/Paris"
        )

        let madridReading = try LunarReturnEngine.calculate(request: madrid)
        let parisReading = try LunarReturnEngine.calculate(request: paris)
        XCTAssertEqual(madridReading.events.count, parisReading.events.count)
        XCTAssertEqual(madridReading.events[0].exactJD, parisReading.events[0].exactJD, accuracy: 0.000001)
        XCTAssertGreaterThan(
            angularDiffForTest(
                madridReading.events[0].returnChart.ascendant.longitude,
                parisReading.events[0].returnChart.ascendant.longitude
            ),
            1.0
        )
    }

    func testLunarReturnReadingContainsTechnicalMetrics() throws {
        let natal = try referenceChart()
        let request = LunarReturnRequest(
            natalChart: natal,
            startDate: utcDate(year: 2026, month: 4, day: 25),
            count: 6,
            placeName: "Madrid",
            latitude: 40.4168,
            longitude: -3.7038,
            timezone: "Europe/Madrid"
        )

        let reading = try LunarReturnEngine.calculate(request: request)
        let first = try XCTUnwrap(reading.events.first)
        XCTAssertEqual(reading.coverageSummary, "6 retornos tecnicos")
        XCTAssertTrue((1...12).contains(first.moon.house))
        XCTAssertTrue((1...12).contains(first.natalHouseForReturnAsc))
        XCTAssertTrue((1...12).contains(first.natalHouseForReturnMC))
        XCTAssertEqual(first.returnPlanetsInNatalHouses.count, 10)
        XCTAssertFalse(first.dominantAspects.isEmpty)
        XCTAssertGreaterThan(reading.statistics.maxSpeed, reading.statistics.minSpeed)
    }

    func testLunarReturnThrowsWhenNatalMoonIsMissing() throws {
        var natal = try referenceChart()
        natal.bodies.removeAll { $0.key == "LUNA" }
        let request = LunarReturnRequest(
            natalChart: natal,
            startDate: utcDate(year: 2026, month: 4, day: 25),
            count: 3,
            placeName: "Madrid",
            latitude: 40.4168,
            longitude: -3.7038,
            timezone: "Europe/Madrid"
        )

        XCTAssertThrowsError(try LunarReturnEngine.calculate(request: request)) { error in
            XCTAssertEqual(error as? LunarReturnError, .missingNatalMoon)
        }
    }

    func testLunarReturnNoteBuilderIncludesTechnicalSections() throws {
        let natal = try referenceChart()
        let request = LunarReturnRequest(
            natalChart: natal,
            startDate: utcDate(year: 2026, month: 4, day: 25),
            count: 3,
            placeName: "Madrid",
            latitude: 40.4168,
            longitude: -3.7038,
            timezone: "Europe/Madrid"
        )
        let reading = try LunarReturnEngine.calculate(request: request)
        let event = try XCTUnwrap(reading.events.first)
        let markdown = LunarReturnNoteBuilder.markdown(reading: reading, selectedEvent: event)

        XCTAssertTrue(markdown.contains("# Revolución Lunar"))
        XCTAssertTrue(markdown.contains("## Tabla de retornos"))
        XCTAssertTrue(markdown.contains("## Retorno seleccionado"))
        XCTAssertTrue(markdown.contains("## Aspectos dominantes"))
    }

    func testJoplinClipperCreatesLunarReturnNotePayload() async throws {
        let client = MockJoplinHTTPClient(responses: [
            #"{"items":[{"id":"folder-1","title":"AstroMalik"}],"has_more":false}"#,
            #"{"id":"note-1"}"#,
        ])
        let service = JoplinClipperService(
            settings: JoplinClipperSettings(
                host: "127.0.0.1",
                port: 41184,
                token: "secret",
                notebook: "AstroMalik"
            ),
            client: client
        )

        try await service.createNote(title: "Revolución Lunar", body: "Informe técnico lunar")

        XCTAssertEqual(client.requests.count, 2)
        XCTAssertEqual(client.requests[1].url?.path, "/notes")
        let body = try XCTUnwrap(client.requests[1].httpBody)
        let payload = try JSONSerialization.jsonObject(with: body) as? [String: Any]
        XCTAssertEqual(payload?["title"] as? String, "Revolución Lunar")
        XCTAssertEqual(payload?["body"] as? String, "Informe técnico lunar")
        XCTAssertEqual(payload?["parent_id"] as? String, "folder-1")
    }

    func testDegToSign() {
        XCTAssertTrue(AstroEngine.degToSign(0).contains("Aries"))
        XCTAssertTrue(AstroEngine.degToSign(30).contains("Tauro"))
        XCTAssertTrue(AstroEngine.degToSign(60).contains("Géminis"))
        XCTAssertTrue(AstroEngine.degToSign(359).contains("Piscis"))
        XCTAssertEqual(AstroEngine.degToSignKey(45), "TAURO")
    }

    func testScoreCalculation() {
        // Saturno conjunción Sol debe tener score alto (≥ 25 → 5 estrellas)
        // score = SATURNO(7) × CONJUNCION(5) × orb_factor(~1) = ~35
        // Con orb 0: factor = 1.0, score = 7*5*(0.5+0.5*1) = 35
        // Debería ser 5 estrellas
        let score = buildScoreForTest(transitKey: "SATURNO", aspectKey: "CONJUNCION", minOrb: 0.1)
        XCTAssertGreaterThanOrEqual(score, 25.0, "Saturno conjunción debe ser 5★")
    }

    func testTransitInvalidRangeThrows() async throws {
        let chart = try referenceChart()
        let store = try referenceCorpusStore()
        let from = Date(timeIntervalSince1970: 1_800_000)
        let to = Date(timeIntervalSince1970: 1_700_000)

        do {
            _ = try await computeTransitPeriod(
                natalChart: chart,
                fromDate: from,
                toDate: to,
                timezone: chart.timezone,
                corpusStore: store
            )
            XCTFail("Rango inverso debería lanzar error")
        } catch TransitError.invalidRange {
            // OK
        } catch {
            XCTFail("Error inesperado: \(error)")
        }
    }

    func testTransitCalculationCanBeCancelled() async throws {
        let chart = try referenceChart()
        let store = try referenceCorpusStore()
        let from = Date(timeIntervalSince1970: 0)
        let to = Date(timeIntervalSince1970: 60 * 60 * 24 * 3600)

        let task = Task {
            try await computeTransitPeriod(
                natalChart: chart,
                fromDate: from,
                toDate: to,
                timezone: chart.timezone,
                corpusStore: store
            )
        }
        task.cancel()

        do {
            _ = try await task.value
            XCTFail("El cálculo cancelado debería lanzar CancellationError")
        } catch is CancellationError {
            // OK
        }
    }

    func testTransitEventsIncludeTimelineSamplesInsideEventRange() async throws {
        let chart = try referenceChart()
        let store = try referenceCorpusStore()
        let events = try await computeTransitPeriod(
            natalChart: chart,
            fromDate: utcDate(year: 2026, month: 1, day: 1),
            toDate: utcDate(year: 2026, month: 6, day: 30),
            timezone: chart.timezone,
            corpusStore: store
        )

        XCTAssertFalse(events.isEmpty, "El rango de referencia debería producir tránsitos")
        for event in events {
            XCTAssertFalse(event.samples.isEmpty, "Cada tránsito debe incluir muestras para la timeline")
            guard let eventStart = isoDate(event.fromDate),
                  let eventEnd = isoDate(event.toDate) else {
                XCTFail("Fechas de evento inválidas: \(event.fromDate) → \(event.toDate)")
                continue
            }
            for sample in event.samples {
                guard let sampleDate = isoDate(sample.date) else {
                    XCTFail("Fecha de muestra inválida: \(sample.date)")
                    continue
                }
                XCTAssertGreaterThanOrEqual(sampleDate, eventStart)
                XCTAssertLessThanOrEqual(sampleDate, eventEnd)
                XCTAssertGreaterThanOrEqual(sample.intensity, 0)
                XCTAssertLessThanOrEqual(sample.intensity, 1)
            }
        }
    }

    func testTransitExactDateSampleMatchesMinimumOrbAndPeakIntensity() async throws {
        let chart = try referenceChart()
        let store = try referenceCorpusStore()
        let events = try await computeTransitPeriod(
            natalChart: chart,
            fromDate: utcDate(year: 2026, month: 1, day: 1),
            toDate: utcDate(year: 2026, month: 6, day: 30),
            timezone: chart.timezone,
            corpusStore: store
        )

        XCTAssertFalse(events.isEmpty, "El rango de referencia debería producir tránsitos")
        for event in events {
            guard let exactSample = event.samples.first(where: { $0.date == event.exactDate }) else {
                XCTFail("Debe existir una muestra en la fecha exacta \(event.exactDate)")
                continue
            }
            let maxIntensity = event.samples.map(\.intensity).max() ?? 0
            XCTAssertEqual(exactSample.orb, event.minOrb, accuracy: 0.01)
            XCTAssertEqual(exactSample.intensity, maxIntensity, accuracy: 0.001)
        }
    }

    func testTimezoneInferenceKnownCities() {
        let service = PlacesService()
        XCTAssertEqual(service.timezoneForCoordinates(lat: 40.4168, lon: -3.7038), "Europe/Madrid")
        XCTAssertEqual(service.timezoneForCoordinates(lat: 48.8566, lon: 2.3522), "Europe/Paris")
        XCTAssertEqual(service.timezoneForCoordinates(lat: 51.5072, lon: -0.1276), "Europe/London")
        XCTAssertEqual(service.timezoneForCoordinates(lat: 40.7128, lon: -74.0060), "America/New_York")
        XCTAssertEqual(service.timezoneForCoordinates(lat: 41.8781, lon: -87.6298), "America/Chicago")
        XCTAssertEqual(service.timezoneForCoordinates(lat: 39.7392, lon: -104.9903), "America/Denver")
        XCTAssertEqual(service.timezoneForCoordinates(lat: 34.0522, lon: -118.2437), "America/Los_Angeles")
    }

    func testHoraryDiagnosticsDoesNotThrow() async {
        let diagnostics = await HoraryEngine.diagnostics()
        XCTAssertFalse(diagnostics.checkedSources.isEmpty)
    }
}

private func referenceChart(
    birthDate: String = "1976-10-11",
    birthTime: String = "20:33",
    timezoneName: String = "Europe/Madrid",
    lat: Double = 40.4168,
    lon: Double = -3.7038
) throws -> NatalChart {
    let jdResult = try julianDayFromLocal(
        birthDate: birthDate,
        birthTime: birthTime,
        timezoneName: timezoneName
    )
    var chart = try AstroEngine.computeNatalChart(
        jd: jdResult.jd,
        lat: lat,
        lon: lon
    )
    chart.name = "Referencia"
    chart.birthDate = birthDate
    chart.birthTime = birthTime
    chart.timezone = timezoneName
    return chart
}

private func referenceCorpusStore() throws -> CorpusStore {
    try CorpusStore(path: referenceCorpusURL().path)
}

private func referenceCorpusDB() throws -> SQLiteDB {
    try SQLiteDB(path: referenceCorpusURL().path, readonly: true)
}

private func referenceCorpusURL() -> URL {
    let testFile = URL(fileURLWithPath: #filePath)
    let repoRoot = testFile
        .deletingLastPathComponent()
        .deletingLastPathComponent()
        .deletingLastPathComponent()
    return repoRoot
        .appendingPathComponent("Sources/AstroMalik/Resources/corpus.db")
}

private func utcDate(year: Int, month: Int, day: Int) -> Date {
    var cal = Calendar(identifier: .gregorian)
    cal.timeZone = TimeZone(secondsFromGMT: 0) ?? .gmt
    return cal.date(from: DateComponents(timeZone: cal.timeZone, year: year, month: month, day: day)) ?? Date()
}

private func sweJuldayForTest(year: Int, month: Int, day: Int) -> Double {
    utcDate(year: year, month: month, day: day).timeIntervalSince1970 / 86_400 + 2_440_587.5
}

private func angularDiffForTest(_ a: Double, _ b: Double) -> Double {
    var diff = abs((a - b + 360).truncatingRemainder(dividingBy: 360))
    if diff > 180 { diff = 360 - diff }
    return diff
}

private func isoDate(_ value: String) -> Date? {
    let parts = value.split(separator: "-").compactMap { Int($0) }
    guard parts.count == 3 else { return nil }
    return utcDate(year: parts[0], month: parts[1], day: parts[2])
}

// Helper para test de score
private func buildScoreForTest(transitKey: String, aspectKey: String, minOrb: Double) -> Double {
    let planetWeights: [String: Double] = [
        "PLUTON": 10, "NEPTUNO": 9, "URANO": 8, "SATURNO": 7, "JUPITER": 6,
        "MARTE": 4, "VENUS": 2, "MERCURIO": 2, "SOL": 2, "LUNA": 1,
    ]
    let aspectWeights: [String: Double] = [
        "CONJUNCION": 5, "OPOSICION": 4.5, "CUADRADO": 4, "TRIGONO": 3, "SEXTIL": 2,
    ]
    let aspectOrbs: [String: Double] = [
        "CONJUNCION": 8, "OPOSICION": 8, "CUADRADO": 7, "TRIGONO": 7, "SEXTIL": 5,
    ]
    let pw = planetWeights[transitKey] ?? 1
    let aw = aspectWeights[aspectKey] ?? 1
    let maxOrb = aspectOrbs[aspectKey] ?? 6
    let orbFactor = maxOrb > 0 ? max(0, 1 - minOrb / maxOrb) : 0.5
    return (pw * aw * (0.5 + 0.5 * orbFactor) * 10).rounded() / 10
}

private final class MockJoplinHTTPClient: JoplinHTTPClient {
    var requests: [URLRequest] = []
    private var responses: [Data]

    init(responses: [String]) {
        self.responses = responses.map { Data($0.utf8) }
    }

    func data(for request: URLRequest) async throws -> (Data, URLResponse) {
        requests.append(request)
        let data = responses.isEmpty ? Data("{}".utf8) : responses.removeFirst()
        let response = HTTPURLResponse(
            url: request.url ?? URL(string: "http://127.0.0.1")!,
            statusCode: 200,
            httpVersion: nil,
            headerFields: nil
        )!
        return (data, response)
    }
}
