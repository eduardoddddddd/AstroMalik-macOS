import SwiftUI

// MARK: - PrimaryDirectionDetailView
// Panel de detalle con 3 DisclosureGroups colapsables.

struct PrimaryDirectionDetailView: View {
    let enriched: EnrichedPrimaryDirection
    let contextualInterpretation: ContextualInterpretation?
    let isGeneratingInterpretation: Bool
    let contextualAvailability: String
    let onRequestInterpretation: () -> Void
    let onInvalidateInterpretation: () -> Void

    @State private var technicalExpanded = true
    @State private var corpusExpanded = true
    @State private var contextualExpanded = true

    private var direction: PrimaryDirection { enriched.direction }

    var body: some View {
        ScrollView(.vertical) {
            VStack(alignment: .leading, spacing: 0) {
                // Header
                headerView
                    .padding(16)
                    .background(Color.appSurface)
                    .overlay(alignment: .bottom) { Divider() }

                VStack(alignment: .leading, spacing: 12) {
                    // Sección 1: Cálculo Técnico
                    technicalSection

                    // Sección 2: Capa 1 — Corpus tradicional
                    corpusSection

                    // Sección 3: Capa 2 — Interpretación contextual LLM
                    contextualSection
                }
                .padding(16)
            }
        }
        .background(Color.appBackground)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    // MARK: - Header

    private var headerView: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .firstTextBaseline, spacing: 12) {
                Text(enriched.displaySummary)
                    .font(.title3.bold())
                    .foregroundStyle(.primary)

                polarityBadge(direction.aspect.polarity)

                Spacer()

                Text(enriched.ageFormatted)
                    .font(.headline.monospaced())
                    .foregroundStyle(Color.appAccentFill)
            }

            HStack(spacing: 16) {
                Label(direction.directionType == .direct ? "Directa" : "Conversa",
                      systemImage: direction.directionType == .direct ? "arrow.forward" : "arrow.backward")
                Label(direction.aspectPlane == .mundane ? "Mundano" : "Zodiacal",
                      systemImage: "globe")
                Label(direction.method.rawValue,
                      systemImage: "house.circle")
                if !enriched.hasInterpretation {
                    Label("Sin corpus", systemImage: "clock.badge.exclamationmark")
                        .foregroundStyle(Color.appWarning)
                }
            }
            .font(.caption)
            .foregroundStyle(.secondary)
        }
    }

    // MARK: - Sección 1: Técnica

    private var technicalSection: some View {
        DisclosureGroup(isExpanded: $technicalExpanded) {
            VStack(alignment: .leading, spacing: 10) {
                technicalGrid
                Divider()
                estimatedDateRow
            }
            .padding(.top, 10)
        } label: {
            sectionLabel("Cálculo Técnico", icon: "function")
        }
        .appCard()
    }

    private var technicalGrid: some View {
        let td = direction.technicalData
        return LazyVGrid(columns: [
            GridItem(.flexible(), alignment: .leading),
            GridItem(.flexible(), alignment: .leading),
        ], spacing: 8) {
            technicalRow("Arco", enriched.arcFormatted)
            technicalRow("Clave", direction.key.rawValue)
            technicalRow("AR Prómissor", "\(String(format: "%.4f", td.promissorRA))°")
            technicalRow("AR Significador", "\(String(format: "%.4f", td.significatorRA))°")
            technicalRow("Dec. Prómissor", "\(String(format: "%.4f", td.promissorDeclination))°")
            technicalRow("Polo Regiomontanus", "\(String(format: "%.4f", td.significatorPole))°")
            technicalRow("Oblicuidad", "\(String(format: "%.4f", td.obliquity))°")
            technicalRow("RAMC", "\(String(format: "%.4f", td.ramc))°")
            technicalRow("Latitud", "\(String(format: "%.4f", td.geoLatitude))°")
            technicalRow("Aspecto", "\(direction.aspect.label) (\(Int(direction.aspectAngle))°)")
        }
    }

    private func technicalRow(_ label: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label)
                .font(.caption2)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.caption.monospaced())
                .foregroundStyle(.primary)
        }
    }

    private var estimatedDateRow: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Período de activación")
                .font(.caption2)
                .foregroundStyle(.secondary)

            let calendar = Calendar.current
            let baseDate = direction.estimatedDate
            let orbeMonths = 6
            let start = calendar.date(byAdding: .month, value: -orbeMonths, to: baseDate) ?? baseDate
            let end   = calendar.date(byAdding: .month, value:  orbeMonths, to: baseDate) ?? baseDate

            HStack(spacing: 8) {
                Image(systemName: "calendar")
                    .foregroundStyle(Color.appAccentFill)
                    .font(.caption)
                Text("\(formattedDate(start)) – \(formattedDate(end))")
                    .font(.caption.monospaced())
            }
        }
    }

    // MARK: - Sección 2: Corpus

    private var corpusSection: some View {
        DisclosureGroup(isExpanded: $corpusExpanded) {
            corpusContent
                .padding(.top, 10)
        } label: {
            sectionLabel("Corpus Tradicional (Capa 1)", icon: "books.vertical")
        }
        .appCard()
    }

    @ViewBuilder
    private var corpusContent: some View {
        if let interp = enriched.interpretation, !interp.textoCortoPD.isEmpty {
            // Populated
            VStack(alignment: .leading, spacing: 8) {
                if let fuente = interp.fuenteNombre, !fuente.isEmpty {
                    HStack(spacing: 4) {
                        Image(systemName: "quote.opening")
                            .font(.caption2)
                            .foregroundStyle(Color.appSecondaryAccent)
                        Text(fuente)
                            .font(.caption.italic())
                            .foregroundStyle(Color.appSecondaryAccent)
                    }
                }
                Text(interp.textoCortoPD)
                    .font(.callout)
                    .foregroundStyle(.primary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        } else {
            HStack(alignment: .top, spacing: 10) {
                Image(systemName: "clock.badge.exclamationmark")
                    .font(.headline)
                    .foregroundStyle(Color.appWarning)
                VStack(alignment: .leading, spacing: 4) {
                    Text("Esta clave aún no tiene texto verificado")
                        .font(.callout.weight(.semibold))
                        .foregroundStyle(Color.appWarning)
                    Text("La ausencia de lectura en la Capa 1 indica cobertura doctrinal todavía incompleta, no un fallo del cálculo. Solo se muestran textos curados manualmente y con atribución verificable.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .padding(10)
            .background(Color.appWarning.opacity(0.08))
            .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
        }
    }

    // MARK: - Sección 3: Contextual (LLM)

    private var contextualSection: some View {
        DisclosureGroup(isExpanded: $contextualExpanded) {
            contextualContent
                .padding(.top, 10)
        } label: {
            HStack(spacing: 8) {
                sectionLabel("Interpretación Contextual (Capa 2)", icon: "sparkles")
                if isGeneratingInterpretation {
                    ProgressView().controlSize(.mini)
                }
            }
        }
        .appCard()
    }

    @ViewBuilder
    private var contextualContent: some View {
        if isGeneratingInterpretation {
            HStack(spacing: 12) {
                ProgressView().controlSize(.regular)
                VStack(alignment: .leading, spacing: 4) {
                    Text("Generando interpretación morinista…")
                        .font(.callout)
                    Text("Evaluando los 6 factores moduladores con el LLM")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
        } else if let interp = contextualInterpretation {
            interpretationBody(interp)
        } else {
            generateButton
        }
    }

    private func interpretationBody(_ interp: ContextualInterpretation) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            // Título y polaridad
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(interp.tituloPrincipal)
                        .font(.callout.bold())
                        .foregroundStyle(.primary)
                        .fixedSize(horizontal: false, vertical: true)

                    HStack(spacing: 10) {
                        intensidadBadge(interp.intensidad)
                        Text(interp.polaridadEmoji + " " + interp.polaridad.capitalized)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                Spacer()
                Button {
                    onInvalidateInterpretation()
                } label: {
                    Image(systemName: "arrow.clockwise")
                        .font(.caption)
                }
                .buttonStyle(.borderless)
                .help("Regenerar interpretación")
            }

            Divider()

            // Texto estructural
            Text(interp.textoEstructural)
                .font(.callout)
                .foregroundStyle(.primary)
                .fixedSize(horizontal: false, vertical: true)

            Divider()

            // Factores moduladores + Áreas en HStack
            HStack(alignment: .top, spacing: 16) {
                // Factores
                        if !interp.factoresConsiderados.isEmpty {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Factores Morinistas")
                            .font(.caption.bold())
                            .foregroundStyle(.secondary)
                        ForEach(interp.factoresConsiderados, id: \.factor) { f in
                            factorRow(f)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .topLeading)
                }

                // Áreas
                if !interp.areasAfectadas.isEmpty {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Áreas Afectadas")
                            .font(.caption.bold())
                            .foregroundStyle(.secondary)
                        ForEach(interp.areasAfectadas, id: \.area) { a in
                            areaRow(a)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .topLeading)
                }
            }

            // Período de activación
            periodRow(interp.periodoActivacion)

            // Prompt version
            Text("Prompt v\(interp.promptVersion)")
                .font(.system(size: 9, design: .monospaced))
                .foregroundStyle(.quaternary)
        }
    }

    private func factorRow(_ f: ContextualInterpretation.FactorModulador) -> some View {
        HStack(alignment: .top, spacing: 6) {
            Text(modulacionEmoji(f.modulacion))
                .font(.caption2)
            VStack(alignment: .leading, spacing: 1) {
                Text(f.factor.replacingOccurrences(of: "_", with: " ").capitalized)
                    .font(.caption2.bold())
                Text(f.valor)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private func areaRow(_ a: ContextualInterpretation.AreaVida) -> some View {
        HStack(spacing: 6) {
            Text(String(repeating: "●", count: a.peso))
                .font(.system(size: 8))
                .foregroundStyle(Color.appAccentFill)
            Text(a.area.capitalized)
                .font(.caption2)
        }
    }

    private func periodRow(_ p: ContextualInterpretation.PeriodoActivacion) -> some View {
        HStack(spacing: 8) {
            Image(systemName: "calendar")
                .font(.caption)
                .foregroundStyle(Color.appAccentFill)
            Text(p.displayString)
                .font(.caption.monospaced())
        }
    }

    private var generateButton: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label(contextualAvailability, systemImage: "key")
                .font(.caption)
                .foregroundStyle(.secondary)
            Text("La interpretación contextual aplica los 6 factores moduladores morinistas (Astrologia Gallica) usando un LLM. Requiere API key de OpenRouter.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            Button {
                onRequestInterpretation()
            } label: {
                Label("Generar interpretación contextual", systemImage: "sparkles")
                    .font(.callout.bold())
            }
            .buttonStyle(.borderedProminent)
            .tint(Color.appAccentFill)
            .controlSize(.regular)
        }
    }

    // MARK: - Shared helpers

    private func sectionLabel(_ title: String, icon: String) -> some View {
        Label(title, systemImage: icon)
            .font(.callout.bold())
            .foregroundStyle(.primary)
    }

    private func polarityBadge(_ polarity: String) -> some View {
        let (color, emoji): (Color, String) = switch polarity {
        case "benefico":  (Color(hex: "#16A34A"), "🟢")
        case "malefico":  (Color(hex: "#DC2626"), "🔴")
        case "mixto":     (Color(hex: "#D97706"), "🟡")
        default:          (Color(hex: "#6B7280"), "⚪️")
        }
        return Text("\(emoji) \(polarity.capitalized)")
            .font(.caption.bold())
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(color.opacity(0.12))
            .foregroundStyle(color)
            .clipShape(Capsule())
    }

    private func intensidadBadge(_ score: Int) -> some View {
        HStack(spacing: 2) {
            ForEach(1...10, id: \.self) { i in
                RoundedRectangle(cornerRadius: 2)
                    .fill(i <= score ? Color.appAccentFill : Color.appBorder)
                    .frame(width: 6, height: 10)
            }
        }
    }

    private func modulacionEmoji(_ mod: String) -> String {
        switch mod {
        case "amplifica": return "⬆️"
        case "atenua":    return "⬇️"
        case "invierte":  return "↔️"
        default:          return "➡️"
        }
    }

    private func formattedDate(_ date: Date) -> String {
        let fmt = DateFormatter()
        fmt.dateFormat = "MMM yyyy"
        fmt.locale = Locale(identifier: "es_ES")
        return fmt.string(from: date)
    }
}

// MARK: - PrimaryDirectionInterpretation display helper

/// Typed access to corpus interpretation for PD.
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
            parts.append("(\(inicio) – \(fin))")
        }
        return parts.joined(separator: " · ")
    }
}
