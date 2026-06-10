# AstroMalik macOS

[![Ask DeepWiki](https://deepwiki.com/badge.svg)](https://deepwiki.com/eduardoddddddd/AstroMalik-macOS)

![Platform](https://img.shields.io/badge/platform-macOS%2014%2B-blue)
![Swift](https://img.shields.io/badge/Swift-6-orange)
![SwiftUI](https://img.shields.io/badge/UI-SwiftUI-0A84FF)
![Swiss Ephemeris](https://img.shields.io/badge/ephemeris-Swiss%20Ephemeris-6f42c1)
![SQLite](https://img.shields.io/badge/storage-SQLite-003B57)
![Local First](https://img.shields.io/badge/privacy-local--first-2ea44f)
![License](https://img.shields.io/badge/license-MIT-lightgrey)

AstroMalik macOS es una aplicación nativa de astrología tradicional para macOS. Calcula cartas natales, lecturas, sinastrías, retornos, tránsitos, técnicas predictivas clásicas/helenísticas, horaria e informes documentales desde una app SwiftUI local-first.

El objetivo no es ser un panel de datos sueltos: la app intenta convertir cálculo astrológico, corpus interpretativo y documentación personal en un flujo de trabajo de astrólogo: calcular, leer, comparar, predecir, sintetizar y archivar.

## Principios del proyecto

- **Local-first**: cartas, notas y consultas viven en el Mac del usuario.
- **Cálculo determinista**: Swiss Ephemeris embebido y motores Swift propios.
- **Corpus visible**: los textos interpretativos no son decoración; se integran en las vistas de lectura.
- **Doctrina explícita**: regencias, secta, dignidades, profecciones, ZR, horaria y direcciones se documentan en código y docs.
- **Exportación documental**: Joplin y PDF son salidas, no requisitos para calcular.
- **Sin dependencias externas de runtime** para el cálculo base.

Los datos de usuario no se guardan en el repositorio. La base local está en:

```text
~/Library/Application Support/AstroMalik/user.db
```

## Estado actual

La app está en fase 1.x: usable como herramienta astrológica de escritorio con módulos natales, predictivos, relacionales y documentales. La navegación se organiza por flujo de trabajo:

- **Carta Natal**: nueva carta, cartas guardadas y lectura.
- **Predictivas**: tránsitos, progresiones, direcciones primarias, profecciones, Firdaria y Zodiacal Releasing.
- **Retornos**: revolución solar y revolución lunar.
- **Síntesis**: panorama predictivo cross-personal.
- **Sinastría y Horaria**: comparación de cartas y consulta horaria clásica.
- **Herramientas**: efemérides, informes, ajustes.

## Funcionalidades principales

### Carta natal y lectura

- Cálculo natal con Swiss Ephemeris.
- Rueda natal interactiva en SwiftUI.
- Posiciones planetarias, casas, ASC/MC y aspectos.
- Corpus natal para planeta-signo, planeta-casa y aspectos.
- **Lectura natal documental**: documento continuo por capítulos, no acordeón ni panel de botones.
- Capítulos de lectura: retrato inmediato, tríada, regente del Ascendente, dominantes, aspectos estructurales, casas y síntesis.
- Densidad `Esencial` / `Completa`.
- Buscador dentro del texto de la lectura.
- Síntesis editable persistida por carta.
- Nota Markdown para Joplin serializada desde el mismo documento de lectura.

Documentación específica: [`docs/LECTURA_NATAL_REFACTOR_ARQUITECTURA.md`](docs/LECTURA_NATAL_REFACTOR_ARQUITECTURA.md).

### Análisis natal extendido

- Lotes helenísticos.
- Almuten Figuris.
- Regente de la genitura.
- Configuraciones aspectuales.
- Distribución elemental/modal/hemisférica.
- Recepciones mutuas.
- Antiscia y contraantiscia.
- Declinaciones y fuera de límites.
- Estrellas fijas.

### Archivo local de cartas

- Persistencia SQLite local.
- Cartas guardadas con nombre, fecha, hora, zona, coordenadas y lugar.
- Notas y etiquetas por carta.
- Búsqueda por texto, etiqueta y metadatos.
- Reutilización de cartas en lectura, sinastría, retornos, tránsitos y predictivas.

### Sinastría

- Comparación de dos cartas guardadas.
- Aspectos A→B y B→A.
- Rueda doble.
- Corpus específico de sinastría.
- Salida documental a Joplin.

### Retornos

- Revolución solar con retorno exacto del Sol.
- Carta anual para lugar elegido.
- Superposición natal/solar.
- Revolución lunar con secuencia de retornos dentro de un periodo.
- Métricas técnicas y exportación documental.

### Tránsitos

- Eventos por rango de fechas.
- Orbes específicos de tránsito.
- Nodo Norte y Nodo Sur como puntos transitantes/natales.
- Fusión del eje nodal para evitar duplicados.
- Scoring técnico, relevancia personal e impacto temporal.
- Timeline visual y detalle por evento.
- Ingresos por casa.

Documento técnico: [`docs/TRANSITOS_ESTRUCTURA_Y_FUNCIONAMIENTO.md`](docs/TRANSITOS_ESTRUCTURA_Y_FUNCIONAMIENTO.md).

### Calendario y efemérides

- Calendario astrológico mensual.
- Lunaciones, eclipses, estaciones, ingresos en signo, Luna vacía de curso y aspectos mundanos.
- Efeméride diaria a 00:00 UTC.
- Resumen mensual personalizado por carta natal.
- Exportación a Joplin.

Documento técnico: [`docs/CALENDARIO_EFEMERIDES_ARQUITECTURA.md`](docs/CALENDARIO_EFEMERIDES_ARQUITECTURA.md).

### Predictivas tradicionales

- **Direcciones primarias** Regiomontanas: directas/conversas, planos zodiacal/eclíptico, claves Naibod/Ptolomeo/Brahe, Pars Fortunae opcional, corpus clásico y filtros profesionales.
- **Arco solar**: real y Naibod.
- **Progresiones secundarias**: día por año, MC/ASC progresados, fase lunar progresada, aspectos y cambios destacados.
- **Profecciones**: whole sign desde Ascendente, Lord of the Year y sub-profecciones.
- **Firdaria**: ciclos mayores y menores con secta.
- **Zodiacal Releasing**: Espíritu/Fortuna, L1/L2, Loosing of the Bond y peaks.

Documentación:

- [`docs/PRIMARY_DIRECTIONS.md`](docs/PRIMARY_DIRECTIONS.md)
- [`docs/primary-directions-corpus-curation.md`](docs/primary-directions-corpus-curation.md)

### Horaria clásica

Horaria usa por defecto motor Swift nativo (`HoraryNativeEngine`) con:

- siete planetas tradicionales;
- casas Regiomontanus;
- dignidades esenciales y accidentales;
- hora planetaria y radicalidad;
- Parte de Fortuna y Parte del Espíritu;
- Luna vía combusta y fuera de curso;
- significadores por casa;
- recepción, perfección, translación y colección básica;
- veredicto estructurado.

Documento técnico: [`docs/HORARY_NATIVE.md`](docs/HORARY_NATIVE.md).

### Panorama predictivo cross-personal

El módulo cross-personal orquesta motores predictivos reales y produce una síntesis por capas:

- anual;
- medio plazo;
- corto plazo;
- lunar.

Puede generar narrativa con Anthropic si el usuario configura API key. El cálculo determinista no depende de esa integración.

Documento: [`docs/CROSS_PERSONAL.md`](docs/CROSS_PERSONAL.md).

### Informes PDF

La app incluye infraestructura de informes profesionales:

- plantillas HTML/CSS;
- renderizado PDF con WebKit;
- rueda natal y rueda doble en SVG;
- timelines y tablas vectoriales;
- exportación opcional como adjunto a Joplin.

Documentación: [`docs/PDF_REPORTS.md`](docs/PDF_REPORTS.md).

### CLI

`astromalik-cli` permite ejecutar flujos cross-personal desde terminal, scripts o LaunchAgent.

Documento: [`docs/CLI.md`](docs/CLI.md).

## Stack técnico

- Swift 6 / SwiftPM.
- SwiftUI para macOS 14+.
- Target C `CSwissEph` con Swiss Ephemeris embebido.
- SQLite3 del sistema mediante wrapper propio.
- WebKit para render PDF.
- Sin dependencias externas de Swift Package Manager.
- Integraciones opcionales: Joplin Web Clipper, Anthropic, OpenRouter/Foundry Local en módulos concretos.

## Requisitos

- macOS 14 o superior.
- Xcode instalado para compilar/testear.
- Apple Silicon recomendado.
- Joplin Desktop solo si se quiere exportar notas vía Web Clipper.

## Desarrollo

Compilar en debug:

```bash
swift build
```

Ejecutar la app SPM:

```bash
.build/arm64-apple-macosx/debug/AstroMalik
```

Ejecutar tests:

```bash
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift test
```

Empaquetar la app macOS:

```bash
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer scripts/package_app.sh
open AstroMalik.app
```

Después de cambios de código o UI, este repo espera regenerar `AstroMalik.app` y comprobar el timestamp de:

```text
AstroMalik.app/Contents/MacOS/AstroMalik
```

## Recursos y persistencia

Recursos embebidos en el bundle:

```text
Sources/AstroMalik/Resources/corpus.db
Sources/AstroMalik/Resources/cities_seed.json
Sources/AstroMalik/Resources/fixed_stars.json
Sources/AstroMalik/Resources/ephe/
Sources/AstroMalik/Resources/Reports/
Sources/AstroMalik/Reports/Templates/
```

Persistencia local del usuario:

```text
~/Library/Application Support/AstroMalik/user.db
```

Ahí viven cartas guardadas, metadatos, cachés persistentes y notas de lectura.

## Estructura del repositorio

```text
Sources/
  AstroMalik/              Módulo principal compartido
    Engine/                Motores astrológicos
    Engine/Reading/        Composer de lectura natal
    Models/                Modelos de dominio
    Persistence/           Stores persistentes
    Reports/               Infraestructura y builders PDF
    Resources/             Corpus, efemérides y recursos empaquetados
    Store/                 SQLite, corpus y usuario
    Views/                 UI SwiftUI
  AstroMalikApp/           Ejecutable GUI
  AstroMalikCLI/           Ejecutable headless
Tests/
  AstroMalikTests/         Tests de motores, UI lógica, informes y stores
  AstroMalikCLITests/      Tests del CLI
docs/                      Documentación técnica y planes
scripts/                   Empaquetado, smoke tests y utilidades
```

## Documentación principal

- [`docs/ARCHITECTURE.md`](docs/ARCHITECTURE.md) — mapa técnico general.
- [`docs/LECTURA_NATAL_REFACTOR_ARQUITECTURA.md`](docs/LECTURA_NATAL_REFACTOR_ARQUITECTURA.md) — refactor de Lectura natal.
- [`docs/PRIMARY_DIRECTIONS.md`](docs/PRIMARY_DIRECTIONS.md) — direcciones primarias.
- [`docs/HORARY_NATIVE.md`](docs/HORARY_NATIVE.md) — horaria nativa.
- [`docs/TRANSITOS_ESTRUCTURA_Y_FUNCIONAMIENTO.md`](docs/TRANSITOS_ESTRUCTURA_Y_FUNCIONAMIENTO.md) — tránsitos.
- [`docs/CALENDARIO_EFEMERIDES_ARQUITECTURA.md`](docs/CALENDARIO_EFEMERIDES_ARQUITECTURA.md) — calendario y efemérides.
- [`docs/PDF_REPORTS.md`](docs/PDF_REPORTS.md) — informes PDF.
- [`docs/CROSS_PERSONAL.md`](docs/CROSS_PERSONAL.md) — panorama predictivo.
- [`docs/CLI.md`](docs/CLI.md) — uso del CLI.

## Integraciones opcionales

### Joplin

La app puede crear notas usando el Web Clipper local de Joplin. Host, puerto, token y cuaderno se configuran en Ajustes. Si el token no está configurado, se intenta resolver desde `ASTROMALIK_JOPLIN_TOKEN` o desde la configuración local de Joplin Desktop.

### Anthropic

El módulo cross-personal puede redactar narrativa con Anthropic. La clave se resuelve desde Keychain o `ANTHROPIC_API_KEY`.

### OpenRouter / Foundry Local

Algunos módulos de interpretación contextual pueden usar OpenRouter o Foundry Local como capa generativa opcional. No sustituyen el cálculo determinista.

## Tests

La suite cubre motores astronómicos, predictivas, horaria, lectura natal, persistencia, PDF, CLI e integraciones mockeadas.

Última validación local relevante tras el refactor de Lectura:

```text
344 tests ejecutados
1 skipped
0 failures
```

## Licencia

MIT, según la configuración del repositorio.

## Autor

Proyecto personal de Eduardo Arias Bravo / AstroMalik.
