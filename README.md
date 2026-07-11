# AstroMalik para macOS

**Astrología tradicional, predictiva y documental en una aplicación privada para Mac.**

[![Última versión](https://img.shields.io/badge/versión-1.1.2-blue)](https://github.com/eduardoddddddd/AstroMalik-macOS/releases/tag/v1.1.2)
![macOS](https://img.shields.io/badge/macOS-14%2B-111111)
![Apple Silicon + Intel](https://img.shields.io/badge/Mac-Apple%20Silicon%20%2B%20Intel-6f42c1)
![Privacidad](https://img.shields.io/badge/privacidad-local--first-2ea44f)
![Licencia](https://img.shields.io/badge/licencia-MIT-lightgrey)

AstroMalik reúne carta natal, lectura, rectificación de hora, técnicas predictivas, sinastría, horaria, efemérides e informes en un único espacio de trabajo. Los cálculos principales se realizan en el propio Mac y no necesitan una cuenta ni un servicio de inteligencia artificial.

---

## Descargar e instalar

### 1. Descarga la aplicación

**[⬇ Descargar AstroMalik 1.1.2 para macOS](https://github.com/eduardoddddddd/AstroMalik-macOS/releases/download/v1.1.2/AstroMalik-macOS-universal.zip)**

No necesitas saber usar GitHub. El enlace anterior descarga directamente un archivo ZIP. Al abrirlo aparecerá `AstroMalik.app`; arrástralo a la carpeta **Aplicaciones**.

También puedes consultar la [página de la versión 1.1.2](https://github.com/eduardoddddddd/AstroMalik-macOS/releases/tag/v1.1.2), donde están el checksum y la versión de terminal.

### 2. Comprueba que tu Mac sea compatible

La misma descarga funciona de forma nativa en:

- Macs con chip Apple: M1, M2, M3, M4 y posteriores.
- Macs con procesador Intel que puedan ejecutar macOS 14 Sonoma o superior.

No tienes que elegir una versión ni instalar Rosetta. Para consultar tu sistema abre ** → Acerca de este Mac**.

### 3. Autoriza la primera apertura

AstroMalik no está notarizado por Apple porque este proyecto no utiliza la suscripción anual de pago del programa de desarrolladores. Por ese motivo macOS puede bloquear la primera apertura aunque el archivo sea correcto.

La solución habitual es:

1. Abre **Aplicaciones**.
2. Haz clic derecho —o Control-clic— sobre AstroMalik.
3. Selecciona **Abrir** y confirma de nuevo.

Si nunca has instalado una aplicación fuera de la App Store, sigue la guía ilustrada paso a paso:

### **[Guía de instalación para principiantes](docs/INSTALACION_MACOS.md)**

La guía explica la advertencia de macOS, **Abrir igualmente**, cómo comprobar la descarga y qué hacer si aparece el mensaje “aplicación dañada”. No recomienda desactivar la seguridad general del Mac.

---

## Qué es AstroMalik

AstroMalik está pensado como un escritorio de trabajo astrológico: permite calcular, leer, comparar, investigar periodos, guardar conclusiones y crear documentos sin saltar entre muchas herramientas.

Sus principios son:

- **Privacidad local:** cartas, sesiones y notas se guardan en tu Mac.
- **Cálculo reproducible:** Swiss Ephemeris y motores propios realizan los cálculos astronómicos y astrológicos.
- **IA opcional:** Anthropic u OpenRouter solo intervienen cuando el usuario lo solicita expresamente.
- **Resultados explicables:** las técnicas muestran factores, fechas, orbes, scores, advertencias y procedencia.
- **Archivo profesional:** las cartas y análisis pueden conservarse y exportarse a PDF, JSON, Markdown o Joplin.

AstroMalik no pretende sustituir documentación oficial, criterio profesional ni investigación biográfica. En especial, la rectificación propone hipótesis comparativas: no certifica una hora de nacimiento.

## Qué puedes hacer

### Carta natal y lectura

- Calcular cartas con fecha, hora, zona, coordenadas y distintos sistemas de casas.
- Consultar rueda, posiciones, casas, Ascendente, Medio Cielo y aspectos.
- Leer una interpretación continua organizada por capítulos.
- Analizar dominantes, elementos, modalidades, hemisferios, recepciones, antiscia, declinaciones y estrellas fijas.
- Calcular lotes helenísticos, Almuten Figuris y regente de la genitura.
- Guardar cartas, notas, etiquetas y síntesis personales.

### Técnicas predictivas

- Tránsitos con timeline, prioridades e ingresos por casa.
- Progresiones secundarias.
- Direcciones primarias Regiomontanas.
- Arco solar real y Naibod.
- Profecciones y Lord of the Year.
- Firdaria.
- Zodiacal Releasing desde Fortuna y Espíritu.
- Revolución solar y revolución lunar.
- Panorama predictivo que combina varias escalas temporales.

### Relaciones, preguntas y calendario

- Sinastría con rueda doble, aspectos en ambas direcciones y corpus específico.
- Horaria clásica con dignidades, radicalidad, significadores, recepción y perfección.
- Calendario mensual con lunaciones, eclipses, estaciones, ingresos y Luna vacía de curso.
- Efemérides diarias y resúmenes mensuales personalizados.

### Documentos y archivo

- Informes PDF con ruedas, tablas y timelines vectoriales.
- Exportación de notas a Joplin mediante una acción explícita.
- Sesiones y resultados persistentes en SQLite.
- Intercambio reproducible mediante JSON versionado.
- Historial local de cartas, consultas e informes.

---

## Rectificación de hora natal

La rectificación es una de las funciones centrales de AstroMalik. Compara distintas horas posibles con eventos reales de la vida y conserva la evidencia que favorece o debilita cada candidata.

El flujo incluye:

1. selección de una carta base y un rango horario;
2. cronología de eventos fechados con precisión, fiabilidad e importancia;
3. búsqueda gruesa y refinamiento fino de candidatas;
4. direcciones primarias, arco solar, progresiones y tránsitos angulares;
5. confirmaciones por profecciones, Firdaria, Zodiacal Releasing, lotes y revolución solar;
6. ranking, clusters, cobertura por evento, comparación lado a lado y control anti-overfitting;
7. guardado de la hora elegida como una carta nueva, sin sobrescribir la original;
8. historial, JSON, PDF, Joplin y comparación narrativa opcional.

La interfaz guía el trabajo en cinco pasos adaptables. Opcionalmente puede ejecutar y comparar Placidus, Signos completos, Casas iguales, Regiomontanus, Campanus y Porfirio para comprobar si la hora propuesta es estable entre sistemas.

Una puntuación no es una probabilidad ni una prueba documental. Conviene revisar clusters, cobertura, advertencias y diversidad de técnicas antes de elegir una hora.

**[Abrir la guía completa de Rectificación](docs/RECTIFICACION_GUI_DE_USO.md)**

## Primer recorrido recomendado

Si acabas de instalar la aplicación:

1. Crea una carta desde **Carta Natal → Nueva Carta**.
2. Guárdala para poder reutilizarla.
3. Abre **Lectura** para recorrer la interpretación natal.
4. Consulta **Tránsitos** o **Panorama Predictivo** para una fecha concreta.
5. Usa **Rectificación** solo si la hora natal es incierta y dispones de eventos biográficos fechados.
6. Genera un PDF o una nota Joplin cuando quieras conservar o compartir el análisis.

## Privacidad, datos e inteligencia artificial

### Dónde se guardan los datos

Las cartas y sesiones del usuario se almacenan localmente en:

```text
~/Library/Application Support/AstroMalik/user.db
```

Actualizar o sustituir `AstroMalik.app` no elimina esa base de datos. Aun así, es recomendable incluirla en tus copias de seguridad.

### Qué funciona sin internet

El cálculo natal, la rectificación determinista, las predictivas, la horaria, el calendario y la mayor parte de las interpretaciones funcionan localmente.

### Funciones opcionales con conexión

- **Anthropic y OpenRouter:** narrativa generativa solicitada expresamente.
- **Joplin Web Clipper:** creación de notas en una instalación local de Joplin.
- **Búsqueda de lugares:** puede consultar servicios externos cuando los datos locales no bastan.

Las funciones de IA no recalculan posiciones astronómicas ni sustituyen los resultados técnicos.

---

## Guías para usuarios

| Necesito… | Documento |
|---|---|
| Instalar la aplicación y resolver el aviso de macOS | [Instalación para principiantes](docs/INSTALACION_MACOS.md) |
| Aprender a rectificar una hora natal | [Guía de Rectificación](docs/RECTIFICACION_GUI_DE_USO.md) |
| Entender los informes PDF | [Informes PDF](docs/PDF_REPORTS.md) |
| Consultar el uso del CLI | [CLI local-first](docs/CLI.md) |

El resto de esta página está orientado a desarrolladores y personas que quieran conocer la implementación interna.

---

## Información técnica

### Arquitectura

- Swift 6 y SwiftUI para macOS 14 o superior.
- Swift Package Manager sin dependencias Swift externas.
- Swiss Ephemeris incluido como target C `CSwissEph`.
- SQLite3 del sistema mediante un wrapper propio.
- WebKit para generar informes PDF.
- Aplicación GUI y CLI construidos sobre el mismo módulo `AstroMalik`.
- Distribución universal con slices `arm64` y `x86_64`.

### Compilar y ejecutar tests

Requisitos de desarrollo: Xcode completo y macOS 14 o superior. Los usuarios que descargan la aplicación no necesitan instalar Xcode.

```bash
# Compilación de desarrollo
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift build

# Suite completa
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift test

# App nativa para la máquina actual
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer scripts/package_app.sh

# App y CLI universales ARM64 + Intel
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer scripts/package_universal_app.sh
```

El empaquetador nativo escribe `AstroMalik.app` en la raíz. El universal no lo modifica: escribe app, CLI, ZIP y checksums en `dist/`.

Más información: [build universal, firma ad-hoc y GitHub Actions](docs/UNIVERSAL_BUILD.md).

### CLI local-first

`astromalik-cli` ofrece resultados para terminal, automatizaciones y agentes externos. Sus valores por defecto no usan red ni generan coste:

```text
--format json --output stdout --narrative none --no-network
```

Ejemplos:

```bash
astromalik-cli charts list
astromalik-cli natal --chart "Edu" --format markdown
astromalik-cli transits --chart "Edu" --from 2026-07-01 --to 2026-07-31
astromalik-cli cross-personal --chart "Edu" --date 2026-07-11 --narrative none
```

Anthropic u OpenRouter requieren permiso explícito mediante los flags de red documentados en [docs/CLI.md](docs/CLI.md).

### Estructura del repositorio

```text
Sources/
  AstroMalik/       Motores, modelos, persistencia, informes, recursos y vistas
  AstroMalikApp/    Punto de entrada de la aplicación
  AstroMalikCLI/    Punto de entrada del CLI
  CSwissEph/        Swiss Ephemeris en C
Tests/              Suite de motores, stores, informes, CLI y rectificación
Resources/          Migraciones y recursos auxiliares
docs/               Guías de uso, arquitectura y planes técnicos
scripts/            Empaquetado y utilidades
```

### Documentación técnica por área

| Área | Documento |
|---|---|
| Arquitectura general | [ARCHITECTURE.md](docs/ARCHITECTURE.md) |
| Lectura natal | [LECTURA_NATAL_REFACTOR_ARQUITECTURA.md](docs/LECTURA_NATAL_REFACTOR_ARQUITECTURA.md) |
| Rectificación: diseño y roadmap | [RECTIFICACION_HORA_NATAL_PLAN.md](docs/RECTIFICACION_HORA_NATAL_PLAN.md) |
| Direcciones primarias | [PRIMARY_DIRECTIONS.md](docs/PRIMARY_DIRECTIONS.md) |
| Horaria nativa | [HORARY_NATIVE.md](docs/HORARY_NATIVE.md) |
| Tránsitos | [TRANSITOS_ESTRUCTURA_Y_FUNCIONAMIENTO.md](docs/TRANSITOS_ESTRUCTURA_Y_FUNCIONAMIENTO.md) |
| Calendario y efemérides | [CALENDARIO_EFEMERIDES_ARQUITECTURA.md](docs/CALENDARIO_EFEMERIDES_ARQUITECTURA.md) |
| Panorama predictivo | [CROSS_PERSONAL.md](docs/CROSS_PERSONAL.md) |
| Informes PDF | [PDF_REPORTS.md](docs/PDF_REPORTS.md) |
| Build universal | [UNIVERSAL_BUILD.md](docs/UNIVERSAL_BUILD.md) |

## Estado del proyecto

- Última versión estable: **1.1.2**.
- Aplicación y CLI universales: **ARM64 + Intel**.
- Deployment target: **macOS 14**.
- Validación: **386 tests, 1 omitido, 0 fallos**.
- Automatización: GitHub Actions genera artefactos universales y los adjunta a cada release etiquetada.

Consulta los cambios de cada versión en [CHANGELOG.md](CHANGELOG.md).

## Licencia y autoría

AstroMalik se distribuye bajo licencia MIT. Proyecto personal de **Eduardo Arias Bravo / AstroMalik**.
