# AstroMalik · macOS

[![Ask DeepWiki](https://deepwiki.com/badge.svg)](https://deepwiki.com/eduardoddddddd/AstroMalik-macOS)



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

AstroMalik-macOS funciona como aplicación astrológica nativa **completa** para Apple Silicon. Versión 1.0 cubre el ciclo entero de práctica astrológica tradicional: análisis natal extendido, predictivas helenísticas y clásicas, sintetizador cross-personal con redacción Anthropic e informes PDF profesionales.

Módulos disponibles:

- motor natal y rueda interactiva, lectura natal guiada y **análisis natal extendido** (almuten figuris, regente de la geniture, lotes, configuraciones aspectuales, antiscia, declinaciones, estrellas fijas);
- archivo local de cartas;
- sinastría con corpus propio;
- revoluciones solar y lunar;
- tránsitos con scoring, foco, timeline e ingresos por casa;
- calendario astrológico, efemérides mundanas y resumen predictivo mensual;
- **profecciones anuales** helenísticas (whole sign);
- **direcciones primarias** Regiomontanas y **arco solar**;
- **progresiones secundarias** (Naibod y Bija);
- **Firdaria** persas con sect engine compartido;
- **Zodiacal Releasing** sobre Espíritu y Fortuna;
- horaria clásica nativa;
- **informe cross-personal** sintetizador con redacción Anthropic en Markdown;
- **14 informes PDF profesionales** con plantillas HTML+CSS renderizadas por WebKit;
- **CLI `astromalik-cli`** para LaunchAgent y cron;
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

### Profecciones anuales

- Profecciones helenísticas en **signos enteros** desde el Ascendente.
- Casa del año, signo profeccionado, Lord of the Year (regente domicilio del signo).
- Activaciones por tránsitos del LotY a planetas natales y por tránsitos al LotY natal.
- Sub-profecciones mensuales (12 partes del año) y diarias (28 días por casa).
- Vista dedicada y exportación a Joplin.

### Arco solar

- Direcciones por arco solar **real** (Sol progresado) y **Naibod** (constante 0°59'08.33"/año).
- Incluye ASC, MC, DSC e IC además de los 10 planetas.
- Aspectos clásicos con sistema de pesos compartido con Direcciones Primarias.
- Bisección para resolver la edad exacta en modo real.
- Integrado como pestaña hermana en la sección de Direcciones Primarias.

### Progresiones secundarias

- Día por año determinista (1 día tras nacimiento = 1 año de vida).
- Planetas, declinaciones y Nodo Norte progresados.
- MC y ASC progresados en modo **Naibod** (RAMC + 0°59'08.33"/año) o **Bija** (avance con el Sol progresado).
- Aspectos progresado → natal y progresado → progresado con bisección al instante exacto.
- Fase lunar progresada (8 fases), Luna progresada por signo y casa.
- Cambios destacados ±5 años: ingresos lentos, estaciones progresadas, transiciones de fase.

### Firdaria y Sect

- Sect engine compartido: secta diurna/nocturna, luminaria, benéficos y maléficos de secta.
- Firdaria persas (Abu Maʿshar / Bonatti) con ciclo de 75 años, ordenes diurno y nocturno.
- Sub-períodos firdarianos (firdar menor) con reparto equitativo entre los 7 planetas clásicos.
- Timeline visual y exportación Joplin.

### Zodiacal Releasing

- ZR de Vettius Valens sobre los lotes de **Espíritu** (carrera/acción) y **Fortuna** (cuerpo/fortuna).
- Niveles L1 (años) y L2 (meses) con períodos según tabla canónica de la Antología Libro IV.
- **Loosing of the Bond** en L2 sobre Cáncer o Capricornio con salto al signo opuesto del L1 (convención Schmidt).
- **Peaks** angulares: sub-períodos L2 angulares al signo del L1.
- Eventos destacados: cambios de L1, LBs próximos, peaks vigentes.

### Análisis natal extendido

Pestaña dentro de la lectura natal con nueve subsistemas:

- **7 lotes helenísticos**: Fortuna, Espíritu, Eros, Necesidad, Victoria, Audacia y Némesis con inversión día/noche.
- **Almuten Figuris** (Ibn Ezra) sobre Sol, Luna, ASC, Lote de Fortuna y sicigia prenatal, con bonos Lilly +12 por regente del día, hora planetaria caldea con horas desiguales y orientalidad.
- **Regente de la geniture**.
- **Configuraciones aspectuales**: T-cuadrada, gran trígono, yod, gran cruz, kite, rectángulo místico.
- **Distribución** por elemento, modalidad, hemisferio y cuadrante con singletons.
- **Recepciones mutuas** (domicilio, exaltación, mixtas).
- **Antiscia y contraantiscia** sobre eje solsticial.
- **Declinaciones**: paralelos, contraparalelos y planetas fuera de límites (OOB).
- **Estrellas fijas** con precesión simple desde J2000 sobre planetas, ASC, MC y Lote de Fortuna.

### Informe cross-personal

- Motor **CrossPersonalEngine** que sintetiza todas las técnicas anteriores en un único estado astrológico personal con cuatro capas temporales (anual, medio plazo, corto plazo, lunar).
- **Cola de prioridad por convergencia**: cuando un planeta o casa aparece en varias capas a la vez, su score sube. Bonificaciones por Lord of the Year, luminaria de secta, regente de la geniture y peak ZR.
- **CrossPersonalAssembler** orquesta los engines reales y rellena el state.
- **Redacción Anthropic**: el state se serializa a JSON y se envía a Claude Sonnet 4.6 (por defecto) o Opus 4.7 con el prompt en español. La salida es un informe Markdown estructurado en 8 secciones siguiendo doctrina helenística/tradicional.
- Resolución de API key vía Keychain (`com.astromalik.anthropic`) o variable `ANTHROPIC_API_KEY`.
- Modos de alcance: completo, anual, mensual, semanal.
- Coste estimado por llamada visible (Sonnet ~$0.05-0.10 por informe completo con prompt caching).

### Informes PDF profesionales

- Infraestructura PDF basada en HTML+CSS renderizado por `WKWebView.createPDF`. Sin dependencias externas.
- **14 informes PDF**: natal, sinastría, análisis natal extendido, horaria, tránsitos, revolución solar, revolución lunar, calendario/efemérides, resumen mensual, profecciones, direcciones primarias, arco solar, progresiones, Firdaria, Zodiacal Releasing y **cross-personal** (corona).
- **Renderers SVG vectoriales**: rueda natal con lanes para evitar solapamiento, rueda doble (sinastría y retornos), timelines (tránsitos, ZR, Firdaria) y tablas de efemérides.
- **Plantilla cross-personal híbrida**: si hay narrativa Anthropic la usa como texto principal y muestra los datos del state como tablas de soporte; si no, produce un PDF solo con datos (preview sin coste de API).
- Tipografía EB Garamond serif para cuerpo + Inter sans para datos. Paleta marfil/tinta/azul noche/dorado. A4 portrait por defecto, landscape para efemérides diarias.
- Idioma español único.

### CLI `astromalik-cli`

- Binario Swift headless para LaunchAgent o cron.
- `astromalik-cli --chart "Edu" --scope weekly --model sonnet --output joplin:AstroMalik`
- Resolución de carta por nombre o UUID desde `user.db`.
- Destinos de salida: `stdout`, `file:/ruta.md`, `joplin:Notebook`.
- LaunchAgent recipes para programación semanal (sábado 18:00) y mensual (día 1, 09:00).
- Códigos de salida estándar para encadenar con scripts.

## Mejoras recientes

Estas son las mejoras más relevantes consolidadas en las últimas fases del proyecto:

- Sidebar reorganizado por flujo de trabajo en 6 secciones (Carta Natal · Predictivas · Retornos · Síntesis · Sinastría y Horaria · Herramientas), con cabeceras sobrias y la síntesis cross-personal («Panorama Predictivo») destacada como culminación.
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
| Motores | Swift nativo para natal, análisis extendido, tránsitos, revoluciones, direcciones primarias y arco solar, progresiones secundarias, Firdaria, Zodiacal Releasing, profecciones, horaria y sintetizador cross-personal |
| Persistencia | SQLite3 del sistema mediante wrapper propio `SQLiteDB` |
| Corpus | `Sources/AstroMalik/Resources/corpus.db` + migraciones SQL idempotentes |
| Recursos | `cities_seed.json`, `fixed_stars.json`, efemérides `.se1`, prompt cross-personal, plantillas HTML de informes |
| PDFs | WebKit (`WKWebView.createPDF`) + plantillas HTML+CSS + SVG vectorial |
| Joplin | Web Clipper local opcional (`127.0.0.1:41184`) |
| Anthropic | Cliente Messages API con prompt caching, Keychain `com.astromalik.anthropic` o `ANTHROPIC_API_KEY` |
| Foundry Local | SDK Python opcional invocado como proceso one-shot |
| OpenRouter | Cliente opcional para interpretación contextual, con Keychain |
| CLI | Binario `astromalik-cli` headless para LaunchAgent y cron |
| Paquete | Swift Package Manager puro, sin paquetes Swift externos. Módulo compartido `AstroMalik` + ejecutable GUI `AstroMalikApp` + ejecutable headless `astromalik-cli` |
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
- [`docs/ARCHITECTURE.md`](docs/ARCHITECTURE.md): arquitectura general actualizada para 1.0.
- [`docs/CROSS_PERSONAL.md`](docs/CROSS_PERSONAL.md): motor sintetizador cross-personal, capas, cola de prioridad por convergencia y narrativa.
- [`docs/PDF_REPORTS.md`](docs/PDF_REPORTS.md): infraestructura PDF, theme, plantillas y los 14 informes.
- [`docs/ANTHROPIC_INTEGRATION.md`](docs/ANTHROPIC_INTEGRATION.md): cliente Anthropic Messages, prompt caching, resolución de API key y pricing.
- [`docs/CLI.md`](docs/CLI.md): binario `astromalik-cli`, argumentos, LaunchAgent recipes.
- [`docs/HORARY_NATIVE.md`](docs/HORARY_NATIVE.md): horaria Swift nativa.
- [`docs/PRIMARY_DIRECTIONS.md`](docs/PRIMARY_DIRECTIONS.md): direcciones primarias.
- [`docs/TRANSITOS_ESTRUCTURA_Y_FUNCIONAMIENTO.md`](docs/TRANSITOS_ESTRUCTURA_Y_FUNCIONAMIENTO.md): tránsitos, scoring y foco.
- [`docs/CALENDARIO_EFEMERIDES_ARQUITECTURA.md`](docs/CALENDARIO_EFEMERIDES_ARQUITECTURA.md): calendario y efemérides.
- [`docs/FOUNDRY_LOCAL_INTEGRATION.md`](docs/FOUNDRY_LOCAL_INTEGRATION.md): integración Foundry Local.
- [`docs/corpus-consolidation-pipeline.md`](docs/corpus-consolidation-pipeline.md): pipeline de corpus.
- [`docs/primary-directions-corpus-curation.md`](docs/primary-directions-corpus-curation.md): curación del corpus clásico.
- [`Tests/AstroMalikTests/PRIMARY_DIRECTIONS_TESTS.md`](Tests/AstroMalikTests/PRIMARY_DIRECTIONS_TESTS.md): notas de validación de direcciones.

## Roadmap

Completado en 1.0 (mayo 2026):

- app nativa SwiftUI con `NavigationSplitView`;
- natal, lectura guiada y archivo local;
- **análisis natal extendido**: 7 lotes, almuten figuris, regente de la geniture, configuraciones aspectuales, distribución, recepciones, antiscia, declinaciones y estrellas fijas;
- sinastría con rueda doble y corpus específico;
- revoluciones solar y lunar;
- tránsitos con scoring, timeline, eje nodal e ingresos por casa;
- calendario/efemérides y resumen predictivo mensual;
- **profecciones anuales** helenísticas (whole sign);
- direcciones primarias Regiomontanas con corpus clásico;
- **arco solar** real y Naibod;
- **progresiones secundarias** completas (Naibod y Bija);
- **Firdaria persas** y **sect engine** compartido;
- **Zodiacal Releasing** sobre Espíritu y Fortuna con LB y peaks;
- horaria nativa Swift;
- **motor cross-personal** sintetizador con cola de prioridad por convergencia;
- **redacción Anthropic** del informe cross-personal (Sonnet 4.6 y Opus 4.7);
- **14 informes PDF** con plantillas HTML+CSS, SVG vectoriales y theme tipográfico profesional;
- **CLI headless** `astromalik-cli` con LaunchAgent recipes;
- empaquetado `.app` con módulo compartido y dos ejecutables.

Líneas posibles para 1.1+:

- Quirón, Lilith y puntos modernos como cuerpos opcionales;
- LB de Zodiacal Releasing en L3/L4;
- tablas firdarianas con duración proporcional como modo alternativo (Bonatti vs helenístico);
- progresiones terciarias y menores;
- profecciones mensual y diaria expandidas;
- astrocartografía y líneas locales;
- carta compuesta y Davison;
- electional puntual (selección de momentos);
- mejora de visualización técnica de Horaria;
- tabla de aspectos aplicativos/separativos más amplia en Horaria;
- configurar sistemas de casas desde UI;
- quincuncio y aspectos menores configurables;
- retornos solares/lunares con orbes propios y opciones avanzadas;
- corpus clásico ampliado para profecciones, ZR y arco solar;
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
