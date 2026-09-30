import XCTest
import CSwissEph
@testable import AstroMalik

final class SwissAstrocartographyEphemerisTests: XCTestCase {
    func testSnapshotMatchesPythonReferenceIncludingFallbackDiagnostics() throws {
        let reference = try loadReference()
        let provider = SwissAstrocartographyEphemeris(ephemerisDirectory: ephemerisDirectory())
        XCTAssertEqual(SwissAstrocartographyEphemeris.requestedFlags, reference.requestedFlags)
        XCTAssertEqual(reference.cases.count, 4)

        for sample in reference.cases {
            let instant = try AstroNatalInstant(julianDay: sample.julianDay)
            let request = try AstrocartographyRequest(instant: instant, bodies: AstroBody.allCases)
            let snapshot = try provider.snapshot(for: request)

            XCTAssertEqual(snapshot.provenance.source, .swissEphemeris)
            XCTAssertEqual(snapshot.provenance.libraryVersion, reference.swissVersion)
            XCTAssertEqual(snapshot.provenance.algorithmVersion, SwissAstrocartographyEphemeris.algorithmVersion)
            XCTAssertEqual(snapshot.greenwichSiderealDegrees, sample.greenwichSiderealDegrees, accuracy: 1e-8)
            XCTAssertEqual(snapshot.positions.map(\.body), AstroBody.allCases)
            XCTAssertEqual(fallbackBodies(in: snapshot), sample.fallbackBodies)

            for (position, expected) in zip(snapshot.positions, sample.positions) {
                XCTAssertEqual(position.body, expected.body)
                XCTAssertEqual(position.returnedFlags, expected.returnedFlags, expected.body.rawValue)
                XCTAssertEqual(position.rightAscensionDegrees, expected.rightAscensionDegrees, accuracy: 1e-8, expected.body.rawValue)
                XCTAssertEqual(position.declinationDegrees, expected.declinationDegrees, accuracy: 1e-8, expected.body.rawValue)
            }
        }
    }

    func testPartialRequestKeepsReturnedFlagsAndVisibleFallback() throws {
        let reference = try loadReference()
        let earliest = try XCTUnwrap(reference.cases.first)
        let provider = SwissAstrocartographyEphemeris(ephemerisDirectory: ephemerisDirectory())
        let instant = try AstroNatalInstant(julianDay: earliest.julianDay)
        let request = try AstrocartographyRequest(instant: instant, bodies: [.sun, .moon])
        let snapshot = try provider.snapshot(for: request)

        XCTAssertEqual(snapshot.positions.map(\.body), [.sun, .moon])
        XCTAssertEqual(snapshot.positions[0].returnedFlags, earliest.positions[0].returnedFlags)
        XCTAssertEqual(snapshot.positions[1].returnedFlags, earliest.positions[1].returnedFlags)
        XCTAssertEqual(fallbackBodies(in: snapshot), [.sun])
        XCTAssertFalse(earliest.fallbackBodies.contains(.moon))
    }

    func testMissingEphemerisDirectoryFailsBeforeCalculation() throws {
        let provider = SwissAstrocartographyEphemeris(ephemerisDirectory: "")
        let request = try sampleRequest()
        XCTAssertThrowsError(try provider.snapshot(for: request)) { error in
            guard case AstrocartographyError.ephemerisFailure = error else {
                return XCTFail("Se esperaba un fallo de efemérides, llegó \(error)")
            }
        }
    }

    private func fallbackBodies(in snapshot: EquatorialSnapshot) -> [AstroBody] {
        snapshot.provenance.diagnostics.compactMap { diagnostic in
            guard diagnostic.code == SwissAstrocartographyEphemeris.fallbackDiagnosticCode,
                  diagnostic.severity == .warning,
                  let name = diagnostic.message.split(separator: ":").first else { return nil }
            return AstroBody(rawValue: String(name))
        }
    }

    private func sampleRequest() throws -> AstrocartographyRequest {
        try AstrocartographyRequest(instant: try AstroNatalInstant(julianDay: 2_451_545))
    }

    private func loadReference() throws -> Reference {
        let url = try XCTUnwrap(Bundle.module.url(forResource: "phase0-swiss-python-reference", withExtension: "json"))
        return try JSONDecoder().decode(Reference.self, from: Data(contentsOf: url))
    }

    private func ephemerisDirectory() -> String {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("Sources/AstroMalik/Resources/ephe")
            .path
    }

    private struct Reference: Decodable {
        let swissVersion: String
        let requestedFlags: Int32
        let cases: [Case]
    }

    private struct Case: Decodable {
        let julianDay: Double
        let greenwichSiderealDegrees: Double
        let positions: [AstroEquatorialPosition]
        let fallbackBodies: [AstroBody]
    }
}
