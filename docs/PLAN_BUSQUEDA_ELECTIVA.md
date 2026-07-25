# Plan de implementación — Búsqueda Electiva

> **Estado global:** 🔵 No iniciado
> **Creado:** 2026-07-25 · **Versión objetivo:** 1.2.0
> **Documento vivo:** este archivo es a la vez plan y panel de gestión. Cada sesión se registra aquí al cerrarla.

---

## 1. Objetivo

Añadir a AstroMalik un módulo de **astrología electiva**: dado un rango de fechas, un lugar, un tipo de asunto y opcionalmente una carta natal, escanear el tiempo y devolver **ventanas rankeadas** donde se cumplen los criterios clásicos, con score, advertencias y trazabilidad de reglas — al nivel del Electional Search de Solar Fire, más el cruce con carta natal y time lords que Solar Fire no tiene.

### Alcance v1 (dentro)

- Motor determinista local (`ElectionalEngine`) con embudo de tres resoluciones (día → hora → minuto).
- Reglas clásicas: estado de la Luna (VoC, vía combusta, combustión, dignidad, próximo aspecto aplicativo), regente del asunto, Ascendente y su regente, fase lunar, Mercurio directo, hora planetaria, maléficos en ángulos.
- Cruce opcional con carta natal (tránsitos del momento sobre ángulos y luminarias natales).
- Presets por asunto (matrimonio, negocio/contrato, viaje, mudanza, cirugía, litigio) con pesos editables, patrón `RectificationSchool`.
- UI en sidebar (sección Sinastría y Horaria → renombrar a "Horaria y Electiva" o sección propia), lista de ventanas, apertura de la carta del momento con la vista natal existente.
- Informe PDF, nota Joplin, subcomando CLI `electional`.

### Fuera de v1

- Cruce con firdaria/ZR vigentes (v1.1 del módulo; dejar hooks).
- Electiva relocalizada (depende del módulo de relocación).
- Narrativa LLM (misma filosofía que rectificación: capa posterior opcional).

---

## 2. Arquitectura propuesta

```
Sources/AstroMalik/Electional/
  Models/ElectionalModels.swift        Request, RuleResult, Window, Score, Preset (Codable versionados)
  Engine/ElectionalEngine.swift        Puro, sin efectos: embudo + evaluación de reglas + ventanas
  Engine/ElectionalRules.swift         Catálogo de reglas como tipos (id, capa, peso, evaluador)
  Engine/ElectionalScanner.swift       Orquestador con efectos: efemérides, caché, cancelación, progreso
  Presets/ElectionalPresets.swift      Presets doctrinales por asunto
  Views/ElectionalView.swift           Formulario + resultados
  Views/ElectionalWindowDetailView.swift
  ElectionalNoteBuilder.swift          Markdown Joplin
Reports/Builders/ElectionalReportBuilder.swift + plantilla en Resources/Reports/templates/
```

Decisiones de diseño ya tomadas:

1. **Refactor previo obligatorio:** `planetaryHourRuler`, `moonVoidOfCourse`, vía combusta, combustión y dignidades viven como `private static` en `HoraryNativeEngine.swift`. Se extraen a un tipo compartido `ClassicalConditions` (en `Engine/`) consumido por horaria y electiva, con tests de paridad para garantizar que la horaria no cambia ni un bit.
2. **Embudo de resoluciones:** paso día (fase lunar, signo de Luna, Mercurio R, regente del día) → paso ~1 h (aspectos aplicativos de la Luna con regla de signo, VoC, hora planetaria, combustión) → paso 2–4 min solo en ventanas supervivientes (ASC, casas, ángulos) con bisección en los bordes. Reutiliza la caché de efemérides introducida en 1.1.3.
3. **Scoring:** `Σ(peso × resultado)` por regla con bandas low/medium/high/critical reutilizando el patrón de `priorityBand` de `TransitEngine`. Toda ventana lista sus reglas cumplidas, violadas y neutrales — explicabilidad igual que rectificación.
4. **Separación motor/orquestador/vista** idéntica a `CrossPersonalEngine` / `CrossPersonalAssembler` / `CrossPersonalView`.

---

## 3. Modelo de trabajo

### Roles

| Rol | Quién | Responsabilidad |
|---|---|---|
| **Arquitectura y diseño** | Claude (Fable, en Claude Code) | Specs cerradas, contratos de tipos, esqueletos de tests, revisión de código entrante, decisiones de integración |
| **Programación pura** | ChatGPT (GPT-5.1 Thinking o el último equivalente) | Implementación de módulos completos contra spec cerrada, sin acceso al repo: recibe spec + interfaces, devuelve Swift |
| **Integración y verificación** | Claude Code (Sonnet basta para lo mecánico; Fable si la integración se complica) | Pegar el código en el repo, compilar, correr tests, arreglar fricción de compilación |
| **Validación doctrinal y QA** | Eduardo | Aprobar specs doctrinales, validar resultados contra criterio propio, probar la UI |

### Flujo por sesión

```
SPEC (Fable) ──► CÓDIGO (ChatGPT) ──► INTEGRACIÓN (Claude Code) ──► VALIDACIÓN (Eduardo)
```

### Reglas del flujo

1. **ChatGPT nunca improvisa doctrina ni interfaces.** Recibe: (a) la spec de la sesión, (b) los tipos/protocolos exactos ya commiteados, (c) los tests que su código debe pasar. Devuelve solo cuerpos de implementación.
2. **Una sesión = un paquete cerrado.** No se arrastra contexto entre sesiones: cada una arranca desde este documento y el estado del repo.
3. **Spec antes que repo.** Ninguna sesión de código se abre sin su spec marcada como ✅ aquí.
4. **Todo cierre de sesión actualiza este documento**: checklist, tabla de registro, y decisiones nuevas en §7.
5. **Commit por sesión**, mensaje `feat(electional): <paquete> [S<n>]`, suite completa en verde antes de commitear.

### Formato de handoff a ChatGPT (plantilla)

```
CONTEXTO: AstroMalik-macOS, Swift 6, sin dependencias externas. Módulo electiva.
SPEC: <pegar sección de spec de la sesión>
INTERFACES YA COMMITEADAS (no modificar): <pegar tipos>
TESTS QUE DEBE PASAR: <pegar esqueletos XCTest>
ENTREGA: solo los archivos .swift completos indicados. Sin explicaciones largas.
PROHIBIDO: cambiar firmas, añadir dependencias, inventar reglas doctrinales no listadas.
```

---

## 4. Sesiones

Estimaciones: **salida** = tokens generados; **procesado** = total entrada+salida (85–95 % cache-read en Claude Code); **tiempo** = reloj de pared incluyendo revisión humana.

### S0 — Spec doctrinal ✍️

- **Modelo:** Fable (chat, sin repo) + validación de Eduardo
- **Entregables:** `docs/ELECTIVA_SPEC_DOCTRINAL.md` — catálogo numerado de reglas (fuente clásica, capa del embudo, peso por defecto, condición evaluable), definición de los 6 presets, casos de prueba doctrinales (fechas concretas con resultado esperado)
- **Cierre:** Eduardo aprueba el catálogo de reglas y los casos golden
- **Tokens:** salida 20–35K · procesado 0,3–0,8M · **Tiempo:** 1,5–2 h

### S1 — Contratos, refactor `ClassicalConditions` y esqueleto de tests 🏗️

- **Modelo:** Fable en Claude Code
- **Entregables:** extracción de utilidades de `HoraryNativeEngine` a `ClassicalConditions` + tests de paridad horaria; `ElectionalModels.swift` completo; `ElectionalRules.swift` con el catálogo tipado (evaluadores como stubs `fatalError`); esqueletos XCTest con los casos golden de S0
- **Cierre:** compila, tests de paridad horaria en verde, suite previa intacta (390/390)
- **Tokens:** salida 80–120K · procesado 3–5M · **Tiempo:** 2–3 h

### S2 — Motor: pasos día y hora 🤖

- **Modelo:** ChatGPT (código) → Claude Code Sonnet (integración)
- **Entregables:** evaluadores de reglas de capa día y capa hora en `ElectionalEngine`; lógica de descarte del embudo
- **Cierre:** tests golden de capas día/hora en verde
- **Tokens:** ChatGPT salida 60–100K · integración: salida 30–60K, procesado 2–4M · **Tiempo:** 2–3 h

### S3 — Motor: paso fino, bisección, scoring y ventanas 🤖

- **Modelo:** ChatGPT (código) → Claude Code Sonnet (integración); Fable si la bisección da guerra
- **Entregables:** evaluadores de capa minuto (ASC/casas/ángulos), bisección de bordes, agregación de score, consolidación de ventanas contiguas, cruce opcional con carta natal
- **Cierre:** suite electiva completa en verde; escaneo de 3 meses < 5 s en un M1
- **Tokens:** ChatGPT salida 80–130K · integración: salida 40–80K, procesado 3–6M · **Tiempo:** 3–4 h

### S4 — Scanner con efectos: caché, progreso, cancelación 🏗️

- **Modelo:** Fable en Claude Code (es integración fina con la caché de 1.1.3 y el patrón de cancelación de rectificación)
- **Entregables:** `ElectionalScanner` + presets de S0 como `ElectionalPresets.swift` con pesos editables
- **Cierre:** cancelación cooperativa verificada; presets cargan y modifican pesos
- **Tokens:** salida 60–90K · procesado 2,5–4M · **Tiempo:** 2 h

### S5 — UI: formulario y resultados 🎨

- **Modelo:** Fable diseña spec de UI (wireframe textual + estados) → ChatGPT genera vistas → Claude Code integra e itera visualmente
- **Entregables:** `ElectionalView` (rango, lugar vía `PlacesService`, asunto, carta natal opcional, preset), lista de ventanas con score/banda/advertencias, detalle con reglas explicadas, botón "abrir carta del momento"
- **Cierre:** flujo completo usable; Eduardo valida con un caso real
- **Tokens:** ChatGPT salida 70–110K · integración: salida 60–110K, procesado 4–7M · **Tiempo:** 3–4 h ⚠️ *la iteración visual es donde el rango se abre*

### S6 — Salidas: PDF, Joplin, CLI 🤖

- **Modelo:** ChatGPT (builders siguen patrones existentes, es lo más mecánico) → Claude Code Sonnet
- **Entregables:** `ElectionalReportBuilder` + plantilla, `ElectionalNoteBuilder`, subcomando CLI `electional` con defaults local-first
- **Cierre:** PDF generado y legible; nota Joplin correcta; `astromalik-cli electional --help` documentado
- **Tokens:** ChatGPT salida 50–80K · integración: salida 40–70K, procesado 2–4M · **Tiempo:** 2 h

### S7 — QA final, docs y release 🏗️

- **Modelo:** Fable en Claude Code
- **Entregables:** suite completa en verde, `ARCHITECTURE.md` + `README.md` + `CHANGELOG.md` actualizados, `docs/ELECTIVA_GUIA_DE_USO.md` para usuarios, tag `v1.2.0`
- **Cierre:** release publicada con artefactos universales desde CI
- **Tokens:** salida 40–70K · procesado 2–4M · **Tiempo:** 1,5–2 h

### Totales

| Concepto | Estimación |
|---|---|
| Salida ChatGPT (código puro) | 260–420K tokens |
| Salida Claude (arquitectura + integración + docs) | 370–645K tokens |
| Procesado total Claude Code | 19–35M tokens (~90 % cache-read) |
| Tiempo de pared | 17–22 h repartidas en 8 sesiones |
| Código nuevo estimado | ~5.500–7.000 líneas con tests |

---

## 5. Panel de gestión

### Checklist maestro

- [ ] **S0** — Spec doctrinal aprobada por Eduardo
- [ ] **S1** — Contratos + `ClassicalConditions` + paridad horaria en verde
- [ ] **S2** — Capas día y hora del motor en verde
- [ ] **S3** — Paso fino + scoring + ventanas en verde · rendimiento OK
- [ ] **S4** — Scanner + presets + cancelación
- [ ] **S5** — UI validada por Eduardo con caso real
- [ ] **S6** — PDF + Joplin + CLI
- [ ] **S7** — QA, docs, tag `v1.2.0`

### Registro de sesiones

*Rellenar una fila al cerrar cada sesión. Tokens reales si el cliente los reporta; si no, aproximar.*

| Sesión | Fecha | Modelo(s) usados | Commit | Tokens reales (salida) | Tiempo real | Desviaciones / notas |
|---|---|---|---|---|---|---|
| S0 | — | — | — | — | — | — |
| S1 | — | — | — | — | — | — |
| S2 | — | — | — | — | — | — |
| S3 | — | — | — | — | — | — |
| S4 | — | — | — | — | — | — |
| S5 | — | — | — | — | — | — |
| S6 | — | — | — | — | — | — |
| S7 | — | — | — | — | — | — |

### Cómo arrancar cada sesión

1. Abrir Claude Code en el repo y pegar: *"Sesión S\<n\> del plan `docs/PLAN_BUSQUEDA_ELECTIVA.md`. Lee el plan, verifica el estado del checklist y ejecuta la sesión."*
2. Para las sesiones 🤖: Claude prepara el handoff (§3) → pegarlo en ChatGPT → traer el código de vuelta a Claude Code para integrar.
3. Al cerrar: actualizar checklist y registro, commitear, y anotar cualquier decisión nueva en §7.

---

## 6. Riesgos

| Riesgo | Impacto | Mitigación |
|---|---|---|
| ChatGPT altera firmas o inventa reglas | Retrabajos de integración | Plantilla de handoff estricta; los tests golden de S0/S1 son el contrato |
| Deriva doctrinal (reglas discutibles) | Resultados poco fiables | S0 se cierra con fuentes citadas y aprobación explícita de Eduardo; nada se codifica sin regla numerada |
| Rendimiento del paso fino | Escaneos lentos | Presupuesto fijado en S3 (< 5 s / 3 meses); el embudo descarta antes de llegar al paso caro |
| Refactor `ClassicalConditions` rompe horaria | Regresión doctrinal grave | Tests de paridad en S1 antes de tocar nada más; `HoraryParityTests` existentes como red |
| Sesión S5 (UI) se come el presupuesto | Sobrecoste de tokens | Wireframe textual cerrado antes de codificar; máximo 2 rondas de iteración visual antes de replantear |

## 7. Registro de decisiones

*Añadir aquí toda decisión tomada durante la ejecución, con fecha.*

- **2026-07-25** — Plan creado. Reparto de roles: Fable arquitectura/diseño/revisión, ChatGPT programación pura contra spec cerrada, integración en Claude Code, validación doctrinal de Eduardo.
- **2026-07-25** — v1 sin narrativa LLM ni cruce con time lords (hooks preparados); relocación queda para su propio plan.
