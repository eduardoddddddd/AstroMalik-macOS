import SwiftUI

// MARK: - PrimaryDirectionFiltersView
// Sheet de filtros. Expone: rango de edad, aspectos, tipos, plano, prómissores, solo-corpus.

struct PrimaryDirectionFiltersView: View {
    @Binding var filters: PDFilters
    let maxYears: Double
    @Environment(\.dismiss) private var dismiss

    // Available promissors derived from the filter
    private let availablePromissors = PLANET_LIST.map(\.key) + ["ASC", "MC"]

    var body: some View {
        NavigationStack {
            Form {
                // MARK: Rango de edad
                Section {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("Edad mínima")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            Spacer()
                            Text("\(Int(filters.ageRange.lowerBound)) años")
                                .font(.caption.monospaced())
                        }
                        Slider(
                            value: Binding(
                                get: { filters.ageRange.lowerBound },
                                set: { newMin in
                                    let max = max(newMin + 1, filters.ageRange.upperBound)
                                    filters.ageRange = newMin...max
                                }
                            ),
                            in: 0...max(1, maxYears - 1), step: 1
                        )

                        HStack {
                            Text("Edad máxima")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            Spacer()
                            Text("\(Int(filters.ageRange.upperBound)) años")
                                .font(.caption.monospaced())
                        }
                        Slider(
                            value: Binding(
                                get: { filters.ageRange.upperBound },
                                set: { newMax in
                                    let min = min(newMax - 1, filters.ageRange.lowerBound)
                                    filters.ageRange = min...newMax
                                }
                            ),
                            in: 1...maxYears, step: 1
                        )
                    }
                } header: {
                    Label("Rango de Edad", systemImage: "calendar.badge.clock")
                }

                // MARK: Aspectos
                Section {
                    ForEach(PDaspect.allCases, id: \.self) { aspect in
                        Toggle(aspect.label, isOn: Binding(
                            get: { filters.aspects.contains(aspect) },
                            set: { on in
                                if on { filters.aspects.insert(aspect) }
                                else if filters.aspects.count > 1 { filters.aspects.remove(aspect) }
                            }
                        ))
                    }
                } header: {
                    Label("Aspectos", systemImage: "star.circle")
                }

                // MARK: Tipo de dirección
                Section {
                    ForEach(PDDirectionType.allCases, id: \.self) { type in
                        Toggle(type == .direct ? "Directas" : "Conversas", isOn: Binding(
                            get: { filters.directionTypes.contains(type) },
                            set: { on in
                                if on { filters.directionTypes.insert(type) }
                                else if filters.directionTypes.count > 1 { filters.directionTypes.remove(type) }
                            }
                        ))
                    }
                } header: {
                    Label("Tipo de Dirección", systemImage: "arrow.left.arrow.right")
                }

                // MARK: Plano
                Section {
                    ForEach(PDAspectPlane.allCases, id: \.self) { plane in
                        Toggle(plane.displayName, isOn: Binding(
                            get: { filters.aspectPlanes.contains(plane) },
                            set: { on in
                                if on { filters.aspectPlanes.insert(plane) }
                                else if filters.aspectPlanes.count > 1 { filters.aspectPlanes.remove(plane) }
                            }
                        ))
                    }
                } header: {
                    Label("Plano del Aspecto", systemImage: "globe")
                }

                // MARK: Prómissores
                Section {
                    HStack {
                        Button("Todos") {
                            filters.promissors = []
                        }
                        .buttonStyle(.bordered)

                        Text(filters.promissors.isEmpty
                             ? "Mostrando todos los prómissores"
                             : "\(filters.promissors.count) seleccionados")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 110))], spacing: 4) {
                        ForEach(availablePromissors, id: \.self) { key in
                            let label = PLANET_LIST.first(where: { $0.key == key })?.label ?? key
                            Toggle(label, isOn: Binding(
                                get: { isPromissorSelected(key) },
                                set: { on in
                                    setPromissor(key, selected: on)
                                }
                            ))
                            .toggleStyle(.button)
                            .buttonStyle(.bordered)
                            .controlSize(.small)
                            .tint(isPromissorSelected(key) ? Color.appAccentFill : .secondary)
                        }
                    }
                } header: {
                    Label("Prómissores", systemImage: "person.circle")
                }

                // MARK: Solo con corpus
                Section {
                    Toggle("Solo direcciones con corpus poblado", isOn: $filters.onlyWithCorpus)
                    Text("Oculta las entradas marcadas como populated=0 en la base de datos de corpus.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                } header: {
                    Label("Corpus", systemImage: "books.vertical")
                }
            }
            .formStyle(.grouped)
            .navigationTitle("Filtros — Direcciones Primarias")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Restablecer") {
                        filters.reset(maxYears: maxYears)
                    }
                    .foregroundStyle(.secondary)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Aplicar") { dismiss() }
                }
            }
            .frame(minWidth: 400, idealWidth: 480, minHeight: 600)
        }
    }

    private func isPromissorSelected(_ key: String) -> Bool {
        filters.promissors.isEmpty || filters.promissors.contains(key)
    }

    private func setPromissor(_ key: String, selected: Bool) {
        if filters.promissors.isEmpty {
            if selected { return }
            filters.promissors = Set(availablePromissors.filter { $0 != key })
            return
        }

        if selected {
            filters.promissors.insert(key)
            if filters.promissors.count == availablePromissors.count {
                filters.promissors = []
            }
        } else if filters.promissors.count > 1 {
            filters.promissors.remove(key)
        }
    }
}
