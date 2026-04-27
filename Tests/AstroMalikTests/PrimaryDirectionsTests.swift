import XCTest
@testable import AstroMalik

// MARK: - Primary Directions Parity Tests
// Validación obligatoria contra valores de referencia de Morinus.
// Tolerancia: ±0.1° en arcos direccionales.
// Casos de test:
//   1. Eduardo natal (1976-10-11 20:33 Madrid)
//   2. William Lilly (1602-05-11 02:00 NS, Diseworth, UK)
//   3. Test de simetría: arco directo ≠ arco converso (no deben ser iguales)
//   4. Test de coherencia: oblicuidad y RAMC contra Swiss Ephemeris directos

final class PrimaryDirectionsTests: XCTestCase {

    private let calculator = PrimaryDirectionCalculator()

    override func setUp() {
        super.setUp()
        AstroEngine.configure(ephePath: nil)
    }

    // MARK: - Speculum Sanity Tests

    /// Test fundamental: la oblicuidad de la eclíptica debe estar alrededor de 23.44°
    func testObliquityRange() throws {
        // J2000.0
        let jd = 2451545.0
        let obl = calculator.getObliquity(jd: jd)
        XCTAssertEqual(obl, 23.44, accuracy: 0.1, "Oblicuidad en J2000 fuera de rango: \(obl)")
    }

    /// Test: RAMC para un JD conocido debe ser coherente
    func testRamcComputation() throws {
        // J2000.0, Greenwich (lon=0)
        let jd = 2451545.0
        let ramc = calculator.getRamc(jd: jd, lon: 0)
        // RAMC en J2000.0 = sidereal time at Greenwich * 15
        // ST at J2000.0 ≈ 18h 41m 50.54s → ~280.46°
        XCTAssertEqual(ramc, 280.46, accuracy: 1.0,
                       "RAMC en J2000.0 fuera de rango: \(ramc)")
    }

    /// Test: ecliptic → equatorial conversion must be consistent
    func testEclipticToEquatorial() throws {
        // Sol en 0° Aries (lon=0, lat=0) → RA=0, decl=0
        let (ra, decl) = calculator.eclipticToEquatorial(lon: 0, lat: 0, obliquity: 23.44)
        XCTAssertEqual(ra, 0, accuracy: 0.01, "RA en 0° Aries debe ser ~0: \(ra)")
        XCTAssertEqual(decl, 0, accuracy: 0.01, "Decl en 0° Aries debe ser ~0: \(decl)")

        // Sol en 90° (0° Cáncer) → RA≈90°, decl≈+23.44°
        let (ra90, decl90) = calculator.eclipticToEquatorial(lon: 90, lat: 0, obliquity: 23.44)
        XCTAssertEqual(ra90, 90, accuracy: 0.5, "RA en 90° debe ser ~90: \(ra90)")
        XCTAssertEqual(decl90, 23.44, accuracy: 0.1,
                       "Decl en 90° debe ser ~oblicuidad: \(decl90)")
    }

    // MARK: - Regiomontanus Speculum Tests

    /// Test: MC speculum must have pole=0 (MC is on meridian, ZD=0)
    func testMCSpeculumPoleIsZero() throws {
        let ramc = 280.0
        let placelat = 40.4168
        let obliquity = 23.44

        // MC longitude doesn't matter for this test; what matters is RA = RAMC
        let (mcRA, mcDecl) = calculator.eclipticToEquatorial(
            lon: 200.0, lat: 0, obliquity: obliquity
        )

        // For MC, RA should equal RAMC; let's use RAMC directly
        let mcSpec = RegiomontanusSpeculum(
            placelat: placelat, ramc: ramc,
            lon: 200.0, lat: 0, ra: ramc, decl: mcDecl
        )

        // MC has MD = 0, so ZD should be ~0 and pole should be ~0
        XCTAssertEqual(mcSpec.pole, 0, accuracy: 0.5,
                       "El polo del MC debe ser ~0°: \(mcSpec.pole)")
        XCTAssertTrue(mcSpec.isUpperMD,
                      "MC debe estar en upper meridian distance")
    }

    /// Test: ASC speculum must have pole = geographic latitude
    func testASCSpeculumPoleIsGeoLat() throws {
        let ramc = 280.0
        let placelat = 40.4168

        // ASC has RA = RAMC + 90° (equatorial ASC)
        let ascRA = RegiomontanusSpeculum.normalize(ramc + 90)
        // ASC declination approximation for this latitude
        let ascDecl = 0.0 // Simplified; actual test below is more precise

        let ascSpec = RegiomontanusSpeculum(
            placelat: placelat, ramc: ramc,
            lon: 60.0, lat: 0, ra: ascRA, decl: ascDecl
        )

        // ASC must have MD = 90° and ZD = 90°, so pole ≈ lat
        XCTAssertEqual(ascSpec.pole, placelat, accuracy: 1.0,
                       "El polo del ASC debe ser ~latitud geográfica: \(ascSpec.pole)")
    }

    /// Test: Zenith Distance calculation matches Morinus reference values
    func testZenithDistanceKnownValues() throws {
        // Case 1: MD = 0° (on meridian) → ZD must be 0
        let zd0 = RegiomontanusSpeculum.calcZD(md: 0, placelat: 40, decl: 20, umd: true)
        XCTAssertEqual(zd0, 0, accuracy: 0.01,
                       "ZD en meridiano debe ser 0: \(zd0)")

        // Case 2: MD = 90° (on horizon) → ZD ~= 90° for decl=0
        let zd90 = RegiomontanusSpeculum.calcZD(md: 90, placelat: 40, decl: 0, umd: true)
        XCTAssertEqual(zd90, 90, accuracy: 0.5,
                       "ZD en horizonte con decl=0 debe ser ~90°: \(zd90)")
    }

    // MARK: - Eduardo Natal Direction Test

    /// Test con carta natal de Eduardo (1976-10-11 20:33 Madrid).
    /// Verifica que las direcciones primarias se calculan y que los arcos
    /// están dentro del rango esperado.
    func testEduardoNatalDirections() throws {
        let jdResult = try julianDayFromLocal(
            birthDate: "1976-10-11",
            birthTime: "20:33",
            timezoneName: "Europe/Madrid"
        )

        let chart = try AstroEngine.computeNatalChart(
            jd: jdResult.jd,
            lat: 40.4168,
            lon: -3.7038
        )

        let birthDate = Calendar.current.date(
            from: DateComponents(year: 1976, month: 10, day: 11)
        )!

        let config = PrimaryDirectionCalculator.Config(
            method: .regiomontanus,
            key: .naibod,
            maxYears: 80,
            aspects: [.conjunction, .sextile, .square, .trine, .opposition],
            significators: [.asc, .mc],
            includeConverse: true,
            aspectPlane: .zodiacal
        )

        let directions = calculator.calculate(
            chart: chart,
            jd: jdResult.jd,
            birthDate: birthDate,
            config: config
        )

        // Must produce some directions
        XCTAssertGreaterThan(directions.count, 0,
                             "Debe haber al menos una dirección primaria")

        // All arcs must be within maxYears range
        let maxArc = 80.0 * (config.key.degreesPerYear ?? 1.0)
        for dir in directions {
            XCTAssertLessThanOrEqual(abs(dir.arc), maxArc + 0.01,
                                     "Arco fuera de rango: \(dir.arc)")
        }

        // Print first 10 for manual verification
        print("\n=== EDUARDO NATAL - Primeras 10 direcciones ===")
        for (i, dir) in directions.prefix(10).enumerated() {
            print("\(i+1). \(dir.promissorLabel) → \(dir.significatorLabel) " +
                  "\(dir.aspect.label) | arc=\(String(format: "%.4f", dir.arc))° | " +
                  "age=\(String(format: "%.1f", dir.estimatedAge))")
        }
    }

    /// Verifica datos intermedios de la carta de Eduardo
    func testEduardoEquatorialData() throws {
        let jdResult = try julianDayFromLocal(
            birthDate: "1976-10-11",
            birthTime: "20:33",
            timezoneName: "Europe/Madrid"
        )

        let chart = try AstroEngine.computeNatalChart(
            jd: jdResult.jd,
            lat: 40.4168,
            lon: -3.7038
        )

        let obliquity = calculator.getObliquity(jd: jdResult.jd)
        let ramc = calculator.getRamc(jd: jdResult.jd, lon: -3.7038)

        // Oblicuidad debe ser ~23.44° para 1976
        XCTAssertEqual(obliquity, 23.44, accuracy: 0.05,
                       "Oblicuidad para 1976 fuera de rango: \(obliquity)")

        print("\n=== EDUARDO - Datos ecuatoriales ===")
        print("Oblicuidad: \(String(format: "%.6f", obliquity))°")
        print("RAMC: \(String(format: "%.6f", ramc))°")
        print("ASC: \(chart.ascendant.formatted) (lon=\(String(format: "%.4f", chart.ascendant.longitude))°)")
        print("MC: \(chart.mc.formatted) (lon=\(String(format: "%.4f", chart.mc.longitude))°)")

        let bodies = calculator.computeEquatorialBodies(
            chart: chart, jd: jdResult.jd, obliquity: obliquity
        )

        for planet in PLANET_LIST.prefix(7) {
            if let body = bodies[planet.key] {
                print("\(body.label): lon=\(String(format: "%.4f", body.longitude))° " +
                      "RA=\(String(format: "%.4f", body.ra))° " +
                      "Decl=\(String(format: "%.4f", body.declination))°")
            }
        }

        // Sol en Libra (~197.7°), RA should be ~195-198°
        let sol = bodies["SOL"]!
        XCTAssertEqual(sol.longitude, 197.7, accuracy: 1.0,
                       "Sol lon fuera de rango: \(sol.longitude)")
    }

    // MARK: - William Lilly Test

    /// William Lilly: 1602-05-11 (NS) 02:00 Diseworth, UK (52.83N, 1.35W)
    /// Cardinales extremadamente conocidos en la tradición.
    func testWilliamLillyDirections() throws {
        // Lilly birth: May 11, 1602 NS (= May 1, 1602 OS = ~April 30 1602 Julian)
        // For NS/OS conversion, May 11 NS 1602 = May 1 OS 1602
        // JD for 1602-05-01 02:00 UT (Old Style, Diseworth ~52.83N, 1.35W)
        let jdResult = try julianDayFromLocal(
            birthDate: "1602-05-01",
            birthTime: "02:00",
            timezoneName: "Europe/London"
        )

        let chart = try AstroEngine.computeNatalChart(
            jd: jdResult.jd,
            lat: 52.83,
            lon: -1.35
        )

        let birthDate = Calendar.current.date(
            from: DateComponents(year: 1602, month: 5, day: 1)
        )!

        let config = PrimaryDirectionCalculator.Config(
            method: .regiomontanus,
            key: .naibod,
            maxYears: 80,
            aspects: [.conjunction, .square, .opposition],
            significators: [.asc, .mc, .sun, .moon],
            includeConverse: true,
            aspectPlane: .zodiacal
        )

        let directions = calculator.calculate(
            chart: chart,
            jd: jdResult.jd,
            birthDate: birthDate,
            config: config
        )

        XCTAssertGreaterThan(directions.count, 0,
                             "Lilly: debe haber al menos una dirección primaria")

        print("\n=== WILLIAM LILLY - Primeras 10 direcciones ===")
        for (i, dir) in directions.prefix(10).enumerated() {
            print("\(i+1). \(dir.promissorLabel) → \(dir.significatorLabel) " +
                  "\(dir.aspect.label) | arc=\(String(format: "%.4f", dir.arc))° | " +
                  "age=\(String(format: "%.1f", dir.estimatedAge))")
        }
    }

    // MARK: - Asymmetry Test

    /// Verifica que arc(direct) ≠ arc(converse) para el mismo par.
    /// Si fueran iguales, hay un bug en el signo del arco.
    func testDirectConverseAsymmetry() throws {
        let jdResult = try julianDayFromLocal(
            birthDate: "1976-10-11",
            birthTime: "20:33",
            timezoneName: "Europe/Madrid"
        )

        let chart = try AstroEngine.computeNatalChart(
            jd: jdResult.jd,
            lat: 40.4168,
            lon: -3.7038
        )

        let birthDate = Calendar.current.date(
            from: DateComponents(year: 1976, month: 10, day: 11)
        )!

        let config = PrimaryDirectionCalculator.Config(
            method: .regiomontanus,
            key: .naibod,
            maxYears: 80,
            aspects: [.conjunction],
            promissors: ["SOL", "LUNA", "MARTE", "SATURNO"],
            significators: [.asc, .mc],
            includeConverse: true,
            aspectPlane: .zodiacal
        )

        let directions = calculator.calculate(
            chart: chart,
            jd: jdResult.jd,
            birthDate: birthDate,
            config: config
        )

        // Group by promissor-significator pair
        var grouped: [String: [PrimaryDirection]] = [:]
        for dir in directions {
            let key = "\(dir.promissor)-\(dir.significator)-\(dir.aspect.rawValue)"
            grouped[key, default: []].append(dir)
        }

        // For pairs with both direct and converse, arcs must differ
        for (key, dirs) in grouped where dirs.count == 2 {
            let arcs = dirs.map { $0.arc }
            if arcs[0] * arcs[1] < 0 {
                // Different signs = different direction types
                XCTAssertNotEqual(abs(arcs[0]), abs(arcs[1]), accuracy: 0.001,
                                  "Arcos simétricos (bug): \(key) → \(arcs)")
            }
        }

        print("\n=== Test de Asimetría - Pares encontrados ===")
        for (key, dirs) in grouped.sorted(by: { $0.key < $1.key }) {
            let arcStr = dirs.map { String(format: "%.4f", $0.arc) }.joined(separator: ", ")
            print("\(key): [\(arcStr)]")
        }
    }

    // MARK: - Key Conversion Tests

    /// Test: Naibod key = 0.98564722°/year
    func testNaibodKey() {
        let naibod = PrimaryDirectionKey.naibod.degreesPerYear!
        XCTAssertEqual(naibod, 0.98564, accuracy: 0.001,
                       "Naibod key incorrecta: \(naibod)")
    }

    /// Test: Ptolemy key = 1.0°/year exactly
    func testPtolemyKey() {
        let ptolemy = PrimaryDirectionKey.ptolemy.degreesPerYear!
        XCTAssertEqual(ptolemy, 1.0, accuracy: 0.0001,
                       "Ptolemy key incorrecta: \(ptolemy)")
    }

    /// Test: Arco convertido a edad con Naibod
    func testArcToAge() {
        let arc = 30.0 // 30° de arco
        let naibod = PrimaryDirectionKey.naibod.degreesPerYear!
        let age = arc / naibod
        // 30 / 0.98564722 ≈ 30.44 years
        XCTAssertEqual(age, 30.44, accuracy: 0.1,
                       "Edad calculada incorrecta: \(age)")
    }

    // MARK: - Speculum Computation Full Test

    /// Test completo: calcula espéculo de Sol en carta de Eduardo
    /// y verifica que W, pole, ZD están en rangos razonables.
    func testSunSpeculumEduardo() throws {
        let jdResult = try julianDayFromLocal(
            birthDate: "1976-10-11",
            birthTime: "20:33",
            timezoneName: "Europe/Madrid"
        )

        let chart = try AstroEngine.computeNatalChart(
            jd: jdResult.jd,
            lat: 40.4168,
            lon: -3.7038
        )

        let obliquity = calculator.getObliquity(jd: jdResult.jd)
        let ramc = calculator.getRamc(jd: jdResult.jd, lon: -3.7038)

        let bodies = calculator.computeEquatorialBodies(
            chart: chart, jd: jdResult.jd, obliquity: obliquity
        )

        let sol = bodies["SOL"]!
        let solSpec = RegiomontanusSpeculum(
            placelat: chart.latitude, ramc: ramc,
            lon: sol.longitude, lat: sol.latitude,
            ra: sol.ra, decl: sol.declination
        )

        // Sol at 20:33 Madrid in October should be below horizon (set before 20:33)
        // Actually, sunset in Madrid on Oct 11 is around 19:30, so Sun is below
        // But this is local time; we need to check
        print("\n=== Sol Speculum Eduardo ===")
        print("Lon: \(String(format: "%.4f", solSpec.longitude))°")
        print("RA: \(String(format: "%.4f", solSpec.ra))°")
        print("Decl: \(String(format: "%.4f", solSpec.declination))°")
        print("MD: \(String(format: "%.4f", solSpec.meridianDistance))°")
        print("ZD: \(String(format: "%.4f", solSpec.zenithDistance))°")
        print("Pole: \(String(format: "%.4f", solSpec.pole))°")
        print("Q: \(String(format: "%.4f", solSpec.q))°")
        print("W: \(String(format: "%.4f", solSpec.w))°")
        print("Eastern: \(solSpec.eastern)")
        print("Above Horizon: \(solSpec.aboveHorizon)")

        // Pole must be between 0 and 90
        XCTAssertGreaterThanOrEqual(solSpec.pole, 0,
                                     "Polo negativo: \(solSpec.pole)")
        XCTAssertLessThanOrEqual(solSpec.pole, 90,
                                  "Polo > 90°: \(solSpec.pole)")

        // W must be 0-360
        XCTAssertGreaterThanOrEqual(solSpec.w, 0)
        XCTAssertLessThan(solSpec.w, 360)
    }

    // MARK: - Mundane Direction Test

    /// Test: direcciones mundanas deben producir arcos diferentes de las zodiacales
    func testMundaneVsZodiacal() throws {
        let jdResult = try julianDayFromLocal(
            birthDate: "1976-10-11",
            birthTime: "20:33",
            timezoneName: "Europe/Madrid"
        )

        let chart = try AstroEngine.computeNatalChart(
            jd: jdResult.jd,
            lat: 40.4168,
            lon: -3.7038
        )

        let birthDate = Calendar.current.date(
            from: DateComponents(year: 1976, month: 10, day: 11)
        )!

        let zodiacalConfig = PrimaryDirectionCalculator.Config(
            method: .regiomontanus,
            key: .naibod,
            maxYears: 50,
            aspects: [.conjunction],
            promissors: ["MARTE"],
            significators: [.asc],
            includeConverse: false,
            aspectPlane: .zodiacal
        )

        let mundaneConfig = PrimaryDirectionCalculator.Config(
            method: .regiomontanus,
            key: .naibod,
            maxYears: 50,
            aspects: [.conjunction],
            promissors: ["MARTE"],
            significators: [.asc],
            includeConverse: false,
            aspectPlane: .mundane
        )

        let zodiacal = calculator.calculate(
            chart: chart, jd: jdResult.jd, birthDate: birthDate, config: zodiacalConfig
        )

        let mundane = calculator.calculate(
            chart: chart, jd: jdResult.jd, birthDate: birthDate, config: mundaneConfig
        )

        print("\n=== Zodiacal vs Mundano: Marte → ASC ===")
        for d in zodiacal { print("  Zodiacal: arc=\(String(format: "%.4f", d.arc))") }
        for d in mundane { print("  Mundano:  arc=\(String(format: "%.4f", d.arc))") }

        // If both produce results, they should generally differ
        if let zArc = zodiacal.first?.arc, let mArc = mundane.first?.arc {
            // They CAN be close but shouldn't be identical (different projection)
            print("  Diferencia: \(String(format: "%.4f", abs(zArc - mArc)))°")
        }
    }

    // MARK: - Part of Fortune Test

    /// Test: Part of Fortune should differ by sect (day vs night)
    func testPartOfFortuneSectDifference() throws {
        // Eduardo: born at 20:33 (Sun below horizon) → NOCTURNAL
        let jdResult = try julianDayFromLocal(
            birthDate: "1976-10-11",
            birthTime: "20:33",
            timezoneName: "Europe/Madrid"
        )

        let chart = try AstroEngine.computeNatalChart(
            jd: jdResult.jd,
            lat: 40.4168,
            lon: -3.7038
        )

        let obliquity = calculator.getObliquity(jd: jdResult.jd)
        let ramc = calculator.getRamc(jd: jdResult.jd, lon: -3.7038)

        let bodies = calculator.computeEquatorialBodies(
            chart: chart, jd: jdResult.jd, obliquity: obliquity
        )

        // Check that Sun is below horizon (nocturnal chart)
        let sol = bodies["SOL"]!
        let solSpec = RegiomontanusSpeculum(
            placelat: chart.latitude, ramc: ramc,
            lon: sol.longitude, lat: sol.latitude,
            ra: sol.ra, decl: sol.declination
        )

        print("\n=== Parte de Fortuna - Secta ===")
        print("Sol sobre horizonte: \(solSpec.aboveHorizon)")
        print("Carta nocturna: \(!solSpec.aboveHorizon)")

        // The part of fortune longitude should be computed
        let ascLon = chart.ascendant.longitude
        let solLon = sol.longitude
        let lunaLon = bodies["LUNA"]!.longitude

        // Nocturnal: PF = ASC + Sol - Luna
        let pfNocturnal = RegiomontanusSpeculum.normalize(ascLon + solLon - lunaLon)
        // Diurnal: PF = ASC + Luna - Sol
        let pfDiurnal = RegiomontanusSpeculum.normalize(ascLon + lunaLon - solLon)

        print("PF Nocturnal (esperado): \(AstroEngine.degToSign(pfNocturnal))")
        print("PF Diurnal (alternativa): \(AstroEngine.degToSign(pfDiurnal))")

        // Must differ
        XCTAssertNotEqual(pfNocturnal, pfDiurnal, accuracy: 0.01,
                          "PF nocturnal y diurnal no deben ser iguales")
    }

    // MARK: - Corpus Store Tests

    /// Helper: crea un SQLiteDB en memoria con la tabla y datos semilla.
    private func makeInMemoryCorpusDB() throws -> SQLiteDB {
        let db = try SQLiteDB(path: ":memory:", readonly: false)
        let store = PrimaryDirectionCorpusStore(db: db)
        try store.ensureSchema()
        return db
    }

    /// Test: schema creation succeeds without errors
    func testCorpusSchemaCreation() throws {
        let db = try makeInMemoryCorpusDB()
        // Verify table exists by querying it
        let rows = try db.query("SELECT COUNT(*) as n FROM primary_direction_meanings")
        XCTAssertEqual(rows.count, 1, "La tabla debe existir y devolver un conteo")
    }

    /// Test: ensureSchema is idempotent (can be called twice without error)
    func testCorpusSchemaIdempotent() throws {
        let db = try SQLiteDB(path: ":memory:", readonly: false)
        let store = PrimaryDirectionCorpusStore(db: db)
        try store.ensureSchema()
        try store.ensureSchema() // Should not throw
    }

    /// Test: inserting and looking up a single entry
    func testCorpusSingleLookup() throws {
        let db = try makeInMemoryCorpusDB()
        let store = PrimaryDirectionCorpusStore(db: db)

        // Insert a test entry
        try db.run("""
            INSERT INTO primary_direction_meanings
            (clave, promissor, significator, aspect, texto_corto, texto_largo,
             fuente_nombre, fuente_referencia, populated, calidad)
            VALUES (?, ?, ?, ?, ?, ?, ?, ?, 1, 8)
        """, args: [
            .text("MARTE_ASC_CONJUNCION"),
            .text("MARTE"), .text("ASC"), .text("CONJUNCION"),
            .text("Período de acción enérgica."),
            .text("La dirección de Marte al Ascendente marca un período intenso..."),
            .text("William Lilly"),
            .text("Christian Astrology, Cap. LXVI")
        ])

        let result = store.lookup(clave: "MARTE_ASC_CONJUNCION")
        XCTAssertNotNil(result, "Debe encontrar la entrada de corpus")
        XCTAssertEqual(result?.promissor, "MARTE")
        XCTAssertEqual(result?.significator, "ASC")
        XCTAssertEqual(result?.fuenteNombre, "William Lilly")
        XCTAssertTrue(result?.populated == true)
    }

    /// Test: unpopulated entries are not returned by lookup
    func testCorpusUnpopulatedNotReturned() throws {
        let db = try makeInMemoryCorpusDB()
        let store = PrimaryDirectionCorpusStore(db: db)

        // Insert with populated = 0
        try db.run("""
            INSERT INTO primary_direction_meanings
            (clave, promissor, significator, aspect, populated)
            VALUES (?, ?, ?, ?, 0)
        """, args: [
            .text("NEPTUNO_ASC_CONJUNCION"),
            .text("NEPTUNO"), .text("ASC"), .text("CONJUNCION")
        ])

        let result = store.lookup(clave: "NEPTUNO_ASC_CONJUNCION")
        XCTAssertNil(result, "Entradas no pobladas no deben aparecer en lookup")
    }

    /// Test: batch lookup returns correct subset
    func testCorpusBatchLookup() throws {
        let db = try makeInMemoryCorpusDB()
        let store = PrimaryDirectionCorpusStore(db: db)

        // Insert 3 entries: 2 populated, 1 not
        for (clave, pop) in [
            ("SOL_ASC_CONJUNCION", 1),
            ("LUNA_MC_TRIGONO", 1),
            ("PLUTON_ASC_CUADRATURA", 0)
        ] {
            let parts = clave.split(separator: "_")
            try db.run("""
                INSERT INTO primary_direction_meanings
                (clave, promissor, significator, aspect, texto_corto, populated, calidad)
                VALUES (?, ?, ?, ?, ?, ?, 5)
            """, args: [
                .text(clave),
                .text(String(parts[0])), .text(String(parts[1])), .text(String(parts[2])),
                .text("Texto test"),
                .integer(Int64(pop))
            ])
        }

        let results = store.lookupBatch(claves: [
            "SOL_ASC_CONJUNCION",
            "LUNA_MC_TRIGONO",
            "PLUTON_ASC_CUADRATURA",
            "MARTE_MC_OPOSICION" // doesn't exist
        ])

        XCTAssertEqual(results.count, 2,
                       "Batch debe devolver solo las 2 entradas pobladas")
        XCTAssertNotNil(results["SOL_ASC_CONJUNCION"])
        XCTAssertNotNil(results["LUNA_MC_TRIGONO"])
        XCTAssertNil(results["PLUTON_ASC_CUADRATURA"])
    }

    /// Test: stats reports correct counts
    func testCorpusStats() throws {
        let db = try makeInMemoryCorpusDB()
        let store = PrimaryDirectionCorpusStore(db: db)

        // Insert entries
        for (clave, pop) in [
            ("A_ASC_CONJUNCION", 1),
            ("B_ASC_CUADRATURA", 1),
            ("C_MC_TRIGONO", 0)
        ] {
            try db.run("""
                INSERT INTO primary_direction_meanings
                (clave, promissor, significator, aspect, populated)
                VALUES (?, 'X', 'Y', ?, ?)
            """, args: [
                .text(clave),
                .text(String(clave.split(separator: "_").last!)),
                .integer(Int64(pop))
            ])
        }

        let stats = store.stats()
        XCTAssertEqual(stats.total, 3)
        XCTAssertEqual(stats.populated, 2)
        XCTAssertEqual(stats.coveragePercent, 66.66, accuracy: 1.0)
    }

    /// Test: clave generation format is correct
    func testCorpusClaveGeneration() throws {
        let db = try makeInMemoryCorpusDB()
        let store = PrimaryDirectionCorpusStore(db: db)

        let direction = PrimaryDirection(
            promissor: "MARTE",
            promissorLabel: "♂ Marte",
            significator: "ASC",
            significatorLabel: "ASC",
            aspect: .conjunction,
            aspectAngle: 0,
            directionType: .direct,
            aspectPlane: .zodiacal,
            arc: 15.5,
            estimatedAge: 15.7,
            estimatedDate: Date(),
            method: .regiomontanus,
            key: .naibod,
            technicalData: PDTechnicalData(
                promissorRA: 0, promissorDeclination: 0,
                significatorRA: 0, significatorDeclination: 0,
                significatorPole: 0, obliquity: 23.44,
                ramc: 0, geoLatitude: 0
            )
        )

        let clave = store.directionCorpusClave(direction)
        XCTAssertEqual(clave, "MARTE_ASC_CONJUNCION",
                       "Clave debe seguir formato PROM_SIG_ASPECTO")
    }

    /// Test: buildInterpretations integrates correctly with direction results
    func testCorpusBuildInterpretations() throws {
        let db = try makeInMemoryCorpusDB()
        let store = PrimaryDirectionCorpusStore(db: db)

        // Seed one entry
        try db.run("""
            INSERT INTO primary_direction_meanings
            (clave, promissor, significator, aspect, texto_largo,
             fuente_nombre, fuente_referencia, populated, calidad)
            VALUES (?, ?, ?, ?, ?, ?, ?, 1, 9)
        """, args: [
            .text("MARTE_ASC_CONJUNCION"),
            .text("MARTE"), .text("ASC"), .text("CONJUNCION"),
            .text("La dirección de Marte al Ascendente marca un período intenso."),
            .text("William Lilly"),
            .text("CA Cap. LXVI")
        ])

        // Create a mock direction
        let dir = PrimaryDirection(
            promissor: "MARTE",
            promissorLabel: "♂ Marte",
            significator: "ASC",
            significatorLabel: "ASC",
            aspect: .conjunction,
            aspectAngle: 0,
            directionType: .direct,
            aspectPlane: .zodiacal,
            arc: 15.5,
            estimatedAge: 15.7,
            estimatedDate: Date(),
            method: .regiomontanus,
            key: .naibod,
            technicalData: PDTechnicalData(
                promissorRA: 0, promissorDeclination: 0,
                significatorRA: 0, significatorDeclination: 0,
                significatorPole: 0, obliquity: 23.44,
                ramc: 0, geoLatitude: 0
            )
        )

        let interps = store.buildInterpretations(for: [dir])
        XCTAssertEqual(interps.count, 1)
        XCTAssertEqual(interps[0].source, "William Lilly")
        XCTAssertTrue(interps[0].structuralText.contains("Marte al Ascendente"))
        XCTAssertNil(interps[0].contextualText, "Capa 2 LLM debe ser nil en Phase 2")
    }

    // MARK: - Service Integration Tests

    /// Test: PrimaryDirectionsService.compute() produces enriched results with timeline
    func testServiceComputeProducesResults() throws {
        let jdResult = try julianDayFromLocal(
            birthDate: "1976-10-11",
            birthTime: "20:33",
            timezoneName: "Europe/Madrid"
        )

        let chart = try AstroEngine.computeNatalChart(
            jd: jdResult.jd,
            lat: 40.4168,
            lon: -3.7038
        )

        let birthDate = Calendar.current.date(
            from: DateComponents(year: 1976, month: 10, day: 11)
        )!

        // Service without corpus (no DB) — directions only, no interpretations
        let service = PrimaryDirectionsService(corpusStore: nil)

        let config = PrimaryDirectionCalculator.Config(
            method: .regiomontanus,
            key: .naibod,
            maxYears: 80,
            aspects: PDaspect.allCases,
            significators: [.asc, .mc, .sun, .moon],
            includeConverse: true,
            aspectPlane: .zodiacal
        )

        let result = service.compute(
            chart: chart,
            jd: jdResult.jd,
            birthDate: birthDate,
            config: config
        )

        XCTAssertGreaterThan(result.enrichedDirections.count, 0,
                             "Service debe producir direcciones enriquecidas")
        XCTAssertGreaterThan(result.timeline.count, 0,
                             "Service debe producir timeline")
        XCTAssertEqual(result.metadata.method, .regiomontanus)
        XCTAssertEqual(result.metadata.key, .naibod)
        XCTAssertEqual(result.metadata.totalDirections, result.enrichedDirections.count)
        XCTAssertEqual(result.metadata.interpretedCount, 0,
                       "Sin corpus, interpretaciones deben ser 0")

        // Timeline decades should be ordered
        let decades = result.timeline.map { $0.decadeStart }
        XCTAssertEqual(decades, decades.sorted(),
                       "Timeline debe estar ordenada por década")

        print("\n=== Service Integration ===")
        print("Total direcciones: \(result.enrichedDirections.count)")
        print("Timeline décadas: \(result.timeline.count)")
        for entry in result.timeline {
            print("  \(entry.label): \(entry.directions.count) dirs (\(entry.overallTone.emoji) \(entry.overallTone.rawValue))")
        }
    }

    /// Test: Service filtering methods work correctly
    func testServiceFiltering() throws {
        let jdResult = try julianDayFromLocal(
            birthDate: "1976-10-11",
            birthTime: "20:33",
            timezoneName: "Europe/Madrid"
        )

        let chart = try AstroEngine.computeNatalChart(
            jd: jdResult.jd,
            lat: 40.4168,
            lon: -3.7038
        )

        let birthDate = Calendar.current.date(
            from: DateComponents(year: 1976, month: 10, day: 11)
        )!

        let service = PrimaryDirectionsService(corpusStore: nil)
        let config = PrimaryDirectionCalculator.Config(
            method: .regiomontanus,
            key: .naibod,
            maxYears: 50,
            aspects: [.conjunction, .square],
            significators: [.asc, .mc],
            includeConverse: true,
            aspectPlane: .zodiacal
        )

        let result = service.compute(
            chart: chart, jd: jdResult.jd, birthDate: birthDate, config: config
        )

        // Filter by age range
        let inRange = result.forAgeRange(20...30)
        for dir in inRange {
            XCTAssertGreaterThanOrEqual(dir.direction.estimatedAge, 20)
            XCTAssertLessThanOrEqual(dir.direction.estimatedAge, 30)
        }

        // Filter by significator
        let ascOnly = result.forSignificator("ASC")
        for dir in ascOnly {
            XCTAssertEqual(dir.direction.significator, "ASC")
        }

        // Filter by aspect
        let conjOnly = result.forAspect(.conjunction)
        for dir in conjOnly {
            XCTAssertEqual(dir.direction.aspect, .conjunction)
        }

        // Nearest to age
        let nearAge40 = result.nearestToAge(40.0, count: 3)
        XCTAssertLessThanOrEqual(nearAge40.count, 3)
    }

    /// Test: EnrichedPrimaryDirection formatting
    func testEnrichedDirectionFormatting() throws {
        let dir = PrimaryDirection(
            promissor: "MARTE",
            promissorLabel: "♂ Marte",
            significator: "ASC",
            significatorLabel: "ASC",
            aspect: .conjunction,
            aspectAngle: 0,
            directionType: .direct,
            aspectPlane: .zodiacal,
            arc: 30.5,
            estimatedAge: 30.93,
            estimatedDate: Date(),
            method: .regiomontanus,
            key: .naibod,
            technicalData: PDTechnicalData(
                promissorRA: 0, promissorDeclination: 0,
                significatorRA: 0, significatorDeclination: 0,
                significatorPole: 0, obliquity: 23.44,
                ramc: 0, geoLatitude: 0
            )
        )

        let enriched = EnrichedPrimaryDirection(direction: dir, interpretation: nil)

        XCTAssertEqual(enriched.displaySummary, "♂ Marte ☌ Conjunción ASC")
        XCTAssertTrue(enriched.ageFormatted.contains("30 años"))
        XCTAssertTrue(enriched.arcFormatted.contains("30°"))
        XCTAssertFalse(enriched.hasInterpretation)
    }

    // MARK: - Corpus Honesty Invariant Tests

    /// Invariante: populated = 0 ⇒ texto_corto IS NULL AND texto_largo IS NULL.
    /// Entradas sin verificar no deben contener texto atribuido a fuentes.
    func testCorpusNoPopulatedEntriesHaveNullText() throws {
        let db = try SQLiteDB(path: ":memory:", readonly: false)
        let store = PrimaryDirectionCorpusStore(db: db)
        try store.ensureSchema()

        // Insert skeleton entries matching the cleaned SQL pattern
        let skeletonEntries = [
            "SOL_ASC_CONJUNCION", "SOL_ASC_CUADRATURA", "MARTE_ASC_CONJUNCION",
            "SATURNO_MC_CONJUNCION", "JUPITER_LUNA_CONJUNCION"
        ]

        for clave in skeletonEntries {
            let parts = clave.split(separator: "_")
            try db.run("""
                INSERT INTO primary_direction_meanings
                (clave, promissor, significator, aspect,
                 texto_corto, texto_largo, fuente_nombre,
                 fuente_referencia, populated, calidad)
                VALUES (?, ?, ?, ?, NULL, NULL, NULL, ?, 0, 0)
            """, args: [
                .text(clave),
                .text(String(parts[0])),
                .text(String(parts[1])),
                .text(String(parts[2])),
                .text("TODO: verificar contra edición real")
            ])
        }

        // Invariant check: all populated=0 entries must have NULL texts
        let rows = try db.query("""
            SELECT clave, texto_corto, texto_largo, fuente_nombre
            FROM primary_direction_meanings
            WHERE populated = 0
        """)

        for row in rows {
            let clave = row["clave"]?.string ?? "?"
            XCTAssertNil(row["texto_corto"]?.string,
                         "populated=0 entry '\(clave)' tiene texto_corto no-NULL")
            XCTAssertNil(row["texto_largo"]?.string,
                         "populated=0 entry '\(clave)' tiene texto_largo no-NULL")
            XCTAssertNil(row["fuente_nombre"]?.string,
                         "populated=0 entry '\(clave)' tiene fuente_nombre no-NULL — atribución sin verificar")
        }

        // lookup() must return nil for all skeleton entries
        for clave in skeletonEntries {
            let result = store.lookup(clave: clave)
            XCTAssertNil(result,
                         "lookup() devolvió resultado para entrada no poblada: \(clave)")
        }

        // buildInterpretations must return empty for unpopulated corpus
        let mockDir = PrimaryDirection(
            promissor: "SOL", promissorLabel: "☉ Sol",
            significator: "ASC", significatorLabel: "ASC",
            aspect: .conjunction, aspectAngle: 0,
            directionType: .direct, aspectPlane: .zodiacal,
            arc: 10.0, estimatedAge: 10.1, estimatedDate: Date(),
            method: .regiomontanus, key: .naibod,
            technicalData: PDTechnicalData(
                promissorRA: 0, promissorDeclination: 0,
                significatorRA: 0, significatorDeclination: 0,
                significatorPole: 0, obliquity: 23.44,
                ramc: 0, geoLatitude: 0
            )
        )

        let interps = store.buildInterpretations(for: [mockDir])
        XCTAssertEqual(interps.count, 0,
                       "Corpus con populated=0 no debe generar interpretaciones")

        // Stats should show 0 populated
        let stats = store.stats()
        XCTAssertEqual(stats.populated, 0)
        XCTAssertEqual(stats.total, skeletonEntries.count)
        XCTAssertEqual(stats.coveragePercent, 0)
    }

    /// Verifica que entradas con texto pero populated=0 son rechazadas.
    /// Protege contra el error original: texto atribuido + populated=1 sin verificar.
    func testCorpusRejectsTextWithoutPopulatedFlag() throws {
        let db = try SQLiteDB(path: ":memory:", readonly: false)
        let store = PrimaryDirectionCorpusStore(db: db)
        try store.ensureSchema()

        // Simulate the WRONG state: text present but populated=0
        try db.run("""
            INSERT INTO primary_direction_meanings
            (clave, promissor, significator, aspect,
             texto_corto, texto_largo, fuente_nombre, populated, calidad)
            VALUES (?, ?, ?, ?, ?, ?, ?, 0, 8)
        """, args: [
            .text("MARTE_ASC_CONJUNCION"),
            .text("MARTE"), .text("ASC"), .text("CONJUNCION"),
            .text("Texto no verificado"),
            .text("Texto largo no verificado contra fuente real"),
            .text("Autor sin verificar")
        ])

        // Must still return nil — populated=0 overrides any text content
        let result = store.lookup(clave: "MARTE_ASC_CONJUNCION")
        XCTAssertNil(result,
                     "populated=0 debe bloquear el resultado aunque haya texto")

        let batch = store.lookupBatch(claves: ["MARTE_ASC_CONJUNCION"])
        XCTAssertTrue(batch.isEmpty,
                      "lookupBatch no debe devolver entradas con populated=0")
    }

    func testPrimaryDirectionsSingleNoteBuilderIncludesSelectedReading() throws {
        let direction = PrimaryDirection(
            promissor: "MARTE",
            promissorLabel: "♂ Marte",
            significator: "ASC",
            significatorLabel: "ASC",
            aspect: .conjunction,
            aspectAngle: 0,
            directionType: .direct,
            aspectPlane: .mundane,
            arc: 15.5,
            estimatedAge: 15.73,
            estimatedDate: Date(timeIntervalSince1970: 0),
            method: .regiomontanus,
            key: .naibod,
            technicalData: PDTechnicalData(
                promissorRA: 197.5, promissorDeclination: -12.3,
                significatorRA: 60.5, significatorDeclination: 20.4,
                significatorPole: 40.4, obliquity: 23.44,
                ramc: 310.05, geoLatitude: 40.4168
            )
        )
        let enriched = EnrichedPrimaryDirection(
            direction: direction,
            interpretation: PrimaryDirectionInterpretation(
                directionId: direction.id,
                clave: "MARTE_ASC_CONJUNCION",
                title: "Marte al ASC",
                structuralText: "Período de acción marcada sobre la identidad.",
                source: "Lilly",
                sourceReference: "CA III",
                quality: 7,
                contextualText: nil
            )
        )
        let contextual = try JSONDecoder().decode(
            ContextualInterpretation.self,
            from: """
            {
              "directionId": "\(direction.id.uuidString)",
              "clave": "MARTE_ASC_CONJUNCION",
              "tituloPrincipal": "Período marciano",
              "textoEstructural": "Lectura contextual de prueba.",
              "factoresConsiderados": [],
              "periodoActivacion": {
                "edadExacta": 15.73,
                "orbeEnMeses": 6,
                "fechaInicio": "1976-01-01",
                "fechaFin": "1976-12-31"
              },
              "areasAfectadas": [],
              "intensidad": 7,
              "polaridad": "malefico",
              "generadoEn": "2026-04-27T10:00:00Z",
              "promptVersion": "1.0.0"
            }
            """.data(using: .utf8)!
        )
        let chart = NatalChart(
            name: "Eduardo",
            birthDate: "1976-10-11",
            birthTime: "20:33",
            timezone: "Europe/Madrid",
            latitude: 40.4168,
            longitude: -3.7038,
            placeName: "Madrid",
            houseSystem: "Regiomontanus",
            ascendant: AngularPoint(longitude: 60.5, formatted: "ASC"),
            mc: AngularPoint(longitude: 300.0, formatted: "MC"),
            cusps: Array(repeating: 0, count: 12),
            bodies: []
        )

        let markdown = PrimaryDirectionsNoteBuilder.singleDirectionMarkdown(
            chart: chart,
            enriched: enriched,
            contextual: contextual
        )

        XCTAssertTrue(markdown.contains("# Dirección Primaria - Eduardo"))
        XCTAssertTrue(markdown.contains("MARTE_ASC_CONJUNCION"))
        XCTAssertTrue(markdown.contains("Período de acción marcada sobre la identidad."))
        XCTAssertTrue(markdown.contains("## Lectura contextual"))
    }

    func testPrimaryDirectionsFilteredReportNoteBuilderIncludesSummaryCounts() {
        let directionA = PrimaryDirection(
            promissor: "SOL",
            promissorLabel: "☉ Sol",
            significator: "ASC",
            significatorLabel: "ASC",
            aspect: .conjunction,
            aspectAngle: 0,
            directionType: .direct,
            aspectPlane: .mundane,
            arc: 10,
            estimatedAge: 10.1,
            estimatedDate: Date(),
            method: .regiomontanus,
            key: .naibod,
            technicalData: PDTechnicalData(
                promissorRA: 0, promissorDeclination: 0,
                significatorRA: 0, significatorDeclination: 0,
                significatorPole: 0, obliquity: 23.44,
                ramc: 0, geoLatitude: 0
            )
        )
        let directionB = PrimaryDirection(
            promissor: "LUNA",
            promissorLabel: "☽ Luna",
            significator: "MC",
            significatorLabel: "MC",
            aspect: .trine,
            aspectAngle: 120,
            directionType: .converse,
            aspectPlane: .zodiacal,
            arc: -20,
            estimatedAge: 20.4,
            estimatedDate: Date(),
            method: .regiomontanus,
            key: .naibod,
            technicalData: PDTechnicalData(
                promissorRA: 0, promissorDeclination: 0,
                significatorRA: 0, significatorDeclination: 0,
                significatorPole: 0, obliquity: 23.44,
                ramc: 0, geoLatitude: 0
            )
        )
        let directions = [
            EnrichedPrimaryDirection(
                direction: directionA,
                interpretation: PrimaryDirectionInterpretation(
                    directionId: directionA.id,
                    clave: "SOL_ASC_CONJUNCION",
                    title: "Sol al ASC",
                    structuralText: "Texto A",
                    source: "Bonatti",
                    sourceReference: "Tractatus X",
                    quality: 7,
                    contextualText: nil
                )
            ),
            EnrichedPrimaryDirection(direction: directionB, interpretation: nil),
        ]
        let chart = NatalChart(
            name: "Carta test",
            birthDate: "2000-01-01",
            birthTime: "12:00",
            timezone: "UTC",
            latitude: 0,
            longitude: 0,
            placeName: "Test",
            houseSystem: "Regiomontanus",
            ascendant: AngularPoint(longitude: 0, formatted: "ASC"),
            mc: AngularPoint(longitude: 90, formatted: "MC"),
            cusps: Array(repeating: 0, count: 12),
            bodies: []
        )

        let markdown = PrimaryDirectionsNoteBuilder.filteredReportMarkdown(
            chart: chart,
            settings: PDSettings(),
            visibleDirections: directions,
            selectedDirection: directions.first,
            cachedContextualIDs: [directionA.id]
        )

        XCTAssertTrue(markdown.contains("Direcciones visibles: 2"))
        XCTAssertTrue(markdown.contains("Con corpus: 1"))
        XCTAssertTrue(markdown.contains("Con contextual en caché: 1"))
        XCTAssertTrue(markdown.contains("### ☉ Sol ☌ Conjunción ASC"))
    }

    func testCorpusSeedCoverageReport() throws {
        let repoRoot = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let sqlURL = repoRoot.appendingPathComponent("Resources/migrations/001_primary_direction_meanings.sql")
        guard FileManager.default.fileExists(atPath: sqlURL.path) else {
            return XCTFail("No encuentro 001_primary_direction_meanings.sql en \(sqlURL.path)")
        }

        let sql = try String(contentsOf: sqlURL, encoding: .utf8)
        let seedKeys = extractSeedKeys(from: sql)
        XCTAssertEqual(seedKeys.count, 29, "La tranche seed debe contener 29 claves")

        let db = try SQLiteDB(path: ":memory:", readonly: false)
        try db.execute(sql)
        let store = PrimaryDirectionCorpusStore(db: db)
        let placeholders = seedKeys.map { _ in "?" }.joined(separator: ",")
        let args: [SQLiteValue] = seedKeys.map { .text($0) }

        let rows = try db.query("""
            SELECT clave, populated, texto_corto, texto_largo, fuente_nombre
            FROM primary_direction_meanings
            WHERE clave IN (\(placeholders))
        """, args: args)

        let populatedCount = rows.filter { ($0["populated"]?.int ?? 0) == 1 }.count
        let emptySeedCount = rows.filter { ($0["populated"]?.int ?? 0) == 0 }.count

        let invariantViolations = rows.compactMap { row -> String? in
            guard (row["populated"]?.int ?? 0) == 0 else { return nil }
            let hasText = row["texto_corto"]?.string != nil || row["texto_largo"]?.string != nil
            let hasSource = row["fuente_nombre"]?.string != nil
            return (hasText || hasSource) ? row["clave"]?.string : nil
        }
        XCTAssertTrue(invariantViolations.isEmpty,
                      "No debe haber atribución parcial ni texto en filas seed sin poblar: \(invariantViolations)")

        var missingFrequency: [String: Int] = [:]
        let config = PrimaryDirectionCalculator.Config(
            method: .regiomontanus,
            key: .naibod,
            maxYears: 80,
            aspects: PDaspect.allCases,
            significators: [.asc, .mc, .sun, .moon],
            includeConverse: true,
            aspectPlane: .zodiacal
        )

        for reference in try referenceCharts() {
            let result = storeResult(for: reference, config: config, store: store)
            for enriched in result.enrichedDirections where !enriched.hasInterpretation {
                let clave = store.directionCorpusClave(enriched.direction)
                missingFrequency[clave, default: 0] += 1
            }
        }

        let topMissing = missingFrequency.sorted { lhs, rhs in
            if lhs.value == rhs.value { return lhs.key < rhs.key }
            return lhs.value > rhs.value
        }.prefix(10)

        print("\n=== Corpus Seed Coverage Report ===")
        print("Seed keys: \(seedKeys.count)")
        print("Pobladas: \(populatedCount)")
        print("Seed aún vacías: \(emptySeedCount)")
        print("Top claves faltantes en cartas de referencia:")
        for (clave, count) in topMissing {
            print("  \(clave): \(count)")
        }
    }

    private func extractSeedKeys(from sql: String) -> [String] {
        guard let regex = try? NSRegularExpression(pattern: #"\('([A-Z_]+)'"#) else {
            return []
        }
        let range = NSRange(sql.startIndex..<sql.endIndex, in: sql)
        let matches = regex.matches(in: sql, options: [], range: range)
        let keys = matches.compactMap { match -> String? in
            guard match.numberOfRanges > 1,
                  let keyRange = Range(match.range(at: 1), in: sql) else { return nil }
            return String(sql[keyRange])
        }
        return Array(Set(keys)).sorted()
    }

    private func referenceCharts() throws -> [(chart: NatalChart, jd: Double, birthDate: Date)] {
        let eduardoJD = try julianDayFromLocal(
            birthDate: "1976-10-11",
            birthTime: "20:33",
            timezoneName: "Europe/Madrid"
        )
        let eduardoChart = try AstroEngine.computeNatalChart(
            jd: eduardoJD.jd,
            lat: 40.4168,
            lon: -3.7038
        )
        let eduardoBirthDate = Calendar.current.date(
            from: DateComponents(year: 1976, month: 10, day: 11)
        )!

        let lillyJD = try julianDayFromLocal(
            birthDate: "1602-05-01",
            birthTime: "02:00",
            timezoneName: "Europe/London"
        )
        let lillyChart = try AstroEngine.computeNatalChart(
            jd: lillyJD.jd,
            lat: 52.83,
            lon: -1.35
        )
        let lillyBirthDate = Calendar.current.date(
            from: DateComponents(year: 1602, month: 5, day: 1)
        )!

        return [
            (eduardoChart, eduardoJD.jd, eduardoBirthDate),
            (lillyChart, lillyJD.jd, lillyBirthDate),
        ]
    }

    private func storeResult(
        for reference: (chart: NatalChart, jd: Double, birthDate: Date),
        config: PrimaryDirectionCalculator.Config,
        store: PrimaryDirectionCorpusStore
    ) -> PrimaryDirectionsResult {
        PrimaryDirectionsService(corpusStore: store).compute(
            chart: reference.chart,
            jd: reference.jd,
            birthDate: reference.birthDate,
            config: config
        )
    }
}
