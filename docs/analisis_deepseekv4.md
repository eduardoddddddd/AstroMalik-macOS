# Análisis DeepSeek v4 — AstroMalik-macOS

**Fecha:** 2026-05-09  
**Versión analizada:** `main` a fecha de hoy  
**Alcance:** Código Swift (~70 archivos), documentación, corpus, tests, infraestructura  

---

## 1. Resumen Ejecutivo

AstroMalik-macOS es una aplicación astrológica nativa para macOS (SwiftUI + Swiss Ephemeris) con un nivel de completitud técnica **sobresaliente** para ser un proyecto individual. Tiene 70 archivos Swift, 17 archivos de test, 1.779 interpretaciones en corpus, y cubre los módulos astrológicos fundamentales: carta natal, tránsitos, sinastría, revoluciones solar/lunar, efemérides, direcciones primarias Regiomontanus y horaria nativa.

La arquitectura es sólida (orientada a motores puros sin estado, vista única con `NavigationSplitView`, persistencia local con SQLite), la documentación es extensa, y la cobertura de tests es buena para los motores críticos.

**Principales brechas detectadas:** duplicación de tablas astrológicas entre motores, ausencia de técnicas predictivas avanzadas y de herramientas complementarias (estrellas fijas, partes arábigas, armonicos), y limitaciones funcionales que impiden que la aplicación alcance el estándar de una herramienta profesional completa.

---

## 2. Fortalezas del Proyecto

### 2.1 Arquitectura de Motores

Cada dominio astrológico está implementado como un motor **puro, sin estado y testeable**:

- `AstroEngine` — núcleo astronómico (Swiss Ephemeris vía `CSwissEph`)
- `EssentialDignityEngine` — dignidades ptolemaicas completas
- `TransitEngine` — scoring multicriterio (técnico × personal × temporal)
- `SolarReturnEngine` / `LunarReturnEngine` — retornos con `swe_solcross_ut` / `swe_mooncross_ut`
- `HoraryNativeEngine` — horaria 100% nativa Swift (sustituyó dependencia Python)
- `PrimaryDirectionCalculator` — Regiomontanus portado de Morinus
- 7 calculadores de efemérides (lunaciones, eclipses, estaciones, ingresos, VoC, aspectos mundanos)

### 2.2 Sistema de Scoring de Tránsitos

El sistema de priorización multicapa es uno de los aspectos más sofisticados del proyecto:

- **Técnico:** peso del planeta (Plutón 10 → Luna 1) × peso del aspecto × factor de orbe
- **Personal:** multiplicador basado en casas angulares/sucedentes/cadentes, regente del ASC, Sol/Luna/ASC tocados
- **Temporal:** duración del evento, número de pasadas, clustering con otros eventos, días hasta el pico
- **Bandas:** critical / high / medium / low

Esto es materialmente superior a la mayoría de apps astrológicas comerciales.

### 2.3 Motor de Horaria Nativo

El reemplazo completo del motor Python por Swift nativo es un logro notable. Implementa:

- 7 planetas tradicionales + Nodo Norte verdadero
- Casas Regiomontanus
- Dignidades esenciales y accidentales
- Hora planetaria y radicalidad
- Recepción simple/mutua
- Perfección directa, translación y colección
- Veredicto estructurado (sí/no/no_todavía/dudoso/requiere_mediacion)
- Regla doctrinal correcta de Luna fuera de curso

### 2.4 Cobertura de Tests

17 archivos de test cubren los motores críticos, incluyendo golden tests para direcciones primarias y tests de regresión para horaria nativa. Esto es excelente para un proyecto individual.

### 2.5 Integración con Herramientas

- **Joplin:** exportación directa de notas Markdown vía Web Clipper API
- **OpenRouter:** cliente opcional para interpretación contextual con LLM
- **Foundry Local:** bridge a proceso Python para interpretación AI

### 2.6 Zero Dependencias Externas Swift

El proyecto no depende de ningún paquete Swift de terceros. SQLite se usa mediante la biblioteca del sistema con un wrapper propio (`SQLiteDB`). Esto elimina riesgos de supply chain y simplifica el build.

---

## 3. Problemas Detectados

### 3.1 Duplicación de Tablas Astrológicas (CRÍTICO)

`EssentialDignityEngine` y `HoraryNativeEngine` contienen **copias independientes** de las mismas tablas:

| Tabla | EssentialDignityEngine | HoraryNativeEngine |
|-------|----------------------|-------------------|
| Domicilios | `domicileRuler(of:)` | `rulerships` |
| Exaltaciones | `exaltation(of:)` | `exaltations` |
| Triplicidades | `triplicityRuler(sign:planet:)` | `triplicities` |
| Términos Egipcios | `egyptianTerms` | `egyptianTerms` |
| Decanatos | `chaldeanOrder` + `faceRuler()` | `decans` |
| Signos | `signName(_:)` | `signs` |
| Elementos | (ausente) | `elements` |
| Modalidades | (ausente) | `modalities` |

**Riesgo:** Cualquier corrección en una tabla (ej. un error en los términos egipcios) debe hacerse en dos sitios. Si se olvida uno, los módulos divergen y producen resultados inconsistentes.

**Solución propuesta:** Extraer todas las tablas a un único `enum TraditionalTables` o `enum AstrologicalConstants` accesible desde ambos motores.

### 3.2 Inconsistencia de Paradigmas entre Motores

| Motor | Paradigma |
|-------|-----------|
| `AstroEngine` | `final class` con métodos `static` |
| `EssentialDignityEngine` | `enum` (sin casos) con métodos `static` |
| `TransitEngine` | Funciones libres (`computeTransitPeriod(...)`) |
| `SolarReturnEngine` | `enum` con métodos `static` |
| `LunarReturnEngine` | `enum` con métodos `static` |
| `HoraryNativeEngine` | `enum` con métodos `static` |
| `EphemerisEngine` | `enum` con métodos `static` |

Esto no rompe nada, pero dificulta:
- Inyección de dependencias para testing
- Posible futura migración a `actor` para concurrencia
- Consistencia de API (algunos lanzan, otros no)

**Solución propuesta:** Unificar a un protocolo `AstrologicalCalculator` con requisitos comunes y usar `struct` + inyección en lugar de `static`.

### 3.3 Estado Global de Swiss Ephemeris

`CSwissEph` mantiene estado global interno. La documentación en `EphemerisEngine` reconoce que paralelizar búsquedas de eclipses provocó crashes (`signal 11`). Los cálculos se ejecutan secuencialmente como workaround.

**Impacto:** La app no puede aprovechar múltiples núcleos para acelerar cálculos de periodos largos de tránsitos o efemérides.

**Solución propuesta:** Evaluar si es posible aislar llamadas a Swiss Ephemeris con un `SerialActor` que serialice el acceso global mientras permite concurrencia en el resto del pipeline.

### 3.4 Cálculo Redundante en Vistas

`NatalWheelView` recalcula aspectos en cada render:

```swift
private var aspects: [NatalAspect] {
    let rawPlanets = Dictionary(uniqueKeysWithValues: chart.bodies.map { ... })
    return AstroEngine.computeNatalAspects(planets: rawPlanets)
}
```

Esto debería precalcularse una vez y almacenarse en `NatalChart` o en el ViewModel.

### 3.5 Corpus de Solo Lectura

El corpus (`corpus.db`) es de solo lectura y está embebido en el bundle. No hay mecanismo para que el usuario:
- Añada interpretaciones propias
- Sobrescriba interpretaciones que considere incorrectas
- Importe corpus de terceros

**Solución propuesta:** Sistema de capas: corpus base (bundle) → corpus de usuario (user.db) con precedence del usuario sobre el base.

### 3.6 Ausencia de Caché entre Módulos

Varios módulos recalculan las mismas posiciones planetarias. Por ejemplo, `TransitEngine` y `EphemerisEngine` llaman independientemente a `AstroEngine.calcPlanets(jd:)`. No existe una caché de posiciones por JD que evite llamadas redundantes a Swiss Ephemeris.

### 3.7 Sin Protocolo de Abstracción para Motores

No hay protocolos que definan la interfaz de cada motor. Esto impide:
- Mocking en tests unitarios puros
- Posibilidad de implementaciones alternativas (ej. JPL Horizons en vez de Swiss Ephemeris)
- Composición de motores mediante dependency injection

---

## 4. Mejoras Funcionales Propuestas (Priorizadas)

### 4.1 Alta Prioridad — Técnicas Predictivas Avanzadas

#### 4.1.1 Progresiones Secundarias

Las progresiones secundarias (1 día = 1 año) son la técnica predictiva más usada después de los tránsitos. La implementación requiere:

- `SecondaryProgressedEngine` que avance la carta natal 1 día por año de vida
- Cálculo de la Luna progresada (fundamental, se mueve ~1° por mes)
- Aspectos entre progresados y natales
- Ángulos progresados (ASC/MC) con el método adecuado (Naibod en ascensión recta, solar arc en longitud)

#### 4.1.2 Direcciones de Arco Solar

Las direcciones de arco solar son más simples que las primarias Regiomontanus pero igualmente importantes. Avanzan todos los puntos natales por el arco solar diario × años.

#### 4.1.3 Técnicas de Señores del Tiempo

- **Profecciones anuales:** el ASC avanza 1 signo por año. Implementable en ~200 líneas.
- **Firdaria:** períodos planetarios secuenciales basados en sect (diurno/nocturno). Puramente algorítmico.

### 4.2 Alta Prioridad — Herramientas Complementarias

#### 4.2.1 Estrellas Fijas

Swiss Ephemeris soporta estrellas fijas con `swe_fixstar2_ut`. Implementar:

- Lista de ~30 estrellas tradicionales principales (Aldebarán, Algol, Antares, Régulus, Spica, Sirius, etc.)
- Cálculo de conjunciones con planetas natales y ángulos
- Orbes ajustados por magnitud (1° para 1ª magnitud, 0.5° para otras)
- Naturaleza planetaria de cada estrella (Marte-Júpiter para Aldebarán, etc.)

Referencia: `swe_fixstar2_ut(star, jd, iflag, &xx, &serr)`

#### 4.2.2 Partes Arábigas (Lotes)

AstroMalik ya calcula Parte de Fortuna y Parte del Espíritu. Ampliar:

- Parte del Matrimonio (ASC + C7 - Venus para hombres, ASC + Venus - C7 para mujeres)
- Parte de la Profesión/Vocación (MC + Luna - Sol)
- Parte de los Hijos (ASC + C5 - Júpiter)
- Parte de la Muerte (ASC + C8 - Luna)
- Parte de la Amistad (ASC + C11 - Sol)
- API genérica: `calculateArabicPart(asc: Double, point1: Double, point2: Double) -> Double`

#### 4.2.3 Antiscias y Contrantiscias

Técnica tradicional fundamental. Dos puntos están en antiscio si son simétricos respecto al eje Cáncer-Capricornio (0° Cáncer / 0° Capricornio):

```swift
func antiscium(longitude: Double) -> Double {
    // Simetría respecto al eje 0° Cáncer — 0° Capricornio
    // antiscio = 360 - (longitude - 90)  → ajustar a [0, 360)
}
```

La contrantiscia es el punto opuesto a la antiscio (+180°).

#### 4.2.4 Puntos Medios (Midpoints)

Técnica cosmobiológica y uraniana. Para cada par de planetas A y B:

```swift
func midpoint(a: Double, b: Double) -> Double {
    let diff = abs((a - b + 360).truncatingRemainder(dividingBy: 360))
    let mp = (a + b) / 2
    if diff > 180 { return (mp + 180).truncatingRemainder(dividingBy: 360) }
    return mp.truncatingRemainder(dividingBy: 360)
}
```

Implementar una cuadrícula de midpoints (matriz 12×12 planetas + ASC + MC) en la vista de carta natal.

#### 4.2.5 Declinaciones y Paralelos

Swiss Ephemeris devuelve latitud y declinación en `xx[1]` y `xx[2]` al usar flags adecuados. Añadir:

- Tabla de declinaciones para todos los planetas
- Aspectos de declinación: paralelo (0° orb ~1°) y contraparalelo (misma declinación, signo opuesto)
- Planetas "fuera de límites" (out of bounds, declinación > 23°27')

### 4.3 Prioridad Media — Módulos Astrológicos

#### 4.3.1 Astrología Electiva

Motor para buscar ventanas temporales favorables:

- Seleccionar planeta/signo/casa objetivo
- Definir restricciones (Luna no vacía de curso, no aspectos duros en angular, etc.)
- Escanear periodo futuro buscando días/horas que cumplan criterios
- Scoring de calidad electiva basado en reglas de Bonatti/Lilly

#### 4.3.2 Astrología Vocacional

Módulo especializado para análisis de carrera:

- Significadores vocacionales: MC, regente del MC, planetas en Casa 10 y Casa 6
- Pesos por casa: 10 (carrera) > 6 (trabajo diario) > 2 (ingresos) > 1 (identidad)
- Combinación casa-signo-planeta para sugerir profesiones
- Se puede construir sobre el corpus existente añadiendo 200-300 textos vocacionales

#### 4.3.3 Gráficos Armónicos (Harmonics)

Los armónicos (1 al 12 como base) revelan patrones que no son visibles en la carta natal:

- Armónico 4: trabajo, realización
- Armónico 5: creatividad, talento
- Armónico 7: espiritualidad, patrones ocultos
- Armónico 9: sabiduría superior, propósito
- Implementación: multiplicar longitudes por N, reducir a [0, 360), calcular aspectos con orbes ajustados (orbe natal / N)

#### 4.3.4 Retornos Planetarios Adicionales

Actualmente solo Sol y Luna. Añadir:

- Retorno de Mercurio (~1 año, útil para periodos de comunicación/estudio)
- Retorno de Venus (~1 año, relaciones/placeres)
- Retorno de Marte (~2 años, acción/proyectos)
- Retorno de Júpiter (~12 años, ciclos de expansión)
- Retorno de Saturno (~29 años, madurez/hitos vitales)

Swiss Ephemeris ofrece `swe_solcross_ut` solo para el Sol. Para otros planetas hay que implementar bisección sobre el cruce de longitud, que es lo que ya hace el motor de efemérides para calcular ingresos de signo (la misma técnica aplica para retornos).

#### 4.3.5 Tránsitos de Luna (Configurable)

Actualmente los tránsitos excluyen la Luna por defecto. Añadir opción de incluirla para:

- Tránsitos diarios de timing preciso (la Luna toca cada planeta natal ~1 vez al mes)
- Útil para planificación a corto plazo
- Debe ser opcional porque genera mucho ruido en periodos largos

### 4.4 Prioridad Media — Mejoras de Cálculo Natal

#### 4.4.1 Sistemas de Casas Adicionales

Actualmente la app usa Placidus para natal y Regiomontanus para horaria. Swiss Ephemeris soporta 20+ sistemas de casas. Añadir como preferencia de usuario:

- Koch (popular en Europa)
- Campanus
- Whole Sign (fundamental en astrología helenística y védica)
- Equal Houses
- Porphyry

#### 4.4.2 Quirón y Asteroides

Swiss Ephemeris soporta asteroides con `swe_calc_ut` usando IDs:

- **Quirón** (#2060): el "sanador herido", puente entre Saturno y Urano. Fundamental en astrología moderna.
- **Ceres** (#1): nutrición, maternidad, ciclos
- **Palas** (#2): sabiduría estratégica, patrones
- **Juno** (#3): compromiso, contratos matrimoniales
- **Vesta** (#4): devoción, foco sagrado

#### 4.4.3 Lilith (Luna Negra)

La Luna Negra media (apogeo lunar medio) se calcula con `SE_MEAN_APOG` en Swiss Ephemeris. Es un punto ampliamente usado en astrología moderna para la sombra psicológica y el empoderamiento femenino.

### 4.5 Prioridad Media — UI/UX

#### 4.5.1 Visualización de Doble Rueda (Bi-Wheel)

Actualmente solo existe rueda simple. Implementar:

- Bi-wheel para sinastría (carta A interior, B exterior)
- Bi-wheel para tránsitos (carta natal interior, tránsitos exterior)
- Bi-wheel para progresiones
- Componente SwiftUI Canvas reutilizable con capas intercambiables

#### 4.5.2 Exportación PDF

Generar informes profesionales en PDF con:

- Wheel renderizado como imagen
- Tablas de posiciones
- Textos interpretativos seleccionados
- Posible uso de `PDFKit` nativo de macOS o generación HTML → PDF vía `WebKit`

#### 4.5.3 Tabla de Aspectos (Aspectarian)

Cuadrícula clásica de aspectos entre todos los planetas, mostrando en cada celda el aspecto exacto y su orbe. Esencial para lectura rápida profesional.

#### 4.5.4 Widgets de macOS

Widgets en Notification Center / Escritorio:
- Tránsito más importante del día
- Fase lunar actual
- Próximo tránsito exacto
- Dashboard compacto

### 4.6 Prioridad Baja — Funcionalidades Avanzadas

#### 4.6.1 AstroCartografía (ACG)

Líneas planetarias sobre mapa mundial mostrando dónde cada planeta está en ángulo (ASC, MC, DESC, IC). Requiere integración con librería de mapas (MapKit).

#### 4.6.2 Astrología Horaria Avanzada

El motor actual es sólido para V1. Ampliaciones posibles:

- Perfección por antiscia
- Perfección por aspectos menores (quincuncio 150°, semisextil 30°)
- Dignidades accidentales completas (velocidad, oriental/occidental, etc.)
- Tabla de dignidades al estilo Lilly (puntuación compuesta -60 a +60)
- Refranaciòn, prohibición y frustración
- Horaria deportiva/eventos (momento exacto de un evento)

#### 4.6.3 Sinastría de Declinaciones

Ampliar sinastría para incluir paralelos y contraparalelos de declinación entre cartas.

#### 4.6.4 Gráfico Compuesto (Composite)

- **Método de punto medio (Davison):** calcular punto medio espacial entre posiciones de A y B
- **Método de punto medio temporal:** carta levantada para el punto medio exacto entre fechas/horas de nacimiento
- Ambos son estándar en astrología de relaciones

#### 4.6.5 Técnicas de Astrología Védica Básica

- Modo sideral (Ayanamsha Lahiri como opción configurable)
- Nakshatras (27 mansiones lunares)
- Dashas básicos (Vimshottari)

---

## 5. Mejoras de Arquitectura y Código

### 5.1 Extraer Tablas Astrológicas Compartidas (P1)

Crear `Sources/AstroMalik/Engine/TraditionalTables.swift`:

```swift
enum TraditionalTables {
    // Domicilios
    static let domicileRulers: [Int: String] = [0: "MARTE", 1: "VENUS", ...]
    // Exaltaciones
    static let exaltations: [String: (sign: Int, degree: Int)] = [...]
    // Triplicidades
    static let triplicities: [Int: [String: String]] = [...]
    // Términos Egipcios
    static let egyptianTerms: [[(ruler: String, endDeg: Int)]] = [...]
    // Decanatos Caldeos (por signo)
    static let decans: [String: [String]] = [...]
    // Signos, elementos, modalidades
    static let signNames: [String] = [...]
    static let elements: [String: String] = [...]
    static let modalities: [String: String] = [...]
}
```

Tanto `EssentialDignityEngine` como `HoraryNativeEngine` deben consumir estas tablas.

### 5.2 Protocolo de Motor de Cálculo (P2)

```swift
protocol AstrologicalCalculator {
    associatedtype Input
    associatedtype Output
    func calculate(_ input: Input) throws -> Output
}

protocol TransitCalculator: AstrologicalCalculator {
    func computeTransits(for chart: NatalChart, from: Date, to: Date) async throws -> [TransitEvent]
}
```

### 5.3 Caché de Posiciones Planetarias (P2)

```swift
actor PlanetPositionCache {
    private var cache: [Double: [String: AstroEngine.RawPlanet]] = [:]
    private let maxEntries = 500
    
    func planets(for jd: Double) throws -> [String: AstroEngine.RawPlanet] {
        if let cached = cache[jd] { return cached }
        let result = try AstroEngine.calcPlanets(jd: jd)
        if cache.count >= maxEntries { cache.removeAll() }
        cache[jd] = result
        return result
    }
}
```

### 5.4 Sistema de Corpus Extensible por Usuario (P2)

- `corpus.db` embebido → capa base (solo lectura)
- `user.db` → tabla `interpretaciones_usuario` con mismas columnas
- `CorpusStore` consulta ambas, con precedencia del usuario
- UI para añadir/editar interpretaciones propias en Settings o en cada vista de detalle
- Posibilidad de exportar/importar interpretaciones de usuario como JSON

### 5.5 Precalcular Aspectos en NatalChart (P3)

Añadir propiedad `nativo` a `NatalChart`:

```swift
struct NatalChart {
    // ...existing fields...
    let aspects: [NatalAspect]  // precomputed at chart creation
}
```

`AstroEngine.computeNatalChart()` ya tiene acceso a los planetas; puede calcular aspectos en el momento de creación y evitar recálculos en vistas.

### 5.6 Tests Unitarios con Inyección (P3)

Actualmente los motores usan `static` y acceden a `CSwissEph` directamente. Para tests unitarios puros:

- Crear protocolos `SwissEphemerisProvider`, `JulianDayProvider` que envuelvan las llamadas a C
- Inyectar mocks en tests para verificar lógica sin depender de efemérides
- Esto permitiría tests deterministas para scoring, dignidades, etc.

---

## 6. Mejoras de Documentación

### 6.1 Documentación de API Interna (P2)

Los motores carecen de documentación de API (DocC). Añadir comentarios `///` para generar documentación con `swift package generate-documentation`.

### 6.2 Guía de Contribución (P3)

Crear `CONTRIBUTING.md` con:
- Estructura del proyecto
- Cómo añadir un nuevo motor
- Convenciones de código
- Cómo ejecutar tests
- Cómo añadir entradas al corpus

### 6.3 Referencia de Corpus (P3)

Documentar el esquema exacto de `corpus.db`, formato de claves para cada tipo de interpretación, y proceso para añadir nuevos textos.

---

## 7. Comparativa con Referencias del Mercado

| Funcionalidad | AstroMalik | Solar Fire | TimePassages | AstroGold | Janus |
|---|---|---|---|---|---|
| Carta natal | Sí | Sí | Sí | Sí | Sí |
| Tránsitos | Sí (scoring avanzado) | Sí | Sí | Sí | Sí |
| Sinastría | Sí | Sí | Sí | Sí | Sí |
| Rev. Solar/Lunar | Sí | Sí | Sí | Sí | Sí |
| Direcciones primarias | Sí (Regiomontanus) | Sí | No | Sí | Sí |
| Progresiones secundarias | **No** | Sí | Sí | Sí | Sí |
| Arco solar | **No** | Sí | No | Sí | Sí |
| Horaria | Sí (nativa) | Sí | No | Sí | Sí |
| Electiva | **No** | Sí | No | Sí | Sí |
| Estrellas fijas | **No** | Sí | Sí | Sí | Sí |
| Partes arábigas | Solo 2 | Sí (>30) | Sí | Sí | Sí |
| Midpoints | **No** | Sí | No | Sí | Sí |
| Armonicos | **No** | Sí | No | Sí | Sí |
| AstroCartografía | **No** | Sí | No | Sí | No |
| Sistema casas múltiple | Placidus/Regio | 30+ | ~10 | ~20 | ~20 |
| Exportación PDF | **No** | Sí | Sí | Sí | Sí |
| Corpus editable por usuario | **No** | Sí | Parcial | Sí | Sí |
| Widgets | **No** | No | Sí | No | No |

**Distancia al estándar profesional:** AstroMalik está aproximadamente al **60%** de funcionalidad respecto a aplicaciones profesionales consolidadas. Cubre los fundamentos con excelencia pero carece de las técnicas predictivas avanzadas y herramientas complementarias que definen una herramienta profesional.

---

## 8. Plan de Acción Propuesto

### Fase 1 — Consolidación (1-2 semanas)

1. Extraer tablas astrológicas duplicadas a `TraditionalTables.swift`
2. Precalcular aspectos en `NatalChart`
3. Añadir protocolos de abstracción para motores
4. Implementar caché de posiciones planetarias
5. Limpiar imports y código muerto

### Fase 2 — Herramientas Fundamentales (2-4 semanas)

1. Estrellas fijas (30 principales con naturaleza planetaria)
2. Partes arábigas (10 lotes tradicionales)
3. Antiscias y contrantiscias
4. Puntos medios (cuadrícula completa + aspecto en detalle)
5. Declinaciones y paralelos

### Fase 3 — Técnicas Predictivas (4-6 semanas)

1. Progresiones secundarias (motor completo)
2. Direcciones de arco solar
3. Profecciones anuales
4. Firdaria
5. Retornos planetarios adicionales (Mercurio, Venus, Marte, Júpiter, Saturno)

### Fase 4 — Módulos Especializados (6-8 semanas)

1. Astrología electiva
2. Vocacional
3. Armonicos (1-12)
4. Quirón y asteroides principales
5. Lilith (Luna Negra)
6. Sistemas de casas adicionales

### Fase 5 — UI y Ecosistema (8-12 semanas)

1. Doble rueda (bi-wheel)
2. Tabla de aspectos (aspectarian)
3. Exportación PDF
4. Corpus editable por usuario
5. Widgets macOS
6. AstroCartografía básica

---

## 9. Conclusión

AstroMalik-macOS es un proyecto **sobresaliente** para ser desarrollado por una sola persona. La calidad del código, la documentación y la cobertura de tests están muy por encima de lo habitual en proyectos individuales de astrología. La decisión de mantenerse libre de dependencias externas Swift es acertada para un proyecto de esta escala.

La principal limitación no es técnica sino de **alcance funcional**: faltan las herramientas complementarias y técnicas predictivas avanzadas que un astrólogo profesional espera. El núcleo astronómico (Swiss Ephemeris) ya soporta todas las funciones necesarias — solo falta implementar las capas astrológicas que las consumen.

La duplicación de tablas astrológicas entre `EssentialDignityEngine` y `HoraryNativeEngine` es el único problema de calidad de código significativo, y es de solución trivial.

Con la hoja de ruta propuesta, AstroMalik podría alcanzar paridad con aplicaciones comerciales establecidas en aproximadamente 3-4 meses de trabajo enfocado, manteniendo su ventaja diferencial: ser una app nativa macOS, de código abierto, sin telemetría ni suscripciones.

---

## Apéndice A: Archivos Clave Referenciados

| Archivo | Función |
|---------|---------|
| `Sources/AstroMalik/Engine/AstroEngine.swift` | Núcleo astronómico: planetas, casas, aspectos, carta natal |
| `Sources/AstroMalik/Engine/EssentialDignityEngine.swift` | Dignidades ptolemaicas: domicilio, exaltación, triplicidad, término, decanato |
| `Sources/AstroMalik/Engine/TransitEngine.swift` | Tránsitos con scoring multicriterio y bandas de prioridad |
| `Sources/AstroMalik/Horary/HoraryNativeEngine.swift` | Motor horaria nativo Swift (duplica tablas de dignidades) |
| `Sources/AstroMalik/PrimaryDirections/PrimaryDirectionCalculator.swift` | Direcciones primarias Regiomontanus |
| `Sources/AstroMalik/Store/CorpusStore.swift` | Acceso al corpus de interpretaciones (solo lectura) |
| `Sources/AstroMalik/Views/NatalWheelView.swift` | Rueda natal interactiva (recalcula aspectos en cada render) |

## Apéndice B: Tablas Duplicadas (Referencia Rápida)

| Dato | `EssentialDignityEngine` (línea) | `HoraryNativeEngine` (línea) |
|------|----------------------------------|------------------------------|
| `domicileRuler` | L:110-122 | `rulerships` diccionario |
| `exaltation` | L:135-146 | `exaltations` diccionario |
| `egyptianTerms` | L:184-196 | `egyptianTerms` diccionario (con endDeg diferente) |
| `chaldeanOrder` | L:207 | `chaldeanOrder` L:75 |
| `signName` | L:214-217 | `signs` array + `elements`/`modalities` diccionarios |

**Atención:** Las tablas de términos egipcios tienen los mismos datos pero los rangos están marcados de forma diferente en cada motor (en uno son rangos, en otro son puntos de corte). Verificar consistencia funcional al unificar.
