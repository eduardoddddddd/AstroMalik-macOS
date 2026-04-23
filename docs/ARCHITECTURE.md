# Arquitectura de AstroMalik-macOS

Este documento explica las decisiones técnicas no obvias del proyecto. Si vienes del README y te preguntas "¿por qué hicieron X así?", respuestas aquí.

## Tabla de contenidos

1. [Por qué Swift Package en lugar de .xcodeproj](#por-qué-swift-package)
2. [El problema del Info.plist en executables SPM](#infoplist-embebido)
3. [Activación de la app y ventanas en primer plano](#activación-de-app)
4. [Arquitectura multi-ventana](#multi-ventana)
5. [Aislamiento de actores en Swift 6](#actor-isolation)
6. [Swiss Ephemeris embebido como target C](#swiss-ephemeris)
7. [SQLite sin GRDB](#sqlite-directo)

---

## Por qué Swift Package

Usar `Package.swift` en lugar de `.xcodeproj` tiene ventajas claras:

- **Portabilidad** — compila desde terminal en cualquier Mac con toolchain Swift, sin Xcode
- **Reproducibilidad** — un único archivo de manifiesto versiona todo el build
- **Sin secretos** — nada de `xcuserdata` o schemes binarios que ensucien el repo

Contra: ejecutar con ▶ desde Xcode es resbaladizo (ver secciones siguientes). La recomendación es desarrollar con Xcode para lectura/edición y ejecutar con `open` desde terminal.

## Info.plist embebido

Un executable SPM **no genera bundle `.app`** — produce un binario Mach-O a secas en `.build/.../AstroMalik`. Sin `Info.plist`, macOS lo trata como daemon y **no le da ventana GUI**.

La solución estándar es incrustar el `Info.plist` directamente en la sección `__TEXT,__info_plist` del binario:

```swift
// En Package.swift
linkerSettings: [
    .linkedLibrary("sqlite3"),
    .unsafeFlags([
        "-Xlinker", "-sectcreate",
        "-Xlinker", "__TEXT",
        "-Xlinker", "__info_plist",
        "-Xlinker", "Info.plist",
    ]),
]
```

Verificable con `otool`:

```bash
otool -P .build/arm64-apple-macosx/debug/AstroMalik | head -20
# muestra el plist en texto plano
```

El `Info.plist` está en la raíz del repo (no dentro de `Resources/` — SPM lo prohíbe para ese nombre).

## Activación de app

Aun con Info.plist embebido, macOS puede no activar la app en primer plano al ejecutarla desde terminal. Se fuerza en código:

```swift
// AstroMalikApp.init()
NSApplication.shared.setActivationPolicy(.regular)
NSApplication.shared.activate(ignoringOtherApps: true)
```

Sin estas dos líneas la app vive en background y no puedes traer la ventana al frente con Cmd+Tab. Con ellas, se comporta como cualquier app nativa.

## Navegación principal

El sidebar expone tres ítems fijos via `NavItem` (enum `CaseIterable`):

| Ítem | Vista | Icono |
|------|-------|-------|
| Nueva Carta | `BirthChartForm` | `star.circle` |
| Cartas Guardadas | `SavedChartsView` | `tray.full` |
| Tránsitos | `TransitsView` (inline) | `calendar.circle` |

**Tránsitos** muestra directamente `TransitsView` en el panel de detalle. Si hay más de una carta guardada, aparece un `Picker` segmentado para elegir cuál carta usar. Si no hay cartas guardadas, se muestra un estado vacío con mensaje.

No hay botón flotante de tránsitos en la toolbar de `NatalChartView` — la funcionalidad vive en el sidebar.

---

## Multi-ventana

### Problema

La primera versión (Fase 0) usaba `.sheet(item: $pendingChart)` para mostrar la carta calculada. En macOS los sheets:

- Tienen tamaño fijo por defecto
- Bloquean la ventana padre mientras están abiertos
- No permiten comparar dos cartas simultáneamente

### Solución

Segundo `WindowGroup` parametrizado por UUID:

```swift
// AstroMalikApp.swift
WindowGroup(id: "chart", for: UUID.self) { $chartId in
    ChartWindowHost(chartId: chartId)
        .environmentObject(appState)
        .frame(minWidth: 960, idealWidth: 1180, minHeight: 640, idealHeight: 800)
}
.windowResizability(.contentMinSize)
```

Apertura desde cualquier vista:

```swift
@Environment(\.openWindow) private var openWindow

appState.register(chart)
openWindow(id: "chart", value: chart.id)
```

### AppState como registro

Como `WindowGroup(for:)` serializa el UUID (SwiftUI lo persiste para restauración de ventanas), el UUID por sí solo no basta para reconstruir la `NatalChart`. `AppState` mantiene dos fuentes resolubles:

```swift
@Published var sessionCharts: [UUID: NatalChart] = [:]   // calculadas en esta sesión

func chart(for id: UUID) -> NatalChart? {
    if let c = sessionCharts[id] { return c }
    return userStore.savedCharts.first(where: { $0.id == id })
}
```

Si el UUID no se resuelve, `ChartWindowHost` muestra un estado vacío elegante en lugar de crashear.

## Actor isolation

En Swift 6 el modelo de concurrencia es estricto. `AppState` está marcado `@MainActor`, y todas las vistas SwiftUI corren en el main actor. Un error común es usar `Task.detached` para trabajo pesado y luego asignar a `@State` desde dentro:

```swift
// ❌ Antipatrón — falla en Swift 6
Task.detached { [chart] in
    let result = appState.corpusStore.build(chart: chart)  // cross-actor sin await
    interpretaciones = result                              // cross-actor a @State
}
```

El patrón correcto: la task vive en el main actor, y solo el trabajo pesado se delega a detached con `.value`:

```swift
// ✅ Patrón correcto
let store = appState.corpusStore
let currentChart = chart
Task {
    let interps = await Task.detached(priority: .userInitiated) {
        store.buildNatalInterpretations(chart: currentChart)
    }.value
    interpretaciones = interps   // ya en main actor
    isLoadingInterp = false
}
```

Este fix está aplicado en `NatalChartView.loadInterpretaciones()`.

## Swiss Ephemeris

Swiss Ephemeris es una librería C de alta precisión (Astrodienst). Se integra como **target SPM `CSwissEph`** compilando los `.c` directamente en el paquete:

```swift
.target(
    name: "CSwissEph",
    path: "Sources/CSwissEph",
    exclude: ["include/module.modulemap"],
    publicHeadersPath: "include",
    cSettings: [.define("JAVAME", to: "0")]
)
```

El target Swift importa con `import CSwissEph` y llama a `swe_calc_ut`, `swe_houses_ex`, etc. directamente. Los archivos de efemérides (`.se1`, 1800–2400) se embeben en el bundle de recursos.

## SQLite directo

El proyecto usa `sqlite3` del sistema (`-lsqlite3`) con un wrapper Swift propio (`SQLiteDB.swift`, ~150 líneas). Se eliminó GRDB en un commit anterior porque:

- GRDB añadía ~200 KB y 100+ archivos al checkout
- El uso es elemental (CRUD sobre ~5 tablas pequeñas)
- SQLite del sistema siempre está disponible en macOS

El coste es mantener nuestro wrapper, pero cabe en un archivo y es trivial de auditar.

---

## Pendientes / Technical Debt

Hallazgos del code review del 2026-04-19. Ordenados por criticidad.

### Crítico

| # | Archivo | Línea | Problema |
|---|---------|-------|---------|
| 1 | `Engine/TransitEngine.swift` | 86, 107, 128, 165 | Force unwrap en `.day!` de `dateComponents` — puede retornar nil y crashear |
| 2 | `Store/UserStore.swift` | 34 | Force unwrap `.first!` en URLs de FileManager sin nil-check |
| 3 | `Models/SavedChartRecord.swift` | 27 | `(try? ...) ?? "{}"` silencia errores de encoding — puede guardar JSON vacío sin aviso |

**Fix sugerido #1 y #2:** reemplazar `!` por `?? 0` / `?? fallback` y manejar el caso nil explícitamente.  
**Fix sugerido #3:** lanzar o loguear el error en lugar de usar `??`.

### Thread Safety

| # | Archivo | Problema |
|---|---------|---------|
| 4 | `Store/UserStore.swift` | Métodos que tocan SwiftData/UI sin `@MainActor` |
| 5 | `Views/TransitsView.swift` | Async `computeTransitPeriod` sin cancellation token; el usuario puede lanzar cálculos concurrentes |
| 6 | `Views/NatalChartView.swift` | Task detached no cancela si el view se desmonta antes de terminar |

**Fix sugerido #4:** añadir `@MainActor` a `UserStore` o aislar los métodos que escriben a `@Published`.  
**Fix sugerido #5 y #6:** guardar la task en `@State var currentTask: Task<Void,Never>?` y cancelar en `.onDisappear`.

### SwiftUI / Calidad

| # | Archivo | Problema |
|---|---------|---------|
| 7 | `Views/BirthChartForm.swift` | Usa `DispatchQueue.main.asyncAfter` — preferir `Task { try? Task.sleep(nanoseconds:) }` |
| 8 | `Views/SavedChartsView.swift` | Doble tap + single tap en el mismo elemento genera UX confusa y lógica duplicada |
| 9 | `Engine/TransitEngine.swift` | Fallback a `.capitalized` para nombres no traducidos puede producir mayúsculas incorrectas (p.ej. "PLUTON") |
| 10 | `Engine/JulianDay.swift` | `TimeZone(identifier: "UTC")!` — UTC siempre es válido pero rompe el patrón de manejo seguro |
