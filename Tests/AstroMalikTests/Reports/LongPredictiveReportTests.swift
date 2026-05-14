import XCTest
@testable import AstroMalik

extension Reports {
    func testLongPredictiveReportBuildersRenderFiveHTMLTemplates() async throws {
        let chart = Self.longPredictiveChart()
        let service = ReportService()
        let generated = Self.longDate("2026-05-14")
        let asOf = Self.longDate("2026-06-01")

        let primary = PrimaryDirectionsLongReportBuilder.build(
            chart: chart,
            settings: PrimaryDirectionsLongReportSettings(
                preset: .classical,
                method: .regiomontanus,
                key: .naibod,
                aspectPlane: .zodiacal,
                minimumWeight: .major,
                includeConverse: true
            ),
            directions: [Self.longPrimaryDirection(weight: .critical)],
            speculum: [Self.longSpeculumRow()],
            asOf: asOf,
            generatedAt: generated
        )
        let solar = SolarArcLongReportBuilder.build(
            chart: chart,
            mode: .naibod,
            targetDate: asOf,
            currentSolarArc: 48.27,
            directions: [Self.longSolarArcDirection()],
            generatedAt: generated
        )
        let progressions = ProgressionsLongReportBuilder.build(
            chart: chart,
            snapshot: Self.longProgressionSnapshot(chart: chart, target: asOf),
            yearlyAspects: [Self.longProgressedAspect(date: asOf)],
            highlightedChanges: [Self.longIngress(date: asOf)],
            generatedAt: generated
        )
        let firdariaTimeline = Self.longFirdariaTimeline()
        let firdaria = FirdariaLongReportBuilder.build(
            chart: chart,
            timeline: firdariaTimeline,
            currentMajor: firdariaTimeline.majorPeriods[0],
            currentMinor: Self.longMinorPeriod(parent: firdariaTimeline.majorPeriods[0]),
            upcomingChanges: [FirdariaMinorChange(id: "minor-change", date: Self.longDate("2026-08-01"), period: Self.longMinorPeriod(parent: firdariaTimeline.majorPeriods[0]))],
            generatedAt: generated
        )
        let zr = ZodiacalReleasingLongReportBuilder.build(
            chart: chart,
            timelines: [Self.longZRTimeline(lot: .spirit), Self.longZRTimeline(lot: .fortune)],
            asOf: asOf,
            generatedAt: generated
        )

        let rendered = try await [
            service.renderHTML(request: PrimaryDirectionsLongReportBuilder.request(data: primary)),
            service.renderHTML(request: SolarArcLongReportBuilder.request(data: solar)),
            service.renderHTML(request: ProgressionsLongReportBuilder.request(data: progressions)),
            service.renderHTML(request: FirdariaLongReportBuilder.request(data: firdaria)),
            service.renderHTML(request: ZodiacalReleasingLongReportBuilder.request(data: zr)),
        ]

        for html in rendered {
            XCTAssertTrue(html.contains("<!doctype html>"))
            XCTAssertTrue(html.contains("<main class=\"report-body\">"))
            XCTAssertTrue(html.contains("Carta Larga Predictiva"))
            XCTAssertTrue(html.contains("Tabla de contenidos"))
        }
    }

    func testLongPredictiveReportsContainRequiredProfessionalSections() async throws {
        let chart = Self.longPredictiveChart()
        let service = ReportService()
        let asOf = Self.longDate("2026-06-01")

        let primary = try await service.renderHTML(request: PrimaryDirectionsLongReportBuilder.request(data: PrimaryDirectionsLongReportBuilder.build(
            chart: chart,
            settings: PrimaryDirectionsLongReportSettings(preset: .classical, method: .regiomontanus, key: .naibod, aspectPlane: .zodiacal, minimumWeight: .major, includeConverse: true),
            directions: [Self.longPrimaryDirection(weight: .critical), Self.longPrimaryDirection(weight: .moderate, exact: Self.longDate("2030-01-01"))],
            speculum: [Self.longSpeculumRow()],
            asOf: asOf
        )))
        XCTAssertTrue(primary.contains("Presets aplicados"))
        XCTAssertTrue(primary.contains("Tabla de direcciones por peso"))
        XCTAssertTrue(primary.contains("Vista del año en curso"))
        XCTAssertTrue(primary.contains("Timeline semántico"))
        XCTAssertTrue(primary.contains("Espéculo Regiomontano"))

        let solar = try await service.renderHTML(request: SolarArcLongReportBuilder.request(data: SolarArcLongReportBuilder.build(
            chart: chart,
            mode: .real,
            targetDate: asOf,
            currentSolarArc: 49.12,
            directions: [Self.longSolarArcDirection()],
            generatedAt: asOf
        )))
        XCTAssertTrue(solar.contains("Modo y arco solar a la fecha"))
        XCTAssertTrue(solar.contains("Tabla de direcciones ±5 años por peso"))
        XCTAssertTrue(solar.contains("Detalle de exactas en ±1 año"))

        let progressions = try await service.renderHTML(request: ProgressionsLongReportBuilder.request(data: ProgressionsLongReportBuilder.build(
            chart: chart,
            snapshot: Self.longProgressionSnapshot(chart: chart, target: asOf),
            yearlyAspects: [Self.longProgressedAspect(date: asOf)],
            highlightedChanges: [Self.longIngress(date: asOf)],
            generatedAt: asOf
        )))
        XCTAssertTrue(progressions.contains("Snapshot progresado"))
        XCTAssertTrue(progressions.contains("Luna progresada por casa y signo"))
        XCTAssertTrue(progressions.contains("Aspectos prog→natal y prog→prog del año"))
        XCTAssertTrue(progressions.contains("Cambios destacados ±5 años"))
        XCTAssertTrue(progressions.contains("Narrativa técnica"))

        let firdariaTimeline = Self.longFirdariaTimeline()
        let firdaria = try await service.renderHTML(request: FirdariaLongReportBuilder.request(data: FirdariaLongReportBuilder.build(
            chart: chart,
            timeline: firdariaTimeline,
            currentMajor: firdariaTimeline.majorPeriods[0],
            currentMinor: Self.longMinorPeriod(parent: firdariaTimeline.majorPeriods[0]),
            upcomingChanges: [],
            generatedAt: asOf
        )))
        XCTAssertTrue(firdaria.contains("Secta"))
        XCTAssertTrue(firdaria.contains("Orden firdariano del usuario"))
        XCTAssertTrue(firdaria.contains("Timeline 75 años"))
        XCTAssertTrue(firdaria.contains("data-firdaria-ruler"))
        XCTAssertTrue(firdaria.contains("Narrativa por planeta del ciclo en curso"))

        let zr = try await service.renderHTML(request: ZodiacalReleasingLongReportBuilder.request(data: ZodiacalReleasingLongReportBuilder.build(
            chart: chart,
            timelines: [Self.longZRTimeline(lot: .spirit), Self.longZRTimeline(lot: .fortune)],
            asOf: asOf,
            generatedAt: asOf
        )))
        XCTAssertTrue(zr.contains("Espíritu y Fortuna calculados"))
        XCTAssertTrue(zr.contains("capítulo actual"))
        XCTAssertTrue(zr.contains("Próximos eventos (LB, peaks)"))
        XCTAssertTrue(zr.contains("Timeline SVG ZR (L1+L2)"))
        XCTAssertTrue(zr.contains("data-zr-level"))
        XCTAssertTrue(zr.contains("Todos los L1 históricos y futuros"))
    }
}

private extension Reports {
    static func longPredictiveChart() -> NatalChart {
        let values: [(String, Double, Int)] = [
            ("SOL", 80, 3), ("LUNA", 145, 5), ("MERCURIO", 72, 3), ("VENUS", 112, 4), ("MARTE", 210, 7),
            ("JUPITER", 250, 9), ("SATURNO", 315, 11), ("URANO", 35, 2), ("NEPTUNO", 355, 12), ("PLUTON", 285, 10),
        ]
        let labels = Dictionary(uniqueKeysWithValues: PLANET_LIST.map { ($0.key, $0.label) })
        let bodies = values.map { key, longitude, house in
            PlanetBody(key: key, label: labels[key] ?? key, longitude: longitude, formatted: AstroEngine.degToSign(longitude), house: house, retrograde: key == "SATURNO")
        }
        return NatalChart(
            name: "Carta Larga Predictiva",
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
            createdAt: longDate("1976-10-11")
        )
    }

    static func longPrimaryDirection(weight: PDWeight, exact: Date = longDate("2026-06-01")) -> EnrichedPrimaryDirection {
        let direction = PrimaryDirection(
            promissor: "MARTE",
            promissorLabel: "♂ Marte",
            significator: "ASC",
            significatorLabel: "ASC",
            aspect: .square,
            aspectAngle: 90,
            directionType: .direct,
            aspectPlane: .zodiacal,
            arc: 49.2,
            estimatedAge: 49.65,
            estimatedDate: exact,
            method: .regiomontanus,
            key: .naibod,
            technicalData: PDTechnicalData(promissorRA: 210.1, promissorDeclination: -12.3, significatorRA: 65.4, significatorDeclination: 22.1, significatorPole: 38.2, obliquity: 23.44, ramc: 335.0, geoLatitude: 40.42),
            weight: weight
        )
        return EnrichedPrimaryDirection(
            direction: direction,
            interpretation: PrimaryDirectionInterpretation(
                directionId: direction.id,
                clave: "MARTE_ASC_CUADRATURA",
                title: "Marte cuadratura ASC",
                structuralText: "Dirección clásica de corte, esfuerzo físico y redefinición del modo de aparecer.",
                source: "Corpus clásico fixture",
                sourceReference: "Regiomontanus / tradición ptolemaica",
                quality: 5,
                contextualText: nil
            )
        )
    }

    static func longSpeculumRow() -> SpeculumRow {
        SpeculumRow(key: "ASC", label: "Ascendente", longitude: 65, latitude: 0, rightAscension: 65.4, declination: 22.1, meridianDistance: 12.3, zenithDistance: 44.4, pole: 38.2, q: 8.1, w: 3.2)
    }

    static func longSolarArcDirection() -> SolarArcDirection {
        SolarArcDirection(
            directedPoint: "SOL",
            directedPointLabel: "☉ Sol",
            directedNatalLongitude: 80,
            directedLongitude: 128.27,
            natalPoint: "ASC",
            natalPointLabel: "ASC",
            natalLongitude: 65,
            aspect: .sextile,
            aspectAngle: 60,
            solarArc: 48.27,
            exactAge: 49.0,
            exactDate: longDate("2026-06-01"),
            orb: 0.12,
            polarity: .applying,
            mode: .naibod,
            weight: .major
        )
    }

    static func longProgressionSnapshot(chart: NatalChart, target: Date) -> ProgressionSnapshot {
        let moon = ProgressedBody(key: "LUNA", label: "☽ Luna", longitude: 145, formatted: AstroEngine.degToSign(145), declination: 11.2, house: 5, retrograde: false, speed: 13.1)
        let sun = ProgressedBody(key: "SOL", label: "☉ Sol", longitude: 128, formatted: AstroEngine.degToSign(128), declination: 18.2, house: 4, retrograde: false, speed: 0.98)
        return ProgressionSnapshot(
            chartID: chart.id,
            chartName: chart.name,
            calculatedAt: target,
            targetDate: target,
            natalJulianDay: 2_443_433.0,
            progressedJulianDay: 2_443_482.0,
            ageYears: 49.65,
            ascendantMode: .naibod,
            bodies: [sun, moon],
            ascendant: ProgressedAngle(key: "ASC", label: "Ascendente", longitude: 112, formatted: AstroEngine.degToSign(112), house: 1),
            mc: ProgressedAngle(key: "MC", label: "Medio Cielo", longitude: 20, formatted: AstroEngine.degToSign(20), house: 10),
            cusps: chart.cusps,
            lunarPhase: ProgressedLunarPhase(id: "phase", name: .gibbous, angle: 132, startsAt: target, dateLabel: "2026-06-01", nextBoundary: 135),
            nextLunarSignIngresses: [],
            nextLunarHouseIngresses: [],
            nextLunarPhaseTransitions: [],
            highlightedChanges: [longIngress(date: target)]
        )
    }

    static func longProgressedAspect(date: Date) -> ProgressedAspect {
        ProgressedAspect(id: "prog-moon-sun", kind: .progressedToNatal, date: date, exactDate: "2026-06-01", progressedKey: "LUNA", progressedLabel: "☽ Luna", targetKey: "SOL", targetLabel: "☉ Sol natal", aspectKey: "TRIGONO", aspectLabel: "△ Trígono", orb: 0.25, applying: true, priority: 8, progressedRetrograde: false)
    }

    static func longIngress(date: Date) -> ProgressedIngress {
        ProgressedIngress(id: "moon-house", kind: .lunarHouse, date: date, dateLabel: "2026-06-01", bodyKey: "LUNA", bodyLabel: "☽ Luna", fromValue: "Casa 4", toValue: "Casa 5", longitude: 145, description: "La Luna progresada cambia de escenario doméstico a creativo.", priority: 8)
    }

    static func longFirdariaTimeline() -> FirdariaTimeline {
        let birth = longDate("2000-01-01")
        let calendar = Calendar(identifier: .gregorian)
        let rulers: [(AstroPlanetKey, Int)] = [(.sol, 10), (.venus, 8), (.mercurio, 13), (.luna, 9), (.saturno, 11), (.jupiter, 12), (.marte, 7), (.nodoNorte, 3), (.nodoSur, 2)]
        var cursor = birth
        let periods = rulers.enumerated().map { index, item in
            let end = calendar.date(byAdding: .year, value: item.1, to: cursor)!
            defer { cursor = end }
            return FirdariaPeriod(id: "major-\(index)", kind: .major, ruler: item.0, cycleIndex: 0, sequenceIndex: index, startDate: cursor, endDate: end, nominalYears: Double(item.1))
        }
        return FirdariaTimeline(
            sect: SectInfo(isDiurnal: true, luminary: .sol, benefic: .jupiter, malefic: .saturno, contrarySectBenefic: .venus, contrarySectMalefic: .marte),
            birthDate: birth,
            cycleIndex: 0,
            cycleStartDate: birth,
            cycleEndDate: calendar.date(byAdding: .year, value: 75, to: birth)!,
            majorPeriods: periods
        )
    }

    static func longMinorPeriod(parent: FirdariaPeriod) -> FirdariaPeriod {
        let end = Calendar(identifier: .gregorian).date(byAdding: .year, value: 1, to: parent.startDate)!
        return FirdariaPeriod(id: "minor-sol", kind: .minor, ruler: .sol, cycleIndex: parent.cycleIndex, sequenceIndex: 0, startDate: parent.startDate, endDate: end, nominalYears: 1)
    }

    static func longZRTimeline(lot: ZRLot) -> ZRTimeline {
        let birth = longDate("2000-01-01")
        let calendar = Calendar(identifier: .gregorian)
        let l1End = calendar.date(byAdding: .year, value: 15, to: birth)!
        let l2Mid = calendar.date(byAdding: .month, value: 6, to: birth)!
        let peak = ZREvent(id: "peak-\(lot.rawValue)", kind: .peak, level: .l2, date: l2Mid, title: "Peak L2", detail: "Angularidad del subperíodo.", signIndex: 0, signKey: "ARIES", signLabel: "♈ Aries", parentSignIndex: 0)
        let lb = ZREvent(id: "lb-\(lot.rawValue)", kind: .loosingOfBond, level: .l2, date: calendar.date(byAdding: .month, value: 9, to: birth)!, title: "Loosing of the Bond", detail: "Salto de vínculo.", signIndex: 3, signKey: "CANCER", signLabel: "♋ Cáncer", parentSignIndex: 0)
        let l2a = ZRPeriod(id: "l2a-\(lot.rawValue)", level: .l2, sequenceIndex: 0, signIndex: 0, signKey: "ARIES", signLabel: "♈ Aries", startDate: birth, endDate: l2Mid, nominalUnits: 6, unitLabel: "meses", angularity: .angular, isPeak: true, events: [peak], children: [])
        let l2b = ZRPeriod(id: "l2b-\(lot.rawValue)", level: .l2, sequenceIndex: 1, signIndex: 3, signKey: "CANCER", signLabel: "♋ Cáncer", startDate: l2Mid, endDate: calendar.date(byAdding: .year, value: 1, to: birth)!, nominalUnits: 6, unitLabel: "meses", angularity: .angular, isPeak: false, events: [lb], children: [])
        let l1 = ZRPeriod(id: "l1-\(lot.rawValue)", level: .l1, sequenceIndex: 0, signIndex: 0, signKey: "ARIES", signLabel: "♈ Aries", startDate: birth, endDate: l1End, nominalUnits: 15, unitLabel: "años", angularity: nil, isPeak: false, events: [], children: [l2a, l2b])
        let lotPoint = HellenisticLotPoint(key: lot.rawValue, name: lot.label, longitude: 12, formatted: AstroEngine.degToSign(12), signIndex: 0, signKey: "ARIES", signLabel: "♈ Aries", sect: SectInfo(isDiurnal: true, luminary: .sol, benefic: .jupiter, malefic: .saturno, contrarySectBenefic: .venus, contrarySectMalefic: .marte))
        return ZRTimeline(lot: lot, lotPoint: lotPoint, sect: lotPoint.sect, birthDate: birth, generatedAt: longDate("2026-05-14"), depth: 2, periods: [l1], highlightedEvents: [peak, lb])
    }

    static func longDate(_ value: String) -> Date {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.date(from: value) ?? Date(timeIntervalSince1970: 0)
    }
}
