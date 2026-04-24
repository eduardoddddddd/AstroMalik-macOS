# Arquitectura de AstroMalik-macOS

AstroMalik-macOS es una app nativa SwiftUI de ventana única. El objetivo actual es uso pro personal: lectura natal guiada, archivo local, tránsitos y horaria integrada sin cuentas ni telemetría.

## Ventana Única

La app usa un solo `WindowGroup` con `NavigationSplitView`. La sidebar decide la sección y el panel derecho contiene el flujo activo:

- Nueva Carta
- Cartas Guardadas
- Lectura
- Tránsitos
- Horaria

La arquitectura multi-ventana experimental se retiró. Las cartas y consultas se abren dentro del detalle principal, y el estado vivo queda en `AppState`.

## Estado De Aplicación

`AppState` mantiene navegación, tema, carta natal activa y estado persistente de tránsitos. `UserStore` y `HoraryStore` publican datos desde `user.db`.

El archivo de cartas admite metadatos locales:

- notas por carta
- etiquetas
- búsqueda por nombre, fecha, lugar, etiqueta o nota

Joplin se trata como destino de salida de lectura. La app genera una nota Markdown lista para pegar en Joplin.

## Motores Astronómicos

`AstroEngine` usa Swiss Ephemeris embebido como target C. Las casas se calculan con `swe_houses_ex2`, capturando código de retorno y mensaje `serr`; esto deja preparada la lectura futura de velocidades de cúspides y ángulos.

La hora local IANA se convierte a JD UT en `JulianDay.swift`. UTC se resuelve sin force unwraps y los errores de fecha/hora/zona se propagan como `LocalizedError`.

## Tránsitos

`TransitEngine` calcula eventos por rango de fechas y agrupa días contiguos por tránsito/aspecto/punto natal. El loop trabaja con `Date` y calendario UTC; los strings ISO se materializan al crear el resultado final.

Cada `TransitEvent` conserva el resumen interpretativo del tránsito y una serie `samples` con fecha, orbe e intensidad diaria normalizada (`1 - orb / maxOrb`). El score 1–5 ★ sigue siendo la fuerza global del evento, mientras que las muestras permiten dibujar la curva temporal real hacia el aspecto exacto.

La vista de tránsitos:

- muestra una timeline superior (`TransitTimelineView`) con barras diarias por intensidad y color de aspecto
- mantiene la tabla inferior para lectura rápida de evento, estrellas, periodo, orbe y disponibilidad de texto
- abre el mismo detalle textual al pulsar una fila de la timeline o una fila de tabla
- conserva resultados al cambiar de sección
- marca resultados como pendientes de recalcular si cambian fechas, carta o Luna
- cancela cálculos en curso al abandonar la vista o lanzar otro cálculo
- muestra errores controlados para rango inválido, rango excesivo o cancelación

## Horaria

Horaria sigue ejecutándose mediante Python, pero ya no depende de un path local hardcodeado. La resolución busca:

1. módulo `horaria` embebido en el bundle, si existe
2. `ASTROMALIK_HORARIA_PATH`
3. ruta guardada en configuración local
4. paquete `horaria` instalado en el Python detectado

`ASTROMALIK_PYTHON_PATH` permite fijar un Python concreto. La pantalla de diagnóstico de Horaria muestra Python, versión, fuente del módulo, path real y último error.

La dirección futura preferente es portar el núcleo de Horaria a Swift o empaquetar un runtime Python controlado dentro del `.app`.

## UI De Lectura

`NatalChartView` ofrece tres modos:

- **Rueda**: rueda natal interactiva en SwiftUI con signos, casas, planetas, ASC/MC y aspectos.
- **Lectura**: lectura guiada con triada Sol/Luna/ASC, regente del Ascendente, casas angulares, aspectos dominantes y síntesis editable.
- **Textos**: corpus expandible de interpretaciones.

La nota de lectura se genera desde `ReadingNoteBuilder` como Markdown.

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
- `swe_houses_ex2`
- rangos/cancelación de tránsitos
- muestras diarias de timeline y pico de intensidad en fecha exacta
- timezones conocidos
- diagnóstico de Horaria
- paridad de Horaria con casos de referencia
