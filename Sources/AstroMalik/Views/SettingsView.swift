import SwiftUI

struct SettingsView: View {
    @EnvironmentObject var appState: AppState
    @State private var pdSettings: PDSettings = PDSettings.load()

    var body: some View {
        Form {
            Section("Apariencia") {
                Picker("Tema", selection: $appState.appearanceMode) {
                    ForEach(AppAppearanceMode.allCases) { mode in
                        Text(mode.label).tag(mode)
                    }
                }
                .pickerStyle(.segmented)

                Text("Elige si AstroMalik sigue el sistema o fuerza modo claro u oscuro.")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Section("Direcciones Primarias — Valores por defecto") {
                Picker("Método", selection: $pdSettings.method) {
                    ForEach([PrimaryDirectionMethod.regiomontanus], id: \.self) { m in
                        Text(m.rawValue.capitalized).tag(m)
                    }
                }
                .pickerStyle(.radioGroup)

                Picker("Clave temporal", selection: $pdSettings.key) {
                    Text("Naibod (59'8\"/año)").tag(PrimaryDirectionKey.naibod)
                    Text("Ptolemeo (1°/año)").tag(PrimaryDirectionKey.ptolemy)
                    Text("Tycho Brahe").tag(PrimaryDirectionKey.brahe)
                }
                .pickerStyle(.radioGroup)

                Text("Predeterminados al abrir Direcciones Primarias. Ajustables por carta desde esa vista.")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Section("OpenRouter") {
                VStack(alignment: .leading, spacing: 10) {
                    statusRow(
                        title: "Estado",
                        value: appState.openRouterAvailability.badgeLabel,
                        tone: badgeTone(for: appState.openRouterAvailability)
                    )
                    statusRow(
                        title: "Fuente activa",
                        value: appState.openRouterAvailability.sourceLabel,
                        tone: .secondary
                    )

                    if let credential = appState.openRouterJoplinCredential {
                        statusRow(
                            title: "Nota Joplin",
                            value: "\(credential.noteTitle) · \(credential.maskedKey)",
                            tone: .secondary
                        )
                    } else {
                        statusRow(
                            title: "Nota Joplin",
                            value: "Sin key detectada en la base local de Joplin",
                            tone: .secondary
                        )
                    }

                    if let validation = appState.openRouterValidation {
                        Divider()
                        statusRow(title: "Label", value: validation.label, tone: .secondary)
                        statusRow(title: "Límite", value: openRouterNumber(validation.limit), tone: .secondary)
                        statusRow(title: "Uso", value: openRouterNumber(validation.usage), tone: .secondary)
                        statusRow(title: "Saldo", value: openRouterNumber(validation.limitRemaining), tone: .secondary)
                    }

                    if let message = appState.openRouterValidationMessage {
                        Label(message, systemImage: message.contains("válida") ? "checkmark.circle.fill" : "info.circle")
                            .font(.caption)
                            .foregroundStyle(message.contains("válida") ? Color.appSecondaryAccent : .secondary)
                    }

                    HStack(spacing: 10) {
                        Button("Importar desde Joplin a Keychain") {
                            Task { await appState.importOpenRouterKeyFromJoplin() }
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(Color.appAccentFill)
                        .disabled(appState.isOpenRouterBusy)

                        Button("Validar key") {
                            Task { await appState.validateOpenRouterKey() }
                        }
                        .buttonStyle(.bordered)
                        .disabled(appState.isOpenRouterBusy)

                        Button("Refrescar") {
                            Task { await appState.refreshOpenRouterDiagnostics() }
                        }
                        .buttonStyle(.borderless)
                        .disabled(appState.isOpenRouterBusy)

                        if appState.isOpenRouterBusy {
                            ProgressView()
                                .controlSize(.small)
                        }
                    }
                }

                Text("La app usa OpenRouter solo desde Keychain y, en segundo lugar, desde OPENROUTER_API_KEY. Joplin actúa únicamente como fuente de importación puntual.")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Section("Joplin Web Clipper") {
                TextField("Host", text: joplinHostBinding)
                    .textFieldStyle(.roundedBorder)
                    .autocorrectionDisabled()

                TextField("Puerto", value: joplinPortBinding, format: .number)
                    .textFieldStyle(.roundedBorder)

                SecureField("Token", text: joplinTokenBinding)
                    .textFieldStyle(.roundedBorder)

                TextField("Cuaderno", text: joplinNotebookBinding)
                    .textFieldStyle(.roundedBorder)

                Text("Se usa para crear notas directamente en Joplin.")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .formStyle(.grouped)
        .padding(20)
        .frame(minWidth: 460, idealWidth: 520, minHeight: 420)
        .onChange(of: pdSettings) { pdSettings.persist() }
        .task {
            await appState.refreshOpenRouterDiagnostics()
        }
    }

    private var joplinHostBinding: Binding<String> {
        Binding(
            get: { appState.joplinSettings.host },
            set: { appState.joplinSettings.host = $0 }
        )
    }

    private var joplinPortBinding: Binding<Int> {
        Binding(
            get: { appState.joplinSettings.port },
            set: { appState.joplinSettings.port = max(1, $0) }
        )
    }

    private var joplinTokenBinding: Binding<String> {
        Binding(
            get: { appState.joplinSettings.token },
            set: { appState.joplinSettings.token = $0 }
        )
    }

    private var joplinNotebookBinding: Binding<String> {
        Binding(
            get: { appState.joplinSettings.notebook },
            set: { appState.joplinSettings.notebook = $0 }
        )
    }

    private func statusRow(title: String, value: String, tone: Color) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 12) {
            Text(title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
                .frame(width: 92, alignment: .leading)
            Text(value)
                .font(.caption.monospaced())
                .foregroundStyle(tone)
        }
    }

    private func badgeTone(for availability: OpenRouterAvailability) -> Color {
        switch availability {
        case .notConfigured:
            return .secondary
        case .ready:
            return Color.appSecondaryAccent
        case .invalid:
            return Color.appWarning
        }
    }

    private func openRouterNumber(_ value: Double) -> String {
        let formatter = NumberFormatter()
        formatter.locale = Locale(identifier: "es_ES")
        formatter.numberStyle = .decimal
        formatter.maximumFractionDigits = 3
        formatter.minimumFractionDigits = 0
        return formatter.string(from: NSNumber(value: value)) ?? String(format: "%.3f", value)
    }
}
