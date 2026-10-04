// Copy only into Tests/AstroMalikTests of an isolated Mac baseline checkout.
// Does not change production sources or fabricate results; records C flags.
import XCTest
@testable import AstroMalik
import CSwissEph
import Foundation

final class F2BackendProbe: XCTestCase {
    func testExportConfiguredCLIBackend() throws {
        guard let output = ProcessInfo.processInfo.environment["F2_BACKEND_PROBE"] else {
            throw XCTSkip("Explicit destination required")
        }
        guard let ephe = AppResources.bundle.url(forResource: "sepl_18", withExtension: "se1", subdirectory: "ephe") else {
            XCTFail("Original CLI bundled Swiss ephemeris missing")
            return
        }
        AstroEngine.configure(ephePath: ephe.deletingLastPathComponent().path)
        let dates = [
            ("eduardo", "1976-10-11", "20:33", "Europe/Madrid"),
            ("buenosAires", "1985-03-15", "14:00", "America/Argentina/Buenos_Aires"),
            ("reykjavik", "1990-01-01", "06:30", "Atlantic/Reykjavik"),
            ("madrid-war1940-control", "1940-07-15", "12:00:00", "Europe/Madrid"),
            ("reference", "2026-10-04", "00:00:00", "UTC")
        ]
        var probes: [[String: Any]] = []
        var version = [CChar](repeating: 0, count: 256)
        _ = SwissEphemerisAccess.swe_version(&version)
        for (id, date, time, zone) in dates {
            let jd = try julianDayFromLocal(birthDate: date, birthTime: time, timezoneName: zone).jd
            for body in [SE_SUN, SE_MOON, SE_PLUTO] {
                var values = [Double](repeating: 0, count: 6)
                var diagnostic = [CChar](repeating: 0, count: 256)
                let flags = SwissEphemerisAccess.swe_calc_ut(jd, body, SEFLG_SPEED, &values, &diagnostic)
                let backend = (flags & SEFLG_MOSEPH) != 0 ? "moshier" : ((flags & SEFLG_SWIEPH) != 0 ? "swiss-files" : "other")
                probes.append(["id": id, "body": Int(body), "julianDay": jd, "returnedFlags": Int(flags), "backend": backend,
                               "diagnostic": String(cString: diagnostic), "longitude": values[0]])
                XCTAssertGreaterThanOrEqual(flags, 0)
                XCTAssertEqual(backend, "swiss-files", "CLI would silently use another backend")
            }
        }
        let document: [String: Any] = ["kind": "observed-original-cli-backend", "platform": "macOS",
                                      "swissVersion": String(cString: version), "tzdataVersion": TimeZone.timeZoneDataVersion,
                                      "configuredResource": ephe.lastPathComponent, "probes": probes]
        let data = try JSONSerialization.data(withJSONObject: document, options: [.prettyPrinted, .sortedKeys])
        try data.write(to: URL(fileURLWithPath: output))
    }
}
