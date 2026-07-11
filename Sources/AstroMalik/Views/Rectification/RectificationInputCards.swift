import SwiftUI

struct RectificationDataCard: View {
    let charts: [NatalChart]
    @Binding var selectedChartID: UUID?
    @Binding var session: RectificationSession

    var body: some View {
        GroupBox("Carta y rango") {
            VStack(alignment: .leading, spacing: 12) {
                Picker("Carta", selection: $selectedChartID) {
                    ForEach(charts) { chart in
                        Text(chart.name.isEmpty ? chart.birthDate : chart.name).tag(Optional(chart.id))
                    }
                }
                .frame(maxWidth: 420)

                ViewThatFits(in: .horizontal) {
                    HStack(spacing: 14) { rangeControls }
                    VStack(alignment: .leading, spacing: 10) { rangeControls }
                }
                ViewThatFits(in: .horizontal) {
                    HStack { stepControls }
                    VStack(alignment: .leading, spacing: 8) { stepControls }
                }
                Toggle("Buscar en las 24 horas", isOn: $session.searchRange.includeFullDayFallback)
                Text("Estimación primera pasada: \(session.searchRange.coarseCandidateEstimate) candidatas")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding(8)
        }
    }

    @ViewBuilder private var rangeControls: some View {
        TextField("Hora central", text: $session.searchRange.centerTime).frame(width: 110)
        Stepper("Antes: \(session.searchRange.minutesBefore) min", value: $session.searchRange.minutesBefore, in: 0...720, step: 15)
        Stepper("Después: \(session.searchRange.minutesAfter) min", value: $session.searchRange.minutesAfter, in: 0...720, step: 15)
    }

    @ViewBuilder private var stepControls: some View {
        Stepper("Paso grueso: \(session.searchRange.coarseStepSeconds / 60) min", value: $session.searchRange.coarseStepSeconds, in: 60...900, step: 60)
        Stepper("Paso fino: \(session.searchRange.fineStepSeconds) s", value: $session.searchRange.fineStepSeconds, in: 30...300, step: 30)
    }
}

struct RectificationQuestionnaireCard: View {
    @Binding var session: RectificationSession

    var body: some View {
        GroupBox("Cuestionario preliminar de Ascendente") {
            VStack(alignment: .leading, spacing: 10) {
                Text("Señal orientativa de baja ponderación; no sustituye los eventos fechados.")
                    .font(.caption).foregroundStyle(.secondary)
                ForEach(AscendantQuestionnaireCatalog.questions) { question in
                    ViewThatFits(in: .horizontal) {
                        HStack { questionLabel(question); answerPicker(question) }
                        VStack(alignment: .leading) { questionLabel(question); answerPicker(question) }
                    }
                }
                if let questionnaire = session.ascendantQuestionnaire,
                   let sign = questionnaire.preliminarySignLabel {
                    Label("Hipótesis preliminar: Ascendente en \(sign) · \(Int(questionnaire.completion * 100)) % completado", systemImage: "sparkle.magnifyingglass")
                        .font(.subheadline.weight(.medium))
                }
            }.padding(8)
        }
    }

    private func questionLabel(_ question: AscendantQuestion) -> some View {
        Text(question.prompt).frame(maxWidth: .infinity, alignment: .leading)
    }

    private func answerPicker(_ question: AscendantQuestion) -> some View {
        Picker("Respuesta", selection: answerBinding(question.id)) {
            Text("Sin responder").tag("")
            ForEach(question.options) { Text($0.label).tag($0.id) }
        }
        .labelsHidden().frame(width: 260)
    }

    private func answerBinding(_ questionID: String) -> Binding<String> {
        Binding(get: { session.ascendantQuestionnaire?.answers[questionID] ?? "" }, set: { value in
            var questionnaire = session.ascendantQuestionnaire ?? AscendantQuestionnaire()
            if value.isEmpty { questionnaire.answers.removeValue(forKey: questionID) }
            else { questionnaire.answers[questionID] = value }
            session.ascendantQuestionnaire = questionnaire
            session.updatedAt = Date()
        })
    }
}

struct RectificationEventsCard: View {
    @Binding var session: RectificationSession
    let onAdd: () -> Void
    let onDelete: (UUID) -> Void

    var body: some View {
        GroupBox("Cronología vital") {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    datasetQuality
                    Spacer()
                    Button("Añadir evento", systemImage: "plus", action: onAdd)
                }
                if session.events.isEmpty {
                    Text("Añade al menos tres eventos con fecha de día, semana o mes; seis o más mejoran la discriminación.")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach($session.events) { $event in
                        RectificationEventEditorRow(event: $event) { onDelete(event.id) }
                        Divider()
                    }
                }
            }
            .padding(8)
        }
    }

    private var datasetQuality: some View {
        let count = session.events.filter { $0.precision.qualifiesForMinimumDataset }.count
        return Label(
            count >= 6 ? "Dataset bueno (\(count))" : count >= 3 ? "Dataset aceptable (\(count))" : "Dataset insuficiente (\(count)/3)",
            systemImage: count >= 6 ? "checkmark.circle.fill" : "info.circle"
        )
        .foregroundStyle(count >= 3 ? Color.appSecondaryAccent : Color.appWarning)
    }
}
