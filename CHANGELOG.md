# Changelog

Todas las novedades reseñables se documentan aquí. El formato sigue [Keep a Changelog](https://keepachangelog.com/es-ES/1.1.0/) y el versionado sigue [SemVer](https://semver.org/lang/es/).

## [Unreleased] — 2026-06-10

### Añadido — Lectura natal como documento

- Nuevo modelo `NatalReading` como documento de lectura generado determinísticamente.
- Nuevo motor `NatalReadingComposer` para componer capítulos en orden doctrinal: retrato inmediato, tríada, regente del Ascendente, dominantes, aspectos estructurales, casas y síntesis.
- Nuevo cálculo ligero `ChartDistribution` para elementos, modalidades, hemisferios, secta y stelliums.
- Nuevo `ReadingRelevance` para rankear aspectos y planeta dominante con scoring documentado.
- Nuevas plantillas `ReadingTemplates` con frases-puente doctrinales en español.
- Campo `missingKeys` en la lectura para auditar huecos del corpus sin romper la UI.
- Tests específicos para composer, distribución, relevancia, regencias, orden de capítulos, corpus faltante y determinismo.

### Añadido — UI de lectura rediseñada

- Nueva vista `NatalReadingView` como documento continuo, no panel de botones.
- Nuevos componentes `ReadingBlockView`, `ReadingChapterView`, `ReadingTOCView` y `ReadingTypography`.
- La Lectura natal arranca ahora en densidad **Completa** para mostrar el texto del corpus desde el primer momento.
- En modo Lectura, `NatalChartView` oculta el panel técnico izquierdo y dedica todo el ancho al documento.
- Navegación por capítulos mediante chips horizontales compactos.
- Hero superior con datos principales de la carta: nombre, fecha/hora, lugar, ASC, MC, Sol y Luna.
- Buscador dentro del corpus visible de la lectura.
- Editor de síntesis ampliado y situado como cierre del documento.

### Añadido — Persistencia y exportación

- Nuevo `ReadingNotesStore` con tabla SQLite `reading_notes` en `user.db` para persistir síntesis por carta.
- Autosave con debounce desde `NatalReadingView` y guardado al salir.
- Nuevo `ReadingNoteBuilder` como serializador Markdown de `NatalReading`, de modo que la nota Joplin refleja el documento visible.
- Tests de guardado y recarga de síntesis.

### Cambiado

- `NatalDetailMode` elimina el modo natal `Textos`: el corpus queda integrado en la Lectura.
- `GuidedReadingView` fue reemplazada por la nueva lectura documental.
- `InterpretacionesView` fue eliminada.
- `SolarReturnView` ya no depende de `InterpretacionesView`; conserva una vista local propia para sus textos.
- README reescrito de cero para describir el producto actual y mover detalle histórico/técnico a documentación y changelog.
- `docs/ARCHITECTURE.md` actualizado para reflejar el composer de lectura, persistencia y nota Markdown.
- `HelpView` actualizado con la nueva descripción de Lectura.

### Eliminado

- Antigua lectura guiada basada en tarjetas clicables sin texto visible.
- Pestaña natal plana de textos en acordeón.

### Validación

- `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift test` — 344 tests, 1 skipped, 0 failures.
- `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer scripts/package_app.sh` ejecutado tras cambios UI.
- `AstroMalik.app/Contents/MacOS/AstroMalik` verificado con timestamp actualizado: 2026-06-10 11:08:54.

## [1.0.0] — 2026-05-14

Primera release mayor. AstroMalik pasó de prototipo avanzado a app de astrología tradicional completa con motores predictivos, análisis natal extendido, horaria nativa, informes PDF y CLI.

### Añadido

- Predictivas clásicas/helenísticas: profecciones, arco solar, progresiones secundarias, Firdaria, Sect Engine y Zodiacal Releasing.
- Análisis natal extendido: lotes, Almuten Figuris, regente de la genitura, configuraciones, distribución, recepciones, antiscia, declinaciones y estrellas fijas.
- CrossPersonalEngine y CrossPersonalAssembler para síntesis predictiva por capas.
- Integración Anthropic opcional para narrativa cross-personal.
- CLI `astromalik-cli` para flujos headless y LaunchAgent.
- Infraestructura PDF profesional basada en HTML/CSS, WebKit y SVG.
- Informes PDF para natal, sinastría, extendido, horaria, tránsitos, retornos, calendario, resumen mensual, profecciones, direcciones, arco solar, progresiones, Firdaria y ZR.

### Cambiado

- `Package.swift` reorganizado en módulo compartido `AstroMalik`, ejecutable GUI `AstroMalikApp` y ejecutable headless `astromalik-cli`.
- Sidebar reorganizado por flujo de trabajo del astrólogo.
- Horaria usa Swift nativo por defecto; Python queda como legado/fallback.
- Direcciones Primarias recibieron vista profesional, presets, pesos, espéculo y corpus clásico.
- README y documentación técnica actualizados para la release 1.0.

### Corregido

- Triplicidad por secta en dignidades esenciales.
- Exilios de planetas con dos domicilios.
- Luna fuera de curso en horaria: no se acepta perfección posterior al cambio de signo.
- Direcciones conversas, clave Brahe, RAMC con `swe_sidtime0` y Pars Fortunae opt-in.
- Layout de ingresos por casa en Tránsitos.

## [0.4.0] — 2026-04-27

### Añadido

- Primer módulo completo de Direcciones Primarias.
- Corpus y política de honestidad para interpretaciones clásicas.
- Intérprete contextual local experimental con Foundry Local.
- Rueda natal interactiva.
- Lectura guiada inicial.
- Sinastría.
- Revolución solar.
- Integración inicial Joplin.
- Archivo de cartas con notas, etiquetas y búsqueda.
- Timeline de tránsitos.

### Cambiado

- Arquitectura consolidada en ventana única.
- Tránsitos conserva estado por carta y mejora cancelación de tareas largas.
- Cálculo de casas migrado a `swe_houses_ex2`.

## [0.3.0] — 2026-04-19

### Añadido

- Tránsitos accesibles desde sidebar principal.
- Picker segmentado para múltiples cartas guardadas.
- Estado vacío cuando no hay cartas guardadas.

### Cambiado

- El botón de Tránsitos salió de la toolbar natal y pasó a navegación principal.

## [0.2.0] — 2026-04-17

### Añadido

- Atajo ⌘↩ en formulario de nacimiento.
- Feedback visual tras calcular carta.
- `Info.plist` embebido en el binario.
- `docs/ARCHITECTURE.md` inicial.
- Este changelog.

### Cambiado

- `NatalChartView` pasó de sheet a contenido de ventana completa.
- Ventana principal redimensionable con mínimos e ideales.

### Corregido

- Bug crítico de arranque por aislamiento de actor en Swift 6.
- Force unwraps y warnings iniciales.

## [0.1.0] — marzo/abril 2026

### Añadido

- Port inicial de Python/pyswisseph a Swift + `CSwissEph`.
- UI SwiftUI básica.
- Tests de sanity sobre carta de referencia.
- Persistencia local SQLite sin GRDB.
- Corpus `corpus.db` inicial.
- Búsqueda de lugares offline + Nominatim.
