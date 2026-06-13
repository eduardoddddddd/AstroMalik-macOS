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
