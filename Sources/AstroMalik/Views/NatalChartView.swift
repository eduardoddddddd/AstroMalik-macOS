import SwiftUI

struct NatalChartView: View {
    @EnvironmentObject var appState: AppState

    var chart: NatalChart
    var onBack: (() -> Void)? = nil

    @State private var interpretaciones: [Interpretation] = []
    @State private var isLoadingInterp = false

    @State private var saveSuccess = false

    var body: some View {
        NavigationStack {
            HSplitView {
                positionsPanel
                    .frame(minWidth: 340, idealWidth: 400, maxWidth: 520)
                interpretacionesPanel
                    .frame(minWidth: 420)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color.appBackground)
            .navigationTitle(chart.name.isEmpty ? "Carta Natal" : chart.name)
            .toolbar {
                if let onBack {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Volver") { onBack() }
                    }
                }
                ToolbarItemGroup(placement: .primaryAction) {
                    Button {
                        Task { await saveChart() }
                    } label: {
                        Label(saveSuccess ? "Guardada ✓" : "Guardar carta", systemImage: "tray.and.arrow.down")
                    }

                }
            }

        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .task { loadInterpretaciones() }
    }

    // MARK: - Positions Panel

    private var positionsPanel: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // Header
                VStack(alignment: .leading, spacing: 4) {
                    if !chart.placeName.isEmpty {
                        Label(chart.placeName, systemImage: "mappin")
                            .font(.caption).foregroundColor(.secondary)
                    }
                    HStack {
                        Label(chart.birthDate, systemImage: "calendar")
                        Text(chart.birthTime)
                    }
                    .font(.caption).foregroundColor(.secondary)
                    Label(chart.timezone, systemImage: "globe")
                        .font(.caption).foregroundColor(.secondary)
                }

                Divider()

                // Puntos angulares
                VStack(alignment: .leading, spacing: 6) {
                    Text("Puntos Angulares")
                        .font(.headline).foregroundColor(.appPrimaryText)
                    angularRow(name: "Ascendente", formatted: chart.ascendant.formatted)
                    angularRow(name: "Medio Cielo", formatted: chart.mc.formatted)
                }

                Divider()

                // Planetas
                VStack(alignment: .leading, spacing: 4) {
                    Text("Posiciones Planetarias")
                        .font(.headline).foregroundColor(.appPrimaryText)
                    planetsTable
                }
            }
            .padding(20)
        }
    }

    private func angularRow(name: String, formatted: String) -> some View {
        HStack {
            Text(name)
                .frame(width: 110, alignment: .leading)
                .foregroundColor(.secondary)
                .font(.subheadline)
            Text(formatted)
                .font(.subheadline.monospacedDigit())
        }
    }

    private var planetsTable: some View {
        VStack(spacing: 0) {
            // Header row
            HStack(spacing: 0) {
                tableHeader("Planeta", width: 110)
                tableHeader("Signo", width: 160)
                tableHeader("Casa", width: 50)
                tableHeader("Grado", width: 80)
            }
            .padding(.bottom, 4)
            Divider()
            ForEach(chart.bodies) { body in
                planetRow(body)
                Divider().opacity(0.4)
            }
        }
    }

    private func tableHeader(_ text: String, width: CGFloat) -> some View {
        Text(text)
            .font(.caption.weight(.semibold))
            .foregroundColor(.secondary)
            .frame(width: width, alignment: .leading)
    }

    private func planetRow(_ body: PlanetBody) -> some View {
        HStack(spacing: 0) {
            Text(body.label + (body.retrograde ? " ℞" : ""))
                .frame(width: 110, alignment: .leading)
                .font(.subheadline)
                .foregroundColor(body.retrograde ? .orange : .primary)
            Text(body.formatted)
                .frame(width: 160, alignment: .leading)
                .font(.subheadline.monospacedDigit())
            Text("Casa \(body.house)")
                .frame(width: 50, alignment: .leading)
                .font(.caption).foregroundColor(.secondary)
            Text(String(format: "%.2f°", body.longitude))
                .frame(width: 80, alignment: .leading)
                .font(.caption.monospacedDigit()).foregroundColor(.secondary)
        }
        .padding(.vertical, 5)
    }

    // MARK: - Interpretaciones Panel

    private var interpretacionesPanel: some View {
        Group {
            if isLoadingInterp {
                ProgressView("Cargando interpretaciones…")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                InterpretacionesView(interpretaciones: interpretaciones)
            }
        }
    }

    // MARK: - Actions

    private func loadInterpretaciones() {
        isLoadingInterp = true
        let store = appState.corpusStore
        let currentChart = chart
        Task {
            let interps: [Interpretation] = await Task.detached(priority: .userInitiated) {
                store.buildNatalInterpretations(chart: currentChart)
            }.value
            interpretaciones = interps
            isLoadingInterp = false
        }
    }

    private func saveChart() async {
        do {
            try appState.userStore.save(chart)
            saveSuccess = true
            DispatchQueue.main.asyncAfter(deadline: .now() + 2) { saveSuccess = false }
        } catch {
            print("[NatalChartView] Save error: \(error)")
        }
    }
}
