import SwiftUI

struct TransitsView: View {
    @EnvironmentObject var appState: AppState

    var natalChart: NatalChart
    @ObservedObject var state: TransitWorkspaceState
    @State private var calculationTask: Task<Void, Never>? = nil

    private var filtered: [TransitEvent] {
        state.events.filter { $0.stars >= state.minStars }
    }

    private var timelineEvents: [TransitEvent] {
        filtered.sorted {
            if $0.exactDate != $1.exactDate { return $0.exactDate < $1.exactDate }
            return $0.score > $1.score
        }
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                controlsBar
                Divider()
                if state.isCalculating {
                    ProgressView("Calculando tránsitos…")
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if let err = state.error {
                    errorView(err)
                } else if state.events.isEmpty {
                    emptyState
                } else {
                    VStack(spacing: 0) {
                        TransitTimelineView(
                            events: timelineEvents,
                            fromDate: state.fromDate,
                            toDate: state.toDate
                        ) { event in
                            state.selectedEvent = event
                        }
                        .frame(minHeight: 220, idealHeight: 300, maxHeight: 420)
                        Divider()
                        transitsList
                    }
                }
            }
            .background(Color.appBackground)
            .navigationTitle("Tránsitos — \(natalChart.name)")
        }
        .frame(minWidth: 700, minHeight: 500)
        .task(id: natalChart.id) {
            state.prepare(for: natalChart)
        }
        .onDisappear {
            calculationTask?.cancel()
            calculationTask = nil
            state.isCalculating = false
        }
        .sheet(item: $state.selectedEvent) { event in
            transitDetail(event)
        }
    }

    // MARK: - Controls

    private var controlsBar: some View {
        HStack(spacing: 16) {
            DatePicker("Desde", selection: $state.fromDate, displayedComponents: .date)
                .labelsHidden()
                .onChange(of: state.fromDate) { _, _ in state.markInputsChanged() }
            Text("→")
            DatePicker("Hasta", selection: $state.toDate, displayedComponents: .date)
                .labelsHidden()
                .onChange(of: state.toDate) { _, _ in state.markInputsChanged() }
            Divider().frame(height: 20)
            Toggle("Sin Luna", isOn: $state.excludeMoon)
                .toggleStyle(.switch)
                .controlSize(.small)
                .onChange(of: state.excludeMoon) { _, _ in state.markInputsChanged() }
            Divider().frame(height: 20)
            HStack(spacing: 4) {
                Text("Min:")
                    .font(.caption).foregroundColor(.secondary)
                Picker("", selection: $state.minStars) {
                    ForEach(1...5, id: \.self) { s in
                        Text("\(s)★").tag(s)
                    }
                }
                .frame(width: 70)
                .pickerStyle(.menu)
            }
            Spacer()
            if state.needsRecalculation && !state.events.isEmpty {
                Label("Cambios sin recalcular", systemImage: "exclamationmark.circle")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            Button {
                startCalculation()
            } label: {
                Label(state.events.isEmpty ? "Calcular" : "Recalcular", systemImage: "calendar.circle")
            }
            .buttonStyle(.borderedProminent)
            .tint(.appAccentFill)
            .disabled(state.isCalculating)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
    }

    // MARK: - List

    private var transitsList: some View {
        Table(filtered, selection: $state.selectedEventID) {
            TableColumn("Tránsito") { e in
                HStack(spacing: 6) {
                    Circle()
                        .fill(Color(hex: e.color))
                        .frame(width: 8, height: 8)
                    Text("\(e.transitLabel) \(e.aspectLabel) \(e.natalLabel)")
                        .font(.subheadline)
                    if e.retrogradeOnExact {
                        Text("℞").foregroundColor(.orange).font(.caption)
                    }
                }
            }
            .width(min: 200)

            TableColumn("Intensidad") { e in
                Text(e.starsDisplay)
                    .font(.caption.monospacedDigit())
                    .foregroundColor(starColor(e.stars))
            }
            .width(90)

            TableColumn("Periodo") { e in
                Text("\(e.fromDate) → \(e.toDate)")
                    .font(.caption.monospacedDigit())
                    .foregroundColor(.secondary)
            }
            .width(min: 180)

            TableColumn("Orbe") { e in
                Text(String(format: "%.1f°", e.minOrb))
                    .font(.caption.monospacedDigit())
                    .foregroundColor(.secondary)
            }
            .width(50)

            TableColumn("Texto") { e in
                if e.text != nil {
                    Image(systemName: "text.alignleft")
                        .foregroundColor(.appPrimaryText)
                        .font(.caption)
                }
            }
            .width(40)
        }
        .tableStyle(.inset(alternatesRowBackgrounds: true))
        .onChange(of: state.selectedEventID) { _, eventID in
            guard let id = eventID else { return }
            if let ev = filtered.first(where: { $0.id == id }) {
                state.selectedEvent = ev
                state.selectedEventID = nil
            }
        }
    }

    // MARK: - Detail Sheet

    private func transitDetail(_ event: TransitEvent) -> some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    HStack {
                        Circle().fill(Color(hex: event.color)).frame(width: 10, height: 10)
                        Text("\(event.transitLabel) \(event.aspectLabel) \(event.natalLabel)")
                            .font(.title3.weight(.medium))
                        if event.retrogradeOnExact { Text("℞").foregroundColor(.orange) }
                    }
                    HStack(spacing: 20) {
                        metaLabel("Intensidad", Text(event.starsDisplay).foregroundColor(starColor(event.stars)))
                        metaLabel("Activo", Text("\(event.fromDate) → \(event.toDate)").font(.caption.monospacedDigit()))
                        metaLabel("Orbe exacto", Text(String(format: "%.2f°", event.minOrb)).font(.caption.monospacedDigit()))
                    }
                    Divider()
                    if let texto = event.text {
                        Text(texto)
                            .font(.body)
                            .lineSpacing(5)
                        if let fuente = event.source, !fuente.isEmpty {
                            Text("Fuente: \(fuente)")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    } else {
                        Text("Sin interpretación disponible en el corpus.")
                            .foregroundColor(.secondary)
                    }
                }
                .padding(24)
            }
            .background(Color.appBackground)
            .navigationTitle("Detalle de Tránsito")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cerrar") { state.selectedEvent = nil }
                }
            }
        }
        .frame(minWidth: 500, minHeight: 400)
    }

    private func metaLabel(_ title: String, _ value: some View) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title).font(.caption2).foregroundColor(.secondary)
            value
        }
    }

    // MARK: - Empty / Error

    private var emptyState: some View {
        VStack(spacing: 8) {
            Image(systemName: "calendar.badge.clock")
                .font(.system(size: 40))
                .foregroundColor(.secondary)
            Text("Selecciona un periodo y pulsa Calcular")
                .font(.subheadline).foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func errorView(_ msg: String) -> some View {
        VStack(spacing: 8) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundColor(.orange).font(.title2)
            Text(msg).foregroundColor(.secondary).font(.subheadline)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Calculation

    private func startCalculation() {
        calculationTask?.cancel()
        state.isCalculating = true
        state.error = nil

        let chart = natalChart
        let fromDate = state.fromDate
        let toDate = state.toDate
        let excludeMoon = state.excludeMoon
        let store = appState.corpusStore

        calculationTask = Task {
            do {
                let events = try await computeTransitPeriod(
                    natalChart: chart,
                    fromDate: fromDate,
                    toDate: toDate,
                    timezone: chart.timezone,
                    excludeMoon: excludeMoon,
                    corpusStore: store
                )
                guard !Task.isCancelled else { return }
                state.events = events
                state.markCalculated()
            } catch is CancellationError {
                if !Task.isCancelled {
                    state.error = "Cálculo de tránsitos cancelado."
                }
            } catch {
                state.error = error.localizedDescription
            }
            if !Task.isCancelled {
                state.isCalculating = false
            }
        }
    }

    // MARK: - Helpers

    private func starColor(_ stars: Int) -> Color {
        switch stars {
        case 5: return Color(hex: "#d97706")
        case 4: return Color(hex: "#2563eb")
        case 3: return Color(hex: "#15803d")
        default: return .secondary
        }
    }
}
