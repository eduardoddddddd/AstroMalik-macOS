# Prompt Codex — Resumen Predictivo Mensual

**Proyecto:** AstroMalik-macOS
**Módulo:** Efemérides → nueva pestaña "Resumen"
**Fecha:** 4 de mayo de 2026

---

## Contexto del proyecto

Trabajas en el repo AstroMalik-macOS. Es una app de astrología nativa macOS (Swift 6, SwiftUI, SPM, macOS 14+) con Swiss Ephemeris embebido como target C (`CSwissEph`). La app tiene ventana única con `NavigationSplitView`, estado en `AppState` (EnvironmentObject), cartas natales guardadas en `UserStore`, y salida documental a Joplin vía `JoplinClipperService` (Web Clipper local 127.0.0.1:41184).

### Lo que ya existe y vas a consumir

1. **EphemerisEngine** (`Sources/AstroMalik/Engine/Ephemeris/EphemerisEngine.swift`):
   - `computeMonth(year:month:timezone:) async throws -> EphemerisMonth`
   - `EphemerisMonth` contiene `events: [CelestialEvent]` y `dailyRows: [DailyEphemerisRow]`
   - `CelestialEvent` tiene: `kind` (newMoon, fullMoon, solarEclipse, lunarEclipse, stationRetrograde, stationDirect, signIngress, voidOfCourse, mundaneAspect…), `longitude`, `signKey`, `signLabel`, `formatted`, `dateUTC`, `dateLocal`, `importance`, `title`, `subtitle`, `planetKeyA`, `eclipseType`, `eclipseMagnitude`, `voidDurationMinutes`…

2. **TransitEngine** (`Sources/AstroMalik/Engine/TransitEngine.swift`):
   - `computeTransitPeriod(natalChart:fromDate:toDate:timezone:excludeMoon:corpusStore:) async throws -> [TransitEvent]`
   - `detectHouseIngresses(natalChart:fromDate:toDate:excludeMoon:corpusStore:) throws -> [TransitHouseIngress]`
   - `TransitEvent` tiene: `transitKey`, `natalKey`, `aspectKey`, `exactDate`, `fromDate`, `toDate`, `score`, `stars`, `priorityBand` (.low/.medium/.high/.critical), `priorityScore`, `text`, `metricReasons`, `retrogradeOnExact`, `samples`…

3. **NatalChart** (`Sources/AstroMalik/Models/NatalChart.swift`):
   - `bodies: [PlanetBody]` con `key`, `longitude`, `house`, `retrograde`
   - `cusps: [Double]` (12 cúspides)
   - `ascendant`, `mc` con `longitude`

4. **AstroEngine** (`Sources/AstroMalik/Engine/AstroEngine.swift`):
   - `planetHouse(deg:cusps:) -> Int`
   - `degToSign(_:) -> String`
   - `degToSignKey(_:) -> String`
   - `calcPlanets(jd:)`, `calcLunarNodes(jd:)`

5. **EphemerisCalendarView** (`Sources/AstroMalik/Views/EphemerisCalendarView.swift`):
   - Tiene un segmented picker con `EphemerisViewMode` (actualmente `.calendar` y `.table`)
   - Tiene `@State var monthData: EphemerisMonth?`
   - Tiene `@EnvironmentObject var appState: AppState`
   - Ya calcula el mes en `.task(id:)`

6. **AppState**:
   - `activeNatalChart: NatalChart?` — carta activa
   - `userStore.savedCharts: [NatalChart]` — cartas guardadas
   - `transitState: TransitWorkspaceState` — estado de tránsitos
   - `corpusStore: CorpusStore` — textos interpretativos
   - `joplinSettings` — configuración Joplin

7. **CorpusStore** (`Sources/AstroMalik/Store/CorpusStore.swift`):
   - `lookupTransit(trKey:nKey:aspKey:) -> (String?, String?)`

8. **Patrones del repo**:
   - Motores como `enum` con funciones estáticas
   - Modelos `Codable`, `Equatable`, `Identifiable`
   - No force unwraps
   - Tests en `Tests/AstroMalikTests/`
   - Tras cambios: `swift test` + `scripts/package_app.sh`
   - Notas Joplin con NoteBuilder + JoplinClipperService

---

## Qué es un Resumen Predictivo Mensual (visión astrológica)

Es la herramienta que un astrólogo profesional prepara para sí mismo o para un cliente al inicio de cada mes. Responde a la pregunta:

> **¿Qué me trae este mes, personalmente?**

No es un listado genérico del cielo (eso ya lo hace la pestaña Calendario). Es el cielo **filtrado y cruzado con la carta natal del usuario**. Contiene:

### A. Lunaciones del mes en casas natales

Cada Luna Nueva y Luna Llena cae en un grado concreto. Ese grado cae en una casa natal específica del usuario. La casa determina el área de vida que se activa:

- Luna Nueva en casa 7 → ciclo de siembra en relaciones/pareja
- Luna Llena en casa 10 → culminación o revelación profesional
- Luna Nueva en casa 2 → arranque de ciclo económico/de valores

Además, si la lunación cae a menos de 5° de un planeta natal, es una activación directa. Luna Nueva conjunción a tu Venus natal → mes de inicio amoroso o creativo potente.

### B. Eclipses sobre la carta (si los hay ese mes)

Un eclipse es una lunación extrema. Además de la casa donde cae, importa:
- Si cae sobre un planeta natal (orbe ≤ 5°), es un evento de primer orden del año
- Si cae en un eje angular (casas 1/7 o 4/10), redefine la identidad o la dirección vital
- El tipo (solar vs lunar, total vs parcial) matiza la intensidad

### C. Estaciones planetarias sobre puntos natales

Cuando un planeta se estaciona (velocidad ≈ 0), su energía se concentra en un grado concreto durante semanas. Si ese grado coincide con un punto natal del usuario (orbe ≤ 3°), es uno de los tránsitos más potentes del año:

- Saturno estación retrógrada sobre tu Luna → semanas de presión emocional
- Júpiter estación directa sobre tu MC → expansión profesional que arranca

### D. Tránsitos activos del mes (top 5-8 por prioridad)

Filtrar los TransitEvent del módulo de tránsitos que estén activos durante el mes (su rango fromDate-toDate se solapa con el mes), ordenados por priorityScore, mostrando los más importantes. No recalcular — reutilizar lo que TransitEngine ya sabe.

### E. Ingresos por casa natal activos

Los TransitHouseIngress del mes, si los hay. Saturno entrando en tu casa 7 es un evento de 2-3 años que empieza en una fecha concreta.

### F. Clima general del mes

Un párrafo breve de síntesis: cuántas lunaciones, si hay eclipse, qué estaciones marcan el tono, cuántos tránsitos activos de prioridad alta o crítica. Es el "termómetro" del mes.

---

## Dónde vive en la app

### Integración en EphemerisCalendarView

Añadir un tercer caso al `EphemerisViewMode`:

```swift
private enum EphemerisViewMode: String, CaseIterable, Identifiable {
    case calendar = "Calendario"
    case table = "Efemérides"
    case summary = "Resumen"
    var id: String { rawValue }
}
```

Cuando el usuario selecciona "Resumen":
- Si hay carta natal activa (o cartas guardadas), se muestra el resumen del mes para esa carta
- Si no hay carta, se muestra un placeholder indicando que guarde una carta natal para ver el resumen personalizado
- Si hay varias cartas guardadas, añadir un picker de carta (mismo patrón que TransitsView en ContentView)

### Dependencia de datos

El resumen necesita:
1. `EphemerisMonth` del mes actual (ya calculado por la vista)
2. `[TransitEvent]` para ese mes (cálculo nuevo, rango = primer y último día del mes)
3. `[TransitHouseIngress]` para ese mes
4. `NatalChart` activa

Los puntos 2 y 3 se calculan bajo demanda cuando el usuario entra en la pestaña Resumen, no antes.

---

## Arquitectura

### Archivos a crear

```
Sources/AstroMalik/Engine/Ephemeris/MonthlySummaryEngine.swift   ← Motor de síntesis
Sources/AstroMalik/Models/MonthlySummary.swift                   ← Modelo de datos
Sources/AstroMalik/Views/MonthlySummaryView.swift                ← Vista del resumen
Sources/AstroMalik/Views/MonthlySummaryNoteBuilder.swift         ← Generador de nota Joplin
Tests/AstroMalikTests/EphemerisTests/MonthlySummaryEngineTests.swift
```

### Archivos a modificar

```
Sources/AstroMalik/Views/EphemerisCalendarView.swift  ← Añadir caso .summary en el picker y en el switch de contenido
```

### Modelo — MonthlySummary.swift

```swift
/// Resumen predictivo mensual personalizado.
struct MonthlySummary: Identifiable, Equatable {
    let id: String                          // "2026-06-CHART_UUID"
    let year: Int
    let month: Int
    let chartName: String

    // A. Lunaciones en casas natales
    let lunationHits: [LunationNatalHit]

    // B. Eclipses sobre la carta
    let eclipseHits: [EclipseNatalHit]

    // C. Estaciones sobre puntos natales
    let stationHits: [StationNatalHit]

    // D. Tránsitos activos top
    let activeTransits: [TransitEvent]      // ya ordenados por priorityScore

    // E. Ingresos por casa
    let houseIngresses: [TransitHouseIngress]

    // F. Clima
    let climateSummary: String
}

/// Luna Nueva o Llena cruzada con la natal.
struct LunationNatalHit: Identifiable, Equatable {
    let id: UUID
    let event: CelestialEvent               // la lunación original
    let natalHouse: Int                      // casa natal donde cae
    let conjunctPlanet: PlanetConjunction?   // si cae a ≤5° de un planeta natal
    let narrative: String                    // texto interpretativo generado
}

/// Conjunción de un evento celeste con un planeta natal.
struct PlanetConjunction: Equatable {
    let planetKey: String
    let planetLabel: String
    let orb: Double                          // distancia angular
}

/// Eclipse cruzado con la natal.
struct EclipseNatalHit: Identifiable, Equatable {
    let id: UUID
    let event: CelestialEvent
    let natalHouse: Int
    let conjunctPlanets: [PlanetConjunction] // puede tocar más de uno
    let isAngular: Bool                      // casa 1, 4, 7 o 10
    let narrative: String
}

/// Estación planetaria que cae sobre un punto natal.
struct StationNatalHit: Identifiable, Equatable {
    let id: UUID
    let event: CelestialEvent
    let natalPlanetKey: String
    let natalPlanetLabel: String
    let natalHouse: Int
    let orb: Double
    let narrative: String
}
```

### Motor — MonthlySummaryEngine.swift

```swift
enum MonthlySummaryEngine {

    /// Genera el resumen predictivo mensual cruzando el cielo con la carta natal.
    ///
    /// - Parameters:
    ///   - ephemeris: EphemerisMonth ya calculado
    ///   - natalChart: carta natal del usuario
    ///   - transits: tránsitos del mes (puede ser [] si no se han calculado)
    ///   - ingresses: ingresos por casa del mes
    /// - Returns: MonthlySummary completo
    static func generateSummary(
        ephemeris: EphemerisMonth,
        natalChart: NatalChart,
        transits: [TransitEvent],
        ingresses: [TransitHouseIngress]
    ) -> MonthlySummary
}
```

### Lógica del motor

#### A. Lunaciones en casas natales

Para cada `CelestialEvent` con kind `.newMoon` o `.fullMoon`:
1. Tomar `event.longitude` (grado de la lunación)
2. Calcular `AstroEngine.planetHouse(deg: longitude, cusps: natalChart.cusps)` → casa natal
3. Buscar conjunciones: para cada `PlanetBody` de `natalChart.bodies`, calcular la distancia angular entre `event.longitude` y `body.longitude`. Si ≤ 5°, crear `PlanetConjunction`.
4. Generar narrativa con templates:

```swift
// Ejemplo de templates (crear como enum MonthlySummaryTemplates)
static func lunationInHouse(_ house: Int, isNew: Bool) -> String {
    let phase = isNew ? "Luna Nueva" : "Luna Llena"
    switch house {
    case 1: return "\(phase) en tu casa 1: ciclo de reinvención personal, imagen y energía vital."
    case 2: return "\(phase) en tu casa 2: foco en recursos, dinero, valores y autoestima."
    case 3: return "\(phase) en tu casa 3: activación de comunicación, aprendizaje y entorno cercano."
    case 4: return "\(phase) en tu casa 4: movimiento en hogar, familia, raíces y vida privada."
    case 5: return "\(phase) en tu casa 5: creatividad, romance, hijos y expresión personal."
    case 6: return "\(phase) en tu casa 6: ajustes en salud, rutina, trabajo diario y servicio."
    case 7: return "\(phase) en tu casa 7: activación de relaciones, pareja, socios y acuerdos."
    case 8: return "\(phase) en tu casa 8: transformación, recursos compartidos, crisis y regeneración."
    case 9: return "\(phase) en tu casa 9: expansión, viajes, estudios superiores y búsqueda de sentido."
    case 10: return "\(phase) en tu casa 10: foco en carrera, vocación, reputación y dirección vital."
    case 11: return "\(phase) en tu casa 11: movimiento en grupos, amistades, proyectos y aspiraciones."
    case 12: return "\(phase) en tu casa 12: retiro, introspección, cierre de ciclos y lo inconsciente."
    default: return "\(phase) activa la casa \(house) de tu carta natal."
    }
}

// Si hay conjunción con planeta natal:
static func lunationConjunct(_ planetLabel: String, orb: Double) -> String {
    "Además, esta lunación activa directamente tu \(planetLabel) natal (orbe \(String(format: "%.1f", orb))°), amplificando su significado personal."
}
```

#### B. Eclipses sobre la carta

Mismo proceso que lunaciones pero con:
- Orbe ≤ 5° para conjunción (más generoso porque los eclipses son más potentes)
- Detectar si cae en casa angular (1, 4, 7, 10) → flag `isAngular`
- Narrativa más enfática: los eclipses marcan puntos de inflexión, no solo ciclos

Templates ejemplo:
```swift
static func eclipseInHouse(_ house: Int, type: String, isSolar: Bool) -> String {
    let eclipseKind = isSolar ? "Eclipse solar" : "Eclipse lunar"
    // Similar a lunaciones pero con tono más fuerte:
    // "Eclipse solar en tu casa 7: punto de inflexión en relaciones..."
}

static func eclipseOnPlanet(_ planetLabel: String, orb: Double) -> String {
    "Este eclipse activa tu \(planetLabel) natal (orbe \(String(format: "%.1f", orb))°). Es un evento de primer orden del año: marca un antes y un después en el ámbito de este planeta."
}

static func eclipseAngular() -> String {
    "El eclipse cae en un eje angular de tu carta, lo que intensifica su impacto en tu dirección vital."
}
```

#### C. Estaciones sobre puntos natales

Para cada `CelestialEvent` con kind `.stationRetrograde` o `.stationDirect`:
1. Tomar `event.longitude`
2. Para cada planeta natal, calcular distancia angular. Si ≤ 3°, crear `StationNatalHit`.
3. Narrativa:

```swift
static func stationOnPlanet(
    stationPlanet: String,  // "Saturno"
    stationType: String,    // "retrógrada" o "directa"
    natalPlanet: String,    // "Luna"
    natalHouse: Int,
    orb: Double
) -> String {
    "\(stationPlanet) se estaciona \(stationType) sobre tu \(natalPlanet) natal en casa \(natalHouse) (orbe \(String(format: "%.1f", orb))°). Durante varias semanas, la energía de \(stationPlanet) se concentra intensamente en este punto de tu carta."
}
```

#### D. Tránsitos activos del mes

Filtrar `transits` que se solapan con el mes:
```swift
let monthStart = "\(String(format: "%04d", year))-\(String(format: "%02d", month))-01"
let monthEnd = ... // último día del mes
let active = transits.filter { $0.toDate >= monthStart && $0.fromDate <= monthEnd }
let top = Array(active.sorted { $0.priorityScore > $1.priorityScore }.prefix(8))
```

No generar textos nuevos — reutilizar los `TransitEvent` tal cual con su `text`, `stars`, `priorityBand` y `metricReasons`.

#### E. Ingresos por casa

Directamente los `TransitHouseIngress` del rango del mes. Ya tienen `text` del corpus.

#### F. Clima general

Generar un string de síntesis:
```swift
static func climateSummary(
    lunationCount: Int,
    hasEclipse: Bool,
    eclipseCount: Int,
    stationHitCount: Int,
    highPriorityTransitCount: Int,
    criticalTransitCount: Int
) -> String {
    var parts: [String] = []
    if hasEclipse {
        parts.append(eclipseCount == 1
            ? "Un eclipse este mes marca un punto de inflexión"
            : "\(eclipseCount) eclipses hacen de este un mes extraordinario")
    }
    if stationHitCount > 0 {
        parts.append("\(stationHitCount) estación(es) planetaria(s) tocan tu carta directamente")
    }
    if criticalTransitCount > 0 {
        parts.append("\(criticalTransitCount) tránsito(s) de prioridad crítica")
    } else if highPriorityTransitCount > 0 {
        parts.append("\(highPriorityTransitCount) tránsito(s) de prioridad alta")
    }
    if parts.isEmpty {
        return "Mes de actividad moderada. Las lunaciones marcan el ritmo principal."
    }
    return parts.joined(separator: ". ") + "."
}
```

---

## Vista — MonthlySummaryView.swift

La vista recibe un `MonthlySummary` y lo presenta en secciones scrollables. El tono visual debe ser sobrio y profesional, coherente con el resto de la app.

### Layout

```
ScrollView {
    VStack(alignment: .leading, spacing: 24) {

        // Cabecera con nombre del mes y carta
        Header: "Resumen predictivo — Junio 2026"
        Subtítulo: "Para [nombre de la carta]"

        // Clima general
        Sección con icono termómetro y texto climateSummary
        Color de fondo según intensidad del mes

        // Lunaciones
        Si lunationHits no está vacío:
        Sección "Lunaciones del mes"
        Para cada hit:
          - Icono 🌑/🌕 + título del evento + casa natal
          - Texto narrativo
          - Si hay conjunción: badge con planeta y orbe

        // Eclipses
        Si eclipseHits no está vacío:
        Sección "Eclipses" con borde o fondo especial (importancia crítica)
        Para cada hit:
          - Icono + tipo + casa natal
          - Narrativa
          - Badge angular si aplica
          - Planetas natales tocados

        // Estaciones sobre natal
        Si stationHits no está vacío:
        Sección "Estaciones planetarias sobre tu carta"
        Para cada hit:
          - Planeta que se estaciona + tipo SR/SD
          - Planeta natal tocado + casa + orbe
          - Narrativa

        // Tránsitos activos
        Si activeTransits no está vacío:
        Sección "Tránsitos activos este mes"
        Para cada tránsito (top 8):
          - transitLabel aspectLabel natalLabel
          - Estrellas + banda de prioridad
          - Periodo activo
          - Texto interpretativo si lo tiene
          Reutilizar el estilo visual de TransitsView para consistencia

        // Ingresos
        Si houseIngresses no está vacío:
        Sección "Ingresos por casa natal"
        Para cada ingreso:
          - Planeta + casa destino
          - Texto si lo tiene

        // Botón Joplin
        Botón para crear nota del resumen completo
    }
}
```

### Comportamiento

- Al seleccionar la pestaña "Resumen", si hay carta activa y monthData ya existe:
  1. Calcular tránsitos del mes con `computeTransitPeriod` (rango: primer día al último del mes)
  2. Calcular ingresos con `detectHouseIngresses` (mismo rango)
  3. Llamar a `MonthlySummaryEngine.generateSummary`
  4. Mostrar resultado
- Mostrar ProgressView durante el cálculo
- Cachear el resultado para no recalcular al cambiar de pestaña y volver
- Invalidar si cambia el mes o la carta activa

---

## NoteBuilder — MonthlySummaryNoteBuilder.swift

Genera Markdown para Joplin:

```markdown
# Resumen Predictivo — Junio 2026
## Para [nombre de la carta]

### Clima del mes
[climateSummary]

### Lunaciones
🌑 **Luna Nueva en ♋ Cáncer** — 15 jun 2026 16:32
Casa natal: 7
[narrativa]

🌕 **Luna Llena en ♑ Capricornio** — 29 jun 2026 08:15
Casa natal: 1
[narrativa]

### Eclipses
(si los hay)

### Estaciones sobre tu carta
(si las hay)

### Tránsitos activos principales
1. ★★★★★ Saturno Conjunción Sol — 03 jun–28 jul — Prioridad Crítica
   [texto interpretativo]
2. ...

### Ingresos por casa natal
(si los hay)

---
*Generado por AstroMalik — [fecha]*
```

---

## Tests — MonthlySummaryEngineTests.swift

```swift
// 1. Test con carta natal de referencia y EphemerisMonth de junio 2026:
//    - Verificar que cada lunación del mes tiene un LunationNatalHit
//    - Verificar que natalHouse está en 1...12
//    - Verificar que la narrativa no está vacía

// 2. Test de conjunción: crear una carta natal con Sol a 24° de Cáncer.
//    Si la Luna Nueva de junio 2026 cae cerca de ese grado,
//    verificar que conjunctPlanet no es nil y orb ≤ 5°.
//    Si no cae cerca, verificar que conjunctPlanet es nil.

// 3. Test de estación: si hay una estación planetaria en el mes
//    y un planeta natal está a ≤3° de esa longitud,
//    verificar que stationHits no está vacío.

// 4. Test de clima: verificar que climateSummary no está vacío
//    y que su contenido varía según la presencia de eclipses/estaciones.

// 5. Test de tránsitos: pasar un array de TransitEvent con distintas
//    fechas. Verificar que solo los del mes aparecen, limitados a 8,
//    ordenados por priorityScore descendente.
```

---

## Reglas del repo

- Swift 6, macOS 14+, SwiftUI, SPM
- No force unwraps
- Ventana única con NavigationSplitView
- Tests enfocados
- Ejecutar `swift test` y después `scripts/package_app.sh`
- Verificar timestamp de `AstroMalik.app/Contents/MacOS/AstroMalik`
- Actualizar `docs/ARCHITECTURE.md` con la nueva funcionalidad
- Nota Joplin: usar `JoplinClipperService` y `MonthlySummaryNoteBuilder`

---

## Entrega esperada

- Lista de archivos creados y modificados
- Resumen de decisiones tomadas
- Tests ejecutados y resultados
- Limitaciones documentadas (por ejemplo: los templates de narrativa son v1 y pueden refinarse, los tránsitos se recalculan por mes lo cual tiene coste)
