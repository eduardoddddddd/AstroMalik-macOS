import SwiftUI

struct PrimaryDirectionDetailView: View {
    let enriched: EnrichedPrimaryDirection
    let contextualInterpretation: ContextualInterpretation?
    let speculumRows: [SpeculumRow]
    let isGeneratingInterpretation: Bool
    let contextualAvailability: String
    let onRequestInterpretation: () -> Void
    let onInvalidateInterpretation: () -> Void

    @State private var alternativesExpanded = false
    @State private var factorsExpanded = true
    @State private var speculumExpanded = false
    @State private var calculationExpanded = false

    private var direction: PrimaryDirection { enriched.direction }
    private var localReading: PrimaryDirectionLocalReading {
        PrimaryDirectionLocalReading.build(for: direction)
    }

    var body: some View {
        ScrollView(.vertical) {
            VStack(alignment: .leading, spacing: 14) {
                heroBlock
                mainTextBlock

                if contextualInterpretation != nil || isGeneratingInterpretation {
                    factorsSection
                } else {
                    contextualDiscovery
                }

                speculumSection
                calculationSection
            }
            .padding(16)
        }
        .background(Color.appBackground)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    private var heroBlock: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top, spacing: 12) {
                VStack(alignment: .leading, spacing: 6) {
                    Text(enriched.displaySummary)
                        .font(.title2.bold())
                        .foregroundStyle(.primary)
                        .fixedSize(horizontal: false, vertical: true)

                    Text(heroSubtitle)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer(minLength: 12)
                VStack(alignment: .trailing, spacing: 6) {
                    polarityBadge(direction.aspect.polarity)
                    weightBadge(direction.weight)
                }
            }

            HStack(spacing: 8) {
                metadataBadge(direction.directionType == .direct ? "Directa" : "Conversa", icon: direction.directionType == .direct ? "arrow.forward" : "arrow.backward")
                metadataBadge(direction.aspectPlane.displayName, icon: "globe")
                metadataBadge(direction.method.rawValue, icon: "scope")
            }
        }
        .padding(16)
        .background(Color.appSurface, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(Color.appBorder.opacity(0.55), lineWidth: 1)
        )
    }

    private var heroSubtitle: String {
        let peak = orbRange(months: direction.key.peakOrbMonths)
        return "\(exactAgeCompact) · \(formattedDate(direction.estimatedDate)) · peak \(peak)"
    }

    private var mainTextBlock: some View {
        let source = primaryTextSource
        return VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Fuente: \(source.label)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
                if hasAlternatives {
                    Button(alternativesExpanded ? "Ocultar alternativos" : "Ver alternativos") {
                        withAnimation(.easeInOut(duration: 0.16)) {
                            alternativesExpanded.toggle()
                        }
                    }
                    .font(.caption)
                    .buttonStyle(.borderless)
                }
            }

            Text(source.title)
                .font(.headline)
                .foregroundStyle(.primary)
                .fixedSize(horizontal: false, vertical: true)

            Text(source.text)
                .font(.body)
                .lineSpacing(4)
                .foregroundStyle(.primary)
                .fixedSize(horizontal: false, vertical: true)

            if alternativesExpanded {
                alternativesBlock
                    .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .padding(16)
        .background(Color.appSurface, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(Color.appBorder.opacity(0.45), lineWidth: 1)
        )
    }

    private var factorsSection: some View {
        DisclosureGroup(isExpanded: $factorsExpanded) {
            if isGeneratingInterpretation {
                generatingContextualView
                    .padding(.top, 10)
            } else if let interp = contextualInterpretation {
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        intensidadBadge(interp.intensidad)
                        Text(interp.polaridadEmoji + " " + interp.polaridad.capitalized)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Spacer()
                        Button {
                            onInvalidateInterpretation()
                        } label: {
                            Label("Regenerar", systemImage: "arrow.clockwise")
                                .font(.caption)
                        }
                        .buttonStyle(.borderless)
                    }

                    LazyVGrid(columns: [
                        GridItem(.flexible(), alignment: .topLeading),
                        GridItem(.flexible(), alignment: .topLeading),
                    ], alignment: .leading, spacing: 12) {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Factores")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(.secondary)
                            ForEach(interp.factoresConsiderados, id: \.factor) { factor in
                                factorRow(factor)
                            }
                        }

                        VStack(alignment: .leading, spacing: 8) {
                            Text("Áreas")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(.secondary)
                            ForEach(interp.areasAfectadas, id: \.area) { area in
                                areaRow(area)
                            }
                        }
                    }

                    Text("Prompt v\(interp.promptVersion)")
                        .font(.caption.monospaced())
                        .foregroundStyle(.tertiary)
                }
                .padding(.top, 10)
            }
        } label: {
            sectionLabel("Factores Morinistas", icon: "sparkles")
        }
        .appCard()
    }

    private var contextualDiscovery: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionLabel("Interpretación contextual", icon: "sparkles")
            Text("La lectura generativa evalúa factores morinistas de la carta natal sin sustituir al corpus curado.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            generateButton
        }
        .appCard()
    }

    private var speculumSection: some View {
        DisclosureGroup(isExpanded: $speculumExpanded) {
            SpeculumTableView(
                rows: speculumRows,
                promissorKey: direction.promissor,
                significatorKey: direction.significator
            )
            .padding(.top, 10)
        } label: {
            sectionLabel("Espéculo Regiomontano", icon: "tablecells")
        }
        .appCard()
    }

    private var calculationSection: some View {
        DisclosureGroup(isExpanded: $calculationExpanded) {
            VStack(alignment: .leading, spacing: 12) {
                technicalTable
                Divider()
                activationOrbView
            }
            .padding(.top, 10)
        } label: {
            sectionLabel("Datos del cálculo", icon: "function")
        }
        .appCard()
    }

    private var technicalTable: some View {
        let td = direction.technicalData
        return VStack(spacing: 0) {
            technicalRow("Arco", enriched.arcFormatted)
            technicalRow("Clave", direction.key.rawValue)
            technicalRow("AR prómissor", degrees(td.promissorRA, precision: 4))
            technicalRow("Decl prómissor", signedDegrees(td.promissorDeclination, precision: 4))
            technicalRow("AR significador", degrees(td.significatorRA, precision: 4))
            technicalRow("Decl significador", signedDegrees(td.significatorDeclination, precision: 4))
            technicalRow("Polo significador", degrees(td.significatorPole, precision: 4))
            technicalRow("Aspecto", "\(direction.aspect.label) (\(Int(direction.aspectAngle))°)")
            technicalRow("Tipo", direction.directionType == .direct ? "Directa" : "Conversa")
            technicalRow("Plano", direction.aspectPlane.displayName)
            technicalRow("Orbe de activación", "peak ±\(direction.key.peakOrbMonths)m · residual ±\(direction.key.residualOrbMonths)m")
        }
        .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 6, style: .continuous)
                .stroke(Color.appBorder.opacity(0.45), lineWidth: 1)
        )
    }

    private func technicalRow(_ key: String, _ value: String) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 12) {
            Text(key)
                .font(.caption)
                .foregroundStyle(.secondary)
                .frame(width: 150, alignment: .leading)
            Text(value)
                .font(.caption.monospaced())
                .foregroundStyle(.primary)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 7)
        .background(Color.appPanel.opacity(0.5))
    }

    private var activationOrbView: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Orbe de activación")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)

            GeometryReader { geo in
                ZStack(alignment: .center) {
                    Capsule()
                        .fill(Color.appAccentFill.opacity(0.12))
                        .frame(width: geo.size.width, height: 8)
                    Capsule()
                        .fill(
                            LinearGradient(
                                colors: [Color.appAccentFill.opacity(0.35), Color.appSecondaryAccent.opacity(0.75), Color.appAccentFill.opacity(0.35)],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(width: max(44, geo.size.width / 3), height: 12)
                }
            }
            .frame(height: 14)

            HStack {
                Text("Residual: \(orbRange(months: direction.key.residualOrbMonths))")
                Spacer()
                Text("Peak: \(orbRange(months: direction.key.peakOrbMonths))")
            }
            .font(.caption.monospaced())
            .foregroundStyle(.secondary)
        }
    }

    private var alternativesBlock: some View {
        VStack(alignment: .leading, spacing: 10) {
            ForEach(alternativeSources) { source in
                VStack(alignment: .leading, spacing: 5) {
                    Text("Fuente: \(source.label)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text(source.title)
                        .font(.caption.weight(.semibold))
                    Text(source.text)
                        .font(.body)
                        .lineSpacing(4)
                        .foregroundStyle(.primary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(10)
                .background(Color.appPanel, in: RoundedRectangle(cornerRadius: 6, style: .continuous))
            }

            if contextualInterpretation == nil && !isGeneratingInterpretation {
                generateButton
                    .padding(.top, 2)
            }
        }
    }

    private var primaryTextSource: MainTextSource {
        if let curatedSource {
            return curatedSource
        }
        if let contextualSource {
            return contextualSource
        }
        return localSource
    }

    private var alternativeSources: [MainTextSource] {
        let primaryID = primaryTextSource.id
        return [curatedSource, contextualSource, localSource]
            .compactMap(\.self)
            .filter { $0.id != primaryID }
    }

    private var hasAlternatives: Bool {
        !alternativeSources.isEmpty || contextualInterpretation == nil
    }

    private var curatedSource: MainTextSource? {
        guard let interp = enriched.interpretation, !interp.textoCortoPD.isEmpty else { return nil }
        let label = interp.fuenteNombre?.isEmpty == false ? interp.fuenteNombre! : "Corpus curado"
        return MainTextSource(id: "corpus", label: label, title: interp.title, text: interp.textoCortoPD)
    }

    private var contextualSource: MainTextSource? {
        guard let interp = contextualInterpretation else { return nil }
        return MainTextSource(
            id: "contextual",
            label: "Generado por LLM",
            title: interp.tituloPrincipal,
            text: interp.textoEstructural
        )
    }

    private var localSource: MainTextSource {
        MainTextSource(
            id: "local",
            label: "Lectura auxiliar",
            title: "Síntesis auxiliar",
            text: localReading.summary
        )
    }

    private var generatingContextualView: some View {
        HStack(spacing: 12) {
            ProgressView().controlSize(.regular)
            VStack(alignment: .leading, spacing: 4) {
                Text("Generando interpretación morinista...")
                    .font(.body)
                Text("Evaluando factores natales, secta, dignidades y áreas afectadas.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var generateButton: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label(contextualAvailability, systemImage: "key")
                .font(.caption)
                .foregroundStyle(.secondary)
            Button {
                onRequestInterpretation()
            } label: {
                Label("Generar interpretación contextual", systemImage: "sparkles")
                    .font(.body.weight(.semibold))
            }
            .buttonStyle(.borderedProminent)
            .tint(Color.appAccentFill)
            .disabled(isGeneratingInterpretation)
        }
    }

    private func factorRow(_ factor: ContextualInterpretation.FactorModulador) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Text(modulationEmoji(factor.modulacion))
                .font(.body)
                .help(modulationHelp(factor.modulacion))
            VStack(alignment: .leading, spacing: 2) {
                Text(factor.factor.replacingOccurrences(of: "_", with: " ").capitalized)
                    .font(.caption.weight(.semibold))
                Text(factor.valor)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private func areaRow(_ area: ContextualInterpretation.AreaVida) -> some View {
        HStack(spacing: 8) {
            Text(String(repeating: "●", count: area.peso))
                .font(.caption.monospaced())
                .foregroundStyle(Color.appAccentFill)
                .help("Peso \(area.peso) sobre 3")
            Text(area.area.capitalized)
                .font(.caption)
        }
    }

    private func sectionLabel(_ title: String, icon: String) -> some View {
        Label(title, systemImage: icon)
            .font(.headline)
            .foregroundStyle(.primary)
    }

    private func metadataBadge(_ title: String, icon: String) -> some View {
        Label(title, systemImage: icon)
            .font(.caption)
            .foregroundStyle(.secondary)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(Color.appPanel, in: Capsule())
    }

    private func polarityBadge(_ polarity: String) -> some View {
        let (color, symbol): (Color, String) = switch polarity {
        case "benefico": (Color(hex: "#16A34A"), "●")
        case "malefico": (Color(hex: "#DC2626"), "●")
        case "mixto": (Color(hex: "#D97706"), "●")
        default: (Color(hex: "#64748B"), "●")
        }
        return HStack(spacing: 6) {
            Text(symbol)
                .font(.headline)
            Text(polarity.capitalized)
                .font(.headline)
        }
        .foregroundStyle(color)
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(color.opacity(0.12), in: Capsule())
    }

    @ViewBuilder
    private func weightBadge(_ weight: PDWeight) -> some View {
        switch weight {
        case .critical:
            HStack(spacing: 6) {
                Text(weight.glyph)
                    .font(.headline)
                Text("Dirección crítica")
                    .font(.caption.weight(.semibold))
            }
            .foregroundStyle(Color.appWarning)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(Color.appWarning.opacity(0.14), in: Capsule())
        case .major:
            HStack(spacing: 6) {
                Text(weight.glyph)
                    .font(.headline)
                Text("Mayor")
                    .font(.caption.weight(.semibold))
            }
            .foregroundStyle(Color.appAccentFill)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(Color.appAccentFill.opacity(0.1), in: Capsule())
        case .moderate, .minor:
            EmptyView()
        }
    }

    private func intensidadBadge(_ score: Int) -> some View {
        HStack(spacing: 2) {
            ForEach(1...10, id: \.self) { i in
                RoundedRectangle(cornerRadius: 2)
                    .fill(i <= score ? Color.appAccentFill : Color.appBorder)
                    .frame(width: 6, height: 10)
            }
        }
        .help("Intensidad \(score) sobre 10")
    }

    private func modulationEmoji(_ modulation: String) -> String {
        switch modulation {
        case "amplifica": return "↑"
        case "atenua": return "↓"
        case "invierte": return "↔"
        default: return "→"
        }
    }

    private func modulationHelp(_ modulation: String) -> String {
        switch modulation {
        case "amplifica": return "Este factor aumenta la expresión de la dirección."
        case "atenua": return "Este factor suaviza o retrasa la expresión de la dirección."
        case "invierte": return "Este factor cambia la forma esperada de manifestación."
        default: return "Este factor contextualiza sin alterar fuertemente la dirección."
        }
    }

    private var exactAgeCompact: String {
        let years = Int(direction.estimatedAge)
        let months = Int((direction.estimatedAge - Double(years)) * 12)
        return "\(years)a \(months)m"
    }

    private func orbRange(months: Int) -> String {
        let calendar = Calendar.current
        let base = direction.estimatedDate
        let start = calendar.date(byAdding: .month, value: -months, to: base) ?? base
        let end = calendar.date(byAdding: .month, value: months, to: base) ?? base
        return "\(formattedDate(start)) - \(formattedDate(end))"
    }

    private func formattedDate(_ date: Date) -> String {
        let fmt = DateFormatter()
        fmt.dateFormat = "MMM yyyy"
        fmt.locale = Locale(identifier: "es_ES")
        return fmt.string(from: date)
    }

    private func degrees(_ value: Double, precision: Int = 2) -> String {
        "\(String(format: "%.\(precision)f", value))°"
    }

    private func signedDegrees(_ value: Double, precision: Int = 2) -> String {
        "\(value >= 0 ? "+" : "")\(String(format: "%.\(precision)f", value))°"
    }
}

private struct MainTextSource: Identifiable {
    let id: String
    let label: String
    let title: String
    let text: String
}

// MARK: - PrimaryDirectionInterpretation display helper

extension PrimaryDirectionInterpretation {
    var textoCortoPD: String { structuralText }
    var fuenteNombre: String? { source.isEmpty ? nil : source }
}

// MARK: - ContextualInterpretation display helper

extension ContextualInterpretation.PeriodoActivacion {
    var displayString: String {
        let ageYears = Int(edadExacta)
        let ageMonths = Int((edadExacta - Double(ageYears)) * 12)
        var parts = ["\(ageYears) años"]
        if ageMonths > 0 { parts.append("\(ageMonths) meses") }
        if let inicio = fechaInicio, let fin = fechaFin {
            parts.append("(\(inicio) - \(fin))")
        }
        return parts.joined(separator: " · ")
    }
}
