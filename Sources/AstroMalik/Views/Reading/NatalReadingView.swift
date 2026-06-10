import SwiftUI

struct NatalReadingView: View {
    let chart: NatalChart
    let interpretaciones: [Interpretation]
    @Binding var selectedFocusKey: String?
    @ObservedObject var notesStore: ReadingNotesStore

    @State private var density: ReadingDensity = .complete
    @State private var extended: NatalExtendedAnalysisResult?
    @State private var extendedError: String?
    @State private var isLoadingExtended = false
    @State private var selectedChapter: ReadingChapterKind? = .portrait
    @State private var synthesis = ""
    @State private var loadedChartId: String?
    @State private var saveTask: Task<Void, Never>?
    @State private var searchText = ""

    private var reading: NatalReading {
        NatalReadingComposer.compose(.init(
            chart: chart,
            interpretations: interpretaciones,
            extended: extended,
            density: density
        ))
    }

    private var visibleReading: NatalReading {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { return reading }
        let chapters = reading.chapters.compactMap { chapter -> ReadingChapter? in
            let blocks = chapter.blocks.filter { blockMatches($0, query: query) }
            guard !blocks.isEmpty else { return nil }
            return ReadingChapter(id: chapter.id, title: chapter.title, subtitle: chapter.subtitle, blocks: blocks)
        }
        return NatalReading(chartId: reading.chartId, chapters: chapters, synthesisDraft: reading.synthesisDraft, missingKeys: reading.missingKeys)
    }

    var body: some View {
        ScrollViewReader { proxy in
            VStack(spacing: 0) {
                topBar(proxy: proxy)
                Divider()
                ScrollView {
                    VStack(alignment: .leading, spacing: 0) {
                        articleHero

                        if visibleReading.chapters.isEmpty {
                            emptySearch
                        } else {
                            ForEach(visibleReading.chapters) { chapter in
                                ReadingChapterView(chapter: chapter, searchQuery: searchText) { key in
                                    selectedFocusKey = key
                                }
                                .id(chapter.id)
                            }
                        }

                        synthesisEditor
                            .id(ReadingChapterKind.synthesis)
                    }
                    .frame(maxWidth: 980, alignment: .leading)
                    .frame(maxWidth: .infinity)
                    .padding(.horizontal, 34)
                    .padding(.bottom, 56)
                }
            }
        }
        .background(Color.appBackground)
        .task(id: chart.id) {
            loadSynthesisIfNeeded(force: true)
            computeExtended()
        }
        .onChange(of: reading.synthesisDraft) { _, _ in
            loadSynthesisIfNeeded(force: false)
        }
        .onDisappear {
            saveTask?.cancel()
            saveSynthesisNow()
        }
    }

    private func topBar(proxy: ScrollViewProxy) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .center, spacing: 14) {
                VStack(alignment: .leading, spacing: 3) {
                    Text("Lectura natal completa")
                        .font(.title2.weight(.semibold))
                        .foregroundColor(.appPrimaryText)
                    Text("Texto del corpus visible, ordenado por método de lectura. Sin desplegables.")
                        .font(.callout)
                        .foregroundColor(.secondary)
                }
                Spacer(minLength: 16)
                Picker("Densidad", selection: $density) {
                    Text("Esencial").tag(ReadingDensity.essential)
                    Text("Completa").tag(ReadingDensity.complete)
                }
                .pickerStyle(.segmented)
                .frame(width: 220)
            }

            HStack(spacing: 12) {
                searchField
                corpusStatus
            }

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(visibleReading.chapters) { chapter in
                        Button {
                            selectedChapter = chapter.id
                            withAnimation(.easeInOut(duration: 0.22)) {
                                proxy.scrollTo(chapter.id, anchor: .top)
                            }
                        } label: {
                            Text(chapter.title)
                                .font(.caption.weight(.semibold))
                                .foregroundColor(selectedChapter == chapter.id ? .appAccentForeground : .appPrimaryText)
                                .padding(.horizontal, 11)
                                .padding(.vertical, 7)
                                .background(selectedChapter == chapter.id ? Color.appAccentFill : Color.appChipBackground)
                                .clipShape(Capsule())
                        }
                        .buttonStyle(.plain)
                    }
                    Button {
                        selectedChapter = .synthesis
                        withAnimation(.easeInOut(duration: 0.22)) {
                            proxy.scrollTo(ReadingChapterKind.synthesis, anchor: .top)
                        }
                    } label: {
                        Text("Síntesis")
                            .font(.caption.weight(.semibold))
                            .foregroundColor(selectedChapter == .synthesis ? .appAccentForeground : .appPrimaryText)
                            .padding(.horizontal, 11)
                            .padding(.vertical, 7)
                            .background(selectedChapter == .synthesis ? Color.appAccentFill : Color.appChipBackground)
                            .clipShape(Capsule())
                    }
                    .buttonStyle(.plain)
                }
                .padding(.vertical, 2)
            }
        }
        .padding(.horizontal, 22)
        .padding(.vertical, 16)
        .background(Color.appPanel)
    }

    private var searchField: some View {
        HStack(spacing: 9) {
            Image(systemName: "magnifyingglass")
                .foregroundColor(.secondary)
            TextField("Buscar una frase en la lectura", text: $searchText)
                .textFieldStyle(.plain)
            if !searchText.isEmpty {
                Button { searchText = "" } label: {
                    Image(systemName: "xmark.circle.fill")
                }
                .buttonStyle(.plain)
                .foregroundColor(.secondary)
            }
        }
        .padding(.horizontal, 11)
        .padding(.vertical, 9)
        .background(Color.appInputBackground)
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 10, style: .continuous).stroke(Color.appBorder.opacity(0.7), lineWidth: 1))
    }

    private var corpusStatus: some View {
        HStack(spacing: 8) {
            Label("\(interpretaciones.count) textos", systemImage: interpretaciones.isEmpty ? "exclamationmark.triangle" : "text.book.closed")
                .foregroundColor(interpretaciones.isEmpty ? .appWarning : .secondary)
            if isLoadingExtended {
                ProgressView().controlSize(.small)
                Text("extendido…")
                    .foregroundColor(.secondary)
            } else if extended != nil {
                Image(systemName: "checkmark.seal")
                    .foregroundColor(.appSecondaryAccent)
            } else if extendedError != nil {
                Image(systemName: "seal")
                    .foregroundColor(.secondary)
            }
        }
        .font(.caption)
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(Color.appSurface)
        .clipShape(Capsule())
    }

    private var articleHero: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(chart.name.isEmpty ? "Carta natal" : chart.name)
                .font(.system(size: 34, weight: .semibold))
                .foregroundColor(.appPrimaryText)
                .fixedSize(horizontal: false, vertical: true)
            HStack(spacing: 16) {
                if !chart.placeName.isEmpty {
                    Label(chart.placeName, systemImage: "mappin")
                }
                Label("\(chart.birthDate) · \(chart.birthTime)", systemImage: "calendar")
                Label(chart.timezone, systemImage: "globe")
            }
            .font(.callout)
            .foregroundColor(.secondary)
            .fixedSize(horizontal: false, vertical: true)

            ReadingFlowLayout(spacing: 8) {
                heroChip("ASC", chart.ascendant.formatted)
                heroChip("MC", chart.mc.formatted)
                if let sun = chart.bodies.first(where: { $0.key == "SOL" }) {
                    heroChip("Sol", "\(sun.formatted) · Casa \(sun.house)")
                }
                if let moon = chart.bodies.first(where: { $0.key == "LUNA" }) {
                    heroChip("Luna", "\(moon.formatted) · Casa \(moon.house)")
                }
            }
        }
        .padding(.top, 28)
        .padding(.bottom, 4)
    }

    private func heroChip(_ label: String, _ value: String) -> some View {
        HStack(spacing: 6) {
            Text(label)
                .font(.caption.weight(.bold))
                .foregroundColor(.secondary)
            Text(value)
                .font(.caption.monospacedDigit())
                .foregroundColor(.appPrimaryText)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 7)
        .background(Color.appChipBackground)
        .clipShape(Capsule())
    }

    private var emptySearch: some View {
        VStack(spacing: 10) {
            Image(systemName: "text.magnifyingglass")
                .font(.system(size: 34))
                .foregroundColor(.secondary)
            Text("Sin coincidencias en el texto de la lectura")
                .font(.headline)
                .foregroundColor(.appPrimaryText)
            Text("Limpia la búsqueda para volver al documento completo.")
                .font(.callout)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 80)
    }

    private var synthesisEditor: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Síntesis")
                .readingChapterTitle()
            Text("Espacio de cierre del astrólogo. Se guarda automáticamente para esta carta.")
                .font(.subheadline)
                .foregroundColor(.secondary)

            if !reading.synthesisDraft.isEmpty {
                VStack(alignment: .leading, spacing: 7) {
                    Text("Borrador automático")
                        .font(.subheadline.weight(.semibold))
                        .foregroundColor(.appPrimaryText)
                    ForEach(reading.synthesisDraft, id: \.self) { item in
                        Text("• \(item)")
                            .font(.callout)
                            .lineSpacing(3)
                            .foregroundColor(.appPrimaryText)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                .padding(.vertical, 10)
            }

            TextEditor(text: $synthesis)
                .font(.title3)
                .lineSpacing(7)
                .frame(minHeight: 300)
                .padding(14)
                .scrollContentBackground(.hidden)
                .background(Color.appInputBackground)
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).stroke(Color.appBorder.opacity(0.8), lineWidth: 1))
                .onChange(of: synthesis) { _, _ in scheduleAutosave() }
        }
    }

    private func computeExtended() {
        isLoadingExtended = true
        extendedError = nil
        do {
            extended = try NatalExtendedAnalysis.compute(chart: chart)
        } catch {
            extended = nil
            extendedError = error.localizedDescription
        }
        isLoadingExtended = false
    }

    private func loadSynthesisIfNeeded(force: Bool) {
        let chartId = chart.id.uuidString
        guard force || loadedChartId != chartId else { return }
        if let note = notesStore.note(for: chartId) {
            synthesis = note.synthesis
        } else {
            synthesis = reading.synthesisDraft.map { "• \($0)" }.joined(separator: "\n")
        }
        loadedChartId = chartId
    }

    private func scheduleAutosave() {
        saveTask?.cancel()
        let chartId = chart.id.uuidString
        let text = synthesis
        saveTask = Task { @MainActor in
            try? await Task.sleep(nanoseconds: 1_000_000_000)
            guard !Task.isCancelled else { return }
            do {
                try notesStore.save(.init(chartId: chartId, synthesis: text, updatedAt: Date()))
            } catch {
                print("[NatalReadingView] Autosave error: \(error)")
            }
        }
    }

    private func saveSynthesisNow() {
        let chartId = chart.id.uuidString
        do {
            try notesStore.save(.init(chartId: chartId, synthesis: synthesis, updatedAt: Date()))
        } catch {
            print("[NatalReadingView] Save error: \(error)")
        }
    }

    private func blockMatches(_ block: ReadingBlock, query: String) -> Bool {
        guard case .corpus(let title, let paragraphs, let source) = block.kind else { return false }
        let haystack = ([title ?? ""] + paragraphs + [source]).joined(separator: "\n")
        return haystack.range(of: query, options: [.caseInsensitive, .diacriticInsensitive]) != nil
    }
}
