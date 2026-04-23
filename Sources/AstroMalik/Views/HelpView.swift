import SwiftUI

struct HelpView: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                section("AstroMalik Help", """
                AstroMalik reúne carta natal, tránsitos y horaria en una sola ventana. La barra lateral sirve para cambiar de función y el panel derecho muestra formularios, listados o resultados.
                """)

                section("Nueva Carta", """
                Introduce fecha, hora, zona y lugar. Al calcular, la carta se carga en el panel derecho. El botón de guardar conserva la carta en tu archivo local.
                """)

                section("Cartas Guardadas y Tránsitos", """
                Desde Cartas Guardadas puedes reabrir cartas ya archivadas. Tránsitos usa una carta guardada para calcular periodos y detalle de eventos.
                """)

                section("Horaria", """
                Horaria calcula el juicio en Python y muestra el resultado en la app. Necesita Python 3 disponible y el paquete horaria instalado o el repositorio local en /Users/eduardoariasbravo/Developer/horaria.
                """)

                section("Apariencia", """
                En Ajustes puedes elegir entre Sistema, Claro u Oscuro.
                """)

                section("Guardar frente a exportar", """
                El botón principal de resultado guarda localmente en la base de datos de AstroMalik. En esta versión no exporta PDF.
                """)
            }
            .padding(24)
        }
        .frame(minWidth: 540, minHeight: 420)
        .background(Color.appBackground)
    }

    private func section(_ title: String, _ body: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.headline)
                .foregroundColor(.appPrimaryText)
            Text(body)
                .font(.body)
                .foregroundColor(.primary)
                .lineSpacing(4)
        }
    }
}
