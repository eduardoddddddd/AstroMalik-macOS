# Changelog

Todas las novedades reseñables se documentan aquí. El formato sigue [Keep a Changelog](https://keepachangelog.com/es-ES/1.1.0/) y el versionado sigue [SemVer](https://semver.org/lang/es/).

## [Unreleased] — 2026-06-13

### Añadido — Rectificación natal determinista (Fases 0 y 1)

- Nuevo módulo **Rectificación** en Carta Natal, basado en cartas guardadas y cronologías vitales.
- Soporte común `HH:mm` / `HH:mm:ss` con conversión local estricta y compatibilidad con cartas existentes.
- Generador de candidatas coarse/fine, modo de día completo sensible a DST y cancelación cooperativa.
- Scorers iniciales de arco solar, tránsitos a ángulos, direcciones primarias y progresiones secundarias.
- Reglas simbólicas centralizadas por evento, ranking normalizado, clusters y advertencias de resultados inconclusos.
- Modelos Codable versionados, validación del dataset y evidencias técnicas reproducibles.
- Guardado de la candidata principal como carta nueva etiquetada, sin modificar la carta original.
- Tests específicos para segundos, DST, límites, scoring, consolidación y dos cartas de referencia independientes.

### Añadido — CLI local-first para agentes y scripts

- `astromalik-cli` pasa a ser una interfaz local, determinista y usable por terminal, scripts y agentes LLM externos sin llamadas externas por defecto.
- Defaults seguros: `--format json`, `--output stdout`, `--narrative none`, `--no-network`.
- Nuevos subcomandos principales: `charts list`, `chart show`, `natal`, `transits`, `monthly`, `weekly` y `cross-personal`.
- Subcomandos predictivos adicionales: `profections`, `firdaria`, `zodiacal-releasing`, `progressions`, `solar-return`, `lunar-return`, `primary-directions` y `solar-arc`.
- Salida JSON estable para agentes con `metadata`, `technicalData`, `events`, `interpretations`, `warnings`, `source` y `networkUsed`.
- Salida Markdown determinista y legible directamente, basada en corpus local y plantillas.
- Compatibilidad con el comando antiguo sin subcomando como alias de `cross-personal`.
- Flags globales antes o después del subcomando, incluyendo `--format`, `--output`, `--user-db`, `--corpus-db`, `--verbose`, `--no-network`, `--allow-network` y `--narrative`/`--llm`.

### Seguridad — CLI sin red por defecto

- `AnthropicClient` ya no se instancia de forma obligatoria en el flujo cross-personal.
- La narrativa Anthropic solo se permite con `--narrative anthropic --allow-network` explícitos.
- OpenRouter queda igualmente protegido por `--allow-network` y no puede ejecutarse accidentalmente.
- La salida Joplin requiere `--allow-network` porque usa el Web Clipper local.
- Mensaje de fallo seguro para Anthropic sin permiso: “La narrativa Anthropic requiere --allow-network y --narrative anthropic explícitos.”

### Documentación — CLI

- `docs/CLI.md` actualizado con filosofía local-first, ejemplos seguros para terminal/agentes y ejemplo explícito de IA con coste.
- README actualizado para reflejar el CLI como superficie principal local-first además de la app SwiftUI.

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

- `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift test` — 349 tests, 1 skipped, 0 failures.
- `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift build` ejecutado correctamente.
- `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer scripts/package_app.sh` ejecutado tras cambios de código/CLI.
- `AstroMalik.app/Contents/MacOS/AstroMalik` verificado con timestamp actualizado: 2026-06-13 13:18:07 CEST.

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
