import XCTest
@testable import AstroMalik

// MARK: - Sanity Check
// Carta de referencia: 1976-10-11 20:33 Europe/Madrid
// Resultado esperado: Saturno en Casa 4, ASC Géminis ~0°

final class AstroEngineTests: XCTestCase {

    override func setUp() {
        super.setUp()
        AstroEngine.configure(ephePath: nil)
    }

    func testJulianDayReference() throws {
        // 1976-10-11 20:33 Madrid → should be around JD 2443068
        let result = try julianDayFromLocal(
            birthDate: "1976-10-11",
            birthTime: "20:33",
            timezoneName: "Europe/Madrid"
        )
        // JD for 1976-10-11 ~19:33 UTC ≈ 2443063.3
        XCTAssertEqual(result.jd, 2443063.3, accuracy: 0.5, "Julian Day fuera de rango esperado")
        XCTAssertEqual(result.timezoneIANA, "Europe/Madrid")
    }

    func testNatalChartReference() throws {
        // Carta de referencia del CONTEXT.md
        let jdResult = try julianDayFromLocal(
            birthDate: "1976-10-11",
            birthTime: "20:33",
            timezoneName: "Europe/Madrid"
        )
        let chart = try AstroEngine.computeNatalChart(
            jd: jdResult.jd,
            lat: 40.4168,  // Madrid
            lon: -3.7038
        )

        // ASC debe ser Géminis (~0°), signIndex = 2
        let ascSignIdx = Int(chart.ascendant.longitude / 30)
        XCTAssertEqual(ascSignIdx, 2, "ASC debe ser Géminis (sign index 2), fue \(SIGN_LABELS[ascSignIdx])")

        // Saturno debe estar en Casa 4
        let saturno = chart.bodies.first { $0.key == "SATURNO" }
        XCTAssertNotNil(saturno, "Saturno no encontrado en la carta")
        XCTAssertEqual(saturno?.house, 4, "Saturno debe estar en Casa 4, está en Casa \(saturno?.house ?? -1)")

        print("✅ ASC: \(chart.ascendant.formatted)")
        print("✅ MC:  \(chart.mc.formatted)")
        for body in chart.bodies {
            let retro = body.retrograde ? " ℞" : ""
            print("  \(body.label)\(retro) → \(body.formatted) Casa \(body.house)")
        }
    }

    func testNatalAspects() throws {
        let jdResult = try julianDayFromLocal(
            birthDate: "1976-10-11",
            birthTime: "20:33",
            timezoneName: "Europe/Madrid"
        )
        let chart = try AstroEngine.computeNatalChart(
            jd: jdResult.jd, lat: 40.4168, lon: -3.7038
        )
        let rawPlanets = Dictionary(uniqueKeysWithValues: chart.bodies.map { b in
            (b.key, AstroEngine.RawPlanet(
                key: b.key, label: b.label,
                deg: b.longitude, speed: b.retrograde ? -1 : 1, retro: b.retrograde
            ))
        })
        let aspects = AstroEngine.computeNatalAspects(planets: rawPlanets)
        XCTAssertFalse(aspects.isEmpty, "Debe haber aspectos natales")
        print("✅ Aspectos natales encontrados: \(aspects.count)")
        for a in aspects.prefix(5) {
            print("  \(a.labelA) \(a.aspLabel) \(a.labelB) (orbe \(a.orb)°)")
        }
    }

    func testDegToSign() {
        XCTAssertTrue(AstroEngine.degToSign(0).contains("Aries"))
        XCTAssertTrue(AstroEngine.degToSign(30).contains("Tauro"))
        XCTAssertTrue(AstroEngine.degToSign(60).contains("Géminis"))
        XCTAssertTrue(AstroEngine.degToSign(359).contains("Piscis"))
        XCTAssertEqual(AstroEngine.degToSignKey(45), "TAURO")
    }

    func testScoreCalculation() {
        // Saturno conjunción Sol debe tener score alto (≥ 25 → 5 estrellas)
        // score = SATURNO(7) × CONJUNCION(5) × orb_factor(~1) = ~35
        // Con orb 0: factor = 1.0, score = 7*5*(0.5+0.5*1) = 35
        // Debería ser 5 estrellas
        let score = buildScoreForTest(transitKey: "SATURNO", aspectKey: "CONJUNCION", minOrb: 0.1)
        XCTAssertGreaterThanOrEqual(score, 25.0, "Saturno conjunción debe ser 5★")
    }
}

// Helper para test de score
private func buildScoreForTest(transitKey: String, aspectKey: String, minOrb: Double) -> Double {
    let planetWeights: [String: Double] = [
        "PLUTON": 10, "NEPTUNO": 9, "URANO": 8, "SATURNO": 7, "JUPITER": 6,
        "MARTE": 4, "VENUS": 2, "MERCURIO": 2, "SOL": 2, "LUNA": 1,
    ]
    let aspectWeights: [String: Double] = [
        "CONJUNCION": 5, "OPOSICION": 4.5, "CUADRADO": 4, "TRIGONO": 3, "SEXTIL": 2,
    ]
    let aspectOrbs: [String: Double] = [
        "CONJUNCION": 8, "OPOSICION": 8, "CUADRADO": 7, "TRIGONO": 7, "SEXTIL": 5,
    ]
    let pw = planetWeights[transitKey] ?? 1
    let aw = aspectWeights[aspectKey] ?? 1
    let maxOrb = aspectOrbs[aspectKey] ?? 6
    let orbFactor = maxOrb > 0 ? max(0, 1 - minOrb / maxOrb) : 0.5
    return (pw * aw * (0.5 + 0.5 * orbFactor) * 10).rounded() / 10
}
