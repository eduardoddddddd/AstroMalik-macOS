# Arquitectura de AstroMalik-macOS

AstroMalik-macOS es una app nativa SwiftUI de ventana única para uso astrológico personal y profesional, sin cuentas ni telemetría. Desde la versión 1.0 cubre el ciclo completo de la astrología tradicional: análisis natal extendido, predictivas helenísticas y clásicas (profecciones, arco solar, progresiones, firdaria, Zodiacal Releasing, direcciones primarias), motor cross-personal con redacción Anthropic e informes PDF profesionales.

## Empaquetado

Desde 1.0 el `Package.swift` tiene tres targets:

- **`AstroMalik`** — módulo compartido con motores, modelos, vistas y servicios. Es lo que importan tanto la GUI como el CLI.
- **`AstroMalikApp`** — ejecutable GUI de doble clic; wrapper mínimo sobre `AstroMalik`.
- **`astromalik-cli`** — ejecutable headless para LaunchAgent y cron; importa `AstroMalik` sin SwiftUI.

Ningún paquete Swift externo. Solo el módulo C `CSwissEph` (Swiss Ephemeris embebido) y SQLite3 del sistema.

## Ventana única

La app usa un solo `WindowGroup` con `NavigationSplitView`. La sidebar está organizada por flujo de trabajo del astrólogo en seis secciones; el panel derecho contiene el flujo activo:

- **Carta Natal** — Nueva Carta · Cartas Guardadas · Lectura · Rectificación
- **Predictivas** — Tránsitos · Progresiones · Direcciones Primarias (· Arco Solar) · Profecciones · Firdaria · Zodiacal Releasing
- **Retornos** — Revolución Solar · Revolución Lunar
- **Síntesis** — Panorama Predictivo *(síntesis cross-personal; resaltada como culminación)*
- **Sinastría y Horaria** — Sinastría · Horaria
- **Herramientas** — Efemérides · Informes (PDFs generados) · Ajustes

`NavItem` separa identidad estable (`rawValue`) de texto visible (`label`), por lo que renombrar etiquetas no afecta la navegación. El orden y la agrupación se definen en las `Section` de `ContentView`; el enrutado real (`DetailRoute`) y `showDefaultDetail` son independientes de cómo se presenta el sidebar.

Las cartas y consultas se abren dentro del detalle principal. El estado vivo queda en `AppState`.

## Rectificación natal

`RectificationEngine` ejecuta un flujo local-first en dos pasadas. `RectificationCandidateGenerator` explora primero el rango con paso grueso, selecciona centros distintos y refina únicamente esas zonas respetando los límites civiles y DST. Los scorers de arco solar, tránsitos angulares, direcciones primarias y progresiones producen `RectificationEvidence`; el motor conserva la evidencia más fuerte por evento/técnica, añade bonificación limitada por confirmación y evita que una candidata gane solo por acumular contactos genéricos.

`RectificationViewModel` aporta progreso, cancelación y guardado seguro. La carta rectificada se crea con UUID nuevo y metadatos de procedencia; la carta original nunca se sobrescribe. La narrativa LLM no forma parte del cálculo y queda como capa opcional posterior.

La capa opcional usa `UnifiedLLMService` con adaptadores Anthropic/OpenRouter. `RectificationNarrativeBuilder` serializa únicamente un payload v1 compacto (eventos, top candidatas, scores y evidencias; nunca la carta completa) y aplica `rectification_prompt.md`, que prohíbe recalcular o inventar datos. La llamada solo se produce al pulsar la acción explícita de IA después de disponer del resultado determinista.

`RectificationSessionStore` persiste en `user.db` el contrato completo de sesión, el último resultado y la narrativa opcional. Cada recálculo distinto genera una versión inmutable; los guardados repetidos del mismo resultado se deduplican. El archivo JSON usa un sobre versionado para intercambio y recuperación. `RectificationReportBuilder` crea el HTML autocontenido que WebKit convierte a PDF, mientras `RectificationNoteBuilder` genera Markdown para Joplin; ambas salidas conservan candidatas, evidencias, advertencias y trazabilidad LLM. Joplin solo se invoca desde una acción explícita de la vista.

## Estado de aplicación

`AppState` mantiene navegación, tema, configuración de Joplin, carta natal activa y estado persistente de tránsitos. `UserStore` y `HoraryStore` publican datos desde `user.db`.

El archivo de cartas admite metadatos locales: notas por carta, etiquetas, búsqueda por nombre, fecha, lugar, etiqueta o nota.

Joplin sigue siendo destino documental de salida. Sinastría, Revolución Solar, Revolución Lunar, Efemérides, Direcciones Primarias, Profecciones, Firdaria, ZR y Cross-personal crean notas directas mediante Web Clipper local.

## Motores astronómicos base

`AstroEngine` usa Swiss Ephemeris embebido como target C. Las casas se calculan con `swe_houses_ex2`. La hora local IANA se convierte a JD UT en `JulianDay.swift`. Los errores de fecha/hora/zona se propagan como `LocalizedError`.

`EssentialDignityEngine` aplica dignidades tradicionales con triplicidad sensible a la secta y cooperante.

`SectEngine` es el resolutor compartido de secta diurna/nocturna. Calcula luminaria, benéfico, maléfico y contrarios. Lo usan todos los módulos que necesitan asignar benéficos/maléficos: Firdaria, ZR, Almuten Figuris, lotes helenísticos, regente de la geniture y, en revisión, los motores antiguos que duplicaban la regla.

## Sinastría

`AstroEngine.computeSynastryAspects(chartA:chartB:)` calcula aspectos de los 10 planetas en ambas direcciones. Claves `SYN_<A>_<B>_<ASPECTO>`. Corpus de 420 textos. Vista con dos pickers, rueda doble y filtros.

## Revoluciones

`SolarReturnEngine` calcula retorno exacto del Sol con `swe_solcross_ut`. `LunarReturnEngine` calcula retornos sucesivos de la Luna con `swe_mooncross_ut`. Ambos resultan en cartas levantadas para la localidad del usuario en el evento.

## Tránsitos

`TransitEngine` calcula eventos por rango de fechas con orbes propios separados de los natales. Nodo Norte, Nodo Sur y Eje Nodal fusionado. Scoring por banda de prioridad (low/medium/high/critical) cruzando puntuación técnica, relevancia personal y impacto temporal. Timeline con muestras diarias. Ingresos por casa abren en modal independiente.

Documento técnico: [`TRANSITOS_ESTRUCTURA_Y_FUNCIONAMIENTO.md`](TRANSITOS_ESTRUCTURA_Y_FUNCIONAMIENTO.md).

## Calendario y efemérides

`Ephemeris/` contiene calculadores puros sobre Swiss Ephemeris: lunaciones, eclipses, estaciones, ingresos en signo, Luna vacía de curso, aspectos mundanos. `EphemerisEngine.computeMonth(...)` orquesta. La tabla diaria usa 00:00 UTC con 10 planetas y Nodo Norte verdadero.

`MonthlySummaryEngine` cruza el `EphemerisMonth` con una carta natal para producir el resumen predictivo mensual.

Documento técnico: [`CALENDARIO_EFEMERIDES_ARQUITECTURA.md`](CALENDARIO_EFEMERIDES_ARQUITECTURA.md).

## Profecciones

`ProfectionEngine` aplica profecciones helenísticas **en signos enteros desde el Ascendente**: casa anual `((age mod 12) + 1)`, Lord of the Year igual al regente domicilio del signo profeccionado. Sub-profecciones mensuales (12 partes del año tropical) y diarias (28 días por casa).

Las activaciones del año se calculan reutilizando `TransitEngine`: tránsitos del LotY a planetas natales y tránsitos al LotY natal, ordenados por banda de prioridad y orbe.

## Arco solar

`SolarArcEngine` produce direcciones por arco solar. Modos:

- **Real**: arco = Sol progresado (1 día = 1 año) menos Sol natal.
- **Naibod**: constante 0°59'08.33"/año.

Las direcciones se calculan sumando el arco a la longitud natal del punto dirigido (10 planetas + ASC + MC + DSC + IC) y detectando aspectos sobre los puntos natales. Sistema de pesos compartido con `PrimaryDirectionCalculator`. Bisección para resolver la edad exacta en modo real.

Se integra como pestaña hermana de Direcciones Primarias.

## Progresiones secundarias

`SecondaryProgressionEngine` aplica el día por año (1 día tras nacimiento = 1 año de vida). Calcula longitudes y declinaciones de los 10 planetas + Nodo Norte verdadero al JD progresado.

MC y ASC progresados en dos modos:

- **Naibod**: RAMC progresado = RAMC natal + (años × 0°59'08.33"). Casas recalculadas con `swe_houses_armc_ex2` para la latitud natal.
- **Bija**: ángulos avanzan solidariamente con el Sol progresado.

Detecta aspectos progresado → natal y progresado → progresado con bisección al instante exacto. Orbe de 0.5° para Luna progresada por su velocidad, 1° para el resto. Reporta fase lunar progresada (8 fases), ingresos de la Luna progresada por signo y casa, estaciones progresadas en los planetas ±5 años, transiciones de fase lunar próximas.

## Firdaria

`FirdariaEngine` aplica el sistema persa (Abu Maʿshar / Bonatti) con ciclo de 75 años:

- Diurno: Sol 10, Venus 8, Mercurio 13, Luna 9, Saturno 11, Júpiter 12, Marte 7, NN 3, NS 2.
- Nocturno: Luna 9, Saturno 11, Júpiter 12, Marte 7, Sol 10, Venus 8, Mercurio 13, NN 3, NS 2.

Tras los 75 años el ciclo se reinicia. Cada período mayor no-nodal se subdivide en 7 firdar menores de reparto equitativo (tradición Bonatti); los nodos no tienen sub-períodos. Reusa `SectEngine`.

## Zodiacal Releasing

`ZodiacalReleasingEngine` aplica el ZR de Vettius Valens sobre los lotes de Espíritu y Fortuna calculados por `HellenisticLots` (con inversión día/noche).

Períodos por signo (años para L1; meses para L2 con mes escolar de 30 días): Aries 15, Tauro 8, Géminis 20, Cáncer 25, Leo 19, Virgo 20, Libra 8, Escorpio 15, Sagitario 12, Capricornio 27, Acuario 30, Piscis 12.

Regla doctrinal del **Loosing of the Bond**: cuando un L2 entra en Cáncer o Capricornio y no es el último del L1, al terminarlo el siguiente L2 salta al signo opuesto al inicio del L1 (convención Schmidt). Tras el LB el ciclo continúa zodiacalmente desde el opuesto.

**Peaks**: L2 angulares al signo del L1 (offset módulo 3 = 0).

Vista con capítulos L1 + L2 y eventos destacados (cambios de L1, LB próximos, peaks vigentes).

## Análisis natal extendido

`NatalExtendedAnalysis.compute(chart:)` orquesta nueve subsistemas que viven en `Sources/AstroMalik/Engine/Extended/`:

- **`LotsEngine`** — siete lotes: Fortuna, Espíritu, Eros, Necesidad, Victoria, Audacia, Némesis. Fórmulas helenísticas con inversión día/noche y cálculo de regente del signo del lote.
- **`AlmutenFigurisEngine`** — almuten figuris (Ibn Ezra) sobre Sol, Luna, ASC, Lote de Fortuna y sicigia prenatal. Sicigia detectada por bisección a la última lunación (nueva o llena) anterior al nacimiento. Bonificaciones Lilly +12 por regente del día (calendario semanal), regente de la hora planetaria (orden caldeo con horas desiguales calculadas con `swe_rise_trans`) y orientalidad (superiores orientales, inferiores occidentales, Luna creciente).
- **`AspectPatternEngine`** — detección de T-cuadrada, gran trígono (mismo elemento), yod (sextil + dos quincuncios), gran cruz, kite y rectángulo místico. Orbe configurable (default 6°).
- **`DistributionEngine`** — distribución de planetas por elemento, modalidad, hemisferio y cuadrante. Singletons.
- **`ReceptionEngine`** — recepciones mutuas: domicilio, exaltación, mixtas.
- **`AntisciaEngine`** — antiscia y contraantiscia sobre el eje solsticial 0° Cáncer / 0° Capricornio.
- **`DeclinationEngine`** — declinaciones de los 10 planetas + nodos, paralelos, contraparalelos y planetas fuera de límites (|δ| > 23°26').
- **`FixedStarsEngine`** — catálogo de estrellas fijas en `fixed_stars.json` con coordenadas J2000, precesión simple aplicada a la fecha natal (50.29"/año). Contactos sobre los 10 planetas, ASC, MC y Lote de Fortuna.
- **Regente de la geniture** (calculado en el orquestador) — domicilio del signo de la luminaria de secta, con sus dignidades esenciales sobre la luminaria.

## Cross-personal

El sintetizador es la corona del proyecto. Detalle propio en [`CROSS_PERSONAL.md`](CROSS_PERSONAL.md).

Resumen:

- **`CrossPersonalEngine`** — puro, determinista, sin Swiss Ephemeris ni disco. Consume `CrossPersonalInputs` (un struct con resultados pre-calculados de todos los engines) y produce un `CrossPersonalState` con cuatro capas temporales: `annual`, `mediumTerm`, `shortTerm`, `lunar`. Cada capa contiene `signals` con subject primario (planeta, casa, signo, lote o eje), peso y metadatos.
- **`CrossPersonalAssembler`** — orquestador con efectos: invoca los engines reales, calcula la profección, RS, direcciones, arco solar, progresiones, firdaria, ZR y tránsitos lentos sobre puntos sensibles, y rellena los inputs del engine.
- **Cola de prioridad** — el engine agrupa signals por subject y aplica scoring: `Σ(weight × layerWeight) × convergenceMultiplier` con bonificaciones para Lord of the Year, luminaria de secta, regente de la geniture y coincidencia con el signo del peak L2 vigente.
- **Vista** `CrossPersonalView` con selector de capas, top topics, exportación a Joplin y, si la API key Anthropic está configurada, botón de generación de informe redactado.

## Anthropic

Cliente Messages API con prompt caching y resolución de API key vía Keychain o variable de entorno. Detalle propio en [`ANTHROPIC_INTEGRATION.md`](ANTHROPIC_INTEGRATION.md).

`AnthropicClient` es un `actor`. `CrossPersonalNarrativeBuilder` serializa el `CrossPersonalState` a JSON snake_case y lo envía con el prompt en español. Pricing y trazabilidad por llamada para Sonnet 4.6, Opus 4.7 y Haiku 4.5.

## Direcciones Primarias

`PrimaryDirectionCalculator` implementa proyección Regiomontana, direcciones directas y conversas, claves Naibod / Ptolomeo / Brahe, plano zodiacal y modo eclíptico de compatibilidad. `PrimaryDirectionsService` orquesta cálculo, corpus, interpretación contextual y note builder.

Corpus clásico de 165 textos basado en Lilly, *Christian Astrology*, Libro III. Migraciones idempotentes vía `MigrationRunner`.

Documento técnico: [`PRIMARY_DIRECTIONS.md`](PRIMARY_DIRECTIONS.md).

## Horaria

Horaria es nativa en Swift por defecto. `HoraryNativeEngine` calcula siete planetas tradicionales, Nodo Norte verdadero, casas Regiomontanus, Partes de Fortuna y Espíritu, hora planetaria, radicalidad, dignidades, vía combusta, Luna fuera de curso, significadores, recepción, perfección directa, translación y colección.

La regla doctrinal crítica es que una perfección lunar solo cuenta si el aspecto exacto ocurre antes de que la Luna salga de signo.

`HoraryEngine` mantiene el motor Python legado seleccionable por variable de entorno `ASTROMALIK_HORARIA_ENGINE`.

Documento técnico: [`HORARY_NATIVE.md`](HORARY_NATIVE.md).

## Informes PDF

Infraestructura HTML+CSS → WKWebView → PDF. Detalle propio en [`PDF_REPORTS.md`](PDF_REPORTS.md).

- `ReportRenderer` actor con `WKWebView.createPDF` y configuración de página.
- `TemplateEngine` Mustache-like con dot-access, `each`, `if`, `unless`, `partial` y escape HTML por defecto. Sin dependencias.
- `ReportTheme` con paleta marfil/tinta/azul noche/dorado, tipografías EB Garamond serif + Inter sans + glifos astrológicos.
- 14 informes con plantillas en `Resources/Reports/templates/` y builders en `Reports/Builders/`.
- Renderers SVG en `Reports/Charts/`: rueda natal con lanes anti-solapamiento, rueda doble, timelines de tránsitos / ZR / Firdaria, tabla de efemérides.
- Informe **cross-personal** combina narrativa Anthropic dividida por encabezado con datos del state como tablas de apoyo.
- `ReportPersistence` mantiene carpeta configurable y vista "Mis informes" lista los PDFs generados.

## CLI

Binario `astromalik-cli` headless. Detalle propio en [`CLI.md`](CLI.md).

`Sources/AstroMalikCLI/main.swift` con parser manual de argumentos (sin Swift Argument Parser). Lee carta de `user.db`, ejecuta `CrossPersonalAssembler` + `CrossPersonalEngine` + `CrossPersonalNarrativeBuilder` y vuelca markdown a `stdout`, `file:/ruta.md` o `joplin:Notebook`.

LaunchAgent recipes en `scripts/launchagents/` para programación semanal y mensual.

## UI de lectura

`NatalChartView` ofrece tres modos: rueda interactiva, Lectura natal como documento continuo y Análisis extendido. En modo Lectura se oculta el panel técnico izquierdo para dar todo el ancho al texto. La lectura se compone con `NatalReadingComposer` desde la carta, el corpus y opcionalmente `NatalExtendedAnalysisResult`; `ReadingRelevance` rankea aspectos/dominantes y `ChartDistribution` cubre temperamento, secta, hemisferios y stelliums. `NatalReadingView` integra navegación compacta por capítulos, densidad Esencial/Completa, buscador de corpus y síntesis autosalvada en `ReadingNotesStore` dentro de `user.db`. `ReadingNoteBuilder` serializa el mismo `NatalReading` a Markdown para Joplin.

## Joplin

`JoplinClipperService` usa `URLSession` contra `127.0.0.1:41184`. Host, puerto, token y cuaderno viven en `AppState.joplinSettings`. Si el token está vacío, se resuelve desde `ASTROMALIK_JOPLIN_TOKEN` o desde los settings locales de Joplin Desktop (`api.token`). Si el cuaderno no existe, se crea.

Caminos de salida actuales: natal (markdown copy/paste), sinastría, revolución solar, revolución lunar, efemérides, resumen mensual, profecciones, direcciones primarias, arco solar, progresiones, firdaria, ZR, cross-personal y los 14 informes PDF (opcionalmente como adjuntos).

## Build y distribución

Swift Package Manager puro. Para desarrollo:

```bash
swift build
.build/arm64-apple-macosx/debug/AstroMalikApp
```

Para el CLI:

```bash
swift build --product astromalik-cli
.build/arm64-apple-macosx/debug/astromalik-cli --help
```

Para app de doble clic:

```bash
./scripts/package_app.sh
open AstroMalik.app
```

El script compila release, crea el bundle, copia recursos, firma ad-hoc y elimina cuarentena.

## Validación

La suite cubre los engines de los 10 bloques de 1.0:

- carta natal de referencia y `swe_houses_ex2`
- corpus de sinastría y motor en ambas direcciones
- revoluciones solar y lunar
- tránsitos: rangos, cancelación, muestras diarias de intensidad, nodos
- efemérides mensual y resumen predictivo mensual
- profecciones: whole sign desde el ASC, activaciones del año
- arco solar: real y Naibod, bisección de edad exacta
- progresiones secundarias: aspectos prog→natal y prog→prog, fase lunar progresada, ingresos
- firdaria: orden y reinicio del ciclo
- sect: diurnal vs nocturnal
- zodiacal releasing: L1 + L2, LB, peaks
- análisis natal extendido: nueve subsistemas con carta de referencia
- cross-personal: scoring de convergencia, top topics, bonificaciones
- Anthropic client: prompt caching, pricing, mapeo de errores
- narrative builder: serialización, secciones por encabezado, modos
- CLI parser y resolutor de destinos
- reports infrastructure: template engine, renderer, service, builders, persistence

Sanity check histórico: carta natal de referencia `1976-10-11 20:33 Europe/Madrid`.
