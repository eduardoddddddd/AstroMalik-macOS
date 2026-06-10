import SwiftUI

struct NatalReadingView: View {
    let chart: NatalChart
    let interpretaciones: [Interpretation]
    @Binding var selectedFocusKey: String?
    @ObservedObject var notesStore: ReadingNotesStore

    @State private var density: ReadingDensity = .essential
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
        HStack(spacing: 0) {
            ScrollViewReader { proxy in
                ReadingTOCView(chapters: visibleReading.chapters, selectedChapter: $selectedChapter) { chapter in
                    withAnimation(.easeInOut(duration: 0.22)) {
                        proxy.scrollTo(chapter, anchor: .top)
                    }
                }

                Divider()

                VStack(spacing: 0) {
                    header
                    Divider()
                    ScrollView {
                        VStack(alignment: .leading, spacing: 0) {
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
                        .frame(maxWidth: 720, alignment: .leading)
                        .frame(maxWidth: .infinity)
                        .padding(.horizontal, 28)
                        .padding(.bottom, 40)
                    }
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

    private var header: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .center, spacing: 12) {
                VStack(alignment: .leading, spacing: 3) {
                    Text("Lectura natal")
                        .font(.title3.weight(.semibold))
                        .foregroundColor(.appPrimaryText)
                    Text("Documento continuo generado desde corpus, carta y relevancia doctrinal.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                Spacer()
                Picker("Densidad", selection: $density) {
                    Text("Esencial").tag(ReadingDensity.essential)
                    Text("Completa").tag(ReadingDensity.complete)
                }
                .pickerStyle(.segmented)
                .frame(width: 220)
            }

            HStack(spacing: 10) {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.secondary)
                TextField("Buscar en el corpus de la lectura", text: $searchText)
                    .textFieldStyle(.plain)
                if !searchText.isEmpty {
                    Button {
                        searchText = ""
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                    }
                    .buttonStyle(.plain)
                    .foregroundColor(.secondary)
                }
                Spacer()
                if isLoadingExtended {
                    ProgressView().controlSize(.small)
                    Text("Enriqueciendo con análisis extendido…")
                        .font(.caption)
                        .foregroundColor(.secondary)
                } else if extended != nil {
                    Label("Extendido aplicado", systemImage: "checkmark.seal")
                        .font(.caption)
                        .foregroundColor(.appSecondaryAccent)
                } else if extendedError != nil {
                    Label("Sin extendido", systemImage: "exclamationmark.triangle")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .padding(9)
            .background(Color.appInputBackground)
            .clipShape(RoundedRectangle(cornerRadius: 9, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 9, style: .continuous).stroke(Color.appBorder.opacity(0.7), lineWidth: 1))
        }
        .padding(18)
        .background(Color.appPanel)
    }

    private var emptySearch: some View {
        VStack(spacing: 10) {
            Image(systemName: "text.magnifyingglass")
                .font(.system(size: 34))
                .foregroundColor(.secondary)
            Text("Sin coincidencias en bloques de corpus")
                .font(.headline)
                .foregroundColor(.appPrimaryText)
            Text("Prueba con otro término o limpia la búsqueda.")
                .font(.callout)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 80)
    }

    private var synthesisEditor: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Síntesis")
                .readingChapterTitle()
            Text("El borrador automático aporta hechos duros; la síntesis final queda persistida por carta.")
                .font(.subheadline)
                .foregroundColor(.secondary)

            if !reading.synthesisDraft.isEmpty {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Borrador automático")
                        .font(.caption.weight(.semibold))
                        .foregroundColor(.secondary)
                    ForEach(reading.synthesisDraft, id: \.self) { item in
                        Text("• \(item)")
                            .font(.callout)
                            .foregroundColor(.appPrimaryText)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                .appCard(padding: 12)
            }

            TextEditor(text: $synthesis)
                .font(.body)
                .lineSpacing(5)
                .frame(minHeight: 180)
                .scrollContentBackground(.hidden)
                .background(Color.appInputBackground)
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 10, style: .continuous).stroke(Color.appBorder, lineWidth: 1))
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
