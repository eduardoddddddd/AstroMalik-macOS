import Foundation

/// Builder del informe PDF cross-personal. Es la corona del bloque
/// PDF: integra la narrativa redactada por Anthropic con los datos
/// estructurados del sintetizador.
///
/// Acepta dos modos:
/// - **Con narrativa** (`narrative != nil`): el PDF muestra la lectura
///   redactada como texto principal y los datos del state como tablas
///   de soporte y apéndice.
/// - **Solo datos** (`narrative == nil`): el PDF se compone únicamente
///   con los datos estructurados del state. Útil para previsualizar el
///   informe sin coste de API.
struct CrossPersonalReportBuilder {

    static func generate(
        state: CrossPersonalState,
        narrative: CrossPersonalNarrative? = nil,
        scope: CrossPersonalNarrativeScope = .complete
    ) async throws -> Data {
        let data = makeData(state: state, narrative: narrative, scope: scope)
        return try await ReportService().generate(request: ReportRequest(templateName: "cross_personal", data: data))
    }

    static func makeData(
        state: CrossPersonalState,
        narrative: CrossPersonalNarrative?,
        scope: CrossPersonalNarrativeScope,
        generatedAt: Date = Date()
    ) -> CrossPersonalReportData {
        let generatedDate = ReportFormatting.generatedDate(generatedAt)
        let referenceLabel = referenceDateLabel(state.metadata.referenceDate)
        let signature = makeSignature(state.natalSignature)
        let narrativeSections = makeNarrativeSections(narrative: narrative)

        return CrossPersonalReportData(
            header: ReportHeaderData(
                chartName: state.metadata.chartName.isEmpty ? "Carta natal" : state.metadata.chartName,
                reportTitle: "Informe cross-personal",
                generatedDate: generatedDate
            ),
            cover: ReportCoverData(
                chartName: state.metadata.chartName.isEmpty ? "Carta natal" : state.metadata.chartName,
                birthDate: "",
                birthTime: "",
                place: "",
                generatedDate: generatedDate,
                ascSign: state.natalSignature.ascendant.signLabel,
                ascGlyph: signGlyph(state.natalSignature.ascendant.signLabel)
            ),
            includeTOC: true,
            generatedDate: generatedDate,
            referenceLabel: referenceLabel,
            scopeLabel: scopeLabel(scope),
            narrative: narrativeSections,
            signature: signature,
            annualSignals: signalRows(in: state, layer: .annual),
            mediumSignals: signalRows(in: state, layer: .mediumTerm),
            shortSignals: signalRows(in: state, layer: .shortTerm),
            lunarSignals: signalRows(in: state, layer: .lunar),
            topics: topicRows(state.topics),
            trazabilityRows: trazabilityRows(narrative: narrative)
        )
    }

    // MARK: - Narrative

    private static func makeNarrativeSections(narrative: CrossPersonalNarrative?) -> CrossPersonalNarrativeSections {
        guard let narrative else { return .empty }
        let sections = MarkdownToHTML.sectionsByH2(narrative.markdown)
        func pick(_ keys: [String]) -> String {
            for key in keys {
                if let html = sections[key], !html.isEmpty { return html }
            }
            return ""
        }
        return CrossPersonalNarrativeSections(
            executiveSummary: pick(["sintesis_ejecutiva", "sintesis"]),
            firmaNatal: pick(["tu_firma_natal", "firma_natal"]),
            yearInProgress: pick(["el_ano_en_curso", "ano_en_curso", "capa_anual"]),
            mediumTerm: pick(["medio_plazo_12_meses", "medio_plazo"]),
            shortTerm: pick(["corto_plazo_proximos_6_meses", "corto_plazo"]),
            lunarLayer: pick(["capa_lunar_lunaciones_y_eclipses_proximos", "capa_lunar"]),
            convergences: pick(["temas_convergentes_que_pesa_de_verdad", "temas_convergentes"]),
            closing: pick(["cierre"])
        )
    }

    // MARK: - Signature

    private static func makeSignature(_ signature: CrossNatalSignature) -> CrossPersonalSignatureCard {
        let prominentLots = signature.prominentLots.map { lot in
            "\(lot.kind.title) en \(lot.signLabel), casa \(lot.house), regente \(lot.rulerLabel)"
        }
        let patterns = signature.aspectPatterns.map { pattern in
            "\(pattern.title) — \(pattern.planetLabels.joined(separator: " · "))"
        }
        let stars = signature.fixedStarContacts.map { contact in
            "\(contact.starName) sobre \(contact.targetLabel) (\(ReportFormatting.decimal(contact.orb, digits: 2))°)"
        }
        return CrossPersonalSignatureCard(
            sunLabel: composedPlacementLabel(signature.sun),
            moonLabel: composedPlacementLabel(signature.moon),
            ascLabel: "\(signature.ascendant.degree) — \(signature.ascendant.signLabel)",
            mcLabel: "\(signature.mc.degree) — \(signature.mc.signLabel)",
            sectLabel: signature.sect.label,
            ascRulerLabel: signature.ascendantRulerLabel,
            almutenLabel: signature.almutenFigurisLabel,
            genitureRulerLabel: signature.rulerOfGenitureLabel,
            prominentLots: prominentLots,
            aspectPatterns: patterns,
            elementBalance: elementBalanceLabel(signature.elementBalance),
            modalityBalance: modalityBalanceLabel(signature.modalityBalance),
            fixedStarsTop: stars
        )
    }

    private static func composedPlacementLabel(_ placement: SignedPlacement) -> String {
        guard !placement.label.isEmpty else { return "sin dato" }
        let retro = placement.retrograde ? " ℞" : ""
        return "\(placement.label)\(retro) · \(placement.signLabel) · casa \(placement.house) · \(placement.degree)"
    }

    private static func elementBalanceLabel(_ balance: ElementBalance) -> String {
        "Fuego \(balance.fire) · Tierra \(balance.earth) · Aire \(balance.air) · Agua \(balance.water)"
    }

    private static func modalityBalanceLabel(_ balance: ModalityBalance) -> String {
        "Cardinal \(balance.cardinal) · Fijo \(balance.fixed) · Mutable \(balance.mutable)"
    }

    // MARK: - Signal rows

    private static func signalRows(in state: CrossPersonalState, layer kind: CrossLayerKind) -> [CrossPersonalSignalRow] {
        guard let layer = state.layer(kind) else { return [] }
        return layer.signals.map { signal in
            CrossPersonalSignalRow(
                source: signal.source,
                subject: signal.subject.label,
                summary: signal.summary,
                detail: signal.detail ?? "",
                exactLabel: dateLabel(signal.exactAt ?? signal.startsAt),
                weight: ReportFormatting.decimal(signal.weight, digits: 2)
            )
        }
    }

    // MARK: - Topic rows

    private static func topicRows(_ topics: [PriorityTopic]) -> [CrossPersonalTopicRow] {
        topics.enumerated().map { index, topic in
            CrossPersonalTopicRow(
                rank: "\(index + 1)",
                title: topic.title,
                subject: topic.subject.label,
                score: ReportFormatting.decimal(topic.convergenceScore, digits: 2),
                layerCount: "\(topic.layerCount)",
                summary: topic.summary
            )
        }
    }

    // MARK: - Trazability

    private static func trazabilityRows(narrative: CrossPersonalNarrative?) -> [ReportMetricRow] {
        guard let narrative else {
            return [
                ReportMetricRow(label: "Modo", value: "Solo datos", detail: "Sin redacción Anthropic")
            ]
        }
        let cost = String(format: "$%.4f USD", narrative.estimatedCostUSD)
        return [
            ReportMetricRow(label: "Modelo", value: narrative.model, detail: "Sonnet/Opus/Haiku Anthropic"),
            ReportMetricRow(label: "Tokens entrada", value: "\(narrative.usage.inputTokens)", detail: "no cache"),
            ReportMetricRow(label: "Tokens salida", value: "\(narrative.usage.outputTokens)", detail: ""),
            ReportMetricRow(label: "Cache lectura", value: "\(narrative.usage.cacheReadInputTokens ?? 0)", detail: "tokens cacheados"),
            ReportMetricRow(label: "Cache creación", value: "\(narrative.usage.cacheCreationInputTokens ?? 0)", detail: "tokens guardados en cache"),
            ReportMetricRow(label: "Coste estimado", value: cost, detail: ""),
        ]
    }

    // MARK: - Labels

    private static func scopeLabel(_ scope: CrossPersonalNarrativeScope) -> String {
        switch scope {
        case .complete: return "Informe completo"
        case .annual: return "Foco anual"
        case .monthly: return "Foco mensual"
        case .weekly: return "Foco semanal"
        }
    }

    private static func referenceDateLabel(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "es_ES")
        formatter.dateStyle = .long
        formatter.timeStyle = .none
        return formatter.string(from: date)
    }

    private static func dateLabel(_ date: Date?) -> String {
        guard let date else { return "" }
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "es_ES")
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: date)
    }

    private static func signGlyph(_ signLabel: String) -> String {
        signLabel.split(separator: " ").first.map(String.init) ?? ""
    }
}
