import XCTest
@testable import AstroMalik

final class LotsEngineTests: XCTestCase {
    override func setUp() {
        super.setUp()
        AstroEngine.configure(ephePath: nil)
    }

    func testReferenceChartComputesSevenLotsInSpecOrder() throws {
        let lots = try LotsEngine().lots(chart: extendedReferenceChart())
        XCTAssertEqual(lots.map(\.kind), [.fortune, .spirit, .eros, .necessity, .victory, .audacity, .nemesis])
        XCTAssertEqual(lots.count, 7)
    }

    func testReferenceNocturnalFortuneAndSpiritAreInExpectedSigns() throws {
        let lots = try LotsEngine().lots(chart: extendedReferenceChart())
        let fortune = try XCTUnwrap(lots.first { $0.kind == .fortune })
        let spirit = try XCTUnwrap(lots.first { $0.kind == .spirit })
        XCTAssertEqual(fortune.longitude, 201.465, accuracy: 0.02)
        XCTAssertEqual(fortune.signKey, "LIBRA")
        XCTAssertEqual(fortune.house, 6)
        XCTAssertEqual(fortune.rulerKey, "VENUS")
        XCTAssertEqual(spirit.signKey, "CAPRICORNIO")
        XCTAssertEqual(spirit.rulerKey, "SATURNO")
    }

    func testDayFormulaInvertsFortuneAndSpirit() throws {
        let chart = syntheticChart(bodies: [
            body("SOL", 20, house: 10),
            body("LUNA", 80, house: 2),
            body("MERCURIO", 100), body("VENUS", 130), body("MARTE", 160), body("JUPITER", 190), body("SATURNO", 220),
        ], asc: 10)
        let lots = try LotsEngine().lots(chart: chart)
        XCTAssertEqual(try XCTUnwrap(lots.first { $0.kind == .fortune }).longitude, 70, accuracy: 0.001)
        XCTAssertEqual(try XCTUnwrap(lots.first { $0.kind == .spirit }).longitude, 310, accuracy: 0.001)
    }
}

final class AlmutenFigurisEngineTests: XCTestCase {
    override func setUp() {
        super.setUp()
        AstroEngine.configure(ephePath: nil)
    }

    func testReferenceAlmutenFigurisExpectedManualWinner() throws {
        let result = try AlmutenFigurisEngine().almutenFiguris(chart: extendedReferenceChart())
        // Cálculo manual con las tablas implementadas: Mercurio 30, Venus 29,
        // Júpiter 28, Saturno 25, Luna 19, Marte 10, Sol 5.
        XCTAssertEqual(result.winnerKey, "MERCURIO")
        XCTAssertEqual(result.totalScores.first?.planetKey, "MERCURIO")
        XCTAssertEqual(result.totalScores.first?.total, 30)
    }

    func testReferenceUsesMostRecentPrenatalFullMoon() throws {
        let chart = try extendedReferenceChart()
        let natalJD = try julianDayFromLocal(birthDate: chart.birthDate, birthTime: chart.birthTime, timezoneName: chart.timezone).jd
        let syzygy = try AlmutenFigurisEngine().prenatalSyzygy(before: natalJD)
        XCTAssertEqual(syzygy.kind, .fullMoon)
        XCTAssertLessThan(syzygy.julianDay, natalJD)
        XCTAssertEqual(syzygy.longitude, 14.8, accuracy: 3.0)
    }

    func testAlmutenHasFiveScoredPointsAndBonuses() throws {
        let result = try AlmutenFigurisEngine().almutenFiguris(chart: extendedReferenceChart())
        XCTAssertEqual(result.pointScores.map(\.key), ["SOL", "LUNA", "ASC", "LOTE_FORTUNA", "SICIGIA_PRENATAL"])
        XCTAssertTrue(result.pointScores.allSatisfy { !$0.dignityAwards.isEmpty })
        XCTAssertTrue(result.bonuses.contains { $0.kind == "regente_dia" })
        XCTAssertTrue(result.bonuses.contains { $0.kind == "regente_hora" })
    }
}

final class AspectPatternEngineTests: XCTestCase {
    func testReferenceChartHasNoMajorAspectPatternAtSixDegrees() throws {
        let patterns = AspectPatternEngine().patterns(chart: try extendedReferenceChart())
        XCTAssertTrue(patterns.isEmpty)
    }

    func testSyntheticPatternsDetectTGrandTrineYodGrandCrossKiteAndRectangle() {
        let charts: [(Chart, AspectPatternKind)] = [
            (syntheticChart(bodies: [body("SOL", 0), body("LUNA", 180), body("MARTE", 90)]), .tSquare),
            (syntheticChart(bodies: [body("SOL", 0), body("LUNA", 120), body("MARTE", 240)]), .grandTrine),
            (syntheticChart(bodies: [body("SOL", 0), body("LUNA", 60), body("MARTE", 210)]), .yod),
            (syntheticChart(bodies: [body("SOL", 0), body("LUNA", 90), body("MARTE", 180), body("VENUS", 270)]), .grandCross),
            (syntheticChart(bodies: [body("SOL", 0), body("LUNA", 120), body("MARTE", 240), body("VENUS", 180)]), .kite),
            (syntheticChart(bodies: [body("SOL", 0), body("LUNA", 60), body("MARTE", 180), body("VENUS", 240)]), .mysticRectangle),
        ]
        for (chart, expectedKind) in charts {
            XCTAssertTrue(AspectPatternEngine().patterns(chart: chart).contains { $0.kind == expectedKind }, "Falta \(expectedKind)")
        }
    }

    func testAverageOrbIsComputedFromParticipatingAspects() {
        let chart = syntheticChart(bodies: [body("SOL", 1), body("LUNA", 181), body("MARTE", 91)])
        let pattern = AspectPatternEngine().patterns(chart: chart).first { $0.kind == .tSquare }
        XCTAssertNotNil(pattern)
        XCTAssertEqual(pattern?.averageOrb ?? -1, 0, accuracy: 0.001)
    }
}

final class DistributionEngineTests: XCTestCase {
    override func setUp() {
        super.setUp()
        AstroEngine.configure(ephePath: nil)
    }

    func testReferenceElementAndModalityCounts() throws {
        let distribution = DistributionEngine().distribution(chart: try extendedReferenceChart())
        XCTAssertEqual(counts(distribution.elements), ["Fuego": 2, "Tierra": 1, "Aire": 4, "Agua": 3])
        XCTAssertEqual(counts(distribution.modalities), ["Cardinal": 3, "Fijo": 5, "Mutable": 2])
    }

    func testReferenceHemispheresAndQuadrantsCountTenPlanets() throws {
        let distribution = DistributionEngine().distribution(chart: try extendedReferenceChart())
        XCTAssertEqual(counts(distribution.hemispheres), ["Norte": 3, "Sur": 7, "Este": 2, "Oeste": 8])
        XCTAssertEqual(distribution.quadrants.reduce(0) { $0 + $1.count }, 10)
    }

    func testReferenceSingletonIsMoonInEarth() throws {
        let singletons = DistributionEngine().distribution(chart: try extendedReferenceChart()).singletons
        XCTAssertTrue(singletons.contains { $0.category == .element && $0.bucketName == "Tierra" && $0.planetKey == "LUNA" })
    }
}

final class ReceptionEngineTests: XCTestCase {
    override func setUp() {
        super.setUp()
        AstroEngine.configure(ephePath: nil)
    }

    func testReferenceMixedReceptionSunSaturn() throws {
        let receptions = ReceptionEngine().receptions(chart: try extendedReferenceChart())
        XCTAssertTrue(receptions.contains { $0.kind == .mixed && Set([$0.planetAKey, $0.planetBKey]) == Set(["SOL", "SATURNO"]) })
    }

    func testSyntheticDomicileAndExaltationReceptions() {
        let domicileChart = syntheticChart(bodies: [body("VENUS", 10), body("MARTE", 40)])
        XCTAssertTrue(ReceptionEngine().receptions(chart: domicileChart).contains { $0.kind == .domicile })

        let exaltationChart = syntheticChart(bodies: [body("SOL", 40), body("LUNA", 10)])
        XCTAssertTrue(ReceptionEngine().receptions(chart: exaltationChart).contains { $0.kind == .exaltation })
    }
}

final class AntisciaEngineTests: XCTestCase {
    override func setUp() {
        super.setUp()
        AstroEngine.configure(ephePath: nil)
    }

    func testAntiscionAndContraAntiscionFormulas() {
        XCTAssertEqual(AntisciaEngine.antiscionLongitude(10), 170, accuracy: 0.0001)
        XCTAssertEqual(AntisciaEngine.contraAntiscionLongitude(10), 350, accuracy: 0.0001)
    }

    func testReferenceHasNoAntisciaContactsAtOneDegree() throws {
        XCTAssertTrue(AntisciaEngine().antiscia(chart: try extendedReferenceChart()).contacts.isEmpty)
    }

    func testSyntheticAntisciaContactsDetected() {
        let chart = syntheticChart(bodies: [body("SOL", 10), body("LUNA", 170), body("VENUS", 350)])
        let contacts = AntisciaEngine().antiscia(chart: chart).contacts
        XCTAssertTrue(contacts.contains { $0.kind == .antiscion && $0.sourcePlanetKey == "SOL" && $0.targetPlanetKey == "LUNA" })
        XCTAssertTrue(contacts.contains { $0.kind == .contraAntiscion && $0.sourcePlanetKey == "SOL" && $0.targetPlanetKey == "VENUS" })
    }
}

final class DeclinationEngineTests: XCTestCase {
    override func setUp() {
        super.setUp()
        AstroEngine.configure(ephePath: nil)
    }

    func testReferenceCalculatesTenPlanetsAndNodes() throws {
        let result = try DeclinationEngine().declinations(chart: extendedReferenceChart())
        XCTAssertEqual(result.bodies.count, 12)
        XCTAssertTrue(result.bodies.contains { $0.key == "NODO_NORTE" })
        XCTAssertTrue(result.bodies.contains { $0.key == "NODO_SUR" })
    }

    func testReferenceNodeAxisIsExactContraParallel() throws {
        let result = try DeclinationEngine().declinations(chart: extendedReferenceChart())
        XCTAssertTrue(result.pairs.contains { $0.kind == .contraParallel && Set([$0.bodyAKey, $0.bodyBKey]) == Set(["NODO_NORTE", "NODO_SUR"]) && $0.orb < 0.001 })
    }

    func testReferenceDeclinationOutOfBoundsListIsDeterministic() throws {
        let result = try DeclinationEngine().declinations(chart: extendedReferenceChart())
        XCTAssertEqual(result.outOfBounds.map(\.key), [])
        XCTAssertFalse(result.pairs.isEmpty)
    }
}

final class FixedStarsEngineTests: XCTestCase {
    override func setUp() {
        super.setUp()
        AstroEngine.configure(ephePath: nil)
    }

    func testCatalogContainsCoreTwentyOneStars() throws {
        let catalog = try FixedStarsEngine().catalog()
        XCTAssertEqual(catalog.count, 21)
        XCTAssertTrue(catalog.contains { $0.key == "ALDEBARAN" })
        XCTAssertTrue(catalog.contains { $0.key == "TOLIMAN" })
    }

    func testAldebaranPrecessionAt1976DiffersFromJ2000ByAboutFourTenths() throws {
        let result = try FixedStarsEngine().fixedStars(chart: extendedReferenceChart())
        let aldebaran = try XCTUnwrap(result.stars.first { $0.key == "ALDEBARAN" })
        XCTAssertEqual(result.precessionAppliedDegrees, -0.324, accuracy: 0.08)
        XCTAssertEqual(aldebaran.longitudeJ2000 - aldebaran.longitude, 0.324, accuracy: 0.08)
    }

    func testSyntheticFixedStarConjunctionToPlanetIsDetected() throws {
        var chart = try extendedReferenceChart()
        let precessedAldebaran = try XCTUnwrap(try FixedStarsEngine().fixedStars(chart: chart).stars.first { $0.key == "ALDEBARAN" })
        chart.bodies = chart.bodies.map { existing in
            existing.key == "SOL" ? body("SOL", precessedAldebaran.longitude, house: existing.house) : existing
        }
        let contacts = try FixedStarsEngine().fixedStars(chart: chart).contacts
        XCTAssertTrue(contacts.contains { $0.starKey == "ALDEBARAN" && $0.targetKey == "SOL" && $0.orb < 0.001 })
    }
}

final class NatalExtendedOrchestratorTests: XCTestCase {
    override func setUp() {
        super.setUp()
        AstroEngine.configure(ephePath: nil)
    }

    func testOrchestratorPopulatesEverySubsystem() throws {
        let result = try NatalExtendedAnalysis.compute(chart: extendedReferenceChart())
        XCTAssertEqual(result.lots.count, 7)
        XCTAssertEqual(result.almutenFiguris.winnerKey, "MERCURIO")
        XCTAssertEqual(result.rulerOfGeniture.rulerKey, "VENUS")
        XCTAssertEqual(result.fixedStars.stars.count, 21)
    }

    func testMarkdownExportContainsAllSections() throws {
        let chart = try extendedReferenceChart()
        let markdown = ExtendedAnalysisNoteBuilder.markdown(chart: chart, result: try NatalExtendedAnalysis.compute(chart: chart))
        for heading in [
            "## 1. Lotes helenísticos", "## 2. Almuten Figuris", "## 3. Regente de la Genitura",
            "## 4. Configuraciones aspectuales", "## 5. Conteos y distribución", "## 6. Recepciones mutuas natales",
            "## 7. Antiscia y contraantiscia", "## 8. Declinaciones y out of bounds", "## 9. Estrellas fijas",
        ] {
            XCTAssertTrue(markdown.contains(heading), "Falta \(heading)")
        }
    }
}

private func extendedReferenceChart() throws -> NatalChart {
    let jdResult = try julianDayFromLocal(
        birthDate: "1976-10-11",
        birthTime: "20:33",
        timezoneName: "Europe/Madrid"
    )
    var chart = try AstroEngine.computeNatalChart(jd: jdResult.jd, lat: 40.4168, lon: -3.7038)
    chart.name = "Referencia extendida"
    chart.birthDate = "1976-10-11"
    chart.birthTime = "20:33"
    chart.timezone = "Europe/Madrid"
    chart.placeName = "Madrid"
    return chart
}

private func syntheticChart(bodies: [PlanetBody], asc: Double = 0) -> NatalChart {
    NatalChart(
        name: "Sintética",
        birthDate: "1976-10-11",
        birthTime: "20:33",
        timezone: "Europe/Madrid",
        latitude: 40.4168,
        longitude: -3.7038,
        placeName: "Madrid",
        ascendant: AngularPoint(longitude: asc, formatted: AstroEngine.degToSign(asc)),
        mc: AngularPoint(longitude: 270, formatted: AstroEngine.degToSign(270)),
        cusps: [0, 30, 60, 90, 120, 150, 180, 210, 240, 270, 300, 330],
        bodies: bodies
    )
}

private func body(_ key: String, _ longitude: Double, house: Int? = nil) -> PlanetBody {
    PlanetBody(
        key: key,
        label: ExtendedAstro.planetLabel(for: key),
        longitude: ExtendedAstro.normalized(longitude),
        formatted: AstroEngine.degToSign(longitude),
        house: house ?? AstroEngine.planetHouse(deg: longitude, cusps: [0, 30, 60, 90, 120, 150, 180, 210, 240, 270, 300, 330]),
        retrograde: false
    )
}

private func counts(_ buckets: [DistributionBucket]) -> [String: Int] {
    Dictionary(uniqueKeysWithValues: buckets.map { ($0.name, $0.count) })
}
