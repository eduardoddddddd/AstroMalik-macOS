# Changelog

Todas las novedades reseñables se documentan aquí. El formato sigue [Keep a Changelog](https://keepachangelog.com/es-ES/1.1.0/) y el versionado sigue [SemVer](https://semver.org/lang/es/).

## [Unreleased]

### Añadido
- Rueda natal interactiva en SwiftUI con signos, casas, planetas, ASC/MC y líneas de aspecto.
- Modo "Lectura" con triada Sol/Luna/ASC, regente del Ascendente, casas angulares, aspectos dominantes y síntesis editable.
- Entrada "Lectura" en la navegación principal.
- Entrada "Sinastría" en la navegación principal.
- Motor de sinastría para dos cartas guardadas, con cálculo de aspectos A→B y B→A.
- Modelos `SynastryAspect` y `SynastryReading`.
- Lookup de corpus `tipo='sinastria'` con claves `SYN_<PLANETA_A>_<PLANETA_B>_<ASPECTO>`.
- Rueda doble de sinastría con planetas A/B y líneas de aspecto.
- Botón para crear nota de sinastría directamente en Joplin vía Web Clipper local.
- Configuración de Joplin en Ajustes: host, puerto, token y cuaderno.
- Autodetección del token local de Joplin desde `ASTROMALIK_JOPLIN_TOKEN` o settings de Joplin Desktop.
- Botón rápido claro/oscuro en la cabecera lateral.
- Diagnóstico de Horaria: Python detectado, versión, fuente del módulo, path y último error.
- Archivo de cartas con notas, etiquetas y búsqueda por texto/tag.
- Nota Markdown preparada para Joplin desde la vista de carta.
- Timeline de tránsitos con barras diarias de intensidad por orbe, eje temporal adaptable, eje de fechas fijo y apertura del detalle al pulsar.
- Tests de `swe_houses_ex2`, cancelación de tránsitos, timeline de intensidad, timezones conocidos, diagnóstico de Horaria, corpus/motor de sinastría y payload Joplin.

### Cambiado
- La arquitectura oficial queda como ventana única. Se retiró el código muerto de hosts multi-ventana y registros de sesión asociados.
- Tránsitos conserva resultados por carta y marca cuándo hay cambios pendientes de recalcular.
- El eje de fechas de tránsitos queda fijo durante el scroll vertical y ocupa todo el ancho disponible.
- Horaria ya no depende de un path local hardcodeado; resuelve bundle, variables de entorno/configuración local y paquete instalado.
- Cálculo de casas migrado de `swe_houses` a `swe_houses_ex2` con captura de error `serr`.
- Loop de tránsitos optimizado: usa fechas internas, materializa ISO solo al construir resultados y guarda muestras diarias de intensidad.
- `PlacesService` reemplaza regiones solapadas por zonas conocidas y bandas no solapadas.
- Roadmap actualizado: Sinastría pasa a fase completada y la exportación avanzada queda como trabajo futuro.

### Corregido
- Eliminados force unwraps en cálculo de días, Application Support y UTC.
- Cancelación explícita de tareas largas de tránsitos e interpretaciones.
- Mensaje específico para errores HTTP 403 de Joplin, apuntando a token/puerto de Web Clipper.

## [0.3.0] — 2026-04-19

### Añadido
- Tránsitos accesible desde el sidebar principal, al mismo nivel que "Nueva Carta" y "Cartas Guardadas"
- Picker segmentado en la vista de Tránsitos para elegir entre múltiples cartas guardadas
- Estado vacío con mensaje claro cuando no hay cartas guardadas al entrar en Tránsitos

### Cambiado
- Eliminado el botón de Tránsitos de la toolbar de `NatalChartView` — la funcionalidad vive ahora en la navegación principal

## [0.2.0] — 2026-04-17

### Añadido
- Etapa experimental de apertura de cartas en ventanas secundarias, retirada posteriormente al consolidar la ventana única.
- Atajo de teclado ⌘↩ en el formulario de nacimiento
- Feedback visual tras calcular la carta
- `Info.plist` embebido en la sección `__TEXT,__info_plist` del binario mediante linker flag `-sectcreate`
- Activación explícita con `NSApplication.setActivationPolicy(.regular)` + `activate(ignoringOtherApps:)`
- `docs/ARCHITECTURE.md` con explicación de decisiones técnicas
- Este CHANGELOG

### Cambiado
- README reescrito de arriba a abajo (más honesto sobre stack real, añade roadmap y relación con otros repos)
- `NatalChartView` ya no se muestra como `.sheet` — se muestra como contenido de ventana completa, redimensionable
- Ancho de columna de posiciones en `NatalChartView` ahora flexible (340 min / 400 ideal / 520 max) en lugar de fijo
- Ventana principal con dimensiones ideales (1100×780) además de mínimas
- `.windowResizability(.contentMinSize)` en la app

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
