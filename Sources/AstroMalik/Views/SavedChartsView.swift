import SwiftUI

struct SavedChartsView: View {
    @EnvironmentObject var appState: AppState
    var onOpenChart: (NatalChart) -> Void
    @State private var chartToDelete: NatalChart? = nil
    @State private var renaming: NatalChart? = nil
    @State private var newName = ""
    @State private var searchText = ""
    @State private var metadataChart: NatalChart? = nil

    private var allCharts: [NatalChart] { appState.userStore.savedCharts }
    private var charts: [NatalChart] {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !query.isEmpty else { return allCharts }
        return allCharts.filter { chart in
            let metadata = appState.userStore.chartMetadata[chart.id] ?? ChartMetadata(notes: "", tags: [])
            let haystack = [
                chart.name,
                chart.birthDate,
                chart.birthTime,
                chart.timezone,
                chart.placeName,
                metadata.notes,
                metadata.tags.joined(separator: " "),
            ].joined(separator: " ").lowercased()
            return haystack.contains(query)
        }
    }

    var body: some View {
        Group {
            if allCharts.isEmpty {
                emptyState
            } else {
                chartsGrid
            }
        }
        .navigationTitle("Cartas Guardadas")
        .sheet(item: $metadataChart) { chart in
            ChartMetadataEditor(
                chart: chart,
                metadata: appState.userStore.chartMetadata[chart.id] ?? ChartMetadata(notes: "", tags: []),
                onSave: { notes, tags in
                    try? appState.userStore.setMetadata(id: chart.id, notes: notes, tags: tags)
                    metadataChart = nil
                },
                onCancel: { metadataChart = nil }
            )
        }
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
        onOpenChart(chart)
    }

    // MARK: - Grid

    private var chartsGrid: some View {
        VStack(spacing: 0) {
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.secondary)
                TextField("Buscar por nombre, lugar, fecha, etiqueta o nota", text: $searchText)
                    .textFieldStyle(.plain)
                if !searchText.isEmpty {
                    Button {
                        searchText = ""
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                    }
                    .buttonStyle(.plain)
                    .foregroundColor(.secondary)
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(Color.appPanel)
            .overlay(Rectangle().fill(Color.appBorder).frame(height: 1), alignment: .bottom)

            if charts.isEmpty {
                noMatchesState
            } else {
                ScrollView {
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 260))], spacing: 16) {
                        ForEach(charts) { chart in
                            Button {
                                openChart(chart)
                            } label: {
                                chartCard(chart)
                            }
                            .buttonStyle(.plain)
                            .contextMenu {
                                Button {
                                    newName = chart.name
                                    renaming = chart
                                } label: {
                                    Label("Renombrar", systemImage: "pencil")
                                }
                                Button {
                                    metadataChart = chart
                                } label: {
                                    Label("Notas y etiquetas", systemImage: "tag")
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
                    .padding(24)
                }
            }
        }
        .background(Color.appBackground)
    }

    private func chartCard(_ chart: NatalChart) -> some View {
        let metadata = appState.userStore.chartMetadata[chart.id] ?? ChartMetadata(notes: "", tags: [])
        return VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top) {
                Image(systemName: "star.circle.fill")
                    .foregroundColor(.appAccentFill)
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

            if !metadata.tags.isEmpty {
                HStack(spacing: 5) {
                    ForEach(metadata.tags.prefix(3), id: \.self) { tag in
                        Text("#\(tag)")
                            .font(.caption2.weight(.semibold))
                            .foregroundColor(.appSecondaryAccent)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 3)
                            .background(Color.appChipBackground)
                            .clipShape(RoundedRectangle(cornerRadius: 5, style: .continuous))
                    }
                }
            }

            if let asc = chart.bodies.first(where: { $0.key == "SOL" }) {
                Text("☉ " + asc.formatted)
                    .font(.caption.monospacedDigit())
                    .foregroundColor(.appSecondaryAccent)
            }
        }
        .frame(maxWidth: .infinity, minHeight: 132, alignment: .topLeading)
        .contentShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        .appCard()
    }

    private var noMatchesState: some View {
        VStack(spacing: 10) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 38))
                .foregroundColor(.secondary)
            Text("Sin resultados")
                .font(.headline)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
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

private struct ChartMetadataEditor: View {
    let chart: NatalChart
    @State var notes: String
    @State var tagsText: String
    var onSave: (String, [String]) -> Void
    var onCancel: () -> Void

    init(
        chart: NatalChart,
        metadata: ChartMetadata,
        onSave: @escaping (String, [String]) -> Void,
        onCancel: @escaping () -> Void
    ) {
        self.chart = chart
        _notes = State(initialValue: metadata.notes)
        _tagsText = State(initialValue: metadata.tags.joined(separator: ", "))
        self.onSave = onSave
        self.onCancel = onCancel
    }

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 14) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(chart.name)
                        .font(.headline)
                        .foregroundColor(.appPrimaryText)
                    Text("\(chart.birthDate) · \(chart.placeName)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                VStack(alignment: .leading, spacing: 6) {
                    Text("Etiquetas")
                        .appSectionHeader()
                    TextField("cliente, estudio, importante", text: $tagsText)
                        .textFieldStyle(.roundedBorder)
                }

                VStack(alignment: .leading, spacing: 6) {
                    Text("Notas")
                        .appSectionHeader()
                    TextEditor(text: $notes)
                        .frame(minHeight: 180)
                        .scrollContentBackground(.hidden)
                        .background(Color.appInputBackground)
                        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: 8, style: .continuous)
                                .stroke(Color.appBorder, lineWidth: 1)
                        )
                }
            }
            .padding(20)
            .background(Color.appBackground)
            .navigationTitle("Notas y etiquetas")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancelar") { onCancel() }
                }
                ToolbarItem(placement: .primaryAction) {
                    Button("Guardar") {
                        let tags = tagsText.split(separator: ",").map(String.init)
                        onSave(notes, tags)
                    }
                }
            }
        }
        .frame(minWidth: 500, minHeight: 420)
    }
}
