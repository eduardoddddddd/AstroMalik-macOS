# AstroMalik · macOS

App nativa de astrología para macOS. Calcula cartas natales con interpretaciones en castellano, tránsitos con scoring y línea temporal de intensidad diaria, consultas de horaria clásica y gestiona un archivo personal de cartas y consultas guardadas, todo en local y sin cuentas.

Esta es la variante macOS del proyecto [AstroMalik](https://github.com/eduardoddddddd/AstroMalik) (Python + React). Comparte motor astronómico (Swiss Ephemeris) y corpus de interpretaciones, pero reescritos en Swift + SwiftUI para ejecución nativa en Apple Silicon.

![Platform](https://img.shields.io/badge/platform-macOS%2014%2B-blue) ![Swift](https://img.shields.io/badge/Swift-6.0-orange) ![Arch](https://img.shields.io/badge/arch-arm64-green) ![License](https://img.shields.io/badge/license-MIT-lightgrey)

---

## ✨ Características

- **Carta natal completa** — posiciones planetarias, ángulos (ASC, MC), 12 casas, aspectos
- **Interpretaciones en castellano** — corpus de 1.779 textos indexados (planeta en signo, planeta en casa, aspectos natales, Ascendente)
- **Rueda natal interactiva** — signos, casas, planetas, ASC/MC y líneas de aspecto en SwiftUI
- **Lectura guiada** — Sol/Luna/ASC, regente del Ascendente, casas angulares, aspectos dominantes y síntesis editable
- **Tránsitos con timeline** — intensidad 1–5 ★, curva diaria por orbe y detalle textual por rango de fechas
- **Horaria integrada** — cálculo doctrinal en Python, visualización y archivo nativos en macOS
- **Archivo personal** — guardar, renombrar, etiquetar, anotar y buscar cartas; base local en `~/Library/Application Support/AstroMalik/user.db`
- **Búsqueda de lugares** — seed offline + Nominatim (OpenStreetMap)
- **Ventana única** — sidebar fija y panel de detalle para natal, tránsitos, horaria e historial
- **Tema configurable** — modo `Sistema`, `Claro` u `Oscuro`
- **Ayuda integrada** — entrada `Help > AstroMalik Help` con guía rápida de uso
- **100 % offline y local** — cálculos en el dispositivo, sin telemetría, sin cuentas

## 🧱 Stack técnico

| Capa | Tecnología |
|---|---|
| UI | SwiftUI (macOS 14+, `NavigationSplitView`, ventana única) |
| Efemérides | [Swiss Ephemeris](https://www.astro.com/swisseph/) en C, embebido como target SPM `CSwissEph` |
| Horaria | Proceso Python configurable (`horaria.cli`) invocado desde `Foundation.Process` + diagnóstico integrado |
| Persistencia | `SQLite3` del sistema (sin GRDB ni otras dependencias) |
| Paquete | Swift Package Manager puro — cero dependencias externas |
| Target | macOS 14+, Apple Silicon (arm64) |

## 📋 Requisitos

- macOS 14 Sonoma o superior
- Xcode 15+ *o* toolchain Swift 6.0+
- ~50 MB de disco (binario + corpus + efemérides)

### Requisito extra para Horaria

La parte de Horaria necesita `python3` disponible y el paquete [`horaria`](https://github.com/eduardoddddddd/horaria) instalado. También puedes fijar rutas sin tocar código:

```text
ASTROMALIK_PYTHON_PATH=/ruta/a/python3
ASTROMALIK_HORARIA_PATH=/ruta/al/repo/horaria
```

La app busca primero un módulo embebido, luego `ASTROMALIK_HORARIA_PATH`, después configuración local y finalmente el paquete instalado en Python. En Horaria hay una pantalla de diagnóstico.

## 🚀 Ejecución rápida

```bash
git clone https://github.com/eduardoddddddd/AstroMalik-macOS.git
cd AstroMalik-macOS
swift build
open .build/arm64-apple-macosx/debug/AstroMalik
```

> ⚠️ **Importante — ejecución desde Xcode:** darle a ▶ en Xcode sobre un Swift Package ejecutable es problemático (el proceso puede arrancar en segundo plano sin ventana). Usa `open` desde terminal — la app incrusta un `Info.plist` en el binario y se registra como app GUI regular. Ver [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md) si quieres entender por qué.

### Activar Horaria en local

```bash
git clone https://github.com/eduardoddddddd/horaria.git ~/Developer/horaria
cd ~/Developer/horaria
python3 -m pip install -e .
```

Si prefieres no instalar el paquete globalmente:

```bash
export ASTROMALIK_HORARIA_PATH="$HOME/Developer/horaria"
```

## 🛠️ Build release (binario optimizado)

```bash
swift build -c release
open .build/arm64-apple-macosx/release/AstroMalik
```

O empaquetar la app lista para doble clic:

```bash
./scripts/package_app.sh
open AstroMalik.app
```

## 🧪 Tests

```bash
swift test
```

Incluye tests de natal y tests de paridad de Horaria contra el motor Python externo.

Sanity check: carta natal del autor (`1976-10-11 20:33 Europe/Madrid`) verifica que Saturno queda en Casa 4 y ASC en Géminis ~0°.

## 📂 Estructura del proyecto

```
.
├── Package.swift              ← Manifiesto SPM (2 targets: CSwissEph + AstroMalik)
├── Info.plist                 ← Incrustado en __TEXT,__info_plist del binario
├── Sources/
│   ├── CSwissEph/             ← Swiss Ephemeris C library (libswe)
│   │   ├── include/           ← Headers + module.modulemap
│   │   └── *.c                ← sweph.c, swehouse.c, swecl.c, …
│   └── AstroMalik/
│       ├── AstroMalikApp.swift       ← @main + escena principal + AppState
│       ├── AppNavigation.swift       ← Rutas internas y navegación de detalle
│       ├── AppTheme.swift            ← Tokens de color + modo claro/oscuro/sistema
│       ├── AppResources.swift        ← Localización del bundle de recursos
│       ├── Engine/
│       │   ├── AstroEngine.swift     ← Cálculo de carta natal
│       │   ├── JulianDay.swift       ← Hora local IANA → JD UT
│       │   └── TransitEngine.swift   ← Tránsitos + scoring 1–5 ★ + muestras de intensidad diaria
│       ├── Store/
│       │   ├── SQLiteDB.swift        ← Wrapper minimalista sobre sqlite3
│       │   ├── CorpusStore.swift     ← corpus.db (read-only, bundle)
│       │   └── UserStore.swift       ← user.db (CRUD, Application Support)
│       ├── Models/            ← NatalChart, PlanetBody, Interpretation, Transit
│       ├── Horary/
│       │   ├── HoraryEngine.swift    ← Wrapper Swift del proceso Python
│       │   ├── Models/               ← Codable para chart/judgement JSON
│       │   ├── Store/                ← Historial horario en user.db
│       │   └── Views/                ← Formulario, historial y resultado horario
│       ├── Services/
│       │   └── PlacesService.swift   ← Seed local + Nominatim
│       ├── Views/
│       │   ├── ContentView.swift         ← Sidebar + detail (NavigationSplitView)
│       │   ├── BirthChartForm.swift      ← Formulario de nacimiento
│       │   ├── NatalChartView.swift      ← rueda, lectura guiada y textos
│       │   ├── NatalWheelView.swift      ← rueda natal interactiva
│       │   ├── GuidedReadingView.swift   ← lectura natal guiada
│       │   ├── InterpretacionesView.swift← Lista filtrable y expandible
│       │   ├── SavedChartsView.swift     ← Grid de cartas guardadas
│       │   ├── SettingsView.swift        ← Selector de apariencia
│       │   ├── HelpView.swift            ← Ayuda integrada
│       │   ├── TransitsView.swift        ← Tránsitos: timeline + tabla por periodo
│       │   ├── TransitTimelineView.swift ← Línea temporal de intensidad por orbe
│       └── Resources/
│           ├── corpus.db      ← 1.779 interpretaciones (read-only, 4 MB)
│           ├── cities_seed.json
│           └── ephe/          ← Archivos Swiss Ephemeris (.se1, 1800–2400)
└── Tests/
    └── AstroMalikTests/
        ├── AstroEngineTests.swift
        └── HoraryParityTests.swift
```

## 🏛️ Decisiones de arquitectura

### Ventana única con panel de detalle

La app usa una sola ventana con `NavigationSplitView`: la sidebar fija cambia de sección y el panel derecho carga formularios, listados y resultados. Esto simplifica el flujo y evita que natal, horaria o historial vayan abriendo ventanas adicionales.

- Navegación consistente entre Nueva Carta, Cartas Guardadas, Tránsitos y Horaria
- Cambio de contexto sin perder la sidebar ni abrir ventanas nuevas
- Mejor encaje para tema claro/oscuro y ayuda integrada

El estado compartido (`AppState`) mantiene la ruta de detalle, la apariencia elegida, la carta activa y el estado vivo de tránsitos.

### Tránsitos con timeline de intensidad

`TransitEngine` calcula los eventos del periodo y, además del score global 1–5 ★, guarda muestras diarias con fecha, orbe e intensidad normalizada. La vista de Tránsitos combina una línea temporal superior con la tabla existente: cada fila dibuja barras por día que suben hacia el aspecto exacto y bajan al alejarse, coloreadas por tipo de aspecto. Al pulsar una fila o barra se abre el detalle textual del tránsito.

### Horaria vía subproceso Python

La lógica doctrinal de Horaria no se porta a Swift en v1. La app invoca `python3 -m horaria.cli --json` desde `Foundation.Process`, envía el request en `stdin` y recibe en `stdout`:

- `chartJSON`
- `judgementJSON`
- `judgementText`

Esto evita duplicar reglas astrológicas en Swift, mantiene paridad con el motor Python probado y deja la parte macOS centrada en UI, persistencia e integración. La resolución del módulo ya no depende de un path local hardcodeado.

### Zero external dependencies en Swift

El proyecto **no depende de ningún paquete Swift externo**. SQLite usa la librería del sistema (linker flag `-lsqlite3`) y el wrapper `SQLiteDB.swift` es propio. Swiss Ephemeris va embebido como target C dentro del mismo SPM. La única dependencia externa funcional es Python para el modo Horaria.

### Info.plist embebido en el binario

Como es un executable SPM sin bundle `.app`, se incrusta el `Info.plist` en la sección `__TEXT,__info_plist` mediante linker flag (`-sectcreate`). Esto permite que macOS trate el proceso como app GUI regular en lugar de daemon de background. La activación de ventana se fuerza también con `NSApplication.shared.setActivationPolicy(.regular)` en el `init()` del App.

### Zonas horarias locales → JD UT

La hora de nacimiento introducida por el usuario es siempre **local** (en la zona IANA del lugar de nacimiento). `JulianDay.swift` convierte a UT antes de pasarla a Swiss Ephemeris. Este punto es crítico y fácil de equivocar — hay tests específicos para ello.

## 🗺️ Roadmap

### ✅ Fase 0 — Bootstrap (completada)
- Port del motor Python a Swift + CSwissEph
- UI básica SwiftUI con formulario + lista de resultados
- Persistencia local con SQLite puro
- Tests de sanity sobre carta de referencia

### ✅ Fase 1 — UX base (completada abril 2026)
- Info.plist embebido + activación explícita de la app GUI
- Feedback visual al calcular (confirmación + atajo ⌘↩)
- Fix de aislamiento de actor (`Task.detached` + `@State`) para Swift 6

### ✅ Fase 2 — Horaria + shell de app (completada abril 2026)
- Modo Horaria integrado en la app macOS
- Historial horario persistente en `user.db`
- Navegación de ventana única
- Modo `Sistema / Claro / Oscuro`
- Ayuda integrada en el menú `Help`
- Script de empaquetado `AstroMalik.app`

### ✅ Fase 3 — Lectura pro inicial (completada abril 2026)
- Rueda natal interactiva en SwiftUI
- Planetas, casas, ASC/MC y aspectos natales
- Lectura guiada con regente del Ascendente
- Síntesis editable y nota Markdown preparada para Joplin
- Archivo con notas, etiquetas y búsqueda
- Tránsitos con línea temporal de intensidad diaria por orbe

### 🚧 Fase 4 — Rueda y exportación avanzada
- Refinar geometría visual de la rueda
- Export PNG/PDF de carta y lectura
- Plantilla Joplin configurable

### 📌 Fase 5 — Distribución pulida
- Icono personalizado en `.icns`
- Notarización opcional con Apple Developer ID
- Exportadores y flujo de instalación más pulidos

### 🔮 Fase 6 — Avanzado
- Slider temporal de tránsitos integrado en la rueda natal
- Sinastría (superposición de dos cartas)
- Export PNG/PDF de la carta
- Integración opcional con Joplin (log de consultas)

## 🔗 Relación con otros repos

Este repo es la variante **macOS nativa** de una familia de proyectos:

- [`AstroMalik`](https://github.com/eduardoddddddd/AstroMalik) — backend FastAPI + frontend React/Vite (variante web, desplegada en HuggingFace Spaces / GitHub Pages)
- `AstroMalik-macOS` — *este repo* (app nativa Swift/SwiftUI para Apple Silicon)
- Ambas comparten corpus `corpus.db` y el motor Swiss Ephemeris

## 📜 Licencia y créditos

Código de aplicación: **MIT License**.

**Swiss Ephemeris** © [Astrodienst AG](https://www.astro.com/swisseph/) — licenciado bajo [Swiss Ephemeris Public License](https://www.astro.com/ftp/swisseph/LICENSE) (GPL-compatible dual-licensing para uso no comercial). Si redistribuyes una build comercial, revisa las condiciones de Astrodienst.

Los archivos `.se1` en `Resources/ephe/` son datos de efemérides de Astrodienst y están sujetos a su licencia.

## 👤 Autor

Eduardo Arias · [@eduardoddddddd](https://github.com/eduardoddddddd)

Órgiva, Granada · 2026
