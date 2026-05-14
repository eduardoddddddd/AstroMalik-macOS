# Plan de Implementación de Nuevas Técnicas Astrológicas
**Documento Estratégico** | AstroMalik-macOS

Este documento detalla a nivel arquitectónico y de ingeniería cómo se implementarían las técnicas astrológicas identificadas en el `analisis_gemini3.1pro.md`. Siguiendo la filosofía **Local-first**, **Swift Nativo** y **Swiss Ephemeris**.

---

## 1. Profecciones Anuales y Mensuales (Técnica de Señores del Tiempo)

### Concepto Astrológico
Avanzar el Ascendente (u otro punto) a razón de un signo por año de vida. El regente tradicional del signo al que llega la profección se convierte en el "Señor del Año". Es la llave maestra que los astrólogos tradicionales usan antes de leer una Revolución Solar.

### Implementación Técnica (`ProfectionEngine`)
- **Cálculo:** No requiere llamar a Swiss Ephemeris para posiciones planetarias, ya que es un cálculo temporal/matemático sobre la carta natal.
  - `edad_en_años = año_actual - año_nacimiento` (ajustado por el mes y día exacto de nacimiento).
  - `signo_profeccion_anual = (signo_ascendente_natal + edad_en_años) % 12`.
  - **Dignidades:** Se toma el regente tradicional (Marte para Escorpio, Júpiter para Piscis, Saturno para Acuario).
- **Arquitectura en Swift:**
  - Crear el módulo `Sources/AstroMalik/Engine/TimeLords/ProfectionEngine.swift`.
  - Estructuras: `ProfectionRequest` (Carta, Fecha Objetivo), `ProfectionResult` (Signo profectado, Señor del Año, Señor del Mes, Casa natal activada).
- **Integración UI:**
  - Nueva sección visual dentro de la vista de **Revolución Solar** o una pestaña nueva de **Señores del Tiempo**. 
  - UI: Una "tarjeta de periodo" destacando el Señor del Año, su dignidad natal y por qué casa natal transita este año.
- **Corpus / Foundry Local:**
  - Integrar el Señor del Año en el prompt generativo: *"Analiza el año considerando que el Señor del Año es [Planeta] (regente de la casa [X] por profección) transitando por la casa [Y]"*.

---

## 2. Progresiones Secundarias

### Concepto Astrológico
Mide la evolución psicológica interna. La fórmula es: 1 día después del nacimiento en las efemérides equivale a 1 año de vida del nativo.

### Implementación Técnica (`SecondaryProgressionEngine`)
- **Cálculo (Capa CSwissEph):**
  - Convertir la edad exacta del usuario en una fracción de días solares medios (ej: 30.5 años = 30.5 días).
  - `Fecha Progresada JD = Fecha Natal JD + Edad en Días`.
  - Hacer un bucle `swe_calc_ut` para todos los planetas en ese nuevo JD.
- **Detección de Estaciones (Eventos Críticos):**
  - Para detectar si un planeta cambia de Directo a Retrógrado (o viceversa) por progresión, el motor requerirá una búsqueda binaria alrededor del JD progresado observando la velocidad del planeta (cuando `swe_calc_ut` devuelve velocidad cercana a 0.0).
- **Arquitectura:**
  - Crear `Sources/AstroMalik/Engine/Progressions/SecondaryProgressionEngine.swift`.
- **Integración UI:**
  - Reutilizar la visualización de la rueda doble `SynastryChartView`. En el interior la Natal, en el exterior los planetas Progresados.
  - Una tabla destacando solo **aspectos partiles** (orbe < 1°) entre progresados y natales, y cambios de signo/casa.

---

## 3. Astrología de Relaciones: Carta Compuesta (Composite Chart)

### Concepto Astrológico
Una carta "artificial" que representa la relación como una entidad independiente, calculada promediando las posiciones de dos cartas natales (puntos medios).

### Implementación Técnica (`CompositeEngine`)
- **Cálculo:**
  - Calcular el punto medio del arco más corto entre las longitudes de los planetas. 
  - Fórmula base: `Long_Comp_Sol = (Long_Sol_A + Long_Sol_B) / 2`.
  - Si la distancia supera los 180°, se suma o resta 180° para asegurar que cruza por el arco menor.
  - Los Nodos Lunares deben forzarse al eje exacto (180° entre Norte y Sur).
  - **Casas:** Calcular el MC por punto medio, y derivar las cúspides (Composite Derived) o calcular el ASC por su propio punto medio.
- **Arquitectura:**
  - Ampliar el módulo de sinastría: `Sources/AstroMalik/Engine/Synastry/CompositeEngine.swift`.
- **Integración UI:**
  - En la vista actual de Sinastría, añadir un Toggle o Tab: `[ A → B ] [ B → A ] [ Compuesta ]`.
  - La visualización de la Compuesta usa la vista de rueda simple `NatalChartView`, ya que se lee como una carta independiente.

---

## 4. Almuten Figuris y Señor de la Genitura (Astrología Medieval)

### Concepto Astrológico
El planeta más fuerte de toda la carta, que rige la psique y el destino (Almuten Figuris).

### Implementación Técnica (`MedievalEngine`)
- **Cálculo de Sizigia (Lunación Prenatal):**
  - Encontrar si la fase previa fue Luna Nueva o Llena.
  - Bucle hacia atrás desde el JD Natal iterando días hasta que la distancia Sol-Luna sea ~0° o ~180°. Afinar con iteración por horas/minutos para la exactitud.
- **Sistema de Puntuación (Extensión de `EssentialDignityEngine`):**
  - Implementar el algoritmo de Ibn Ezra u Omar de Tiberíades.
  - Asignar pesos a los candidatos (Regentes del Sol, Luna, ASC, Parte Fortuna, Sizigia).
  - Dignidades esenciales: Domicilio (+5), Exaltación (+4), Triplicidad (+3), Término (+2), Decanato (+1).
  - Dignidades accidentales: Casa angular (+12), Sucedente (+6), Cadente (+3), Combustión (-5), Cazimi (+5), etc.
- **Arquitectura:**
  - `Sources/AstroMalik/Engine/Medieval/AlmutenEngine.swift`.
- **Integración UI:**
  - Una sección nueva en la "Lectura Natal Guiada" (debajo del "Regente del Ascendente"), con una tarjeta dorada que indique: **Señor de la Genitura: Júpiter**, con el desglose de sus puntos.

---

## 5. Puntos Medios (Midpoints) y Armónicos

### Concepto Astrológico
El punto exacto entre dos planetas o ángulos, clave en astrología Uraniana/Cosmobiología.

### Implementación Técnica
- **Cálculo:**
  - Para 10 planetas + ASC + MC, hay `12 * 11 / 2 = 66` pares de puntos medios.
  - Se calculan en tiempo de ejecución de la carta natal.
  - Proyección en un **dial de 90°**: `(Longitud % 90)`. Si un tercer planeta cae en el mismo grado del dial (orbe 1°), activa ese punto medio.
- **Arquitectura:**
  - `Sources/AstroMalik/Engine/MidpointEngine.swift`.
- **Integración UI:**
  - Un panel técnico en formato tabla: `Sol/Luna = 15° Aries`. Destacando cruces directos (Ej: `Sol/Luna = Venus`).

---

## 6. Estrellas Fijas

### Concepto Astrológico
Conjunciones partiles (muy cerradas) a estrellas fijas de magnitud importante.

### Implementación Técnica
- **Cálculo (Swiss Ephemeris):**
  - Utilizar `swe_fixstar2_ut()` de la librería C.
  - Pasar los nombres de las estrellas Behenias (ej: `"Aldebaran"`, `"Regulus"`, `"Spica"`, `"Algol"`, `"Sirius"`).
  - Obtener la longitud de la estrella para el JD Natal (su posición cambia un grado cada 72 años por la precesión).
- **Filtro y Match:**
  - Cruzar estas posiciones con los planetas natales y los ángulos. Orbe máximo estricto: 1.5°.
- **Integración UI:**
  - Añadir indicadores sutiles en la Rueda Natal (estrellitas en el anillo zodiacal exterior).
  - En el listado de posiciones planetarias, añadir una pequeña etiqueta roja: `[ Conj. Algol ]`.

---

## 7. Astrocartografía (Astrolocalidad)

### Concepto Astrológico
Proyección de las posiciones planetarias en el globo terráqueo en el momento del nacimiento.

### Implementación Técnica (Fase Avanzada)
- **Cálculo de Líneas:**
  - Requiere trigonometría esférica avanzada. 
  - Línea del Ascendente: Puntos en la Tierra donde, en ese momento JD, el planeta estaba cortando el horizonte este.
  - Línea del Medio Cielo: Puntos donde la Longitud Geográfica Terrestre + Tiempo Sidéreo de Greenwich = Ascensión Recta del Planeta.
- **Integración UI:**
  - Usar **MapKit** de Apple nativo (`MKMapView`).
  - Trazar `MKPolyline` superpuestas en el mapa para el Sol, Luna, Júpiter, Venus, etc.
  - Codificación de color (Amarillo = Sol, Azul = Júpiter) y estilo de trazo (Sólido = Medio Cielo, Discontinuo = Ascendente).

---

## Resumen de Prioridades Sugeridas

Si se planificara ejecutar estas mejoras, el orden lógico para optimizar esfuerzo/impacto en AstroMalik sería:

1. **Sprint 1 (Alto impacto tradicional):** Profecciones Anuales + Estrellas Fijas Mayores. (Se integran a la perfección con la mentalidad de Horaria y Direcciones).
2. **Sprint 2 (Completar módulos base):** Carta Compuesta (Complementa la Sinastría existente sin añadir nueva carga cognitiva pesada).
3. **Sprint 3 (Expansión al paradigma moderno):** Progresiones Secundarias (Reutiliza la lógica de efemérides y vista de doble rueda).
4. **Sprint 4 (Astrología Medieval profunda):** Almuten Figuris y Lunación Prenatal (Calculo intensivo y heurística de puntuación).
5. **Sprint 5 (Visualización Avanzada):** Astrocartografía con MapKit (Proyecto de interfaz complejo).
