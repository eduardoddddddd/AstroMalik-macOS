import SwiftUI

struct GuidedReadingView: View {
    let chart: NatalChart
    let interpretaciones: [Interpretation]
    @Binding var synthesis: String
    @Binding var selectedFocusKey: String?

    private var sun: PlanetBody? { chart.bodies.first(where: { $0.key == "SOL" }) }
    private var moon: PlanetBody? { chart.bodies.first(where: { $0.key == "LUNA" }) }
    private var ascRuler: PlanetBody? {
        let rulerKey = rulerForAscendant
        return chart.bodies.first(where: { $0.key == rulerKey })
    }
    private var rulerForAscendant: String {
        switch AstroEngine.degToSignKey(chart.ascendant.longitude) {
        case "ARIES": return "MARTE"
        case "TAURO": return "VENUS"
        case "GEMINIS": return "MERCURIO"
        case "CANCER": return "LUNA"
        case "LEO": return "SOL"
        case "VIRGO": return "MERCURIO"
        case "LIBRA": return "VENUS"
        case "ESCORPIO": return "MARTE"
        case "SAGITARIO": return "JUPITER"
        case "CAPRICORNIO": return "SATURNO"
        case "ACUARIO": return "SATURNO"
        case "PISCIS": return "JUPITER"
        default: return "SOL"
        }
    }

    private var topAspects: [NatalAspect] {
        let rawPlanets = Dictionary(uniqueKeysWithValues: chart.bodies.map { body in
            (body.key, AstroEngine.RawPlanet(
                key: body.key,
                label: body.label,
                deg: body.longitude,
                speed: body.retrograde ? -1 : 1,
                retro: body.retrograde
            ))
        })
        return Array(AstroEngine.computeNatalAspects(planets: rawPlanets).prefix(8))
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                readingBlock("Tríada base", systemImage: "triangle") {
                    if let sun { focusRow("Sol", body: sun, key: "SOL") }
                    if let moon { focusRow("Luna", body: moon, key: "LUNA") }
                    angularRow("Ascendente", value: chart.ascendant.formatted, key: "ASC")
                }

                readingBlock("Regente del Ascendente", systemImage: "key") {
                    if let ascRuler {
                        focusRow(ascRuler.label, body: ascRuler, key: ascRuler.key)
                        Text("Regente clásico de \(AstroEngine.degToSign(chart.ascendant.longitude).components(separatedBy: " ").prefix(2).joined(separator: " ")).")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }

                readingBlock("Casas angulares", systemImage: "scope") {
                    angularRow("Ascendente", value: chart.ascendant.formatted, key: "ASC")
                    angularRow("Medio Cielo", value: chart.mc.formatted, key: "MC")
                    ForEach(chart.bodies.filter { [1, 4, 7, 10].contains($0.house) }) { body in
                        focusRow(body.label, body: body, key: body.key)
                    }
                }

                readingBlock("Aspectos dominantes", systemImage: "line.diagonal") {
                    ForEach(topAspects) { aspect in
                        Button {
                            selectedFocusKey = aspect.keyA
                        } label: {
                            HStack {
                                Text("\(aspect.labelA) \(aspect.aspLabel) \(aspect.labelB)")
                                    .font(.subheadline)
                                Spacer()
                                Text(String(format: "%.2f°", aspect.orb))
                                    .font(.caption.monospacedDigit())
                                    .foregroundColor(.secondary)
                            }
                        }
                        .buttonStyle(.plain)
                    }
                }

                readingBlock("Síntesis editable", systemImage: "square.and.pencil") {
                    TextEditor(text: $synthesis)
                        .frame(minHeight: 160)
                        .scrollContentBackground(.hidden)
                        .background(Color.appInputBackground)
                        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: 8, style: .continuous)
                                .stroke(Color.appBorder, lineWidth: 1)
                        )
                }
            }
            .padding(18)
        }
        .background(Color.appBackground)
    }

    private func readingBlock<Content: View>(
        _ title: String,
        systemImage: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Label(title, systemImage: systemImage)
                .appSectionHeader()
            content()
        }
        .appCard()
    }

    private func focusRow(_ title: String, body: PlanetBody, key: String) -> some View {
        Button {
            selectedFocusKey = key
        } label: {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.subheadline.weight(.medium))
                        .foregroundColor(.appPrimaryText)
                    Text("\(body.formatted) · Casa \(body.house)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                Spacer()
                if !summary(for: key).isEmpty {
                    Image(systemName: "text.alignleft")
                        .foregroundColor(.appSecondaryAccent)
                }
            }
        }
        .buttonStyle(.plain)
    }

    private func angularRow(_ title: String, value: String, key: String) -> some View {
        Button {
            selectedFocusKey = key
        } label: {
            HStack {
                Text(title)
                    .font(.subheadline.weight(.medium))
                    .foregroundColor(.appPrimaryText)
                Spacer()
                Text(value)
                    .font(.caption.monospacedDigit())
                    .foregroundColor(.secondary)
            }
        }
        .buttonStyle(.plain)
    }

    private func summary(for key: String) -> String {
        interpretaciones.first { interpretation in
            interpretation.clave.hasPrefix("\(key)_") || interpretation.clave.contains("_\(key)_")
        }?.texto ?? ""
    }
}

enum ReadingNoteBuilder {
    static func markdown(chart: NatalChart, interpretations: [Interpretation], synthesis: String) -> String {
        var lines: [String] = [
            "# Lectura natal - \(chart.name)",
            "",
            "- Fecha: \(chart.birthDate) \(chart.birthTime)",
            "- Lugar: \(chart.placeName)",
            "- Zona: \(chart.timezone)",
            "- ASC: \(chart.ascendant.formatted)",
            "- MC: \(chart.mc.formatted)",
            "",
            "## Síntesis",
            synthesis.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "_Pendiente de completar._" : synthesis,
            "",
            "## Puntos principales",
        ]

        let priorityKeys = ["ASC", "SOL", "LUNA"]
        for key in priorityKeys {
            let matching = interpretations.filter {
                $0.clave.hasPrefix("\(key)_") || $0.clave.contains("_\(key)_")
            }
            for interpretation in matching.prefix(2) {
                lines += [
                    "",
                    "### \(interpretation.titulo)",
                    interpretation.texto,
                ]
            }
        }

        return lines.joined(separator: "\n")
    }
}
