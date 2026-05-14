import XCTest
@testable import astromalik_cli

final class AstroMalikCLITests: XCTestCase {
    private let defaultDate = Date(timeIntervalSince1970: 1_700_000_000)
    private var calendar: Calendar {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(secondsFromGMT: 0)!
        return cal
    }

    func testParserHandlesAllFlags() throws {
        let command = try AstroMalikCLIParser.parse(
            arguments: [
                "--chart", "Edu",
                "--date", "2026-05-14",
                "--scope", "weekly",
                "--model", "opus",
                "--output", "joplin:AstroMalik",
                "--user-db", "/tmp/user.db",
                "--corpus-db", "/tmp/corpus.db",
                "--verbose"
            ],
            defaultDate: defaultDate,
            calendar: calendar
        )

        guard case .run(let options) = command else {
            return XCTFail("Expected run command")
        }
        XCTAssertEqual(options.chartQuery, "Edu")
        XCTAssertEqual(options.referenceDate, calendar.date(from: DateComponents(timeZone: calendar.timeZone, year: 2026, month: 5, day: 14)))
        XCTAssertEqual(options.scope, .weekly)
        XCTAssertEqual(options.model, .opus)
        XCTAssertEqual(options.output, .joplin("AstroMalik"))
        XCTAssertEqual(options.userDBPath, "/tmp/user.db")
        XCTAssertEqual(options.corpusDBPath, "/tmp/corpus.db")
        XCTAssertTrue(options.verbose)
    }

    func testParserFailsOnMissingChart() {
        XCTAssertThrowsError(try AstroMalikCLIParser.parse(arguments: ["--scope", "weekly"], defaultDate: defaultDate, calendar: calendar)) { error in
            XCTAssertEqual(error as? CLIParseError, .missingChart)
        }
    }

    func testParserFailsOnInvalidScope() {
        XCTAssertThrowsError(try AstroMalikCLIParser.parse(arguments: ["--chart", "Edu", "--scope", "foo"], defaultDate: defaultDate, calendar: calendar)) { error in
            XCTAssertEqual(error as? CLIParseError, .invalidScope("foo"))
        }
    }

    func testOutputDestinationParsing() throws {
        XCTAssertEqual(try AstroMalikCLIParser.parseOutput("stdout"), .stdout)
        XCTAssertEqual(try AstroMalikCLIParser.parseOutput("file:/tmp/report.md"), .file("/tmp/report.md"))
        XCTAssertEqual(try AstroMalikCLIParser.parseOutput("joplin:AstroMalik"), .joplin("AstroMalik"))
    }
}
