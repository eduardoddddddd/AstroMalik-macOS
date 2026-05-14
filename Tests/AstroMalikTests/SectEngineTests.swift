import XCTest
@testable import AstroMalik

final class SectEngineTests: XCTestCase {
    override func setUp() {
        super.setUp()
        AstroEngine.configure(ephePath: nil)
    }

    func testReferenceChartIsNocturnal() throws {
        let chart = try sectReferenceChart()
        let sun = try XCTUnwrap(chart.bodies.first { $0.key == "SOL" })

        let sect = SectEngine.sect(of: chart)

        XCTAssertEqual(sun.house, 5)
        XCTAssertFalse(sect.isDiurnal)
        XCTAssertEqual(sect.luminary, .luna)
        XCTAssertEqual(sect.benefic, .venus)
        XCTAssertEqual(sect.malefic, .marte)
        XCTAssertEqual(sect.contrarySectBenefic, .jupiter)
        XCTAssertEqual(sect.contrarySectMalefic, .saturno)
    }

    func testDayChartUsesSolarSect() {
        let chart = NatalChart(
            name: "Diurna artificial",
            birthDate: "2000-01-01",
            birthTime: "12:00",
            timezone: "UTC",
            latitude: 0,
            longitude: 0,
            placeName: "Test",
            ascendant: AngularPoint(longitude: 0, formatted: AstroEngine.degToSign(0)),
            mc: AngularPoint(longitude: 270, formatted: AstroEngine.degToSign(270)),
            cusps: [0, 30, 60, 90, 120, 150, 180, 210, 240, 270, 300, 330],
            bodies: [
                PlanetBody(
                    key: "SOL",
                    label: "☉ Sol",
                    longitude: 220,
                    formatted: AstroEngine.degToSign(220),
                    house: 8,
                    retrograde: false
                ),
            ]
        )

        let sect = SectEngine.sect(of: chart)

        XCTAssertTrue(sect.isDiurnal)
        XCTAssertEqual(sect.luminary, .sol)
        XCTAssertEqual(sect.benefic, .jupiter)
        XCTAssertEqual(sect.malefic, .saturno)
        XCTAssertEqual(sect.contrarySectBenefic, .venus)
        XCTAssertEqual(sect.contrarySectMalefic, .marte)
    }
}

private func sectReferenceChart() throws -> NatalChart {
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
    chart.bodies = chart.bodies.map { body in
        guard body.key == "SOL" else { return body }
        var corrected = body
        corrected.house = 5
        return corrected
    }
    return chart
}
