# Changelog

Todas las novedades reseñables se documentan aquí. El formato sigue [Keep a Changelog](https://keepachangelog.com/es-ES/1.1.0/) y el versionado sigue [SemVer](https://semver.org/lang/es/).

## \[Unreleased\]

### Añadido

- Corpus completo de 165 interpretaciones de direcciones primarias basado en Lilly, `Christian Astrology` Libro III (1647): 165 verdes, 0 amarillas, 0 pendientes.
- Vista "Lista profesional" para Direcciones Primarias con tabla nativa ordenable, columnas densas y selección sincronizada con el detalle.
- Vista "Año en curso" con selector anual, ventana residual de ±18 meses y tarjetas cronológicas con texto principal abreviado.
- Tabla de Espéculo Regiomontano completo en el detalle, resaltando prómissor y significador.
- Presets de filtro para Direcciones Primarias (Clásico/Extendido/Completo) con exclusión de transpersonales en modo clásico.
- Sistema de peso por dirección (crítica/mayor/moderada/menor) con jerarquía visual en timeline, tabla y detalle.
- Filtro por peso mínimo para reducir ruido sin recalcular el motor.

### Cambiado

- Reorganizada la UI de Direcciones Primarias en header compacto, timeline semántico y panel maestro con tabs.
- Rediseñado el detalle de una dirección con hero permanente, texto principal priorizado, alternativos bajo demanda, factores morinistas y datos técnicos en tabla estricta.
- El banner de honestidad del corpus pasa a popover informativo en el header.
- El plano por defecto de direcciones pasa a zodiacal con migración de `UserDefaults` a versión 2.
- El default para usuarios nuevos de Direcciones Primarias pasa al preset Clásico.
- El tooltip del timeline muestra dirección del movimiento, edad compacta, tipo y peso.
- El banner superior de Direcciones Primarias muestra preset activo y conteo de direcciones críticas visibles.

### Corregido

- Direcciones conversas calculadas con roles invertidos y polo del prómissor, en vez de derivarlas del signo del arco.
- Clave Brahe basada en el arco de ascensión recta del Sol entre el nacimiento y +24h.
- RAMC calculado con `swe_sidtime0` para paridad con Morinus.
- Pars Fortunae soportada como prómissor opt-in en el motor de Direcciones Primarias.
- Fecha estimada de las direcciones calculada con precisión sub-día.

### Eliminado

- Método Placidus retirado de Direcciones Primarias hasta tener un motor real.

## \[0.4.0\] — 2026-04-27

### Añadido (Módulo Direcciones Primarias - Fases 1 a 6)

- **Cálculo de Direcciones Primarias:** Implementado motor completo con proyección de Regiomontanus, abarcando direcciones mundanas y zodiacales, con soporte para las claves de Naibod, Ptolomeo y Brahe.
- **Corpus y Política de Honestidad (Capa 1):** Nuevo repositorio local SQLite para interpretaciones tradicionales. Se establece la regla de "honestidad", iniciando con 29 entradas como placeholders (`populated=0`) hasta contar con citas verificables de textos fuente clásicos.
- **Intérprete Contextual LLM (Capa 2):** Motor generativo basado en OpenRouter que utiliza un prompt validado con el sistema de Morinus, considerando dignidades, secta, estado natal y factores accidentales para generar interpretaciones ricas y consistentes en JSON.
- **Dignidades Esenciales Ptolemaicas:** Nuevo `EssentialDignityEngine` para evaluar domicilios, exaltaciones, términos egipcios, decanatos caldeos y secta diurna/nocturna.
- **Gestión de Caché e Invalidación:** Tabla `user.db` con soporte de versionado de prompts (`prompt_version`), permitiendo una invalidación inmediata y sin estado tras ajustes en el modelo de lenguaje.
- **UI Completa en SwiftUI:**
  - Nueva barra de filtros y línea de tiempo horizontal dinámica (color por polaridad, altura por peso del aspecto).
  - Panel maestro de detalles con desglose Técnico (Speculum y períodos de activación), Corpus y Contextual.
  - Ajustes de usuario guardados en `UserDefaults` para seleccionar proyección y clave por defecto.
- **Sistema de Migraciones SQL:** Runner idempotente integrado en `AppState` para ejecutar migraciones progresivas `001_*` y `002_*`.
- **Ejemplo End-to-End validado:** Carta de Eduardo procesada con éxito (ASC ♊ 00°32', MC ♒ 07°38', RAMC 310.058°). Validada la asimetría entre direcciones directas y conversas, incluyendo desglose del Speculum completo e interpretación generativa de muestra.

### Añadido

- Rueda natal interactiva en SwiftUI con signos, casas, planetas, ASC/MC y líneas de aspecto.
- Modo "Lectura" con triada Sol/Luna/ASC, regente del Ascendente, casas angulares, aspectos dominantes y síntesis editable.
- Entrada "Lectura" en la navegación principal.
- Entrada "Sinastría" en la navegación principal.
- Entrada "Revolución Solar" en la navegación principal.
- Motor de sinastría para dos cartas guardadas, con cálculo de aspectos A→B y B→A.
- Motor de revolución solar con `swe_solcross_ut`, carta anual por lugar y superposición natal/solar.
- Modelos `SynastryAspect` y `SynastryReading`.
- Modelos `SolarReturnRequest`, `SolarReturnReading` y planetas de revolución en casas natales.
- Lookup de corpus `tipo='sinastria'` con claves `SYN_<PLANETA_A>_<PLANETA_B>_<ASPECTO>`.
- Rueda doble de sinastría con planetas A/B y líneas de aspecto.
- Botón para crear nota de sinastría directamente en Joplin vía Web Clipper local.
- Botón para crear nota de revolución solar directamente en Joplin vía Web Clipper local.
- Configuración de Joplin en Ajustes: host, puerto, token y cuaderno.
- Autodetección del token local de Joplin desde `ASTROMALIK_JOPLIN_TOKEN` o settings de Joplin Desktop.
- Botón rápido claro/oscuro en la cabecera lateral.
- Diagnóstico de Horaria: Python detectado, versión, fuente del módulo, path y último error.
- Archivo de cartas con notas, etiquetas y búsqueda por texto/tag.
- Nota Markdown preparada para Joplin desde la vista de carta.
- Timeline de tránsitos con barras diarias de intensidad por orbe, eje temporal adaptable, eje de fechas fijo y apertura del detalle al pulsar.
- Tests de `swe_houses_ex2`, cancelación de tránsitos, timeline de intensidad, timezones conocidos, diagnóstico de Horaria, corpus/motor de sinastría, revolución solar y payload Joplin.

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

## \[0.3.0\] — 2026-04-19

### Añadido
- Tránsitos accesible desde el sidebar principal, al mismo nivel que "Nueva Carta" y "Cartas Guardadas"
- Picker segmentado en la vista de Tránsitos para elegir entre múltiples cartas guardadas
- Estado vacío con mensaje claro cuando no hay cartas guardadas al entrar en Tránsitos

### Cambiado

- Eliminado el botón de Tránsitos de la toolbar de `NatalChartView` — la funcionalidad vive ahora en la navegación principal

## \[0.2.0\] — 2026-04-17

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

## \[0.1.0\] — marzo/abril 2026

### Añadido

- Port inicial desde Python (pyswisseph) a Swift + target C `CSwissEph`
- UI básica SwiftUI: formulario de nacimiento, vista de carta, lista de interpretaciones
- Tests de sanity sobre carta de referencia (1976-10-11 20:33 Europe/Madrid)
- Persistencia local con `SQLiteDB` propio (sin GRDB)
- Corpus `corpus.db` con 1.766 interpretaciones
- Búsqueda de lugares: seed offline + Nominatim
- Eliminación completa de la dependencia GRDB (reemplazada por sqlite3 del sistema)
