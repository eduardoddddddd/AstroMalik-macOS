# Plan de portado AstroMalik macOS → iPhone/iPad (universal)

> Documento maestro para coordinar el porte. Pensado para que **Codex (ChatGPT 5.5 high / xhigh)** ejecute el grueso del trabajo en _prompts_ secuenciales, con revisiones puntuales del arquitecto (Claude Opus 4.7, plan Pro). Última actualización: 2026-05-15.

## 0. Resumen ejecutivo

- **Objetivo:** un nuevo target *iOS universal (iPhone + iPad)* compartiendo el `Package.swift` actual, manteniendo cálculos astrológicos, persistencia, reportes PDF, vistas SwiftUI y eliminando todo lo que dependa de procesos/servicios externos.
- **Distribución:** sideload personal vía Xcode (perfil 7 días) o AltStore. **No App Store**, por tanto:
  - No necesitamos backend para claves API.
  - Pero se aprovecha para **eliminar todas las integraciones LLM/Joplin/Foundry** según decisión del usuario.
- **Importante — distinción CÁLCULO vs INTERPRETACIÓN LLM:**
  - Horary y Primary Directions ya tienen **cálculo 100% Swift nativo** sobre `CSwissEph` (`HoraryNativeEngine.swift`, motor PD nativo). Eso se porta intacto.
  - Lo único que se quita es la **capa de narrativa/interpretación basada en LLM** (Foundry Local + OpenRouter).
  - `PrimaryDirectionLocalReading.swift` es una **lectura operativa local determinista escrita en Swift puro** (no es LLM) → se mantiene también.
- **Features/archivos que se ELIMINAN del port iOS** (no se portan, no se compilan en iOS):
  1. `AnthropicClient` + `CrossPersonalNarrativeBuilder` (narrativa Cross-Personal vía Anthropic API).
  2. `OpenRouterClient.swift` en `PrimaryDirections/Interpretation/` (LLM remoto).
  3. `PrimaryDirectionFoundryClient.swift` (LLM local Foundry vía Python).
  4. `PrimaryDirectionContextualInterpreter.swift` + `PDInterpretationContextBuilder.swift` (orquestador y prompt-builder para el LLM PD).
  5. Struct `ContextualInterpretation` si queda huérfana tras lo anterior (a confirmar por Codex).
  6. `HoraryFoundryClient.swift` y la sección "Lectura local con Foundry" en `HoraryResultView.swift` (líneas 336 y 588).
  7. `JoplinClipperService` + `JoplinOpenRouterKeyLocator` (clipper Joplin Desktop, sin sentido en iOS).
  8. `astromalik-cli` (no se incluye en target iOS; se mantiene macOS-only).
- **Features que se MANTIENEN íntegros:** todos los cálculos (Swiss Ephemeris C, transitos, returns, profections, ZR, firdaria, **horary nativo Swift**, **primary directions nativo Swift** + `PrimaryDirectionLocalReading`), persistencia SQLite, reportes PDF (PDFKit multiplataforma) y todas las vistas SwiftUI (la lectura técnica del juicio horario y la lectura operativa de PD siguen funcionando sin LLM).
- **Estructura de capas:**
  - `CSwissEph` (C puro) → portable.
  - `AstroMalik` (librería Swift) → se mantiene **un único módulo**, con `#if os(iOS)` / `#if os(macOS)` para las pocas zonas que tocan AppKit (≤ 7 archivos identificados).
  - `AstroMalikApp` (macOS) → permanece intacto.
  - `AstroMalikIOSApp` (NUEVO) → target ejecutable iOS-only.
  - `astromalik-cli` (macOS) → se condiciona a `.macOS` en `Package.swift`.

## 1. Inventario técnico relevante

| Categoría | Ubicación | Estado |
|---|---|---|
| Lib C Swiss Ephemeris | `Sources/CSwissEph` | ✅ portable, C ANSI, sin POSIX exótico |
| App SwiftUI principal | `Sources/AstroMalik/AstroMalikApp.swift` | ⚠️ usa `NSApplication`, `AppKit`, `WindowGroup` con menús macOS |
| Tema | `AppTheme.swift` | ⚠️ usa `NSColor` |
| Reports / PDF | `Sources/AstroMalik/Reports/**` | ✅ PDFKit funciona idéntico iOS (revisar 1 archivo `ReportSmoke.swift`) |
| Vistas con AppKit directo | `Views/MyReportsView.swift`, `Views/PDFExportButton.swift`, `Views/NatalChartView.swift` (copy), `Views/CrossPersonal/CrossPersonalView.swift` (copy), `Views/SettingsView.swift` (NSOpenPanel) | ⚠️ aislar con `#if` o reemplazar |
| Persistencia | `Persistence/MigrationRunner.swift`, SQLite | ✅ usa `applicationSupportDirectory`, portable |
| Recursos | `Resources/ephe`, `corpus.db`, etc. | ✅ se copian igual |
| Tests | `Tests/AstroMalikTests`, `Tests/AstroMalikCLITests` | ⚠️ los del CLI dejan de compilar en iOS — condicionar |
| Integraciones a borrar | ver §0 | 🚮 eliminar archivos y referencias |

AppKit usage **total** identificado (grep): 7 archivos. Ningún ViewModel ni Engine usa AppKit. Confirmado que el aislamiento es viable sin refactor mayor.

## 2. Estrategia general

1. **Limpieza primero, port después.** Antes de añadir el target iOS, eliminamos del módulo `AstroMalik` todo el código que se va a tirar (Anthropic / OpenRouter / Joplin / Foundry). Esto reduce el footprint a portar y deja la base limpia. *Esto se hace en `main` o en una rama `port/ios` — decisión del usuario.*
2. **Aislar AppKit con `#if os(macOS)`** en los 7 archivos identificados, reemplazando o `#else`-eando las llamadas con equivalentes iOS (UIPasteboard, ShareSheet, UIDocumentPicker, etc.).
3. **Añadir plataforma iOS al `Package.swift`** y crear target ejecutable `AstroMalikIOSApp` con escena `WindowGroup` simple.
4. **Crear proyecto Xcode delgado** que importe el SwiftPM como dependencia local — es la forma estándar de poder firmar y desplegar a iPhone con perfil personal. SwiftPM solo NO permite generar `.ipa` directamente.
5. **Adaptar UI compacta para iPhone**: `NavigationSplitView` ya degrada bien en iPhone (sidebar → stack). Las vistas más densas (TransitsView, EphemerisCalendarView, SynastryView) necesitan modo "compact" con cards o tabla scrollable horizontal. **iPad reutiliza la vista actual prácticamente sin tocar**.
6. **Reportes PDF**: se sustituye la lógica de guardar/abrir por `ShareLink` + `UIDocumentPickerViewController` (export to Files) e integración con QuickLook.
7. **Smoke test en simulador iPhone 15** y luego en dispositivo real con sideload Xcode.

## 3. Roadmap por fases (con prompts para Codex)

Cada fase produce un commit autocontenido. Codex ejecuta el prompt en xhigh; Claude (arquitecto) revisa cuando se indica 🔎. Los prompts están escritos para ser pegados tal cual.

> **Convención prompts:** Codex trabaja sobre rama `port/ios` desde `main`. Cada prompt asume `pwd` en el root del repo. Después de cada fase: `swift build` en macOS debe seguir verde antes de seguir.

---

### Fase 0 — Preparación de rama y branch hygiene (5 min, manual)

```bash
git checkout main && git pull
git checkout -b port/ios
mkdir -p docs/port-ios
```

Sin prompt — el usuario lo hace antes de empezar.

---

### Fase 1 — Eliminar integraciones externas (Codex, ~30 min) 🔎 revisa Claude al final

**Prompt para Codex (xhigh):**

````
Estás en el repo AstroMalik (SwiftPM, macOS). Rama actual: port/ios. Objetivo de esta tarea: ELIMINAR código y referencias a integraciones externas que NO se portarán a iOS. Mantén la app macOS COMPILANDO al final.

CONTEXTO CLAVE (no te confundas):
- Horary y Primary Directions tienen el CÁLCULO 100% Swift nativo (HoraryNativeEngine.swift, motor PD nativo). NO TOCAR.
- PrimaryDirectionLocalReading.swift es Swift puro determinista (no es LLM). MANTENER.
- Lo único que se elimina es la capa de NARRATIVA/INTERPRETACIÓN LLM construida encima.

ARCHIVOS A BORRAR (rm -f):
- Sources/AstroMalik/Services/AnthropicClient.swift
- Sources/AstroMalik/Services/CrossPersonalNarrativeBuilder.swift
- Sources/AstroMalik/Services/JoplinClipperService.swift
- Sources/AstroMalik/Services/JoplinOpenRouterKeyLocator.swift
- Sources/AstroMalik/PrimaryDirections/Interpretation/OpenRouterClient.swift
- Sources/AstroMalik/PrimaryDirections/Interpretation/PrimaryDirectionFoundryClient.swift
- Sources/AstroMalik/PrimaryDirections/Interpretation/PrimaryDirectionContextualInterpreter.swift
- Sources/AstroMalik/PrimaryDirections/Interpretation/PDInterpretationContextBuilder.swift
- Sources/AstroMalik/Horary/Interpretation/HoraryFoundryClient.swift
- docs/ANTHROPIC_INTEGRATION.md
- docs/FOUNDRY_LOCAL_INTEGRATION.md

ARCHIVOS A REVISAR (NO borrar a ciegas — pueden ser solo modelos de datos huérfanos):
- Sources/AstroMalik/PrimaryDirections/Interpretation/ContextualInterpretation.swift — si tras borrar el interpreter y el builder NADIE más lo referencia, bórralo; si la vista PrimaryDirectionDetailView.swift sigue mostrando esos datos desde cache SQLite previo, evalúa: opción A) borrar la sección de la vista, opción B) mantener struct como modelo de datos read-only para entradas cacheadas. Documenta cuál escogiste.

REFERENCIAS A LIMPIAR (mantén intactos los cálculos):
1. Sources/AstroMalik/AstroMalikApp.swift — quita campos joplinSettings, loadJoplinSettings, saveJoplinSettings, y cualquier import/uso de los clientes borrados.
2. Sources/AstroMalik/Views/CrossPersonal/CrossPersonalView.swift — elimina sección "Generar narrativa con Anthropic"; el reporte cross-personal queda solo con datos crudos + plantilla. Mantén export PDF.
3. Sources/AstroMalik/Views/SettingsView.swift — quita ajustes Anthropic API key, OpenRouter API key, Joplin endpoint/token, Foundry rutas Python.
4. Sources/AstroMalik/PrimaryDirections/Views/PrimaryDirectionsView.swift — quita los statusBadge/strings que referencian `PrimaryDirectionFoundryClient.configuredModel` (líneas 25 y 221) y el botón/flujo de `requestContextualInterpretation`. CONSERVA todo el flujo de cálculo y la visualización de `PrimaryDirectionLocalReading` (esa es Swift puro).
5. Sources/AstroMalik/PrimaryDirections/ViewModels/PrimaryDirectionsViewModel.swift — quita propiedad `contextualInterpretation`, dependencia `interpreter: PrimaryDirectionContextualInterpreter?` y método `requestContextualInterpretation`. NO TOQUES nada relacionado con cálculo de direcciones, filtros, ni `localReading`.
6. Sources/AstroMalik/PrimaryDirections/Views/PrimaryDirectionDetailView.swift — quita la sección que muestra `contextualInterpretation` y sus helpers `factorRow`/`areaRow`. CONSERVA la sección de `PrimaryDirectionLocalReading.build(for: direction)` (líneas 18-19) — es lectura local determinista, no LLM.
7. Sources/AstroMalik/PrimaryDirections/Views/PDDetailContainer.swift — quita el parámetro `interpreter: PrimaryDirectionContextualInterpreter?`.
8. Sources/AstroMalik/Horary/Views/HoraryResultView.swift — quita la sección "Genera una lectura local con Foundry…" (línea 336) y la llamada `HoraryFoundryClient().interpret(query:)` (línea 588) y todo el state asociado a `aiInterpretation`. CONSERVA TODA la visualización del juicio técnico nativo (es lo que ya calcula HoraryNativeEngine).
9. Sources/AstroMalik/Reports/Builders/CrossPersonalReportBuilder.swift — si depende de narrativa Anthropic, sustituye por sección estática (placeholder doctrinal) o elimina la sección narrativa.
7. README.md y CHANGELOG.md — añade entrada "Removed: integraciones Anthropic/OpenRouter/Joplin/Foundry (preparación port iOS)".

CRITERIOS DE ACEPTACIÓN:
- `swift build` en macOS verde, sin warnings nuevos.
- `swift test` verde (los tests que dependían de los clientes borrados deben eliminarse — listarlos en el commit).
- No queda ningún `import` de los archivos borrados.
- grep "Anthropic\|OpenRouter\|JoplinClipper\|Foundry" Sources/ debe estar vacío salvo strings inocuos en docs.

COMMIT: `chore(ios-port): remove Anthropic/OpenRouter/Joplin/Foundry integrations`.

REPORTA: lista de archivos borrados, líneas eliminadas aprox, y cualquier decisión donde tuviste que escoger entre "borrar el feature entero" vs "dejar un stub".
````

**🔎 Revisión Claude:** validar que `CrossPersonalView` y `PrimaryDirectionsView` siguen siendo útiles sin LLM, y que no quedaron símbolos huérfanos. ~5 min.

---

### Fase 2 — Aislar AppKit en el módulo compartido (Codex, ~45 min) 🔎 revisa Claude

**Prompt para Codex (xhigh):**

````
Repo AstroMalik, rama port/ios, post Fase 1. Objetivo: aislar el uso de AppKit en el módulo `AstroMalik` para que ese módulo compile tanto en macOS como en iOS. El target ejecutable macOS se mantiene intacto.

PASO 1 — añadir helper de plataforma:
Crea Sources/AstroMalik/PlatformShims.swift con typealiases y funciones cross-plataforma:
- PlatformColor = NSColor en macOS, UIColor en iOS
- PlatformImage = NSImage / UIImage
- func platformCopyToPasteboard(_ string: String) usando NSPasteboard en macOS, UIPasteboard en iOS.
- func platformReveal(_ url: URL) que en macOS llama NSWorkspace.shared.activateFileViewerSelecting, en iOS hace no-op (o presenta share sheet — ver paso 3).
Usa `#if canImport(AppKit) && os(macOS)` y `#if canImport(UIKit)` para los imports.

PASO 2 — refactorizar archivos AppKit-tainted:
Por cada uno de estos 7 archivos sustituye llamadas directas por el shim:
- Sources/AstroMalik/AppTheme.swift (NSColor)
- Sources/AstroMalik/AstroMalikApp.swift (NSApplication — todo el código de activación SOLO en `#if os(macOS)`)
- Sources/AstroMalik/Views/MyReportsView.swift (NSWorkspace)
- Sources/AstroMalik/Views/NatalChartView.swift (NSPasteboard copy)
- Sources/AstroMalik/Views/PDFExportButton.swift (NSSavePanel, NSWorkspace.open)
- Sources/AstroMalik/Views/CrossPersonal/CrossPersonalView.swift (NSPasteboard)
- Sources/AstroMalik/Views/SettingsView.swift (NSOpenPanel para elegir carpeta — en iOS usar UIDocumentPickerViewController via UIViewControllerRepresentable; documenta en TODO si lo dejas para Fase 5)
- Sources/AstroMalik/Reports/Service/ReportSmoke.swift (NSWorkspace.open)

PASO 3 — export/share unificado para PDFs:
En PDFExportButton.swift crea una rama `#if os(iOS)` que presente ShareLink(item: URL del PDF) en lugar del NSSavePanel + NSWorkspace.open. Mantén el comportamiento macOS exacto.

PASO 4 — CHECKLIST:
- `swift build` macOS verde.
- Para validar iOS: añade temporalmente `.iOS(.v17)` al array platforms del Package.swift y prueba `swift build -Xswiftc "-target" -Xswiftc "arm64-apple-ios17.0"` (puede no funcionar 100% por SQLite linking — si falla, documenta el error pero deja el código preparado; lo arreglamos en Fase 3 con el target Xcode).
- Reporta cualquier archivo donde el shim no fue posible y necesitó un `#if os(macOS) ... #else ... #endif` completo.

COMMIT: `refactor(ios-port): isolate AppKit usage behind platform shims`.

NO HAGAS:
- No crees aún el target iOS ni modifiques los demás targets de Package.swift más allá de añadir .iOS(.v17) si decides activarlo.
- No reescribas vistas para layout compact — eso es Fase 5.
````

**🔎 Revisión Claude:** lee `PlatformShims.swift` y revisa que `#if os(macOS)` esté correctamente cerrado en `AstroMalikApp.swift` (la parte de `NSApplication.shared.setActivationPolicy` debe quedar 100% fuera del build iOS). ~10 min.

---

### Fase 3 — Añadir target iOS al SwiftPM y crear app shell (Codex, ~40 min)

**Prompt para Codex (xhigh):**

````
Repo AstroMalik, rama port/ios, post Fase 2. Objetivo: declarar iOS como plataforma soportada del Package y crear un target ejecutable iOS mínimo que arranque la app SwiftUI compartida.

PASO 1 — Package.swift:
- platforms: añadir `.iOS(.v17)` junto a `.macOS(.v14)`.
- Crear nuevo target: `.executableTarget(name: "AstroMalikIOSApp", dependencies: ["AstroMalik"], path: "Sources/AstroMalikIOSApp")`.
- El target `astromalik-cli` debe quedar condicionado a macOS: envuélvelo en `#if os(macOS)` dentro de Package.swift usando la técnica estándar (declarar targets en un array Swift y filtrar). Si SwiftPM no permite `#if` sobre targets, declara `astromalik-cli` igual pero documenta en su `Sources/AstroMalikCLI/` un `#if os(macOS)` envolviendo todo el código del CLI para que no rompa en iOS.
- Verifica que el target `AstroMalik` tiene linkerSettings que funcionen también en iOS: `linkedLibrary("sqlite3")` funciona en ambos (iOS provee libsqlite3).

PASO 2 — Sources/AstroMalikIOSApp/:
Crea:
- App.swift: `@main struct AstroMalikIOSApp: App { var body: some Scene { WindowGroup { RootView() } } }`
- RootView.swift: por ahora un `ContentView()` (reusa Sources/AstroMalik/Views/ContentView.swift). Si ContentView depende de cosas macOS-only (ventanas, menús), envuélvelo o crea una RootView específica iOS que use `NavigationStack` (iPhone) o `NavigationSplitView` (iPad) con la lista de secciones principales del AppNavigation.
- Info.plist iOS mínimo (UILaunchScreen vacío, UISupportedInterfaceOrientations iPhone portrait + landscape, iPad all).

PASO 3 — Recursos:
Verifica que `Resources/ephe/*.se1` y `corpus.db` se incluyen también en build iOS. Como están en el target `AstroMalik` ya se transmiten — confirma.

PASO 4 — Build:
- `swift build` macOS verde.
- `swift build -Xswiftc "-target" -Xswiftc "arm64-apple-ios17.0-simulator"` debería al menos compilar el módulo AstroMalik. Si falla por SQLite o linker reporta el error exacto.

COMMIT: `feat(ios-port): add iOS platform and AstroMalikIOSApp executable target`.

NO HAGAS:
- No crees aún el proyecto Xcode — eso es la siguiente fase y la hace el usuario manualmente.
- No adaptes layouts.

REPORTA: estructura final de Package.swift y cualquier ajuste que tuviste que hacer en CLI/Tests para compatibilizar.
````

---

### Fase 4 — Proyecto Xcode delgado (manual con guía, ~30 min) 🔎 Claude solo guía, no toca

> SwiftPM standalone NO puede generar `.ipa`. Necesitamos un Xcode project que consuma el SwiftPM como local package. Lo hace el usuario porque requiere Xcode GUI y signing con su Apple ID.

**Guía para el usuario (no es prompt Codex):**

1. Abrir Xcode → File → New → Project → iOS → App.
2. Nombre: `AstroMalikIOS`, interface SwiftUI, language Swift, **no** incluir tests (los tenemos en SwiftPM).
3. Guardar en `apps/AstroMalikIOS/` dentro del repo (crear carpeta).
4. En el proyecto Xcode: File → Add Package Dependencies → Add Local → seleccionar la raíz del repo (donde está `Package.swift`).
5. En el target `AstroMalikIOS` → General → Frameworks → añadir `AstroMalik` (library product).
6. Borrar el `ContentView.swift` autogenerado y el `App.swift` autogenerado.
7. Reemplazar con un App.swift que importe AstroMalik y use `RootView()`.
8. Signing & Capabilities → Team = tu Apple ID personal (gratis), Bundle ID = `com.eduardo.astromalik.ios` (o lo que prefieras).
9. Conectar iPhone vía cable, seleccionar como destino, Run.
10. En el iPhone, Ajustes → General → VPN y gestión de dispositivos → confiar en tu perfil.

**Criterio de éxito Fase 4:** la app arranca en iPhone físico y muestra la primera pantalla (aunque sea fea / cropped).

---

### Fase 5 — Adaptar UI para iPhone compact (Codex, ~90 min, dividido en 2 prompts) 🔎 revisa Claude

#### Prompt 5A — Navegación y vistas estructurales

````
Repo AstroMalik, rama port/ios, post Fase 4. La app arranca en iPhone pero las vistas pesadas no se ven bien. Objetivo de esta sub-fase: refactorizar la navegación raíz para que funcione bien en iPhone (compact) y mantenga el sidebar en iPad (regular).

PASO 1 — RootView adaptativa:
Modifica Sources/AstroMalikIOSApp/RootView.swift así:
- Usa `@Environment(\.horizontalSizeClass)` para detectar compact vs regular.
- Compact (iPhone): NavigationStack con una pantalla "Home" que lista las secciones (NatalChart, Transits, Returns, Profections, Firdaria, ZR, PrimaryDirections, Horary, Reports, Settings) como NavigationLinks.
- Regular (iPad): NavigationSplitView reusando AppNavigation existente del módulo AstroMalik si es viable, o replicando la sidebar.

PASO 2 — Vistas que necesitan adaptación compact (NO macOS):
Por cada una de las siguientes, envuelve el contenido pesado para que en compact use scroll vertical + cards en vez de tabla densa. Mantén iPad regular como está.

- Views/TransitsView.swift (~657 líneas)
- Views/EphemerisCalendarView.swift
- Views/EphemerisTableView.swift
- Views/SynastryView.swift
- Views/TransitTimelineView.swift

Para cada una: si el layout actual usa `Table` (SwiftUI Table funciona en iPad pero raro en iPhone), añade un branch `if horizontalSizeClass == .compact { ListVersion() } else { ExistingTable() }`. La ListVersion debe mostrar las mismas filas como `List` con `VStack` por fila.

PASO 3 — NatalWheelView:
Verifica que NatalWheelView (canvas SwiftUI) escala bien en iPhone — debería, ya que es vectorial. Si no, añade `.aspectRatio(1, contentMode: .fit)` y un `GeometryReader` que use min(width, height).

PASO 4 — Settings:
Sources/AstroMalik/Views/SettingsView.swift — el NSOpenPanel para seleccionar carpeta de reportes en iOS debe ser un UIDocumentPickerViewController vía UIViewControllerRepresentable. Crea Sources/AstroMalik/Views/iOSFolderPicker.swift con la representable y úsalo dentro de `#if os(iOS)`.

VALIDACIÓN:
- swift build macOS verde.
- Build iOS desde Xcode (proyecto creado en Fase 4) verde.
- En simulador iPhone 15: navega por las 10 secciones, verifica que ninguna crashea ni queda en blanco.

COMMIT: `feat(ios-port): adaptive navigation and compact-mode list fallbacks for iPhone`.
````

**🔎 Revisión Claude:** ojo a TransitsView por su tamaño (657 líneas) — revisar si el branch compact/regular quedó limpio o si quedó duplicación masiva. ~15 min.

#### Prompt 5B — PDF/share y pequeños detalles iOS

````
Repo AstroMalik, rama port/ios, post 5A. Objetivo: pulir flujos de export y detalles iOS.

PASO 1 — MyReportsView en iOS:
Sources/AstroMalik/Views/MyReportsView.swift — en iOS no hay "revelar en Finder". Reemplaza el botón por:
- ShareLink(item: report.url) para compartir/exportar a Files.
- Botón "Vista previa" que abre QuickLook (QLPreviewController vía UIViewControllerRepresentable, crea archivo helper en Views/iOS/PDFQuickLook.swift).
- Mantén las acciones macOS igual (`#if os(macOS)`).

PASO 2 — PDFExportButton:
Verifica que el branch iOS de Fase 2 (ShareLink) realmente abre el share sheet con el PDF. Si en su lugar muestra solo un alert, corrige para que use `ShareLink(item: url, preview: SharePreview("Reporte", image: Image(systemName: "doc.richtext")))`.

PASO 3 — Estado de almacenamiento:
MigrationRunner.swift usa `applicationSupportDirectory` — en iOS esto es sandboxed por app y funciona. Verifica que `Resources/ephe` y `corpus.db` se copian a Application Support en el primer arranque (mismo flujo que macOS). Si el bundle de iOS no encuentra los recursos, ajusta `Bundle.module` (debe funcionar idéntico ya que es SwiftPM).

PASO 4 — Iconos y splash:
Genera AppIcon iOS (1024x1024 base) en apps/AstroMalikIOS/Assets.xcassets a partir de AstroMalik.icns existente. Si no tienes herramienta para extraer del .icns, crea un placeholder rojizo con texto "AM" y el usuario lo regenerará luego.

VALIDACIÓN:
- En simulador iPhone: genera un reporte PDF Natal, comparte vía AirDrop simulator, abre con QuickLook desde MyReports.
- swift build macOS y iOS verde.

COMMIT: `feat(ios-port): iOS share sheet, QuickLook for reports, app icon placeholder`.
````

---

### Fase 6 — Tests y CI mínima (Codex, ~30 min)

````
Repo AstroMalik, rama port/ios, post 5B. Objetivo: garantizar que los tests no se rompen en iOS y que el CLI sigue funcionando en macOS.

PASO 1 — Tests:
- Tests/AstroMalikTests: deben pasar también con `swift test` apuntando a iOS simulator (al menos los cálculos puros — engine, ephemeris, primary directions). Marca con `#if os(macOS)` cualquier test que dependa de NSWorkspace / FileManager-macOS-only.
- Tests/AstroMalikCLITests: condiciona TODO el archivo a `#if os(macOS)`.

PASO 2 — Script de validación:
Crea scripts/build_ios.sh que ejecute:
- swift build (macOS)
- xcodebuild -scheme AstroMalikIOS -destination 'platform=iOS Simulator,name=iPhone 15' build (si el proyecto Xcode está en apps/AstroMalikIOS/AstroMalikIOS.xcodeproj)

PASO 3 — README:
Actualiza README.md sección "Build" con instrucciones iOS:
- Requisitos: Xcode 15+, iOS 17+.
- Pasos sideload personal.
- Limitaciones: sin integraciones LLM/Joplin/Foundry (referenciar este documento).

COMMIT: `test(ios-port): platform-aware tests + iOS build script + README update`.
````

---

### Fase 7 — QA en dispositivo real y polish (manual + Codex puntual, ~60 min)

Checklist para el usuario sobre iPhone físico:
- [ ] Cálculo carta natal con ubicación arbitraria (verificar geocoding offline — `cities_seed.json`).
- [ ] Transitos a 3 meses vista (medir tiempo).
- [ ] Solar return + Lunar return.
- [ ] Profecciones + ZR + Firdaria.
- [ ] Primary Directions (cálculo, sin interpretación LLM — debe estar oculto).
- [ ] Horary nativo (sin interpretación Foundry).
- [ ] Generar PDF Natal completo, abrir en Files, compartir por correo.
- [ ] Synastry entre 2 cartas guardadas.
- [ ] Eliminar carta, restaurar, verificar persistencia tras kill-app.
- [ ] Cambio dark/light.
- [ ] Rotación landscape iPad.

Cualquier bug detectado → prompt puntual a Codex con stack trace + archivo afectado. **Claude solo entra si el bug es de arquitectura o cross-cutting.**

---

## 4. Riesgos y mitigaciones

| Riesgo | Probabilidad | Mitigación |
|---|---|---|
| Swiss Ephemeris C no compila en iOS por POSIX | Baja | `swe_*.c` es ANSI C portable. Si hay `#include <sys/...>` no soportado, condicionar con `#ifdef __APPLE__` |
| SQLite linking diferente en iOS | Baja | `-lsqlite3` funciona idéntico. Sandbox: `applicationSupportDirectory` es la ruta correcta |
| Vistas con `Table` SwiftUI no renderizan bien iPhone | Media | Branch compact con `List` (cubierto en Fase 5A) |
| AppIcon falta para sideload | Baja | Placeholder en Fase 5B, refinar después |
| Perfil personal de 7 días caduca | Cierto | Aceptado por el usuario. Reinstalar desde Xcode cada semana o usar AltStore para auto-refresh |
| Recursos `ephe/*.se1` (~30 MB) inflan el ipa | Media | Aceptable para uso personal. Si molesta, hacer download bajo demanda en Fase futura |
| Cross-personal sin narrativa pierde valor | Media | Decisión del usuario. El reporte sigue con datos + plantilla doctrinal |
| Codex confunde "cálculo nativo Swift" con "interpretación LLM" en Horary/PD y borra de más | Alta si no se aclara | El prompt de Fase 1 lleva sección CONTEXTO CLAVE explícita. Revisión 🔎 Claude verifica que `HoraryNativeEngine`, motor PD nativo y `PrimaryDirectionLocalReading` quedan intactos y siguen renderizando en sus vistas |

## 5. Estimación

- Fase 1–6 con Codex xhigh: ~4 horas wall-clock si las revisiones de Claude son eficientes.
- Fase 4 (Xcode manual): 30 min usuario.
- Fase 7 (QA real): 1 hora usuario.
- **Total realista: medio día de trabajo concentrado.**

## 6. Después del MVP (fuera de scope inicial)

- Sincronización iCloud de cartas guardadas (CKContainer).
- Widgets iOS (Today's transits).
- Apple Watch app (solo lectura del día).
- Re-introducir narrativa LLM **vía un backend propio mínimo** si algún día se quiere App Store.
