import Foundation

func wheel(chart: NatalChart, theme: ReportTheme, size: Int = 600) -> String {
    let side = Double(size)
    let center = side / 2
    let outerRadius = side * 0.46
    let zodiacInnerRadius = outerRadius - side * 0.07
    let houseOuterRadius = outerRadius * 0.66
    let houseInnerRadius = outerRadius * 0.50
    let planetBaseRadius = outerRadius * 0.79
    let aspectRadius = outerRadius * 0.38

    var canvas = SVGCanvas(width: side, height: side)
        .rect(x: 0, y: 0, width: side, height: side, fill: theme.palette.background, stroke: "none", strokeWidth: 0)
        .circle(cx: center, cy: center, r: outerRadius, fill: "none", stroke: theme.palette.primary, strokeWidth: 1.8)
        .circle(cx: center, cy: center, r: outerRadius - 8, fill: "none", stroke: theme.palette.goldSoft, strokeWidth: 0.9)
        .circle(cx: center, cy: center, r: zodiacInnerRadius, fill: "none", stroke: theme.palette.neutralRule, strokeWidth: 1.1)
        .circle(cx: center, cy: center, r: houseOuterRadius, fill: "none", stroke: theme.palette.neutralRule, strokeWidth: 1)
        .circle(cx: center, cy: center, r: houseInnerRadius, fill: "none", stroke: theme.palette.neutralRule, strokeWidth: 0.8)
        .circle(cx: center, cy: center, r: aspectRadius, fill: "#FFFFFF22", stroke: theme.palette.neutralRule, strokeWidth: 0.8)

    for index in 0..<12 {
        let longitude = Double(index * 30)
        let start = SVGChartSupport.point(longitude: longitude, centerX: center, centerY: center, radius: zodiacInnerRadius)
        let end = SVGChartSupport.point(longitude: longitude, centerX: center, centerY: center, radius: outerRadius)
        canvas = canvas.line(x1: start.x, y1: start.y, x2: end.x, y2: end.y, stroke: theme.palette.neutralRule, strokeWidth: 0.9)

        let signPoint = SVGChartSupport.point(longitude: longitude + 15, centerX: center, centerY: center, radius: outerRadius - 27)
        canvas = canvas.raw(ChartSVGRenderingSupport.glyphElement(
            AstroGlyph.sign(index: index),
            x: signPoint.x,
            y: signPoint.y,
            size: 23,
            stroke: ChartSVGRenderingSupport.signColor(index: index, theme: theme),
            strokeWidth: 7,
            attributes: ["data-sign-index": "\(index)"]
        ))
    }

    let cusps = Array(chart.cusps.prefix(12))
    for (index, cusp) in cusps.enumerated() {
        let start = SVGChartSupport.point(longitude: cusp, centerX: center, centerY: center, radius: houseInnerRadius)
        let end = SVGChartSupport.point(longitude: cusp, centerX: center, centerY: center, radius: houseOuterRadius)
        canvas = canvas.line(x1: start.x, y1: start.y, x2: end.x, y2: end.y, stroke: theme.palette.goldSoft, strokeWidth: index == 0 ? 1.5 : 0.8)

        let next = cusps.indices.contains(index + 1) ? cusps[index + 1] : (cusps.first ?? cusp) + 360
        let midpoint = midpointLongitude(cusp, next)
        let labelPoint = SVGChartSupport.point(longitude: midpoint, centerX: center, centerY: center, radius: (houseInnerRadius + houseOuterRadius) / 2)
        canvas = canvas.text(x: labelPoint.x, y: labelPoint.y, text: "\(index + 1)", fontSize: 9, fill: theme.palette.inkSoft, anchor: "middle")
    }

    let bodiesByKey = Dictionary(uniqueKeysWithValues: chart.bodies.map { ($0.key, $0) })
    for aspect in ChartSVGRenderingSupport.natalAspects(for: chart) {
        guard let left = bodiesByKey[aspect.keyA], let right = bodiesByKey[aspect.keyB] else { continue }
        let a = SVGChartSupport.point(longitude: left.longitude, centerX: center, centerY: center, radius: aspectRadius)
        let b = SVGChartSupport.point(longitude: right.longitude, centerX: center, centerY: center, radius: aspectRadius)
        let color = ChartSVGRenderingSupport.aspectColor(aspect.aspKey, theme: theme)
        canvas = canvas.raw("""
        <line data-aspect-line="natal" data-aspect="\(SVGChartSupport.escapeAttribute(aspect.aspKey))" data-corpus="\(SVGChartSupport.escapeAttribute(aspect.corpusClave))" x1="\(SVGChartSupport.format(a.x))" y1="\(SVGChartSupport.format(a.y))" x2="\(SVGChartSupport.format(b.x))" y2="\(SVGChartSupport.format(b.y))" stroke="\(SVGChartSupport.escapeAttribute(color))" stroke-width="1.15" opacity="0.62" stroke-linecap="round"/>
        """)
    }

    canvas = markAngle(canvas, longitude: chart.ascendant.longitude, label: "ASC", center: center, inner: houseInnerRadius * 0.55, outer: outerRadius + 10, theme: theme)
    canvas = markAngle(canvas, longitude: chart.mc.longitude, label: "MC", center: center, inner: houseInnerRadius * 0.55, outer: outerRadius + 10, theme: theme)

    for placement in ChartSVGRenderingSupport.placements(for: chart.bodies) {
        let body = placement.body
        let radius = planetBaseRadius - Double(placement.lane) * 18
        let point = SVGChartSupport.point(longitude: body.longitude, centerX: center, centerY: center, radius: radius)
        let color = ChartSVGRenderingSupport.planetColor(body.key, theme: theme)
        if let glyph = AstroGlyph.planet(for: body.key) {
            canvas = canvas.raw(ChartSVGRenderingSupport.glyphElement(
                glyph,
                x: point.x,
                y: point.y,
                size: 24,
                stroke: color,
                strokeWidth: 7,
                attributes: [
                    "data-planet": body.key,
                    "data-house": "\(body.house)",
                    "data-longitude": SVGChartSupport.format(SVGChartSupport.normalizedLongitude(body.longitude)),
                ]
            ))
        }
        let label = "\(SVGChartSupport.degreeInSignText(body.longitude)) H\(body.house)\(body.retrograde ? " ℞" : "")"
        canvas = canvas.text(x: point.x, y: point.y + 18, text: label, fontSize: 7.5, fill: theme.palette.inkSoft, anchor: "middle")
    }

    return canvas.build()
}

private func markAngle(
    _ canvas: SVGCanvas,
    longitude: Double,
    label: String,
    center: Double,
    inner: Double,
    outer: Double,
    theme: ReportTheme
) -> SVGCanvas {
    let start = SVGChartSupport.point(longitude: longitude, centerX: center, centerY: center, radius: inner)
    let end = SVGChartSupport.point(longitude: longitude, centerX: center, centerY: center, radius: outer)
    let textPoint = SVGChartSupport.point(longitude: longitude, centerX: center, centerY: center, radius: outer + 12)
    return canvas
        .raw("""
        <line data-angle="\(SVGChartSupport.escapeAttribute(label))" x1="\(SVGChartSupport.format(start.x))" y1="\(SVGChartSupport.format(start.y))" x2="\(SVGChartSupport.format(end.x))" y2="\(SVGChartSupport.format(end.y))" stroke="\(SVGChartSupport.escapeAttribute(theme.palette.primary))" stroke-width="2.6" stroke-linecap="round"/>
        """)
        .text(x: textPoint.x, y: textPoint.y, text: label, fontSize: 11, fill: theme.palette.primary, anchor: "middle")
}

private func midpointLongitude(_ start: Double, _ end: Double) -> Double {
    var adjustedEnd = end
    if adjustedEnd < start { adjustedEnd += 360 }
    return SVGChartSupport.normalizedLongitude(start + ((adjustedEnd - start) / 2))
}
