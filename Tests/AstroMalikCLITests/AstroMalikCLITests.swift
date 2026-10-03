import XCTest
import AstroMalik
@testable import astromalik_cli

final class AstroMalikCLITests: XCTestCase {
    private let defaultDate = Date(timeIntervalSince1970: 1_700_000_000)
    private var calendar: Calendar {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(secondsFromGMT: 0)!
        return cal
    }

    func testParserHandlesNatalSubcommandAndGlobalDefaults() throws {
        let command = try AstroMalikCLIParser.parse(
            arguments: ["natal", "--chart", "Edu", "--format", "markdown", "--user-db", "/tmp/user.db", "--verbose"],
            defaultDate: defaultDate,
            calendar: calendar
        )

        guard case .run(let options) = command else { return XCTFail("Expected run command") }
        XCTAssertEqual(options.command, .natal)
        XCTAssertEqual(options.chartQuery, "Edu")
        XCTAssertEqual(options.format, .markdown)
        XCTAssertEqual(options.output, .stdout)
        XCTAssertEqual(options.narrative, .none)
        XCTAssertFalse(options.allowNetwork)
        XCTAssertEqual(options.userDBPath, "/tmp/user.db")
        XCTAssertTrue(options.verbose)
    }


    func testGlobalFlagsCanPrecedeSubcommand() throws {
        let command = try AstroMalikCLIParser.parse(
            arguments: ["--format", "markdown", "natal", "--chart", "Edu"],
            defaultDate: defaultDate,
            calendar: calendar
        )
        guard case .run(let options) = command else { return XCTFail("Expected run command") }
        XCTAssertEqual(options.command, .natal)
        XCTAssertEqual(options.format, .markdown)
        XCTAssertEqual(options.chartQuery, "Edu")
    }

    func testParserHandlesTransitsRange() throws {
        let command = try AstroMalikCLIParser.parse(
            arguments: ["transits", "--chart", "Edu", "--from", "2026-06-15", "--to", "2026-06-21"],
            defaultDate: defaultDate,
            calendar: calendar
        )

        guard case .run(let options) = command else { return XCTFail("Expected run command") }
        XCTAssertEqual(options.command, .transits)
        XCTAssertEqual(options.fromDate, calendar.date(from: DateComponents(timeZone: calendar.timeZone, year: 2026, month: 6, day: 15)))
        XCTAssertEqual(options.toDate, calendar.date(from: DateComponents(timeZone: calendar.timeZone, year: 2026, month: 6, day: 21)))
    }

    func testLegacyCommandDefaultsToCrossPersonalWithoutNetworkOrNarrative() throws {
        let command = try AstroMalikCLIParser.parse(arguments: ["--chart", "Edu"], defaultDate: defaultDate, calendar: calendar)
        guard case .run(let options) = command else { return XCTFail("Expected run command") }
        XCTAssertEqual(options.command, .crossPersonal)
        XCTAssertEqual(options.format, .json)
        XCTAssertEqual(options.output, .stdout)
        XCTAssertEqual(options.narrative, .none)
        XCTAssertFalse(options.allowNetwork)
    }

    func testCrossPersonalNarrativeNoneDoesNotRequireNetwork() throws {
        let command = try AstroMalikCLIParser.parse(
            arguments: ["cross-personal", "--chart", "Edu", "--date", "2026-06-13", "--scope", "weekly", "--narrative", "none"],
            defaultDate: defaultDate,
            calendar: calendar
        )
        guard case .run(let options) = command else { return XCTFail("Expected run command") }
        XCTAssertEqual(options.command, .crossPersonal)
        XCTAssertEqual(options.narrative, .none)
        XCTAssertFalse(options.allowNetwork)
    }

    func testAnthropicNarrativeWithoutAllowNetworkFails() {
        XCTAssertThrowsError(try AstroMalikCLIParser.parse(
            arguments: ["cross-personal", "--chart", "Edu", "--narrative", "anthropic"],
            defaultDate: defaultDate,
            calendar: calendar
        )) { error in
            XCTAssertEqual(error as? CLIParseError, .networkDenied("La narrativa Anthropic requiere --allow-network y --narrative anthropic explícitos."))
        }
    }

    func testOutputDestinationParsing() throws {
        XCTAssertEqual(try AstroMalikCLIParser.parseOutput("stdout"), .stdout)
        XCTAssertEqual(try AstroMalikCLIParser.parseOutput("file:/tmp/report.md"), .file("/tmp/report.md"))
        XCTAssertEqual(try AstroMalikCLIParser.parseOutput("joplin:AstroMalik"), .joplin("AstroMalik"))
    }

    func testChartsListWorksAgainstUserDBAndJSONReportsNoNetwork() async throws {
        let dbURL = try makeUserDBWithOneChart()
        let result = try await AstroMalikCLIRunner.run(request: AstroMalikCLIRequest(
            command: .chartsList,
            referenceDate: defaultDate,
            format: .json,
            output: .stdout,
            userDBPath: dbURL.path,
            allowNetwork: false,
            narrative: .none
        ))

        XCTAssertFalse(result.networkUsed)
        XCTAssertEqual(result.format, "json")
        let data = try XCTUnwrap(result.content.data(using: .utf8))
        let object = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        XCTAssertEqual(object?["networkUsed"] as? Bool, false)
        XCTAssertEqual(object?["source"] as? String, "local")
        let technical = try XCTUnwrap(object?["technicalData"] as? [String: Any])
        let charts = try XCTUnwrap(technical["charts"] as? [[String: Any]])
        XCTAssertEqual(charts.count, 1)
        XCTAssertEqual(charts.first?["name"] as? String, "Edu")
    }


    // MARK: astrocartography (F6.4)

    func testAstrocartographyParserAcceptsPlaceOrCoordinatesAndRejectsMisuse() throws {
        func parse(_ args: [String]) throws -> CLIOptions {
            guard case .run(let options) = try AstroMalikCLIParser.parse(arguments: args, defaultDate: defaultDate, calendar: calendar) else {
                throw CLIParseError.invalidCommand("expected run")
            }
            return options
        }
        let byPlace = try parse(["astrocartography", "--chart", "Edu", "--place", "Madrid", "--near-km", "50", "--regional-km", "400", "--no-readings", "--format", "markdown"])
        XCTAssertEqual(byPlace.command, .astrocartography)
        XCTAssertEqual(byPlace.placeQuery, "Madrid"); XCTAssertEqual(byPlace.nearKm, 50); XCTAssertEqual(byPlace.regionalKm, 400)
        XCTAssertFalse(byPlace.includeReadings); XCTAssertEqual(byPlace.format, .markdown); XCTAssertFalse(byPlace.allowNetwork)
        let byCoords = try parse(["--lat", "40,4168", "astrocartography", "--chart", "Edu", "--lon", "-3.7"])
        XCTAssertEqual(byCoords.latitude, 40.4168); XCTAssertEqual(byCoords.longitude, -3.7); XCTAssertTrue(byCoords.includeReadings)
        let bare = try parse(["astrocartography", "--chart", "Edu"])
        XCTAssertNil(bare.placeQuery); XCTAssertNil(bare.latitude); XCTAssertEqual(bare.format, .json)

        XCTAssertThrowsError(try parse(["astrocartography"])) { XCTAssertEqual($0 as? CLIParseError, .missingChart) }
        XCTAssertThrowsError(try parse(["astrocartography", "--chart", "Edu", "--lat", "40"])) // lon missing
        XCTAssertThrowsError(try parse(["astrocartography", "--chart", "Edu", "--lat", "40", "--lon", "-3", "--place", "Madrid"]))
        XCTAssertThrowsError(try parse(["astrocartography", "--chart", "Edu", "--lat", "91", "--lon", "0"])) { XCTAssertEqual($0 as? CLIParseError, .invalidNumber("--lat", "91")) }
        XCTAssertThrowsError(try parse(["astrocartography", "--chart", "Edu", "--lat", "0", "--lon", "181"]))
        XCTAssertThrowsError(try parse(["astrocartography", "--chart", "Edu", "--lat", "x", "--lon", "0"]))
        XCTAssertThrowsError(try parse(["astrocartography", "--chart", "Edu", "--near-km", "300", "--regional-km", "300"]))
        XCTAssertThrowsError(try parse(["astrocartography", "--chart", "Edu", "--regional-km", "50"])) // default near is 100
        XCTAssertThrowsError(try parse(["natal", "--chart", "Edu", "--place", "Madrid"])) // only for astrocartography
    }

    func testAstrocartographyJSONIsVersionedDeterministicOfflineAndComplete() async throws {
        let dbURL = try makeUserDBWithOneChart()
        func run(_ build: (inout AstroMalikCLIRequest) -> Void) async throws -> AstroMalikCLIResult {
            var request = AstroMalikCLIRequest(command: .astrocartography, chartQuery: "Edu", referenceDate: defaultDate, format: .json,
                                               output: .stdout, userDBPath: dbURL.path, allowNetwork: false)
            build(&request)
            return try await AstroMalikCLIRunner.run(request: request)
        }
        let first = try await run { $0.latitude = 40.4168; $0.longitude = -3.7038 }
        let second = try await run { $0.latitude = 40.4168; $0.longitude = -3.7038 }
        XCTAssertEqual(first.content, second.content, "same input → byte-identical output")
        XCTAssertFalse(first.networkUsed); XCTAssertEqual(first.model, "local"); XCTAssertEqual(first.estimatedCostUSD, 0)
        XCTAssertFalse(first.content.lowercased().contains("generatedat"))
        let object = try XCTUnwrap(JSONSerialization.jsonObject(with: Data(first.content.utf8)) as? [String: Any])
        XCTAssertEqual(object["schemaVersion"] as? Int, 1)
        XCTAssertEqual(object["kind"] as? String, "astromalik.astrocartography")
        XCTAssertEqual((object["chartLines"] as? [[String: Any]])?.count, 40)
        let place = try XCTUnwrap(object["place"] as? [String: Any])
        XCTAssertEqual((place["lines"] as? [[String: Any]])?.count, 40)
        XCTAssertNotNil(place["headline"])
        XCTAssertEqual((place["lines"] as? [[String: Any]])?.compactMap { $0["distanceKm"] as? Double }.sorted(), (place["lines"] as? [[String: Any]])?.compactMap { $0["distanceKm"] as? Double })
        // The sample chart has only two bodies: the relocation is reported as unavailable, never faked.
        XCTAssertNil(place["relocation"]); XCTAssertNotNil(place["relocationError"])
        let method = try XCTUnwrap(object["method"] as? [String: Any])
        XCTAssertEqual(method["ephemerisSource"] as? String, "swissEphemeris")
        XCTAssertEqual(method["sphereRadiusKm"] as? Double, 6371.0088)

        let bare = try await run { _ in }
        let bareObject = try XCTUnwrap(JSONSerialization.jsonObject(with: Data(bare.content.utf8)) as? [String: Any])
        XCTAssertNil(bareObject["place"]); XCTAssertEqual((bareObject["chartLines"] as? [[String: Any]])?.count, 40)

        let byName = try await run { $0.placeQuery = "Madrid" }
        let named = try XCTUnwrap((try XCTUnwrap(JSONSerialization.jsonObject(with: Data(byName.content.utf8)) as? [String: Any]))["place"] as? [String: Any])
        XCTAssertTrue((named["name"] as? String ?? "").contains("Madrid")); XCTAssertEqual(named["origin"] as? String, "localCatalog")

        let noReadings = try await run { $0.latitude = 10; $0.longitude = 10; $0.includeReadings = false; $0.nearKm = 5000; $0.regionalKm = 9000 }
        let nr = try XCTUnwrap((try XCTUnwrap(JSONSerialization.jsonObject(with: Data(noReadings.content.utf8)) as? [String: Any]))["place"] as? [String: Any])
        XCTAssertEqual((nr["readings"] as? [Any])?.count, 0)
        let withReadings = try await run { $0.latitude = 10; $0.longitude = 10; $0.nearKm = 5000; $0.regionalKm = 9000 }
        let wr = try XCTUnwrap((try XCTUnwrap(JSONSerialization.jsonObject(with: Data(withReadings.content.utf8)) as? [String: Any]))["place"] as? [String: Any])
        XCTAssertGreaterThan((wr["readings"] as? [Any])?.count ?? 0, 0)

        let markdown = try await run { $0.format = .markdown; $0.latitude = 40; $0.longitude = -3 }
        XCTAssertTrue(markdown.content.hasPrefix("# Astrocartografía — Edu"))
    }

    func testAstrocartographyRejectsUnknownPlaceAndConflictingInputWithoutNetwork() async throws {
        let dbURL = try makeUserDBWithOneChart()
        func request(_ build: (inout AstroMalikCLIRequest) -> Void) -> AstroMalikCLIRequest {
            var r = AstroMalikCLIRequest(command: .astrocartography, chartQuery: "Edu", referenceDate: defaultDate, userDBPath: dbURL.path)
            build(&r); return r
        }
        do { _ = try await AstroMalikCLIRunner.run(request: request { $0.placeQuery = "CiudadQueNoExisteZZZ" }); XCTFail("unknown place") }
        catch let error as AstroMalikCLIRunnerError { XCTAssertTrue(error.localizedDescription.contains("no encontrado")); XCTAssertEqual(error.exitCode, 1) }
        do { _ = try await AstroMalikCLIRunner.run(request: request { $0.placeQuery = "Madrid"; $0.latitude = 1; $0.longitude = 1 }); XCTFail("conflict") }
        catch let error as AstroMalikCLIRunnerError { XCTAssertEqual(error.exitCode, 1) }
        do { _ = try await AstroMalikCLIRunner.run(request: request { $0.nearKm = 500; $0.regionalKm = 100 }); XCTFail("thresholds") }
        catch let error as AstroMalikCLIRunnerError { XCTAssertTrue(error.localizedDescription.contains("Umbrales")) }
        do { _ = try await AstroMalikCLIRunner.run(request: request { $0.output = .joplin("codex") }); XCTFail("Joplin needs --allow-network") }
        catch let error as AstroMalikCLIRunnerError { XCTAssertEqual(error.exitCode, 6) }
    }

    private func makeUserDBWithOneChart() throws -> URL {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let dbURL = dir.appendingPathComponent("user.db")
        let chartID = "11111111-1111-1111-1111-111111111111"
        let chartJSON = """
        {"id":"\(chartID)","name":"Edu","birthDate":"1990-01-01","birthTime":"12:00","timezone":"UTC","latitude":40.0,"longitude":-3.0,"placeName":"Madrid","houseSystem":"Placidus","ascendant":{"longitude":0.0,"formatted":"♈ Aries 00°00'"},"mc":{"longitude":270.0,"formatted":"♑ Capricornio 00°00'"},"cusps":[0,30,60,90,120,150,180,210,240,270,300,330],"bodies":[{"key":"SOL","label":"☉ Sol","longitude":280.0,"formatted":"♑ Capricornio 10°00'","house":10,"retrograde":false},{"key":"LUNA","label":"☽ Luna","longitude":45.0,"formatted":"♉ Tauro 15°00'","house":2,"retrograde":false}],"createdAt":0}
        """
        let escapedJSON = chartJSON.replacingOccurrences(of: "'", with: "''")
        let sql = """
        CREATE TABLE saved_charts (id TEXT PRIMARY KEY, name TEXT NOT NULL, birth_date TEXT NOT NULL, birth_time TEXT NOT NULL, timezone TEXT NOT NULL, latitude REAL NOT NULL, longitude REAL NOT NULL, place_name TEXT NOT NULL DEFAULT '', chart_json TEXT NOT NULL, notes TEXT NOT NULL DEFAULT '', tags TEXT NOT NULL DEFAULT '', created_at REAL NOT NULL);
        INSERT INTO saved_charts (id, name, birth_date, birth_time, timezone, latitude, longitude, place_name, chart_json, notes, tags, created_at) VALUES ('\(chartID)', 'Edu', '1990-01-01', '12:00', 'UTC', 40.0, -3.0, 'Madrid', '\(escapedJSON)', '', '', 0);
        """
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/sqlite3")
        process.arguments = [dbURL.path, sql]
        try process.run()
        process.waitUntilExit()
        XCTAssertEqual(process.terminationStatus, 0)
        return dbURL
    }
}
