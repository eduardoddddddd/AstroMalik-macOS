import Foundation

func doubleWheel(natal: NatalChart, secondary: NatalChart, theme: ReportTheme, size: Int = 700) -> String {
    let side = Double(size)
    let center = side / 2
    let outerRadius = side * 0.46
    let zodiacInnerRadius = outerRadius - side * 0.055
    let secondaryRadius = outerRadius * 0.78
    let natalRadius = outerRadius * 0.61
    let aspectOuterRadius = outerRadius * 0.70
    let aspectInnerRadius = outerRadius * 0.46

    var canvas = SVGCanvas(width: side, height: side)
        .rect(x: 0, y: 0, width: side, height: side, fill: theme.palette.background, stroke: "none", strokeWidth: 0)
        .circle(cx: center, cy: center, r: outerRadius, fill: "none", stroke: theme.palette.primary, strokeWidth: 1.8)
        .circle(cx: center, cy: center, r: zodiacInnerRadius, fill: "none", stroke: theme.palette.neutralRule, strokeWidth: 1)
        .circle(cx: center, cy: center, r: secondaryRadius + 18, fill: "none", stroke: theme.palette.goldSoft, strokeWidth: 1)
        .circle(cx: center, cy: center, r: secondaryRadius - 20, fill: "none", stroke: theme.palette.neutralRule, strokeWidth: 0.8)
        .circle(cx: center, cy: center, r: natalRadius + 18, fill: "none", stroke: theme.palette.goldSoft, strokeWidth: 1)
        .circle(cx: center, cy: center, r: natalRadius - 20, fill: "none", stroke: theme.palette.neutralRule, strokeWidth: 0.8)
        .circle(cx: center, cy: center, r: aspectInnerRadius - 18, fill: "#FFFFFF20", stroke: theme.palette.neutralRule, strokeWidth: 0.8)

    for index in 0..<12 {
        let longitude = Double(index * 30)
        let start = SVGChartSupport.point(longitude: longitude, centerX: center, centerY: center, radius: zodiacInnerRadius)
        let end = SVGChartSupport.point(longitude: longitude, centerX: center, centerY: center, radius: outerRadius)
        canvas = canvas.line(x1: start.x, y1: start.y, x2: end.x, y2: end.y, stroke: theme.palette.neutralRule, strokeWidth: 0.8)
        let signPoint = SVGChartSupport.point(longitude: longitude + 15, centerX: center, centerY: center, radius: outerRadius - 24)
        canvas = canvas.raw(ChartSVGRenderingSupport.glyphElement(
            AstroGlyph.sign(index: index),
            x: signPoint.x,
            y: signPoint.y,
            size: 22,
            stroke: ChartSVGRenderingSupport.signColor(index: index, theme: theme),
            strokeWidth: 7,
            attributes: ["data-sign-index": "\(index)"]
        ))
    }

    let natalByKey = Dictionary(uniqueKeysWithValues: natal.bodies.map { ($0.key, $0) })
    let secondaryByKey = Dictionary(uniqueKeysWithValues: secondary.bodies.map { ($0.key, $0) })
    for aspect in ChartSVGRenderingSupport.interChartAspects(natal: natal, secondary: secondary).prefix(80) {
        guard let natalBody = natalByKey[aspect.targetPlanetKey], let secondaryBody = secondaryByKey[aspect.sourcePlanetKey] else { continue }
        let inner = SVGChartSupport.point(longitude: natalBody.longitude, centerX: center, centerY: center, radius: aspectInnerRadius)
        let outer = SVGChartSupport.point(longitude: secondaryBody.longitude, centerX: center, centerY: center, radius: aspectOuterRadius)
        let color = ChartSVGRenderingSupport.aspectColor(aspect.aspectKey, theme: theme)
        canvas = canvas.raw("""
        <line data-aspect-line="double" data-aspect="\(SVGChartSupport.escapeAttribute(aspect.aspectKey))" data-corpus="\(SVGChartSupport.escapeAttribute(aspect.corpusClave))" x1="\(SVGChartSupport.format(inner.x))" y1="\(SVGChartSupport.format(inner.y))" x2="\(SVGChartSupport.format(outer.x))" y2="\(SVGChartSupport.format(outer.y))" stroke="\(SVGChartSupport.escapeAttribute(color))" stroke-width="1" opacity="0.44" stroke-linecap="round"/>
        """)
    }

    canvas = drawBodies(
        ChartSVGRenderingSupport.placements(for: natal.bodies),
        on: canvas,
        center: center,
        baseRadius: natalRadius,
        laneDirection: -1,
        theme: theme,
        ringName: "natal"
    )

    canvas = drawBodies(
        ChartSVGRenderingSupport.placements(for: secondary.bodies),
        on: canvas,
        center: center,
        baseRadius: secondaryRadius,
        laneDirection: 1,
        theme: theme,
        ringName: "secondary"
    )

    return canvas
        .text(x: center, y: center - 8, text: "Interior: natal", fontSize: 10, fill: theme.palette.inkSoft, anchor: "middle")
        .text(x: center, y: center + 10, text: "Exterior: secundaria", fontSize: 10, fill: theme.palette.inkSoft, anchor: "middle")
        .build()
}

private func drawBodies(
    _ placements: [SVGBodyPlacement],
    on canvas: SVGCanvas,
    center: Double,
    baseRadius: Double,
    laneDirection: Double,
    theme: ReportTheme,
    ringName: String
) -> SVGCanvas {
    var output = canvas
    for placement in placements {
        let body = placement.body
        let radius = baseRadius + laneDirection * Double(placement.lane) * 16
        let point = SVGChartSupport.point(longitude: body.longitude, centerX: center, centerY: center, radius: radius)
        guard let glyph = AstroGlyph.planet(for: body.key) else { continue }
        output = output.raw(ChartSVGRenderingSupport.glyphElement(
            glyph,
            x: point.x,
            y: point.y,
            size: ringName == "natal" ? 22 : 24,
            stroke: ChartSVGRenderingSupport.planetColor(body.key, theme: theme),
            strokeWidth: 7,
            attributes: [
                "data-ring": ringName,
                "data-planet": body.key,
                "data-house": "\(body.house)",
            ]
        ))
        let labelOffset = ringName == "natal" ? 16.0 : 18.0
        output = output.text(
            x: point.x,
            y: point.y + labelOffset,
            text: "\(SVGChartSupport.degreeInSignText(body.longitude)) H\(body.house)",
            fontSize: 7,
            fill: theme.palette.inkSoft,
            anchor: "middle"
        )
    }
    return output
}
