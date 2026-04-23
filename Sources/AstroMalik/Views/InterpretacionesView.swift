import SwiftUI

struct InterpretacionesView: View {
    var interpretaciones: [Interpretation]

    @State private var expanded: Set<String> = []
    @State private var filterTipo: InterpretationType? = nil

    private var filtered: [Interpretation] {
        guard let t = filterTipo else { return interpretaciones }
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
                    LazyVStack(spacing: 0) {
                        ForEach(filtered) { interp in
                            interpretationRow(interp)
                            Divider().padding(.leading, 16)
                        }
                    }
                    .padding(.bottom, 20)
                }
            }
        }
        .background(Color.appBackground)
    }

    // MARK: - Filter Bar

    private var filterBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                filterChip(label: "Todas", tipo: nil)
                filterChip(label: "Planeta/Signo", tipo: .natalPlanetaSigno)
                filterChip(label: "Planeta/Casa",  tipo: .natalPlanetaCasa)
                filterChip(label: "Aspectos",      tipo: .aspectoNatal)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
        }
    }

    private func filterChip(label: String, tipo: InterpretationType?) -> some View {
        let active = filterTipo == tipo
        return Button {
            filterTipo = tipo
        } label: {
            Text(label)
                .font(.caption.weight(active ? .semibold : .regular))
                .padding(.horizontal, 12)
                .padding(.vertical, 5)
                .background(active ? Color.appAccentFill : Color.appChipBackground)
                .foregroundColor(active ? .appAccentForeground : .appPrimaryText)
                .cornerRadius(20)
        }
        .buttonStyle(.plain)
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
        .background(isExpanded ? Color.appPanel : Color.clear)
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
