import SwiftUI

struct TransitsView: View {
    @EnvironmentObject var appState: AppState

    var natalChart: NatalChart

    @State private var fromDate  = Date()
    @State private var toDate    = Calendar.current.date(byAdding: .month, value: 6, to: Date())!
    @State private var excludeMoon = true
    @State private var events: [TransitEvent] = []
    @State private var isCalculating = false
    @State private var error: String? = nil
    @State private var selectedEventID: UUID? = nil
    @State private var selectedEvent: TransitEvent? = nil
    @State private var minStars: Int = 1

    private var filtered: [TransitEvent] {
        events.filter { $0.stars >= minStars }
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                controlsBar
                Divider()
                if isCalculating {
                    ProgressView("Calculando tránsitos…")
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if let err = error {
                    errorView(err)
                } else if events.isEmpty {
                    emptyState
                } else {
                    transitsList
                }
            }
            .background(Color.appBackground)
            .navigationTitle("Tránsitos — \(natalChart.name)")
        }
        .frame(minWidth: 700, minHeight: 500)
        .sheet(item: $selectedEvent) { event in
            transitDetail(event)
        }
    }

    // MARK: - Controls

    private var controlsBar: some View {
        HStack(spacing: 16) {
            DatePicker("Desde", selection: $fromDate, displayedComponents: .date)
                .labelsHidden()
            Text("→")
            DatePicker("Hasta", selection: $toDate, displayedComponents: .date)
                .labelsHidden()
            Divider().frame(height: 20)
            Toggle("Sin Luna", isOn: $excludeMoon)
                .toggleStyle(.switch)
                .controlSize(.small)
            Divider().frame(height: 20)
            HStack(spacing: 4) {
                Text("Min:")
                    .font(.caption).foregroundColor(.secondary)
                Picker("", selection: $minStars) {
                    ForEach(1...5, id: \.self) { s in
                        Text("\(s)★").tag(s)
                    }
                }
                .frame(width: 70)
                .pickerStyle(.menu)
            }
            Spacer()
            Button {
                Task { await calculate() }
            } label: {
                Label("Calcular", systemImage: "calendar.circle")
            }
            .buttonStyle(.borderedProminent)
            .tint(.appAccentFill)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
    }

    // MARK: - List

    private var transitsList: some View {
        Table(filtered, selection: $selectedEventID) {
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
        .onChange(of: selectedEventID) { _, eventID in
            guard let id = eventID else { return }
            if let ev = filtered.first(where: { $0.id == id }) {
                selectedEvent = ev
                selectedEventID = nil
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
                    Button("Cerrar") { selectedEvent = nil }
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

    private func calculate() async {
        isCalculating = true
        error = nil
        do {
            events = try await computeTransitPeriod(
                natalChart: natalChart,
                fromDate: fromDate,
                toDate: toDate,
                timezone: natalChart.timezone,
                excludeMoon: excludeMoon,
                corpusStore: appState.corpusStore
            )
        } catch {
            self.error = error.localizedDescription
        }
        isCalculating = false
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
