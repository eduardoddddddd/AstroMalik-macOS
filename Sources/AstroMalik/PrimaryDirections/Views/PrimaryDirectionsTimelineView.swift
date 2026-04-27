import SwiftUI

struct PrimaryDirectionsTimelineView: View {
    let directions: [EnrichedPrimaryDirection]
    let timeline: [PrimaryDirectionTimelineEntry]
    let ageDomain: ClosedRange<Double>
    @Binding var selectedDirection: EnrichedPrimaryDirection?

    @State private var hoveredId: UUID?
    @State private var activeClusterID: String?

    private let axisY: CGFloat = 132
    private let laneTop: CGFloat = 28
    private let laneGap: CGFloat = 14
    private let laneCount = 6
    private let minimumMarkerSpacing: CGFloat = 16
    private let leftInset: CGFloat = 72
    private let rightInset: CGFloat = 36

    private let laneLabels = ["ASC", "MC", "Sol", "Luna", "Otros", "DSC/IC"]

    var body: some View {
        GeometryReader { geo in
            let width = max(geo.size.width, 680)
            let clusters = timelineClusters(width: width)

            ZStack(alignment: .topLeading) {
                backgroundBands(width: width)
                laneLabelLayer
                ageGrid(width: width)
                axis(width: width)

                ForEach(clusters) { cluster in
                    if cluster.events.count > 1 {
                        clusterMarker(cluster)
                    } else if let enriched = cluster.events.first {
                        directionMarker(enriched, x: cluster.x, y: cluster.y)
                    }
                }

                if let selected = selectedDirection {
                    selectedSummary(selected)
                        .position(
                            x: min(max(xPosition(age: selected.direction.estimatedAge, width: width), 170), width - 170),
                            y: 14
                        )
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

    private var laneLabelLayer: some View {
        ZStack(alignment: .topLeading) {
            ForEach(Array(laneLabels.enumerated()), id: \.offset) { index, label in
                Text(label)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .frame(width: 52, alignment: .trailing)
                    .position(x: 30, y: laneTop + CGFloat(index) * laneGap)
            }
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
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(toneColor(entry.overallTone).opacity(0.055))
                        .frame(width: max(0, x2 - x1 - 4), height: 112)
                        .offset(x: x1 + 2, y: 24)
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
                    .frame(width: 1, height: isMajor ? 132 : 106)
                    .offset(x: x, y: isMajor ? 24 : 36)

                if isMajor {
                    Text("\(Int(age))")
                        .font(.caption.monospaced())
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
                .frame(width: width - leftInset, height: 1)
                .offset(x: leftInset, y: axisY)

            HStack(spacing: 12) {
                legendItem("Fluido", color: Color(hex: "#16A34A"))
                legendItem("Tenso", color: Color(hex: "#DC2626"))
                legendItem("Neutro", color: Color(hex: "#64748B"))
                Spacer()
                Text("\(Int(ageDomain.lowerBound))-\(Int(ageDomain.upperBound)) años")
                    .font(.caption.monospaced())
                    .foregroundStyle(.secondary)
            }
            .padding(.leading, leftInset)
            .padding(.trailing, 16)
            .position(x: width / 2, y: 168)
        }
    }

    private func legendItem(_ label: String, color: Color) -> some View {
        HStack(spacing: 5) {
            Circle()
                .fill(color)
                .frame(width: 7, height: 7)
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private func directionMarker(_ enriched: EnrichedPrimaryDirection, x: CGFloat, y: CGFloat) -> some View {
        let dir = enriched.direction
        let isSelected = selectedDirection?.id == enriched.id
        let isHovered = hoveredId == enriched.id
        let color = polarityColor(dir.aspect.polarity)
        let markerSize: CGFloat = isSelected ? 16 : (isHovered ? 13 : 10)

        return ZStack {
            Path { path in
                path.move(to: CGPoint(x: x, y: axisY - 2))
                path.addLine(to: CGPoint(x: x, y: y + 8))
            }
            .stroke(
                color.opacity(isSelected ? 0.9 : 0.35),
                style: StrokeStyle(lineWidth: isSelected ? 2.5 : 1.5, lineCap: .round)
            )

            markerDot(for: dir, color: color, size: markerSize, isSelected: isSelected)
                .position(x: x, y: y)

            if isHovered {
                tooltipView(for: enriched)
                    .position(x: clampedTooltipX(x), y: max(62, y - 48))
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
        .accessibilityLabel("\(enriched.displaySummary), \(enriched.ageFormatted)")
        .accessibilityAddTraits(isSelected ? [.isSelected, .isButton] : .isButton)
        .animation(.easeInOut(duration: 0.12), value: isSelected)
        .zIndex(isSelected || isHovered ? 10 : 1)
    }

    private func clusterMarker(_ cluster: TimelineCluster) -> some View {
        let isSelected = cluster.events.contains { $0.id == selectedDirection?.id }
        let color = clusterTone(cluster)
        let size: CGFloat = min(24, 14 + CGFloat(cluster.events.count))

        return ZStack {
            Path { path in
                path.move(to: CGPoint(x: cluster.x, y: axisY - 2))
                path.addLine(to: CGPoint(x: cluster.x, y: cluster.y + 10))
            }
            .stroke(color.opacity(isSelected ? 0.9 : 0.35), style: StrokeStyle(lineWidth: isSelected ? 2.5 : 1.5, lineCap: .round))

            Circle()
                .fill(color)
                .frame(width: size, height: size)
                .overlay {
                    Text("\(cluster.events.count)")
                        .font(.system(size: 9, weight: .bold, design: .monospaced))
                        .foregroundStyle(.white)
                }
                .overlay {
                    Circle().stroke(Color.white.opacity(isSelected ? 0.95 : 0.55), lineWidth: isSelected ? 2 : 1)
                }
                .position(x: cluster.x, y: cluster.y)
        }
        .contentShape(Rectangle())
        .onTapGesture {
            activeClusterID = cluster.id
        }
        .popover(isPresented: Binding(
            get: { activeClusterID == cluster.id },
            set: { if !$0 { activeClusterID = nil } }
        )) {
            clusterPopover(cluster)
                .frame(width: 320)
                .padding(12)
        }
        .accessibilityLabel("Cluster de \(cluster.events.count) direcciones en carril \(laneLabels[cluster.lane])")
        .accessibilityAddTraits(.isButton)
        .zIndex(isSelected ? 12 : 4)
    }

    private func clusterPopover(_ cluster: TimelineCluster) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("\(cluster.events.count) direcciones")
                .font(.headline)
            ForEach(cluster.events) { enriched in
                Button {
                    selectedDirection = enriched
                    activeClusterID = nil
                } label: {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(enriched.displaySummary)
                            .font(.caption.weight(.semibold))
                            .lineLimit(2)
                        Text("\(enriched.ageFormatted) · Arco \(enriched.arcFormatted)")
                            .font(.caption.monospaced())
                            .foregroundStyle(Color.appAccentFill)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .buttonStyle(.plain)
            }
        }
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
                .font(.caption.weight(.semibold))
                .foregroundStyle(.primary)
                .lineLimit(2)
            Text(enriched.ageFormatted)
                .font(.caption.monospaced())
                .foregroundStyle(Color.appAccentFill)
            Text("Arco \(enriched.arcFormatted)")
                .font(.caption.monospaced())
                .foregroundStyle(.secondary)
        }
        .padding(8)
        .frame(width: 210, alignment: .leading)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(Color.appBorder.opacity(0.6), lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.14), radius: 10, y: 4)
    }

    private func timelineClusters(width: CGFloat) -> [TimelineCluster] {
        var clusters: [TimelineCluster] = []
        var lastIndexByLane = Array<Int?>(repeating: nil, count: laneCount)

        for enriched in directions.sorted(by: { $0.direction.estimatedAge < $1.direction.estimatedAge }) {
            let lane = preferredLane(for: enriched.direction.significator)
            let x = xPosition(age: enriched.direction.estimatedAge, width: width)
            let y = laneTop + CGFloat(lane) * laneGap

            if let lastIndex = lastIndexByLane[lane],
               x - clusters[lastIndex].x < minimumMarkerSpacing {
                clusters[lastIndex].events.append(enriched)
                clusters[lastIndex].x = (clusters[lastIndex].x + x) / 2
            } else {
                clusters.append(TimelineCluster(lane: lane, x: x, y: y, events: [enriched]))
                lastIndexByLane[lane] = clusters.indices.last
            }
        }

        return clusters
    }

    private func preferredLane(for significator: String) -> Int {
        switch significator {
        case "ASC":
            return 0
        case "MC":
            return 1
        case "SOL":
            return 2
        case "LUNA":
            return 3
        case "DSC", "IC":
            return 5
        default:
            return 4
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
        let available = max(width - leftInset - rightInset, 1)
        return leftInset + CGFloat((age - lower) / span) * available
    }

    private func clampedTooltipX(_ x: CGFloat) -> CGFloat {
        min(max(x, 120), 10000)
    }

    private func clusterTone(_ cluster: TimelineCluster) -> Color {
        let maleficCount = cluster.events.filter { $0.direction.aspect.polarity == "malefico" }.count
        let beneficCount = cluster.events.filter { $0.direction.aspect.polarity == "benefico" }.count
        if maleficCount > beneficCount { return polarityColor("malefico") }
        if beneficCount > maleficCount { return polarityColor("benefico") }
        return polarityColor("neutro")
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

private struct TimelineCluster: Identifiable {
    let lane: Int
    var x: CGFloat
    let y: CGFloat
    var events: [EnrichedPrimaryDirection]

    var id: String {
        "\(lane)-\(events.first?.id.uuidString ?? "empty")-\(events.count)"
    }
}
