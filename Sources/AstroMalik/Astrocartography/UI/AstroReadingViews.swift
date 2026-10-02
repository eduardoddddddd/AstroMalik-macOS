import SwiftUI

/// Full text, always visible: no collapsible controls (project reading policy).
struct AstroReadingCardView: View {
    let entry: AstroReadingEntry

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(entry.title).font(.subheadline.bold())
            layer("Qué suele activar", entry.mechanism)
            layer("Potencial", entry.potential)
            layer("Sombra", entry.shadow)
            layer("Cómo trabajarlo", entry.practice)
            Text("Lectura simbólica original de AstroMalik. Tradición interpretativa, no evidencia de efectos causales ni predicción.")
                .font(.caption2).foregroundStyle(.secondary)
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.appSurface, in: RoundedRectangle(cornerRadius: 8))
        .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.appBorder, lineWidth: 1))
        .textSelection(.enabled)
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Lectura: \(entry.title)")
    }

    private func layer(_ heading: String, _ text: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(heading).font(.caption.bold()).foregroundStyle(Color.appSecondaryAccent)
            Text(text).font(.callout).fixedSize(horizontal: false, vertical: true)
        }
    }
}

/// Shows the text, or an explicit fallback when no editorial text is available.
struct AstroReadingLookupView: View {
    let lookup: AstroReadingLookup

    var body: some View {
        switch lookup {
        case .available(let entry):
            AstroReadingCardView(entry: entry)
        case .missing(let id, let reason):
            VStack(alignment: .leading, spacing: 4) {
                Label("Sin lectura para \(id.body.mapLabel) · \(id.angle.rawValue)", systemImage: "text.badge.xmark")
                    .font(.caption.bold())
                Text(reason).font(.caption)
            }
            .foregroundStyle(Color.appWarning)
            .padding(10).frame(maxWidth: .infinity, alignment: .leading)
            .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.appWarning, lineWidth: 1))
        }
    }
}

/// Distances and interpretation are drawn as two separate blocks per line.
struct AstroPlaceReadingsView: View {
    let set: AstroPlaceReadingSet
    let placeName: String
    let onSelectLine: (AstroLineID) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Lectura de \(placeName)").font(.headline)
            Text(String(format: "Líneas a ≤%.0f km (cerca) y ≤%.0f km (regional), ordenadas por distancia. Los umbrales son parámetros del producto: la banda no mide la intensidad del efecto.",
                        set.policy.nearKm, set.policy.regionalKm))
                .font(.caption).foregroundStyle(.secondary)
            coverageLine
            if set.items.isEmpty {
                Text("Ninguna línea dentro del umbral regional con los filtros actuales. Amplía el umbral o activa más cuerpos y ángulos.")
                    .font(.caption)
            }
            ForEach(set.items) { item in
                VStack(alignment: .leading, spacing: 6) {
                    distanceRow(item)
                    AstroReadingLookupView(lookup: item.lookup)
                }
            }
            if set.omittedDistantCount > 0 {
                Text("\(set.omittedDistantCount) líneas más lejanas que el umbral regional no se listan; siguen en las distancias globales.")
                    .font(.caption).foregroundStyle(.secondary)
            }
        }
    }

    private func distanceRow(_ item: AstroPlaceReadingItem) -> some View {
        Button { onSelectLine(item.proximity.lineID) } label: {
            VStack(alignment: .leading, spacing: 2) {
                Text("Distancia · \(item.proximity.lineID.body.mapLabel) \(item.proximity.lineID.angle.rawValue)")
                    .font(.caption.bold())
                Text(String(format: "%.3f ± %.6f km · %@%@%@", item.proximity.distanceKm, item.proximity.estimatedErrorKm,
                            item.band.rawValue, item.crossesBoundary ? " *" : "", item.isVisibleByFilters ? "" : " (oculta por filtros)"))
                    .font(.caption.monospacedDigit())
            }
        }
        .buttonStyle(.borderless)
        .accessibilityHint("Selecciona la línea en el mapa")
    }

    @ViewBuilder private var coverageLine: some View {
        let coverage = set.coverage
        if coverage.isComplete {
            Text("Cobertura editorial: \(coverage.covered)/\(coverage.total) líneas del lugar\(set.editorialVersion.map { " · \($0)" } ?? "").")
                .font(.caption2).foregroundStyle(.secondary)
        } else {
            Text("Cobertura editorial incompleta: \(coverage.covered)/\(coverage.total). Sin texto: \(coverage.missing.map { "\($0.body.rawValue) \($0.angle.rawValue)" }.joined(separator: ", ")).")
                .font(.caption).foregroundStyle(Color.appWarning)
        }
    }
}
