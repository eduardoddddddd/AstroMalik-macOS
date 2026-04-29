# AstroMalik · macOS

AstroMalik-macOS es una app nativa de astrología para macOS, escrita en Swift y SwiftUI, pensada para trabajo astrológico personal/profesional en local. Calcula cartas natales, lecturas guiadas, sinastrías, revoluciones solares y lunares, tránsitos, direcciones primarias y consultas de horaria clásica. Guarda cartas y consultas en una base local, usa Swiss Ephemeris embebido y no requiere cuentas ni servicios externos para los cálculos.

Esta app es la variante nativa de la familia [AstroMalik](https://github.com/eduardoddddddd/AstroMalik). El proyecto web original nació con Python/React; esta versión macOS concentra la experiencia en una app de escritorio Apple Silicon con motores Swift, persistencia SQLite y UI SwiftUI.

![Platform](https://img.shields.io/badge/platform-macOS%2014%2B-blue) ![Swift](https://img.shields.io/badge/Swift-6.0-orange) ![Arch](https://img.shields.io/badge/arch-arm64-green) ![License](https://img.shields.io/badge/license-MIT-lightgrey)

---

## Estado Actual

AstroMalik-macOS ya no depende de Python para Horaria. El módulo horario se calcula por defecto con un motor Swift nativo (`HoraryNativeEngine`) que usa `CSwissEph`, casas Regiomontanus y reglas tradicionales estrictas. El antiguo paquete Python `horaria` queda únicamente como modo legado/fallback para comparación o diagnóstico.

La app empaquetada se genera con:

```bash
./scripts/package_app.sh
open AstroMalik.app
```

Después de cualquier cambio de código o UI, este repo espera regenerar `AstroMalik.app` y comprobar que `AstroMalik.app/Contents/MacOS/AstroMalik` tiene timestamp actualizado.

## Características

- **Carta natal completa**: posiciones planetarias, casas, ASC/MC, aspectos y rueda natal interactiva.
- **Lectura natal guiada**: tríada Sol/Luna/ASC, regente del Ascendente, casas angulares, aspectos dominantes y síntesis editable.
- **Corpus interpretativo local**: textos natales, aspectos, tránsitos, sinastría y corpus clásico de direcciones primarias.
- **Sinastría**: comparación de dos cartas guardadas, aspectos A→B y B→A, rueda doble y notas Joplin.
- **Revolución solar**: retorno exacto con `swe_solcross_ut`, carta anual por lugar, superposición natal/solar y lectura técnica.
- **Revolución lunar**: retornos lunares secuenciales, métricas técnicas y lectura mensual.
- **Tránsitos**: eventos por rango, foco por prioridad, desglose técnico/personal/temporal, motivos compactos, muestras diarias de intensidad y timeline visual.
- **Direcciones primarias**: motor Regiomontano con direcciones directas/conversas, claves Naibod/Ptolomeo/Brahe, presets clásicos y corpus Lilly.
- **Horaria clásica nativa**: juicio horario en Swift, siete planetas tradicionales, Nodo Norte, Partes, dignidades, recepción, perfección y Luna fuera de curso coherente.
- **Archivo local**: cartas y consultas guardadas en `~/Library/Application Support/AstroMalik/user.db`.
- **Joplin directo**: creación de notas desde sinastría, revolución solar/lunar y direcciones, vía Web Clipper local.
- **Búsqueda de lugares**: seed offline + Nominatim/OpenStreetMap.
- **Ventana única**: `NavigationSplitView` con sidebar fija y panel de detalle.
- **Tema configurable**: Sistema, Claro, Oscuro y botón rápido claro/oscuro.
- **Local-first**: cálculos y archivo en el Mac, sin telemetría.

## Stack Técnico

| Capa | Tecnología |
|---|---|
| UI | SwiftUI, macOS 14+, `NavigationSplitView` |
| Efemérides | Swiss Ephemeris en C, target SPM `CSwissEph` |
| Motores | Swift nativo para natal, tránsitos, revoluciones, direcciones y horaria |
| Persistencia | SQLite3 del sistema mediante wrapper propio `SQLiteDB` |
| Corpus | `Resources/corpus.db` + migraciones SQL idempotentes |
| Joplin | Web Clipper local opcional (`127.0.0.1:41184`) |
| Paquete | Swift Package Manager puro, sin paquetes Swift externos |
| Target | macOS 14+, Apple Silicon arm64 |

## Requisitos

- macOS 14 Sonoma o superior
- Xcode 15+ o toolchain Swift 6.0+
- ~50 MB de disco para binario, corpus y efemérides
- Joplin Desktop solo si quieres crear notas directas
- OpenRouter API key solo si quieres interpretaciones contextuales LLM en Direcciones Primarias

### Horaria

Horaria funciona de forma nativa en Swift por defecto y no necesita Python.

Modo normal:

```bash
swift build
open .build/arm64-apple-macosx/debug/AstroMalik
```

Modo legado opcional para comparar con el antiguo paquete Python:

```bash
export ASTROMALIK_HORARIA_ENGINE=python
export ASTROMALIK_PYTHON_PATH=/ruta/a/python3
export ASTROMALIK_HORARIA_PATH=/ruta/al/repo/horaria
```

Modo Swift estricto, útil para tests o depuración:

```bash
export ASTROMALIK_HORARIA_ENGINE=swift
```

La pantalla de diagnóstico de Horaria queda enfocada al modo Python legado. La app no la necesita para calcular en el flujo normal.

### Joplin

Joplin es opcional y se usa como destino de notas. Por defecto:

```text
Host: 127.0.0.1
Puerto: 41184
Cuaderno: AstroMalik
```

El token se puede introducir en Ajustes. Si está vacío, la app intenta resolverlo desde `ASTROMALIK_JOPLIN_TOKEN` o desde los settings locales de Joplin Desktop (`api.token`). Si el cuaderno no existe, lo crea antes de guardar la nota.

### OpenRouter

Direcciones Primarias puede generar interpretaciones contextuales con OpenRouter. La app prefiere key en Keychain; también puede importarla desde una nota local de Joplin o usar `OPENROUTER_API_KEY` como fallback de desarrollo.

## Ejecución

```bash
git clone https://github.com/eduardoddddddd/AstroMalik-macOS.git
cd AstroMalik-macOS
swift build
open .build/arm64-apple-macosx/debug/AstroMalik
```

Para app de doble clic:

```bash
./scripts/package_app.sh
open AstroMalik.app
```

> Nota: ejecutar el target SPM directamente con ▶ en Xcode puede abrir un proceso sin ventana. Usa `open` o el `.app` empaquetado. El proyecto incrusta `Info.plist` en el binario para que macOS lo trate como app GUI regular.

## Tests

```bash
swift test
```

La suite cubre:

- carta natal de referencia y conversión de zonas horarias
- casas con `swe_houses_ex2`
- tránsitos, cancelación, muestras diarias de intensidad, ASC/MC como puntos transitables y bandas de prioridad
- sinastría y corpus `SYN_*`
- revolución solar y lunar
- Joplin con cliente HTTP mock
- direcciones primarias Regiomontanus, conversas, corpus y goldens
- Horaria nativa, compatibilidad JSON legacy y regresión de Luna fuera de curso

## Estructura Del Proyecto

```text
.
├── Package.swift
├── Info.plist
├── Resources/
│   ├── corpus.db
│   ├── cities_seed.json
│   ├── ephe/
│   └── migrations/
├── Sources/
│   ├── CSwissEph/
│   └── AstroMalik/
│       ├── Engine/
│       ├── Horary/
│       ├── Models/
│       ├── Persistence/
│       ├── PrimaryDirections/
│       ├── Services/
│       ├── Store/
│       └── Views/
├── Tests/AstroMalikTests/
├── docs/
└── scripts/
```

Puntos de entrada relevantes:

- `AstroEngine.swift`: carta natal, aspectos, casas y utilidades comunes.
- `HoraryNativeEngine.swift`: motor horario Swift nativo.
- `PrimaryDirectionsService.swift`: cálculo y lectura de direcciones primarias.
- `MigrationRunner.swift`: copia/migración de `corpus.db` y `user.db`.
- `JoplinClipperService.swift`: salida a Joplin Web Clipper.
- `scripts/package_app.sh`: build release, bundle `.app`, firma ad-hoc y quita cuarentena.

## Arquitectura Por Módulo

### Ventana Única

La app usa un único `WindowGroup` con `NavigationSplitView`. La sidebar cambia de sección y el panel derecho conserva el flujo activo. `AppState` centraliza navegación, tema, configuración Joplin, carta activa, stores y estado persistente de tránsitos.

### Natal Y Lectura

`AstroEngine` calcula planetas, casas y aspectos con Swiss Ephemeris. `NatalChartView` combina rueda SwiftUI, lectura guiada y textos del corpus. La lectura natal puede copiar una nota Markdown lista para pegar en Joplin.

### Sinastría

La sinastría requiere dos cartas guardadas. Calcula aspectos en ambas direcciones porque el corpus distingue planeta origen y planeta destino:

```text
SYN_<PLANETA_A>_<PLANETA_B>_<ASPECTO>
```

El corpus contiene 420 textos de sinastría. La UI muestra cobertura textual, lista agrupada por dirección y rueda doble.

### Revolución Solar Y Lunar

La revolución solar calcula el retorno exacto del Sol para un año y un lugar de revolución. La revolución lunar calcula retornos sucesivos de la Luna a su posición natal. Ambas vistas exponen datos técnicos, lectura y salida a Joplin.

### Tránsitos

`TransitEngine` agrupa eventos por rango y guarda muestras diarias con orbe e intensidad normalizada. La UI combina timeline visual y tabla de foco, conserva resultados al cambiar de sección y marca cuándo hay cambios pendientes de recalcular.

La vista distingue cuatro capas:

- **Técnica**: fuerza abstracta del tránsito según planeta transitante, aspecto y orbe.
- **Personal**: cuánto toca la carta natal concreta, incluyendo ASC, MC, regente del Ascendente, luminares y angularidad.
- **Impacto**: duración, repetición, exactitud y concentración temporal.
- **Prioridad**: señal práctica para decidir qué mirar primero, clasificada en Baja, Media, Alta o Crítica.

El documento de referencia del módulo está en [`docs/TRANSITOS_ESTRUCTURA_Y_FUNCIONAMIENTO.md`](docs/TRANSITOS_ESTRUCTURA_Y_FUNCIONAMIENTO.md).

### Direcciones Primarias

El módulo de Direcciones Primarias implementa proyección Regiomontana adaptada de Morinus. Soporta:

- direcciones directas y conversas reales
- plano zodiacal y eclíptico de compatibilidad
- claves Naibod, Ptolomeo y Brahe
- Pars Fortunae opt-in
- presets Clásico, Extendido y Completo
- pesos crítica/mayor/moderada/menor
- vista Lista profesional, Cards y Año en curso
- espéculo Regiomontano completo en el detalle
- corpus clásico poblado desde Lilly, `Christian Astrology`, Libro III
- interpretación contextual opcional con OpenRouter

La política documental del corpus está en `docs/PRIMARY_DIRECTIONS.md` y `docs/primary-directions-corpus-curation.md`.

### Horaria Nativa

Horaria es Swift nativa por defecto. `HoraryNativeEngine` calcula:

- siete planetas tradicionales y Nodo Norte verdadero
- casas Regiomontanus
- Parte de Fortuna y Parte del Espíritu
- dignidades esenciales y accidentales
- hora planetaria y radicalidad
- Luna vía combusta y Luna fuera de curso
- significadores por casa
- recepción simple/mutua
- perfección directa, translación y colección básica
- veredicto estructurado: sí, no, no todavía, dudoso o requiere mediación

La corrección doctrinal más importante es que una perfección lunar solo cuenta si el aspecto exacto ocurre antes de que la Luna salga de signo. Esto evita contradicciones como “Luna vacía” y, a la vez, “perfección por esa misma Luna” después del cambio de signo.

`HoraryEngine` mantiene Python como fallback temporal. Variables:

- `ASTROMALIK_HORARIA_ENGINE=swift`: fuerza Swift y propaga error si falla.
- `ASTROMALIK_HORARIA_ENGINE=python`: fuerza el motor legado Python.
- sin variable: intenta Swift y cae a Python si hay error inesperado.

### Joplin

Joplin es una salida de informes, no un requisito de cálculo. Actualmente crean notas directas Sinastría, Revolución Solar, Revolución Lunar y Direcciones Primarias. Natal conserva copia Markdown.

## Base De Datos Y Recursos

- `Resources/corpus.db`: corpus distribuido con la app.
- `~/Library/Application Support/AstroMalik/user.db`: cartas, consultas y cachés del usuario.
- `Resources/migrations/`: migraciones idempotentes. Las de corpus se aplican sobre una copia writable del corpus; las de usuario sobre `user.db`.
- `Resources/ephe/`: efemérides Swiss `.se1`.

## Roadmap Actual

Completado en abril de 2026:

- app nativa SwiftUI de ventana única
- natal, lectura guiada, tránsitos, sinastría
- revolución solar y lunar
- Joplin Web Clipper
- direcciones primarias Regiomontanus con corpus clásico
- Horaria nativa Swift
- empaquetado `.app`

Siguientes líneas probables:

- pulir export PNG/PDF
- mejorar visualización técnica de Horaria y tabla de aspectos aplicativos
- ampliar corpus clásico verificable
- notarización opcional con Apple Developer ID
- distribución más cómoda para usuarios no técnicos

## Relación Con Otros Repos

- [`AstroMalik`](https://github.com/eduardoddddddd/AstroMalik): variante web Python/FastAPI + React/Vite.
- `AstroMalik-macOS`: este repo, app nativa Swift/SwiftUI para Apple Silicon.

Ambos comparten orientación y parte del corpus, pero el macOS actual ya no es un wrapper de la versión Python: sus motores principales viven dentro de Swift.

## Licencia Y Créditos

Código de aplicación: MIT License.

Swiss Ephemeris © [Astrodienst AG](https://www.astro.com/swisseph/) bajo [Swiss Ephemeris Public License](https://www.astro.com/ftp/swisseph/LICENSE). Si redistribuyes una build comercial, revisa las condiciones de Astrodienst.

Los archivos `.se1` en `Resources/ephe/` son datos de efemérides de Astrodienst y están sujetos a su licencia.

## Autor

Eduardo Arias · [@eduardoddddddd](https://github.com/eduardoddddddd)

Órgiva, Granada · 2026
