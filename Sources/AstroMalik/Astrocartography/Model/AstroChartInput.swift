import Foundation

struct AstroChartInput: Equatable, Sendable {
    let id: UUID
    let date: String
    let time: String
    let timezone: String
    let fingerprint: String
    let name: String
    let placeName: String
    let houseSystem: String
    let natalBodies: [AstroNatalBody]
    let natalCusps: [Double]
    let natalAsc: Double
    let natalMC: Double

    init(_ chart: NatalChart) {
        id = chart.id; date = chart.birthDate; time = chart.birthTime; timezone = chart.timezone
        fingerprint = (try? AstroNatalFingerprint.make(chart)) ?? ""
        name = chart.name; placeName = chart.placeName
        houseSystem = chart.houseSystem
        natalBodies = chart.bodies.compactMap { p in AstroBody(rawValue: p.key).map { AstroNatalBody(body: $0, longitudeDegrees: p.longitude) } }
        natalCusps = chart.cusps; natalAsc = chart.ascendant.longitude; natalMC = chart.mc.longitude
    }
    var exportChart: AstroExportDocument.Chart {
        AstroExportDocument.Chart(id: id, name: name, birthDate: date, birthTime: time, timezone: timezone, placeName: placeName,
                                  houseSystem: houseSystem, natalAscendantDegrees: natalAsc, natalMCDegrees: natalMC,
                                  natalCuspsDegrees: natalCusps)
    }
    func relocationSource(instant: AstroNatalInstant) throws -> AstroRelocationSource {
        try AstroRelocationSource(natalChartID: id, instant: instant, houseSystem: houseSystem, bodies: natalBodies)
    }
    func request() throws -> AstrocartographyRequest {
        let jd = try julianDayFromLocal(birthDate: date, birthTime: time, timezoneName: timezone).jd
        return try AstrocartographyRequest(instant: AstroNatalInstant(julianDay: jd),
                                           geometryToleranceKm: AstroMercatorGeometry.coreBudgetKm)
    }
}

