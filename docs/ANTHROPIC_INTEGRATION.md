# Integración Anthropic

Desde 1.0 AstroMalik integra la API de Anthropic Messages para redactar el informe cross-personal en lenguaje natural. La integración es opcional pero recomendable: el motor cross-personal funciona sin LLM y produce datos estructurados; el cliente Anthropic los convierte en un informe legible.

## Filosofía

El LLM **redacta**, no calcula. Toda la astrología seria sucede en el motor Swift determinista. El cliente Anthropic recibe el state ya sintetizado y produce un Markdown estructurado, sin inventar técnicas ni señales que no aparezcan en el JSON. Esto:

- mantiene la app **localmente correcta** astronómicamente,
- minimiza el coste (el LLM no recalcula nada),
- hace el resultado **auditable** (cada afirmación del LLM debe corresponderse con datos del state),
- permite cachear agresivamente la parte fija del prompt.

## Cliente

`Sources/AstroMalik/Services/AnthropicClient.swift`

`actor AnthropicClient` que envuelve `URLSession` contra `https://api.anthropic.com/v1/messages`. API:

```swift
func send(systemPrompt: String, userPayload: String) async throws -> AnthropicMessageResponse
```

El cliente serializa el request a JSON con:

- `model` (default `claude-sonnet-4-6`, opcional `claude-opus-4-7`).
- `max_tokens` (default 4096, en config `.opusLong` sube a 8000).
- `system` como array con un solo bloque que tiene `cache_control: { type: "ephemeral" }`. Esto activa el **prompt caching** efímero: la primera llamada paga el `cache_write` (×1.25 sobre input) pero las llamadas siguientes en los próximos 5 minutos pagan solo `cache_read` (×0.10 sobre input). El system prompt es ~5-6K tokens, así que la economía cae mucho.
- `messages` con un solo turno user.

Headers:

```text
content-type: application/json
x-api-key: <api key>
anthropic-version: 2023-06-01
user-agent: AstroMalik/1.0 (macOS)
```

Mapeo de errores:

- 401 → `AnthropicError.unauthorized`
- 429 → `AnthropicError.rateLimited`
- 529 → `AnthropicError.overloaded`
- Otros → `AnthropicError.httpError(code, body)`

## Resolución de la API key

Sin hardcoded. Sin disco dentro del repo. Sin logs.

Orden de resolución:

1. **Keychain** del sistema, servicio `com.astromalik.anthropic`, cuenta `api_key`.
2. **Variable de entorno** `ANTHROPIC_API_KEY`.

Si ambos están vacíos, el cliente lanza `AnthropicError.missingAPIKey`.

API expuesta por el cliente:

```swift
func resolveAPIKey() throws -> String
func credentialSource() -> AnthropicCredentialSource?    // .keychain | .environment | nil
func hasAPIKey() -> Bool
func maskedKeyTail() -> String?                          // últimos 4 caracteres
func saveAPIKey(_ key: String) throws                    // escribe Keychain
func deleteAPIKey()                                       // borra Keychain
```

`SettingsView` expone estado, máscara y campo SecureField para guardar manualmente la key. Si la key viene de Joplin (nota dedicada con el contenido), el botón "Importar desde Joplin" lee la nota vía `JoplinClipperService.fetchNoteBody(id:)`, extrae la primera línea que empieza por `sk-ant-` y la guarda en Keychain.

## Pricing y métricas

`AnthropicPricing` y `AnthropicUsage.estimatedCostUSD(model:)`:

| Modelo | Input | Cache read | Cache write | Output |
|---|---:|---:|---:|---:|
| Sonnet 4.6 (`claude-sonnet-4-6`) | $3.00 | $0.30 | $3.75 | $15.00 |
| Opus 4.7 (`claude-opus-4-7`) | $15.00 | $1.50 | $18.75 | $75.00 |
| Haiku 4.5 (`claude-haiku-4-5-20251001`) | $1.00 | $0.10 | $1.25 | $5.00 |

Precio por millón de tokens.

Cada `AnthropicMessageResponse.usage` contiene `inputTokens`, `outputTokens`, `cacheCreationInputTokens` y `cacheReadInputTokens`. La función `estimatedCostUSD(model:)` aplica la tabla y devuelve el coste real de la llamada.

`CrossPersonalNarrative.joplinMarkdown()` incluye un apéndice de trazabilidad con el coste, modelo y conteo de tokens. Ningún log expone la API key.

## El prompt template

`Sources/AstroMalik/Resources/cross_personal_prompt.md`

Es el contrato con el LLM. ~250 líneas. Reglas clave:

- Rol: astrólogo profesional con formación helenística/clásica.
- Idioma: español de España.
- Input: JSON estructurado con `metadata`, `natalSignature`, `layers`, `topics`.
- Output: Markdown con estructura fija en 7 secciones (Síntesis ejecutiva, Tu firma natal, El año en curso, Medio plazo, Corto plazo, Capa lunar, Temas convergentes, Cierre).
- Longitud: 2.500-4.000 palabras (más corto si los datos son escasos).
- Prohibido: predicciones con fecha exacta, lenguaje místico recargado, inventar técnicas no presentes en el JSON, hablar de planetas con voluntad.
- Obligado: priorizar `topics` por convergencia, aplicar doctrina (secta, dignidades, LotY).

## El builder

`Sources/AstroMalik/Services/CrossPersonalNarrativeBuilder.swift`

API:

```swift
func build(state: CrossPersonalState) async throws -> CrossPersonalNarrative
func build(state: CrossPersonalState, scope: CrossPersonalNarrativeScope) async throws -> CrossPersonalNarrative
```

Flujo:

1. Carga el system prompt del bundle (`cross_personal_prompt.md`).
2. Serializa el state a JSON snake-case ordenado.
3. Compone el user payload con cabecera de carta, fecha de referencia y alcance solicitado + JSON.
4. Llama al cliente.
5. Devuelve `CrossPersonalNarrative` con el Markdown, modelo, tokens, coste estimado, fecha de generación.

`CrossPersonalNarrative.joplinMarkdown()` añade el apéndice de trazabilidad. `suggestedJoplinTitle()` produce un título canónico.

## Modos de alcance

`CrossPersonalNarrativeScope` modula la redacción sin cambiar el state subyacente:

- `.complete` — informe completo (default).
- `.annual` — foco en profección, RS, firdaria, direcciones.
- `.monthly` — foco en tránsitos del mes y lunaciones próximas.
- `.weekly` — foco en accionable a 7-10 días vista.

El payload del user incluye una línea `Instrucción de alcance: …` que el LLM debe respetar. Los pesos de las capas no cambian; cambia qué privilegia la prosa final.

## Tests

`Tests/AstroMalikTests/AnthropicClientTests.swift`:

- pricing matches public schedule (Sonnet, Opus).
- cache read reduce coste real.
- request incluye `cache_control: ephemeral` en el bloque system.
- headers `anthropic-version`, `x-api-key`, `Content-Type` correctos.
- mapeo HTTP 401 → `.unauthorized`, 429 → `.rateLimited`.
- missing API key lanza `.missingAPIKey`.
- response con varios bloques text se combina con `\n\n`.

`Tests/AstroMalikTests/CrossPersonalNarrativeBuilderTests.swift`:

- loader inyectado funciona.
- payload contiene "Estado astrológico cross-personal" y JSON snake_case.
- markdown y coste > 0 en la respuesta.
- `joplinMarkdown()` incluye trazabilidad con modelo y coste.

Mock HTTP compartido en `Tests/AstroMalikTests/Support/MockAnthropicHTTPClient.swift`.

## Relación con Foundry Local y OpenRouter

AstroMalik mantiene tres caminos LLM en 1.0:

- **Anthropic** (Messages API directa) — camino principal para el informe cross-personal. Calidad alta, prompt caching, coste predecible.
- **Foundry Local** — interpretaciones contextuales locales para Direcciones Primarias y Horaria. Sin internet, sin coste, modelo `qwen2.5-7b` por defecto.
- **OpenRouter** — alternativa cloud opcional para interpretaciones de direcciones. Útil si no se quiere abrir cuenta directa con Anthropic.

Las credenciales viven en Keychain separado por servicio:

```text
com.astromalik.anthropic
com.astromalik.openrouter
(Foundry Local no necesita credenciales)
```

Foundry sigue documentado en [`FOUNDRY_LOCAL_INTEGRATION.md`](FOUNDRY_LOCAL_INTEGRATION.md). El cliente OpenRouter vive en `Sources/AstroMalik/PrimaryDirections/Interpretation/OpenRouterClient.swift`.

## Costes operativos típicos

Con Sonnet 4.6 y prompt caching efímero activo:

- Informe semanal (tarea programada del CLI): ~$0.02 × 52/año = **~$1/año**.
- Informe mensual: ~$0.05 × 12/año = **~$0.6/año**.
- Informe anual completo: ~$0.10 × 1/año = **$0.10**.
- Informes puntuales: ~$0.08 × 5/año = **$0.40**.

Total: **menos de $2 al año** para una práctica personal regular. Con Opus para el informe anual: $3-4/año.
