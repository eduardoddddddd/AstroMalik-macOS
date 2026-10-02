import SwiftUI

/// Sections of the side panel, in the order a newcomer should visit them.
enum AstroPanelSection: String, CaseIterable, Identifiable {
    case guia = "Guía", mapa = "Mapa", lugar = "Lugar", relocada = "Relocada", comparar = "Comparar", datos = "Datos"
    var id: String { rawValue }
    var systemImage: String {
        switch self {
        case .guia: return "questionmark.circle"
        case .mapa: return "map"
        case .lugar: return "mappin.and.ellipse"
        case .relocada: return "house"
        case .comparar: return "square.stack.3d.up"
        case .datos: return "tablecells"
        }
    }
}

/// Compact icon + label tabs: six segments do not fit a 330 pt panel as text.
struct AstroPanelTabBar: View {
    @Binding var selection: AstroPanelSection
    let badges: [AstroPanelSection: String]

    var body: some View {
        HStack(spacing: 2) {
            ForEach(AstroPanelSection.allCases) { section in
                Button { selection = section } label: {
                    VStack(spacing: 2) {
                        Image(systemName: section.systemImage).font(.system(size: 14))
                        Text(section.rawValue).font(.system(size: 10)).lineLimit(1)
                    }
                    .frame(maxWidth: .infinity).padding(.vertical, 5)
                    .background(selection == section ? Color.appAccentFill.opacity(0.18) : Color.clear,
                                in: RoundedRectangle(cornerRadius: 6))
                    .overlay(alignment: .topTrailing) {
                        if let badge = badges[section] {
                            Text(badge).font(.system(size: 9, weight: .bold)).padding(.horizontal, 4)
                                .background(Color.appAccentFill, in: Capsule()).foregroundStyle(Color.appAccentForeground)
                        }
                    }
                }
                .buttonStyle(.plain)
                .accessibilityLabel(section.rawValue)
                .accessibilityAddTraits(selection == section ? [.isSelected, .isButton] : .isButton)
            }
        }
        .padding(2)
        .background(Color.appSurface, in: RoundedRectangle(cornerRadius: 8))
        .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.appBorder, lineWidth: 1))
    }
}

/// Introduction for someone who has never used astrocartography, written in the
/// vocabulary and flow of this program.
struct AstroGuideView: View {
    let chartName: String?
    let visibleLineCount: Int
    let comparisonCount: Int
    let savedCount: Int
    let policy: AstroProximityPolicy
    let onGo: (AstroPanelSection) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Guía rápida").font(.title3.bold())
            status
            block("¿Qué es la astrocartografía?", """
                En el instante de tu nacimiento, cada planeta estaba en algún punto del cielo visto desde \
                cada lugar de la Tierra. La astrocartografía marca sobre un mapa los lugares donde un planeta \
                estaba justo en uno de los cuatro puntos clave del cielo: saliendo por el horizonte este, \
                poniéndose por el oeste, en lo más alto o en lo más bajo. Cada una de esas franjas es una línea.
                """)
            block("Cómo se lee en AstroMalik", """
                Con tu carta activa se dibujan 10 planetas × 4 ángulos = 40 líneas. El color indica el planeta \
                y el trazo indica el ángulo. La tradición lee cada línea como un tono simbólico del lugar por \
                el que pasa. Es una forma de explorar y reflexionar, no una predicción ni una medida de efectos.
                """)
            angles
            steps
            block("Qué significa «cerca»", """
                Una línea se considera cerca si pasa a \(Int(policy.nearKm)) km o menos del lugar, y regional \
                hasta \(Int(policy.regionalKm)) km. Son umbrales del programa que puedes cambiar en la pestaña \
                Lugar. No miden fuerza: una línea a 20 km no es «más intensa» que una a 80 km; solo está más cerca. \
                Otras escuelas usan radios distintos, así que conviene leer con criterio.
                """)
            block("Qué conviene saber antes de fiarte", """
                La hora de nacimiento importa. Un error de 4 minutos desplaza todas las líneas aproximadamente \
                1° de longitud, unos 110 km sobre el ecuador. Si tu hora es dudosa, trata las líneas como una \
                zona, no como una frontera. El cálculo es local y no usa Internet; solo el mapa base de Apple \
                puede necesitar conexión. Los textos son lecturas simbólicas originales de AstroMalik.
                """)
            glossary
        }
    }

    @ViewBuilder private var status: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(chartName.map { "Carta activa: \($0)" } ?? "Sin carta activa: elígela arriba para empezar.").font(.callout.bold())
            Text("\(visibleLineCount) de 40 líneas visibles · \(comparisonCount) lugares en comparación · \(savedCount) guardados")
                .font(.caption).foregroundStyle(.secondary)
        }
        .padding(10).frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.appSurface, in: RoundedRectangle(cornerRadius: 8))
    }

    private var angles: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Los cuatro ángulos").font(.headline)
            angleRow("ASC · puntos", "Ascendente: identidad, cuerpo y presencia; cómo te sientes y te ven al llegar.")
            angleRow("DSC · raya y punto", "Descendente: los otros; pareja, socios, acuerdos y encuentros.")
            angleRow("MC · línea continua", "Medio Cielo: vida pública, vocación y reputación.")
            angleRow("IC · rayas", "Fondo del Cielo: hogar, raíces, familia y vida privada.")
        }
    }

    private func angleRow(_ name: String, _ meaning: String) -> some View {
        VStack(alignment: .leading, spacing: 1) {
            Text(name).font(.caption.bold()).foregroundStyle(Color.appSecondaryAccent)
            Text(meaning).font(.callout).fixedSize(horizontal: false, vertical: true)
        }
    }

    private var steps: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Paso a paso").font(.headline)
            step(.mapa, "1 · Explora el mapa", "Filtra por planeta, ángulo o por tema (profesión, pareja, hogar…). Pulsa una línea para leer qué significa.")
            step(.lugar, "2 · Elige un lugar", "Busca una ciudad, escribe coordenadas o pulsa en el mapa. Verás un resumen de qué líneas pasan cerca y sus lecturas completas.")
            step(.relocada, "3 · Mira la carta relocada", "Las casas y ángulos de tu carta si hubieras nacido en ese lugar, con el mismo instante. Tu carta natal no cambia.")
            step(.comparar, "4 · Compara lugares", "Hasta 6 lugares a la vez, con un ranking según el tema que te interese.")
            step(.datos, "5 · Datos y precisión", "Distancias exactas, cotas de error y cómo se calcularon, por si quieres comprobarlo.")
        }
    }

    private func step(_ section: AstroPanelSection, _ title: String, _ detail: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack {
                Text(title).font(.callout.bold())
                Spacer()
                Button("Ir a \(section.rawValue)") { onGo(section) }.controlSize(.small)
            }
            Text(detail).font(.caption).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
        }
    }

    private var glossary: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Glosario mínimo").font(.headline)
            term("Línea", "Franja de la Tierra donde un planeta ocupaba uno de los cuatro ángulos en tu nacimiento.")
            term("Carta relocada", "Tu mismo instante de nacimiento visto desde otro lugar: cambian casas y ángulos, no los planetas.")
            term("Tema", "Conjunto de líneas que la tradición asocia con un área de vida. Sirve para filtrar y ordenar; no puntúa.")
            term("Cerca / regional", "Banda de distancia a una línea, definida por el programa.")
        }
    }

    private func term(_ name: String, _ meaning: String) -> some View {
        (Text(name + ": ").bold() + Text(meaning)).font(.caption).fixedSize(horizontal: false, vertical: true)
    }

    private func block(_ title: String, _ text: String) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(title).font(.headline)
            Text(text).font(.callout).fixedSize(horizontal: false, vertical: true)
        }
    }
}

/// «Qué hay aquí» for the selected place, before any technical number.
struct AstroPlaceSummaryCard: View {
    let summary: AstroPlaceSummary
    let activeTheme: AstroTheme?
    let onSelectLine: (AstroLineID) -> Void
    let onSelectTheme: (AstroTheme?) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Resumen del lugar").font(.headline)
            Text(summary.headline).font(.callout.bold()).fixedSize(horizontal: false, vertical: true)
            ForEach(summary.lines) { line in
                Button { onSelectLine(line.proximity.lineID) } label: {
                    VStack(alignment: .leading, spacing: 1) {
                        Text("\(line.band.rawValue) · \(line.phrase)").font(.caption.bold())
                        if let gist = line.gist { Text(gist).font(.caption).foregroundStyle(.secondary) }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .buttonStyle(.plain)
                .accessibilityHint("Selecciona la línea en el mapa")
            }
            if !summary.themes.isEmpty {
                Text("Temas con líneas cerca").font(.caption.bold()).padding(.top, 4)
                ForEach(summary.themes) { activity in
                    Button { onSelectTheme(activeTheme == activity.theme ? nil : activity.theme) } label: {
                        HStack(alignment: .firstTextBaseline) {
                            Image(systemName: activeTheme == activity.theme ? "checkmark.circle.fill" : "circle").font(.caption)
                            Text(activity.theme.title).font(.caption)
                            Spacer()
                            Text(counts(activity)).font(.caption2.monospacedDigit()).foregroundStyle(.secondary)
                        }
                    }
                    .buttonStyle(.plain)
                    .accessibilityHint(activeTheme == activity.theme ? "Quita el filtro por tema" : "Filtra el mapa por este tema")
                }
                if summary.quietThemeCount > 0 {
                    Text("\(summary.quietThemeCount) temas sin líneas dentro del umbral regional.").font(.caption2).foregroundStyle(.secondary)
                }
            }
            Text("Los temas ordenan por cercanía de sus líneas; no puntúan ni predicen. La lectura completa de cada línea está debajo.")
                .font(.caption2).foregroundStyle(.secondary)
        }
        .padding(10).frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.appSurface, in: RoundedRectangle(cornerRadius: 8))
        .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.appBorder, lineWidth: 1))
    }

    private func counts(_ activity: AstroThemeActivity) -> String {
        var parts: [String] = []
        if activity.nearCount > 0 { parts.append("\(activity.nearCount) cerca") }
        if activity.regionalCount > 0 { parts.append("\(activity.regionalCount) regional") }
        return parts.joined(separator: " · ")
    }
}

/// Ranks compared and valid saved places for one theme.
struct AstroThemeRankingView: View {
    @Binding var theme: AstroTheme
    let entries: [AstroPlaceRankingEntry]
    let policy: AstroProximityPolicy

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Ranking por tema").font(.headline)
            Picker("Tema", selection: $theme) {
                ForEach(AstroTheme.allCases) { Text($0.title).tag($0) }
            }.labelsHidden().accessibilityLabel("Tema para ordenar los lugares")
            Text(theme.explanation).font(.caption).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
            if entries.isEmpty {
                Text("Añade lugares a la comparación o guarda alguno con resultado vigente para ordenarlos.").font(.caption)
            }
            ForEach(entries) { entry in
                HStack(alignment: .firstTextBaseline) {
                    Text("\(entry.rank).").font(.callout.bold().monospacedDigit())
                    VStack(alignment: .leading, spacing: 1) {
                        Text(entry.place.name).font(.callout)
                        Text(detail(entry.activity)).font(.caption).foregroundStyle(.secondary)
                    }
                }
            }
            Text(String(format: "Orden: más líneas del tema a ≤%.0f km, luego a ≤%.0f km, luego la más cercana; empates por nombre. Criterio de lectura del programa, no una puntuación ni una recomendación de dónde vivir.",
                        policy.nearKm, policy.regionalKm)).font(.caption2).foregroundStyle(.secondary)
        }
    }

    private func detail(_ activity: AstroThemeActivity) -> String {
        guard let nearest = activity.nearest else { return "Sin líneas de este tema con distancia definida." }
        let counts = "\(activity.nearCount) cerca · \(activity.regionalCount) regional"
        return "\(counts) · más cercana: \(AstroPlaceSummaryBuilder.phrase(nearest))"
    }
}
