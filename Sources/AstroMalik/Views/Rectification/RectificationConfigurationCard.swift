import SwiftUI

struct RectificationConfigurationCard: View {
    @Binding var config: RectificationConfig

    var body: some View {
        GroupBox("Configuración profesional") {
            VStack(alignment: .leading, spacing: 10) {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 220), alignment: .leading)], alignment: .leading, spacing: 10) {
                    Picker("Escuela", selection: schoolBinding) {
                        ForEach(RectificationSchool.allCases) { Text($0.label).tag($0) }
                    }
                    Picker("Casas", selection: $config.houseSystem) {
                        ForEach(RectificationHouseSystem.allCases) { Text($0.label).tag($0) }
                    }
                    Stepper("Ventana cluster: \(config.clusterWindowMinutes) min", value: $config.clusterWindowMinutes, in: 2...30)
                    Toggle("Penalizar sobreajuste", isOn: $config.penalizeWeakContacts)
                    Toggle("Comparar todos los sistemas de casas", isOn: $config.evaluateMultipleHouseSystems)
                }
                if config.evaluateMultipleHouseSystems {
                    Label("Ejecutará seis análisis completos y mostrará convergencia o dispersión entre sistemas.", systemImage: "clock.arrow.2.circlepath")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                ViewThatFits(in: .horizontal) {
                    HStack { orbControls }
                    VStack(alignment: .leading, spacing: 8) { orbControls }
                }
                Text("Técnicas habilitadas").font(.subheadline.weight(.semibold))
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 190), alignment: .leading)], alignment: .leading, spacing: 6) {
                    ForEach(RectificationTechnique.allCases) { technique in
                        Toggle(technique.label, isOn: techniqueEnabledBinding(technique))
                    }
                }
                DisclosureGroup("Pesos y sensibilidad anti-overfitting") {
                    VStack(alignment: .leading, spacing: 8) {
                        ViewThatFits(in: .horizontal) {
                            HStack { overfittingControls }
                            VStack(alignment: .leading) { overfittingControls }
                        }
                        ForEach(RectificationTechnique.allCases.filter { config.enabledTechniques.contains($0) }) { technique in
                            HStack {
                                Text(technique.label).frame(width: 210, alignment: .leading)
                                Slider(value: techniqueWeightBinding(technique), in: 0...1.5, step: 0.05)
                                Text(String(format: "%.2f", config.techniqueWeights[technique] ?? 1)).frame(width: 42).monospacedDigit()
                            }
                        }
                    }.padding(.top, 8)
                }
                Text("Cuantas más técnicas se habilitan, mayor es la penalización por concentración y complejidad. Los señores del tiempo actúan como confirmación.")
                    .font(.caption).foregroundStyle(.secondary)
            }.padding(8)
        }
    }

    @ViewBuilder private var orbControls: some View {
        Text("Multiplicador de orbe")
        Slider(value: $config.orbMultiplier, in: 0.25...2, step: 0.05)
        Text(String(format: "%.2f×", config.orbMultiplier)).monospacedDigit().frame(width: 55)
        Toggle("Planetas modernos", isOn: $config.useModernPlanets)
    }

    @ViewBuilder private var overfittingControls: some View {
        Text("Fuerza de penalización")
        Slider(value: overfittingStrengthBinding, in: 0...1, step: 0.05)
        Text(String(format: "%.2f", config.resolvedOverfittingPenaltyStrength)).monospacedDigit()
    }

    private var schoolBinding: Binding<RectificationSchool> {
        Binding(get: { config.resolvedSchool }, set: { config.applySchoolPreset($0) })
    }

    private var overfittingStrengthBinding: Binding<Double> {
        Binding(
            get: { config.resolvedOverfittingPenaltyStrength },
            set: { config.overfittingPenaltyStrength = min(1, max(0, $0)) }
        )
    }

    private func techniqueEnabledBinding(_ technique: RectificationTechnique) -> Binding<Bool> {
        Binding(get: { config.enabledTechniques.contains(technique) }, set: { enabled in
            if enabled { config.enabledTechniques.insert(technique) }
            else { config.enabledTechniques.remove(technique) }
        })
    }

    private func techniqueWeightBinding(_ technique: RectificationTechnique) -> Binding<Double> {
        Binding(get: { config.techniqueWeights[technique] ?? 1 }, set: { config.techniqueWeights[technique] = $0 })
    }
}
