import XCTest
@testable import AstroMalik

private let angleAccuracy = 1e-4
private let ageAccuracy = 1e-3

private struct PDGoldenFile: Codable {
    let eduardo: PDGoldenChart
    let buenosAires: PDGoldenChart
    let reykjavik: PDGoldenChart
    let eduardoBraheKey: PDGoldenScenario
    let eduardoPartOfFortunePromissor: PDGoldenScenario
    let eduardoConverseDirections: PDGoldenScenario

    func chart(for key: String) -> PDGoldenChart {
        switch key {
        case "eduardo": return eduardo
        case "buenosAires": return buenosAires
        case "reykjavik": return reykjavik
        default: fatalError("Unknown golden chart key: \(key)")
        }
    }
}

private struct PDGoldenChart: Codable {
    let ramc: Double
    let obliquity: Double
    let totalDirections: Int
    let directCount: Int
    let converseCount: Int
    let first10: [PDGoldenDirection]
    let first5Converse: [PDGoldenDirection]
    let speculum: [String: PDGoldenSpeculum]
}

private struct PDGoldenScenario: Codable {
    let totalDirections: Int
    let directCount: Int
    let converseCount: Int
    let partOfFortunePromissorCount: Int
    let first10: [PDGoldenDirection]
    let first5Converse: [PDGoldenDirection]
}

private struct PDGoldenDirection: Codable {
    let promissor: String
    let significator: String
    let aspect: String
    let arc: Double
    let age: Double
    let type: String
}

private struct PDGoldenSpeculum: Codable {
    let ra: Double
    let decl: Double
    let pole: Double
    let q: Double
    let w: Double
}

private struct PDChartFixture {
    let key: String
    let name: String
    let birthDate: String
    let birthTime: String
    let timezone: String
    let latitude: Double
    let longitude: Double
    let placeName: String
}

final class PrimaryDirectionsGoldenTests: XCTestCase {
    override func setUp() {
        super.setUp()
        AstroEngine.configure(ephePath: nil)
    }

    func testEduardoPrimaryDirectionsGolden() throws {
        try assertGoldenChart(.eduardo)
    }

    func testBuenosAiresPrimaryDirectionsGolden() throws {
        try assertGoldenChart(.buenosAires)
    }

    func testReykjavikPrimaryDirectionsGolden() throws {
        try assertGoldenChart(.reykjavik)
    }

    func testEduardoBraheKey() throws {
        let expected = try loadGoldenFile().eduardoBraheKey
        let actual = try buildGoldenScenario(.eduardo, config: braheGoldenConfig())
        assertGoldenScenario(actual, expected, "eduardo Brahe")
    }

    func testEduardoPartOfFortuneAsPromissor() throws {
        let expected = try loadGoldenFile().eduardoPartOfFortunePromissor
        let actual = try buildGoldenScenario(.eduardo, config: partOfFortunePromissorGoldenConfig())
        assertGoldenScenario(actual, expected, "eduardo Part of Fortune promissor")
        XCTAssertGreaterThan(actual.partOfFortunePromissorCount, 0)
    }

    func testEduardoConverseDirections() throws {
        let expected = try loadGoldenFile().eduardoConverseDirections
        let actual = try buildGoldenScenario(.eduardo, config: defaultGoldenConfig())
        assertGoldenScenario(actual, expected, "eduardo converse")
        XCTAssertEqual(actual.first5Converse.count, 5)
    }

    func testClassicalPresetReducesDirectionCount() throws {
        let fixture = PDChartFixture.eduardo
        let jdResult = try julianDayFromLocal(
            birthDate: fixture.birthDate,
            birthTime: fixture.birthTime,
            timezoneName: fixture.timezone
        )
        let chart = try makeNatalChart(fixture: fixture, jd: jdResult.jd)
        let birthDate = try makeBirthDate(fixture.birthDate)
        let preset = PDFilterPreset.classical
        let config = PrimaryDirectionCalculator.Config(
            method: .regiomontanus,
            key: .naibod,
            maxYears: 90,
            aspects: preset.orderedAspects,
            promissors: preset.orderedPromissors,
            significators: preset.orderedSignificators,
            includeConverse: true,
            aspectPlane: .zodiacal
        )

        let classicalDirections = PrimaryDirectionCalculator().calculate(
            chart: chart,
            jd: jdResult.jd,
            birthDate: birthDate,
            config: config
        )
        let fullDirections = PrimaryDirectionCalculator().calculate(
            chart: chart,
            jd: jdResult.jd,
            birthDate: birthDate,
            config: defaultGoldenConfig()
        )
        let minimumWeight = PDFilters(maxYears: 90, preset: preset).minimumWeight
        let visibleClassicalDirections = classicalDirections.filter { $0.weight >= minimumWeight }

        XCTAssertGreaterThanOrEqual(visibleClassicalDirections.count, 40)
        XCTAssertLessThanOrEqual(visibleClassicalDirections.count, 120)
        XCTAssertLessThan(visibleClassicalDirections.count, fullDirections.count)
        XCTAssertLessThan(classicalDirections.count, fullDirections.count)
    }

    private func assertGoldenChart(_ fixture: PDChartFixture) throws {
        let expected = try loadGoldenFile().chart(for: fixture.key)
        let actual = try buildGoldenChart(fixture)

        XCTAssertEqual(actual.totalDirections, expected.totalDirections, "\(fixture.key) direction count changed")
        XCTAssertEqual(actual.directCount, expected.directCount, "\(fixture.key) direct count changed")
        XCTAssertEqual(actual.converseCount, expected.converseCount, "\(fixture.key) converse count changed")
        XCTAssertEqual(actual.ramc, expected.ramc, accuracy: angleAccuracy, "\(fixture.key) RAMC changed")
        XCTAssertEqual(actual.obliquity, expected.obliquity, accuracy: angleAccuracy, "\(fixture.key) obliquity changed")

        assertGoldenDirections(actual.first10, expected.first10, "\(fixture.key) first10")
        assertGoldenDirections(actual.first5Converse, expected.first5Converse, "\(fixture.key) first5Converse")

        XCTAssertEqual(Set(actual.speculum.keys), Set(expected.speculum.keys), "\(fixture.key) speculum keys changed")
        for key in expectedSpeculumKeys {
            let actualRow = try XCTUnwrap(actual.speculum[key], "\(fixture.key) missing actual speculum row \(key)")
            let expectedRow = try XCTUnwrap(expected.speculum[key], "\(fixture.key) missing expected speculum row \(key)")
            XCTAssertEqual(actualRow.ra, expectedRow.ra, accuracy: angleAccuracy, "\(fixture.key) \(key) RA changed")
            XCTAssertEqual(actualRow.decl, expectedRow.decl, accuracy: angleAccuracy, "\(fixture.key) \(key) decl changed")
            XCTAssertEqual(actualRow.pole, expectedRow.pole, accuracy: angleAccuracy, "\(fixture.key) \(key) pole changed")
            XCTAssertEqual(actualRow.q, expectedRow.q, accuracy: angleAccuracy, "\(fixture.key) \(key) q changed")
            XCTAssertEqual(actualRow.w, expectedRow.w, accuracy: angleAccuracy, "\(fixture.key) \(key) w changed")
        }
    }

    private func assertGoldenScenario(
        _ actual: PDGoldenScenario,
        _ expected: PDGoldenScenario,
        _ label: String
    ) {
        XCTAssertEqual(actual.totalDirections, expected.totalDirections, "\(label) direction count changed")
        XCTAssertEqual(actual.directCount, expected.directCount, "\(label) direct count changed")
        XCTAssertEqual(actual.converseCount, expected.converseCount, "\(label) converse count changed")
        XCTAssertEqual(
            actual.partOfFortunePromissorCount,
            expected.partOfFortunePromissorCount,
            "\(label) Part of Fortune promissor count changed"
        )
        assertGoldenDirections(actual.first10, expected.first10, "\(label) first10")
        assertGoldenDirections(actual.first5Converse, expected.first5Converse, "\(label) first5Converse")
    }

    private func assertGoldenDirections(
        _ actual: [PDGoldenDirection],
        _ expected: [PDGoldenDirection],
        _ label: String
    ) {
        XCTAssertEqual(actual.count, expected.count, "\(label) size changed")
        for (index, pair) in zip(actual, expected).enumerated() {
            let (actualDirection, expectedDirection) = pair
            XCTAssertEqual(actualDirection.promissor, expectedDirection.promissor, "\(label)[\(index)] promissor changed")
            XCTAssertEqual(actualDirection.significator, expectedDirection.significator, "\(label)[\(index)] significator changed")
            XCTAssertEqual(actualDirection.aspect, expectedDirection.aspect, "\(label)[\(index)] aspect changed")
            XCTAssertEqual(actualDirection.type, expectedDirection.type, "\(label)[\(index)] type changed")
            XCTAssertEqual(actualDirection.arc, expectedDirection.arc, accuracy: angleAccuracy, "\(label)[\(index)] arc changed")
            XCTAssertEqual(actualDirection.age, expectedDirection.age, accuracy: ageAccuracy, "\(label)[\(index)] age changed")
        }
    }
}

final class PrimaryDirectionsGoldenBootstrapTests: XCTestCase {
    func testGeneratePrimaryDirectionsGoldenBaseline() throws {
        guard ProcessInfo.processInfo.environment["GENERATE_PD_GOLDEN"] == "1" else {
            throw XCTSkip("Run swift scripts/generate_pd_golden.swift to regenerate the golden baseline.")
        }

        AstroEngine.configure(ephePath: nil)
        let golden = try generateGoldenFile()
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data = try encoder.encode(golden)
        let outputURL = testsDirectoryURL().appendingPathComponent("PrimaryDirectionsGolden.json")
        try data.write(to: outputURL, options: [.atomic])

        print("Primary Directions golden baseline generated:")
        for fixture in pdFixtures {
            let chart = golden.chart(for: fixture.key)
            let firstArc = chart.first10.first?.arc ?? 0
            print(
                "- \(fixture.key): directions=\(chart.totalDirections), " +
                "first10=\(chart.first10.count), ramc=\(format(chart.ramc)), " +
                "obliquity=\(format(chart.obliquity)), firstArc=\(format(firstArc))"
            )
        }
        print("Wrote \(outputURL.path)")
    }
}

private let pdFixtures: [PDChartFixture] = [.eduardo, .buenosAires, .reykjavik]

private let expectedSpeculumKeys = Set(PLANET_LIST.map(\.key) + ["ASC", "MC"])

private extension PDChartFixture {
    static let eduardo = PDChartFixture(
        key: "eduardo",
        name: "Eduardo",
        birthDate: "1976-10-11",
        birthTime: "20:33",
        timezone: "Europe/Madrid",
        latitude: 40.4168,
        longitude: -3.7038,
        placeName: "Madrid, España"
    )

    static let buenosAires = PDChartFixture(
        key: "buenosAires",
        name: "Buenos Aires Control",
        birthDate: "1985-03-15",
        birthTime: "14:00",
        timezone: "America/Argentina/Buenos_Aires",
        latitude: -34.6037,
        longitude: -58.3816,
        placeName: "Buenos Aires, Argentina"
    )

    static let reykjavik = PDChartFixture(
        key: "reykjavik",
        name: "Reykjavik Control",
        birthDate: "1990-01-01",
        birthTime: "06:30",
        timezone: "Atlantic/Reykjavik",
        latitude: 64.1466,
        longitude: -21.9426,
        placeName: "Reykjavik, Iceland"
    )
}

private func generateGoldenFile() throws -> PDGoldenFile {
    let charts = Dictionary(
        uniqueKeysWithValues: try pdFixtures.map { fixture in
            (fixture.key, try buildGoldenChart(fixture))
        }
    )

    return PDGoldenFile(
        eduardo: charts["eduardo"]!,
        buenosAires: charts["buenosAires"]!,
        reykjavik: charts["reykjavik"]!,
        eduardoBraheKey: try buildGoldenScenario(.eduardo, config: braheGoldenConfig()),
        eduardoPartOfFortunePromissor: try buildGoldenScenario(
            .eduardo,
            config: partOfFortunePromissorGoldenConfig()
        ),
        eduardoConverseDirections: try buildGoldenScenario(.eduardo, config: defaultGoldenConfig())
    )
}

private func buildGoldenChart(_ fixture: PDChartFixture) throws -> PDGoldenChart {
    let jdResult = try julianDayFromLocal(
        birthDate: fixture.birthDate,
        birthTime: fixture.birthTime,
        timezoneName: fixture.timezone
    )
    let chart = try makeNatalChart(fixture: fixture, jd: jdResult.jd)
    let birthDate = try makeBirthDate(fixture.birthDate)
    let calculator = PrimaryDirectionCalculator()
    let config = defaultGoldenConfig()

    let directions = calculator.calculate(
        chart: chart,
        jd: jdResult.jd,
        birthDate: birthDate,
        config: config
    )
    let obliquity = calculator.getObliquity(jd: jdResult.jd)
    let ramc = calculator.getRamc(jd: jdResult.jd, lon: fixture.longitude)
    let speculumRows = calculator.computeFullSpeculum(chart: chart, jd: jdResult.jd)
    let speculum = Dictionary(
        uniqueKeysWithValues: speculumRows
            .filter { expectedSpeculumKeys.contains($0.key) }
            .map {
                (
                    $0.key,
                    PDGoldenSpeculum(
                        ra: rounded($0.rightAscension, scale: 8),
                        decl: rounded($0.declination, scale: 8),
                        pole: rounded($0.pole, scale: 8),
                        q: rounded($0.q, scale: 8),
                        w: rounded($0.w, scale: 8)
                    )
                )
            }
    )

    return PDGoldenChart(
        ramc: rounded(ramc, scale: 8),
        obliquity: rounded(obliquity, scale: 8),
        totalDirections: directions.count,
        directCount: directions.filter { $0.directionType == .direct }.count,
        converseCount: directions.filter { $0.directionType == .converse }.count,
        first10: goldenDirections(directions.prefix(10)),
        first5Converse: goldenDirections(directions.filter { $0.directionType == .converse }.prefix(5)),
        speculum: speculum
    )
}

private func buildGoldenScenario(
    _ fixture: PDChartFixture,
    config: PrimaryDirectionCalculator.Config
) throws -> PDGoldenScenario {
    let jdResult = try julianDayFromLocal(
        birthDate: fixture.birthDate,
        birthTime: fixture.birthTime,
        timezoneName: fixture.timezone
    )
    let chart = try makeNatalChart(fixture: fixture, jd: jdResult.jd)
    let birthDate = try makeBirthDate(fixture.birthDate)
    let directions = PrimaryDirectionCalculator().calculate(
        chart: chart,
        jd: jdResult.jd,
        birthDate: birthDate,
        config: config
    )

    return PDGoldenScenario(
        totalDirections: directions.count,
        directCount: directions.filter { $0.directionType == .direct }.count,
        converseCount: directions.filter { $0.directionType == .converse }.count,
        partOfFortunePromissorCount: directions.filter { $0.promissor == "PARTFORTUNA" }.count,
        first10: goldenDirections(directions.prefix(10)),
        first5Converse: goldenDirections(directions.filter { $0.directionType == .converse }.prefix(5))
    )
}

private func defaultGoldenConfig(
    key: PrimaryDirectionKey = .naibod,
    promissors: [String] = [],
    includeConverse: Bool = true
) -> PrimaryDirectionCalculator.Config {
    PrimaryDirectionCalculator.Config(
        method: .regiomontanus,
        key: key,
        maxYears: 90,
        aspects: PDaspect.allCases,
        promissors: promissors,
        significators: [.asc, .mc, .sun, .moon],
        includeConverse: includeConverse,
        aspectPlane: .zodiacal
    )
}

private func braheGoldenConfig() -> PrimaryDirectionCalculator.Config {
    defaultGoldenConfig(key: .brahe)
}

private func partOfFortunePromissorGoldenConfig() -> PrimaryDirectionCalculator.Config {
    defaultGoldenConfig(promissors: PLANET_LIST.map(\.key) + ["ASC", "MC", "PARTFORTUNA"])
}

private func goldenDirections<S: Sequence>(_ directions: S) -> [PDGoldenDirection] where S.Element == PrimaryDirection {
    directions.map {
        PDGoldenDirection(
            promissor: $0.promissor,
            significator: $0.significator,
            aspect: $0.aspect.rawValue,
            arc: rounded($0.arc, scale: 8),
            age: rounded($0.estimatedAge, scale: 8),
            type: $0.directionType.rawValue
        )
    }
}

private func makeNatalChart(fixture: PDChartFixture, jd: Double) throws -> NatalChart {
    let rawPlanets = try AstroEngine.calcPlanets(jd: jd)
    let houses = try AstroEngine.calcHouses(
        jd: jd,
        lat: fixture.latitude,
        lon: fixture.longitude,
        system: "P"
    )
    let cusps = houses.cusps.map { normalize($0) }

    let bodies = PLANET_LIST.compactMap { planet -> PlanetBody? in
        guard let raw = rawPlanets[planet.key] else { return nil }
        return PlanetBody(
            key: planet.key,
            label: planet.label,
            longitude: normalize(raw.deg),
            formatted: AstroEngine.degToSign(raw.deg),
            house: AstroEngine.planetHouse(deg: raw.deg, cusps: cusps),
            retrograde: raw.retro
        )
    }

    return NatalChart(
        id: UUID(uuidString: stableID(for: fixture.key))!,
        name: fixture.name,
        birthDate: fixture.birthDate,
        birthTime: fixture.birthTime,
        timezone: fixture.timezone,
        latitude: fixture.latitude,
        longitude: fixture.longitude,
        placeName: fixture.placeName,
        houseSystem: "Placidus",
        ascendant: AngularPoint(
            longitude: normalize(houses.asc),
            formatted: AstroEngine.degToSign(houses.asc)
        ),
        mc: AngularPoint(
            longitude: normalize(houses.mc),
            formatted: AstroEngine.degToSign(houses.mc)
        ),
        cusps: cusps,
        bodies: bodies,
        createdAt: Date(timeIntervalSince1970: 0)
    )
}

private func loadGoldenFile() throws -> PDGoldenFile {
    let decoder = JSONDecoder()
    if let resourceURL = Bundle.module.url(forResource: "PrimaryDirectionsGolden", withExtension: "json") {
        return try decoder.decode(PDGoldenFile.self, from: Data(contentsOf: resourceURL))
    }

    let fallbackURL = testsDirectoryURL().appendingPathComponent("PrimaryDirectionsGolden.json")
    return try decoder.decode(PDGoldenFile.self, from: Data(contentsOf: fallbackURL))
}

private func testsDirectoryURL() -> URL {
    URL(fileURLWithPath: #filePath).deletingLastPathComponent()
}

private func makeBirthDate(_ birthDate: String) throws -> Date {
    let parts = birthDate.split(separator: "-").compactMap { Int($0) }
    guard parts.count == 3 else { throw JulianDayError.invalidDate(birthDate) }
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = TimeZone(secondsFromGMT: 0)!
    return calendar.date(from: DateComponents(year: parts[0], month: parts[1], day: parts[2]))!
}

private func stableID(for key: String) -> String {
    switch key {
    case "eduardo": return "11111111-1111-1111-1111-111111111111"
    case "buenosAires": return "22222222-2222-2222-2222-222222222222"
    case "reykjavik": return "33333333-3333-3333-3333-333333333333"
    default: return "99999999-9999-9999-9999-999999999999"
    }
}

private func normalize(_ value: Double) -> Double {
    var result = value.truncatingRemainder(dividingBy: 360)
    if result < 0 { result += 360 }
    return result
}

private func rounded(_ value: Double, scale: Double) -> Double {
    let multiplier = pow(10, scale)
    return (value * multiplier).rounded() / multiplier
}

private func format(_ value: Double) -> String {
    String(format: "%.4f", value)
}
