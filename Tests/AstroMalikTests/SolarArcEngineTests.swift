import XCTest
@testable import AstroMalik

final class SolarArcEngineTests: XCTestCase {
    override func setUp() {
        super.setUp()
        AstroEngine.configure(ephePath: nil)
    }

    func testNaibodSolarArcAtAge49() throws {
        let chart = try referenceChart()
        let engine = SolarArcEngine()

        let arc = try XCTUnwrap(engine.solarArcAmount(chart: chart, age: 49, mode: .naibod))
        let expected = 49.0 * (59.0 / 60.0 + 8.33 / 3600.0)

        XCTAssertEqual(arc, expected, accuracy: 0.01)
        XCTAssertEqual(arc, 48.27, accuracy: 0.05)
    }

    func testRealSolarArcAtAge49StaysNearNaibod() throws {
        let chart = try referenceChart()
        let engine = SolarArcEngine()

        let real = try XCTUnwrap(engine.solarArcAmount(chart: chart, age: 49, mode: .real))
        let naibod = try XCTUnwrap(engine.solarArcAmount(chart: chart, age: 49, mode: .naibod))

        // La carta de referencia nace en octubre, cuando el Sol real progresado
        // avanza algo más rápido que el arco medio Naibod; sigue estando en el
        // entorno de una diferencia menor a 1°.
        XCTAssertEqual(real, naibod, accuracy: 1.0)
        XCTAssertEqual(real, 49.12, accuracy: 0.1)
    }

    func testDetectsDirectedSunAspectToNatalAscendant() throws {
        let chart = try referenceChart()
        let engine = SolarArcEngine()

        let directions = engine.solarArc(
            chart: chart,
            from: 35,
            to: 50,
            mode: .naibod,
            orb: 1.0
        )

        let sunToAsc = directions.filter { direction in
            direction.directedPoint == "SOL" && direction.natalPoint == "ASC"
        }

        XCTAssertFalse(sunToAsc.isEmpty, "Debe detectar al menos un aspecto exacto del Sol dirigido al ASC natal entre 35 y 50 años")
        XCTAssertTrue(sunToAsc.contains { [PDaspect.trine, .opposition, .square, .sextile, .conjunction].contains($0.aspect) })
        XCTAssertTrue(sunToAsc.allSatisfy { (35...50).contains($0.exactAge) })
    }

    private func referenceChart() throws -> NatalChart {
        let jdResult = try julianDayFromLocal(
            birthDate: "1976-10-11",
            birthTime: "20:33",
            timezoneName: "Europe/Madrid"
        )
        var chart = try AstroEngine.computeNatalChart(
            jd: jdResult.jd,
            lat: 40.4168,
            lon: -3.7038
        )
        chart.name = "Referencia"
        chart.birthDate = "1976-10-11"
        chart.birthTime = "20:33"
        chart.timezone = "Europe/Madrid"
        chart.placeName = "Madrid"
        return chart
    }
}
