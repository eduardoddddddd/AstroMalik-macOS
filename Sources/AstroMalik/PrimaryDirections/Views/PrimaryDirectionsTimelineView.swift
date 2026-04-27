import SwiftUI

// MARK: - PrimaryDirectionsTimelineView
// Timeline horizontal scrollable. Cada marcador = una dirección primaria.
// Color según polaridad del aspecto. Hover tooltip. Click → selección.

struct PrimaryDirectionsTimelineView: View {
    let directions: [EnrichedPrimaryDirection]
    let timeline: [PrimaryDirectionTimelineEntry]
    let ageDomain: ClosedRange<Double>
    @Binding var selectedDirection: EnrichedPrimaryDirection?

    // Hover state por dirección
    @State private var hoveredId: UUID? = nil
    // Offset de scroll (para zoom futuro)
    @State private var magnification: CGFloat = 1.0

    private let markerHeight: CGFloat = 120
    private let ageStep: Double = 5   // marcadores de guía cada 5 años

    var body: some View {
        GeometryReader { geo in
            ScrollView(.horizontal, showsIndicators: true) {
                ZStack(alignment: .topLeading) {
                    // Fondo con raíles de edad
                    ageRailsLayer(width: timelineWidth(geo: geo))

                    // Marcadores de décadas
                    decadeLabels(width: timelineWidth(geo: geo))

                    // Marcadores de direcciones
                    ForEach(directions) { enriched in
                        directionMarker(for: enriched, totalWidth: timelineWidth(geo: geo))
                    }
                }
                .frame(width: timelineWidth(geo: geo), height: markerHeight + 40)
                .contentShape(Rectangle())
            }
            .background(Color.appBackground)
            .gesture(MagnificationGesture()
                .onChanged { value in magnification = max(0.5, min(3.0, value)) }
                .onEnded { _ in }
            )
        }
    }

    // MARK: - Layout helpers

    private func timelineWidth(geo: GeometryProxy) -> CGFloat {
        let base = max(geo.size.width, 1200)
        return base * magnification
    }

    /// Convierte edad (años) a posición X en la timeline.
    private func xPosition(age: Double, totalWidth: CGFloat) -> CGFloat {
        let lower = ageDomain.lowerBound
        let span = max(ageDomain.upperBound - lower, 1)
        return CGFloat((age - lower) / span) * totalWidth
    }

    // MARK: - Sub-views

    @ViewBuilder
    private func ageRailsLayer(width: CGFloat) -> some View {
        let start = floor(ageDomain.lowerBound / ageStep) * ageStep
        let end = ceil(ageDomain.upperBound / ageStep) * ageStep
        ForEach(Array(stride(from: start, through: end, by: ageStep)), id: \.self) { age in
            let x = xPosition(age: age, totalWidth: width)
            Rectangle()
                .fill(Color.appBorder.opacity(0.3))
                .frame(width: 1, height: markerHeight + 40)
                .offset(x: x)
        }
    }

    @ViewBuilder
    private func decadeLabels(width: CGFloat) -> some View {
        ForEach(timeline) { entry in
            let x = xPosition(age: Double(entry.decadeStart), totalWidth: width)
            VStack(alignment: .leading, spacing: 2) {
                Text(entry.label)
                    .font(.system(size: 9, weight: .medium, design: .monospaced))
                    .foregroundStyle(.secondary)
                Text(entry.overallTone.emoji)
                    .font(.system(size: 9))
            }
            .offset(x: x + 4, y: markerHeight + 4)
        }
    }

    @ViewBuilder
    private func directionMarker(for enriched: EnrichedPrimaryDirection, totalWidth: CGFloat) -> some View {
        let dir = enriched.direction
        let x = xPosition(age: dir.estimatedAge, totalWidth: totalWidth)
        let isSelected = selectedDirection?.id == dir.id
        let isHovered = hoveredId == dir.id
        let color = polarityColor(dir.aspect.polarity)
        let markerH = markerHeight(for: dir)

        ZStack(alignment: .top) {
            // Stem
            Rectangle()
                .fill(color.opacity(isSelected ? 1.0 : 0.55))
                .frame(width: isSelected ? 3 : 2, height: markerH)

            // Cap
            Circle()
                .fill(color)
                .frame(width: isSelected ? 14 : 10, height: isSelected ? 14 : 10)
                .shadow(color: color.opacity(0.5), radius: isSelected ? 6 : 0)
                .offset(y: -7)
        }
        .offset(x: x - 1, y: markerHeight - markerH)
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.15)) {
                hoveredId = hovering ? dir.id : nil
            }
        }
        .onTapGesture {
            withAnimation(.easeInOut(duration: 0.18)) {
                selectedDirection = (selectedDirection?.id == dir.id) ? nil : enriched
            }
        }
        .overlay(alignment: .top) {
            if isHovered || isSelected {
                tooltipView(for: enriched)
                    .offset(x: -94, y: -58)
                    .transition(.opacity.combined(with: .scale(scale: 0.95, anchor: .bottom)))
                    .zIndex(100)
            }
        }
        .animation(.easeInOut(duration: 0.15), value: isHovered)
        .animation(.easeInOut(duration: 0.15), value: isSelected)
    }

    private func tooltipView(for enriched: EnrichedPrimaryDirection) -> some View {
        let dir = enriched.direction
        return VStack(alignment: .leading, spacing: 3) {
            Text(enriched.displaySummary)
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(.primary)
            Text(enriched.ageFormatted)
                .font(.system(size: 10))
                .foregroundStyle(.secondary)
            HStack(spacing: 4) {
                Text("Arco: \(enriched.arcFormatted)")
                Text(dir.directionType == .direct ? "Directa" : "Conversa")
                    .foregroundStyle(.secondary)
            }
            .font(.system(size: 9, design: .monospaced))
        }
        .padding(8)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(Color.appBorder.opacity(0.6), lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.15), radius: 6, y: 2)
        .frame(width: 200)
    }

    // MARK: - Color helpers

    private func polarityColor(_ polarity: String) -> Color {
        switch polarity {
        case "benefico":  return Color(hex: "#16A34A")
        case "malefico":  return Color(hex: "#DC2626")
        case "mixto":     return Color(hex: "#D97706")
        default:          return Color(hex: "#6B7280")
        }
    }

    /// Altura del marcador proporcional a la relevancia (aspecto mayor = más alto).
    private func markerHeight(for dir: PrimaryDirection) -> CGFloat {
        switch dir.aspect {
        case .conjunction, .opposition: return markerHeight
        case .square:                   return markerHeight * 0.85
        case .trine:                    return markerHeight * 0.75
        case .sextile:                  return markerHeight * 0.65
        }
    }
}
