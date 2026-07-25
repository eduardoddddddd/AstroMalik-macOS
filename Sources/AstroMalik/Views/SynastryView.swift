import SwiftUI
import Darwin

struct SynastryView: View {
    @EnvironmentObject var appState: AppState

    @State private var chartAID: UUID?
    @State private var chartBID: UUID?
    @State private var reading: SynastryReading?
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
                chartPicker(fallbackTitle: "Primera carta", selection: $chartAID)
                Button {
                    swap(&chartAID, &chartBID)
                    reading = nil
                } label: {
                    Image(systemName: "arrow.left.arrow.right")
                        .frame(width: 28, height: 28)
                }
                .buttonStyle(.bordered)
                .help("Intercambiar cartas")
                chartPicker(fallbackTitle: "Segunda carta", selection: $chartBID)
                Spacer()
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

    private func chartPicker(fallbackTitle: String, selection: Binding<UUID?>) -> some View {
        let selectedName = selection.wrappedValue
            .flatMap { id in charts.first(where: { $0.id == id }) }
            .map { SynastryNaming.displayName(for: $0) }
        return VStack(alignment: .leading, spacing: 5) {
            Text(selectedName ?? fallbackTitle)
                .font(.caption.weight(.semibold))
                .foregroundColor(.secondary)
            Picker(fallbackTitle, selection: selection) {
                ForEach(charts) { chart in
                    Text(SynastryNaming.displayName(for: chart))
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
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 22) {
                    overview(reading)
                    highlightedSection(reading)
                    houseOverlaySection(reading)
                    remainingSections(reading)
                }
                .padding(18)
            }
        }
    }

    private func summaryBar(_ reading: SynastryReading) -> some View {
        HStack(spacing: 14) {
            Label(reading.coverageSummary, systemImage: "text.book.closed")
                .font(.subheadline.weight(.medium))
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
                chartName: "\(nameA(reading)) + \(nameB(reading))",
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

    private func overview(_ reading: SynastryReading) -> some View {
        ViewThatFits(in: .horizontal) {
            HStack(alignment: .top, spacing: 18) {
                synthesisCard(reading)
                    .frame(maxWidth: .infinity, alignment: .top)
                wheel(reading)
                    .frame(width: 360, height: 300)
            }
            VStack(spacing: 18) {
                synthesisCard(reading)
                wheel(reading)
                    .frame(height: 320)
            }
        }
    }

    private func synthesisCard(_ reading: SynastryReading) -> some View {
        SynastrySynthesisCard(
            contacts: visibleContacts(reading),
            chartAName: nameA(reading),
            chartBName: nameB(reading)
        )
    }

    private func wheel(_ reading: SynastryReading) -> some View {
        SynastryWheelView(
            reading: reading,
            aspects: visibleContacts(reading).compactMap(\.representativeAspect),
            chartAName: nameA(reading),
            chartBName: nameB(reading)
        )
    }

    private func highlightedSection(_ reading: SynastryReading) -> some View {
        let contacts = highlightedContacts(reading)
        return VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline) {
                Text("Contactos destacados")
                    .appSectionHeader()
                Spacer()
                Text("\(contacts.count)")
                    .font(.caption.monospacedDigit().weight(.semibold))
                    .foregroundColor(.secondary)
            }
            Text("Luminarias y funciones personales con orbe de hasta 3°.")
                .font(.caption)
                .foregroundColor(.secondary)
            if contacts.isEmpty {
                Text("No hay contactos personales dentro de este umbral; el tema central sigue señalado en la síntesis.")
                    .font(.callout)
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .appCard()
            } else {
                ForEach(contacts) { contact in
                    SynastryContactCard(
                        contact: contact,
                        chartAName: nameA(reading),
                        chartBName: nameB(reading),
                        prominent: true
                    )
                }
            }
        }
    }

    /// Superposición por casas: en qué área de la vida del otro aterriza cada
    /// planeta. Tras los aspectos es la técnica más usada en sinastría, y solo
    /// estaba disponible en el PDF.
    private func houseOverlaySection(_ reading: SynastryReading) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Casas mutuas")
                .appSectionHeader()
            Text("Dónde aterriza cada persona en la vida de la otra. La casa indica el área de experiencia que se activa en la convivencia.")
                .font(.caption)
                .foregroundColor(.secondary)
            ViewThatFits(in: .horizontal) {
                HStack(alignment: .top, spacing: 14) {
                    houseOverlayColumn(source: reading.chartA, target: reading.chartB)
                    houseOverlayColumn(source: reading.chartB, target: reading.chartA)
                }
                VStack(spacing: 14) {
                    houseOverlayColumn(source: reading.chartA, target: reading.chartB)
                    houseOverlayColumn(source: reading.chartB, target: reading.chartA)
                }
            }
        }
    }

    private func houseOverlayColumn(source: NatalChart, target: NatalChart) -> some View {
        let sourceName = SynastryNaming.displayName(for: source)
        let targetName = SynastryNaming.displayName(for: target)
        return VStack(alignment: .leading, spacing: 8) {
            Text("\(sourceName) en las casas de \(targetName)")
                .font(.subheadline.weight(.semibold))
                .foregroundColor(.appPrimaryText)
            ForEach(source.bodies) { body in
                HStack(spacing: 10) {
                    Text(body.label)
                        .font(.callout)
                        .foregroundColor(.appPrimaryText.opacity(0.9))
                    Spacer()
                    Text("Casa \(AstroEngine.planetHouse(deg: body.longitude, cusps: target.cusps))")
                        .font(.caption.monospacedDigit().weight(.medium))
                        .foregroundColor(.secondary)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(Color.appPanel)
        .clipShape(RoundedRectangle(cornerRadius: 9, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 9, style: .continuous)
                .stroke(Color.appBorder.opacity(0.8), lineWidth: 1)
        )
    }

    @ViewBuilder
    private func remainingSections(_ reading: SynastryReading) -> some View {
        let highlightedIDs = Set(highlightedContacts(reading).map(\.id))
        let remaining = visibleContacts(reading).filter { !highlightedIDs.contains($0.id) }
        let personal = remaining.filter { $0.interpretivePriority <= 1 }
        let personalSlow = remaining.filter { $0.interpretivePriority == 2 }
        let generational = remaining.filter(\.isPrimarilyGenerational)

        VStack(alignment: .leading, spacing: 12) {
            Text("Resto de contactos")
                .appSectionHeader()
            Text("Todas las interpretaciones están visibles; los grupos solo conservan el orden editorial.")
                .font(.caption)
                .foregroundColor(.secondary)
            SynastryContactSection(
                title: "Otros contactos personales y sociales",
                contacts: personal,
                chartAName: nameA(reading),
                chartBName: nameB(reading)
            )
            SynastryContactSection(
                title: "Contactos personal–lento",
                contacts: personalSlow,
                chartAName: nameA(reading),
                chartBName: nameB(reading)
            )
            SynastryContactSection(
                title: "Contactos generacionales",
                contacts: generational,
                chartAName: nameA(reading),
                chartBName: nameB(reading),
                subtitle: "\(generational.count) contactos generacionales"
            )
        }
    }

    /// Los contactos sin texto de corpus se muestran igualmente: la geometría es
    /// válida aunque falte la interpretación, y ocultarlos dejaría la pantalla
    /// vacía si el corpus no estuviera disponible.
    private func visibleContacts(_ reading: SynastryReading) -> [SynastryContact] {
        reading.contacts.sorted(by: SynastryContact.editorialOrder)
    }

    private func highlightedContacts(_ reading: SynastryReading) -> [SynastryContact] {
        visibleContacts(reading).filter {
            let keys = [$0.chartAPlanetKey, $0.chartBPlanetKey]
            return $0.orb <= 3
                && (keys.contains(where: SynastryPointClass.personal.contains)
                    || keys.contains(where: SynastryPointClass.isAngle))
        }
    }

    private func nameA(_ reading: SynastryReading) -> String {
        SynastryNaming.displayName(for: reading.chartA)
    }

    private func nameB(_ reading: SynastryReading) -> String {
        SynastryNaming.displayName(for: reading.chartB)
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
                    title: "Sinastría - \(nameA(reading)) y \(nameB(reading))",
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

private struct SynastrySynthesisCard: View {
    let contacts: [SynastryContact]
    let chartAName: String
    let chartBName: String

    private var synthesis: SynastrySynthesis {
        SynastrySynthesis.build(from: contacts.filter(\.hasText))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 15) {
            HStack {
                Label("Síntesis de \(chartAName) y \(chartBName)", systemImage: "sparkles")
                    .font(.headline)
                    .foregroundColor(.appPrimaryText)
                Spacer()
                Text("\(contacts.count) contactos únicos")
                    .font(.caption.monospacedDigit())
                    .foregroundColor(.secondary)
            }

            Text(synthesis.balanceText)
                .font(.callout)
                .foregroundColor(.appPrimaryText.opacity(0.9))
                .lineSpacing(3)

            HStack(spacing: 9) {
                scoreBadge(
                    "Armonía \(score(synthesis.harmonyScore))",
                    color: Color(hex: "#15803d")
                )
                scoreBadge(
                    "Fricción \(score(synthesis.frictionScore))",
                    color: Color(hex: "#dc2626")
                )
                if synthesis.conjunctionScore > 0 {
                    scoreBadge(
                        "Integración \(score(synthesis.conjunctionScore))",
                        color: Color(hex: "#d97706")
                    )
                }
            }

            Divider()

            VStack(alignment: .leading, spacing: 6) {
                Text("Tema central")
                    .font(.caption.weight(.semibold))
                    .foregroundColor(.secondary)
                if let central = synthesis.centralContact {
                    Text(contactTitle(central))
                        .font(.subheadline.weight(.semibold))
                    Text("Es el contacto personal más exacto, con orbe \(String(format: "%.2f°", central.orb)). Funciona como punto de entrada, no como conclusión total.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                } else {
                    Text("No hay un contacto personal disponible para destacar.")
                        .font(.callout)
                        .foregroundColor(.secondary)
                }
            }

            if !synthesis.doubleWhammies.isEmpty {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Reciprocidades")
                        .font(.caption.weight(.semibold))
                        .foregroundColor(.secondary)
                    Text(doubleWhammyText)
                        .font(.callout)
                        .foregroundColor(.appPrimaryText.opacity(0.88))
                }
            }
        }
        .padding(18)
        .background(
            LinearGradient(
                colors: [Color.appPanel, Color.appAccentFill.opacity(0.07)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(Color.appAccentFill.opacity(0.32), lineWidth: 1)
        )
    }

    private var doubleWhammyText: String {
        let labels = synthesis.doubleWhammies.prefix(4).map(\.label)
        let suffix = synthesis.doubleWhammies.count > 4 ? " y otras" : ""
        return "Se repiten en ambos sentidos \(labels.joined(separator: ", "))\(suffix). Estas correspondencias refuerzan el tema compartido sin determinar cómo se vivirá."
    }

    private func contactTitle(_ contact: SynastryContact) -> String {
        "\(contact.chartAPlanetLabel) de \(chartAName) \(contact.aspectLabel) \(contact.chartBPlanetLabel) de \(chartBName)"
    }

    private func score(_ value: Double) -> String {
        String(format: "%.1f", value)
    }

    private func scoreBadge(_ text: String, color: Color) -> some View {
        Text(text)
            .font(.caption.monospacedDigit().weight(.semibold))
            .foregroundColor(color)
            .padding(.horizontal, 9)
            .padding(.vertical, 5)
            .background(color.opacity(0.1))
            .clipShape(Capsule())
    }
}

private struct SynastryContactSection: View {
    let title: String
    let contacts: [SynastryContact]
    let chartAName: String
    let chartBName: String
    var subtitle: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 3) {
                    Text(title)
                        .font(.subheadline.weight(.semibold))
                        .foregroundColor(.appPrimaryText)
                    Text(subtitle ?? "\(contacts.count) contactos")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                Spacer()
            }

            LazyVStack(spacing: 10) {
                if contacts.isEmpty {
                    Text("No hay contactos en este grupo.")
                        .font(.callout)
                        .foregroundColor(.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.vertical, 8)
                } else {
                    ForEach(contacts) { contact in
                        SynastryContactCard(
                            contact: contact,
                            chartAName: chartAName,
                            chartBName: chartBName
                        )
                    }
                }
            }
        }
        .padding(14)
        .background(Color.appPanel)
        .clipShape(RoundedRectangle(cornerRadius: 9, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 9, style: .continuous)
                .stroke(Color.appBorder.opacity(0.8), lineWidth: 1)
        )
    }
}

private struct SynastryContactCard: View {
    let contact: SynastryContact
    let chartAName: String
    let chartBName: String
    var prominent = false

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundColor(.appPrimaryText)
                    .multilineTextAlignment(.leading)
                HStack(spacing: 8) {
                    Text("Orbe \(String(format: "%.2f°", contact.orb))")
                    if contact.isPrimarilyGenerational {
                        Text("Generacional")
                            .foregroundColor(.secondary.opacity(0.8))
                    }
                }
                .font(.caption.monospacedDigit())
                .foregroundColor(.secondary)
            }

            ForEach(Array(availableDirections.enumerated()), id: \.element) { index, direction in
                if index > 0 {
                    Divider()
                }
                SynastryLensText(
                    direction: direction,
                    aspect: contact.aspect(for: direction),
                    chartAName: chartAName,
                    chartBName: chartBName,
                    showsDirectionalHeader: availableDirections.count > 1
                )
            }
        }
        .padding(16)
        .background(Color.appPanel)
        .clipShape(RoundedRectangle(cornerRadius: prominent ? 10 : 8, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: prominent ? 10 : 8, style: .continuous)
                .stroke(
                    prominent
                        ? Color.appAccentFill.opacity(0.5)
                        : Color.appBorder.opacity(0.75),
                    lineWidth: prominent ? 1.2 : 1
                )
        )
    }

    private var title: String {
        "\(contact.chartAPlanetLabel) de \(chartAName) \(contact.aspectLabel) \(contact.chartBPlanetLabel) de \(chartBName)"
    }

    private var availableDirections: [SynastryDirection] {
        contact.distinctDirections
    }
}

private struct SynastryLensText: View {
    let direction: SynastryDirection
    let aspect: SynastryAspect?
    let chartAName: String
    let chartBName: String
    var showsDirectionalHeader = true

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if showsDirectionalHeader {
                Text(lensLabel)
                    .font(.caption.weight(.semibold))
                    .foregroundColor(.appAccentFill)
            }

            if let copy {
                Text(copy.text)
                    .font(.callout)
                    .foregroundColor(.appPrimaryText.opacity(0.9))
                    .lineSpacing(4)
                    .textSelection(.enabled)
                if !copy.source.isEmpty {
                    Text(copy.source)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            } else {
                Text("Sin interpretación disponible en el corpus para esta dirección.")
                    .font(.callout)
                    .foregroundColor(.secondary)
            }
        }
    }

    private var lensLabel: String {
        let source = direction.sourceName(chartAName: chartAName, chartBName: chartBName)
        let target = direction.targetName(chartAName: chartAName, chartBName: chartBName)
        return "Cómo lo vive \(source) → \(target)"
    }

    private var copy: SynastryLensCopy? {
        guard let aspect else { return nil }
        return SynastryLensCopy.make(
            for: aspect,
            chartAName: chartAName,
            chartBName: chartBName
        )
    }
}

private struct SynastryWheelView: View {
    let reading: SynastryReading
    let aspects: [SynastryAspect]
    let chartAName: String
    let chartBName: String

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
                        marker: initials(chartAName),
                        color: .appAccentFill,
                        position: point(for: body.longitude, center: center, radius: outerRadius + 2)
                    )
                }

                ForEach(reading.chartB.bodies) { body in
                    wheelLabel(
                        text: body.symbol,
                        marker: initials(chartBName),
                        color: .appSecondaryAccent,
                        position: point(for: body.longitude, center: center, radius: innerRadius)
                    )
                }

                VStack(spacing: 4) {
                    Text(chartAName)
                        .foregroundColor(.appAccentFill)
                    Text(chartBName)
                        .foregroundColor(.appSecondaryAccent)
                }
                .font(.caption.weight(.bold))
                .lineLimit(1)
                .frame(maxWidth: 120)
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
                .font(.system(size: 6, weight: .bold))
                .foregroundColor(.appAccentForeground)
                .frame(minWidth: 13, minHeight: 11)
                .padding(.horizontal, 2)
                .background(color)
                .clipShape(Capsule())
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
        // Incluye ASC y MC: sin ellos las líneas de los contactos angulares
        // no llegarían a dibujarse.
        let chartAMap = AstroEngine.synastryPoints(reading.chartA)
        let chartBMap = AstroEngine.synastryPoints(reading.chartB)

        for aspect in aspects {
            let chartAKey = aspect.direction == .aToB
                ? aspect.sourcePlanetKey
                : aspect.targetPlanetKey
            let chartBKey = aspect.direction == .aToB
                ? aspect.targetPlanetKey
                : aspect.sourcePlanetKey
            guard let chartABody = chartAMap[chartAKey],
                  let chartBBody = chartBMap[chartBKey]
            else {
                continue
            }
            var path = Path()
            path.move(to: point(for: chartABody.longitude, center: center, radius: outerRadius))
            path.addLine(to: point(for: chartBBody.longitude, center: center, radius: innerRadius))
            context.stroke(
                path,
                with: .color(color(for: aspect.aspectKey).opacity(aspect.hasText ? 0.58 : 0.22)),
                lineWidth: aspect.hasText ? 1.15 : 0.8
            )
        }
    }

    private func initials(_ name: String) -> String {
        let parts = name.split(separator: " ")
        let letters = parts.prefix(2).compactMap(\.first)
        return letters.isEmpty ? "•" : String(letters)
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
        let chartAName = SynastryNaming.displayName(for: reading.chartA)
        let chartBName = SynastryNaming.displayName(for: reading.chartB)
        let contacts = reading.contactsWithText
        let synthesis = SynastrySynthesis.build(from: contacts)
        var lines: [String] = [
            "# Sinastría - \(chartAName) y \(chartBName)",
            "",
            "## Cartas",
            "- \(chartAName): \(reading.chartA.birthDate) \(reading.chartA.birthTime) · \(reading.chartA.placeName)",
            "- \(chartBName): \(reading.chartB.birthDate) \(reading.chartB.birthTime) · \(reading.chartB.placeName)",
            "- Cobertura: \(reading.coverageSummary)",
            "- Lentes direccionales sin texto: \(reading.missingTextCount)",
            "",
            "## Síntesis",
            "",
            synthesis.balanceText,
            "",
        ]

        if let central = synthesis.centralContact {
            lines += [
                "### Tema central",
                "\(contactTitle(central, chartAName: chartAName, chartBName: chartBName)) (orbe \(String(format: "%.2f°", central.orb))).",
                "",
            ]
        }
        if !synthesis.doubleWhammies.isEmpty {
            lines += [
                "### Reciprocidades",
                synthesis.doubleWhammies.map(\.label).joined(separator: ", "),
                "",
            ]
        }

        lines += ["## Contactos", ""]
        for contact in contacts {
            lines += [
                "### \(contactTitle(contact, chartAName: chartAName, chartBName: chartBName))",
                "- Orbe: \(String(format: "%.2f°", contact.orb))",
                "",
            ]
            let directions = contact.distinctDirections
            for direction in directions {
                guard let aspect = contact.aspect(for: direction),
                      let copy = SynastryLensCopy.make(
                          for: aspect,
                          chartAName: chartAName,
                          chartBName: chartBName
                      ) else { continue }
                let source = direction.sourceName(
                    chartAName: chartAName,
                    chartBName: chartBName
                )
                let target = direction.targetName(
                    chartAName: chartAName,
                    chartBName: chartBName
                )
                // El encabezado direccional solo aporta cuando hay dos lecturas
                // en espejo; con una sola describiría de más.
                lines += [
                    directions.count > 1
                        ? "#### Cómo lo vive \(source) → \(target)"
                        : "#### Lectura",
                    "- Clave: `\(aspect.corpusClave)`",
                    "",
                    copy.text,
                    "",
                ]
            }
        }

        return lines.joined(separator: "\n")
    }

    private static func contactTitle(
        _ contact: SynastryContact,
        chartAName: String,
        chartBName: String
    ) -> String {
        "\(contact.chartAPlanetLabel) de \(chartAName) \(contact.aspectLabel) \(contact.chartBPlanetLabel) de \(chartBName)"
    }
}

private extension PlanetBody {
    var symbol: String {
        label.split(separator: " ").first.map(String.init) ?? label
    }
}
