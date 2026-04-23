# AstroMalik · macOS

App nativa de astrología para macOS. Calcula cartas natales con interpretaciones en castellano, tránsitos con scoring de intensidad, y gestiona un archivo personal de cartas guardadas — todo local, sin dependencias cloud.

Esta es la variante macOS del proyecto [AstroMalik](https://github.com/eduardoddddddd/AstroMalik) (Python + React). Comparte motor astronómico (Swiss Ephemeris) y corpus de interpretaciones, pero reescritos en Swift + SwiftUI para ejecución nativa en Apple Silicon.

![Platform](https://img.shields.io/badge/platform-macOS%2014%2B-blue) ![Swift](https://img.shields.io/badge/Swift-6.0-orange) ![Arch](https://img.shields.io/badge/arch-arm64-green) ![License](https://img.shields.io/badge/license-MIT-lightgrey)

---

## ✨ Características

- **Carta natal completa** — posiciones planetarias, ángulos (ASC, MC), 12 casas, aspectos
- **Interpretaciones en castellano** — corpus de 1.766 textos indexados (planeta en signo, planeta en casa, aspectos natales)
- **Tránsitos con scoring** — intensidad 1–5 ★ por rango de fechas
- **Archivo personal** — guardar, renombrar y eliminar cartas; base local en `~/Library/Application Support/AstroMalik/user.db`
- **Búsqueda de lugares** — seed offline + Nominatim (OpenStreetMap)
- **Multi-ventana** — cada carta se abre en su propia ventana nativa de macOS, redimensionable e independiente
- **100 % offline y local** — cálculos en el dispositivo, sin telemetría, sin cuentas

## 🧱 Stack técnico

| Capa | Tecnología |
|---|---|
| UI | SwiftUI (macOS 14+, multi-window, NavigationSplitView) |
| Efemérides | [Swiss Ephemeris](https://www.astro.com/swisseph/) en C, embebido como target SPM `CSwissEph` |
| Persistencia | `SQLite3` del sistema (sin GRDB ni otras dependencias) |
| Paquete | Swift Package Manager puro — cero dependencias externas |
| Target | macOS 14+, Apple Silicon (arm64) |

## 📋 Requisitos

- macOS 14 Sonoma o superior
- Xcode 15+ *o* toolchain Swift 6.0+
- ~50 MB de disco (binario + corpus + efemérides)

## 🚀 Ejecución rápida

```bash
git clone https://github.com/eduardoddddddd/AstroMalik-macOS.git
cd AstroMalik-macOS
swift build
open .build/arm64-apple-macosx/debug/AstroMalik
```

> ⚠️ **Importante — ejecución desde Xcode:** darle a ▶ en Xcode sobre un Swift Package ejecutable es problemático (el proceso puede arrancar en segundo plano sin ventana). Usa `open` desde terminal — la app incrusta un `Info.plist` en el binario y se registra como app GUI regular. Ver [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md) si quieres entender por qué.

## 🛠️ Build release (binario optimizado)

```bash
swift build -c release
open .build/arm64-apple-macosx/release/AstroMalik
```

## 🧪 Tests

```bash
swift test
```

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
│       ├── AstroMalikApp.swift       ← @main + WindowGroups + AppState
│       ├── Engine/
│       │   ├── AstroEngine.swift     ← Cálculo de carta natal
│       │   ├── JulianDay.swift       ← Hora local IANA → JD UT
│       │   └── TransitEngine.swift   ← Tránsitos + scoring 1–5 ★
│       ├── Store/
│       │   ├── SQLiteDB.swift        ← Wrapper minimalista sobre sqlite3
│       │   ├── CorpusStore.swift     ← corpus.db (read-only, bundle)
│       │   └── UserStore.swift       ← user.db (CRUD, Application Support)
│       ├── Models/            ← NatalChart, PlanetBody, Interpretation, Transit
│       ├── Services/
│       │   └── PlacesService.swift   ← Seed local + Nominatim
│       ├── Views/
│       │   ├── ContentView.swift         ← Sidebar + detail (NavigationSplitView)
│       │   ├── BirthChartForm.swift      ← Formulario de nacimiento
│       │   ├── NatalChartView.swift      ← HSplitView: posiciones + interpretaciones
│       │   ├── InterpretacionesView.swift← Lista filtrable y expandible
│       │   ├── SavedChartsView.swift     ← Grid de cartas guardadas
│       │   ├── TransitsView.swift        ← Tabla de tránsitos por periodo
│       │   └── ChartWindowHost.swift     ← Contenedor de ventana secundaria
│       └── Resources/
│           ├── corpus.db      ← 1.766 interpretaciones (read-only, 4 MB)
│           ├── cities_seed.json
│           └── ephe/          ← Archivos Swiss Ephemeris (.se1, 1800–2400)
└── Tests/
    └── AstroMalikTests/
        └── AstroEngineTests.swift
```

## 🏛️ Decisiones de arquitectura

### Ventanas multiples en lugar de sheets

Cada carta calculada abre una **ventana secundaria independiente** mediante `WindowGroup(id: "chart", for: UUID.self)` + `@Environment(\.openWindow)`. Esto sustituye a los sheets modales (que en macOS son de tamaño fijo y rompen el flujo de trabajo multi-carta). Permite:

- Abrir varias cartas a la vez y compararlas lado a lado
- Redimensionar libremente (el sheet tenía tamaño fijo)
- Integración natural con Mission Control, Exposé y gestión de ventanas del sistema

El estado compartido (`AppState.sessionCharts`) resuelve el UUID → carta al abrir cada ventana.

### Zero external dependencies

El proyecto **no depende de ningún paquete Swift externo**. SQLite usa la librería del sistema (linker flag `-lsqlite3`) y el wrapper `SQLiteDB.swift` es propio. Swiss Ephemeris va embebido como target C dentro del mismo SPM. Resultado: compilación inmediata, sin resolución de dependencias, binario autocontenido de ~3 MB en debug.

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

### ✅ Fase 1 — UX digna (completada abril 2026)
- Arquitectura multi-ventana (sheet → WindowGroup por UUID)
- Info.plist embebido + activación explícita de la app GUI
- Ventanas redimensionables con min/ideal/max correctos
- Feedback visual al calcular (confirmación + atajo ⌘↩)
- Fix de aislamiento de actor (`Task.detached` + `@State`) para Swift 6

### 🚧 Fase 2 — Rueda astrológica (en diseño)
- Render SVG/Canvas de la rueda natal con glifos zodiacales
- Planetas posicionados en sus grados exactos
- Líneas de aspecto coloreadas por tipo (tensos / suaves / menores)
- Interactividad: hover/click → interpretación lateral

### 📌 Fase 3 — Distribución como `.app`
- Script de empaquetado → bundle `AstroMalik.app` instalable en `/Applications`
- Icono personalizado en `.icns`
- Firma ad-hoc para desarrollo local (notarización opcional con Apple Developer ID)

### 🔮 Fase 4 — Avanzado
- Horaria con casas Regiomontanus (modo separado)
- Tránsitos interactivos con slider temporal en la rueda
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
