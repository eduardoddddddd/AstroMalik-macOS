# Auditoría 1.0 — AstroMalik

**Rama:** `main` | **17 commits nuevos** | **164 archivos Swift**  
**Revisor:** agente automatizado | **Fecha:** 2026-05-14

---

## Bloqueantes 1.0

*No se encontraron bugs bloqueantes.*

---

## No bloqueantes

### NB-1 — `try?` silencia errores de renderizado PDF (ReportRenderer)
- `Sources/AstroMalik/Reports/Service/ReportRenderer.swift:130` → `try? await waitForDocumentReadiness(in: webView)`
- `Sources/AstroMalik/Reports/Service/ReportRenderer.swift:172` → `_ = try? await evaluateJavaScript(...)`
- La espera de `document.fonts.ready` y layout CSS se descarta silenciosamente si falla. Un PDF puede generarse con fuentes de fallback o layout incompleto sin aviso al usuario.
- **Fix sugerido:** Loguear el error con `print("[ReportRenderer] Font readiness falló: \(error)")` en vez de descartar; o emitir una advertencia de calidad en el resultado.

### NB-2 — Force-unwrap de constante de compilación (AnthropicClient)
- `Sources/AstroMalik/Services/AnthropicClient.swift:233` → `URL(string: "https://api.anthropic.com/v1")!`
- URL literal de compilación. No es un crash realista pero técnicamente es un force-unwrap.
- **Fix sugerido:** `guard let url = URL(...) else { fatalError("URL inválida") }` o extraer a constante de configuración con test en `init`.

### NB-3 — Creación repetida de `AnthropicClient()` en SettingsView
- `Sources/AstroMalik/Views/SettingsView.swift:126,145,265,315,324` → Cada evaluación de SwiftUI crea una instancia nueva de actor para leer Keychain.
- Ineficiencia sin riesgo de crash. Keychain se consulta 5+ veces por render.
- **Fix sugerido:** Almacenar una única instancia en `@State` o en el `AppState`.

### NB-4 — Ensamblador cross-personal degrada silenciosamente errores de motores
- `Sources/AstroMalik/Engine/CrossPersonalAssembler.swift:14,17,101` → `try?` con fallback defensivo. Si ProfectionEngine, NatalExtended o SolarReturnEngine fallan, el estado cross-personal se construye con datos degradados sin aviso.
- Diseño intencional para resiliencia. El usuario nunca sabe que faltan piezas del análisis.
- **Fix sugerido:** Añadir un campo `degradedEngines: [String]` al `CrossMetadata` que informe qué técnicas se usaron en fallback.

### NB-5 — `AnthropicError.httpError` incluye cuerpo completo de respuesta HTTP
- `Sources/AstroMalik/Services/AnthropicClient.swift:38-39` → `"Anthropic HTTP \(code): \(body)"`
- Si Anthropic devolviera información sensible en un cuerpo de error (improbable pero posible), se incluiría en el `errorDescription` visible en UI.
- **Fix sugerido:** Truncar a 200 caracteres o sanitizar antes de incluir en mensaje de error.

---

## Seguridad

| Verificación | Resultado |
|---|---|
| API key en logs (`print`/`NSLog`/`os_log`) | **Limpio** — ningún log incluye API keys |
| API key en archivos rastreados por git | **Limpio** — solo test keys falsas (`sk-ant-test-key-*`, `sk-or-v1-0123...`) |
| `.env` / `.secret` / `*.key` en repo | **Limpio** — `.gitignore` bloquea todos los patrones relevantes |
| `SecureField` para entrada de API key | **Correcto** — `SettingsView` usa `SecureField` |
| Keychain como almacenamiento primario | **Correcto** — `kSecAttrAccessibleWhenUnlockedThisDeviceOnly` |
| Keys enmascaradas en UI | **Correcto** — `maskedKeyTail()` muestra últimos 4 caracteres |
| OpenRouter: key escaneada desde Joplin SQLite | **Correcto** — solo lectura, patrón regex en código, sin persistencia de keys en repo |

---

## Doctrina astrológica

| Motor | Verificación | Detalle |
|---|---|---|
| **ProfectionEngine** | ✅ Correcto | Whole-sign desde ASC. `house = (age % 12) + 1`, `signIndex = (ascSign + age%12) % 12`. `ProfectionEngine.swift:274-279` |
| **ZodiacalReleasingEngine** | ✅ Correcto | LB en Cáncer (índice 3) o Capricornio (índice 9) → salto al opuesto del L1. `signIndex = opposite(of: l1SignIndex)`. `ZodiacalReleasingEngine.swift:222` |
| **FirdariaEngine** | ✅ Correcto | Ciclo de 75 años. `cycleYears = 75`, reset en `years / 75`. Orden diurno/nocturno según sect. `FirdariaEngine.swift:15,145-149` |
| **HellenisticLots** | ✅ Correcto | Inversión día/noche. Fortune: `ASC + Moon - Sun` (día) / `ASC + Sun - Moon` (noche). Spirit espejo. `HellenisticLots.swift:40-70` |
| **CrossPersonalEngine** | ✅ Correcto | Scoring por convergencia: `base = Σ(weight × layerWeight)`, multiplicador por capas distintas, bonus aditivos. `CrossPersonalEngine.swift:597-620` |
| **SectEngine** | ✅ Correcto | Sol en casas 7-12 → diurno. Asignaciones de beneficio/maleficio según sect. `SectEngine.swift:4-27` |

---

## Memoria y concurrencia

| Componente | Verificación |
|---|---|
| `WKWebView` + delegate (ReportRenderer) | ✅ Sin retain cycle. `navigationDelegate` es weak (WebKit), se nilla explícitamente en línea 127, timer usa `[weak self]`. |
| `AnthropicClient` (actor) | ✅ Funciones `nonisolated` solo acceden Keychain (thread-safe) y `ProcessInfo` (thread-safe). `send()` está aislado al actor. |
| `ReportService` (actor) | ✅ Envuelve `ReportRenderer` (actor) correctamente con `await`. |
| `CrossPersonalEngine` (enum) | ✅ Sin estado mutable, solo funciones estáticas puras. |
| `CrossPersonalAssembler` (enum) | ✅ Sin estado mutable. `try?` defensivo sin data races. |

---

## Veredicto

**APTO para tag 1.0** — sin bloqueantes.

Los 5 hallazgos no bloqueantes (NB-1 a NB-5) son mejoras cosméticas o de diagnóstico. Ninguno causa crash, corrupción de datos, fuga de memoria ni violación de seguridad. La doctrina astrológica es correcta en los 6 motores auditados.
