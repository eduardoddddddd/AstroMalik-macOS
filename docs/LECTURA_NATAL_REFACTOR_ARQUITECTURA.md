# Refactor del Modo "Lectura" Natal — Arquitectura y Plan Codex

**Proyecto:** AstroMalik-macOS
**Autor:** Claude (Anthropic) — rol: Arquitecto SW + Astrólogo
**Fecha:** 10 de junio de 2026
**Alcance:** Rediseño completo del modo Lectura de la carta natal: diagnóstico del estado actual, modelo doctrinal de lectura, motor de composición, vistas SwiftUI, persistencia de síntesis, integración y prompts Codex por sprint.

---

## 1. Diagnóstico del estado actual (tras inspección del código)

### 1.1 Qué hay hoy

`NatalChartView` ofrece 4 modos: **Rueda | Lectura | Análisis extendido | Textos**.

- **`GuidedReadingView` (Lectura):** cuatro tarjetas (Tríada base, Regente del ASC, Casas angulares, Aspectos dominantes) cuyas filas son `Button` que solo mutan `selectedFocusKey`. Ese binding **únicamente lo consume la pestaña Rueda**: pulsar en Lectura no produce ningún efecto visible. Los textos del corpus **no se muestran en Lectura** — como mucho aparece un icono `text.alignleft` que indica "hay texto", pero el texto está en otra pestaña. Al final, un `TextEditor` de síntesis **no persistido** (`@State synthesis = ""`): se pierde al salir de la vista.
- **`InterpretacionesView` (Textos):** lista plana de filas colapsadas con chevron (el "desplegable absurdo"). Para leer 30 textos hay que hacer 30 clics. Sin orden doctrinal (el orden es el del corpus), sin jerarquía de importancia, sin contexto técnico (no muestra posición/casa/orbe junto al texto), sin tipografía de lectura.

### 1.2 Diagnóstico de fondo

1. **La Lectura es un índice sin contenido.** Es navegación pura sobre datos que ya están en el panel izquierdo. No es una lectura: no se puede *leer* nada en el modo Lectura.
2. **Los textos son un almacén sin lectura.** El modo Textos es un volcado del corpus con UI de acordeón. El corpus es bueno (es el activo del proyecto) pero la presentación lo destruye: leer una carta requiere abrir cada ficha a mano y reconstruir mentalmente el orden.
3. **Datos y texto viven separados.** El astrólogo necesita ver "Sol en Capricornio, casa 10, dignidad X" *junto* al texto interpretativo, no en paneles distintos.
4. **No hay capa de síntesis automática en Lectura** pese a que `NatalExtendedAnalysisResult` ya calcula distribución elemental/modal, almutén, patrones de aspecto, recepciones, etc. La Lectura ignora todo eso.
5. **Sin jerarquía de relevancia.** Un trígono Venus–Neptuno de orbe 6° aparece con el mismo peso que una cuadratura Sol–Saturno partil.
6. **La síntesis manual se pierde** (no persiste) y la nota Joplin (`ReadingNoteBuilder`) no refleja la lectura real: solo ASC/SOL/LUNA con `prefix(2)`.

### 1.3 Principio rector del refactor

> **La Lectura debe ser un documento, no un panel de control.**

Una lectura natal real es un texto continuo con arco narrativo: temperamento → quién es (tríada) → cómo se gobierna (regente) → qué domina (dominantes) → dónde vive la energía (casas) → qué tensiones estructuran la vida (aspectos) → síntesis. El refactor convierte el modo Lectura en exactamente eso: **un documento generado determinísticamente, legible de arriba abajo, sin un solo desplegable**, con los datos técnicos integrados como apoyos visuales (chips) y los textos del corpus siempre visibles, ordenados por doctrina y relevancia.

Consecuencia estructural: **el modo "Textos" desaparece como pestaña**. Su función (consultar el corpus crudo) queda cubierta por un buscador opcional dentro de Lectura. `NatalDetailMode` queda en: `Rueda | Lectura | Análisis extendido`.

---

## 2. Modelo doctrinal de la Lectura (especificación astrológica)

La lectura se compone de **capítulos** en orden fijo. Cada capítulo combina hechos calculados (determinismo del motor) + textos del corpus (siempre visibles) + en algunos casos una frase-puente generada por plantilla en español (mismo patrón que `RevolutionTemplates`).

### Capítulo 0 — Retrato inmediato (lead)
La primera pantalla responde "¿qué carta es esta?" en 10 segundos.
- **Temperamento:** balance elemental y modal (de `NatalExtendedAnalysisResult.distribution`; si no está calculado, el composer lo calcula localmente: es un conteo trivial). Frase por plantilla: "Carta de dominante fuego-cardinal: temperamento colérico, iniciativa antes que persistencia…". Plantillas por combinación dominante (elemento × modalidad) + casos de carencia ("ausencia de tierra…").
- **Secta:** diurna/nocturna y su luminar regente.
- **Hemisferios:** oriental/occidental, sobre/bajo horizonte (frase corta).
- **Stellium** si existe (3+ planetas en mismo signo o casa).
- Chips técnicos: 🔥3 🜃1 🜁4 🜄2 · Cardinal 5 / Fijo 3 / Mutable 2 · Diurna · ASC ♑.

### Capítulo 1 — La tríada
Sol, Luna, Ascendente. Para cada uno: cabecera con posición, casa, dignidad esencial (de `EssentialDignityEngine`), retrogradación; debajo, **texto completo** del corpus planeta-en-signo seguido del de planeta-en-casa, fusionados en un bloque de lectura continua con la fuente citada al pie. Sin chevrons.

### Capítulo 2 — El regente del Ascendente
Regencia clásica (la tabla ya existe en `GuidedReadingView.rulerForAscendant`; se extrae al composer). Posición, signo, casa, dignidad, dispositor. Frase-puente por plantilla: "La vida se gobierna desde la casa N…". Textos del corpus del regente (signo + casa). Si hay recepción mutua con otro planeta (ya calculada en extended), mencionarla.

### Capítulo 3 — Dominantes de la carta
- **Almutén Figuris** (reutilizar `AlmutenFigurisResult` si el análisis extendido está disponible; si no, omitir el bloque, no recalcular).
- **Planeta más angular y digno:** scoring propio del composer (ver §4.3).
- Texto del corpus del dominante si difiere de la tríada.

### Capítulo 4 — Aspectos estructurales
Los aspectos natales **rankeados por relevancia** (no por orbe bruto):
- Los **5–7 primeros** se muestran como bloques de lectura: cabecera "☉ Sol □ Saturno ♄ · orbe 1°12' · aplicativo" + **texto completo** del corpus del aspecto.
- El resto aparece como **lista compacta de una línea** al final del capítulo (visible, no plegada): glifos + orbe. Quien quiere el texto de un aspecto menor lo toca y se navega al ancla de ese aspecto en modo "Lectura completa" (ver §5.3).

### Capítulo 5 — Las casas: áreas de vida
Recorrido por casas con planetas, en orden angular → sucedente → cadente:
- Casas angulares (1, 10, 7, 4) con planetas: bloque con texto completo planeta-en-casa.
- Resto de casas ocupadas: cabecera + texto en cuerpo normal.
- Casas vacías: una sola línea agrupada al final ("Casas vacías: 2, 6, 8, 11 — sus asuntos se leen por su regente"), con el regente de cada una y su casa.

### Capítulo 6 — Síntesis
- **Borrador automático:** el composer genera 4–6 viñetas de hechos duros ("Dominante fuego-cardinal", "Sol angular en 10 con dignidad X", "Cuadratura partil Sol–Saturno", "Regente del ASC en 12") como punto de partida.
- **Editor persistente:** `TextEditor` cuya nota se guarda por carta (`chart.id`) — ver §6. Se precarga con el borrador la primera vez; después manda lo del usuario.

### Decisiones doctrinales del capítulo de lectura

| Decisión | Elección | Justificación |
|---|---|---|
| Regencias | Clásicas (coherente con el proyecto) | Ya establecido en RS y horaria |
| Dignidades en cabeceras | Esenciales de `EssentialDignityEngine`, con secta para triplicidad si la API lo permite | Coherencia con extended |
| Aspectos | Solo ptolemaicos | Doctrina del proyecto |
| Orden de capítulos | Fijo, no configurable en v1 | La lectura es un método, no un dashboard |
| Plantillas-puente | Español, determinhoras, mismo estilo que `RevolutionTemplates` | Nada de LLM en el motor |

---

## 3. Arquitectura Swift

```
Sources/AstroMalik/
├── Engine/
│   └── Reading/
│       ├── NatalReadingComposer.swift     ← Motor puro: chart + corpus (+extended opcional) → NatalReading
│       ├── ReadingRelevance.swift         ← Scoring de aspectos y planetas
│       ├── ReadingTemplates.swift         ← Frases-puente en español (temperamento, regente, casas vacías)
│       └── ChartDistribution.swift        ← Balance elemental/modal/hemisferios (si no existe ya reutilizable desde Extended)
├── Models/
│   └── NatalReading.swift                 ← Documento de lectura (capítulos y bloques)
├── Views/
│   └── Reading/
│       ├── NatalReadingView.swift         ← Sustituye a GuidedReadingView
│       ├── ReadingChapterView.swift
│       ├── ReadingBlockView.swift         ← Render de cada tipo de bloque
│       ├── ReadingTOCView.swift           ← Índice lateral con anclas
│       └── ReadingTypography.swift        ← Estilos de lectura (modificadores)
├── Persistence/
│   └── ReadingNotesStore.swift            ← Síntesis editable persistida por carta
```

Se **eliminan**: `GuidedReadingView.swift`, `InterpretacionesView.swift` (y el caso `.texts` de `NatalDetailMode`). `ReadingNoteBuilder` se reescribe sobre `NatalReading`.

### 3.1 Modelos

```swift
// MARK: - NatalReading.swift

/// Documento de lectura natal, generado determinísticamente.
struct NatalReading: Equatable {
    let chartId: String
    let chapters: [ReadingChapter]
    let synthesisDraft: [String]          // viñetas del borrador automático
}

struct ReadingChapter: Identifiable, Equatable {
    let id: ReadingChapterKind            // ancla para el TOC
    let title: String                     // "La tríada", "Aspectos estructurales"…
    let subtitle: String?
    let blocks: [ReadingBlock]
}

enum ReadingChapterKind: String, CaseIterable {
    case portrait, triad, ascRuler, dominants, aspects, houses, synthesis
}

struct ReadingBlock: Identifiable, Equatable {
    let id: String                        // estable: "triad.SOL", "aspect.SOL_SATURNO_CUADRATURA"
    let kind: ReadingBlockKind
    let emphasis: ReadingEmphasis
}

enum ReadingBlockKind: Equatable {
    /// Frase-puente generada por plantilla (lead del capítulo o transición).
    case lead(text: String)
    /// Cabecera técnica de un punto: nombre, posición, casa, dignidad, retro.
    case pointHeader(PointHeaderData)
    /// Texto del corpus, siempre visible. Puede concatenar signo+casa.
    case corpus(title: String?, paragraphs: [String], source: String)
    /// Fila de chips técnicos (elementos, modalidades, secta…).
    case chips([ReadingChip])
    /// Línea de aspecto compacta (para los no estructurales).
    case aspectLine(AspectLineData)
    /// Lista agrupada (casas vacías y sus regentes).
    case groupedList(title: String, items: [String])
}

enum ReadingEmphasis: Int, Comparable { case secondary = 0, normal = 1, primary = 2
    static func < (l: Self, r: Self) -> Bool { l.rawValue < r.rawValue } }

struct PointHeaderData: Equatable {
    let key: String                       // "SOL" — para enfocar la rueda
    let title: String                     // "Sol en Capricornio"
    let detail: String                    // "♑ 14°22' · Casa 10 · Exaltación de Marte… "
    let badges: [String]                  // ["Angular", "℞", "Domicilio"]
}

struct ReadingChip: Equatable { let label: String; let value: String; let tint: ChipTint
    enum ChipTint { case fire, earth, air, water, neutral, accent } }

struct AspectLineData: Equatable {
    let id: String
    let text: String                      // "☿ Mercurio △ ♃ Júpiter · 3°41'"
    let score: Double
}
```

### 3.2 Motor — NatalReadingComposer

```swift
enum NatalReadingComposer {
    struct Input {
        let chart: NatalChart
        let interpretations: [Interpretation]
        let extended: NatalExtendedAnalysisResult?   // opcional: si está, enriquece
        let mode: ReadingDensity                     // .essential / .complete
    }

    enum ReadingDensity { case essential, complete }

    /// Función pura, síncrona, determinista. Sin Swiss Ephemeris:
    /// todo lo astronómico ya está en NatalChart / extended.
    static func compose(_ input: Input) -> NatalReading
}
```

Reglas duras del composer:
- **Puro y testeable**: misma entrada → mismo documento. Sin acceso a stores, sin async, sin C.
- **No recalcula astronomía** (principio ya establecido en el proyecto): consume `NatalChart`, `computeNatalAspects` (que es geometría sobre longitudes ya calculadas) y, si llega, `NatalExtendedAnalysisResult`.
- **Lookup del corpus robusto**: hoy se hace con `hasPrefix("\(key)_")`/`contains("_\(key)_")` (frágil). El composer indexa las `Interpretation` por `(tipo, clave)` con claves normalizadas y resuelve explícitamente `PLANETA_SIGNO`, `PLANETA_CASA_N`, `A_ASPECTO_B`. Si un texto no existe, el bloque se omite y se registra en `NatalReading` un hueco (`missingKeys`) útil para auditar el corpus.
- La tabla de regencias del ASC **se mueve aquí** desde la vista (las vistas no contienen doctrina).

### 3.3 ReadingRelevance — scoring de aspectos y dominantes

```swift
enum ReadingRelevance {
    /// Puntúa un aspecto natal para decidir si es "estructural".
    /// Factores (aditivos, documentados):
    ///  +3 si involucra Sol o Luna; +2 si involucra regente del ASC
    ///  +2 si alguno de los dos es angular (casas 1,4,7,10)
    ///  +2 si orbe <= 1° (partil); +1 si <= 3°
    ///  +1 conjunción/oposición/cuadratura (aspectos mayores duros estructuran)
    ///  +1 si involucra al almutén (cuando extended disponible)
    static func aspectScore(_ a: NatalAspect, chart: NatalChart, extended: NatalExtendedAnalysisResult?) -> Double

    /// Planeta dominante: angularidad (3/2/1/0) + dignidad esencial (escala
    /// del EssentialDignityEngine) + nº de aspectos a luminarias.
    static func dominantPlanet(chart: NatalChart, extended: NatalExtendedAnalysisResult?) -> String?
}
```

Umbral v1: estructurales = top N por score con N = 5 en `.essential`, 8 en `.complete`, siempre incluyendo cualquier partil a luminaria.

---

## 4. Vistas — especificación UI

### 4.1 NatalReadingView (sustituye a GuidedReadingView)

Layout de **documento con índice**:

```
┌────────────┬──────────────────────────────────────────┐
│ ÍNDICE     │  (columna de texto, ancho máx ~720pt)    │
│ ● Retrato  │  RETRATO INMEDIATO                       │
│ ○ Tríada   │  Carta diurna de dominante fuego…        │
│ ○ Regente  │  [🔥3] [🜃1] [🜁4] [🜄2] [Cardinal 5]…   │
│ ○ Dominan. │                                          │
│ ○ Aspectos │  LA TRÍADA                               │
│ ○ Casas    │  ☉ Sol en Capricornio                    │
│ ○ Síntesis │  ♑ 14°22' · Casa 10 · [Angular]          │
│            │  «Texto del corpus completo, visible,    │
│ [Esencial⇄ │   párrafos con lineSpacing…»             │
│  Completa] │   — Fuente                                │
└────────────┴──────────────────────────────────────────┘
```

- **TOC lateral** (`ReadingTOCView`, ~180pt): un botón por capítulo; `ScrollViewReader` + `scrollTo(chapter.id)` para saltar; resaltado del capítulo visible vía preferencias de scroll (v1 puede resaltar solo el último pulsado).
- **Columna de lectura**: `ScrollView` único, `frame(maxWidth: 720)` centrado. **Cero `DisclosureGroup`, cero chevrons, cero `lineLimit`** en textos de corpus.
- **Tipografía de lectura** (`ReadingTypography`): títulos de capítulo `.title3.weight(.semibold)` con espaciado superior generoso (28pt); cuerpo `.body` con `lineSpacing(5)`; fuente del corpus en `.footnote` gris al pie del bloque; cabeceras técnicas con dígitos monoespaciados. Nada de tarjetas anidadas: el documento usa separación tipográfica, no cajas. Las cajas (`appCard`) quedan solo para chips del retrato y para el editor de síntesis.
- **Interacción con la rueda conservada**: pulsar un `pointHeader` sigue actualizando `selectedFocusKey` (binding existente) — útil al volver a la pestaña Rueda — pero ya no es la función principal.
- **Toggle de densidad** `Esencial | Completa` (segmented, en la cabecera del documento): conmuta `ReadingDensity` y recompone. *Esencial* = capítulos 0–4 con top de aspectos y solo casas angulares en bloque; *Completa* = todo el corpus disponible ordenado (sustituye al antiguo modo Textos, pero ya ordenado y legible).
- **Buscador de corpus** (sustituto del valor residual de Textos): campo de búsqueda en la cabecera; al escribir, filtra bloques `corpus` resaltando coincidencias. Sin pestaña aparte.

### 4.2 ReadingBlockView

`switch block.kind`: render dedicado por tipo. El de `corpus` parte `texto` en párrafos por `\n\n` y los muestra completos. `aspectLine` es una fila de una línea con glifos y orbe monoespaciado. `groupedList` es una línea corrida con separadores `·`.

### 4.3 Estado y carga

`NatalReadingView` recibe `chart`, `interpretaciones` (ya cargadas por `NatalChartView`) y opcionalmente dispara el cálculo extendido en `.task` (reutilizando el mismo camino que `NatalExtendedAnalysisView`; si tarda, el documento se muestra primero sin almutén/distribución extendida y se recompone al llegar — el composer es barato). La composición en sí es síncrona y rápida (puro Swift sobre datos ya residentes).

---

## 5. Persistencia de la síntesis — ReadingNotesStore

Problema actual: `@State synthesis` se pierde. Solución mínima coherente con el proyecto (sin nuevas dependencias):

```swift
/// Notas de lectura por carta, persistidas como JSON en Application Support
/// (mismo directorio base que UserStore; inspeccionar patrón existente).
final class ReadingNotesStore: ObservableObject {
    struct ReadingNote: Codable { var chartId: String; var synthesis: String; var updatedAt: Date }
    func note(for chartId: String) -> ReadingNote?
    func save(_ note: ReadingNote) throws
}
```

- Autosave con debounce (~1 s tras dejar de teclear) + guardado en `onDisappear`.
- Si `UserStore` ya persiste cartas en SQLite/JSON, **Codex debe inspeccionar y usar el mismo mecanismo** (tabla/fichero junto a las cartas) en lugar de inventar otro.

### Nota Joplin (ReadingNoteBuilder v2)

El builder se reescribe como **serializador Markdown de `NatalReading`**: la nota es exactamente el documento que se ve en pantalla (WYSIWYG), capítulo a capítulo, con la síntesis del usuario al final. Un solo origen de verdad: el composer. Esto elimina la divergencia actual entre lo que se lee y lo que se exporta.

---

## 6. Integración

| Archivo | Cambio |
|---|---|
| `NatalChartView.swift` | `NatalDetailMode` pierde `.texts`; `.reading` monta `NatalReadingView`; pasa `interpretaciones` y `ReadingNotesStore` (vía `appState`) |
| `GuidedReadingView.swift` | **Eliminar** |
| `InterpretacionesView.swift` | **Eliminar** |
| `AstroMalikApp.swift` / `AppState` | Registrar `ReadingNotesStore` |
| `docs/ARCHITECTURE.md` | Sección "Lectura natal (composer)" |
| `HelpView.swift` | Actualizar referencias al modo Textos |

El PDF natal (`NatalReportBuilder`) **no se toca en este refactor**, pero queda anotado como siguiente paso natural: consumir `NatalReading` para que informe y pantalla cuenten la misma lectura.

---

## 7. Plan de sprints

### Sprint R1 — Motor (1 sesión Codex)
`NatalReading.swift`, `NatalReadingComposer`, `ReadingRelevance`, `ReadingTemplates`, `ChartDistribution` (o reutilización del cálculo de Extended), índice robusto del corpus + `missingKeys`. **Sin UI.** Tests.

### Sprint R2 — Documento UI (1–2 sesiones)
`NatalReadingView`, `ReadingChapterView`, `ReadingBlockView`, `ReadingTOCView`, `ReadingTypography`. Toggle densidad. Integración en `NatalChartView` (aún sin borrar Textos). Package.

### Sprint R3 — Síntesis persistente + nota + limpieza (1 sesión)
`ReadingNotesStore` con autosave, borrador automático, `ReadingNoteBuilder` v2, eliminación de `GuidedReadingView`/`InterpretacionesView`/`.texts`, buscador de corpus, docs. Package.

---

## 8. Tests

```
Tests/AstroMalikTests/ReadingTests/
├── NatalReadingComposerTests.swift
├── ReadingRelevanceTests.swift
└── ReadingNotesStoreTests.swift
```

- **Determinismo:** dos llamadas con el mismo input producen `NatalReading` iguales (Equatable).
- **Orden de capítulos:** siempre portrait→triad→ascRuler→dominants→aspects→houses→synthesis; capítulos sin datos se omiten sin romper el orden.
- **Tríada completa:** con un corpus fixture que cubre SOL/LUNA/ASC, el capítulo triad contiene 3 `pointHeader` y sus `corpus`.
- **Relevancia:** un aspecto partil Sol–Saturno con Sol angular puntúa por encima de un trígono Mercurio–Júpiter de 5°; los estructurales son ≤ N y todo partil a luminaria entra.
- **Distribución:** fixture con 4 planetas en fuego → chip de fuego correcto; carta sin tierra → plantilla de carencia presente.
- **Corpus faltante:** clave ausente → bloque omitido + clave en `missingKeys` (sin crash, sin texto vacío).
- **Regente del ASC:** los 12 signos → regente clásico correcto (tabla movida al composer).
- **Store:** guardar/recargar síntesis por `chartId`; debounce no pierde el último valor.

---

## 9. Prompts Codex

### Prompt maestro (anteponer a cada sprint)

```text
Trabajas en el repo AstroMalik-macOS. Antes de editar, inspecciona los modelos,
motores, vistas y tests existentes relacionados: NatalChartView.swift,
GuidedReadingView.swift, InterpretacionesView.swift, Models/Interpretation.swift,
CorpusStore (buildNatalInterpretations), AstroEngine.computeNatalAspects,
EssentialDignityEngine, NatalExtendedAnalysisView y sus modelos
(NatalExtendedAnalysisResult, distribución, almutén). No generes código aislado:
integra en la arquitectura actual.

Reglas del repo:
- Swift 6, macOS 14+, SwiftUI, SPM, sin dependencias externas.
- No usar force unwraps. UI de ventana única con NavigationSplitView.
- El composer de lectura es PURO: sin Swiss Ephemeris, sin async, sin stores.
- Las vistas no contienen doctrina astrológica (tablas de regencia, scoring, etc.
  viven en Engine/Reading).
- Añadir tests enfocados. Tras cambios de código/UI: `swift test` y
  `scripts/package_app.sh`; comprobar timestamp de
  AstroMalik.app/Contents/MacOS/AstroMalik.
- Actualizar docs/ARCHITECTURE.md al cerrar el último sprint.

Entrega: archivos modificados, decisiones, pruebas ejecutadas, limitaciones.
```

### Sprint R1 — Composer y relevancia

```text
Implementa el motor de Lectura Natal (NatalReadingComposer) según
docs/LECTURA_NATAL_REFACTOR_ARQUITECTURA.md, secciones 2–4.

Tareas:
1. Crear Sources/AstroMalik/Models/NatalReading.swift con NatalReading,
   ReadingChapter, ReadingChapterKind, ReadingBlock, ReadingBlockKind,
   ReadingEmphasis, PointHeaderData, ReadingChip, AspectLineData, y un campo
   missingKeys: [String] en NatalReading para auditoría del corpus.
   Todo Equatable; Codable solo si resulta gratuito.
2. Crear Sources/AstroMalik/Engine/Reading/ChartDistribution.swift:
   balance elemental, modal, hemisferios y stellium (3+ cuerpos en mismo
   signo o casa) a partir de NatalChart. Si NatalExtendedAnalysisResult ya
   expone una distribución equivalente, reutilizar su modelo y dejar esta
   utilidad como fallback documentado.
3. Crear Engine/Reading/ReadingTemplates.swift: frases-puente en español
   para (a) temperamento dominante elemento×modalidad y carencias,
   (b) secta, (c) regente del ASC por casa (12 entradas),
   (d) casas vacías. Estilo: el de RevolutionTemplates (conciso, doctrinal).
4. Crear Engine/Reading/ReadingRelevance.swift con aspectScore y
   dominantPlanet según la receta documentada (factores aditivos
   comentados uno a uno en el código).
5. Crear Engine/Reading/NatalReadingComposer.swift:
   - Input { chart, interpretations, extended?, mode (.essential/.complete) }.
   - Índice del corpus por (tipo, clave) normalizada; resolución explícita
     de claves PLANETA_SIGNO, PLANETA_CASA y aspecto. Inspeccionar las
     claves reales generadas por CorpusStore.buildNatalInterpretations
     antes de escribir el parser.
   - Mover aquí la tabla de regencias del ASC desde GuidedReadingView.
   - compose() construye los capítulos en el orden: portrait, triad,
     ascRuler, dominants, aspects, houses, synthesis(draft).
   - Aspectos: usar AstroEngine.computeNatalAspects una sola vez, rankear
     con ReadingRelevance; estructurales como corpus-block, resto como
     aspectLine ordenadas por score.
   - synthesisDraft: 4–6 viñetas de hechos duros.
6. Tests en Tests/AstroMalikTests/ReadingTests/ según sección 8 del doc
   (determinismo, orden, tríada, relevancia, distribución, missingKeys,
   regencias).
No crear UI. No tocar GuidedReadingView ni InterpretacionesView todavía.
```

### Sprint R2 — Documento UI

```text
Implementa la vista de Lectura Natal como documento continuo, según
docs/LECTURA_NATAL_REFACTOR_ARQUITECTURA.md, sección 4 (layout incluido).

Tareas:
1. Crear Views/Reading/ReadingTypography.swift con los modificadores
   tipográficos del documento (título de capítulo, cuerpo con lineSpacing(5),
   fuente de corpus, cabecera técnica monoespaciada). Sin tarjetas anidadas.
2. Crear Views/Reading/ReadingBlockView.swift: render por ReadingBlockKind.
   Prohibido DisclosureGroup, chevrons y lineLimit en bloques corpus.
3. Crear Views/Reading/ReadingChapterView.swift y ReadingTOCView.swift
   (índice lateral ~180pt, ScrollViewReader + scrollTo por ReadingChapterKind).
4. Crear Views/Reading/NatalReadingView.swift:
   - Recibe chart, interpretaciones, binding selectedFocusKey (los
     pointHeader siguen actualizándolo) y binding synthesis (temporal,
     hasta Sprint R3).
   - Columna de lectura con frame(maxWidth: 720) centrada.
   - Toggle Esencial|Completa que recompone con ReadingDensity.
   - .task: si NatalExtendedAnalysisResult es accesible por el mismo camino
     que usa NatalExtendedAnalysisView, calcularlo y recomponer al llegar;
     el documento debe renderizarse antes sin él.
5. En NatalChartView: el caso .reading monta NatalReadingView. Mantener
   .texts intacto en este sprint.
6. swift test + scripts/package_app.sh + timestamp.
```

### Sprint R3 — Persistencia, nota y limpieza

```text
Cierra el refactor de Lectura según el documento, secciones 5–6.

Tareas:
1. Crear Persistence/ReadingNotesStore.swift. Inspeccionar primero cómo
   persiste UserStore las cartas y usar el mismo mecanismo/directorio.
   API: note(for:), save(_:). Autosave con debounce ~1s y guardado en
   onDisappear desde NatalReadingView. Precargar el borrador automático
   (synthesisDraft) solo si no existe nota previa.
2. Reescribir ReadingNoteBuilder como serializador Markdown de NatalReading
   (capítulo a capítulo, chips como línea de texto, síntesis del usuario al
   final). Actualizar copyJoplinNote en NatalChartView.
3. Añadir buscador de corpus en la cabecera de NatalReadingView: filtra y
   resalta bloques corpus por texto.
4. Eliminar GuidedReadingView.swift, InterpretacionesView.swift y el caso
   .texts de NatalDetailMode. Revisar referencias (HelpView, SolarReturnView
   importa InterpretacionesView: inspeccionar y resolver — si SolarReturnView
   la reutiliza, extraer allí una vista mínima propia o migrarla al mismo
   patrón de bloques antes de borrar).
5. Tests de ReadingNotesStore. Actualizar docs/ARCHITECTURE.md.
6. swift test + scripts/package_app.sh + timestamp.
```

**Aviso detectado en la inspección:** `SolarReturnView.swift` también referencia `InterpretacionesView` — el prompt R3 ya obliga a Codex a resolverlo antes de borrar.

---

## 10. Resumen ejecutivo

| Antes | Después |
|---|---|
| Lectura = índice clicable sin textos | Lectura = documento continuo con arco doctrinal |
| Textos = acordeón plano de fichas | Corpus integrado inline, ordenado por relevancia; pestaña eliminada |
| Sin síntesis automática | Retrato (elementos/modalidades/secta/hemisferios/stellium) + dominantes |
| Aspectos por orbe bruto | Scoring de relevancia documentado |
| Síntesis manual volátil | Persistida por carta con borrador automático |
| Nota Joplin ≠ pantalla | Nota = serialización exacta del documento |
| Doctrina en la vista (regencias) | Doctrina en Engine/Reading, vistas tontas |

---

*Documento generado tras inspección directa de GuidedReadingView.swift, NatalChartView.swift, InterpretacionesView.swift, Interpretation.swift y NatalExtendedAnalysisView.swift en el repositorio.*
