import Foundation

enum SectEngine {
    static func sect(of chart: Chart) -> SectInfo {
        let sunHouse = chart.bodies.first(where: { $0.key == AstroPlanetKey.sol.key })?.house
        let isDiurnal = sunHouse.map { (7...12).contains($0) }
            ?? isBodyAboveHorizon(longitude: chart.bodies.first(where: { $0.key == AstroPlanetKey.sol.key })?.longitude, cusps: chart.cusps)

        if isDiurnal {
            return SectInfo(
                isDiurnal: true,
                luminary: .sol,
                benefic: .jupiter,
                malefic: .saturno,
                contrarySectBenefic: .venus,
                contrarySectMalefic: .marte
            )
        }
        return SectInfo(
            isDiurnal: false,
            luminary: .luna,
            benefic: .venus,
            malefic: .marte,
            contrarySectBenefic: .jupiter,
            contrarySectMalefic: .saturno
        )
    }

    private static func isBodyAboveHorizon(longitude: Double?, cusps: [Double]) -> Bool {
        guard let longitude, cusps.count >= 12 else { return false }
        let house = AstroEngine.planetHouse(deg: longitude, cusps: cusps)
        return (7...12).contains(house)
    }
}
