import AppKit
import SwiftUI

struct CrossPersonalView: View {
    @EnvironmentObject var appState: AppState

    let chart: NatalChart
    let referenceDate: Date
    private let narrativeClient = AnthropicClient()

    @State private var state: CrossPersonalState?
    @State private var narrative: CrossPersonalNarrative?
    @State private var isLoading = false
    @State private var isExporting = false
    @State private var isNarrativeLoading = false
    @State private var errorMessage: String?
    @State private var statusMessage: String?
    @State private var selectedLayer: CrossLayerKind = .annual
    @State private var selectedModel: CrossPersonalNarrativeModel = .sonnet

    init(chart: NatalChart, referenceDate: Date = Date()) {
        self.chart = chart
        self.referenceDate = referenceDate
    }

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()
            content
        }
        .background(Color.appBackground)
        .task(id: chart.id) { await load() }
        .onChange(of: selectedModel) { _, model in
            Task { await narrativeClient.setModel(model.modelID) }
        }
    }

    private var header: some View {
        HStack(alignment: .center, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Estado cross")
                    .font(.title3.weight(.semibold))
                    .foregroundColor(.appPrimaryText)
                Text("Síntesis personal por capas: anual, medio plazo, corto plazo y activadores lunares/eclípticos.")
                    .font(.caption)
                    .foregroundColor(.secondary)
                if let signature = state?.natalSignature {
                    Text(signatureLine(signature))
                        .font(.caption.monospacedDigit())
                        .foregroundColor(.secondary)
                }
            }
            Spacer()
            Picker("Modelo", selection: $selectedModel) {
                ForEach(CrossPersonalNarrativeModel.allCases) { model in
                    Text(model.label).tag(model)
                }
            }
            .labelsHidden()
            .frame(width: 190)
            .disabled(isNarrativeLoading)

            Button { Task { await generateNarrative() } } label: {
                if isNarrativeLoading {
                    HStack(spacing: 8) {
                        ProgressView()
                            .controlSize(.small)
                        Text("Generando…")
                    }
                } else {
                    Label("Generar informe redactado", systemImage: "text.bubble")
                }
            }
            .buttonStyle(.borderedProminent)
            .disabled(state == nil || isNarrativeLoading || !narrativeClient.hasAPIKey())

            Button { Task { await load() } } label: {
                Label("Recalcular", systemImage: "arrow.clockwise")
            }
            .buttonStyle(.bordered)
            .disabled(isLoading || isNarrativeLoading)

            Button { exportToJoplin() } label: {
                Label(isExporting ? "Exportando…" : "Exportar a Joplin", systemImage: "square.and.arrow.up")
            }
            .disabled(state == nil || isExporting)
            .buttonStyle(.borderedProminent)
        }
        .padding(18)
    }

    @ViewBuilder
    private var content: some View {
        if isLoading {
            ProgressView("Calculando estado cross…")
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else if let errorMessage {
            VStack(spacing: 12) {
                Image(systemName: "exclamationmark.triangle")
                    .font(.system(size: 42))
                    .foregroundColor(.appWarning)
                Text(errorMessage)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else if let state {
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    if let statusMessage {
                        Text(statusMessage)
                            .font(.callout)
                            .foregroundColor(statusMessage.contains("Error") ? .appWarning : .appSecondaryAccent)
                    }
                    natalSignatureCard(state.natalSignature)
                    topTopicsSection(state.topics)
                    narrativePanel()
                    layerTabs(state.layers)
                }
                .padding(18)
            }
        } else {
            Text("Sin datos cross-personales.")
                .foregroundColor(.secondary)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    private func natalSignatureCard(_ signature: CrossNatalSignature) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Label("Firma natal", systemImage: "person.crop.circle.badge.checkmark")
                .appSectionHeader()
            HStack(alignment: .top, spacing: 16) {
                metric("Sol", "\(signature.sun.degree) · casa \(signature.sun.house)")
                metric("Luna", "\(signature.moon.degree) · casa \(signature.moon.house)")
                metric("ASC", signature.ascendant.degree)
                metric("MC", signature.mc.degree)
            }
            HStack(alignment: .top, spacing: 16) {
                metric("Secta", signature.sect.label)
                metric("Regente ASC", signature.ascendantRulerLabel)
                metric("Almuten", signature.almutenFigurisLabel)
                metric("Regente genitura", signature.rulerOfGenitureLabel)
            }
            if !signature.prominentLots.isEmpty {
                Text(signature.prominentLots.map { "\($0.kind.title): \($0.signLabel), casa \($0.house), reg. \($0.rulerLabel)" }.joined(separator: " · "))
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .appCard()
    }

    private func topTopicsSection(_ topics: [PriorityTopic]) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Label("Top topics", systemImage: "list.number")
                .appSectionHeader()
            if topics.isEmpty {
                Text("No hay prioridades agregadas.")
                    .foregroundColor(.secondary)
            } else {
                ForEach(Array(topics.prefix(10).enumerated()), id: \.element.id) { index, topic in
                    topTopicRow(index: index, topic: topic)
                }
            }
        }
        .appCard()
    }

    private func topTopicRow(index: Int, topic: PriorityTopic) -> some View {
        let rank = String(index + 1)
        let score = String(format: "%.3f", topic.convergenceScore)
        let layers = topic.layers.map(\.label).joined(separator: ", ")
        return HStack(alignment: .top, spacing: 10) {
            Text(rank)
                .font(.caption.monospacedDigit().weight(.bold))
                .foregroundColor(.white)
                .frame(width: 24, height: 24)
                .background(Circle().fill(Color.appAccentFill))
            VStack(alignment: .leading, spacing: 3) {
                HStack {
                    Text(topic.title).font(.subheadline.weight(.semibold))
                    Spacer()
                    Text(score)
                        .font(.caption.monospacedDigit())
                        .foregroundColor(.secondary)
                }
                Text("\(topic.layerCount) capas · \(layers)")
                    .font(.caption)
                    .foregroundColor(.secondary)
                Text(topic.summary)
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
        }
        .padding(10)
        .background(Color.appSurface)
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
    }

    @ViewBuilder
    private func narrativePanel() -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .center) {
                Label("Informe redactado", systemImage: "doc.richtext")
                    .appSectionHeader()
                Spacer()
                if isNarrativeLoading {
                    ProgressView()
                        .controlSize(.small)
                }
                Button("Copiar Markdown") { copyNarrativeMarkdown() }
                    .buttonStyle(.bordered)
                    .disabled(narrative == nil)
                Button("Guardar en Joplin") { saveNarrativeToJoplin() }
                    .buttonStyle(.borderedProminent)
                    .disabled(narrative == nil || isExporting)
            }

            if let narrative {
                ScrollView {
                    Text(AttributedString(markdownOrPlain: narrative.markdown))
                        .font(.body)
                        .foregroundColor(.appPrimaryText)
                        .textSelection(.enabled)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(12)
                }
                .frame(minHeight: 180, maxHeight: 420)
                .background(Color.appSurface)
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))

                Text(narrativeUsageLine(narrative))
                    .font(.caption.monospacedDigit())
                    .foregroundColor(.secondary)
            } else {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Todavía no hay informe redactado.")
                        .foregroundColor(.secondary)
                    if !narrativeClient.hasAPIKey() {
                        Text("Configura ANTHROPIC_API_KEY o guarda una API key en Ajustes para habilitar la generación.")
                            .font(.caption)
                            .foregroundColor(.appWarning)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(12)
                .background(Color.appSurface)
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
            }
        }
        .appCard()
    }

    private func layerTabs(_ layers: [CrossLayer]) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Picker("Capa", selection: $selectedLayer) {
                ForEach(CrossLayerKind.allCases, id: \.self) { layer in
                    Text(layer.label).tag(layer)
                }
            }
            .pickerStyle(.segmented)

            let layer = layers.first { $0.kind == selectedLayer }
            if let layer, !layer.signals.isEmpty {
                ForEach(layer.signals) { signal in signalRow(signal) }
            } else {
                Text("Sin señales para esta capa.")
                    .foregroundColor(.secondary)
                    .padding(.vertical, 8)
            }
        }
        .appCard()
    }

    private func signalRow(_ signal: CrossSignal) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(signal.summary)
                        .font(.subheadline.weight(.semibold))
                        .foregroundColor(.appPrimaryText)
                    Text("\(signal.source) · \(signal.subject.label)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                Spacer()
                Text(String(format: "%.2f", signal.weight))
                    .font(.caption.monospacedDigit())
                    .foregroundColor(.secondary)
            }
            if let detail = signal.detail, !detail.isEmpty {
                Text(detail)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            if let exactAt = signal.exactAt {
                Text("Exacto: \(displayDate(exactAt))")
                    .font(.caption2.monospacedDigit())
                    .foregroundColor(.secondary)
            } else if let startsAt = signal.startsAt, let endsAt = signal.endsAt {
                Text("Periodo: \(displayDate(startsAt)) → \(displayDate(endsAt))")
                    .font(.caption2.monospacedDigit())
                    .foregroundColor(.secondary)
            }
        }
        .padding(10)
        .background(Color.appSurface)
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
    }

    private func metric(_ title: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title).font(.caption.weight(.semibold)).foregroundColor(.secondary)
            Text(value.isEmpty ? "—" : value).font(.subheadline).foregroundColor(.appPrimaryText)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func signatureLine(_ signature: CrossNatalSignature) -> String {
        "Sol \(signature.sun.signLabel) · Luna \(signature.moon.signLabel) · ASC \(signature.ascendant.signLabel) · \(signature.sect.label) · Almuten \(signature.almutenFigurisLabel)"
    }

    @MainActor
    private func load() async {
        isLoading = true
        errorMessage = nil
        statusMessage = nil
        narrative = nil
        defer { isLoading = false }
        do {
            state = try await CrossPersonalAssembler.state(
                chart: chart,
                referenceDate: referenceDate,
                corpusStore: appState.corpusStore
            )
        } catch {
            state = nil
            errorMessage = error.localizedDescription
        }
    }

    @MainActor
    private func generateNarrative() async {
        guard let state else { return }
        isNarrativeLoading = true
        statusMessage = nil
        defer { isNarrativeLoading = false }
        do {
            await narrativeClient.setModel(selectedModel.modelID)
            let builder = CrossPersonalNarrativeBuilder(client: narrativeClient)
            narrative = try await builder.build(state: state)
            statusMessage = "Informe redactado generado."
        } catch CrossPersonalNarrativeError.anthropic(let anthropicError) {
            statusMessage = narrativeErrorToast(anthropicError)
        } catch {
            statusMessage = "Error al generar informe: \(error.localizedDescription)"
        }
    }

    private func exportToJoplin() {
        guard let state else { return }
        isExporting = true
        statusMessage = nil
        let title = CrossPersonalNoteBuilder.noteTitle(chart: chart, referenceDate: referenceDate)
        let body = CrossPersonalNoteBuilder.markdown(state: state)
        let settings = appState.joplinSettings
        Task {
            do {
                let service = JoplinClipperService(settings: settings)
                try await service.createNote(title: title, body: body)
                await MainActor.run { statusMessage = "Nota creada en Joplin."; isExporting = false }
            } catch {
                await MainActor.run { statusMessage = "Error al exportar a Joplin: \(error.localizedDescription)"; isExporting = false }
            }
        }
    }

    private func saveNarrativeToJoplin() {
        guard let narrative else { return }
        isExporting = true
        statusMessage = nil
        let settings = appState.joplinSettings
        Task {
            do {
                let service = JoplinClipperService(settings: settings)
                try await service.createNote(
                    title: narrative.suggestedJoplinTitle(),
                    body: narrative.joplinMarkdown()
                )
                await MainActor.run {
                    statusMessage = "Informe redactado guardado en Joplin."
                    isExporting = false
                }
            } catch {
                await MainActor.run {
                    statusMessage = "Error al guardar informe en Joplin: \(error.localizedDescription)"
                    isExporting = false
                }
            }
        }
    }

    private func copyNarrativeMarkdown() {
        guard let markdown = narrative?.markdown else { return }
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(markdown, forType: .string)
        statusMessage = "Markdown copiado al portapapeles."
    }

    private func narrativeUsageLine(_ narrative: CrossPersonalNarrative) -> String {
        let input = decimal(narrative.usage.inputTokens)
        let output = decimal(narrative.usage.outputTokens)
        return "\(input) tokens entrada · \(output) salida · $\(String(format: "%.4f", narrative.estimatedCostUSD)) USD"
    }

    private func narrativeErrorToast(_ error: AnthropicError) -> String {
        switch error {
        case .unauthorized:
            return "Revisa la API key en Ajustes"
        case .rateLimited:
            return "Anthropic está limitando la llamada. Espera unos minutos antes de reintentar."
        default:
            return "Error al generar informe: \(error.localizedDescription)"
        }
    }

    private func decimal(_ value: Int) -> String {
        let formatter = NumberFormatter()
        formatter.locale = Locale(identifier: "es_ES")
        formatter.numberStyle = .decimal
        formatter.maximumFractionDigits = 0
        return formatter.string(from: NSNumber(value: value)) ?? "\(value)"
    }

    private func displayDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "es_ES")
        formatter.timeZone = TimeZone(identifier: chart.timezone) ?? .current
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        return formatter.string(from: date)
    }
}

private enum CrossPersonalNarrativeModel: String, CaseIterable, Identifiable {
    case sonnet
    case opus

    var id: String { rawValue }

    var label: String {
        switch self {
        case .sonnet: return "Sonnet 4.6 (rápido)"
        case .opus: return "Opus 4.7 (calidad)"
        }
    }

    var modelID: String {
        switch self {
        case .sonnet: return "claude-sonnet-4-6"
        case .opus: return "claude-opus-4-7"
        }
    }
}

private extension AttributedString {
    init(markdownOrPlain markdown: String) {
        if let parsed = try? AttributedString(markdown: markdown) {
            self = parsed
        } else {
            self = AttributedString(markdown)
        }
    }
}

enum CrossPersonalNoteBuilder {
    static func noteTitle(chart: NatalChart, referenceDate: Date) -> String {
        "Estado cross — \(chart.name.isEmpty ? "Carta" : chart.name) — \(date(referenceDate))"
    }

    static func markdown(state: CrossPersonalState) -> String {
        var lines: [String] = [
            "# Estado cross — \(state.metadata.chartName)",
            "",
            "- Referencia: \(date(state.metadata.referenceDate))",
            "- Generado: \(dateTime(state.metadata.generatedAt))",
            "- Engine: CrossPersonalEngine \(state.metadata.engineVersion)",
            "- Corpus reference: AstroMalik `corpus.db` vía `CorpusStore`.",
            "",
            "## Firma natal",
            "- Sol: \(state.natalSignature.sun.degree), casa \(state.natalSignature.sun.house)",
            "- Luna: \(state.natalSignature.moon.degree), casa \(state.natalSignature.moon.house)",
            "- ASC: \(state.natalSignature.ascendant.degree)",
            "- MC: \(state.natalSignature.mc.degree)",
            "- Secta: \(state.natalSignature.sect.label)",
            "- Regente ASC: \(state.natalSignature.ascendantRulerLabel)",
            "- Almuten Figuris: \(state.natalSignature.almutenFigurisLabel)",
            "- Regente de la Genitura: \(state.natalSignature.rulerOfGenitureLabel)",
            "",
            "## Top topics",
        ]

        if state.topics.isEmpty { lines.append("- Sin prioridades agregadas.") }
        for (index, topic) in state.topics.prefix(10).enumerated() {
            lines.append("\(index + 1). **\(topic.title)** — score \(String(format: "%.3f", topic.convergenceScore)), \(topic.layerCount) capas")
            lines.append("   - \(topic.summary)")
            lines.append("   - Capas: \(topic.layers.map(\.label).joined(separator: ", "))")
        }

        for layer in state.layers {
            lines += ["", "## \(layer.label)"]
            if layer.signals.isEmpty { lines.append("- Sin señales.") }
            for signal in layer.signals {
                lines.append("- **\(signal.summary)** (`\(signal.source)`, peso \(String(format: "%.2f", signal.weight)))")
                if let detail = signal.detail { lines.append("  - \(detail)") }
                if let exactAt = signal.exactAt { lines.append("  - Exacto: \(date(exactAt))") }
                else if let startsAt = signal.startsAt, let endsAt = signal.endsAt { lines.append("  - Periodo: \(date(startsAt)) → \(date(endsAt))") }
            }
        }

        return lines.joined(separator: "\n")
    }

    private static func date(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "es_ES")
        formatter.timeZone = TimeZone(identifier: "Europe/Madrid") ?? .current
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: date)
    }

    private static func dateTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "es_ES")
        formatter.timeZone = TimeZone(identifier: "Europe/Madrid") ?? .current
        formatter.dateFormat = "yyyy-MM-dd HH:mm"
        return formatter.string(from: date)
    }
}
