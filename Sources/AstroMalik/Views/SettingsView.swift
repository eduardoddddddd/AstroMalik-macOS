import SwiftUI

struct SettingsView: View {
    @EnvironmentObject var appState: AppState

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

                Text("Se usa para crear notas de sinastría directamente en Joplin.")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .formStyle(.grouped)
        .padding(20)
        .frame(minWidth: 460, idealWidth: 520, minHeight: 360)
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
}
