import Foundation

enum NatalExtendedAnalysis {
    static func compute(
        chart: Chart,
        configuration: NatalExtendedAnalysisConfiguration = .default
    ) throws -> NatalExtendedAnalysisResult {
        let lotsEngine = LotsEngine()
        let lots = try lotsEngine.lots(chart: chart)
        let almuten = try AlmutenFigurisEngine().almutenFiguris(chart: chart)
        let geniture = try rulerOfGeniture(chart: chart)
        let patterns = AspectPatternEngine().patterns(chart: chart, orb: configuration.aspectPatternOrb)
        let distribution = DistributionEngine().distribution(chart: chart)
        let receptions = ReceptionEngine().receptions(chart: chart)
        let antiscia = AntisciaEngine().antiscia(chart: chart, orb: configuration.antisciaOrb)
        let declinations = try DeclinationEngine().declinations(chart: chart, orb: configuration.declinationOrb)
        let fixedStars = try FixedStarsEngine().fixedStars(chart: chart, orb: configuration.fixedStarOrb)

        return NatalExtendedAnalysisResult(
            generatedAt: Date(),
            configuration: configuration,
            lots: lots,
            almutenFiguris: almuten,
            rulerOfGeniture: geniture,
            aspectPatterns: patterns,
            distribution: distribution,
            receptions: receptions,
            antiscia: antiscia,
            declinations: declinations,
            fixedStars: fixedStars
        )
    }

    static func rulerOfGeniture(chart: Chart) throws -> RulerOfGeniture {
        let sect = SectEngine.sect(of: chart)
        let luminary = try ExtendedAstro.body(sect.luminary.key, in: chart)
        let sign = ExtendedAstro.signIndex(luminary.longitude)
        let ruler = EssentialDignityEngine.domicileRuler(of: sign)
        let dignities = EssentialDignityEngine.dignities(
            planet: ruler,
            longitude: luminary.longitude,
            isDiurnal: sect.isDiurnal
        )
        let awards = dignities.map { score in
            DignityAward(
                planetKey: ruler,
                planetLabel: ExtendedAstro.planetLabel(for: ruler),
                dignity: score.dignity.rawValue,
                points: score.score
            )
        }
        let summary = dignities
            .map { "\($0.dignity.rawValue) (\($0.score))" }
            .joined(separator: ", ")
        return RulerOfGeniture(
            sectLabel: sect.label,
            luminaryKey: luminary.key,
            luminaryLabel: luminary.label,
            luminaryLongitude: ExtendedAstro.rounded(luminary.longitude, places: 6),
            luminaryFormatted: luminary.formatted,
            rulerKey: ruler,
            rulerLabel: ExtendedAstro.planetLabel(for: ruler),
            dignityAwards: awards,
            dignitySummary: summary.isEmpty ? "Sin dignidad esencial positiva" : summary
        )
    }
}
