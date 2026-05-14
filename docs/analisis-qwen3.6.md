# Análisis Qwen 3.6 Plus — AstroMalik macOS

> Informe elaborado el 5 de mayo de 2026
> Revisión completa de código fuente, documentación y arquitectura

---

## 1. Resumen Ejecutivo

AstroMalik-macOS es una aplicación nativa macOS (Swift 5.9, SwiftUI) de astrología profesional con motor de cálculo propio basado en Swiss Ephemeris (C library compilada inline). Cero dependencias Swift externas. Cubre carta natal, tránsitos, revoluciones solares y lunares, sinastría, direcciones primarias (Regiomontanus), efemérides mensuales con eventos celestes y astrología horaria clásica nativa.

**Valoración global: 8.5/10** — Código sólido, doctrinalmente riguroso, con arquitectura limpia. Las áreas de mejora son principalmente funcionales (cobertura astrológica) y de UX (export, visualización).

---

## 2. Fortalezas del Proyecto

### 2.1 Arquitectura

- **Zero-dependency Swift**: Compilar Swiss Ephemeris como `CSwissEph` target inline elimina supply-chain risk y hace el build determinista.
- **Pure function engines**: Todos los motores astrológicos son stateless (`static` methods), lo que los hace trivialmente testeables y thread-safe.
- **Sendable / MainActor discipline**: Uso correcto de concurrencia Swift 6. Los cálculos pesados van en `Task.detached`, la UI en `MainActor`.
- **Protocol-based services**: `JoplinHTTPClient` permite mocking sin dependencias de red reales en tests.
- **Migration runner idempotente**: Safe to re-run, dual database (corpus + user), naming convention routing.

### 2.2 Rigor Doctrinal

- **Motor horario nativo**: Implementación completa de Lilly — 7 planetas tradicionales, casas Regiomontanus, sect, dignidades esenciales y accidentales, perfección (aplicativo directo, translación, colección), recepción (simple y mutua), consideraciones (ASC temprano/tardío, vía combusta, Luna vacía, Saturno en 1/7), veredicto con 5 categorías y confianza. Esto es **astrología clásica seria**, no aproximación new-age.
- **Dignidades esenciales ptolemaicas**: Domicilios, exaltaciones, triplicidades (con sect), términos egipcios, decanatos caldeos — todo con fuentes citadas en comentarios (Tetrabiblos, Bonatti, Lilly).
- **Direcciones primarias Regiomontanus**: Proyección speculum completa (pole, Q, W, ZD, MD), tres claves temporales (Naibod, Ptolomeo, Brahe), tres planos de aspecto (zodiacal, mundane, eclíptico), Pars Fortunae sect-dependent. Port directo de Morinus con paridad verificada por tests golden.
- **Corpus honesty policy**: `populated=0` entries tienen NULL text; solo fuentes verificadas obtienen `populated=1`. Esto es integridad intelectual rara en software astrológico.

### 2.3 Testing

- **17 archivos de test**, ~4000+ líneas totales.
- **Golden reference tests** para direcciones primarias (detección de regresión).
- **William Lilly chart** (1602-05-01) como validación histórica.
- **Paridad horaria** entre motor Swift y legacy Python.
- **In-memory SQLite** para corpus testing sin I/O real.

### 2.4 Funcionalidad Operativa

- **Joplin integration**: Export directo de lecturas a notas, auto-detección de token.
- **Ephemeris calendar**: 6 calculadores independientes (lunaciones, eclipses, estaciones, ingresos de signo, void of course, aspectos mundanos).
- **Transit scoring multidimensional**: Score técnico + relevancia personal + impacto temporal + priority bands (critical/high/medium/low).
- **Offline-first**: Seed cities JSON + timezone inference determinista por coordenadas.

---

## 3. Análisis Crítico por Módulo

### 3.1 Carta Natal (`AstroEngine.swift`)

**Lo bueno**:
- 10 planetas + nodos lunares, casas Placidus, 5 aspectos ptolemaicos.
- `swe_houses_ex2` con velocidades de cúspides (preparado para futuro uso).
- Cálculo de aspectos con orbs diferenciados.

**Limitaciones**:
- **Solo Placidus**: No hay selector de sistema de casas. Muchos astrólogos clásicos prefieren Regiomontanus o Whole Sign para ciertos análisis. Los horarios ya usan Regiomontanus (hardcoded "R"), pero la carta natal no ofrece alternativa.
- **Sin aspectos menores**: Quincunx (150°), semi-sextil (30°), semi-cuadrado (45°), sesqui-cuadrado (135°), quintile (72°). Estos son relevantes en astrología moderna y algunos astrólogos clásicos usan el quincunx.
- **Sin asteroides**: Quirón, Lilith (media y verdadera), Parte de Fortuna en carta natal (solo aparece en horaria).
- **Sin estrellas fijas**: Regulus, Spica, Antares, Algol, etc. Son parte de la tradición clásica (Ptolomeo les dedica espacio en Tetrabiblos).
- **Nodos**: Solo true node, no mean node como alternativa.

### 3.2 Tránsitos (`TransitEngine.swift`)

**Lo bueno**:
- Scoring multidimensional bien pensado con pesos planetarios, de aspecto, factor orb.
- Fusión de eje nodal (NODO_NORTE + NODO_SUR → EJE_NODAL).
- House ingress detection para planetas exteriores.
- Priority bands con percentiles.
- Detección de cancelaciones (aspecto que se anula por retrogradación).

**Limitaciones**:
- **Sin tránsitos de nodos a planetas natales con orbs diferenciados por tipo de nodo**: El eje nodal fusionado pierde la distinción entre tránsito de nodo norte vs sur, que algunos astrólogos distinguen.
- **Sin secondary progressions**: Las progresiones secundarias son una técnica predictiva fundamental que falta completamente.
- **Sin solar arc directions**: Otra técnica predictiva mayor ausente.
- **Sin composite/midpoint transits**: Puntos medios (Sol/MC, Luna/ASC, etc.) como puntos sensibles a tránsitos.
- **El scoring es opaco**: Los pesos están hardcoded sin explicación doctrinal en el código. ¿Por qué Plutón=10 y Luna=1? Esto refleja una jerarquía moderna (transpersonales > personales) que no es universal.

### 3.3 Revolución Solar (`SolarReturnEngine.swift`)

**Lo bueno**:
- Cálculo exacto con `swe_solcross_ut`.
- Overlay de planetas solares en casas natales.
- Lectura guiada estructurada.

**Limitaciones**:
- **Sin carta de生日 solar completa**: No genera aspectos de la revolución solar internamente (solo overlay sobre natal). Una revolución solar se lee con sus propios aspectos internos + aspectos a la natal.
- **Sin comparación de ASC/MC solar con natal**: El ASC de la revolución solar y su regidor son fundamentales para la lectura del año.
- **Sin método de ubicación**: No explica si usa el método de relocación (Travested) o el de retorno al lugar de nacimiento.

### 3.4 Revolución Lunar (`LunarReturnEngine.swift`)

**Lo bueno**:
- Retornos secuenciales con `swe_mooncross_ut`.
- Scoring de intensidad.
- Estadísticas (intervalo ~27.3 días, distribución de casas lunares).

**Limitaciones**:
- **Mini-narrativas genéricas**: Las interpretaciones parecen template-based, no adaptadas a la carta natal del usuario.
- **Sin overlay con carta natal**: La revolución lunar se lee en relación con la carta natal (dónde cae la Luna solar en casas natales, aspectos a planetas natales).

### 3.5 Direcciones Primarias (`PrimaryDirections/`)

**Lo bueno**:
- Implementación Regiomontanus completa y verificada contra Morinus.
- Directas y conversas como operaciones geométricas separadas (correcto).
- Tres claves temporales (Naibod, Ptolomeo, Brahe).
- Tres planos de aspecto.
- Corpus curado de 165 entradas clásicas de Lilly.
- Foundry Local para interpretación contextual.
- Timeline semántico por décadas.
- Vista de año actual con ventana ±18 meses.

**Limitaciones**:
- **Solo Regiomontanus**: Faltan Placidus, Campanus, Zodiacal (sin proyección de polo). Cada método da direcciones diferentes y algunos astrólogos prefieren alternativas.
- **Sin anti-escia**: Las direcciones por anti-escia (eje equinoccial) son una técnica clásica ausente.
- **Sin promotores adicionales**: Solo 5 significadores (ASC, MC, Sol, Luna, Pars Fortunae). Faltan nodos lunares como significadores.
- **Sin cálculo de hyleg/alcocoden**: El hyleg (dador de vida) y alcocoden (dador de años) son fundamentales en la tradición de direcciones primarias para cálculo de longevidad.

### 3.6 Astrología Horaria (`HoraryNativeEngine.swift`)

**Lo bueno**:
- Implementación completa de la tradición de Lilly.
- 7 planetas tradicionales + Nodo Norte.
- Sect, dignidades, perfección, recepción, consideraciones, veredicto.
- Hora planetaria con cálculo de amanecer/atardecer.
- Timing por casa + modalidad + grados.
- Motor nativo Swift con fallback a Python.

**Limitaciones**:
- **Sin Partes árabes adicionales**: Solo Fortune y Spirit. Faltan Parte de Amor, Parte de Comercio, Parte de Enfermedad, etc., que son relevantes según el tema de la pregunta.
- **Sin estrellas fijas**: No considera conjunciones a estrellas fijas (especialmente relevante para Luna).
- **Sin cálculo de grado del ASC como significador**: El grado exacto del ASC y su decanato/termino pueden dar información adicional.
- **Los términos egipcios difieren ligeramente** entre `HoraryNativeEngine` y `EssentialDignityEngine` (ejemplo: Aries en horaria tiene Júpiter 0-6, Venus 6-14, Mercurio 14-21 vs EssentialDignityEngine que tiene Júpiter 0-6, Venus 6-12, Mercurio 12-20). **Esto es una inconsistencia que debe corregirse**.

### 3.7 Efemérides (`Ephemeris/`)

**Lo bueno**:
- 6 calculadores independientes bien separados.
- Angular bisection para precisión de eventos.
- Void of course con lógica correcta (último aspecto ptolemaico a ingreso lunar).
- Retrograde re-entries en sign ingresses.

**Limitaciones**:
- **Sin cálculo de fase lunar detallada**: Solo new/full/quarters. Faltan octiles (45°, 135°, 225°, 315°) que algunos astrólogos usan.
- **Sin eclipses por Saros**: Los eclipses no están clasificados por serie Saros, que da contexto histórico.
- **Sin aspects ingress**: No detecta cuándo un aspecto exacto entre planetas tránsitos se forma por ingreso de uno de ellos en un signo.

---

## 4. Mejoras Funcionales Propuestas (Priorizadas)

### PRIORIDAD ALTA — Impacto directo en valor astrológico

#### 4.1 Sistemas de casas múltiples
**Problema**: Solo Placidus para natal, Regiomontanus para horaria/PD.
**Propuesta**: Selector de sistemas: Placidus, Regiomontanus, Whole Sign, Equal, Campanus, Koch. Swiss Ephemeris soporta todos via `swe_houses_ex2` con diferentes letras de `hsys`.
**Impacto**: Permite a astrólogos clásicos usar Whole Sign (tradición helenística) o Regiomontanus (tradición medieval) para cartas natales.

#### 4.2 Progresiones Secundarias
**Problema**: Ausente completamente.
**Propuesta**: Motor de secondary progressions (1 día = 1 año). Calcular posiciones progresadas de todos los planetas, aspectos progresados a natal, Luna progresada como trigger principal.
**Impacto**: Es la técnica predictiva más usada junto con tránsitos. Sin esto, el módulo predictivo está incompleto.

#### 4.3 Solar Arc Directions
**Problema**: Ausente.
**Propuesta**: Motor que mueve todos los planetas natales el mismo arco que el Sol progresado. Aspectos solar arc a planetas natales y ángulos.
**Impacto**: Técnica predictiva fundamental en astrología psicológica y moderna.

#### 4.4 Partes Árabes en Carta Natal
**Problema**: Solo Parte de Fortuna en horaria.
**Propuesta**: Calcular en carta natal: Parte de Fortuna (sect-dependent), Parte del Espíritu, Parte de Eros, Parte de Victoria, Parte de Necesidad. Fórmulas sect-dependent documentadas.
**Impacto**: Enriquece la lectura natal con puntos sensibles de la tradición clásica.

#### 4.5 Estrellas Fijas
**Problema**: Ausentes en todos los módulos.
**Propuesta**: Incluir las 15 estrellas fijas behenianas (Aldebaran, Algol, Capella, Sirius, etc.) con longitudes calculables via Swiss Ephemeris (`SE_STARNAME`). Aspectos a estrellas fijas en carta natal, tránsitos y horaria.
**Impacto**: Las estrellas fijas son parte integral de la tradición clásica (Ptolomeo, Lilly, Bonatti).

#### 4.6 Consistencia de Términos Egipcios
**Problema**: Los términos egipcios difieren entre `HoraryNativeEngine` y `EssentialDignityEngine`.
**Propuesta**: Unificar en una sola fuente de verdad. `EssentialDignityEngine` parece más cercano a las fuentes clásicas (Lilly CA p.104). Horaria debe usar el mismo engine en lugar de tener tablas duplicadas.
**Impacto**: Elimina discrepancias doctrinales y reduce código duplicado.

### PRIORIDAD MEDIA — Mejoras significativas

#### 4.7 Carta de Revolución Solar Completa
**Propuesta**: Calcular aspectos internos de la revolución solar, no solo overlay sobre natal. Incluir: ASC/MC solar y sus regidores, aspectos entre planetas solares, planetas solares en casas natales, planetas natales en casas solares.

#### 4.8 Asteroides Principales
**Propuesta**: Añadir Quirón (SE_CHIRON), Lilith verdadera (SE_MEAN_APOG o SE_OSCU_APOG), y opcionalmente Ceres, Pallas, Juno, Vesta. Swiss Ephemeris los soporta nativamente.

#### 4.9 Sinastría Mejorada
**Propuesta**: Añadir composite chart (puntos medios entre dos cartas), Davison relationship chart, y comparison de cartas progresadas (no solo natales).

#### 4.10 Horary — Partes Árabes Contextuales
**Propuesta**: Según el tema de la pregunta (casa seleccionada), calcular partes relevantes:
- Casa 7 (matrimonio): Parte de Amor, Parte de Matrimonio
- Casa 2 (dinero): Parte de Comercio, Parte de Sustancia
- Casa 6 (salud): Parte de Enfermedad, Parte de Cirugía
- Casa 10 (carrera): Parte de Profesión

#### 4.11 Tránsitos — Midpoints Sensibles
**Propuesta**: Calcular puntos medios natales relevantes (Sol/MC, Luna/ASC, Sol/Luna, ASC/MC) y detectar tránsitos a estos puntos con orbes estrechos (1-1.5°).

#### 4.12 Direcciones Primarias — Método Placidus
**Propuesta**: Añadir direcciones primarias por Placidus como alternativa a Regiomontanus. Requiere implementar la proyección de polo de Placidus.

### PRIORIDAD BAJA — Nice to have

#### 4.13 Astrocartografía
**Propuesta**: Mapa de líneas de relocación (ASC, MC, DC, IC de planetas sobre el globo). Swiss Ephemeris tiene `swe_azalt` y funciones de relocación.

#### 4.14 Elecciones (Electional Astrology)
**Propuesta**: Módulo para encontrar ventanas temporales favorables según criterios astrológicos (Luna creciente, en buen signo, sin aflicciones, regente de hora favorable).

#### 4.15 Retornos de Planetas Exteriores
**Propuesta**: Calcular retornos de Saturno (~29.5 años), Urano (~84 años), Neptuno (~165 años), Plutón (~248 años). El retorno de Saturno es particularmente importante.

#### 4.16 Fases Lunares Detalladas
**Propuesta**: Octiles (45°, 135°, 225°, 315°), balsamic phase, disseminating phase, con interpretaciones.

#### 4.17 Aspectos Menores
**Propuesta**: Quincunx (150°), semi-sextil (30°), semi-cuadrado (45°), sesqui-cuadrado (135°), quintile (72°), bi-quintile (144°). Con orbes apropiados (más estrechos que los mayores).

---

## 5. Mejoras Técnicas

### 5.1 Error Handling
- Reemplazar `fatalError` en `AppState.init()` con graceful degradation.
- Eliminar `try?` silenciosos en `CorpusStore` — al menos loguear errores.
- Añadir retry logic para Nominatim y OpenRouter.

### 5.2 Configuración Externalizada
- Los pesos de scoring de tránsitos deben ser configurables por el usuario, no hardcoded.
- Los orbes de aspectos deben ser ajustables por preferencia.
- Crear un `AstroConfig` struct con defaults pero permitiendo override.

### 5.3 Duplicación de Código
- `HoraryNativeEngine` y `EssentialDignityEngine` tienen tablas duplicadas (domicilios, exaltaciones, triplicidades, términos, decanatos). Refactorizar para que horaria use `EssentialDignityEngine`.
- Los cálculos de signos/grados se repiten en múltiples archivos. Crear un `SignUtils` shared.

### 5.4 Export y Visualización
- **Export PDF/PNG** de la rueda natal.
- **Export PDF** de lecturas completas.
- **Print-friendly** layout para todas las vistas.
- **SVG export** de la rueda para uso en otros contextos.

### 5.5 Localización
- Infraestructura para i18n (al menos inglés/español).
- Los labels de planetas, signos y aspectos están hardcoded en español.
- Usar `String(localized:)` o un sistema de diccionarios.

### 5.6 Performance
- El ephemeris engine calcula secuencialmente (por diseño, Swiss Ephemeris tiene estado global). Considerar caching de posiciones planetarias para rangos superpuestos.
- Las direcciones primarias calculan hasta 120 años por defecto — permitir cálculo lazy bajo demanda.

---

## 6. Observaciones Doctrinales Específicas

### 6.1 Sect en Carta Natal
La sect se calcula correctamente en horaria (Sol en casas 7-12 = diurna), pero **no se expone en la carta natal**. La sect es fundamental para:
- Fórmula del Parte de Fortuna
- Regentes de triplicidad
- Planetas benéficos/maléficos por sect

**Propuesta**: Calcular y mostrar sect en la carta natal, usarla para el Parte de Fortuna natal.

### 6.2 Regente del ASC
El regente del ASC (dispositor) es una pieza clave de la lectura natal que **no se calcula explícitamente** en `AstroEngine`. Solo aparece en horaria.

**Propuesta**: Añadir `ascRuler` a `NatalChart`, con su posición en casa y signo.

### 6.3 Almuten
El almuten (planeta con más dignidades en un punto) no se calcula. Es relevante para:
- Almuten del ASC (regente general de la carta)
- Almuten de la Luna
- Almuten del Parte de Fortuna

**Propuesta**: Función `almuten(longitude: [Double]) -> String` que sume dignidades de todos los planetas en un punto y retorne el ganador.

### 6.4 Vía Combusta
Se detecta en horaria (Luna 15° Sagitario - 15° Capricornio), pero **no se muestra en carta natal**. Es una zona de aflicción que algunos astrólogos marcan en la rueda.

### 6.5 Cazimi vs Combust
Se distingue correctamente en horaria (cazimi < 17', combusto < 8.5°). Esta distinción **debería aparecer también en la carta natal** para planetas cercanos al Sol.

---

## 7. Inconsistencias Detectadas

### 7.1 Términos Egipcios Duplicados y Diferentes

| Signo | HoraryNativeEngine | EssentialDignityEngine | Fuente Clásica (Lilly) |
|-------|-------------------|----------------------|----------------------|
| Aries | Júp 0-6, Ven 6-14, Mer 14-21 | Júp 0-6, Ven 6-12, Mer 12-20 | Júp 0-6, Ven 6-12, Mer 12-20 ✓ |
| Piscis | Ven 0-12, Júp 12-16, Mer 16-19 | Ven 0-8, Júp 8-14, Mer 14-20 | Ven 0-8, Júp 8-14, Mer 14-20 ✓ |

**Veredicto**: `EssentialDignityEngine` es correcto según Lilly. `HoraryNativeEngine` tiene errores en varios signos. **Acción**: Eliminar tablas de horaria y usar `EssentialDignityEngine`.

### 7.2 Decanatos Diferentes

Los decanatos en `HoraryNativeEngine` siguen un orden diferente al de `EssentialDignityEngine` (que usa orden caldeo puro). El orden caldeo es: Marte, Sol, Venus, Mercurio, Luna, Saturno, Júpiter, repitiendo.

**Veredicto**: `EssentialDignityEngine` es correcto. Unificar.

### 7.3 Nomenclatura de Planetas

- `AstroEngine`: usa keys en mayúsculas (`SOL`, `LUNA`, `MERCURIO`)
- `HoraryNativeEngine`: usa nombres capitalizados (`Sol`, `Luna`, `Mercurio`)
- `EssentialDignityEngine`: usa keys en mayúsculas

Esto obliga a mapeos constantes y es fuente potencial de bugs.

**Propuesta**: Establecer un canonical planet key enum (`PlanetKey: String, CaseIterable`) y usarlo en todos los módulos.

---

## 8. Evaluación del Corpus

### 8.1 Estado Actual
- **1,779 interpretaciones** en corpus.db
- 125 planet-sign, 121 planet-house, 368 natal aspects, 745 transits, 420 synastry
- 165 entradas de direcciones primarias (Lilly Book III)
- 74 house ingress interpretations

### 8.2 Cobertura
| Tipo | Combinaciones Posibles | Cubiertas | % |
|------|----------------------|-----------|---|
| Planet-Sign | 12 × 12 = 144 | 125 | 87% |
| Planet-House | 12 × 12 = 144 | 121 | 84% |
| Natal Aspects | ~55 pares × 5 aspectos = 275 | 368 | >100% (incluye nodos) |
| Synastry | 12 × 12 × 5 × 2 dir = 1440 | 420 | 29% |
| Transits | ~12 planetas × 12 casas × 5 aspectos = 720 | 745 | >100% |
| PD Classical | 165 curadas | 165 | 100% |

### 8.3 Recomendaciones de Corpus
- **Completar sinastría**: Los 420 textos cubren solo 29% de combinaciones posibles. Priorizar los aspectos más frecuentes (conjunciones y oposiciones entre planetas personales).
- **Añadir interpretaciones de Partes árabes**: Parte de Fortuna en signo/casa, aspectos a PF.
- **Añadir interpretaciones de estrellas fijas**: Conjunciones a las 15 behenianas.
- **Añadir interpretaciones de progresiones secundarias**: Luna progresada en signo/casa, aspectos progresados.

---

## 9. Comparativa con Analyses Anteriores

El repo ya contiene análisis de Claude Opus, Gemini 3.1 Pro y ChatGPT 5.5. Mi perspectiva como Qwen 3.6 Plus añade:

1. **Detección de inconsistencia en términos egipcios** — No identificada en análisis previos.
2. **Propuesta de almuten como concepto unificador** — No mencionado previamente.
3. **Énfasis en sect como hilo conductor** — Presente en horaria pero ausente en natal.
4. **Análisis de cobertura del corpus con porcentajes** — Cuantificación precisa.
5. **Propuesta de PlanetKey enum canónico** — Solución técnica a problema de nomenclatura.

---

## 10. Roadmap Sugerido

### Fase 1 — Correcciones (1-2 semanas)
1. Unificar términos egipcios y decanatos (eliminar duplicados en horaria)
2. Crear `PlanetKey` enum canónico
3. Exponer sect en carta natal
4. Añadir regente del ASC a `NatalChart`
5. Reemplazar `fatalError` con graceful degradation

### Fase 2 — Funcionalidad Predictiva (3-4 semanas)
1. Motor de progresiones secundarias
2. Solar arc directions
3. Partes árabes en carta natal
4. Retorno de Saturno

### Fase 3 — Profundidad Doctrinal (3-4 semanas)
1. Estrellas fijas (15 behenianas)
2. Sistemas de casas múltiples
3. Almuten calculator
4. Asteroides (Quirón, Lilith)
5. Midpoints sensibles

### Fase 4 — UX y Export (2-3 semanas)
1. Export PDF/PNG de rueda natal
2. Print-friendly layouts
3. Configuración de orbes y pesos
4. Localización inglés/español

---

## 11. Conclusión

AstroMalik-macOS es un proyecto **técnicamente excelente** con una base doctrinal sólida. La decisión de usar Swiss Ephemeris C library directamente (sin wrappers Swift de terceros) demuestra madurez técnica. El motor horario nativo es probablemente la joya del proyecto — una implementación seria de la tradición de Lilly que pocos softwares comerciales igualan.

Las principales oportunidades de mejora son:
1. **Consistencia interna** (unificar tablas de dignidades, nomenclatura de planetas)
2. **Técnicas predictivas faltantes** (progresiones secundarias, solar arc)
3. **Profundidad doctrinal** (estrellas fijas, almuten, sect en natal, partes árabes)
4. **UX profesional** (export, sistemas de casas configurables, localización)

Con las mejoras de Fase 1 y 2, AstroMalik se posicionaría como una de las aplicaciones astrológicas open-source más completas disponibles para macOS.

---

*Informe generado por Qwen 3.6 Plus — Mayo 2026*
