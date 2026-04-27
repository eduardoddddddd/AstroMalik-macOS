import SwiftUI

// MARK: - PrimaryDirectionsTimelineView
// Navegador temporal compacto. El eje horizontal es edad; los carriles verticales
// evitan que las direcciones se amontonen cuando hay muchos eventos cercanos.

struct PrimaryDirectionsTimelineView: View {
    let directions: [EnrichedPrimaryDirection]
    let timeline: [PrimaryDirectionTimelineEntry]
    let ageDomain: ClosedRange<Double>
    @Binding var selectedDirection: EnrichedPrimaryDirection?

    @State private var hoveredId: UUID?

    private let axisY: CGFloat = 142
    private let laneTop: CGFloat = 24
    private let laneGap: CGFloat = 18
    private let laneCount = 6
    private let minimumMarkerSpacing: CGFloat = 22

    var body: some View {
        GeometryReader { geo in
            let width = max(geo.size.width, 640)
            let placed = placedDirections(width: width)

            ZStack(alignment: .topLeading) {
                backgroundBands(width: width)
                ageGrid(width: width)
                axis(width: width)

                ForEach(placed) { item in
                    directionMarker(item)
                }

                if let selected = selectedDirection {
                    selectedSummary(selected)
                        .position(x: min(max(xPosition(age: selected.direction.estimatedAge, width: width), 150), width - 150), y: 14)
                }
            }
            .frame(width: width, height: 184)
            .background(
                LinearGradient(
                    colors: [Color.appPanel.opacity(0.85), Color.appBackground],
                    startPoint: .top,
                    endPoint: .bottom
                )
            )
            .clipShape(Rectangle())
        }
    }

    private func backgroundBands(width: CGFloat) -> some View {
        ZStack(alignment: .topLeading) {
            ForEach(timeline) { entry in
                let start = max(Double(entry.decadeStart), ageDomain.lowerBound)
                let end = min(Double(entry.decadeEnd), ageDomain.upperBound)
                if end > start {
                    let x1 = xPosition(age: start, width: width)
                    let x2 = xPosition(age: end, width: width)
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(toneColor(entry.overallTone).opacity(0.055))
                        .frame(width: max(0, x2 - x1 - 4), height: 124)
                        .offset(x: x1 + 2, y: 20)
                }
            }
        }
    }

    private func ageGrid(width: CGFloat) -> some View {
        ZStack(alignment: .topLeading) {
            ForEach(ageTicks(step: 5), id: \.self) { age in
                let isMajor = Int(age) % 10 == 0
                let x = xPosition(age: age, width: width)
                Rectangle()
                    .fill(Color.appBorder.opacity(isMajor ? 0.5 : 0.22))
                    .frame(width: 1, height: isMajor ? 142 : 116)
                    .offset(x: x, y: isMajor ? 22 : 34)

                if isMajor {
                    Text("\(Int(age))")
                        .font(.system(size: 10, weight: .semibold, design: .monospaced))
                        .foregroundStyle(.secondary)
                        .position(x: x, y: axisY + 22)
                }
            }
        }
    }

    private func axis(width: CGFloat) -> some View {
        ZStack(alignment: .topLeading) {
            Rectangle()
                .fill(Color.primary.opacity(0.18))
                .frame(width: width, height: 1)
                .offset(y: axisY)

            HStack(spacing: 12) {
                legendItem("Fluido", color: Color(hex: "#16A34A"))
                legendItem("Tenso", color: Color(hex: "#DC2626"))
                legendItem("Neutro", color: Color(hex: "#64748B"))
                Spacer()
                Text("\(Int(ageDomain.lowerBound))-\(Int(ageDomain.upperBound)) años")
                    .font(.caption.monospaced())
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 16)
            .position(x: width / 2, y: 168)
        }
    }

    private func legendItem(_ label: String, color: Color) -> some View {
        HStack(spacing: 5) {
            Circle()
                .fill(color)
                .frame(width: 7, height: 7)
            Text(label)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
    }

    private func directionMarker(_ item: TimelinePlacedDirection) -> some View {
        let enriched = item.enriched
        let dir = enriched.direction
        let isSelected = selectedDirection?.id == enriched.id
        let isHovered = hoveredId == enriched.id
        let color = polarityColor(dir.aspect.polarity)
        let markerSize: CGFloat = isSelected ? 16 : (isHovered ? 13 : 10)

        return ZStack {
            Path { path in
                path.move(to: CGPoint(x: item.x, y: axisY - 2))
                path.addLine(to: CGPoint(x: item.x, y: item.y + 8))
            }
            .stroke(
                color.opacity(isSelected ? 0.9 : 0.35),
                style: StrokeStyle(lineWidth: isSelected ? 2.5 : 1.5, lineCap: .round)
            )

            markerDot(for: dir, color: color, size: markerSize, isSelected: isSelected)
                .position(x: item.x, y: item.y)

            if isHovered {
                tooltipView(for: enriched)
                    .position(x: clampedTooltipX(item.x), y: max(64, item.y - 50))
                    .zIndex(50)
            }
        }
        .contentShape(Rectangle())
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.12)) {
                hoveredId = hovering ? dir.id : nil
            }
        }
        .onTapGesture {
            withAnimation(.spring(response: 0.22, dampingFraction: 0.82)) {
                selectedDirection = enriched
            }
        }
        .animation(.easeInOut(duration: 0.12), value: isSelected)
        .zIndex(isSelected || isHovered ? 10 : 1)
    }

    @ViewBuilder
    private func markerDot(for direction: PrimaryDirection, color: Color, size: CGFloat, isSelected: Bool) -> some View {
        if direction.directionType == .direct {
            Circle()
                .fill(color)
                .frame(width: size, height: size)
                .overlay {
                    Circle()
                        .stroke(Color.white.opacity(isSelected ? 0.95 : 0.45), lineWidth: isSelected ? 2 : 1)
                }
                .shadow(color: color.opacity(isSelected ? 0.45 : 0), radius: 8, y: 2)
        } else {
            RoundedRectangle(cornerRadius: 3, style: .continuous)
                .fill(color)
                .frame(width: size, height: size)
                .overlay {
                    RoundedRectangle(cornerRadius: 3, style: .continuous)
                        .stroke(Color.white.opacity(isSelected ? 0.95 : 0.45), lineWidth: isSelected ? 2 : 1)
                }
                .shadow(color: color.opacity(isSelected ? 0.45 : 0), radius: 8, y: 2)
        }
    }

    private func selectedSummary(_ enriched: EnrichedPrimaryDirection) -> some View {
        HStack(spacing: 8) {
            Circle()
                .fill(polarityColor(enriched.direction.aspect.polarity))
                .frame(width: 8, height: 8)
            Text(enriched.displaySummary)
                .font(.caption.weight(.semibold))
                .lineLimit(1)
            Text(enriched.ageFormatted)
                .font(.caption.monospaced())
                .foregroundStyle(Color.appAccentFill)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(.regularMaterial, in: Capsule())
        .overlay(Capsule().stroke(Color.appBorder.opacity(0.5), lineWidth: 1))
        .shadow(color: .black.opacity(0.08), radius: 8, y: 3)
    }

    private func tooltipView(for enriched: EnrichedPrimaryDirection) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(enriched.displaySummary)
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(.primary)
                .lineLimit(2)
            Text(enriched.ageFormatted)
                .font(.system(size: 10, design: .monospaced))
                .foregroundStyle(Color.appAccentFill)
            Text("Arco \(enriched.arcFormatted)")
                .font(.system(size: 9, design: .monospaced))
                .foregroundStyle(.secondary)
        }
        .padding(8)
        .frame(width: 210, alignment: .leading)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .stroke(Color.appBorder.opacity(0.6), lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.14), radius: 10, y: 4)
    }

    private func placedDirections(width: CGFloat) -> [TimelinePlacedDirection] {
        var lastXByLane = Array(repeating: CGFloat.leastNormalMagnitude * -1, count: laneCount)
        var output: [TimelinePlacedDirection] = []

        for enriched in directions.sorted(by: { $0.direction.estimatedAge < $1.direction.estimatedAge }) {
            let x = xPosition(age: enriched.direction.estimatedAge, width: width)
            let preferredLane = preferredLane(for: enriched.direction.aspect)
            let lane = availableLane(preferred: preferredLane, x: x, lastXByLane: lastXByLane)
            lastXByLane[lane] = x
            let y = laneTop + CGFloat(lane) * laneGap
            output.append(TimelinePlacedDirection(enriched: enriched, x: x, y: y))
        }

        return output
    }

    private func availableLane(preferred: Int, x: CGFloat, lastXByLane: [CGFloat]) -> Int {
        let ordered = laneOrder(preferred: preferred)
        if let lane = ordered.first(where: { x - lastXByLane[$0] > minimumMarkerSpacing }) {
            return lane
        }
        return ordered.min(by: { lastXByLane[$0] < lastXByLane[$1] }) ?? preferred
    }

    private func laneOrder(preferred: Int) -> [Int] {
        Array(0..<laneCount).sorted { lhs, rhs in
            abs(lhs - preferred) < abs(rhs - preferred)
        }
    }

    private func preferredLane(for aspect: PDaspect) -> Int {
        switch aspect {
        case .conjunction: return 0
        case .sextile: return 1
        case .square: return 2
        case .trine: return 3
        case .opposition: return 4
        }
    }

    private func ageTicks(step: Double) -> [Double] {
        let start = ceil(ageDomain.lowerBound / step) * step
        let end = floor(ageDomain.upperBound / step) * step
        guard start <= end else { return [] }
        return Array(stride(from: start, through: end, by: step))
    }

    private func xPosition(age: Double, width: CGFloat) -> CGFloat {
        let lower = ageDomain.lowerBound
        let span = max(ageDomain.upperBound - lower, 1)
        let inset: CGFloat = 36
        let available = max(width - inset * 2, 1)
        return inset + CGFloat((age - lower) / span) * available
    }

    private func clampedTooltipX(_ x: CGFloat) -> CGFloat {
        min(max(x, 110), 10000)
    }

    private func polarityColor(_ polarity: String) -> Color {
        switch polarity {
        case "benefico": return Color(hex: "#16A34A")
        case "malefico": return Color(hex: "#DC2626")
        case "mixto": return Color(hex: "#D97706")
        default: return Color(hex: "#64748B")
        }
    }

    private func toneColor(_ tone: PrimaryDirectionTimelineTone) -> Color {
        switch tone {
        case .favorable: return Color(hex: "#16A34A")
        case .challenging: return Color(hex: "#DC2626")
        case .mixed: return Color(hex: "#D97706")
        }
    }
}

private struct TimelinePlacedDirection: Identifiable {
    var id: UUID { enriched.id }
    let enriched: EnrichedPrimaryDirection
    let x: CGFloat
    let y: CGFloat
}
