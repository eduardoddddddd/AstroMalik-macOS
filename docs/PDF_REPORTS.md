# Informes PDF

Desde 1.0 AstroMalik genera 14 informes PDF profesionales en español, todos basados en la misma infraestructura HTML+CSS → WebKit → PDF. Sin dependencias externas.

## Filosofía

Los PDFs son el formato profesional para entregar trabajo astrológico a un consultante o archivar la propia práctica. Los requisitos no negociables:

- **Tipografía seria**: serif para texto, sans para datos, glifos astrológicos vectoriales.
- **Diseño impreso**: márgenes generosos, page breaks controlados, encabezado y pie con numeración.
- **Reutilizable**: 14 informes deben compartir tema y plantillas base para que el conjunto sea coherente.
- **Sin servicios externos**: cero dependencias de runtime. WebKit ya está en macOS.
- **Iterable visualmente**: poder abrir el HTML en el navegador antes de pulsar "exportar".

Por eso la implementación es HTML+CSS renderizado por `WKWebView.createPDF`, en vez de PDFKit imperativo o frameworks Swift externos.

## Arquitectura

Tres capas:

### Infraestructura

`Sources/AstroMalik/Reports/Service/`

- **`ReportRenderer`** — actor que envuelve `WKWebView` y `createPDF`. Configurable por tamaño de página (`A4 portrait`, `A4 landscape`, `letter`) y márgenes en mm.
- **`TemplateEngine`** — evaluador Mustache-like sin dependencias. Soporta `{{var.path}}`, `{{#each items}}...{{/each}}`, `{{#if cond}}...{{/if}}`, `{{#unless cond}}...{{/unless}}`, `{{> partialName}}` y `{{{raw}}}` (sin escape HTML). El escape HTML es default.
- **`ReportTheme`** — tokens visuales: paleta marfil/tinta/azul noche/dorado/benefico/malefico, tipografías EB Garamond serif + Inter sans + glifos astrológicos, márgenes, escalas tipográficas (h1 32pt → caption 9pt). `cssVariables()` emite el `:root`.
- **`ReportService`** — actor orquestador: nombre de plantilla + datos Codable → PDF.
- **`ReportPersistence`** — carpeta destino configurable, escaneo del histórico, eliminación con confirmación.
- **`MarkdownToHTML`** — convertidor minimalista usado por el cross-personal para incrustar la narrativa Anthropic.

### Plantillas

`Sources/AstroMalik/Resources/Reports/templates/`

Una plantilla por informe. Cada una incluye los partials base:

- `_layout.html` — header, body, footer con paginación CSS counter.
- `_cover.html` — portada estándar.
- `_toc.html` — tabla de contenidos (CSS counters + JS embebido mínimo).
- `_theme.css.html` — variables CSS, estilos base, tablas con stripes, badges por banda de prioridad.
- `_print.css.html` — `@page`, márgenes vía variables, `break-inside: avoid` para tablas, `page-break-after: avoid` para encabezados.
- `_glyphs.css.html` — placeholders para `@font-face` con WOFF2 inline; sistema fallback si no están embebidas.

### Renderers SVG

`Sources/AstroMalik/Reports/Charts/`

Strings SVG autocontenidos que se inyectan como `{{{wheelSVG}}}` en las plantillas:

- **`SVGCanvas`** — builder de SVG con `circle`, `line`, `path`, `text`, `group`, `rect`, `raw`. Funciones puras.
- **`WheelSVGRenderer`** — rueda natal con doble círculo exterior, divisiones de 30°, glifos por sector, cúspides de casa, líneas de aspecto coloreadas y algoritmo de lanes para evitar solapamiento de planetas próximos (`ChartSVGRenderingSupport.placements`).
- **`DoubleWheelSVGRenderer`** — rueda doble para sinastría y retornos. Dos anillos concéntricos con planetas natales y secundarios, aspectos cruzados.
- **`TimelineSVGRenderer`** — tres timelines: tránsitos (per-planet bands con color por banda de prioridad), ZR (L1 + L2 con peaks y LB) y Firdaria (ribbon de 75 años).
- **`EphemerisTableHTML`** — la efeméride diaria es demasiado densa para SVG; se emite como `<table>` HTML directa.
- **`Glyphs`** — `AstroGlyph` por planeta y signo (paths SVG o Unicode con fuente embebida según el caso).
- **`ChartSVGRenderingSupport`** — helpers compartidos: longitud → punto en círculo, color por aspecto, color por planeta, lanes anti-solapamiento, formato de grado en signo.

## Los 14 informes

Cada uno tiene plantilla HTML + ReportData + Builder + tests.

| Informe | Plantilla | Páginas |
|---|---|---:|
| Carta natal | `natal.html` | 8-12 |
| Sinastría | `synastry.html` | 12-16 |
| Análisis natal extendido | `extended_natal.html` | 10-15 |
| Horaria | `horary.html` | 4-6 |
| Tránsitos | `transits.html` | 10-18 |
| Revolución Solar | `solar_return.html` | 8-12 |
| Revolución Lunar | `lunar_return.html` | 4-6 |
| Calendario y efemérides | `calendar.html` | 6-10 |
| Resumen predictivo mensual | `monthly_summary.html` | 4-8 |
| Profecciones | `profections.html` | 4-6 |
| Direcciones primarias | `primary_directions.html` | 8-14 |
| Arco solar | `solar_arc.html` | 6-10 |
| Progresiones secundarias | `progressions.html` | 8-12 |
| Firdaria | `firdaria.html` | 6-10 |
| Zodiacal Releasing | `zodiacal_releasing.html` | 10-16 |
| **Cross-personal** (la corona) | `cross_personal.html` | 20-35 |

### Informe cross-personal — modo híbrido

`CrossPersonalReportBuilder.generate(state:narrative:scope:)` acepta dos modos:

- **Con narrativa Anthropic** (`narrative != nil`): el PDF muestra la lectura redactada por secciones (síntesis ejecutiva, firma natal, año en curso, medio plazo, corto plazo, capa lunar, temas convergentes, cierre) como texto principal y los datos del state como tablas de apoyo. La narrativa Markdown se parte por encabezado `## h2` con `MarkdownToHTML.sectionsByH2`, se convierte a HTML y se inyecta en la plantilla.
- **Solo datos** (`narrative == nil`): el PDF se compone únicamente con los datos estructurados del state. Útil como preview gratis sin coste de API.

Apéndice de trazabilidad técnica con modelo Anthropic, tokens, cache, coste estimado en USD.

## Tema visual

Tokens fijos en `ReportTheme.default`:

```text
--bg:           #F4EEE0   marfil profundo
--ink:          #1B1B1F   tinta principal
--ink-soft:     #4A4A52   texto secundario
--primary:      #1B2A4E   azul noche para encabezados
--gold:         #A07C2C   acento ocre dorado
--gold-soft:    #C7A95A   orlas y líneas finas
--benefic:      #3F6E48   verdes para benéficos
--malefic:      #8C3A2A   terracota para maléficos
--neutral-rule: #D8CDB4   separadores
--table-stripe: #ECE2CC
```

Tipografías:

- Cuerpo: `"EB Garamond", "Garamond", "Adobe Garamond Pro", serif`
- Datos / UI: `"Inter", -apple-system, BlinkMacSystemFont, "Helvetica Neue", Arial, sans-serif`
- Glifos: `"astro-glyphs", "Apple Symbols", "Segoe UI Symbol", serif`

Escala: h1 32pt, h2 22pt, h3 16pt, body 11pt, caption 9pt. Línea base 1.5.

Página: A4 portrait por defecto. Márgenes 25/25/20/25 mm (top/right/bottom/left).

## Integración UI

En 1.0 cada vista relevante incluye un botón **"Exportar PDF"** que invoca al builder correspondiente con los datos ya en pantalla. El flujo común:

1. Pulsar el botón → indicador de carga.
2. El builder produce `Data` con el PDF.
3. `ReportPersistence` lo guarda en la carpeta destino configurada (default `~/Documents/AstroMalik/`).
4. Toast de éxito con botón "Abrir" que ejecuta `NSWorkspace.shared.open(url)`.
5. Opcionalmente subida a Joplin como adjunto.

La sidebar tiene una entrada **"Mis informes"** (`MyReportsView`) que lista los PDFs presentes en la carpeta destino ordenados por fecha descendente, con acción de abrir, revelar en Finder y eliminar.

Ajustes (`SettingsView`) tiene una sección "Informes PDF" con:

- Carpeta destino (NSOpenPanel + persistencia por bookmark).
- Tamaño de página por defecto (A4 / Letter).
- Toggle "Abrir en Preview automáticamente al generar".
- Toggle "Subir cada PDF a Joplin como adjunto".

## Tests

`Tests/AstroMalikTests/Reports/` cubre cada pieza:

- `TemplateEngineTests` — features Mustache, escape HTML, errores.
- `ReportRendererTests` — render de HTML mínimo a PDF, magic bytes "%PDF-".
- `ReportServiceTests` — render del layout con datos mock.
- `WheelSVGRendererTests` — viewBox correcto, glifos presentes, líneas de aspecto en el SVG.
- `NatalReportTests`, `SynastryReportTests`, `ExtendedNatalReportTests`, `HoraryReportTests`, `PredictiveReportBuilderTests`, `LongPredictiveReportTests`, `CrossPersonalReportTests` — un test por informe con la carta de referencia.
- `ReportPersistenceTests` — guardar, listar histórico, eliminar.
- `ReportTestSupport` — helpers compartidos.

## Roadmap

- **1.0**: 14 informes, infraestructura, integración UI, histórico.
- **1.1+ posible**: embeber WOFF2 reales (EB Garamond, Inter, Astrodot), generar libro PDF maestro que combine varios informes en un solo entregable, exportación adicional a EPUB para lectores e-reader, modo bilingüe (es/en).
