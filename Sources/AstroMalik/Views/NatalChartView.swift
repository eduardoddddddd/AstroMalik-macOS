import SwiftUI
import AppKit

enum NatalDetailMode: String, CaseIterable, Identifiable {
    case wheel = "Rueda"
    case reading = "Lectura"
    case texts = "Textos"

    var id: String { rawValue }
}

struct NatalChartView: View {
    @EnvironmentObject var appState: AppState

    var chart: NatalChart
    var initialMode: NatalDetailMode
    var onBack: (() -> Void)? = nil

    @State private var interpretaciones: [Interpretation] = []
    @State private var isLoadingInterp = false
    @State private var detailMode: NatalDetailMode
    @State private var selectedFocusKey: String? = "ASC"
    @State private var synthesis = ""

    @State private var saveSuccess = false
    @State private var noteCopied = false
    @State private var interpretationTask: Task<Void, Never>? = nil
    @State private var saveFeedbackTask: Task<Void, Never>? = nil

    init(
        chart: NatalChart,
        initialMode: NatalDetailMode = .wheel,
        onBack: (() -> Void)? = nil
    ) {
        self.chart = chart
        self.initialMode = initialMode
        self.onBack = onBack
        _detailMode = State(initialValue: initialMode)
    }

    var body: some View {
        VStack(spacing: 0) {
            chartHeader
            Divider()
            GeometryReader { proxy in
                let positionsWidth = min(max(proxy.size.width * 0.36, 340), 460)
                HStack(spacing: 0) {
                    positionsPanel
                        .frame(width: positionsWidth)
                    Divider()
                    detailPanel
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.appBackground)
        .navigationTitle(chart.name.isEmpty ? "Carta Natal" : chart.name)
        .toolbar {
            if let onBack {
                ToolbarItem(placement: .cancellationAction) {
                    Button {
                        onBack()
                    } label: {
                        Label("Volver", systemImage: "chevron.left")
                    }
                }
            }
            ToolbarItemGroup(placement: .primaryAction) {
                Button {
                    appState.showPrimaryDirections(for: chart)
                } label: {
                    Label("Direcciones Primarias", systemImage: "arrow.triangle.swap")
                }
                Button {
                    Task { await saveChart() }
                } label: {
                    Label(saveSuccess ? "Guardada" : "Guardar carta", systemImage: saveSuccess ? "checkmark.circle" : "tray.and.arrow.down")
                }
                Button {
                    copyJoplinNote()
                } label: {
                    Label(noteCopied ? "Nota copiada" : "Copiar nota Joplin", systemImage: noteCopied ? "checkmark.circle" : "doc.on.clipboard")
                }
            }
        }
        .onAppear { startLoadingInterpretaciones() }
        .onChange(of: chart.id) { _, _ in startLoadingInterpretaciones() }
        .onDisappear {
            interpretationTask?.cancel()
            interpretationTask = nil
            saveFeedbackTask?.cancel()
            saveFeedbackTask = nil
        }
    }

    // MARK: - Header

    private var chartHeader: some View {
        HStack(alignment: .top, spacing: 18) {
            VStack(alignment: .leading, spacing: 6) {
                Text(chart.name.isEmpty ? "Carta Natal" : chart.name)
                    .font(.system(size: 24, weight: .semibold))
                    .foregroundColor(.appPrimaryText)
                    .lineLimit(1)
                HStack(spacing: 12) {
                    if !chart.placeName.isEmpty {
                        Label(chart.placeName, systemImage: "mappin")
                    }
                    Label(chart.birthDate, systemImage: "calendar")
                    Label(chart.birthTime, systemImage: "clock")
                    Label(chart.timezone, systemImage: "globe")
                }
                .font(.caption)
                .foregroundColor(.secondary)
                .lineLimit(1)
            }
            .layoutPriority(1)

            Spacer()

            HStack(spacing: 10) {
                Picker("Vista", selection: $detailMode) {
                    ForEach(NatalDetailMode.allCases) { mode in
                        Text(mode.rawValue).tag(mode)
                    }
                }
                .pickerStyle(.segmented)
                .frame(width: 250)
                compactMetric("ASC", chart.ascendant.formatted)
                compactMetric("MC", chart.mc.formatted)
            }
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 16)
    }

    // MARK: - Positions Panel

    private var positionsPanel: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Puntos Angulares")
                        .appSectionHeader()
                    angularRow(name: "Ascendente", formatted: chart.ascendant.formatted)
                    angularRow(name: "Medio Cielo", formatted: chart.mc.formatted)
                }
                .appCard()

                VStack(alignment: .leading, spacing: 4) {
                    Text("Posiciones Planetarias")
                        .appSectionHeader()
                    planetsTable
                }
                .appCard()
            }
            .padding(18)
        }
        .background(Color.appSurface)
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
        .padding(.vertical, 3)
    }

    private var planetsTable: some View {
        VStack(spacing: 4) {
            ForEach(chart.bodies) { body in
                planetRow(body)
            }
        }
    }

    private func planetRow(_ body: PlanetBody) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 10) {
            Text(body.label + (body.retrograde ? " ℞" : ""))
                .frame(minWidth: 92, alignment: .leading)
                .font(.subheadline)
                .foregroundColor(body.retrograde ? .appWarning : .appPrimaryText)

            VStack(alignment: .leading, spacing: 2) {
                Text(body.formatted)
                    .font(.subheadline.monospacedDigit())
                    .foregroundColor(.appPrimaryText)
                Text("Casa \(body.house)")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Spacer(minLength: 8)

            Text(String(format: "%.2f°", body.longitude))
                .font(.caption.monospacedDigit())
                .foregroundColor(.secondary)
        }
        .padding(.vertical, 7)
        .padding(.horizontal, 10)
        .background(Color.appSurface)
        .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
    }

    // MARK: - Interpretaciones Panel

    private var detailPanel: some View {
        Group {
            if isLoadingInterp {
                ProgressView("Cargando interpretaciones…")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                switch detailMode {
                case .wheel:
                    wheelPanel
                case .reading:
                    GuidedReadingView(
                        chart: chart,
                        interpretaciones: interpretaciones,
                        synthesis: $synthesis,
                        selectedFocusKey: $selectedFocusKey
                    )
                case .texts:
                    InterpretacionesView(interpretaciones: interpretaciones)
                }
            }
        }
    }

    private var wheelPanel: some View {
        VStack(spacing: 0) {
            NatalWheelView(chart: chart, selectedKey: $selectedFocusKey)
                .frame(minHeight: 360)
                .padding(18)
            Divider()
            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    selectedFocusCard
                }
                .padding(18)
            }
        }
        .background(Color.appBackground)
    }

    private var selectedFocusCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(selectedFocusTitle)
                .appSectionHeader()
            if selectedFocusInterpretations.isEmpty {
                Text("Selecciona un planeta, ASC o MC para ver sus textos relacionados.")
                    .font(.callout)
                    .foregroundColor(.secondary)
            } else {
                ForEach(selectedFocusInterpretations.prefix(4)) { interpretation in
                    VStack(alignment: .leading, spacing: 4) {
                        Text(interpretation.titulo)
                            .font(.subheadline.weight(.semibold))
                            .foregroundColor(.appPrimaryText)
                        Text(interpretation.texto)
                            .font(.callout)
                            .lineLimit(5)
                            .foregroundColor(.secondary)
                    }
                    Divider().opacity(0.35)
                }
            }
        }
        .appCard()
    }

    private var selectedFocusTitle: String {
        guard let key = selectedFocusKey else { return "Elemento seleccionado" }
        if key == "ASC" { return "Ascendente" }
        if key == "MC" { return "Medio Cielo" }
        return chart.bodies.first(where: { $0.key == key })?.label ?? key
    }

    private var selectedFocusInterpretations: [Interpretation] {
        guard let key = selectedFocusKey else { return [] }
        return interpretaciones.filter { interpretation in
            interpretation.clave == key ||
            interpretation.clave.hasPrefix("\(key)_") ||
            interpretation.clave.contains("_\(key)_")
        }
    }

    private func compactMetric(_ title: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(title)
                .font(.caption2.weight(.bold))
                .foregroundColor(.secondary)
            Text(value)
                .font(.caption.monospacedDigit())
                .foregroundColor(.appPrimaryText)
                .lineLimit(1)
        }
        .frame(width: 118, alignment: .leading)
        .appCard(padding: 10)
    }

    // MARK: - Actions

    private func startLoadingInterpretaciones() {
        interpretationTask?.cancel()
        isLoadingInterp = true
        let store = appState.corpusStore
        let currentChart = chart
        interpretationTask = Task {
            let worker = Task.detached(priority: .userInitiated) {
                store.buildNatalInterpretations(chart: currentChart)
            }
            let interps = await withTaskCancellationHandler {
                await worker.value
            } onCancel: {
                worker.cancel()
            }
            guard !Task.isCancelled else { return }
            interpretaciones = interps
            isLoadingInterp = false
        }
    }

    private func saveChart() async {
        do {
            try appState.userStore.save(chart)
            saveSuccess = true
            saveFeedbackTask?.cancel()
            saveFeedbackTask = Task {
                try? await Task.sleep(nanoseconds: 2_000_000_000)
                guard !Task.isCancelled else { return }
                saveSuccess = false
            }
        } catch {
            print("[NatalChartView] Save error: \(error)")
        }
    }

    private func copyJoplinNote() {
        let note = ReadingNoteBuilder.markdown(chart: chart, interpretations: interpretaciones, synthesis: synthesis)
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(note, forType: .string)
        noteCopied = true
        saveFeedbackTask?.cancel()
        saveFeedbackTask = Task {
            try? await Task.sleep(nanoseconds: 2_000_000_000)
            guard !Task.isCancelled else { return }
            noteCopied = false
        }
    }
}
