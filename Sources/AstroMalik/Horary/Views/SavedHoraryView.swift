import SwiftUI

struct SavedHoraryView: View {
    @EnvironmentObject var appState: AppState
    var onOpenQuery: (SavedHoraryQuery) -> Void
    @State private var queryToDelete: SavedHoraryQuery? = nil

    private var queries: [SavedHoraryQuery] { appState.horaryStore.savedQueries }

    var body: some View {
        Group {
            if queries.isEmpty {
                emptyState
            } else {
                queriesGrid
            }
        }
        .confirmationDialog(
            "¿Eliminar consulta horaria?",
            isPresented: .init(get: { queryToDelete != nil }, set: { if !$0 { queryToDelete = nil } }),
            titleVisibility: .visible
        ) {
            Button("Eliminar", role: .destructive) {
                if let query = queryToDelete {
                    try? appState.horaryStore.delete(query)
                }
                queryToDelete = nil
            }
            Button("Cancelar", role: .cancel) { queryToDelete = nil }
        } message: {
            Text("Esta acción no se puede deshacer.")
        }
    }

    private func openQuery(_ query: SavedHoraryQuery) {
        onOpenQuery(query)
    }

    private var queriesGrid: some View {
        ScrollView {
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 280))], spacing: 16) {
                ForEach(queries) { query in
                    Button {
                        openQuery(query)
                    } label: {
                        queryCard(query)
                    }
                    .buttonStyle(.plain)
                    .contextMenu {
                        Button {
                            openQuery(query)
                        } label: {
                            Label("Abrir consulta", systemImage: "questionmark.bubble")
                        }
                        Divider()
                        Button(role: .destructive) {
                            queryToDelete = query
                        } label: {
                            Label("Eliminar", systemImage: "trash")
                        }
                    }
                }
            }
            .padding(24)
        }
        .background(Color.appBackground)
    }

    private func queryCard(_ query: SavedHoraryQuery) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top) {
                Image(systemName: "questionmark.bubble.fill")
                    .foregroundColor(.appAccentFill)
                    .font(.title3)
                Spacer()
                Text(query.request.datetimeLocal.replacingOccurrences(of: "T", with: " "))
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.trailing)
            }

            Text(query.request.question)
                .font(.headline)
                .foregroundColor(.appPrimaryText)
                .lineLimit(3)

            VStack(alignment: .leading, spacing: 3) {
                Label(query.request.placeName, systemImage: "mappin.circle")
                    .font(.caption).foregroundColor(.secondary)
                Label("Casa \(query.request.questionHouse) · \(query.judgement.perfectionKind)", systemImage: "sparkles")
                    .font(.caption).foregroundColor(.secondary)
                Label(query.judgement.radical ? "Carta radical" : "Carta no radical", systemImage: "checkmark.seal")
                    .font(.caption).foregroundColor(.secondary)
            }
        }
        .frame(maxWidth: .infinity, minHeight: 150, alignment: .topLeading)
        .contentShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        .appCard()
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "archivebox")
                .font(.system(size: 48))
                .foregroundColor(.secondary)
            Text("No hay consultas guardadas")
                .font(.headline).foregroundColor(.secondary)
            Text("Calcula una consulta horaria y se guardará en tu historial local.")
                .font(.subheadline).foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.appBackground)
    }
}
