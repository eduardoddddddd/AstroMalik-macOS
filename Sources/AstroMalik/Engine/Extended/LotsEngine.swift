import Foundation

/// Motor de lotes helenísticos herméticos.
/// Fórmulas documentadas en sentido algebraico: `ASC + puntoB - puntoA`,
/// con inversión día/noche según la secta de la carta.
final class LotsEngine {
    func lots(chart: Chart) throws -> [NatalLot] {
        let sect = SectEngine.sect(of: chart)
        let sun = try ExtendedAstro.body("SOL", in: chart).longitude
        let moon = try ExtendedAstro.body("LUNA", in: chart).longitude
        let mercury = try ExtendedAstro.body("MERCURIO", in: chart).longitude
        let venus = try ExtendedAstro.body("VENUS", in: chart).longitude
        let mars = try ExtendedAstro.body("MARTE", in: chart).longitude
        let jupiter = try ExtendedAstro.body("JUPITER", in: chart).longitude
        let saturn = try ExtendedAstro.body("SATURNO", in: chart).longitude
        let asc = chart.ascendant.longitude

        // Fortuna: día ASC + Luna - Sol; noche ASC + Sol - Luna.
        let fortune = sect.isDiurnal
            ? ExtendedAstro.normalized(asc + moon - sun)
            : ExtendedAstro.normalized(asc + sun - moon)

        // Espíritu: día ASC + Sol - Luna; noche ASC + Luna - Sol.
        let spirit = sect.isDiurnal
            ? ExtendedAstro.normalized(asc + sun - moon)
            : ExtendedAstro.normalized(asc + moon - sun)

        // Eros (Venus): día ASC + Venus - Espíritu; noche ASC + Espíritu - Venus.
        let eros = sect.isDiurnal
            ? ExtendedAstro.normalized(asc + venus - spirit)
            : ExtendedAstro.normalized(asc + spirit - venus)

        // Necesidad (Mercurio): día ASC + Mercurio - Fortuna; noche ASC + Fortuna - Mercurio.
        let necessity = sect.isDiurnal
            ? ExtendedAstro.normalized(asc + mercury - fortune)
            : ExtendedAstro.normalized(asc + fortune - mercury)

        // Victoria (Júpiter): día ASC + Júpiter - Espíritu; noche ASC + Espíritu - Júpiter.
        let victory = sect.isDiurnal
            ? ExtendedAstro.normalized(asc + jupiter - spirit)
            : ExtendedAstro.normalized(asc + spirit - jupiter)

        // Audacia (Marte): día ASC + Marte - Fortuna; noche ASC + Fortuna - Marte.
        let audacity = sect.isDiurnal
            ? ExtendedAstro.normalized(asc + mars - fortune)
            : ExtendedAstro.normalized(asc + fortune - mars)

        // Némesis (Saturno): día ASC + Saturno - Fortuna; noche ASC + Fortuna - Saturno.
        let nemesis = sect.isDiurnal
            ? ExtendedAstro.normalized(asc + saturn - fortune)
            : ExtendedAstro.normalized(asc + fortune - saturn)

        return [
            makeLot(.fortune, longitude: fortune, chart: chart, formula: "Día: ASC + Luna - Sol. Noche: ASC + Sol - Luna."),
            makeLot(.spirit, longitude: spirit, chart: chart, formula: "Día: ASC + Sol - Luna. Noche: ASC + Luna - Sol."),
            makeLot(.eros, longitude: eros, chart: chart, formula: "Día: ASC + Venus - Espíritu. Noche: ASC + Espíritu - Venus."),
            makeLot(.necessity, longitude: necessity, chart: chart, formula: "Día: ASC + Mercurio - Fortuna. Noche: ASC + Fortuna - Mercurio."),
            makeLot(.victory, longitude: victory, chart: chart, formula: "Día: ASC + Júpiter - Espíritu. Noche: ASC + Espíritu - Júpiter."),
            makeLot(.audacity, longitude: audacity, chart: chart, formula: "Día: ASC + Marte - Fortuna. Noche: ASC + Fortuna - Marte."),
            makeLot(.nemesis, longitude: nemesis, chart: chart, formula: "Día: ASC + Saturno - Fortuna. Noche: ASC + Fortuna - Saturno."),
        ]
    }

    func lot(_ kind: NatalLotKind, chart: Chart) throws -> NatalLot {
        guard let found = try lots(chart: chart).first(where: { $0.kind == kind }) else {
            throw NatalExtendedError.missingBody(kind.rawValue)
        }
        return found
    }

    private func makeLot(
        _ kind: NatalLotKind,
        longitude rawLongitude: Double,
        chart: Chart,
        formula: String
    ) -> NatalLot {
        let longitude = ExtendedAstro.normalized(rawLongitude)
        let signIndex = ExtendedAstro.signIndex(longitude)
        let ruler = EssentialDignityEngine.domicileRuler(of: signIndex)
        return NatalLot(
            key: "LOTE_\(kind.rawValue.uppercased())",
            kind: kind,
            name: "\(kind.symbol) \(kind.title)",
            formulaComment: formula,
            longitude: ExtendedAstro.rounded(longitude, places: 6),
            formatted: AstroEngine.degToSign(longitude),
            signIndex: signIndex,
            signKey: SIGN_KEYS[signIndex],
            signLabel: SIGN_LABELS[signIndex],
            house: AstroEngine.planetHouse(deg: longitude, cusps: chart.cusps),
            rulerKey: ruler,
            rulerLabel: ExtendedAstro.planetLabel(for: ruler),
            dispositorKey: ruler,
            dispositorLabel: ExtendedAstro.planetLabel(for: ruler)
        )
    }
}
