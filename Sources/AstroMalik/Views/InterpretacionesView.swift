import SwiftUI

struct InterpretacionesView: View {
    var interpretaciones: [Interpretation]

    @State private var expanded: Set<String> = []
    @State private var selectedFilter: InterpretationFilter = .all

    private var filtered: [Interpretation] {
        guard let t = selectedFilter.tipo else { return interpretaciones }
        return interpretaciones.filter { $0.tipo == t }
    }

    var body: some View {
        VStack(spacing: 0) {
            filterBar
            Divider()
            if filtered.isEmpty {
                emptyState
            } else {
                ScrollView {
                    LazyVStack(spacing: 10) {
                        ForEach(filtered) { interp in
                            interpretationRow(interp)
                        }
                    }
                    .padding(18)
                }
            }
        }
        .background(Color.appBackground)
    }

    // MARK: - Filter Bar

    private var filterBar: some View {
        HStack {
            Picker("Tipo", selection: $selectedFilter) {
                ForEach(InterpretationFilter.allCases) { filter in
                    Text(filter.label).tag(filter)
                }
            }
            .pickerStyle(.segmented)
            .frame(maxWidth: 560)
            Spacer()
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 12)
        .background(Color.appPanel)
    }

    // MARK: - Row

    private func interpretationRow(_ interp: Interpretation) -> some View {
        let isExpanded = expanded.contains(interp.id)
        return VStack(alignment: .leading, spacing: 0) {
            Button {
                if isExpanded { expanded.remove(interp.id) }
                else { expanded.insert(interp.id) }
            } label: {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 3) {
                        Text(interp.titulo)
                            .font(.subheadline.weight(.medium))
                            .foregroundColor(.appPrimaryText)
                            .multilineTextAlignment(.leading)
                        if !interp.fuente.isEmpty {
                            Text(interp.fuente)
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }
                    }
                    Spacer()
                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .padding(.top, 2)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            if isExpanded {
                Text(interp.texto)
                    .font(.callout)
                    .foregroundColor(.appPrimaryText.opacity(0.88))
                    .lineSpacing(4)
                    .padding(.horizontal, 16)
                    .padding(.bottom, 14)
                    .padding(.top, 4)
                    .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .background(Color.appPanel)
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(isExpanded ? Color.appAccentFill.opacity(0.45) : Color.appBorder.opacity(0.75), lineWidth: 1)
        )
        .animation(.easeInOut(duration: 0.18), value: isExpanded)
    }

    // MARK: - Empty

    private var emptyState: some View {
        VStack(spacing: 8) {
            Image(systemName: "text.book.closed")
                .font(.system(size: 36))
                .foregroundColor(.secondary)
            Text("Sin interpretaciones disponibles")
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

private enum InterpretationFilter: String, CaseIterable, Identifiable {
    case all
    case planetaSigno
    case planetaCasa
    case aspectos

    var id: String { rawValue }

    var label: String {
        switch self {
        case .all: return "Todas"
        case .planetaSigno: return "Signos"
        case .planetaCasa: return "Casas"
        case .aspectos: return "Aspectos"
        }
    }

    var tipo: InterpretationType? {
        switch self {
        case .all: return nil
        case .planetaSigno: return .natalPlanetaSigno
        case .planetaCasa: return .natalPlanetaCasa
        case .aspectos: return .aspectoNatal
        }
    }
}
