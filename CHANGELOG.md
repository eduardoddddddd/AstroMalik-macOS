# Changelog

Todas las novedades reseñables se documentan aquí. El formato sigue [Keep a Changelog](https://keepachangelog.com/es-ES/1.1.0/) y el versionado sigue [SemVer](https://semver.org/lang/es/).

## [Unreleased]

## [0.3.0] — 2026-04-19

### Añadido
- Tránsitos accesible desde el sidebar principal, al mismo nivel que "Nueva Carta" y "Cartas Guardadas"
- Picker segmentado en la vista de Tránsitos para elegir entre múltiples cartas guardadas
- Estado vacío con mensaje claro cuando no hay cartas guardadas al entrar en Tránsitos

### Cambiado
- Eliminado el botón de Tránsitos de la toolbar de `NatalChartView` — la funcionalidad vive ahora en la navegación principal

## [0.2.0] — 2026-04-17

### Añadido
- Arquitectura multi-ventana: cada carta calculada abre en su propia ventana independiente mediante `WindowGroup(id: "chart", for: UUID.self)`
- `ChartWindowHost.swift` como contenedor de ventanas secundarias con fallback elegante cuando el UUID no resuelve
- `AppState.sessionCharts` — registro en memoria de cartas calculadas en la sesión
- `AppState.register(_:)` y `AppState.chart(for:)` para resolución UUID → NatalChart
- Atajo de teclado ⌘↩ en el formulario de nacimiento
- Feedback visual tras calcular: "Carta abierta en ventana: X"
- `Info.plist` embebido en la sección `__TEXT,__info_plist` del binario mediante linker flag `-sectcreate`
- Activación explícita con `NSApplication.setActivationPolicy(.regular)` + `activate(ignoringOtherApps:)`
- `docs/ARCHITECTURE.md` con explicación de decisiones técnicas
- Este CHANGELOG

### Cambiado
- README reescrito de arriba a abajo (más honesto sobre stack real, añade roadmap y relación con otros repos)
- `NatalChartView` ya no se muestra como `.sheet` — se muestra como contenido de ventana completa, redimensionable
- Ancho de columna de posiciones en `NatalChartView` ahora flexible (340 min / 400 ideal / 520 max) en lugar de fijo
- `SavedChartsView` abre cartas en ventana secundaria en lugar de sheet modal
- Ventana principal con dimensiones ideales (1100×780) además de mínimas
- `.windowResizability(.contentMinSize)` en ambos `WindowGroup`

### Corregido
- **Bug crítico de arranque:** `Task.detached` en `NatalChartView.loadInterpretaciones` rompía aislamiento de actor en Swift 6 → la app salía con `failure (0x5)` al arrancar desde Xcode. Refactorizado al patrón correcto: task padre en MainActor + `Task.detached { ... }.value` solo para el trabajo pesado de SQLite
- `JulianDay.swift:62` — `var utcComps` → `let utcComps` (nunca se muta)
- `SQLiteDB.swift:96` — descarte explícito del resultado de `withUnsafeBytes { sqlite3_bind_blob(...) }`
- Eliminado botón "Cerrar" en `NatalChartView` (ya no es sheet; la ventana se cierra con su propia cruz o ⌘W)

## [0.1.0] — marzo/abril 2026

### Añadido
- Port inicial desde Python (pyswisseph) a Swift + target C `CSwissEph`
- UI básica SwiftUI: formulario de nacimiento, vista de carta, lista de interpretaciones
- Tests de sanity sobre carta de referencia (1976-10-11 20:33 Europe/Madrid)
- Persistencia local con `SQLiteDB` propio (sin GRDB)
- Corpus `corpus.db` con 1.766 interpretaciones
- Búsqueda de lugares: seed offline + Nominatim
- Eliminación completa de la dependencia GRDB (reemplazada por sqlite3 del sistema)
