import SwiftUI

struct HoraryDiagnosticsView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var diagnostics: HoraryDiagnostics?
    @State private var isLoading = false

    var body: some View {
        NavigationStack {
            Group {
                if isLoading && diagnostics == nil {
                    ProgressView("Revisando Horaria...")
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if let diagnostics {
                    diagnosticsContent(diagnostics)
                } else {
                    emptyState
                }
            }
            .background(Color.appBackground)
            .navigationTitle("Diagnóstico de Horaria")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cerrar") { dismiss() }
                }
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        Task { await refresh() }
                    } label: {
                        Label("Actualizar", systemImage: "arrow.clockwise")
                    }
                    .disabled(isLoading)
                }
            }
        }
        .frame(minWidth: 560, minHeight: 420)
        .task { await refresh() }
    }

    private func diagnosticsContent(_ diagnostics: HoraryDiagnostics) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                statusHeader(diagnostics)
                VStack(alignment: .leading, spacing: 10) {
                    row("Python", diagnostics.pythonPath ?? "No encontrado")
                    row("Versión", diagnostics.pythonVersion ?? "No disponible")
                    row("Fuente Horaria", diagnostics.moduleSource ?? "No disponible")
                    row("Módulo", diagnostics.modulePath ?? "No disponible")
                }
                .appCard()

                VStack(alignment: .leading, spacing: 8) {
                    Text("Fuentes revisadas")
                        .appSectionHeader()
                    ForEach(diagnostics.checkedSources, id: \.self) { source in
                        Label(source, systemImage: "checklist")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                }
                .appCard()

                if let lastError = diagnostics.lastError, !lastError.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Último error")
                            .appSectionHeader()
                        Text(lastError)
                            .font(.callout)
                            .foregroundColor(.secondary)
                            .textSelection(.enabled)
                    }
                    .appCard()
                }
            }
            .padding(20)
        }
    }

    private func statusHeader(_ diagnostics: HoraryDiagnostics) -> some View {
        HStack(spacing: 12) {
            Image(systemName: diagnostics.isReady ? "checkmark.seal.fill" : "exclamationmark.triangle.fill")
                .font(.title2)
                .foregroundColor(diagnostics.isReady ? .appSecondaryAccent : .appWarning)
            VStack(alignment: .leading, spacing: 3) {
                Text(diagnostics.isReady ? "Horaria disponible" : "Horaria no disponible")
                    .font(.headline)
                    .foregroundColor(.appPrimaryText)
                Text(diagnostics.isReady ? "El motor se puede invocar desde la app." : "Configura el módulo o revisa Python.")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            Spacer()
        }
        .appCard()
    }

    private func row(_ title: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(.caption2.weight(.semibold))
                .foregroundColor(.secondary)
            Text(value)
                .font(.subheadline)
                .foregroundColor(.appPrimaryText)
                .textSelection(.enabled)
        }
    }

    private var emptyState: some View {
        VStack(spacing: 10) {
            Image(systemName: "stethoscope")
                .font(.system(size: 42))
                .foregroundColor(.secondary)
            Text("Sin diagnóstico")
                .font(.headline)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func refresh() async {
        isLoading = true
        diagnostics = await HoraryEngine.diagnostics()
        isLoading = false
    }
}
