import SwiftUI

struct NatalWheelView: View {
    let chart: NatalChart
    @Binding var selectedKey: String?

    private var aspects: [NatalAspect] {
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

    var body: some View {
        GeometryReader { proxy in
            let side = min(proxy.size.width, proxy.size.height)
            let center = CGPoint(x: proxy.size.width / 2, y: proxy.size.height / 2)
            let outerRadius = side * 0.45
            let planetRadius = side * 0.34
            let aspectRadius = side * 0.25

            ZStack {
                Canvas { context, size in
                    drawWheel(context: &context, center: center, outerRadius: outerRadius, planetRadius: planetRadius)
                    drawAspects(context: &context, center: center, radius: aspectRadius)
                }

                ForEach(0..<12, id: \.self) { index in
                    let longitude = Double(index * 30 + 15)
                    Text(SIGN_LABELS[index].split(separator: " ").first.map(String.init) ?? "")
                        .font(.title3)
                        .position(point(for: longitude, center: center, radius: outerRadius - 22))
                        .allowsHitTesting(false)
                }

                ForEach(chart.bodies) { body in
                    wheelButton(
                        key: body.key,
                        label: body.labelSymbol,
                        position: point(for: body.longitude, center: center, radius: planetRadius)
                    )
                }

                wheelButton(
                    key: "ASC",
                    label: "ASC",
                    position: point(for: chart.ascendant.longitude, center: center, radius: planetRadius + 28),
                    compact: false
                )
                wheelButton(
                    key: "MC",
                    label: "MC",
                    position: point(for: chart.mc.longitude, center: center, radius: planetRadius + 28),
                    compact: false
                )
            }
        }
        .background(Color.appSurface)
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(Color.appBorder, lineWidth: 1)
        )
    }

    private func wheelButton(key: String, label: String, position: CGPoint, compact: Bool = true) -> some View {
        Button {
            selectedKey = key
        } label: {
            Text(label)
                .font(compact ? .headline : .caption.weight(.bold))
                .foregroundColor(selectedKey == key ? .appAccentForeground : .appPrimaryText)
                .frame(width: compact ? 30 : 42, height: compact ? 30 : 24)
                .background(selectedKey == key ? Color.appAccentFill : Color.appPanel)
                .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .stroke(Color.appBorder.opacity(0.7), lineWidth: 1)
                )
        }
        .buttonStyle(.plain)
        .position(position)
    }

    private func drawWheel(
        context: inout GraphicsContext,
        center: CGPoint,
        outerRadius: CGFloat,
        planetRadius: CGFloat
    ) {
        let circles = [outerRadius, planetRadius, outerRadius * 0.58]
        for radius in circles {
            context.stroke(
                Path(ellipseIn: CGRect(x: center.x - radius, y: center.y - radius, width: radius * 2, height: radius * 2)),
                with: .color(Color.appBorder),
                lineWidth: 1
            )
        }

        for index in 0..<12 {
            let longitude = Double(index * 30)
            var path = Path()
            path.move(to: point(for: longitude, center: center, radius: outerRadius * 0.58))
            path.addLine(to: point(for: longitude, center: center, radius: outerRadius))
            context.stroke(path, with: .color(Color.appBorder.opacity(0.75)), lineWidth: 1)
        }

        for cusp in chart.cusps {
            var path = Path()
            path.move(to: point(for: cusp, center: center, radius: outerRadius * 0.12))
            path.addLine(to: point(for: cusp, center: center, radius: outerRadius * 0.58))
            context.stroke(path, with: .color(Color.appSecondaryAccent.opacity(0.45)), lineWidth: 1)
        }
    }

    private func drawAspects(context: inout GraphicsContext, center: CGPoint, radius: CGFloat) {
        let bodyMap = Dictionary(uniqueKeysWithValues: chart.bodies.map { ($0.key, $0) })
        for aspect in aspects {
            guard let a = bodyMap[aspect.keyA], let b = bodyMap[aspect.keyB] else { continue }
            var path = Path()
            path.move(to: point(for: a.longitude, center: center, radius: radius))
            path.addLine(to: point(for: b.longitude, center: center, radius: radius))
            context.stroke(path, with: .color(color(for: aspect.aspKey).opacity(0.55)), lineWidth: 1.2)
        }
    }

    private func point(for longitude: Double, center: CGPoint, radius: CGFloat) -> CGPoint {
        let radians = (longitude - 90) * .pi / 180
        return CGPoint(
            x: center.x + cos(radians) * radius,
            y: center.y + sin(radians) * radius
        )
    }

    private func color(for aspectKey: String) -> Color {
        switch aspectKey {
        case "CONJUNCION": return Color(hex: "#d97706")
        case "SEXTIL": return Color(hex: "#2563eb")
        case "CUADRADO": return Color(hex: "#dc2626")
        case "TRIGONO": return Color(hex: "#15803d")
        case "OPOSICION": return Color(hex: "#a21caf")
        default: return .secondary
        }
    }
}

private extension PlanetBody {
    var labelSymbol: String {
        label.split(separator: " ").first.map(String.init) ?? label
    }
}
