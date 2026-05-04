# Arquitectura de AstroMalik-macOS

AstroMalik-macOS es una app nativa SwiftUI de ventana única. El objetivo actual es uso pro personal: lectura natal guiada, sinastría, revoluciones solar/lunar, archivo local, tránsitos, calendario/efemérides, direcciones primarias y horaria nativa, sin cuentas ni telemetría.

## Ventana Única

La app usa un solo `WindowGroup` con `NavigationSplitView`. La sidebar decide la sección y el panel derecho contiene el flujo activo:

- Nueva Carta
- Cartas Guardadas
- Lectura
- Sinastría
- Revolución Solar
- Revolución Lunar
- Tránsitos
- Efemérides
- Direcciones Primarias
- Horaria

La arquitectura multi-ventana experimental se retiró. Las cartas y consultas se abren dentro del detalle principal, y el estado vivo queda en `AppState`.

## Estado De Aplicación

`AppState` mantiene navegación, tema, configuración de Joplin, carta natal activa y estado persistente de tránsitos. `UserStore` y `HoraryStore` publican datos desde `user.db`.

El archivo de cartas admite metadatos locales:

- notas por carta
- etiquetas
- búsqueda por nombre, fecha, lugar, etiqueta o nota

Joplin se trata como destino de salida de lectura. La lectura natal genera una nota Markdown lista para pegar en Joplin; Sinastría, Revolución Solar, Revolución Lunar, Efemérides y Direcciones Primarias crean notas directas mediante Web Clipper local.

## Motores Astronómicos

`AstroEngine` usa Swiss Ephemeris embebido como target C. Las casas se calculan con `swe_houses_ex2`, capturando código de retorno y mensaje `serr`; esto deja preparada la lectura futura de velocidades de cúspides y ángulos.

La hora local IANA se convierte a JD UT en `JulianDay.swift`. UTC se resuelve sin force unwraps y los errores de fecha/hora/zona se propagan como `LocalizedError`.

## Sinastría

La sinastría se implementa sobre cartas guardadas. `AstroEngine.computeSynastryAspects(chartA:chartB:)` calcula los aspectos de los 10 planetas en ambas direcciones, A→B y B→A, usando `ASPECT_DEFS` y la misma diferencia angular que natal/tránsitos.

Cada `SynastryAspect` conserva:

- dirección (`aToB` o `bToA`)
- planeta origen y planeta destino
- aspecto, orbe y clave de corpus
- interpretación opcional

Las claves se generan como:

```text
SYN_<PLANETA_A>_<PLANETA_B>_<ASPECTO>
```

`CorpusStore.lookupSynastry` filtra `tipo = 'sinastria'` y `buildSynastryReading` hidrata los aspectos con textos. El corpus contiene 420 textos de sinastría: 84 pares ordenados por 5 aspectos clásicos. Las ausencias esperadas son planeta consigo mismo y pares entre Urano/Neptuno/Plutón en ambas direcciones.

`SynastryView` muestra dos pickers de cartas guardadas, cálculo manual, resumen de cobertura, lista agrupada por dirección y rueda doble A/B. El toggle “Mostrar sin texto” afecta a la lista y a las líneas dibujadas: los aspectos sin texto aparecen atenuados cuando se muestran.

## Revolución Solar

`SolarReturnEngine` calcula el retorno exacto del Sol con `swe_solcross_ut`. El punto de partida es el 1 de enero UTC del año solicitado; la longitud objetivo es la longitud natal del Sol. El JD exacto no depende del lugar, pero la carta anual sí se levanta con las coordenadas donde la persona estará ese año.

`SolarReturnReading` conserva carta natal, carta anual, JD exacto, fecha/hora local y UTC, casa natal donde caen ASC/MC de revolución, planetas de revolución por casas natales, aspectos dominantes e interpretaciones reutilizadas del corpus natal.

`SolarReturnView` usa una carta guardada, año y buscador de lugar. El resultado ofrece pestañas de rueda solar, superposición natal/solar, lectura técnica y textos. La v1 no persiste revoluciones solares en `user.db`; el archivo profesional del informe se hace creando una nota Joplin directa.

## Revolución Lunar

`LunarReturnEngine` calcula retornos sucesivos de la Luna a su longitud natal con `swe_mooncross_ut`. Cada evento conserva JD exacto, fecha local/UTC, carta de retorno, Luna de retorno, ASC/MC de retorno y casas natales donde caen los ángulos.

La lectura resume foco lunar por casa, tono del Ascendente, intensidad mensual y estadísticas del periodo. La vista expone métricas técnicas y permite crear una nota Joplin directa del ciclo lunar.

## Efemérides

El módulo de Calendario/Efemérides muestra el cielo general, no el cielo respecto a una carta natal. Vive en `Sources/AstroMalik/Engine/Ephemeris/` y se compone de calculadores puros sobre Swiss Ephemeris:

- `LunationCalculator`: Luna Nueva, Luna Llena, cuartos y fase lunar diaria.
- `EclipseCalculator`: eclipses solares y lunares globales, tipo y magnitud cuando Swiss Ephemeris la devuelve.
- `StationCalculator`: estaciones directas/retrógradas por cruce de velocidad eclíptica = 0.
- `SignIngressCalculator`: ingresos en signo, incluyendo retrocesos por retrogradación; la Luna se incluye solo bajo demanda para evitar ruido.
- `VoidOfCourseCalculator`: Luna vacía de curso desde el último aspecto ptolemaico hasta el ingreso lunar siguiente.
- `MundaneAspectCalculator`: aspectos mundanos exactos entre planetas en tránsito, con Luna opcional para vistas diarias futuras.
- `EphemerisEngine`: orquestador mensual y tabla diaria de efemérides.

`EphemerisEngine.computeMonth(year:month:timezone:)` ejecuta los calculadores secuencialmente. Esta decisión es deliberada: `CSwissEph`/Swiss Ephemeris mantiene estado global y las búsquedas de eclipses no son seguras en concurrencia; paralelizarlas con `async let` provocó un crash `signal 11` en tests.

La tabla diaria usa posiciones a las **00:00 UTC**, convención estándar de efemérides, e incluye 10 planetas más Nodo Norte verdadero. `DailyEphemerisRow` conserva longitud, signo, velocidad, retrogradación y fase lunar.

La UI `EphemerisCalendarView` se integra en la sidebar como “Efemérides”, después de Tránsitos. Ofrece vista calendario mensual, detalle del día seleccionado, vista de tabla clásica y exportación directa a Joplin mediante `EphemerisNoteBuilder`.

## Tránsitos

`TransitEngine` calcula eventos por rango de fechas y agrupa días contiguos por tránsito/aspecto/punto natal. El loop trabaja con `Date` y calendario UTC; los strings ISO se materializan al crear el resultado final.

Cada `TransitEvent` conserva el resumen interpretativo del tránsito y una serie `samples` con fecha, orbe e intensidad diaria normalizada (`1 - orb / maxOrb`). El score 1–5 ★ sigue siendo la fuerza global del evento, mientras que las muestras permiten dibujar la curva temporal real hacia el aspecto exacto.

La vista de tránsitos:

- muestra una timeline superior (`TransitTimelineView`) con barras diarias por intensidad y color de aspecto
- mantiene fijo el eje de fechas al hacer scroll vertical por los eventos
- expande el eje temporal para ocupar todo el ancho disponible cuando el rango cabe en pantalla
- mantiene la tabla inferior para lectura rápida de evento, estrellas, periodo, orbe y disponibilidad de texto
- abre el mismo detalle textual al pulsar una fila de la timeline o una fila de tabla
- conserva resultados al cambiar de sección
- marca resultados como pendientes de recalcular si cambian fechas, carta o Luna
- cancela cálculos en curso al abandonar la vista o lanzar otro cálculo
- muestra errores controlados para rango inválido, rango excesivo o cancelación

## Direcciones Primarias

El módulo de Direcciones Primarias vive completo en Swift. `PrimaryDirectionCalculator` implementa proyección Regiomontana, direcciones directas y conversas, claves Naibod/Ptolomeo/Brahe, plano zodiacal y modo eclíptico de compatibilidad. `PrimaryDirectionsService` orquesta cálculo, corpus, interpretación contextual y note builder.

El UI se organiza en header compacto, timeline semántico, panel maestro con tabs y detalle profesional. El preset Clásico es el default para usuarios nuevos y reduce ruido excluyendo transpersonales; los presets Extendido/Completo permiten ampliar el universo. El detalle incluye hero permanente, texto principal priorizado, alternativas bajo demanda, factores contextuales y espéculo Regiomontano completo.

El corpus clásico de direcciones incluye 165 textos poblados desde Lilly, `Christian Astrology`, Libro III. Las migraciones de corpus y usuario son idempotentes y están separadas por `MigrationRunner`.

## Horaria

Horaria es nativa en Swift por defecto. `HoraryNativeEngine` usa `CSwissEph` y el mismo contrato `HoraryResponse`/`HoraryChart`/`HoraryJudgement` que ya consumía la UI, pero sin proceso externo.

El motor nativo calcula:

- siete planetas tradicionales y Nodo Norte verdadero
- casas Regiomontanus
- Parte de Fortuna y Parte del Espíritu
- hora planetaria y radicalidad
- dignidades esenciales y accidentales
- vía combusta y Luna fuera de curso
- significadores por casa
- recepción simple/mutua
- perfección directa, translación y colección básica
- veredicto estructurado, confianza, factores a favor/en contra y warnings técnicos

La regla doctrinal crítica es que una perfección lunar solo cuenta si el aspecto exacto ocurre antes de que la Luna salga de signo. Si la Luna está vacía de curso, el motor no acepta una perfección posterior al cambio de signo como “sí” limpio.

`HoraryEngine` conserva el motor Python como legado/fallback temporal:

- sin variable: intenta Swift nativo y cae a Python solo si Swift falla inesperadamente
- `ASTROMALIK_HORARIA_ENGINE=swift`: fuerza Swift y propaga errores
- `ASTROMALIK_HORARIA_ENGINE=python`: fuerza el paquete `horaria` externo

`ASTROMALIK_PYTHON_PATH` y `ASTROMALIK_HORARIA_PATH` solo son relevantes para el modo legado. La pantalla de diagnóstico de Horaria queda como herramienta de compatibilidad Python, no como requisito del flujo normal.

## UI De Lectura

`NatalChartView` ofrece tres modos:

- **Rueda**: rueda natal interactiva en SwiftUI con signos, casas, planetas, ASC/MC y aspectos.
- **Lectura**: lectura guiada con triada Sol/Luna/ASC, regente del Ascendente, casas angulares, aspectos dominantes y síntesis editable.
- **Textos**: corpus expandible de interpretaciones.

La nota de lectura se genera desde `ReadingNoteBuilder` como Markdown.

## Joplin

La app tiene dos caminos de salida hacia Joplin:

- natal: `ReadingNoteBuilder` genera Markdown para copiar/pegar
- sinastría: `SynastryNoteBuilder` genera Markdown y `JoplinClipperService` crea la nota vía Web Clipper
- revolución solar: `SolarReturnNoteBuilder` genera el informe anual y lo envía por el mismo servicio
- revolución lunar: `LunarReturnNoteBuilder` genera el informe mensual y lo envía por el mismo servicio
- efemérides: `EphemerisNoteBuilder` genera el calendario mensual y mini tabla diaria
- direcciones primarias: `PrimaryDirectionsNoteBuilder` genera notas filtradas o de dirección seleccionada

`JoplinClipperService` usa `URLSession` contra el servidor local de Joplin (`127.0.0.1:41184` por defecto). Host, puerto, token y cuaderno viven en `AppState.joplinSettings` y se editan desde Ajustes. Si el token está vacío, el servicio intenta resolverlo desde `ASTROMALIK_JOPLIN_TOKEN` o desde los settings locales de Joplin Desktop (`api.token`). Si el cuaderno no existe, se crea antes de crear la nota.

## Tema

La preferencia de apariencia se mantiene en `UserDefaults` como `Sistema`, `Claro` u `Oscuro`. Además de Ajustes, la sidebar incluye un botón rápido para alternar claro/oscuro sin pasar por el menú de settings.

## Build Y Distribución

El proyecto sigue siendo Swift Package Manager puro. Para desarrollo:

```bash
swift build
open .build/arm64-apple-macosx/debug/AstroMalik
```

Para app de doble clic:

```bash
./scripts/package_app.sh
open AstroMalik.app
```

El script compila release, crea el bundle, copia recursos, firma ad-hoc y elimina cuarentena.

## Validación

La suite cubre:

- carta natal de referencia
- ASC y corpus asociado
- corpus de sinastría, formato de claves y cobertura de 420 textos
- motor de sinastría en ambas direcciones
- lookup de sinastría y generación de nota Markdown
- motor de revolución solar, exactitud del retorno solar y cambio de lugar
- lectura de revolución solar con corpus natal reutilizado
- generación de nota Markdown de revolución solar
- motor de revolución lunar y secuencia ordenada de retornos
- direcciones primarias Regiomontanus, conversas, presets, corpus y goldens
- payload de creación de nota Joplin con cliente HTTP mock
- `swe_houses_ex2`
- rangos/cancelación de tránsitos
- muestras diarias de timeline y pico de intensidad en fecha exacta
- calculadores de Efemérides: lunaciones, eclipses, estaciones, ingresos, Luna vacía de curso, aspectos mundanos y orquestador mensual
- timezones conocidos
- diagnóstico de Horaria legado
- Horaria nativa, JSON legacy y regresión de Luna fuera de curso
