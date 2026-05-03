import SwiftUI

struct TransitsView: View {
    @EnvironmentObject var appState: AppState

    var natalChart: NatalChart
    @ObservedObject var state: TransitWorkspaceState
    @State private var calculationTask: Task<Void, Never>? = nil

    private var filtered: [TransitEvent] {
        let events: [TransitEvent]
        switch state.focusFilter {
        case .focus:
            events = state.events.filter { $0.priorityBand == .critical || $0.priorityBand == .high }
        case .important:
            events = state.events.filter {
                $0.priorityBand == .critical || $0.priorityBand == .high || $0.priorityBand == .medium
            }
        case .all:
            events = state.events
        case .technical:
            events = state.events.filter { $0.technicalStars >= 4 }
        }
        return events.sorted(by: transitPrioritySort)
    }

    private var timelineEvents: [TransitEvent] {
        filtered
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
                } else if state.events.isEmpty && state.houseIngresses.isEmpty {
                    emptyState
                } else {
                    VStack(spacing: 0) {
                        if !state.events.isEmpty {
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
                        if !state.houseIngresses.isEmpty {
                            Divider()
                            houseIngressSection
                        }
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
                Text("Mostrar")
                    .font(.caption).foregroundColor(.secondary)
                Picker("", selection: $state.focusFilter) {
                    ForEach(TransitFocusFilter.allCases) { filter in
                        Text(filter.label).tag(filter)
                    }
                }
                .frame(width: 118)
                .pickerStyle(.menu)
                .help("Foco muestra solo los tránsitos prioritarios por combinación de técnica, relevancia personal e impacto temporal.")
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

            TableColumn("Prioridad") { e in
                VStack(alignment: .leading, spacing: 2) {
                    Text("\(e.priorityStarsDisplay) \(e.priorityLabel)")
                        .font(.caption.monospacedDigit().weight(.semibold))
                        .foregroundColor(priorityColor(e.priorityBand))
                    Text(String(format: "%.1f", e.priorityScore))
                        .font(.caption2.monospacedDigit())
                        .foregroundColor(.secondary)
                }
            }
            .width(125)

            TableColumn("Motivo") { e in
                Text(e.compactReason)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(1)
                    .truncationMode(.tail)
            }
            .width(min: 210, ideal: 280)

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

    private var houseIngressSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Image(systemName: "arrow.right.circle.fill")
                    .foregroundColor(Color(hex: "#2563eb"))
                Text("Ingresos por casa")
                    .font(.headline)
                Text("\(state.houseIngresses.count)")
                    .font(.caption.monospacedDigit())
                    .foregroundColor(.secondary)
            }

            ScrollView {
                LazyVStack(alignment: .leading, spacing: 8) {
                    ForEach(state.houseIngresses) { ingress in
                        houseIngressCard(ingress)
                    }
                }
                .padding(.bottom, 2)
            }
            .frame(maxHeight: 180)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(Color.appPanel.opacity(0.45))
    }

    private func houseIngressCard(_ ingress: TransitHouseIngress) -> some View {
        HStack(alignment: .center, spacing: 10) {
            Image(systemName: "arrow.right.circle")
                .foregroundColor(Color(hex: "#2563eb"))
            VStack(alignment: .leading, spacing: 3) {
                Text("\(ingress.transitLabel) ingresa en Casa \(ingress.house)")
                    .font(.subheadline.weight(.semibold))
                Text("Desde Casa \(ingress.fromHouse) · \(ingress.date)")
                    .font(.caption.monospacedDigit())
                    .foregroundColor(.secondary)
            }
            Spacer()
            Text(String(repeating: "★", count: ingress.stars))
                .font(.caption.monospacedDigit())
                .foregroundColor(starColor(ingress.stars))
                .accessibilityLabel("\(ingress.stars) estrellas")
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(Color.appBackground)
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
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
                        metaLabel("Activo", Text("\(event.fromDate) → \(event.toDate)").font(.caption.monospacedDigit()))
                        metaLabel("Orbe exacto", Text(String(format: "%.2f°", event.minOrb)).font(.caption.monospacedDigit()))
                    }
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Por qué importa")
                            .font(.headline)
                        if event.metricReasons.isEmpty {
                            Text("Sin énfasis personal claro")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        } else {
                            FlowLayout(spacing: 6) {
                                ForEach(event.metricReasons, id: \.self) { reason in
                                    Text(reason)
                                        .font(.caption)
                                        .padding(.horizontal, 8)
                                        .padding(.vertical, 4)
                                        .background(Color.appPanel)
                                        .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                                }
                            }
                        }
                    }
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Métricas")
                            .font(.headline)
                        VStack(alignment: .leading, spacing: 6) {
                            metricRow(
                                "Prioridad",
                                "\(event.priorityStarsDisplay) \(event.priorityLabel) · \(String(format: "%.1f", event.priorityScore))",
                                priorityColor(event.priorityBand)
                            )
                            metricRow(
                                "Técnica",
                                "\(event.technicalStarsDisplay) · \(String(format: "%.1f", event.technicalScore))",
                                starColor(event.technicalStars)
                            )
                            metricRow(
                                "Personal",
                                "\(event.personalRelevanceStarsDisplay) · ×\(String(format: "%.2f", event.personalRelevance))",
                                starColor(event.personalRelevanceStars)
                            )
                            metricRow(
                                "Impacto",
                                "\(event.temporalImpactStarsDisplay) · ×\(String(format: "%.2f", event.temporalImpact))",
                                starColor(event.temporalImpactStars)
                            )
                        }
                        Text("Técnica mide planeta transitante, aspecto y orbe. Personal mide cuánto toca esta carta natal concreta. Impacto mide duración, repetición, exactitud y acumulación temporal.")
                            .font(.caption)
                            .foregroundColor(.secondary)
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

    private func metricRow(_ title: String, _ value: String, _ color: Color) -> some View {
        HStack(spacing: 8) {
            Text("\(title):")
                .font(.caption.weight(.semibold))
                .frame(width: 70, alignment: .leading)
            Text(value)
                .font(.caption.monospacedDigit())
                .foregroundColor(color)
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
                let houseIngresses = try detectHouseIngresses(
                    natalChart: chart,
                    fromDate: fromDate,
                    toDate: toDate,
                    excludeMoon: excludeMoon
                )
                guard !Task.isCancelled else { return }
                state.events = events
                state.houseIngresses = houseIngresses
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

    private func priorityColor(_ band: TransitPriorityBand) -> Color {
        switch band {
        case .critical: return Color(hex: "#d97706")
        case .high: return Color(hex: "#2563eb")
        case .medium: return Color(hex: "#15803d")
        case .low: return .secondary
        }
    }

    private func transitPrioritySort(_ lhs: TransitEvent, _ rhs: TransitEvent) -> Bool {
        if lhs.priorityBand.rank != rhs.priorityBand.rank { return lhs.priorityBand.rank > rhs.priorityBand.rank }
        if lhs.priorityScore != rhs.priorityScore { return lhs.priorityScore > rhs.priorityScore }
        if lhs.exactDate != rhs.exactDate { return lhs.exactDate < rhs.exactDate }
        if lhs.minOrb != rhs.minOrb { return lhs.minOrb < rhs.minOrb }
        return lhs.transitKey < rhs.transitKey
    }
}

private struct FlowLayout: Layout {
    var spacing: CGFloat = 6

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let maxWidth = proposal.width ?? 420
        var x: CGFloat = 0
        var y: CGFloat = 0
        var lineHeight: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x > 0 && x + size.width > maxWidth {
                x = 0
                y += lineHeight + spacing
                lineHeight = 0
            }
            x += size.width + spacing
            lineHeight = max(lineHeight, size.height)
        }
        return CGSize(width: maxWidth, height: y + lineHeight)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var x = bounds.minX
        var y = bounds.minY
        var lineHeight: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x > bounds.minX && x + size.width > bounds.maxX {
                x = bounds.minX
                y += lineHeight + spacing
                lineHeight = 0
            }
            subview.place(at: CGPoint(x: x, y: y), proposal: ProposedViewSize(size))
            x += size.width + spacing
            lineHeight = max(lineHeight, size.height)
        }
    }
}
