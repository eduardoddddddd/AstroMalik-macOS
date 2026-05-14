# Cross-personal — Sintetizador y redacción

El módulo cross-personal es la corona del proyecto. Combina los resultados de todos los motores predictivos y del análisis natal extendido en un único estado astrológico personal, prioriza los temas por convergencia entre capas y opcionalmente entrega una redacción profesional vía Anthropic.

## Filosofía

Cada técnica astrológica mira a la persona desde un ángulo distinto. La fuerza interpretativa no está en cada una por separado sino en **lo que se repite** entre técnicas: si Saturno aparece como Firdaria mayor, como tránsito al Sol y como dirección primaria al MC durante el mismo año, ese es el tema. El cross-personal automatiza esa lectura cruzada con un algoritmo determinista y sin LLM.

La narrativa Anthropic vive encima: sintetiza el state ya priorizado y produce un informe en español siguiendo doctrina helenística/tradicional. El LLM redacta, no calcula ni inventa señales.

## Arquitectura

Tres piezas, separadas a propósito:

### 1. `CrossPersonalEngine` — puro

`Sources/AstroMalik/Engine/CrossPersonalEngine.swift`

API:

```swift
enum CrossPersonalEngine {
    static func state(
        inputs: CrossPersonalInputs,
        options: CrossPersonalOptions = .default
    ) -> CrossPersonalState
}
```

Sin Swiss Ephemeris, sin disco, sin red. Toma una estructura pre-rellenada (`CrossPersonalInputs`) y produce el state agregado. Esto lo hace **trivialmente testeable** y **reproducible**: mismos inputs, mismos topics.

### 2. `CrossPersonalAssembler` — orquestador

`Sources/AstroMalik/Engine/CrossPersonalAssembler.swift`

API:

```swift
enum CrossPersonalAssembler {
    static func assemble(
        chart: NatalChart,
        referenceDate: Date,
        corpusStore: CorpusStore
    ) async throws -> CrossPersonalInputs

    static func state(
        chart: NatalChart,
        referenceDate: Date,
        corpusStore: CorpusStore,
        options: CrossPersonalOptions = .default
    ) async throws -> CrossPersonalState
}
```

Invoca a los engines reales (`ProfectionEngine`, `SolarReturnEngine`, `PrimaryDirectionsService`, `SolarArcEngine`, `SecondaryProgressionEngine`, `FirdariaEngine`, `ZodiacalReleasingEngine`, `NatalExtendedAnalysis`, `computeTransitPeriod` y el calendario de efemérides para lunaciones/eclipses) y rellena los inputs. Es el punto donde vive la parte costosa.

### 3. `CrossPersonalNarrativeBuilder` — redacción

`Sources/AstroMalik/Services/CrossPersonalNarrativeBuilder.swift`

Toma un `CrossPersonalState`, lo serializa a JSON snake-case ordenado y lo envía a Anthropic con el system prompt en español (`Resources/cross_personal_prompt.md`). Devuelve un `CrossPersonalNarrative` con el Markdown del informe + métricas de uso (tokens, coste).

Cuatro alcances:

- `.complete` — el informe completo (default).
- `.annual` — foco anual; el LLM prioriza profección, RS, firdaria y direcciones.
- `.monthly` — foco mensual; prioriza tránsitos del mes y lunaciones inminentes.
- `.weekly` — foco semanal; sólo lo accionable a 7-10 días vista.

## El state

`CrossPersonalState` tiene cuatro partes:

```text
metadata        — fecha, chart id, fecha de generación, versión del engine
natalSignature  — firma natal condensada (Sol, Luna, ASC, MC, secta,
                  regente del ASC, almuten, regente de la geniture,
                  lotes prominentes, configuraciones, distribución,
                  estrellas fijas)
layers          — cuatro capas temporales con sus signals
topics          — cola de prioridad por convergencia
```

Cada **layer** contiene **signals**:

```text
annual          — profección anual, LotY, ZR L1/L2 de Espíritu y Fortuna,
                  Firdaria mayor y menor, regente ASC RS, repeticiones
                  natales RS, planetas angulares RS
mediumTerm      — direcciones primarias activas ±12 meses, arco solar
                  ±12 meses, aspectos progresados del año, Luna progresada
                  por casa, fase lunar progresada, ingresos lunares
                  progresados próximos
shortTerm       — tránsitos lentos (Saturno+) sobre puntos sensibles
                  con banda de prioridad
lunar           — lunaciones próximas sobre puntos natales sensibles,
                  próximos eclipses con eco a Saros, retornos planetarios
```

Cada `CrossSignal` apunta a un **subject primario** (`planet`, `house`, `sign`, `lot` o `axis`) y opcionalmente a subjects secundarios. El subject es la unidad de agrupación para la cola de prioridad.

## Algoritmo de convergencia

Determinista. Sin LLM. Reproducible.

1. Agrupar todos los signals por subject primario.
2. Score base por subject: `Σ(signal.weight × layerWeight[signal.layer])`.
   - `annual` = 1.0
   - `mediumTerm` = 0.8
   - `shortTerm` = 0.6
   - `lunar` = 0.5 (eclipses ×2 vía `eclipseLunarMultiplier`)
3. Multiplicador por convergencia entre capas distintas:
   - 1 capa → ×1.0
   - 2 capas → ×1.5
   - 3 capas → ×2.0
   - 4+ capas → ×2.5
4. Bonus de coronación si el subject es:
   - Lord of the Year (profección) → +0.3
   - luminaria de secta → +0.2
   - regente de la geniture → +0.2
   - mismo signo que el peak L2 vigente de Espíritu o Fortuna → +0.3
5. Ordenar topics descendente por score y devolver los `topTopicsLimit` primeros (default 12).

El resultado es una lista priorizada donde Saturno aparece arriba si converge en Firdaria mayor + tránsito al Sol + dirección al MC, y la casa 7 aparece arriba si converge en profección anual + ZR L1 en Libra + Marte progresado al regente de 7.

## Bonificaciones y pesos — racional astrológico

- **LotY** pesa más porque la doctrina helenística dice que sus tránsitos cuentan doble durante el año profeccionado.
- **Luminaria de secta** es el indicador de salud del nativo según la tradición: actividad sobre ella siempre es noticia.
- **Regente de la geniture** es el planeta que rige la luminaria de secta; su movimiento afecta el hilo conductor de la carta.
- **Peak ZR** marca capítulos vitales angulares. Cualquier técnica que apunte al signo del peak refuerza la importancia.

Los pesos por capa siguen la lógica clásica: lo anual ordena, lo medio plazo describe el movimiento, lo corto plazo da el tono inmediato, lo lunar es el activador puntual. Eclipses pesan el doble porque su impacto excede el momento del evento.

## Narrativa

El prompt template (`Resources/cross_personal_prompt.md`) fuerza al LLM a:

- Apoyarse en `topics` (cola de prioridad) y no inventar señales fuera del JSON.
- Aplicar doctrina helenística/tradicional informada: secta, dignidades, dispositorías, no caer en "Saturno = malo".
- Tono profesional, español de España, 2.500-4.000 palabras.
- Estructura fija en 7 secciones: Síntesis ejecutiva, Tu firma natal, El año en curso, Medio plazo, Corto plazo, Capa lunar, Temas convergentes, Cierre.

El builder usa **prompt caching** ephemeral del sistema (`anthropic-version: 2023-06-01`, `cache_control: ephemeral`), reduciendo el coste de input ~70% en llamadas repetidas.

Pricing actual (USD/M tokens):

| Modelo | Input | Cache read | Cache write | Output |
|---|---:|---:|---:|---:|
| Sonnet 4.6 | 3.00 | 0.30 | 3.75 | 15.00 |
| Opus 4.7 | 15.00 | 1.50 | 18.75 | 75.00 |
| Haiku 4.5 | 1.00 | 0.10 | 1.25 | 5.00 |

Un informe completo Sonnet ronda **$0.05-0.10**. Un informe Opus ronda **$0.30-0.50**. Un informe semanal Sonnet baja a **~$0.02**.

## Tests

`Tests/AstroMalikTests/CrossPersonalEngineTests.swift` cubre:

- carta de referencia 1976-10-11 20:33 Madrid produce signals en las cuatro capas.
- profección anual aparece como signal `source = "profection"` y el LotY como `source = "profection_loty"`.
- al menos un topic tiene `layerCount >= 2`.
- convergencia: signals en más capas suben el score, multiplicadores aplicados.
- bonificación LotY hace que un topic suba sobre otro con misma carga base.
- topics ordenados por score descendente.
- state es JSONEncoder/Decoder simétrico.

`Tests/AstroMalikTests/CrossPersonalNarrativeBuilderTests.swift` cubre:

- template loader inyectado funciona.
- payload del user contiene el JSON con snake_case.
- markdown del response y estimación de coste vienen rellenos.
- `joplinMarkdown()` incluye el apéndice de trazabilidad con modelo y coste.

`Tests/AstroMalikTests/Reports/CrossPersonalReportTests.swift` cubre la pieza PDF (ver `PDF_REPORTS.md`).

## Costes operativos típicos

Asumiendo Sonnet con caching y un volumen razonable:

- Informe semanal automatizado vía LaunchAgent (sábado 18:00): 52/año × $0.02 = **~$1/año**.
- Informe mensual (día 1, 09:00): 12/año × $0.05 = **~$0.6/año**.
- Informe anual completo en cumpleaños: 1/año × $0.10 = **$0.10**.
- Informes puntuales (4-5 al año): 5 × $0.08 = **$0.40**.

Total típico: **menos de $2 al año**. Con Opus para el informe anual: $3-4/año.

## Roadmap del cross-personal

- **1.0**: cuatro capas (annual, mediumTerm, shortTerm, lunar), cola de prioridad por convergencia, narrativa Anthropic en español.
- **1.1+ posible**: capa adicional "ciclo de vida" con tránsitos epocales (Saturno return, Urano oposición, Quirón return), corpus de plantillas de informe para sub-presets más específicos (carrera, salud, relaciones), modo bilingüe (es/en).
