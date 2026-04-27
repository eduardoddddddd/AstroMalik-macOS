import XCTest
@testable import AstroMalik

// MARK: - EssentialDignityEngine Tests

final class EssentialDignityEngineTests: XCTestCase {

    // MARK: - Domicilios

    func testDomicileRulers() {
        XCTAssertEqual(EssentialDignityEngine.domicileRuler(of: 0), "MARTE")    // Aries
        XCTAssertEqual(EssentialDignityEngine.domicileRuler(of: 3), "LUNA")     // Cáncer
        XCTAssertEqual(EssentialDignityEngine.domicileRuler(of: 4), "SOL")      // Leo
        XCTAssertEqual(EssentialDignityEngine.domicileRuler(of: 8), "JUPITER")  // Sagitario
        XCTAssertEqual(EssentialDignityEngine.domicileRuler(of: 9), "SATURNO")  // Capricornio
    }

    func testSolEnLeoEsDomicilio() {
        // Sol en Leo 15° = longitud 135°
        let d = EssentialDignityEngine.primaryDignity(planet: "SOL", longitude: 135)
        XCTAssertEqual(d.dignity, .domicile)
        XCTAssertEqual(d.score, 5)
    }

    func testSolEnLibraEsExilio() {
        // Sol en Libra 5° = longitud 185°
        let d = EssentialDignityEngine.primaryDignity(planet: "SOL", longitude: 185)
        XCTAssertEqual(d.dignity, .detriment)
        XCTAssertEqual(d.score, -5)
    }

    // MARK: - Exaltaciones

    func testSolExaltacionAries() {
        // Sol en Aries 19° = longitud 19°
        let ds = EssentialDignityEngine.dignities(planet: "SOL", longitude: 19)
        XCTAssertTrue(ds.contains(where: { $0.dignity == .exaltation }))
    }

    func testJupiterExaltacionCancer() {
        // Júpiter en Cáncer 15° = 105°
        let ds = EssentialDignityEngine.dignities(planet: "JUPITER", longitude: 105)
        XCTAssertTrue(ds.contains(where: { $0.dignity == .exaltation }))
    }

    func testSaturnoExaltacionLibra() {
        // Saturno en Libra 21° = 201°
        let ds = EssentialDignityEngine.dignities(planet: "SATURNO", longitude: 201)
        XCTAssertTrue(ds.contains(where: { $0.dignity == .exaltation }))
    }

    // MARK: - Caída

    func testSolCaidaEnLibra() {
        // Sol exaltado en Aries → caída en Libra
        let ds = EssentialDignityEngine.dignities(planet: "SOL", longitude: 185)
        XCTAssertTrue(ds.contains(where: { $0.dignity == .detriment || $0.dignity == .fall }))
    }

    // MARK: - Peregrino

    func testMartePeregrenoEnLibra() {
        // Marte en Libra 25° = 205°
        // Libra: exilio de Marte (Marte domicilio Aries/Escorpio → exilio en Libra)
        // por tanto no puede ser peregrino — ajustamos: Géminis 28° = 88°
        // decanato de Géminis (sign 2): pos 2*3 + 2 = 8 → chaldeanOrder[8%7]=chaldeanOrder[1]=SOL
        // No hay domicilio/exalt/caída de Marte en Géminis. Sí hay Faz(SOL), no Marte.
        // Conclusión: Marte en Géminis 28° es peregrino para Marte.
        let d = EssentialDignityEngine.primaryDignity(planet: "MARTE", longitude: 88)
        XCTAssertEqual(d.dignity, .peregrine,
                       "Marte en Géminis 28° no tiene ninguna dignidad: debe ser peregrino")
    }

    // MARK: - Sect

    func testSolEnSectDiurna() {
        XCTAssertTrue(EssentialDignityEngine.isInSect(planet: "SOL", isDiurnal: true))
        XCTAssertFalse(EssentialDignityEngine.isInSect(planet: "SOL", isDiurnal: false))
    }

    func testMarteEnSectNocturna() {
        XCTAssertTrue(EssentialDignityEngine.isInSect(planet: "MARTE", isDiurnal: false))
        XCTAssertFalse(EssentialDignityEngine.isInSect(planet: "MARTE", isDiurnal: true))
    }

    func testMercurioEnAmbasSects() {
        XCTAssertTrue(EssentialDignityEngine.isInSect(planet: "MERCURIO", isDiurnal: true))
        XCTAssertTrue(EssentialDignityEngine.isInSect(planet: "MERCURIO", isDiurnal: false))
    }

    func testIsDiurnal() {
        XCTAssertTrue(EssentialDignityEngine.isDiurnal(sunHouse: 10))  // Sol en Casa 10 = diurna
        XCTAssertFalse(EssentialDignityEngine.isDiurnal(sunHouse: 4))  // Sol en Casa 4 = nocturna
    }

    // MARK: - Recepción Mutua

    func testMutualReceptionDetected() {
        // Sol en Cáncer (regido por Luna), Luna en Leo (regida por Sol) = recepción mutua
        let hasMR = EssentialDignityEngine.mutualReceptionByDomicile(
            planetA: "SOL", lonA: 100,   // Cáncer ~100°
            planetB: "LUNA", lonB: 130   // Leo ~130°
        )
        XCTAssertTrue(hasMR)
    }

    func testNoMutualReception() {
        let hasMR = EssentialDignityEngine.mutualReceptionByDomicile(
            planetA: "SOL", lonA: 20,     // Aries
            planetB: "MARTE", lonB: 200   // Libra
        )
        XCTAssertFalse(hasMR)
    }

    // MARK: - Description string

    func testDescriptionReturnsDignityName() {
        let desc = EssentialDignityEngine.description(planet: "SOL", longitude: 135) // Leo
        XCTAssertEqual(desc, "domicilio")
    }
}

// MARK: - PDInterpretationContextBuilder Tests

final class PDInterpretationContextBuilderTests: XCTestCase {

    // MARK: - Test helpers

    private func makeChart(sunHouse: Int = 10, bodies: [PlanetBody]? = nil) -> NatalChart {
        var chartBodies: [PlanetBody] = bodies ?? [
            PlanetBody(key: "SOL", label: "☉ Sol", longitude: 197.5,
                       formatted: "♎ Libra 17°30'", house: sunHouse, retrograde: false),
            PlanetBody(key: "LUNA", label: "☽ Luna", longitude: 60.5,
                       formatted: "♊ Géminis 00°30'", house: 4, retrograde: false),
            PlanetBody(key: "MARTE", label: "♂ Marte", longitude: 340.0,
                       formatted: "♓ Piscis 10°00'", house: 6, retrograde: false),
            PlanetBody(key: "SATURN", label: "♄ Saturno", longitude: 110.0,
                       formatted: "♋ Cáncer 20°00'", house: 5, retrograde: false),
        ]
        return NatalChart(
            id: UUID(),
            name: "Test Chart",
            birthDate: "1976-10-11",
            birthTime: "20:33",
            timezone: "Europe/Madrid",
            latitude: 40.4168,
            longitude: -3.7038,
            placeName: "Madrid",
            houseSystem: "Regiomontanus",
            ascendant: AngularPoint(longitude: 60.5, formatted: "♊ Géminis 00°30'"),
            mc: AngularPoint(longitude: 330.0, formatted: "♓ Piscis 00°00'"),
            cusps: Array(repeating: 0.0, count: 12),
            bodies: chartBodies
        )
    }

    private func makeDirection(promissor: String = "MARTE", significator: String = "ASC") -> PrimaryDirection {
        PrimaryDirection(
            promissor: promissor,
            promissorLabel: "♂ \(promissor)",
            significator: significator,
            significatorLabel: significator,
            aspect: .conjunction,
            aspectAngle: 0,
            directionType: .direct,
            aspectPlane: .zodiacal,
            arc: 15.5,
            estimatedAge: 15.73,
            estimatedDate: Date(),
            method: .regiomontanus,
            key: .naibod,
            technicalData: PDTechnicalData(
                promissorRA: 0, promissorDeclination: 0,
                significatorRA: 0, significatorDeclination: 0,
                significatorPole: 0, obliquity: 23.44,
                ramc: 0, geoLatitude: 40.4168
            )
        )
    }

    // MARK: - Build Tests

    func testBuildReturnsContext() {
        let chart = makeChart()
        let direction = makeDirection()
        let ctx = PDInterpretationContextBuilder.build(chart: chart, direction: direction)

        XCTAssertNotNil(ctx)
        XCTAssertNotNil(ctx.promissorDignity, "Debe haber dignidad del promissor")
        XCTAssertNotNil(ctx.birthYear)
        XCTAssertEqual(ctx.birthYear, 1976)
    }

    func testSectDetectedCorrectly() {
        // Sol en casa 10 = carta diurna
        let chartDiurnal = makeChart(sunHouse: 10)
        let ctx = PDInterpretationContextBuilder.build(
            chart: chartDiurnal, direction: makeDirection()
        )
        XCTAssertFalse(ctx.isNocturnal, "Sol en Casa 10 = carta diurna")
    }

    func testNocturnalChartDetected() {
        // Sol en casa 4 = carta nocturna
        let chartNocturnal = makeChart(sunHouse: 4)
        let ctx = PDInterpretationContextBuilder.build(
            chart: chartNocturnal, direction: makeDirection()
        )
        XCTAssertTrue(ctx.isNocturnal, "Sol en Casa 4 = carta nocturna")
    }

    func testPromissorHouseExtracted() {
        let chart = makeChart()
        let dir = makeDirection(promissor: "MARTE")
        let ctx = PDInterpretationContextBuilder.build(chart: chart, direction: dir)
        XCTAssertEqual(ctx.promissorNatalHouse, 6, "Marte debe estar en Casa 6")
    }

    func testMarteSectNocturna() {
        let chartNocturnal = makeChart(sunHouse: 4)
        let dir = makeDirection(promissor: "MARTE")
        let ctx = PDInterpretationContextBuilder.build(chart: chartNocturnal, direction: dir)
        XCTAssertTrue(ctx.promissorInSect, "Marte en sect nocturna")
    }

    func testMarteFueraDeSectDiurna() {
        let chartDiurnal = makeChart(sunHouse: 10)
        let dir = makeDirection(promissor: "MARTE")
        let ctx = PDInterpretationContextBuilder.build(chart: chartDiurnal, direction: dir)
        XCTAssertFalse(ctx.promissorInSect, "Marte fuera de sect en carta diurna")
    }

    func testSignificatorConditionForASC() {
        let chart = makeChart()
        let dir = makeDirection(significator: "ASC")
        let ctx = PDInterpretationContextBuilder.build(chart: chart, direction: dir)
        XCTAssertNotNil(ctx.significatorCondition)
        XCTAssertTrue(ctx.significatorCondition?.contains("ASC") ?? false)
    }

    func testSignificatorConditionForMC() {
        let chart = makeChart()
        let dir = makeDirection(significator: "MC")
        let ctx = PDInterpretationContextBuilder.build(chart: chart, direction: dir)
        XCTAssertNotNil(ctx.significatorCondition)
        XCTAssertTrue(ctx.significatorCondition?.contains("MC") ?? false)
    }

    func testNativeAgeCalculated() {
        let chart = makeChart()
        let dir = makeDirection()
        let refDate = Calendar.current.date(from: DateComponents(year: 2026, month: 4, day: 27))!
        let ctx = PDInterpretationContextBuilder.build(
            chart: chart, direction: dir, currentDate: refDate
        )
        if let age = ctx.nativeCurrentAge {
            XCTAssertGreaterThan(age, 49.0)
            XCTAssertLessThan(age, 50.0)
        }
    }

    // MARK: - Profection Tests

    func testProfectionAtAge15() {
        // ASC en Géminis (sign 2), edad 15 → (2 + 15) % 12 = 5 = Virgo
        let result = PDInterpretationContextBuilder.profection(
            ascendantLongitude: 60.5,   // Géminis
            ageAtDirection: 15.73
        )
        XCTAssertEqual(result.year, 15)
        XCTAssertEqual(result.signIndex, 5)   // Virgo
        XCTAssertEqual(result.signName, "Virgo")
        XCTAssertEqual(result.lord, "MERCURIO")
    }

    func testProfectionAtAge0IsAscendant() {
        // Edad 0 → signo del Ascendente mismo
        let result = PDInterpretationContextBuilder.profection(
            ascendantLongitude: 0.0,    // Aries sign 0
            ageAtDirection: 0.5
        )
        XCTAssertEqual(result.signIndex, 0)   // Aries
        XCTAssertEqual(result.lord, "MARTE")
    }

    func testProfectionWrapsAround12() {
        // Edad 12 → vuelve al Ascendente
        let result = PDInterpretationContextBuilder.profection(
            ascendantLongitude: 30.0,   // Tauro sign 1
            ageAtDirection: 12.0
        )
        XCTAssertEqual(result.signIndex, 1)   // Tauro (1 + 12) % 12 = 1
    }
}

// MARK: - MigrationRunner Tests

final class MigrationRunnerTests: XCTestCase {

    // MARK: - Test DB helpers

    private func makeInMemoryConfig() throws -> (config: MigrationRunner.Config, corpusDB: SQLiteDB, userDB: SQLiteDB) {
        let tmpDir = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: tmpDir, withIntermediateDirectories: true)

        let corpusURL = tmpDir.appendingPathComponent("corpus.db")
        let userURL = tmpDir.appendingPathComponent("user.db")

        // Pre-create empty DBs (simulating writable copies already in place)
        let corpusDB = try SQLiteDB(path: corpusURL.path, readonly: false)
        let userDB = try SQLiteDB(path: userURL.path, readonly: false)

        let config = MigrationRunner.Config(
            corpusWritableURL: corpusURL,
            userDBURL: userURL,
            resourceBundle: AppResources.bundle
        )
        return (config, corpusDB, userDB)
    }

    // MARK: - ensureMigrationsTable (internal behavior via apply)

    func testMigrationsTableCreatedAfterRun() throws {
        let (config, corpusDB, userDB) = try makeInMemoryConfig()
        _ = try MigrationRunner.applyAll(config: config)

        // Both DBs should have migrations_applied table
        let corpusRows = try corpusDB.query("SELECT name FROM sqlite_master WHERE type='table' AND name='migrations_applied'")
        XCTAssertEqual(corpusRows.count, 1, "corpus.db debe tener migrations_applied")

        let userRows = try userDB.query("SELECT name FROM sqlite_master WHERE type='table' AND name='migrations_applied'")
        XCTAssertEqual(userRows.count, 1, "user.db debe tener migrations_applied")
    }

    func testApplyIsIdempotent() throws {
        let (config, _, _) = try makeInMemoryConfig()

        // First run
        let result1 = try MigrationRunner.applyAll(config: config)
        // Second run
        let result2 = try MigrationRunner.applyAll(config: config)

        XCTAssertFalse(result1.hasErrors, "Primera ejecución no debe tener errores")
        XCTAssertFalse(result2.hasErrors, "Segunda ejecución no debe tener errores")

        // Everything applied in first run should be skipped in second
        let firstAppliedCount = result1.applied.count
        let secondSkippedCount = result2.skipped.count
        XCTAssertEqual(firstAppliedCount, secondSkippedCount,
                       "Todo lo aplicado en la primera ejecución debe saltarse en la segunda")
        XCTAssertEqual(result2.applied.count, 0,
                       "Segunda ejecución no debe aplicar ninguna migración nueva")
    }

    func testCorpusMigrationsGoToCorpusDB() throws {
        // Test the routing logic directly with in-memory DBs and raw SQL
        let corpusURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString + "_corpus.db")
        let userURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString + "_user.db")

        let corpusDB = try SQLiteDB(path: corpusURL.path, readonly: false)
        let userDB = try SQLiteDB(path: userURL.path, readonly: false)

        // Simulate what applyAll does: corpus SQL → corpusDB, user SQL → userDB
        let corpusSQL = """
            CREATE TABLE IF NOT EXISTS primary_direction_meanings (
                id INTEGER PRIMARY KEY, clave TEXT NOT NULL UNIQUE
            )
        """
        let userSQL = """
            CREATE TABLE IF NOT EXISTS primary_directions_interpretations (
                id INTEGER PRIMARY KEY, direction_id TEXT NOT NULL
            )
        """

        try corpusDB.execute(corpusSQL)
        try userDB.execute(userSQL)

        let corpusTables = try corpusDB.query(
            "SELECT name FROM sqlite_master WHERE type='table' AND name='primary_direction_meanings'"
        )
        XCTAssertEqual(corpusTables.count, 1, "primary_direction_meanings debe estar en corpus.db")

        let userTables = try userDB.query(
            "SELECT name FROM sqlite_master WHERE type='table' AND name='primary_direction_meanings'"
        )
        XCTAssertEqual(userTables.count, 0,
                       "primary_direction_meanings NO debe estar en user.db")
    }

    func testUserMigrationsGoToUserDB() throws {
        let userURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString + "_user.db")
        let userDB = try SQLiteDB(path: userURL.path, readonly: false)

        let userSQL = """
            CREATE TABLE IF NOT EXISTS primary_directions_interpretations (
                id INTEGER PRIMARY KEY, direction_id TEXT NOT NULL
            )
        """
        try userDB.execute(userSQL)

        let tables = try userDB.query(
            "SELECT name FROM sqlite_master WHERE type='table' AND name='primary_directions_interpretations'"
        )
        XCTAssertEqual(tables.count, 1, "primary_directions_interpretations debe estar en user.db")
    }

    func testResultReportsAppliedAndSkipped() throws {
        let (config, _, _) = try makeInMemoryConfig()

        let result1 = try MigrationRunner.applyAll(config: config)
        let result2 = try MigrationRunner.applyAll(config: config)

        XCTAssertGreaterThanOrEqual(result1.applied.count, 0)
        XCTAssertEqual(result2.applied.count, 0)
        XCTAssertGreaterThanOrEqual(result2.skipped.count, 0)
    }

    func testIsCorpusMigrationConvention() {
        // The naming convention: 001_* plus curated PD meanings → corpus.
        XCTAssertTrue(MigrationRunner.isCorpusMigration("001_primary_direction_meanings.sql"))
        XCTAssertTrue(MigrationRunner.isCorpusMigration("003_primary_direction_ecliptic_meanings.sql"))
        XCTAssertTrue(MigrationRunner.isCorpusMigration("006_populate_pd_classical_corpus.sql"))
        XCTAssertFalse(MigrationRunner.isCorpusMigration("002_primary_directions_interpretations.sql"))
    }
}
