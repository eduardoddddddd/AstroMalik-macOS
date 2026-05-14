import XCTest
@testable import AstroMalik

final class Charts: XCTestCase {}

extension Charts {
    func testWheelSVGContainsTenPlanetGlyphsAndViewBox() throws {
        let svg = wheel(chart: Self.sampleChart(), theme: .default, size: 600)

        XCTAssertTrue(svg.contains("<svg"))
        XCTAssertTrue(svg.contains("viewBox=\"0 0 600 600\""))

        for (key, glyph) in [
            ("SOL", "sun"),
            ("LUNA", "moon"),
            ("MERCURIO", "mercury"),
            ("VENUS", "venus"),
            ("MARTE", "mars"),
            ("JUPITER", "jupiter"),
            ("SATURNO", "saturn"),
            ("URANO", "uranus"),
            ("NEPTUNO", "neptune"),
            ("PLUTON", "pluto"),
        ] {
            XCTAssertTrue(svg.contains("data-planet=\"\(key)\""), "Missing planet \(key)")
            XCTAssertTrue(svg.contains("data-glyph=\"\(glyph)\""), "Missing glyph \(glyph)")
        }
    }

    func testWheelAspectLinesOnlyGeneratedForNatalAspectsInOrb() throws {
        let withAspect = Self.sampleChart(longitudes: ["SOL": 0, "LUNA": 60])
        let withoutAspect = Self.sampleChart(longitudes: ["SOL": 0, "LUNA": 23])

        let svgWithAspect = wheel(chart: withAspect, theme: .default, size: 600)
        let svgWithoutAspect = wheel(chart: withoutAspect, theme: .default, size: 600)

        XCTAssertTrue(svgWithAspect.contains("data-aspect-line=\"natal\""))
        XCTAssertTrue(svgWithAspect.contains("data-corpus=\"SOL_LUNA_SEXTIL\""))
        XCTAssertFalse(svgWithoutAspect.contains("data-aspect-line=\"natal\""))
    }

    func testDoubleWheelHasTwoRingsAndInterChartAspectLines() throws {
        let natal = Self.sampleChart(longitudes: ["SOL": 0, "LUNA": 90])
        let secondary = Self.sampleChart(name: "Secundaria", longitudes: ["SOL": 60, "LUNA": 140])

        let svg = doubleWheel(natal: natal, secondary: secondary, theme: .default, size: 700)

        XCTAssertTrue(svg.contains("viewBox=\"0 0 700 700\""))
        XCTAssertTrue(svg.contains("data-ring=\"natal\""))
        XCTAssertTrue(svg.contains("data-ring=\"secondary\""))
        XCTAssertTrue(svg.contains("data-aspect-line=\"double\""))
    }

    func testTransitsTimelineRendersMonthlyTicksBandsAndPriorityBlocks() throws {
        let from = Self.date("2026-01-01")
        let to = Self.date("2026-04-01")
        let event = TransitEvent(
            transitKey: "SATURNO",
            transitLabel: "Saturno",
            natalKey: "SOL",
            natalLabel: "Sol",
            aspectKey: "CUADRADO",
            aspectLabel: "Cuadratura",
            color: "#8C3A2A",
            fromDate: "2026-01-15",
            toDate: "2026-02-20",
            exactDate: "2026-02-01",
            activeDays: 36,
            minOrb: 0.2,
            retrogradeOnExact: false,
            score: 8,
            stars: 4,
            priorityBand: .high
        )

        let svg = transitsTimeline(events: [event], from: from, to: to, theme: .default, width: 800, height: 400)

        XCTAssertTrue(svg.contains("data-transit-band=\"SATURNO\""))
        XCTAssertTrue(svg.contains("data-transit-event="))
        XCTAssertTrue(svg.contains("data-priority=\"high\""))
        XCTAssertTrue(svg.contains("ene 2026") || svg.contains("Jan 2026"))
    }

    func testZRTimelineRendersL1L2AndMarkers() throws {
        let timeline = Self.sampleZRTimeline()
        let svg = zrTimeline(timeline: timeline, depth: 2, theme: .default, width: 800, height: 300)

        XCTAssertTrue(svg.contains("data-zr-level=\"L1\""))
        XCTAssertTrue(svg.contains("data-zr-level=\"L2\""))
        XCTAssertTrue(svg.contains("data-zr-marker=\"loosing-of-bond\""))
        XCTAssertTrue(svg.contains("data-zr-marker=\"peak\""))
    }

    func testFirdariaTimelineRendersMajorPlanetBlocksOn75YearAxis() throws {
        let svg = firdariaTimeline(timeline: Self.sampleFirdariaTimeline(), theme: .default, width: 800, height: 120)

        XCTAssertTrue(svg.contains("Firdaria"))
        XCTAssertTrue(svg.contains("data-firdaria-ruler=\"SOL\""))
        XCTAssertTrue(svg.contains("+10"))
    }

    func testDailyEphemerisHTMLRendersTableSpeedsRetrogradesAndMoonPhase() throws {
        let month = EphemerisMonth(
            id: "2026-01",
            year: 2026,
            month: 1,
            events: [],
            dailyRows: [DailyEphemerisRow(
                date: "2026-01-01",
                positions: Self.dailyPositions(),
                lunarPhaseAngle: 180,
                lunarPhaseLabel: "Llena"
            )]
        )

        let html = dailyEphemeris(month: month, theme: .default)

        XCTAssertTrue(html.contains("<table"))
        XCTAssertTrue(html.contains("☊ Nodo Norte"))
        XCTAssertTrue(html.contains("<sup class=\"speed\">"))
        XCTAssertTrue(html.contains("class=\"retrograde\""))
        XCTAssertTrue(html.contains("🌕"))
    }
}

private extension Charts {
    static func sampleChart(name: String = "Determinista", longitudes: [String: Double]? = nil) -> NatalChart {
        let values = longitudes ?? [
            "SOL": 0,
            "LUNA": 60,
            "MERCURIO": 64,
            "VENUS": 120,
            "MARTE": 180,
            "JUPITER": 240,
            "SATURNO": 300,
            "URANO": 15,
            "NEPTUNO": 85,
            "PLUTON": 145,
        ]
        let labelByKey = Dictionary(uniqueKeysWithValues: PLANET_LIST.map { ($0.key, $0.label) })
        let bodies = values.sorted { lhs, rhs in
            let left = ChartSVGRenderingSupport.planetOrder.firstIndex(of: lhs.key) ?? 999
            let right = ChartSVGRenderingSupport.planetOrder.firstIndex(of: rhs.key) ?? 999
            return left < right
        }.map { key, longitude in
            PlanetBody(
                key: key,
                label: labelByKey[key] ?? key,
                longitude: longitude,
                formatted: AstroEngine.degToSign(longitude),
                house: max(1, min(12, Int(longitude / 30) + 1)),
                retrograde: key == "MERCURIO"
            )
        }
        return NatalChart(
            name: name,
            birthDate: "1976-10-11",
            birthTime: "20:33",
            timezone: "Europe/Madrid",
            latitude: 40.4168,
            longitude: -3.7038,
            placeName: "Madrid",
            houseSystem: "Placidus",
            ascendant: AngularPoint(longitude: 12, formatted: AstroEngine.degToSign(12)),
            mc: AngularPoint(longitude: 282, formatted: AstroEngine.degToSign(282)),
            cusps: stride(from: 0.0, to: 360.0, by: 30.0).map { $0 },
            bodies: bodies,
            createdAt: Self.date("1976-10-11")
        )
    }

    static func sampleZRTimeline() -> ZRTimeline {
        let birth = date("2000-01-01")
        let calendar = Calendar(identifier: .gregorian)
        let l2Start = birth
        let l2Mid = calendar.date(byAdding: .month, value: 6, to: l2Start)!
        let l2End = calendar.date(byAdding: .year, value: 1, to: l2Start)!
        let peak = ZREvent(
            id: "peak-1",
            kind: .peak,
            level: .l2,
            date: l2Mid,
            title: "Peak",
            detail: "Peak determinista",
            signIndex: 0,
            signKey: "ARIES",
            signLabel: "♈ Aries",
            parentSignIndex: 0
        )
        let lb = ZREvent(
            id: "lb-1",
            kind: .loosingOfBond,
            level: .l2,
            date: l2End,
            title: "LB",
            detail: "Loosing determinista",
            signIndex: 1,
            signKey: "TAURO",
            signLabel: "♉ Tauro",
            parentSignIndex: 0
        )
        let l2a = ZRPeriod(
            id: "l2-a",
            level: .l2,
            sequenceIndex: 0,
            signIndex: 0,
            signKey: "ARIES",
            signLabel: "♈ Aries",
            startDate: l2Start,
            endDate: l2Mid,
            nominalUnits: 6,
            unitLabel: "meses",
            angularity: .angular,
            isPeak: true,
            events: [peak],
            children: []
        )
        let l2b = ZRPeriod(
            id: "l2-b",
            level: .l2,
            sequenceIndex: 1,
            signIndex: 1,
            signKey: "TAURO",
            signLabel: "♉ Tauro",
            startDate: l2Mid,
            endDate: l2End,
            nominalUnits: 6,
            unitLabel: "meses",
            angularity: .succedent,
            isPeak: false,
            events: [lb],
            children: []
        )
        let l1 = ZRPeriod(
            id: "l1-a",
            level: .l1,
            sequenceIndex: 0,
            signIndex: 0,
            signKey: "ARIES",
            signLabel: "♈ Aries",
            startDate: birth,
            endDate: l2End,
            nominalUnits: 1,
            unitLabel: "años",
            angularity: .angular,
            isPeak: false,
            events: [],
            children: [l2a, l2b]
        )
        let sect = sampleSect()
        return ZRTimeline(
            lot: .fortune,
            lotPoint: HellenisticLotPoint(key: "fortune", name: "Fortuna", longitude: 0, formatted: "♈ Aries 00°00'", signIndex: 0, signKey: "ARIES", signLabel: "♈ Aries", sect: sect),
            sect: sect,
            birthDate: birth,
            generatedAt: birth,
            depth: 2,
            periods: [l1],
            highlightedEvents: [peak, lb]
        )
    }

    static func sampleFirdariaTimeline() -> FirdariaTimeline {
        let birth = date("2000-01-01")
        let calendar = Calendar(identifier: .gregorian)
        let solEnd = calendar.date(byAdding: .year, value: 10, to: birth)!
        let venusEnd = calendar.date(byAdding: .year, value: 18, to: birth)!
        return FirdariaTimeline(
            sect: sampleSect(),
            birthDate: birth,
            cycleIndex: 0,
            cycleStartDate: birth,
            cycleEndDate: calendar.date(byAdding: .year, value: 75, to: birth)!,
            majorPeriods: [
                FirdariaPeriod(id: "sol", kind: .major, ruler: .sol, cycleIndex: 0, sequenceIndex: 0, startDate: birth, endDate: solEnd, nominalYears: 10),
                FirdariaPeriod(id: "venus", kind: .major, ruler: .venus, cycleIndex: 0, sequenceIndex: 1, startDate: solEnd, endDate: venusEnd, nominalYears: 8),
            ]
        )
    }

    static func dailyPositions() -> [PlanetDailyPosition] {
        let keys = ["SOL", "LUNA", "MERCURIO", "VENUS", "MARTE", "JUPITER", "SATURNO", "URANO", "NEPTUNO", "PLUTON", "NODO_NORTE"]
        return keys.enumerated().map { index, key in
            let longitude = Double(index * 27)
            return PlanetDailyPosition(
                planetKey: key,
                longitude: longitude,
                formatted: AstroEngine.degToSign(longitude),
                speed: key == "MERCURIO" ? -0.42 : 1.23,
                retrograde: key == "MERCURIO",
                signKey: SIGN_KEYS[SVGChartSupport.signIndex(for: longitude)]
            )
        }
    }

    static func sampleSect() -> SectInfo {
        SectInfo(isDiurnal: true, luminary: .sol, benefic: .jupiter, malefic: .saturno, contrarySectBenefic: .venus, contrarySectMalefic: .marte)
    }

    static func date(_ iso: String) -> Date {
        let formatter = SVGChartSupport.isoDayFormatter()
        return formatter.date(from: iso)!
    }
}
