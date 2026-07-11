# Changelog

Todas las novedades reseñables se documentan aquí. El formato sigue [Keep a Changelog](https://keepachangelog.com/es-ES/1.1.0/) y el versionado sigue [SemVer](https://semver.org/lang/es/).

## [Unreleased]

Sin cambios documentados todavía.

## [1.1.3] — 2026-07-11

### Mejorado — rectificación profesional

- Caché de efemérides de tránsito por evento y cálculo angular ligero de revoluciones solares, deduplicado por año.
- Comparación opcional y auditable entre los seis sistemas de casas, con sistema ganador y aviso de convergencia o dispersión horaria.
- Fiabilidad del evento incorporada al score y editable como cierta, probable, incierta o informada por terceros.
- Flujo SwiftUI en cinco pasos, formularios adaptables y componentes separados para evitar filas rotas en ventanas estrechas.
- Cobertura por evento y comparación de sistemas visibles en UI, PDF y notas Joplin.
- Política heurística de score centralizada y documentada; eliminado el diagnóstico duplicado que nunca se rellenaba en el resultado.
- Configuración restaurada correctamente al reabrir o importar una sesión.
- Pruebas de caché, fiabilidad, política y evaluación multisistema.

### Validación

- Suite completa: 390 tests, 1 omitido, 0 fallos.

## [1.1.2] — 2026-07-11

### Corregido

- Compatibilidad de compilación entre la versión local de Xcode y el toolchain del runner `macos-14` de GitHub Actions.
- Expresiones numéricas simplificadas y trigonometría tipada explícitamente, sin cambios en los cálculos resultantes.
- Generación automática de la GitHub Release universal verificada desde el propio tag.

## [1.1.1] — 2026-07-11

### Añadido — distribución universal de macOS

- Aplicación universal con ejecutables nativos `arm64` y `x86_64` en un solo `.app`.
- CLI universal para Apple Silicon e Intel.
- Empaquetador independiente `scripts/package_universal_app.sh`; no modifica el `AstroMalik.app` ARM existente.
- Verificador automático de arquitecturas, `Info.plist`, recursos y firma ad-hoc.
- ZIP de distribución y checksum SHA-256 generados en `dist/`.
- Workflow de GitHub Actions que construye artefactos descargables y, al recibir un tag, crea la GitHub Release con ZIP y checksums.
- Guía de instalación para usuarios no técnicos y documentación técnica del build universal.

### Distribución sin cuenta de pago de Apple

- Se mantiene firma ad-hoc gratuita, sin Developer ID ni notarización.
- La documentación explica la primera apertura mediante las opciones oficiales **Abrir** o **Abrir igualmente**.
- No se recomienda desactivar Gatekeeper globalmente ni ejecutar comandos con `sudo`.

### Validación

- Suite completa: 386 tests, 1 omitido, 0 fallos.
- App y CLI verificados con slices `x86_64 arm64`.
- ZIP descomprimido y firma ad-hoc verificada después del empaquetado.
- CLI ejecutado nativamente en ARM64 y como Intel mediante Rosetta.
- El empaquetador ARM original continúa generando un binario `arm64` independiente.

## [1.1.0] — 2026-07-11

Release menor centrada en la rectificación natal asistida, el CLI local-first y la lectura natal documental.

### Convención de publicación

- Tag recomendado: **`v1.1.0`**.
- No usar `1.1`: omite el componente de parche y es menos consistente con SemVer y con el tag previo `v1.0.0`.
- El tag debe crearse únicamente sobre el commit final validado; esta actualización del changelog no crea el tag.

### Añadido — Rectificación natal asistida (Fases 0–4)

- Nuevo módulo **Rectificación** en Carta Natal, basado en cartas guardadas y cronologías vitales.
- Soporte común `HH:mm` / `HH:mm:ss` con conversión local estricta y compatibilidad con cartas existentes.
- Generador de candidatas coarse/fine, modo de día completo sensible a DST y cancelación cooperativa.
- Scorers iniciales de arco solar, tránsitos a ángulos, direcciones primarias y progresiones secundarias.
- Reglas simbólicas centralizadas por evento, ranking normalizado, clusters y advertencias de resultados inconclusos.
- Modelos Codable versionados, validación del dataset y evidencias técnicas reproducibles.
- Guardado de la candidata principal como carta nueva etiquetada, sin modificar la carta original.
- Tests específicos para segundos, DST, límites, scoring, consolidación y dos cartas de referencia independientes.
- Capa narrativa opcional con contrato común Anthropic/OpenRouter, payload compacto versionado y prompt que prohíbe inventar cálculos.
- Selector explícito de proveedor y trazabilidad de modelo, tokens y coste disponible.
- Persistencia SQLite de sesiones de rectificación, resultados cacheados e historial deduplicado de análisis.
- Reapertura, edición, recálculo y eliminación de sesiones desde el historial de Rectificación.
- Importación y exportación JSON mediante un archivo versionado.
- Informe técnico PDF con candidatas, evidencia, advertencias y trazabilidad narrativa.
- Nota Joplin de rectificación creada únicamente por acción explícita.
- Cuestionario preliminar de Ascendente con cinco preguntas, porcentaje de completitud e hipótesis de signo de baja ponderación.
- Confirmaciones deterministas adicionales por profecciones, Firdaria, Zodiacal Releasing, lotes sensibles a hora y revolución solar.
- Comparación lado a lado de candidatas y distribución visual de clusters horarios.
- Presets de escuela **Tradicional**, **Equilibrada** y **Moderna**, con selección de técnicas y ajuste individual de pesos.
- Configuración de sistema de casas, orbes, planetas modernos, ventana de cluster, penalización de sobreajuste y sensibilidad de la auditoría.
- Diagnóstico anti-overfitting con score bruto, score ajustado, penalización y concentración por evento/técnica.

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

- Validación final de Rectificación: `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift test` — 386 tests, 1 skipped, 0 failures.
- `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer scripts/package_app.sh` ejecutado después de los cambios de código/UI.
- `AstroMalik.app/Contents/MacOS/AstroMalik` verificado con timestamp actualizado: 2026-07-11 00:38:17 CEST.

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
