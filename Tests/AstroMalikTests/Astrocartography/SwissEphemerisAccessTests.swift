import Foundation
import XCTest
import CSwissEph
#if canImport(AstroMalikCore)
@testable import AstroMalikCore
#else
@testable import AstroMalik
#endif

final class SwissEphemerisAccessTests: XCTestCase {
    func testRecursiveTransactionAndReleaseAfterThrow() throws {
        enum Expected: Error { case failure }
        let jd = SwissEphemerisAccess.transaction {
            SwissEphemerisAccess.transaction {
                SwissEphemerisAccess.swe_julday(2000, 1, 1, 12, SE_GREG_CAL)
            }
        }
        XCTAssertEqual(jd, 2_451_545, accuracy: 1e-10)
        XCTAssertThrowsError(try SwissEphemerisAccess.transaction { throw Expected.failure })
        let released = expectation(description: "another thread can enter after throw")
        DispatchQueue.global().async {
            SwissEphemerisAccess.transaction { released.fulfill() }
        }
        wait(for: [released], timeout: 5)
    }

    func testCriticalSectionsNeverOverlap() {
        let probe = AccessProbe()
        DispatchQueue.concurrentPerform(iterations: 100) { _ in
            SwissEphemerisAccess.transaction {
                probe.enter()
                Thread.sleep(forTimeInterval: 0.0001)
                _ = SwissEphemerisAccess.swe_sidtime(2_451_545)
                probe.leave()
            }
        }
        XCTAssertEqual(probe.maximumActive, 1)
        XCTAssertEqual(probe.completed, 100)
    }

    func testConcurrentNatalLikeAndEquatorialCallsMatchSerialBaseline() {
        // Configuration+calculation is one atomic transaction. No personal charts.
        let dates = (0..<24).map { 2_451_545.0 + Double($0 * 157) }
        let baseline = dates.map(sample)
        let probe = AccessProbe()
        DispatchQueue.concurrentPerform(iterations: 120) { index in
            let dateIndex = index % dates.count
            if sample(dates[dateIndex]) != baseline[dateIndex] { probe.recordMismatch() }
        }
        XCTAssertEqual(probe.mismatches, 0)
        XCTAssertTrue(baseline.allSatisfy { $0.count == 9 && $0.allSatisfy(\.isFinite) })
    }

    func testLibraryVersionIsReportedThroughFacade() {
        var buffer = [CChar](repeating: 0, count: 64)
        _ = SwissEphemerisAccess.swe_version(&buffer)
        XCTAssertEqual(String(cString: buffer), "2.10.03")
    }

    func testContractDateBoundsMatchGregorianConversion() {
        XCTAssertEqual(SwissEphemerisAccess.swe_julday(1800, 1, 1, 0, SE_GREG_CAL), 2_378_496.5)
        XCTAssertEqual(SwissEphemerisAccess.swe_julday(3000, 1, 1, 0, SE_GREG_CAL), 2_816_787.5)
    }

    private func sample(_ jd: Double) -> [Double] {
        SwissEphemerisAccess.transaction {
            AstroEngine.configure(ephePath: nil)
            var natal = [Double](repeating: 0, count: 6)
            var equatorial = natal
            var error = [CChar](repeating: 0, count: 256)
            let natalFlags = SwissEphemerisAccess.swe_calc_ut(jd, SE_MOON, SEFLG_SPEED, &natal, &error)
            let equatorialFlags = SwissEphemerisAccess.swe_calc_ut(jd, SE_MOON, SEFLG_SPEED | SEFLG_EQUATORIAL, &equatorial, &error)
            let sidereal = SwissEphemerisAccess.swe_sidtime(jd)
            // Distinct pre-existing consumers also enter the common boundary.
            let houses = try? AstroEngine.calcHouses(jd: jd, lat: 40, lon: -3)
            guard natalFlags >= 0, equatorialFlags >= 0, let houses else { return [] }
            return [natal[0], equatorial[0], equatorial[1], sidereal,
                    houses.asc, houses.mc, houses.cusps[0], Double(natalFlags), Double(equatorialFlags)]
        }
    }
}

/// Test-only mutable probe. Its own lock makes failure detection race-free even
/// if the production lock regresses. Never export this type to production.
private final class AccessProbe: @unchecked Sendable {
    private let lock = NSLock()
    private var active = 0
    private(set) var maximumActive = 0
    private(set) var completed = 0
    private(set) var mismatches = 0

    func enter() {
        lock.lock(); defer { lock.unlock() }
        active += 1
        maximumActive = max(maximumActive, active)
    }
    func leave() {
        lock.lock(); defer { lock.unlock() }
        active -= 1
        completed += 1
    }
    func recordMismatch() {
        lock.lock(); defer { lock.unlock() }
        mismatches += 1
    }
}
