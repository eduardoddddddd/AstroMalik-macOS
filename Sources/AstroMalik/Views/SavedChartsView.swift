import SwiftUI

struct SavedChartsView: View {
    @EnvironmentObject var appState: AppState
    var onOpenChart: (NatalChart) -> Void
    @State private var chartToDelete: NatalChart? = nil
    @State private var renaming: NatalChart? = nil
    @State private var newName = ""

    private var charts: [NatalChart] { appState.userStore.savedCharts }

    var body: some View {
        Group {
            if charts.isEmpty {
                emptyState
            } else {
                chartsGrid
            }
        }
        .navigationTitle("Cartas Guardadas")
        .alert("Renombrar carta", isPresented: .init(
            get: { renaming != nil },
            set: { if !$0 { renaming = nil } }
        )) {
            TextField("Nombre", text: $newName)
            Button("Guardar") {
                if let chart = renaming {
                    try? appState.userStore.rename(id: chart.id, name: newName)
                }
                renaming = nil
            }
            Button("Cancelar", role: .cancel) { renaming = nil }
        }
        .confirmationDialog(
            "¿Eliminar carta?",
            isPresented: .init(get: { chartToDelete != nil }, set: { if !$0 { chartToDelete = nil } }),
            titleVisibility: .visible
        ) {
            Button("Eliminar", role: .destructive) {
                if let c = chartToDelete {
                    try? appState.userStore.delete(c)
                }
                chartToDelete = nil
            }
            Button("Cancelar", role: .cancel) { chartToDelete = nil }
        } message: {
            Text("Esta acción no se puede deshacer.")
        }
    }

    private func openChart(_ chart: NatalChart) {
        appState.register(chart)
        onOpenChart(chart)
    }

    // MARK: - Grid

    private var chartsGrid: some View {
        ScrollView {
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 260))], spacing: 16) {
                ForEach(charts) { chart in
                    chartCard(chart)
                        .onTapGesture(count: 2) { openChart(chart) }
                        .onTapGesture { openChart(chart) }
                        .contextMenu {
                            Button {
                                newName = chart.name
                                renaming = chart
                            } label: {
                                Label("Renombrar", systemImage: "pencil")
                            }
                            Button {
                                openChart(chart)
                            } label: {
                                Label("Ver carta", systemImage: "star.circle")
                            }
                            Divider()
                            Button(role: .destructive) {
                                chartToDelete = chart
                            } label: {
                                Label("Eliminar", systemImage: "trash")
                            }
                        }
                }
            }
            .padding(20)
        }
        .background(Color.appBackground)
    }

    private func chartCard(_ chart: NatalChart) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Image(systemName: "star.circle.fill")
                    .foregroundColor(.appPrimaryText)
                    .font(.title3)
                Spacer()
                Text(chart.birthDate)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            Text(chart.name)
                .font(.headline)
                .foregroundColor(.appPrimaryText)
                .lineLimit(1)

            VStack(alignment: .leading, spacing: 3) {
                if !chart.placeName.isEmpty {
                    Label(chart.placeName, systemImage: "mappin.circle")
                        .font(.caption).foregroundColor(.secondary)
                }
                Label(chart.birthTime + " · " + chart.timezone, systemImage: "clock")
                    .font(.caption).foregroundColor(.secondary)
            }

            if let asc = chart.bodies.first(where: { $0.key == "SOL" }) {
                Text("☉ " + asc.formatted)
                    .font(.caption.monospacedDigit())
                    .foregroundColor(.appSecondaryAccent)
            }
        }
        .padding(16)
        .background(Color.appPanel)
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.05), radius: 4, x: 0, y: 2)
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "tray")
                .font(.system(size: 48))
                .foregroundColor(.secondary)
            Text("No hay cartas guardadas")
                .font(.headline).foregroundColor(.secondary)
            Text("Calcula una carta natal y guárdala desde la vista de resultados.")
                .font(.subheadline).foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.appBackground)
    }
}
