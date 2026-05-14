import Foundation

func transitsTimeline(
    events: [TransitEvent],
    from: Date,
    to: Date,
    theme: ReportTheme,
    width: Int = 800,
    height: Int = 400
) -> String {
    let canvasWidth = Double(width)
    let canvasHeight = Double(height)
    let left = 92.0
    let right = 28.0
    let top = 44.0
    let bottom = 42.0
    let plotWidth = max(1, canvasWidth - left - right)
    let endDate = maxDate(to, from.addingTimeInterval(86_400))
    let scale = DateScale(start: from, end: endDate, x: left, width: plotWidth)

    let grouped = Dictionary(grouping: events, by: \TransitEvent.transitKey)
    let orderedKeys = orderedTransitKeys(Array(grouped.keys))
    let rows = max(orderedKeys.count, 1)
    let bandHeight = max(24, (canvasHeight - top - bottom) / Double(rows))

    var canvas = SVGCanvas(width: canvasWidth, height: canvasHeight)
        .rect(x: 0, y: 0, width: canvasWidth, height: canvasHeight, fill: theme.palette.background, stroke: "none", strokeWidth: 0)
        .text(x: left, y: 22, text: "Tránsitos activos", fontSize: 14, fill: theme.palette.primary, anchor: "start")
        .line(x1: left, y1: canvasHeight - bottom + 2, x2: canvasWidth - right, y2: canvasHeight - bottom + 2, stroke: theme.palette.inkSoft, strokeWidth: 1)

    for tick in monthTicks(from: from, to: endDate) {
        let x = scale.x(for: tick)
        canvas = canvas
            .line(x1: x, y1: top - 8, x2: x, y2: canvasHeight - bottom + 8, stroke: theme.palette.neutralRule, strokeWidth: 0.6)
            .text(x: x, y: canvasHeight - bottom + 23, text: SVGChartSupport.monthDateFormatter().string(from: tick), fontSize: 8, fill: theme.palette.inkSoft, anchor: "middle")
    }

    if orderedKeys.isEmpty {
        canvas = canvas.text(x: canvasWidth / 2, y: canvasHeight / 2, text: "Sin eventos en el rango", fontSize: 12, fill: theme.palette.inkSoft, anchor: "middle")
    }

    for (index, key) in orderedKeys.enumerated() {
        let y = top + Double(index) * bandHeight
        let label = grouped[key]?.first?.transitLabel ?? key.capitalized
        canvas = canvas
            .rect(x: left, y: y, width: plotWidth, height: bandHeight - 4, fill: index.isMultiple(of: 2) ? "#FFFFFF22" : "#00000008", stroke: theme.palette.neutralRule, strokeWidth: 0.4, rx: 4, attributes: ["data-transit-band": key])
            .text(x: left - 10, y: y + (bandHeight - 4) / 2, text: label, fontSize: 9, fill: theme.palette.inkSoft, anchor: "end")

        for event in (grouped[key] ?? []).sorted(by: { $0.exactDate < $1.exactDate }) {
            let start = SVGChartSupport.parseISODate(event.fromDate) ?? SVGChartSupport.parseISODate(event.exactDate) ?? from
            let end = SVGChartSupport.parseISODate(event.toDate) ?? SVGChartSupport.parseISODate(event.exactDate) ?? start.addingTimeInterval(86_400)
            let clampedStart = maxDate(start, from)
            let clampedEnd = minDate(maxDate(end, clampedStart.addingTimeInterval(86_400)), endDate)
            guard clampedEnd >= from && clampedStart <= endDate else { continue }

            let x1 = scale.x(for: clampedStart)
            let x2 = scale.x(for: clampedEnd)
            let rectWidth = max(3, x2 - x1)
            let rectY = y + 6
            let rectHeight = max(10, bandHeight - 16)
            let color = ChartSVGRenderingSupport.priorityColor(event.priorityBand, theme: theme)
            canvas = canvas.rect(
                x: x1,
                y: rectY,
                width: rectWidth,
                height: rectHeight,
                fill: color,
                stroke: theme.palette.ink,
                strokeWidth: 0.35,
                rx: 3,
                attributes: [
                    "data-transit-event": event.id.uuidString,
                    "data-priority": event.priorityBand.rawValue,
                    "data-aspect": event.aspectKey,
                    "data-natal": event.natalKey,
                ]
            )
            if rectWidth > 42 {
                canvas = canvas.text(x: x1 + 5, y: rectY + rectHeight / 2, text: "\(event.aspectLabel) \(event.natalLabel)", fontSize: 7, fill: theme.palette.background, anchor: "start")
            }
        }
    }

    return canvas.build()
}

func zrTimeline(
    timeline: ZRTimeline,
    depth: Int = 2,
    theme: ReportTheme,
    width: Int = 800,
    height: Int = 300
) -> String {
    let canvasWidth = Double(width)
    let canvasHeight = Double(height)
    let left = 72.0
    let right = 28.0
    let top = 42.0
    let plotWidth = max(1, canvasWidth - left - right)
    let l1Y = top + 22
    let l2Y = l1Y + 76
    let l1Height = 48.0
    let l2Height = 42.0

    let startDate = timeline.periods.map(\.startDate).min() ?? timeline.birthDate
    let endDate = timeline.periods.map(\.endDate).max() ?? Calendar(identifier: .gregorian).date(byAdding: .year, value: 1, to: startDate) ?? startDate.addingTimeInterval(31_536_000)
    let scale = DateScale(start: startDate, end: maxDate(endDate, startDate.addingTimeInterval(86_400)), x: left, width: plotWidth)

    var canvas = SVGCanvas(width: canvasWidth, height: canvasHeight)
        .rect(x: 0, y: 0, width: canvasWidth, height: canvasHeight, fill: theme.palette.background, stroke: "none", strokeWidth: 0)
        .text(x: left, y: 22, text: "Zodiacal Releasing — \(timeline.lotPoint.name)", fontSize: 14, fill: theme.palette.primary, anchor: "start")
        .line(x1: left, y1: canvasHeight - 32, x2: canvasWidth - right, y2: canvasHeight - 32, stroke: theme.palette.inkSoft, strokeWidth: 1)
        .text(x: left - 10, y: l1Y + l1Height / 2, text: "L1", fontSize: 10, fill: theme.palette.inkSoft, anchor: "end")

    for tick in yearTicks(from: startDate, to: endDate, interval: 5) {
        let x = scale.x(for: tick)
        canvas = canvas
            .line(x1: x, y1: top, x2: x, y2: canvasHeight - 28, stroke: theme.palette.neutralRule, strokeWidth: 0.45)
            .text(x: x, y: canvasHeight - 14, text: yearString(tick), fontSize: 8, fill: theme.palette.inkSoft, anchor: "middle")
    }

    for period in timeline.periods {
        canvas = renderZRPeriod(period, canvas: canvas, scale: scale, y: l1Y, height: l1Height, theme: theme)
    }

    if depth >= 2 {
        canvas = canvas.text(x: left - 10, y: l2Y + l2Height / 2, text: "L2", fontSize: 10, fill: theme.palette.inkSoft, anchor: "end")
        for child in timeline.periods.flatMap(\.children) {
            canvas = renderZRPeriod(child, canvas: canvas, scale: scale, y: l2Y, height: l2Height, theme: theme)
        }
    }

    let events = uniqueZREvents(timeline.highlightedEvents + timeline.periods.flatMap { $0.flattened().flatMap(\.events) })
    for event in events {
        let x = scale.x(for: event.date)
        switch event.kind {
        case .loosingOfBond:
            canvas = canvas.polygon(
                points: [(x, l2Y - 13), (x - 7, l2Y - 1), (x + 7, l2Y - 1)],
                fill: theme.palette.gold,
                stroke: theme.palette.ink,
                strokeWidth: 0.4,
                attributes: ["data-zr-marker": "loosing-of-bond", "data-zr-event": event.id]
            )
        case .peak:
            canvas = canvas.circle(cx: x, cy: l1Y - 10, r: 5, fill: theme.palette.benefic, stroke: theme.palette.ink, strokeWidth: 0.5)
                .raw("<metadata data-zr-marker=\"peak\" data-zr-event=\"\(SVGChartSupport.escapeAttribute(event.id))\"/>")
        case .levelOneChange:
            canvas = canvas.line(x1: x, y1: l1Y - 8, x2: x, y2: l1Y + l1Height + 8, stroke: theme.palette.primary, strokeWidth: 1.1)
        }
    }

    return canvas.build()
}

func firdariaTimeline(
    timeline: FirdariaTimeline,
    theme: ReportTheme,
    width: Int = 800,
    height: Int = 120
) -> String {
    let canvasWidth = Double(width)
    let canvasHeight = Double(height)
    let left = 72.0
    let right = 28.0
    let top = 38.0
    let plotWidth = max(1, canvasWidth - left - right)
    let bandHeight = 34.0
    let calendar = Calendar(identifier: .gregorian)
    let startDate = timeline.birthDate
    let endDate = calendar.date(byAdding: .year, value: 75, to: startDate) ?? startDate.addingTimeInterval(75 * 31_536_000)
    let scale = DateScale(start: startDate, end: endDate, x: left, width: plotWidth)

    var canvas = SVGCanvas(width: canvasWidth, height: canvasHeight)
        .rect(x: 0, y: 0, width: canvasWidth, height: canvasHeight, fill: theme.palette.background, stroke: "none", strokeWidth: 0)
        .text(x: left, y: 20, text: "Firdaria — eje 75 años", fontSize: 13, fill: theme.palette.primary, anchor: "start")
        .line(x1: left, y1: canvasHeight - 26, x2: canvasWidth - right, y2: canvasHeight - 26, stroke: theme.palette.inkSoft, strokeWidth: 1)

    for tick in yearTicks(from: startDate, to: endDate, interval: 10) {
        let x = scale.x(for: tick)
        canvas = canvas
            .line(x1: x, y1: top - 6, x2: x, y2: canvasHeight - 20, stroke: theme.palette.neutralRule, strokeWidth: 0.5)
            .text(x: x, y: canvasHeight - 10, text: "+\(calendar.dateComponents([.year], from: startDate, to: tick).year ?? 0)", fontSize: 8, fill: theme.palette.inkSoft, anchor: "middle")
    }

    for period in timeline.majorPeriods {
        let x1 = scale.x(for: maxDate(period.startDate, startDate))
        let x2 = scale.x(for: minDate(period.endDate, endDate))
        let w = max(2, x2 - x1)
        let color = ChartSVGRenderingSupport.planetColor(period.ruler, theme: theme)
        canvas = canvas.rect(
            x: x1,
            y: top,
            width: w,
            height: bandHeight,
            fill: color,
            stroke: theme.palette.background,
            strokeWidth: 0.8,
            rx: 4,
            attributes: ["data-firdaria-ruler": period.ruler.rawValue, "data-firdaria-kind": period.kind.rawValue]
        )
        if w > 34 {
            canvas = canvas.text(x: x1 + w / 2, y: top + bandHeight / 2, text: period.ruler.shortLabel, fontSize: 9, fill: theme.palette.background, anchor: "middle")
        }
    }

    return canvas.build()
}

private func renderZRPeriod(_ period: ZRPeriod, canvas: SVGCanvas, scale: DateScale, y: Double, height: Double, theme: ReportTheme) -> SVGCanvas {
    let x1 = scale.x(for: period.startDate)
    let x2 = scale.x(for: period.endDate)
    let width = max(2, x2 - x1)
    let color = ChartSVGRenderingSupport.signColor(index: period.signIndex, theme: theme)
    var output = canvas.rect(
        x: x1,
        y: y,
        width: width,
        height: height,
        fill: color,
        stroke: theme.palette.background,
        strokeWidth: 0.8,
        rx: 4,
        attributes: [
            "data-zr-level": period.level.label,
            "data-zr-sign": period.signKey,
            "data-zr-period": period.id,
        ]
    )
    if width > 28 {
        output = output.text(x: x1 + width / 2, y: y + height / 2, text: period.signLabel.replacingOccurrences(of: "♈ ", with: "").split(separator: " ").last.map(String.init) ?? period.signKey, fontSize: period.level == .l1 ? 10 : 8, fill: "#FFFFFF", anchor: "middle")
    }
    if period.isPeak {
        output = output.circle(cx: x1 + min(width / 2, width - 6), cy: y + 8, r: 4, fill: theme.palette.benefic, stroke: theme.palette.ink, strokeWidth: 0.4)
    }
    return output
}

private struct DateScale {
    let start: Date
    let end: Date
    let x: Double
    let width: Double

    func x(for date: Date) -> Double {
        let total = max(1, end.timeIntervalSince(start))
        let ratio = SVGChartSupport.clamp(date.timeIntervalSince(start) / total, 0, 1)
        return x + ratio * width
    }
}

private func orderedTransitKeys(_ keys: [String]) -> [String] {
    let preferred = ["SATURNO", "URANO", "NEPTUNO", "PLUTON", "JUPITER", "MARTE", "SOL", "LUNA", "MERCURIO", "VENUS"]
    let rank = Dictionary(uniqueKeysWithValues: preferred.enumerated().map { ($0.element, $0.offset) })
    return keys.sorted {
        let leftRank = rank[$0] ?? 999
        let rightRank = rank[$1] ?? 999
        if leftRank != rightRank { return leftRank < rightRank }
        return $0 < $1
    }
}

private func monthTicks(from: Date, to: Date) -> [Date] {
    let calendar = Calendar(identifier: .gregorian)
    let startComponents = calendar.dateComponents([.year, .month], from: from)
    var current = calendar.date(from: startComponents) ?? from
    if current < from, let next = calendar.date(byAdding: .month, value: 1, to: current) { current = next }
    var ticks: [Date] = []
    while current <= to {
        ticks.append(current)
        guard let next = calendar.date(byAdding: .month, value: 1, to: current) else { break }
        current = next
    }
    return ticks
}

private func yearTicks(from: Date, to: Date, interval: Int) -> [Date] {
    let calendar = Calendar(identifier: .gregorian)
    var ticks: [Date] = [from]
    var offset = interval
    while let tick = calendar.date(byAdding: .year, value: offset, to: from), tick <= to {
        ticks.append(tick)
        offset += interval
    }
    if ticks.last != to { ticks.append(to) }
    return ticks
}

private func yearString(_ date: Date) -> String {
    let calendar = Calendar(identifier: .gregorian)
    return String(calendar.component(.year, from: date))
}

private func uniqueZREvents(_ events: [ZREvent]) -> [ZREvent] {
    var seen: Set<String> = []
    var result: [ZREvent] = []
    for event in events.sorted(by: { $0.date < $1.date }) {
        guard !seen.contains(event.id) else { continue }
        seen.insert(event.id)
        result.append(event)
    }
    return result
}

private func maxDate(_ lhs: Date, _ rhs: Date) -> Date { lhs >= rhs ? lhs : rhs }
private func minDate(_ lhs: Date, _ rhs: Date) -> Date { lhs <= rhs ? lhs : rhs }
