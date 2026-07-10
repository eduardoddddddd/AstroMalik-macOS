import SwiftUI
import Darwin

struct SynastryView: View {
    @EnvironmentObject var appState: AppState

    @State private var chartAID: UUID?
    @State private var chartBID: UUID?
    @State private var reading: SynastryReading?
    @State private var showAspectsWithoutText = false
    @State private var isCalculating = false
    @State private var isCreatingNote = false
    @State private var statusMessage: String?
    @State private var errorMessage: String?
    @State private var calculationTask: Task<Void, Never>?
    @State private var noteTask: Task<Void, Never>?

    private var charts: [NatalChart] { appState.userStore.savedCharts }

    private var chartA: NatalChart? {
        guard let chartAID else { return nil }
        return charts.first { $0.id == chartAID }
    }

    private var chartB: NatalChart? {
        guard let chartBID else { return nil }
        return charts.first { $0.id == chartBID }
    }

    var body: some View {
        Group {
            if charts.count < 2 {
                emptyState
            } else {
                workspace
            }
        }
        .background(Color.appBackground)
        .navigationTitle("Sinastría")
        .onAppear(perform: ensureInitialSelection)
        .onChange(of: charts) { _, _ in ensureInitialSelection() }
        .onDisappear {
            calculationTask?.cancel()
            noteTask?.cancel()
        }
    }

    private var workspace: some View {
        VStack(spacing: 0) {
            controls
            Divider()
            if isCalculating {
                ProgressView("Calculando sinastría…")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if let reading {
                results(reading)
            } else {
                readyState
            }
        }
    }

    private var controls: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .bottom, spacing: 14) {
                chartPicker(title: "Persona A", selection: $chartAID)
                Button {
                    swap(&chartAID, &chartBID)
                    reading = nil
                } label: {
                    Image(systemName: "arrow.left.arrow.right")
                        .frame(width: 28, height: 28)
                }
                .buttonStyle(.bordered)
                .help("Intercambiar cartas")
                chartPicker(title: "Persona B", selection: $chartBID)
                Spacer()
                Toggle("Mostrar sin texto", isOn: $showAspectsWithoutText)
                    .toggleStyle(.checkbox)
                Button {
                    calculate()
                } label: {
                    Label("Calcular", systemImage: "sparkles")
                }
                .buttonStyle(.borderedProminent)
                .tint(.appAccentFill)
                .disabled(chartA == nil || chartB == nil || chartAID == chartBID || isCalculating)
            }

            if let message = statusMessage {
                Label(message, systemImage: "checkmark.circle.fill")
                    .font(.caption)
                    .foregroundColor(.appSecondaryAccent)
            }
            if let errorMessage {
                Label(errorMessage, systemImage: "exclamationmark.triangle.fill")
                    .font(.caption)
                    .foregroundColor(.red)
            }
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 14)
        .background(Color.appPanel)
    }

    private func chartPicker(title: String, selection: Binding<UUID?>) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(title)
                .font(.caption.weight(.semibold))
                .foregroundColor(.secondary)
            Picker(title, selection: selection) {
                ForEach(charts) { chart in
                    Text(chart.name.isEmpty ? chart.birthDate : chart.name)
                        .tag(Optional(chart.id))
                }
            }
            .labelsHidden()
            .frame(width: 220)
        }
    }

    private func results(_ reading: SynastryReading) -> some View {
        VStack(spacing: 0) {
            summaryBar(reading)
            SynastryWheelView(
                reading: reading,
                aspects: visibleAspects(reading)
            )
            .frame(minHeight: 300, idealHeight: 340, maxHeight: 380)
            .padding(18)
            Divider()
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 14) {
                    section(reading, direction: .aToB)
                    section(reading, direction: .bToA)
                }
                .padding(18)
            }
        }
    }

    private func summaryBar(_ reading: SynastryReading) -> some View {
        HStack(spacing: 14) {
            Label(reading.coverageSummary, systemImage: "text.book.closed")
                .font(.subheadline.weight(.medium))
            if reading.missingTextCount > 0 {
                Text(showAspectsWithoutText
                     ? "\(reading.missingTextCount) aspectos sin texto visibles"
                     : "\(reading.missingTextCount) aspectos sin texto ocultos")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            Spacer()
            Button {
                createJoplinNote(reading)
            } label: {
                if isCreatingNote {
                    ProgressView()
                        .controlSize(.small)
                } else {
                    Label("Crear nota Joplin", systemImage: "note.text.badge.plus")
                }
            }
            .buttonStyle(.bordered)
            .disabled(isCreatingNote)
            PDFExportButton(
                chartName: "\(displayName(reading.chartA)) + \(displayName(reading.chartB))",
                reportType: "Informe de sinastría",
                generate: { pageSize in
                    try await SynastryReportBuilder.generate(from: reading, pageSize: pageSize)
                }
            )
            .environmentObject(appState)
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 11)
        .background(Color.appSurface)
    }

    private func section(_ reading: SynastryReading, direction: SynastryDirection) -> some View {
        let items = displayedAspects(reading, direction: direction)
        return VStack(alignment: .leading, spacing: 10) {
            Text(sectionTitle(reading, direction: direction))
                .appSectionHeader()
            if items.isEmpty {
                Text("No hay aspectos con texto en esta dirección.")
                    .font(.callout)
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .appCard()
            } else {
                ForEach(items) { aspect in
                    SynastryAspectRow(aspect: aspect)
                }
            }
        }
    }

    private func displayedAspects(_ reading: SynastryReading, direction: SynastryDirection) -> [SynastryAspect] {
        visibleAspects(reading)
            .filter { $0.direction == direction }
    }

    private func visibleAspects(_ reading: SynastryReading) -> [SynastryAspect] {
        reading.aspects
            .filter { showAspectsWithoutText || $0.hasText }
            .sorted {
                if $0.hasText != $1.hasText { return $0.hasText && !$1.hasText }
                return $0.orb < $1.orb
            }
    }

    private func sectionTitle(_ reading: SynastryReading, direction: SynastryDirection) -> String {
        switch direction {
        case .aToB:
            return "\(displayName(reading.chartA)) sobre \(displayName(reading.chartB))"
        case .bToA:
            return "\(displayName(reading.chartB)) sobre \(displayName(reading.chartA))"
        }
    }

    private var readyState: some View {
        VStack(spacing: 10) {
            Image(systemName: "person.2.circle")
                .font(.system(size: 44))
                .foregroundColor(.secondary)
            Text("Elige dos cartas guardadas y calcula la sinastría.")
                .font(.headline)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "person.2.slash")
                .font(.system(size: 48))
                .foregroundColor(.secondary)
            Text("Necesitas al menos dos cartas guardadas")
                .font(.headline)
                .foregroundColor(.secondary)
            Text("Guarda cartas natales desde Nueva Carta para compararlas aquí.")
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func ensureInitialSelection() {
        guard charts.count >= 2 else {
            chartAID = nil
            chartBID = nil
            reading = nil
            return
        }
        if chartAID == nil || !charts.contains(where: { $0.id == chartAID }) {
            chartAID = charts[0].id
        }
        if chartBID == nil || !charts.contains(where: { $0.id == chartBID }) || chartAID == chartBID {
            chartBID = charts.first { $0.id != chartAID }?.id
        }
    }

    private func calculate() {
        guard let chartA, let chartB, chartA.id != chartB.id else { return }
        calculationTask?.cancel()
        statusMessage = nil
        errorMessage = nil
        isCalculating = true
        let store = appState.corpusStore
        calculationTask = Task {
            let worker = Task.detached(priority: .userInitiated) {
                store.buildSynastryReading(chartA: chartA, chartB: chartB)
            }
            let result = await withTaskCancellationHandler {
                await worker.value
            } onCancel: {
                worker.cancel()
            }
            guard !Task.isCancelled else { return }
            reading = result
            isCalculating = false
        }
    }

    private func createJoplinNote(_ reading: SynastryReading) {
        noteTask?.cancel()
        statusMessage = nil
        errorMessage = nil
        isCreatingNote = true
        let settings = appState.joplinSettings
        noteTask = Task {
            do {
                let service = JoplinClipperService(settings: settings)
                try await service.createNote(
                    title: "Sinastría - \(displayName(reading.chartA)) y \(displayName(reading.chartB))",
                    body: SynastryNoteBuilder.markdown(reading: reading)
                )
                guard !Task.isCancelled else { return }
                statusMessage = "Nota creada en Joplin."
            } catch {
                guard !Task.isCancelled else { return }
                errorMessage = error.localizedDescription
            }
            isCreatingNote = false
        }
    }
}

private struct SynastryAspectRow: View {
    let aspect: SynastryAspect
    @State private var expanded = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Button {
                expanded.toggle()
            } label: {
                HStack(alignment: .top, spacing: 12) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(title)
                            .font(.subheadline.weight(.semibold))
                            .foregroundColor(.appPrimaryText)
                            .multilineTextAlignment(.leading)
                        HStack(spacing: 8) {
                            Text("Orbe \(String(format: "%.2f°", aspect.orb))")
                            Text(aspect.corpusClave)
                        }
                        .font(.caption.monospacedDigit())
                        .foregroundColor(.secondary)
                    }
                    Spacer()
                    Image(systemName: expanded ? "chevron.up" : "chevron.down")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .padding(.top, 3)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            if expanded {
                VStack(alignment: .leading, spacing: 8) {
                    if let interpretation = aspect.interpretation {
                        Text(interpretation.texto)
                            .font(.callout)
                            .foregroundColor(.appPrimaryText.opacity(0.88))
                            .lineSpacing(4)
                        if !interpretation.fuente.isEmpty {
                            Text(interpretation.fuente)
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    } else {
                        Text("Sin interpretación disponible en el corpus.")
                            .font(.callout)
                            .foregroundColor(.secondary)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 14)
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .background(Color.appPanel)
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(expanded ? Color.appAccentFill.opacity(0.45) : Color.appBorder.opacity(0.75), lineWidth: 1)
        )
        .animation(.easeInOut(duration: 0.18), value: expanded)
    }

    private var title: String {
        "\(aspect.sourcePlanetLabel) de \(aspect.direction.sourceInitial) \(aspect.aspectLabel) \(aspect.targetPlanetLabel) de \(aspect.direction.targetInitial)"
    }
}

private struct SynastryWheelView: View {
    let reading: SynastryReading
    let aspects: [SynastryAspect]

    var body: some View {
        GeometryReader { proxy in
            let side = min(proxy.size.width, proxy.size.height)
            let center = CGPoint(x: proxy.size.width / 2, y: proxy.size.height / 2)
            let outerRadius = side * 0.46
            let innerRadius = side * 0.32
            let aspectOuterRadius = side * 0.36
            let aspectInnerRadius = side * 0.24

            ZStack {
                Canvas { context, _ in
                    drawBase(
                        context: &context,
                        center: center,
                        outerRadius: outerRadius,
                        innerRadius: innerRadius
                    )
                    drawAspects(
                        context: &context,
                        center: center,
                        outerRadius: aspectOuterRadius,
                        innerRadius: aspectInnerRadius
                    )
                }

                ForEach(0..<12, id: \.self) { index in
                    let longitude = Double(index * 30 + 15)
                    Text(SIGN_LABELS[index].split(separator: " ").first.map(String.init) ?? "")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .position(point(for: longitude, center: center, radius: outerRadius - 18))
                        .allowsHitTesting(false)
                }

                ForEach(reading.chartA.bodies) { body in
                    wheelLabel(
                        text: body.symbol,
                        marker: "A",
                        color: .appAccentFill,
                        position: point(for: body.longitude, center: center, radius: outerRadius + 2)
                    )
                }

                ForEach(reading.chartB.bodies) { body in
                    wheelLabel(
                        text: body.symbol,
                        marker: "B",
                        color: .appSecondaryAccent,
                        position: point(for: body.longitude, center: center, radius: innerRadius)
                    )
                }

                VStack(spacing: 4) {
                    Text("A")
                        .foregroundColor(.appAccentFill)
                    Text("B")
                        .foregroundColor(.appSecondaryAccent)
                }
                .font(.caption.weight(.bold))
                .padding(7)
                .background(Color.appPanel)
                .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
            }
        }
        .background(Color.appSurface)
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(Color.appBorder, lineWidth: 1)
        )
    }

    private func wheelLabel(text: String, marker: String, color: Color, position: CGPoint) -> some View {
        ZStack(alignment: .topTrailing) {
            Text(text)
                .font(.caption.weight(.bold))
                .foregroundColor(.appPrimaryText)
                .frame(width: 24, height: 24)
                .background(Color.appPanel)
                .clipShape(RoundedRectangle(cornerRadius: 5, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 5, style: .continuous)
                        .stroke(color.opacity(0.8), lineWidth: 1)
                )
            Text(marker)
                .font(.system(size: 7, weight: .bold))
                .foregroundColor(.appAccentForeground)
                .frame(width: 11, height: 11)
                .background(color)
                .clipShape(Circle())
                .offset(x: 4, y: -4)
        }
        .position(position)
    }

    private func drawBase(
        context: inout GraphicsContext,
        center: CGPoint,
        outerRadius: CGFloat,
        innerRadius: CGFloat
    ) {
        for radius in [outerRadius, innerRadius, outerRadius * 0.58] {
            context.stroke(
                Path(ellipseIn: CGRect(x: center.x - radius, y: center.y - radius, width: radius * 2, height: radius * 2)),
                with: .color(Color.appBorder),
                lineWidth: 1
            )
        }

        for index in 0..<12 {
            let longitude = Double(index * 30)
            var path = Path()
            path.move(to: point(for: longitude, center: center, radius: outerRadius * 0.58))
            path.addLine(to: point(for: longitude, center: center, radius: outerRadius))
            context.stroke(path, with: .color(Color.appBorder.opacity(0.55)), lineWidth: 1)
        }
    }

    private func drawAspects(
        context: inout GraphicsContext,
        center: CGPoint,
        outerRadius: CGFloat,
        innerRadius: CGFloat
    ) {
        let chartAMap = Dictionary(uniqueKeysWithValues: reading.chartA.bodies.map { ($0.key, $0) })
        let chartBMap = Dictionary(uniqueKeysWithValues: reading.chartB.bodies.map { ($0.key, $0) })

        for aspect in aspects {
            let sourceMap = aspect.direction == .aToB ? chartAMap : chartBMap
            let targetMap = aspect.direction == .aToB ? chartBMap : chartAMap
            guard let source = sourceMap[aspect.sourcePlanetKey],
                  let target = targetMap[aspect.targetPlanetKey]
            else {
                continue
            }
            var path = Path()
            path.move(to: point(for: source.longitude, center: center, radius: outerRadius))
            path.addLine(to: point(for: target.longitude, center: center, radius: innerRadius))
            context.stroke(
                path,
                with: .color(color(for: aspect.aspectKey).opacity(aspect.hasText ? 0.58 : 0.22)),
                lineWidth: aspect.hasText ? 1.15 : 0.8
            )
        }
    }

    private func point(for longitude: Double, center: CGPoint, radius: CGFloat) -> CGPoint {
        let radians = (longitude - 90) * .pi / 180
        let cosine = CGFloat(Darwin.cos(Double(radians)))
        let sine = CGFloat(Darwin.sin(Double(radians)))
        return CGPoint(x: center.x + cosine * radius, y: center.y + sine * radius)
    }

    private func color(for aspectKey: String) -> Color {
        switch aspectKey {
        case "CONJUNCION": return Color(hex: "#d97706")
        case "SEXTIL": return Color(hex: "#2563eb")
        case "CUADRADO": return Color(hex: "#dc2626")
        case "TRIGONO": return Color(hex: "#15803d")
        case "OPOSICION": return Color(hex: "#a21caf")
        default: return .secondary
        }
    }
}

enum SynastryNoteBuilder {
    static func markdown(reading: SynastryReading) -> String {
        var lines: [String] = [
            "# Sinastría - \(displayName(reading.chartA)) y \(displayName(reading.chartB))",
            "",
            "## Cartas",
            "- Persona A: \(displayName(reading.chartA)) · \(reading.chartA.birthDate) \(reading.chartA.birthTime) · \(reading.chartA.placeName)",
            "- Persona B: \(displayName(reading.chartB)) · \(reading.chartB.birthDate) \(reading.chartB.birthTime) · \(reading.chartB.placeName)",
            "- Cobertura: \(reading.coverageSummary)",
            "- Sin texto: \(reading.missingTextCount)",
            "",
        ]

        for direction in SynastryDirection.allCases {
            let title: String
            switch direction {
            case .aToB:
                title = "\(displayName(reading.chartA)) sobre \(displayName(reading.chartB))"
            case .bToA:
                title = "\(displayName(reading.chartB)) sobre \(displayName(reading.chartA))"
            }
            lines += ["## \(title)", ""]
            let aspects = reading.aspects
                .filter { $0.direction == direction && $0.hasText }
                .sorted { $0.orb < $1.orb }
            if aspects.isEmpty {
                lines.append("_Sin textos disponibles._")
                lines.append("")
                continue
            }
            for aspect in aspects {
                lines += [
                    "### \(aspect.sourcePlanetLabel) de \(aspect.direction.sourceInitial) \(aspect.aspectLabel) \(aspect.targetPlanetLabel) de \(aspect.direction.targetInitial)",
                    "- Orbe: \(String(format: "%.2f°", aspect.orb))",
                    "- Clave: `\(aspect.corpusClave)`",
                    "",
                    aspect.interpretation?.texto ?? "",
                    "",
                ]
            }
        }

        return lines.joined(separator: "\n")
    }
}

private func displayName(_ chart: NatalChart) -> String {
    chart.name.isEmpty ? chart.birthDate : chart.name
}

private extension PlanetBody {
    var symbol: String {
        label.split(separator: " ").first.map(String.init) ?? label
    }
}
