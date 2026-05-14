# Changelog

Todas las novedades reseñables se documentan aquí. El formato sigue [Keep a Changelog](https://keepachangelog.com/es-ES/1.1.0/) y el versionado sigue [SemVer](https://semver.org/lang/es/).

## \[1.0.0\] — 2026-05-14

Primera release mayor. AstroMalik pasa de prototipo avanzado a app de astrología tradicional completa con motor de informes profesional.

### Añadido — Predictivas helenísticas y clásicas

- **Profecciones anuales** (helenístico): casa anual desde el Ascendente en signos enteros, Lord of the Year, sub-profecciones mensuales y diarias, activaciones del año por tránsitos al LotY. Motor `ProfectionEngine`, vista dedicada y exportación a Joplin.
- **Arco solar** (real y Naibod): direcciones del Sol progresado a puntos natales, integradas como pestaña hermana de Direcciones Primarias. Reutiliza el sistema de pesos clásico.
- **Progresiones secundarias** completas: planetas, declinaciones, MC y ASC progresados (Naibod o Bija), aspectos prog→natal y prog→prog con bisección, fase lunar progresada, Luna progresada por casa y signo, estaciones progresadas y cambios destacados ±5 años.
- **Firdaria persas** (Abu Maʿshar / Bonatti): ciclo de 75 años con períodos mayores y menores, distinción día/noche, vista de timeline y exportación Joplin.
- **Sect Engine** compartido: secta diurna/nocturna, luminaria, benéficos y maléficos de secta, reusable por todos los módulos.
- **Zodiacal Releasing** (Valens) sobre los lotes de **Espíritu** y **Fortuna**: niveles L1 (años) y L2 (meses), Loosing of the Bond en Cáncer/Capricornio con salto al signo opuesto del L1 (convención Schmidt), peaks angulares, vista con capítulos y eventos destacados.
- **Lotes helenísticos**: Fortuna, Espíritu, Eros, Necesidad, Victoria, Audacia y Némesis con fórmulas Paulus Alexandrinus e inversión día/noche.

### Añadido — Análisis natal extendido

- **Almuten Figuris** (Ibn Ezra) sobre Sol, Luna, ASC, Lote de Fortuna y sicigia prenatal, con bonificaciones Lilly +12 (regente del día, hora planetaria caldea con horas desiguales y orientalidad).
- **Regente de la geniture**: domicilio de la luminaria de secta con sus dignidades esenciales.
- **Configuraciones aspectuales** detectadas: T-cuadrada, gran trígono, yod, gran cruz, kite y rectángulo místico.
- **Distribución** por elemento, modalidad, hemisferio y cuadrante con detección de singletons.
- **Recepciones mutuas** (domicilio, exaltación, mixtas).
- **Antiscia y contraantiscia** sobre eje solsticial y aspectos antiscia.
- **Declinaciones**: paralelos, contraparalelos y planetas fuera de límites (OOB).
- **Estrellas fijas**: catálogo en J2000 con precesión simple sobre planetas, ASC, MC y Lote de Fortuna.

### Añadido — Motor cross-personal

- **CrossPersonalEngine**: sintetizador determinista que consume todos los motores predictivos y el análisis natal extendido, produce un `CrossPersonalState` con cuatro capas temporales (anual, medio plazo, corto plazo, lunar) y una cola de prioridad por convergencia entre capas. Bonificaciones por LotY, luminaria de secta, regente de la geniture y coincidencia con peak ZR.
- **CrossPersonalAssembler**: orquestador que invoca los engines reales y rellena los inputs del sintetizador.
- Vista cross-personal con selector de capas, top topics y exportación.

### Añadido — Integración Anthropic

- **AnthropicClient** (actor) para la Messages API con prompt caching efímero, resolución de API key por Keychain (`com.astromalik.anthropic`) y fallback a `ANTHROPIC_API_KEY`.
- **CrossPersonalNarrativeBuilder**: redacta el informe cross-personal en Markdown con Sonnet 4.6 por defecto o Opus 4.7 opcional. Plantilla del prompt en español con doctrina helenística/tradicional informada.
- Modos de alcance configurables: completo, anual, mensual, semanal.
- Trazabilidad por llamada con coste estimado en USD para Sonnet 4.6, Opus 4.7 y Haiku 4.5.

### Añadido — CLI y scheduling

- Binario `astromalik-cli` que ejecuta toda la cadena cross-personal desde línea de comandos: chart por nombre o UUID, scope, modelo, destino (stdout, file, joplin:Notebook).
- LaunchAgent recipes para Sábado 18:00 (semanal) y día 1 a las 09:00 (mensual).

### Añadido — Informes PDF profesionales

- **Infraestructura PDF** basada en HTML+CSS renderizado por `WKWebView.createPDF`: actor `ReportRenderer`, `TemplateEngine` Mustache-like sin dependencias, `ReportTheme` (EB Garamond serif + Inter sans + paleta marfil/tinta/azul noche/dorado), partials de layout/cover/TOC, CSS imprimible con page breaks controlados.
- **Renderers SVG vectoriales**: rueda natal con lanes para evitar solapamiento, rueda doble (sinastría y retornos), timelines (tránsitos, ZR, Firdaria) y tabla de efemérides diaria.
- **14 informes PDF**: natal, sinastría, análisis natal extendido, horaria, tránsitos, revolución solar, revolución lunar, calendario/efemérides, resumen mensual, profecciones, direcciones primarias, arco solar, progresiones, Firdaria, Zodiacal Releasing.
- **Informe cross-personal PDF**: combina narrativa Anthropic dividida por encabezado con datos estructurados del sintetizador en modo híbrido (con o sin redacción).
- Convertidor Markdown→HTML interno para incrustar narrativa en las plantillas.

### Cambiado — Empaquetado

- `Package.swift` refactorizado en módulo compartido `AstroMalik` + ejecutable GUI `AstroMalikApp` + ejecutable headless `astromalik-cli`. El CLI no arrastra SwiftUI.
- `.gitignore` reforzado contra secretos: ignora `.claude/`, `.env*`, `*.secret`, `secrets/`, `**/anthropic*.key`, `**/openrouter*.key` y variantes.

### Doctrinal

- Profecciones implementan **whole sign** desde el Ascendente (helenístico canónico), no cúspides cuadrantes.
- Zodiacal Releasing aplica Loosing of the Bond solo en L2 (versión spec; LB en L3/L4 quedará para versiones futuras si se demanda).
- Sect Engine consolidado y reutilizado por todos los motores que lo necesitan; sin duplicación de la regla diurnal/nocturnal.

## \[Unreleased\]

### Añadido

- Módulo completo de Calendario/Efemérides accesible desde la sidebar, con vista mensual, detalle diario y tabla clásica de posiciones.
- Motor `EphemerisEngine` con calculadores de lunaciones, cuartos, eclipses, estaciones planetarias, ingresos en signo, Luna vacía de curso y aspectos mundanos.
- Efeméride diaria a 00:00 UTC con 10 planetas, Nodo Norte, velocidades, retrogradación y fase lunar.
- Exportación mensual de Efemérides a Joplin mediante `EphemerisNoteBuilder`, con eventos por tipo y mini tabla diaria.
- Nueva pestaña **Resumen** en Efemérides: resumen predictivo mensual personalizado por carta natal, con lunaciones/eclipses en casas natales, conjunciones a planetas natales, estaciones directas sobre la carta, top de tránsitos activos, ingresos por casa y exportación propia a Joplin.
- Tests focalizados para el módulo de Efemérides: lunaciones, eclipses, estaciones, ingresos, Luna vacía, aspectos mundanos y orquestador mensual.
- Tests focalizados para `MonthlySummaryEngine`: casas natales de lunaciones, conjunciones, estaciones, clima mensual y filtrado de tránsitos activos.

- Nodos lunares visibles en la carta natal como cuerpos calculados (`☊ Nodo Norte` y `☋ Nodo Sur`), sin incorporarlos todavía al cálculo de aspectos natales.
- Detección de ingresos por casa en Tránsitos para Marte, Júpiter, Saturno, Urano, Neptuno y Plutón.
- Botón `Ingresos N` en Tránsitos que abre una hoja independiente para consultar ingresos por casa sin alterar el split principal timeline/tabla.
- 72 interpretaciones de corpus para ingresos por casa (`PLANETA_tr_CASA_N_INGRESO`), con detalle clicable y fuente enlazada.
- Script reproducible `scripts/seed_house_ingress_interpretations.py` para regenerar las interpretaciones de ingresos por casa.
- Motor de Horaria nativo en Swift (`HoraryNativeEngine`) con siete planetas tradicionales, casas Regiomontanus, dignidades, recepción, perfección, translación/colección básica y juicio estructurado.
- Campos estructurados en el juicio horario: veredicto, confianza, motivo principal, factores a favor/en contra, advertencias técnicas y rango temporal simbólico.
- Vista de resultado horario reorganizada en tarjetas de veredicto, Luna/curso, factores favorables, bloqueos y notas técnicas.
- Tests de regresión para las 8 consultas horarias guardadas actuales y para el caso de Luna vacía al final de signo.
- Documento `docs/HORARY_NATIVE.md` con arquitectura, contrato y modo legado Python.
- Corpus completo de 165 interpretaciones de direcciones primarias basado en Lilly, `Christian Astrology` Libro III (1647): 165 verdes, 0 amarillas, 0 pendientes.
- Vista "Lista profesional" para Direcciones Primarias con tabla nativa ordenable, columnas densas y selección sincronizada con el detalle.
- Vista "Año en curso" con selector anual, ventana residual de ±18 meses y tarjetas cronológicas con texto principal abreviado.
- Tabla de Espéculo Regiomontano completo en el detalle, resaltando prómissor y significador.
- Presets de filtro para Direcciones Primarias (Clásico/Extendido/Completo) con exclusión de transpersonales en modo clásico.
- Sistema de peso por dirección (crítica/mayor/moderada/menor) con jerarquía visual en timeline, tabla y detalle.
- Filtro por peso mínimo para reducir ruido sin recalcular el motor.

### Cambiado

- Dignidades esenciales: la triplicidad ahora respeta la secta diurna/nocturna; el cooperante sigue contando como regente válido.
- Direcciones Primarias propagan la secta real de la carta al describir dignidades esenciales en el contexto interpretativo.
- Horaria usa Swift nativo por defecto; Python queda como motor legado/fallback forzable con `ASTROMALIK_HORARIA_ENGINE=python`.
- README y documentación de arquitectura actualizados para reflejar Horaria nativa, Direcciones Primarias, corpus clásico, revoluciones y el flujo real de Joplin.
- Reorganizada la UI de Direcciones Primarias en header compacto, timeline semántico y panel maestro con tabs.
- Rediseñado el detalle de una dirección con hero permanente, texto principal priorizado, alternativos bajo demanda, factores morinistas y datos técnicos en tabla estricta.
- El banner de honestidad del corpus pasa a popover informativo en el header.
- El plano por defecto de direcciones pasa a zodiacal con migración de `UserDefaults` a versión 2.
- El default para usuarios nuevos de Direcciones Primarias pasa al preset Clásico.
- El tooltip del timeline muestra dirección del movimiento, edad compacta, tipo y peso.
- El banner superior de Direcciones Primarias muestra preset activo y conteo de direcciones críticas visibles.

### Corregido

- Exilio de planetas con dos domicilios: Mercurio, Venus, Marte, Júpiter y Saturno ya detectan correctamente sus dos signos de exilio.
- Tránsitos: la nueva funcionalidad de ingresos por casa ya no rompe el layout principal; se consulta desde modal dedicado.
- La Luna fuera de curso ya no puede producir una perfección directa si el aspecto exacto ocurre después del cambio de signo.
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
- **Intérprete Contextual LLM (Capa 2):** Motor generativo local basado en Foundry Local y `qwen2.5-7b` que utiliza un prompt validado con el sistema de Morinus, considerando dignidades, secta, estado natal y factores accidentales para generar interpretaciones ricas y consistentes en JSON.
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
