import Foundation

struct SVGBodyPlacement {
    let body: PlanetBody
    let lane: Int
}

enum ChartSVGRenderingSupport {
    static let planetOrder = ["SOL", "LUNA", "MERCURIO", "VENUS", "MARTE", "JUPITER", "SATURNO", "URANO", "NEPTUNO", "PLUTON", "NODO_NORTE", "NODO_SUR"]

    static func orderedBodies(_ bodies: [PlanetBody]) -> [PlanetBody] {
        let rank = Dictionary(uniqueKeysWithValues: planetOrder.enumerated().map { ($0.element, $0.offset) })
        return bodies.sorted { lhs, rhs in
            let lRank = rank[lhs.key] ?? 999
            let rRank = rank[rhs.key] ?? 999
            if lRank != rRank { return lRank < rRank }
            return lhs.key < rhs.key
        }
    }

    static func placements(for bodies: [PlanetBody], minimumSeparationDegrees: Double = 5) -> [SVGBodyPlacement] {
        let sorted = bodies.sorted {
            let left = SVGChartSupport.normalizedLongitude($0.longitude)
            let right = SVGChartSupport.normalizedLongitude($1.longitude)
            if left != right { return left < right }
            return $0.key < $1.key
        }
        var result: [SVGBodyPlacement] = []
        var previousLongitude: Double?
        var previousLane = 0

        for body in sorted {
            let longitude = SVGChartSupport.normalizedLongitude(body.longitude)
            let lane: Int
            if let previousLongitude, abs(longitude - previousLongitude) < minimumSeparationDegrees {
                lane = (previousLane + 1) % 4
            } else {
                lane = 0
            }
            result.append(SVGBodyPlacement(body: body, lane: lane))
            previousLongitude = longitude
            previousLane = lane
        }

        // Preserve canonical planet ordering for deterministic layer output while keeping computed lanes.
        let laneByKey = Dictionary(uniqueKeysWithValues: result.map { ($0.body.key, $0.lane) })
        return orderedBodies(bodies).map { SVGBodyPlacement(body: $0, lane: laneByKey[$0.key] ?? 0) }
    }

    static func natalAspects(for chart: NatalChart) -> [NatalAspect] {
        let rawPlanets = Dictionary(uniqueKeysWithValues: chart.bodies.map { body in
            (body.key, AstroEngine.RawPlanet(
                key: body.key,
                label: body.label,
                deg: body.longitude,
                speed: body.retrograde ? -1 : 1,
                retro: body.retrograde
            ))
        })
        return AstroEngine.computeNatalAspects(planets: rawPlanets)
    }

    static func interChartAspects(natal: NatalChart, secondary: NatalChart) -> [SynastryAspect] {
        let natalMap = Dictionary(uniqueKeysWithValues: natal.bodies.map { ($0.key, $0) })
        let secondaryMap = Dictionary(uniqueKeysWithValues: secondary.bodies.map { ($0.key, $0) })
        var found: [SynastryAspect] = []
        for secondaryKey in planetOrder {
            guard let secondaryBody = secondaryMap[secondaryKey] else { continue }
            for natalKey in planetOrder {
                guard let natalBody = natalMap[natalKey] else { continue }
                let diff = SVGChartSupport.angularDistance(secondaryBody.longitude, natalBody.longitude)
                for aspect in ASPECT_DEFS {
                    let orb = abs(diff - aspect.angle)
                    if orb <= aspect.orb {
                        found.append(SynastryAspect(
                            direction: .bToA,
                            sourcePlanetKey: secondaryKey,
                            sourcePlanetLabel: secondaryBody.label,
                            targetPlanetKey: natalKey,
                            targetPlanetLabel: natalBody.label,
                            aspectKey: aspect.key,
                            aspectLabel: aspect.label,
                            orb: (orb * 100).rounded() / 100,
                            corpusClave: "SYN_\(secondaryKey)_\(natalKey)_\(aspect.key)",
                            interpretation: nil
                        ))
                    }
                }
            }
        }
        return found.sorted { lhs, rhs in
            if lhs.orb != rhs.orb { return lhs.orb < rhs.orb }
            return lhs.corpusClave < rhs.corpusClave
        }
    }

    static func aspectColor(_ key: String, theme: ReportTheme) -> String {
        switch key.uppercased() {
        case "CONJUNCION": return theme.palette.ink
        case "TRIGONO": return theme.palette.benefic
        case "SEXTIL": return "#6CA87A"
        case "CUADRADO", "OPOSICION": return theme.palette.malefic
        default: return theme.palette.inkSoft
        }
    }

    static func planetColor(_ key: String, theme: ReportTheme) -> String {
        switch key.uppercased() {
        case "SOL": return theme.palette.gold
        case "LUNA": return "#7C8798"
        case "MERCURIO": return "#2A8A86"
        case "VENUS": return theme.palette.benefic
        case "MARTE": return theme.palette.malefic
        case "JUPITER": return "#2F5E9E"
        case "SATURNO": return theme.palette.primary
        case "URANO": return "#287C9E"
        case "NEPTUNO": return "#5267A3"
        case "PLUTON": return "#5E4B6A"
        case "NODO_NORTE": return "#5E7F48"
        case "NODO_SUR": return "#8A7C62"
        default: return theme.palette.ink
        }
    }

    static func planetColor(_ key: AstroPlanetKey, theme: ReportTheme) -> String {
        planetColor(key.rawValue, theme: theme)
    }

    static func signColor(index: Int, theme: ReportTheme) -> String {
        let palette = [
            "#C96B52", "#8DA36A", "#C9A24D", "#6F98B4",
            "#D28B3E", "#7FA27C", "#B7956E", "#8B5A5A",
            "#A56F45", "#6F746D", "#5C8DA0", "#7383A9",
        ]
        return palette[max(0, min(11, index))]
    }

    static func priorityColor(_ band: TransitPriorityBand, theme: ReportTheme) -> String {
        switch band {
        case .low: return theme.palette.neutralRule
        case .medium: return theme.palette.primary
        case .high: return theme.palette.gold
        case .critical: return theme.palette.malefic
        }
    }

    static func glyphElement(
        _ glyph: AstroGlyph,
        x: Double,
        y: Double,
        size: Double,
        stroke: String,
        fill: String = "none",
        strokeWidth: Double = 7,
        attributes: [String: String] = [:]
    ) -> String {
        let scale = size / 100
        let extra = SVGChartSupport.attributes(attributes.merging(["data-glyph": glyph.canonicalName]) { current, _ in current })
        return """
        <g transform="translate(\(SVGChartSupport.format(x)) \(SVGChartSupport.format(y))) scale(\(SVGChartSupport.format(scale)))"\(extra)>
          <path d="\(SVGChartSupport.escapeAttribute(glyph.pathD))" fill="\(SVGChartSupport.escapeAttribute(fill))" stroke="\(SVGChartSupport.escapeAttribute(stroke))" stroke-width="\(SVGChartSupport.format(strokeWidth))" stroke-linecap="round" stroke-linejoin="round"/>
        </g>
        """
    }
}
