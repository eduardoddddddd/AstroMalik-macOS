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
                Desde Cartas Guardadas puedes reabrir, buscar, etiquetar y anotar cartas ya archivadas. Tránsitos usa una carta guardada para calcular periodos, línea temporal de intensidad diaria, tabla y detalle de eventos.
                """)

                section("Lectura", """
                La sección Lectura abre la carta activa con rueda interactiva, lectura guiada, regente del Ascendente, aspectos dominantes y síntesis editable.
                """)

                section("Horaria", """
                Horaria calcula el juicio en Python y muestra el resultado en la app. Necesita Python 3 y el paquete horaria instalado, o una ruta configurada con ASTROMALIK_HORARIA_PATH. Usa el botón de diagnóstico para revisar la instalación.
                """)

                section("Apariencia", """
                En Ajustes puedes elegir entre Sistema, Claro u Oscuro.
                """)

                section("Guardar frente a exportar", """
                El botón principal de resultado guarda localmente en la base de datos de AstroMalik. La vista de carta puede copiar una nota Markdown preparada para Joplin.
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
