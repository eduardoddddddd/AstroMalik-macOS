# AstroMalik · macOS

![Platform](https://img.shields.io/badge/platform-macOS%2014%2B-blue) ![Swift](https://img.shields.io/badge/Swift-6.0-orange) ![SwiftUI](https://img.shields.io/badge/UI-SwiftUI-0A84FF) ![Swiss Ephemeris](https://img.shields.io/badge/ephemeris-Swiss%20Ephemeris-6f42c1) ![SQLite](https://img.shields.io/badge/storage-SQLite-003B57) ![Foundry Local](https://img.shields.io/badge/AI-Foundry%20Local-7A3EE6) ![Local First](https://img.shields.io/badge/privacy-local--first-2ea44f) ![License](https://img.shields.io/badge/license-MIT-lightgrey)

AstroMalik-macOS es una app nativa de astrología para macOS, escrita en Swift y SwiftUI, pensada para trabajo astrológico personal y profesional en local. Calcula cartas natales, lecturas guiadas, sinastrías, revoluciones solares y lunares, tránsitos, direcciones primarias y consultas de horaria clásica. Guarda cartas y consultas en una base local, usa Swiss Ephemeris embebido y no requiere cuentas ni servicios externos para los cálculos.

La filosofía del proyecto es **local-first**: los datos del usuario viven en su Mac, los cálculos deterministas se hacen dentro de la app y las integraciones externas son opcionales. Joplin se usa como salida documental si el usuario quiere archivar informes; Foundry Local puede añadir redacción contextual local, pero nunca sustituye el cálculo astrológico del motor.

Las cartas y consultas guardadas **no se escriben en el corpus del proyecto**. Viven en la base local del usuario (`~/Library/Application Support/AstroMalik/user.db`), fuera del repositorio Git. Ese fichero no se sube a GitHub salvo que alguien lo copie manualmente dentro del repo y lo añada explícitamente.

Esta app es la variante nativa de la familia [AstroMalik](https://github.com/eduardoddddddd/AstroMalik). El proyecto web original nació con Python/React; esta versión macOS concentra la experiencia en una app de escritorio Apple Silicon con motores Swift, persistencia SQLite, corpus embebido y UI SwiftUI de ventana única.

---

## Contenido

- [Estado actual](#estado-actual)
- [Qué hace](#qué-hace)
- [Mejoras recientes](#mejoras-recientes)
- [Stack técnico](#stack-técnico)
- [Requisitos](#requisitos)
- [Ejecución](#ejecución)
- [Integraciones opcionales](#integraciones-opcionales)
- [Arquitectura por módulo](#arquitectura-por-módulo)
- [Base de datos y recursos](#base-de-datos-y-recursos)
- [Tests y validación](#tests-y-validación)
- [Estructura del proyecto](#estructura-del-proyecto)
- [Roadmap](#roadmap)
- [Licencia y créditos](#licencia-y-créditos)

## Estado actual

AstroMalik-macOS ya funciona como aplicación astrológica nativa completa para Apple Silicon. Los módulos principales viven en Swift y comparten un núcleo común basado en Swiss Ephemeris:

- motor natal y rueda interactiva;
- lectura natal guiada;
- archivo local de cartas;
- sinastría con corpus propio;
- revoluciones solar y lunar;
- tránsitos con scoring, foco y timeline;
- calendario astrológico, efemérides mundanas y resumen predictivo mensual personalizado;
- direcciones primarias Regiomontanas;
- horaria clásica nativa;
- exportación documental hacia Joplin.

El cambio arquitectónico más importante de las últimas fases es que **Horaria ya no depende de Python en el flujo normal**. El módulo horario se calcula por defecto con `HoraryNativeEngine`, un motor Swift nativo que usa `CSwissEph`, casas Regiomontanus y reglas tradicionales estrictas. El antiguo paquete Python `horaria` queda únicamente como modo legado/fallback para comparación o diagnóstico.

La app empaquetada se genera con:

```bash
./scripts/package_app.sh
open AstroMalik.app
```

Después de cualquier cambio de código o UI, este repo espera regenerar `AstroMalik.app` y comprobar que `AstroMalik.app/Contents/MacOS/AstroMalik` tiene timestamp actualizado.

## Qué hace

### Carta natal

- Cálculo de carta natal con Swiss Ephemeris embebido.
- Posiciones planetarias, casas, Ascendente, Medio Cielo y aspectos clásicos.
- Conversión correcta de hora local IANA a JD UT.
- Rueda natal interactiva en SwiftUI con signos, casas, planetas, ASC/MC y líneas de aspecto.
- Textos de corpus para planeta en signo, planeta en casa y aspectos natales.
- Nota Markdown preparada para copiar a Joplin desde la lectura natal.

### Lectura natal guiada

- Flujo de lectura con tríada Sol/Luna/Ascendente.
- Regente del Ascendente.
- Casas angulares.
- Aspectos dominantes.
- Síntesis editable.
- UI integrada dentro de la misma ventana, sin abrir ventanas secundarias.

### Archivo local de cartas

- Guardado de cartas en `~/Library/Application Support/AstroMalik/user.db`.
- Nombre, fecha, hora, zona horaria, coordenadas y lugar.
- Notas y etiquetas por carta.
- Búsqueda por texto, etiqueta, lugar o metadatos.
- Apertura directa de cartas guardadas para lectura, sinastría, tránsitos, revoluciones y direcciones primarias.

### Sinastría

- Comparación de dos cartas guardadas.
- Aspectos en ambas direcciones: A hacia B y B hacia A.
- Rueda doble de sinastría.
- Corpus específico con claves:

```text
SYN_<PLANETA_A>_<PLANETA_B>_<ASPECTO>
```

- 420 textos de sinastría en el corpus actual.
- Cobertura textual visible en la UI.
- Notas directas en Joplin vía Web Clipper local.

### Revolución solar

- Retorno exacto del Sol con `swe_solcross_ut`.
- Carta anual levantada para el lugar elegido por el usuario.
- Superposición natal/solar.
- ASC/MC de revolución ubicados en casas natales.
- Planetas de revolución leídos en relación con la carta natal.
- Lectura técnica y salida directa a Joplin.

### Revolución lunar

- Retornos sucesivos de la Luna a su longitud natal mediante `swe_mooncross_ut`.
- Secuencia de retornos dentro del periodo consultado.
- Fecha local/UTC, carta de retorno, Luna de retorno, ASC/MC y casas natales activadas.
- Métricas técnicas e intensidad mensual.
- Informe mensual exportable a Joplin.

### Tránsitos

- Eventos por rango de fechas.
- Orbes propios de tránsito, separados de los orbes natales.
- Orbes más estrechos para Nodo Norte y Nodo Sur.
- Nodo Norte y Nodo Sur como puntos natales y transitantes.
- Fusión del eje nodal para evitar duplicados:

```text
Nodo Norte conjunción + Nodo Sur oposición -> Eje Nodal sobre punto natal
Nodo Norte oposición + Nodo Sur conjunción -> Eje Nodal sobre punto natal
Nodo Norte cuadratura + Nodo Sur cuadratura -> Eje Nodal cuadratura punto natal
```

- Scoring técnico por planeta transitante, aspecto y orbe.
- Relevancia personal según punto natal tocado, angularidad, Sol/Luna, regente del Ascendente, ASC/MC y nodos natales.
- Impacto temporal por duración, repetición, retrogradación y concentración.
- Bandas de prioridad: baja, media, alta y crítica.
- Motivos compactos para entender por qué un tránsito sube de prioridad.
- Muestras diarias de intensidad para dibujar la curva del tránsito.
- Timeline visual con eje de fechas fijo y detalle al pulsar.

Documento técnico: [`docs/TRANSITOS_ESTRUCTURA_Y_FUNCIONAMIENTO.md`](docs/TRANSITOS_ESTRUCTURA_Y_FUNCIONAMIENTO.md).

### Calendario y efemérides

- Vista mensual del cielo general, independiente de una carta natal.
- Lunaciones: Luna Nueva, Luna Llena, Cuarto Creciente y Cuarto Menguante.
- Eclipses solares y lunares globales, con tipo y grado zodiacal.
- Estaciones planetarias directas y retrógradas.
- Ingresos en signo, incluyendo ingresos retrógrados.
- Luna vacía de curso con último aspecto e ingreso lunar de cierre.
- Aspectos mundanos exactos entre planetas en tránsito.
- Tabla clásica de efemérides diaria a 00:00 UTC con 10 planetas, Nodo Norte, velocidades, retrogradación y fase lunar.
- Pestaña **Resumen** que cruza el mes con una carta natal: lunaciones/eclipses en casas natales, activaciones de planetas natales, estaciones directas sobre la carta, tránsitos principales e ingresos por casa.
- Exportación mensual directa a Joplin.

Documento técnico: [`docs/CALENDARIO_EFEMERIDES_ARQUITECTURA.md`](docs/CALENDARIO_EFEMERIDES_ARQUITECTURA.md).

### Direcciones primarias

- Motor Regiomontano adaptado de Morinus.
- Direcciones directas y conversas reales.
- Plano zodiacal y modo eclíptico de compatibilidad.
- Claves Naibod, Ptolomeo y Brahe.
- RAMC calculado con `swe_sidtime0`.
- Pars Fortunae opt-in.
- Presets Clásico, Extendido y Completo.
- Sistema de pesos: crítica, mayor, moderada y menor.
- Vista Lista profesional con tabla nativa ordenable.
- Vista Cards para exploración.
- Vista Año en curso con ventana residual de ±18 meses.
- Timeline semántico por significador.
- Detalle profesional con hero, edad exacta, fecha estimada, polaridad, tipo, plano, texto principal, alternativos, factores contextuales y espéculo Regiomontano completo.
- Corpus clásico poblado desde Lilly, `Christian Astrology`, Libro III.
- Interpretación contextual local opcional con Foundry Local.
- Informes a Joplin de dirección seleccionada o informe filtrado.

Documentación:

- [`docs/PRIMARY_DIRECTIONS.md`](docs/PRIMARY_DIRECTIONS.md)
- [`docs/primary-directions-corpus-curation.md`](docs/primary-directions-corpus-curation.md)
- [`corpus_sources/reports/pd_corpus_population_report.md`](corpus_sources/reports/pd_corpus_population_report.md)

### Horaria clásica nativa

Horaria se calcula por defecto en Swift con `HoraryNativeEngine`.

El motor nativo calcula:

- siete planetas tradicionales;
- Nodo Norte verdadero;
- casas Regiomontanus;
- Parte de Fortuna y Parte del Espíritu;
- dignidades esenciales y accidentales;
- hora planetaria y radicalidad;
- Luna vía combusta;
- Luna fuera de curso;
- significadores por casa;
- recepción simple y mutua;
- perfección directa;
- translación y colección básica;
- veredicto estructurado: sí, no, no todavía, dudoso o requiere mediación;
- confianza, motivo principal, factores a favor, factores en contra, advertencias técnicas y rango temporal simbólico.

La corrección doctrinal más importante es que una perfección lunar solo cuenta si el aspecto exacto ocurre antes de que la Luna salga de signo. Esto evita contradicciones como mostrar una Luna vacía de curso y, al mismo tiempo, aceptar una perfección posterior al cambio de signo como un "sí" limpio.

Documento técnico: [`docs/HORARY_NATIVE.md`](docs/HORARY_NATIVE.md).

## Mejoras recientes

Estas son las mejoras más relevantes consolidadas en las últimas fases del proyecto:

- Calendario/Efemérides mensual con lunaciones, eclipses, estaciones, ingresos, Luna vacía de curso, aspectos mundanos, tabla diaria y exportación Joplin.
- Resumen predictivo mensual personalizado dentro de Efemérides, con exportación Joplin independiente.
- Port de Horaria a Swift nativo con Python relegado a modo legado.
- Juicio horario estructurado con veredicto, confianza, factores y warnings.
- Corrección de Luna fuera de curso para impedir perfecciones lunares inválidas tras cambio de signo.
- Rediseño de resultado horario en tarjetas de veredicto, Luna/curso, factores favorables, bloqueos y notas técnicas.
- Direcciones primarias con corpus clásico Lilly completo para el alcance actual.
- Vista Lista profesional y vista Año en curso en Direcciones Primarias.
- Espéculo Regiomontano completo en el detalle.
- Presets Clásico/Extendido/Completo y filtro por peso mínimo.
- Direcciones conversas calculadas con roles astronómicos invertidos, no derivadas del signo del arco.
- Clave Brahe basada en el arco real de ascensión recta del Sol entre nacimiento y +24h.
- Pars Fortunae como prómissor opt-in.
- Tránsitos con orbes propios, separados de los orbes natales.
- Incorporación de Nodo Norte, Nodo Sur y Eje Nodal en tránsitos.
- Relevancia personal más fina para tránsitos a ASC, MC, Sol, Luna, regente del Ascendente y nodos.
- Timeline de tránsitos con muestras diarias de intensidad.
- Revolución solar y lunar con informes Joplin.
- Sinastría con 420 textos y rueda doble.
- Joplin Web Clipper configurable desde Ajustes.
- Autodetección de token Joplin desde variable de entorno o settings locales.
- Integración Foundry Local one-shot para interpretaciones contextuales locales.
- OpenRouter disponible como infraestructura opcional para interpretación contextual, con key en Keychain y posibilidad de importación puntual desde Joplin.
- Empaquetado `.app` con firma ad-hoc, icono y recursos embebidos.

## Stack técnico

| Capa | Tecnología |
|---|---|
| UI | SwiftUI, macOS 14+, `NavigationSplitView` |
| Lenguaje | Swift 6.0 / Swift Package Manager |
| Efemérides | Swiss Ephemeris en C, target SPM `CSwissEph` |
| Motores | Swift nativo para natal, tránsitos, revoluciones, direcciones y horaria |
| Persistencia | SQLite3 del sistema mediante wrapper propio `SQLiteDB` |
| Corpus | `Sources/AstroMalik/Resources/corpus.db` + migraciones SQL idempotentes |
| Recursos | `cities_seed.json`, efemérides `.se1`, prompt de direcciones y migraciones |
| Joplin | Web Clipper local opcional (`127.0.0.1:41184`) |
| Foundry Local | SDK Python opcional invocado como proceso one-shot |
| OpenRouter | Cliente opcional para interpretación contextual, con Keychain |
| Paquete | Swift Package Manager puro, sin paquetes Swift externos |
| Target | macOS 14+, Apple Silicon arm64 |

## Requisitos

- macOS 14 Sonoma o superior.
- Apple Silicon arm64.
- Swift toolchain disponible en el sistema.
- Xcode 15+ si quieres entorno IDE completo.
- Command Line Tools si solo quieres compilar desde terminal.
- Aproximadamente 50 MB para binario, corpus y efemérides.
- Joplin Desktop solo si quieres crear notas directas.
- Foundry Local solo si quieres interpretaciones contextuales locales en Direcciones Primarias u Horaria.
- OpenRouter solo si quieres usar interpretación contextual externa desde la capa experimental correspondiente.

## Ejecución

### Instalación para desarrollo

No hace falta ser Apple Developer para compilar y usar AstroMalik en local. La vía más ligera es instalar las herramientas de línea de comandos de Apple:

```bash
xcode-select --install
```

Esto instala la toolchain necesaria (`swift`, `clang`, linker y utilidades de build) sin descargar Xcode completo. Xcode sigue siendo útil si quieres inspeccionar el proyecto con IDE, pero no es obligatorio para lanzar el build desde terminal.

Clonar y ejecutar en modo debug:

```bash
git clone https://github.com/eduardoddddddd/AstroMalik-macOS.git
cd AstroMalik-macOS
swift build
open .build/arm64-apple-macosx/debug/AstroMalik
```

Crear una app local de doble clic:

```bash
./scripts/package_app.sh
open AstroMalik.app
```

El script compila en release, crea `AstroMalik.app`, copia recursos, firma ad-hoc y elimina la cuarentena local del bundle generado.

> Nota: ejecutar el target SPM directamente con el botón de Xcode puede abrir un proceso sin ventana. Usa `open` o el `.app` empaquetado. El proyecto incrusta `Info.plist` en el binario para que macOS lo trate como app GUI regular.

### Distribución fuera del Mac del desarrollador

AstroMalik no está notarizada actualmente con Apple Developer ID. Esto no afecta al uso local desde código, pero sí puede afectar a una `.app` descargada desde GitHub, AirDrop, Drive o un `.zip`: macOS puede mostrar el aviso de Gatekeeper indicando que no puede verificar el desarrollador.

Para una build local creada con `./scripts/package_app.sh`, normalmente basta con abrir `AstroMalik.app`. Si recibes una app ya compilada y macOS la bloquea, las opciones habituales son:

```bash
xattr -dr com.apple.quarantine AstroMalik.app
open AstroMalik.app
```

También puede abrirse desde Finder con clic derecho sobre `AstroMalik.app` y luego **Abrir**. Para una distribución pública sin avisos de seguridad, el siguiente paso sería firmar con Developer ID y notarizar la app con Apple.

## Integraciones opcionales

### Horaria legacy Python

Horaria funciona de forma nativa en Swift por defecto y no necesita Python.

Modo Swift estricto, útil para tests o depuración:

```bash
export ASTROMALIK_HORARIA_ENGINE=swift
```

Modo legado para comparar con el antiguo paquete Python:

```bash
export ASTROMALIK_HORARIA_ENGINE=python
export ASTROMALIK_PYTHON_PATH=/ruta/a/python3
export ASTROMALIK_HORARIA_PATH=/ruta/al/repo/horaria
```

Sin variable de entorno, `HoraryEngine` intenta Swift nativo y solo cae a Python si hay un error inesperado.

### Joplin

Joplin es una salida de informes, no un requisito de cálculo. Por defecto:

```text
Host: 127.0.0.1
Puerto: 41184
Cuaderno: AstroMalik
```

El token se puede introducir en Ajustes. Si está vacío, la app intenta resolverlo desde:

- `ASTROMALIK_JOPLIN_TOKEN`;
- settings locales de Joplin Desktop (`api.token`).

Si el cuaderno configurado no existe, la app lo crea antes de guardar la nota.

Actualmente crean notas directas:

- Sinastría;
- Revolución Solar;
- Revolución Lunar;
- Direcciones Primarias.

La lectura natal conserva copia Markdown preparada para pegar.

### Foundry Local

Direcciones Primarias y Horaria pueden generar interpretaciones locales con Foundry Local. La integración actual usa el SDK Python instalado por defecto en:

```text
/Users/eduardoariasbravo/Developer/Foundry Local/.venv/bin/python
```

Variables útiles:

```text
ASTROMALIK_FOUNDRY_PYTHON
ASTROMALIK_FOUNDRY_PD_SCRIPT
ASTROMALIK_FOUNDRY_HORARY_SCRIPT
ASTROMALIK_FOUNDRY_MODEL
ASTROMALIK_FOUNDRY_MODEL_CACHE_DIR
```

Direcciones Primarias y Horaria usan `qwen2.5-7b` por defecto; `ASTROMALIK_FOUNDRY_MODEL` puede forzar otro alias.

La decisión arquitectónica es deliberada: AstroMalik no abre un servidor propio para Foundry. Swift invoca un proceso Python one-shot, envía JSON por `stdin` y espera JSON limpio por `stdout`.

Documento técnico: [`docs/FOUNDRY_LOCAL_INTEGRATION.md`](docs/FOUNDRY_LOCAL_INTEGRATION.md).

### OpenRouter

El proyecto incluye un cliente OpenRouter para lectura contextual opcional en la capa de Direcciones Primarias. La app resuelve credenciales de forma conservadora:

- Keychain como fuente principal;
- `OPENROUTER_API_KEY` como fallback;
- importación puntual desde una nota local de Joplin si el usuario lo solicita.

La key no se trata como parte del cálculo astrológico base y no es necesaria para usar la app.

## Arquitectura por módulo

### Ventana única

La app usa un único `WindowGroup` con `NavigationSplitView`. La sidebar cambia de sección y el panel derecho conserva el flujo activo. `AppState` centraliza navegación, tema, configuración Joplin, carta activa, stores, servicios e intérpretes.

Secciones principales:

- Nueva Carta;
- Cartas Guardadas;
- Lectura;
- Sinastría;
- Revolución Solar;
- Revolución Lunar;
- Tránsitos;
- Horaria;
- Direcciones Primarias.

### Motor natal

`AstroEngine` calcula planetas, casas y aspectos con Swiss Ephemeris. Las casas se calculan con `swe_houses_ex2`, capturando código de retorno y mensaje `serr`. `JulianDay.swift` convierte fecha/hora local y zona IANA a JD UT antes de llamar a Swiss Ephemeris.

### Corpus

`CorpusStore` lee el corpus embebido para natal, aspectos, tránsitos y sinastría. `PrimaryDirectionCorpusStore` gestiona la tabla de direcciones primarias creada/poblada por migraciones. El diseño distingue corpus curado de lectura contextual generativa.

### Persistencia

`SQLiteDB` es un wrapper propio sobre SQLite3 del sistema. `UserStore` gestiona cartas guardadas, notas, etiquetas y metadatos. `HoraryStore` gestiona consultas horarias guardadas.

### Migraciones

`MigrationRunner` aplica migraciones idempotentes:

- migraciones de corpus sobre una copia writable del corpus distribuido;
- migraciones de usuario sobre `user.db`.

Este patrón permite distribuir una base de corpus inicial y ampliar tablas como `primary_direction_meanings` sin depender de servicios externos.

### Empaquetado

`scripts/package_app.sh`:

- compila release;
- crea `AstroMalik.app`;
- copia binario, `Info.plist`, bundle de recursos, migraciones y prompt contextual;
- copia icono `.icns` si existe;
- firma ad-hoc;
- elimina cuarentena.

## Base de datos y recursos

Recursos principales:

- `Sources/AstroMalik/Resources/corpus.db`: corpus embebido principal.
- `Sources/AstroMalik/Resources/cities_seed.json`: seed offline de lugares.
- `Sources/AstroMalik/Resources/ephe/`: archivos Swiss Ephemeris `.se1`.
- `Resources/migrations/`: migraciones SQL idempotentes.
- `Resources/pd_contextual_prompt.md`: prompt de interpretación contextual de direcciones.
- `~/Library/Application Support/AstroMalik/user.db`: cartas, consultas, metadatos y cachés del usuario.

Conteo actual del corpus principal embebido:

| Tipo | Registros |
|---|---:|
| `natal_planeta_signo` | 125 |
| `natal_planeta_casa` | 121 |
| `aspecto_natal` | 368 |
| `transito` | 745 |
| `sinastria` | 420 |
| **Total** | **1.779** |

El corpus de Direcciones Primarias se construye por migraciones sobre `primary_direction_meanings`, con textos clásicos trazables y política de honestidad documental.

## Tests y validación

Ejecutar la suite:

```bash
swift test
```

La suite cubre:

- carta natal de referencia y conversión de zonas horarias;
- casas con `swe_houses_ex2`;
- tránsitos, cancelación, muestras diarias de intensidad, ASC/MC como puntos transitables y bandas de prioridad;
- orbes propios de tránsito frente a orbes natales;
- Nodo Norte, Nodo Sur y fusión del Eje Nodal en tránsitos;
- sinastría y corpus `SYN_*`;
- revolución solar;
- revolución lunar;
- Joplin con cliente HTTP mock;
- direcciones primarias Regiomontanus;
- direcciones conversas;
- presets, pesos, corpus y goldens de direcciones primarias;
- Foundry Local para Horaria y Direcciones Primarias mediante clientes testeables;
- Horaria nativa, compatibilidad JSON legacy y regresión de Luna fuera de curso;
- cliente OpenRouter y gestión de credenciales donde aplica.

Sanity check histórico: carta natal de referencia `1976-10-11 20:33 Europe/Madrid`.

## Estructura del proyecto

```text
.
├── Package.swift
├── Info.plist
├── AstroMalik.icns
├── CHANGELOG.md
├── README.md
├── Resources/
│   ├── migrations/
│   └── pd_contextual_prompt.md
├── Sources/
│   ├── CSwissEph/
│   └── AstroMalik/
│       ├── AppNavigation.swift
│       ├── AppResources.swift
│       ├── AppTheme.swift
│       ├── AstroMalikApp.swift
│       ├── Engine/
│       ├── Horary/
│       ├── Models/
│       ├── Persistence/
│       ├── PrimaryDirections/
│       ├── Resources/
│       ├── Services/
│       ├── Store/
│       └── Views/
├── Tests/
│   └── AstroMalikTests/
├── corpus_sources/
├── docs/
└── scripts/
```

Archivos y módulos especialmente relevantes:

- `Sources/AstroMalik/Engine/AstroEngine.swift`: carta natal, aspectos, casas y utilidades comunes.
- `Sources/AstroMalik/Engine/TransitEngine.swift`: tránsitos, scoring, prioridad, nodos y timeline.
- `Sources/AstroMalik/Engine/SolarReturnEngine.swift`: revolución solar.
- `Sources/AstroMalik/Engine/LunarReturnEngine.swift`: revolución lunar.
- `Sources/AstroMalik/Engine/EssentialDignityEngine.swift`: dignidades esenciales tradicionales.
- `Sources/AstroMalik/Horary/HoraryNativeEngine.swift`: motor horario Swift nativo.
- `Sources/AstroMalik/Horary/HoraryEngine.swift`: selector Swift/Python legacy.
- `Sources/AstroMalik/PrimaryDirections/PrimaryDirectionsService.swift`: orquestación de cálculo, corpus, interpretación y notas.
- `Sources/AstroMalik/PrimaryDirections/Calculation/PrimaryDirectionCalculator.swift`: cálculo Regiomontano.
- `Sources/AstroMalik/PrimaryDirections/Calculation/RegiomontanusProjection.swift`: proyección y espéculo.
- `Sources/AstroMalik/PrimaryDirections/Corpus/PrimaryDirectionCorpusStore.swift`: lectura de corpus clásico de direcciones.
- `Sources/AstroMalik/PrimaryDirections/Interpretation/PrimaryDirectionFoundryClient.swift`: puente Foundry Local.
- `Sources/AstroMalik/Horary/Interpretation/HoraryFoundryClient.swift`: puente Foundry Local para horaria.
- `Sources/AstroMalik/PrimaryDirections/Interpretation/OpenRouterClient.swift`: cliente OpenRouter opcional.
- `Sources/AstroMalik/Persistence/MigrationRunner.swift`: copia y migración de bases.
- `Sources/AstroMalik/Services/JoplinClipperService.swift`: salida a Joplin Web Clipper.
- `Sources/AstroMalik/Services/PlacesService.swift`: búsqueda de lugares offline + Nominatim.
- `scripts/package_app.sh`: build release, bundle `.app`, firma ad-hoc y recursos.
- `scripts/foundry_primary_direction_once.py`: llamada one-shot Foundry para direcciones.
- `scripts/foundry_horary_once.py`: llamada one-shot Foundry para horaria.

## Documentación del proyecto

- [`CHANGELOG.md`](CHANGELOG.md): historial de novedades.
- [`docs/ARCHITECTURE.md`](docs/ARCHITECTURE.md): arquitectura general.
- [`docs/HORARY_NATIVE.md`](docs/HORARY_NATIVE.md): horaria Swift nativa.
- [`docs/PRIMARY_DIRECTIONS.md`](docs/PRIMARY_DIRECTIONS.md): direcciones primarias.
- [`docs/TRANSITOS_ESTRUCTURA_Y_FUNCIONAMIENTO.md`](docs/TRANSITOS_ESTRUCTURA_Y_FUNCIONAMIENTO.md): tránsitos, scoring y foco.
- [`docs/FOUNDRY_LOCAL_INTEGRATION.md`](docs/FOUNDRY_LOCAL_INTEGRATION.md): integración Foundry Local.
- [`docs/corpus-consolidation-pipeline.md`](docs/corpus-consolidation-pipeline.md): pipeline de corpus.
- [`docs/primary-directions-corpus-curation.md`](docs/primary-directions-corpus-curation.md): curación del corpus clásico.
- [`Tests/AstroMalikTests/PRIMARY_DIRECTIONS_TESTS.md`](Tests/AstroMalikTests/PRIMARY_DIRECTIONS_TESTS.md): notas de validación de direcciones.

## Roadmap

Completado en abril/mayo de 2026:

- app nativa SwiftUI de ventana única;
- natal, lectura guiada y archivo local;
- tránsitos con timeline, foco, orbes propios y eje nodal;
- sinastría con rueda doble y corpus específico;
- revolución solar;
- revolución lunar;
- Joplin Web Clipper;
- direcciones primarias Regiomontanas con corpus clásico;
- interpretación contextual opcional con Foundry Local;
- horaria nativa Swift;
- empaquetado `.app`.

Líneas probables de evolución:

- export PNG/PDF de cartas e informes;
- mejora de visualización técnica de Horaria;
- tabla de aspectos aplicativos/separativos más amplia en Horaria;
- ampliar corpus clásico verificable;
- configurar sistemas de casas desde UI;
- ampliar soporte de nodos, Lilith, Quirón y puntos modernos donde tenga sentido;
- ingresos de planetas por casa en Tránsitos;
- quincuncio y aspectos menores configurables;
- retornos solares/lunares con orbes propios y opciones avanzadas;
- notarización opcional con Apple Developer ID;
- distribución más cómoda para usuarios no técnicos.

## Relación con otros repos

- [`AstroMalik`](https://github.com/eduardoddddddd/AstroMalik): variante web Python/FastAPI + React/Vite.
- `AstroMalik-macOS`: este repo, app nativa Swift/SwiftUI para Apple Silicon.

Ambos comparten orientación y parte del corpus, pero el macOS actual ya no es un wrapper de la versión Python: sus motores principales viven dentro de Swift.

## Licencia y créditos

Código de aplicación: MIT License.

Swiss Ephemeris © [Astrodienst AG](https://www.astro.com/swisseph/) bajo [Swiss Ephemeris Public License](https://www.astro.com/ftp/swisseph/LICENSE). Si redistribuyes una build comercial, revisa las condiciones de Astrodienst.

Los archivos `.se1` en `Sources/AstroMalik/Resources/ephe/` son datos de efemérides de Astrodienst y están sujetos a su licencia.

## Autor

Eduardo Arias · [@eduardoddddddd](https://github.com/eduardoddddddd)

Órgiva, Granada · 2026
