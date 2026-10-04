"""Inventory authentic Mac navigation for capture; no image generation."""
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
BASE = "Sources/AstroMalik/"
rows = [
    ("nueva-carta", "Nueva Carta", "birthForm", "Views/BirthChartForm.swift", "Introducir datos civiles de Eduardo de F1; capturar formulario antes de calcular."),
    ("cartas", "Cartas Guardadas", "savedCharts", "Views/SavedChartsView.swift", "Ver Eduardo, Buenos Aires y Reykjavik importadas en la cuenta de pruebas; abrir Eduardo para fijarla activa."),
    ("lectura", "Lectura", "reading", "Views/Reading/NatalReadingView.swift", "Carta activa Eduardo; esperar corpus local; no activar IA."),
    ("rectificacion", "Rectificación", "rectification", "Views/Rectification/RectificationView.swift", "Usar caso sintético rectification.run del manifiesto; no presentarlo como biografía de Eduardo."),
    ("transitos", "Tránsitos", "transits", "Views/TransitsView.swift", "Elegir Eduardo y rango 2026-10-04 a 2027-04-04 cuando el control lo permita; anotar rango observado."),
    ("progresiones", "Progresiones", "progressions", "Views/Progressions/ProgressionsView.swift", "Eduardo activa; fecha referencia fija 2026-10-04; esperar cálculo."),
    ("direcciones-primarias", "Direcciones Primarias", "primaryDirections", "PrimaryDirections/Views/PrimaryDirectionsView.swift", "Eduardo activa; técnica Regiomontanas; registrar configuración y filtros observados."),
    ("profecciones", "Profecciones", "profections", "Views/Profections/ProfectionsView.swift", "Eduardo activa; fecha referencia 2026-10-04; esperar cálculo."),
    ("firdaria", "Firdaria", "firdaria", "Views/Firdaria/FirdariaView.swift", "Eduardo activa; fecha referencia 2026-10-04; esperar cálculo."),
    ("zodiacal-releasing", "Zodiacal Releasing", "zodiacalReleasing", "Views/ZodiacalReleasing/ZRView.swift", "Eduardo activa; registrar lote, profundidad y fecha observados."),
    ("revolucion-solar", "Revolución Solar", "solarReturn", "Views/SolarReturnView.swift", "Eduardo activa; año 2026, ubicación natal Madrid; esperar cálculo."),
    ("revolucion-lunar", "Revolución Lunar", "lunarReturn", "Views/LunarReturnView.swift", "Eduardo activa; inicio 2026-10-04, Madrid, tres retornos si control disponible."),
    ("panorama-predictivo", "Panorama Predictivo", "crossPersonal", "Views/CrossPersonal/CrossPersonalView.swift", "Eduardo activa; fecha 2026-10-04; narrativa externa desactivada."),
    ("sinastria", "Sinastría", "synastry", "Views/SynastryView.swift", "Elegir Eduardo y Buenos Aires F1; no inventar pareja; esperar tabla/doble rueda."),
    ("horaria", "Horaria", "horaryHome", "Horary/Views/HoraryHomeView.swift", "Nueva Consulta; petición horary.compute del manifiesto, pregunta de prueba F3."),
    ("astrocartografia", "Astrocartografía", "astrocartography", "Astrocartography/UI/AstrocartographyView.swift", "Elegir Eduardo; esperar líneas; si mapa base requiere red registrar estado local sin atribuirlo a fallo de líneas."),
    ("efemerides", "Efemérides", "ephemeris", "Views/EphemerisCalendarView.swift", "Mes octubre 2026; registrar zona y fecha observadas."),
    ("informes", "Informes", "myReports", "Views/MyReportsView.swift", "Cuenta aislada; vista real con estado vacío si no hay informes, identificarlo en metadata."),
    ("ajustes", "Ajustes", "settings", "Views/SettingsView.swift", "Capturar apariencia/valores por defecto; evitar revelar claves o tokens."),
]
extras = [
    ("natal-rueda", "Cartas Guardadas", "natalResult", "Views/NatalChartView.swift", "Abrir Eduardo y seleccionar Rueda."),
    ("natal-extendida", "Cartas Guardadas", "natalResult", "Views/NatalExtended/NatalExtendedAnalysisView.swift", "Abrir Eduardo y seleccionar Análisis extendido; esperar corpus."),
    ("arco-solar", "Direcciones Primarias", "primaryDirections", "PrimaryDirections/Views/SolarArcDirectionsView.swift", "Cambiar técnica a Arco Solar; Eduardo activa; registrar filtros."),
    ("horaria-resultado", "Horaria", "horaryResult", "Horary/Views/HoraryResultView.swift", "Calcular petición horary.compute de prueba F3 y abrir resultado real."),
    ("horaria-historial", "Horaria", "horaryHome", "Horary/Views/SavedHoraryView.swift", "Seleccionar Historial de la cuenta aislada; sin datos personales."),
    ("horaria-diagnostico", "Horaria", "horaryResult", "Horary/Views/HoraryDiagnosticsView.swift", "Abrir diagnóstico real si accesible desde resultado; no fabricar UI ausente."),
    ("rectificacion-auditoria", "Rectificación", "rectification", "Views/Rectification/RectificationAuditSummaryView.swift", "Calcular caso sintético del manifiesto y abrir auditoría real."),
    ("ayuda", None, "helpSheet", "Views/HelpView.swift", "Menú Help → AstroMalik Help; capturar ventana/hoja completa."),
]

def main():
    screens = [{"id": key, "sidebarLabel": label, "route": route, "source": BASE + source,
                "instruction": instruction, "requiredSidebar": index < len(rows)}
               for index, (key, label, route, source, instruction) in enumerate(rows + extras)]
    for screen in screens:
        if not (ROOT / "engine/vendor/AstroMalik-macOS" / screen["source"]).is_file():
            raise SystemExit("Source view missing: " + screen["source"])
    output = ROOT / "fixtures/inputs/f2/screens-inventory.json"
    output.write_text(json.dumps({"schemaVersion": 1, "kind": "capture-inventory-not-screenshots", "screens": screens,
                                 "requirements": ["Real Mac AstroMalik window; source commit recorded", "Isolated test account/data or read-only existing session approved by root",
                                                  "Light theme and window at least 1100×780 preferred", "Chart Eduardo from F1; exact observed inputs in per-image metadata",
                                                  "No credentials on screen; no network narrative", "Visual inspection required; loading/placeholders do not prove populated calculation"]},
                                ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    print(f"Inventory prepared: 19 sidebar views + {len(extras)} detail views")

if __name__ == "__main__":
    main()
