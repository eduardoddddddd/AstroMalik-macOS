import SwiftUI

struct RectificationEventEditorRow: View {
    @Binding var event: RectificationEvent
    let onDelete: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            ViewThatFits(in: .horizontal) {
                wideLayout
                compactLayout
            }
            if event.precision == .dateRange {
                HStack {
                    Text("Fin del rango")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    DatePicker(
                        "",
                        selection: endDateBinding,
                        in: event.dateStart...,
                        displayedComponents: .date
                    )
                    .labelsHidden()
                }
            }
        }
        .padding(.vertical, 4)
    }

    private var wideLayout: some View {
        HStack(alignment: .top, spacing: 8) {
            TextField("Título", text: $event.title).frame(width: 150)
            typePicker.frame(width: 155)
            DatePicker("", selection: $event.dateStart, displayedComponents: .date)
                .labelsHidden()
            precisionPicker.frame(width: 115)
            confidencePicker.frame(width: 150)
            Stepper("\(event.importance)/5", value: $event.importance, in: 1...5)
                .frame(width: 92)
            deleteButton
        }
        .fixedSize(horizontal: true, vertical: false)
    }

    private var compactLayout: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                TextField("Título", text: $event.title)
                deleteButton
            }
            LazyVGrid(
                columns: [GridItem(.adaptive(minimum: 170), alignment: .leading)],
                alignment: .leading,
                spacing: 8
            ) {
                LabeledContent("Tipo") { typePicker }
                LabeledContent("Fecha") {
                    DatePicker("", selection: $event.dateStart, displayedComponents: .date)
                        .labelsHidden()
                }
                LabeledContent("Precisión") { precisionPicker }
                LabeledContent("Fiabilidad") { confidencePicker }
                Stepper("Importancia \(event.importance)/5", value: $event.importance, in: 1...5)
            }
        }
    }

    private var typePicker: some View {
        Picker("Tipo", selection: $event.type) {
            ForEach(RectificationEventType.allCases) { type in
                Text(type.label).tag(type)
            }
        }
        .labelsHidden()
    }

    private var precisionPicker: some View {
        Picker("Precisión", selection: $event.precision) {
            ForEach(RectificationEventPrecision.allCases) { precision in
                Text(precision.label).tag(precision)
            }
        }
        .labelsHidden()
    }

    private var confidencePicker: some View {
        Picker("Fiabilidad", selection: $event.confidence) {
            ForEach(RectificationEventConfidence.allCases) { confidence in
                Text(confidence.label).tag(confidence)
            }
        }
        .labelsHidden()
    }

    private var deleteButton: some View {
        Button(role: .destructive, action: onDelete) {
            Image(systemName: "trash")
        }
        .buttonStyle(.borderless)
        .help("Eliminar evento")
    }

    private var endDateBinding: Binding<Date> {
        Binding(
            get: { event.dateEnd ?? event.dateStart },
            set: { event.dateEnd = $0 }
        )
    }
}

extension RectificationEventPrecision {
    var label: String {
        switch self {
        case .exactDay: return "Día exacto"
        case .approximateWeek: return "Semana"
        case .approximateMonth: return "Mes"
        case .approximateQuarter: return "Trimestre"
        case .approximateYear: return "Año"
        case .dateRange: return "Rango"
        }
    }
}
