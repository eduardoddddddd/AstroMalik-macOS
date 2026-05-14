# Detailed Implementation Plan & Prompts
**Proyecto:** AstroMalik-macOS
**Objetivo:** Estructurar el desarrollo de las nuevas características astrológicas en 4 fases incrementales, proporcionando un *prompt* detallado y listo para usar en un LLM (como Gemini, Claude o GPT) para cada fase.

---

## Fase 1: Señores del Tiempo (Profecciones Anuales) y Estrellas Fijas Mayores
**Nivel de Complejidad:** Bajo / Fruta Madura
**Objetivo:** Añadir las Profecciones Anuales (pura matemática) y conjunciones a Estrellas Fijas mayores (requiere CSwissEph).

### Prompt para el LLM (Fase 1)

```text
Actúa como un desarrollador experto en Swift 6, SwiftUI y Astrología Tradicional. 
Estamos trabajando en `AstroMalik-macOS`, una app local con arquitectura de ventana única, que usa un wrapper en C llamado `CSwissEph` sobre Swiss Ephemeris.

Objetivo: Implementar dos nuevas funcionalidades (Fase 1):
1. **Profecciones Anuales:**
   - Regla astrológica: Avanzar el Ascendente 1 signo (30°) por cada año de vida cumplido.
   - Crea un `ProfectionEngine.swift` que reciba la carta natal y la fecha actual. Calcula el Signo Profectado, el Señor del Año (regente tradicional del signo) y la casa natal activada. No requiere llamar a Swiss Ephemeris, es matemática basada en la edad.
2. **Estrellas Fijas Mayores:**
   - Regla astrológica: Detectar conjunciones partiles (orbe <= 1.5°) entre planetas natales/ángulos y las estrellas Behenias principales (Aldebaran, Regulus, Spica, Algol, Sirius).
   - Usa la función `swe_fixstar2_ut()` de `CSwissEph`. Crea un `FixedStarEngine.swift`.
3. **UI (SwiftUI):**
   - Para las profecciones, diseña una vista de "Tarjeta del Señor del Año" (Señor, Signo, Casa natal activada).
   - Para las estrellas, añade una pequeña etiqueta indicadora (como un badge) junto al planeta en la lista de posiciones natales.

Proporciona el código completo de los Engines (`ProfectionEngine.swift`, `FixedStarEngine.swift`), las estructuras de datos necesarias, y los fragmentos de SwiftUI para integrarlo limpiamente en nuestra UI existente. Mantén el código libre de force unwraps (`!`) y seguro para concurrencia estricta en Swift 6.
```

---

## Fase 2: Ampliación Relacional y Moderna (Carta Compuesta y Progresiones Secundarias)
**Nivel de Complejidad:** Medio
**Objetivo:** Implementar la Carta Compuesta (promedio de dos cartas) y Progresiones Secundarias (1 día = 1 año).

### Prompt para el LLM (Fase 2)

```text
Actúa como un desarrollador experto en Swift 6 y SwiftUI para la app `AstroMalik-macOS`.
El proyecto usa Swiss Ephemeris (`CSwissEph`).

Objetivo: Implementar la Fase 2 de funcionalidades astrológicas:
1. **Carta Compuesta (Composite Chart):**
   - Regla astrológica: El punto medio exacto por el arco más corto entre las longitudes eclípticas de los planetas de la Persona A y la Persona B. Si la distancia es > 180°, ajusta por el lado corto. Los Nodos deben forzarse al eje exacto.
   - Crea un `CompositeEngine.swift` que reciba dos objetos con posiciones planetarias natales y devuelva un set de posiciones sintético.
2. **Progresiones Secundarias:**
   - Regla astrológica: 1 día efeméride tras el nacimiento equivale a 1 año de vida tropical.
   - Crea un `SecondaryProgressionEngine.swift`. Recibe la carta natal y la fecha objetivo. Debe sumar la edad de la persona en días al Julian Day (JD) Natal, y ejecutar el cálculo (`swe_calc_ut`) para obtener las posiciones progresadas en ese nuevo JD.
   - Importante: Detectar si un planeta personal (Mercurio, Venus, Marte) ha cambiado de dirección (Rx a Directo o viceversa) por progresión respecto a la natal.
3. **UI (SwiftUI):**
   - Para la Carta Compuesta, describe cómo adaptar la actual vista de Sinastría para añadir un selector en la cabecera `[ A -> B | B -> A | Compuesta ]`, mostrando una carta de rueda simple para la Compuesta.
   - Para las progresiones, detalla cómo reutilizar una rueda doble (Natal dentro, Progresada fuera) y crear una tabla de aspectos partiles (orbe <= 1°) entre progresados y natales.

Genera el código de los Engines y la adaptación de las vistas en SwiftUI. Asegúrate de estructurarlo modularmente y de que sea compatible con Swift 6 Concurrency.
```

---

## Fase 3: Astrología Medieval Profunda (Almuten Figuris y Lunación Prenatal)
**Nivel de Complejidad:** Alto (Algorítmica heurística)
**Objetivo:** Implementar el cálculo del Señor de la Genitura según la tradición medieval, buscando hacia atrás la Sizigia.

### Prompt para el LLM (Fase 3)

```text
Actúa como un desarrollador experto en Swift 6 y astrología medieval (algoritmos de Ibn Ezra / Omar de Tiberíades) para la app macOS local `AstroMalik-macOS`. 

Objetivo: Implementar el módulo `MedievalEngine.swift` (Fase 3).
Tareas:
1. **Búsqueda de Sizigia (Lunación Prenatal):**
   - Crea una función que itere hacia atrás desde el Julian Day (JD) natal usando la librería `CSwissEph` (Swiss Ephemeris) para encontrar el instante exacto previo donde la distancia longitudinal Sol-Luna fue ~0° (Luna Nueva) o ~180° (Luna Llena).
2. **Cálculo del Almuten Figuris:**
   - Los candidatos son los regentes tradicionales del: Sol, Luna, Ascendente, Parte de la Fortuna y la Sizigia.
   - Implementa un sistema de puntuación base:
     - Esenciales: Domicilio: +5, Exaltación: +4, Triplicidad (respeta la secta diurna/nocturna): +3, Término: +2, Decanato: +1.
     - Accidentales: Añadir bonus por Angularidad (+12 Casa 1/10/7/4), Sucedente (+6), Cadente (+3).
     - Restar puntos por Combustión (distancia al Sol < 8.5°).
   - El planeta que suma más puntos totales se devuelve como Almuten Figuris (Señor de la Genitura).
3. **UI (SwiftUI):**
   - Diseña una "Tarjeta del Señor de la Genitura" para integrarse en la Lectura Guiada Natal. Debe mostrar al planeta ganador, su puntuación total y una pequeña tabla de desglose de sus puntos.

Genera el algoritmo en Swift 6, garantizando limpieza en los bucles, rendimiento al buscar la sizigia y seguridad de memoria al usar la librería C.
```

---

## Fase 4: Astrolocalidad (Astrocartografía con MapKit)
**Nivel de Complejidad:** Muy Alto (Matemática esférica y UI de Mapas)
**Objetivo:** Trazar las líneas planetarias de ángulos sobre el mapamundi.

### Prompt para el LLM (Fase 4)

```text
Actúa como un desarrollador experto en Swift 6, SwiftUI y trigonometría esférica aplicada a astronomía para `AstroMalik-macOS`.

Objetivo: Implementar el módulo de Astrocartografía (Fase 4) usando `MapKit`.
Tareas:
1. **Cálculo Esférico (`AstrocartographyEngine.swift`):**
   - Dado el Julian Day (JD) Natal constante, calcula las rutas geográficas (latitud, longitud) donde cada planeta estaba cruzando los 4 ángulos (Ascendente, Descendente, Medio Cielo, Fondo del Cielo).
   - Línea MC: Puntos donde la Longitud Geográfica Terrestre + Tiempo Sidéreo de Greenwich equivale a la Ascensión Recta del Planeta.
   - Línea ASC: Puntos donde el planeta corta el horizonte Este (requiere resolver un triángulo esférico usando la declinación del planeta y la latitud).
   - La función debe devolver arrays de coordenadas `CLLocationCoordinate2D` mapeando las líneas completas por la Tierra.
2. **Integración con MapKit (`AstroMapView.swift`):**
   - Usa la API nativa de `Map` de SwiftUI para macOS 14+.
   - Dibuja estas rutas como superposiciones de polilíneas (`MapPolyline` o equivalente).
   - Codificación visual: Amarillo para Sol, Azul para Júpiter, etc. Trazos sólidos para las líneas del meridiano (MC/IC), punteados para el horizonte (ASC/DSC).
   - Manejo de bordes: Gestiona matemáticamente el salto del antimeridiano (180° a -180°) rompiendo la línea en dos segmentos para que el renderizador del mapa no dibuje una recta cruzando toda la pantalla horizontalmente.
   
Proporciona el algoritmo trigonométrico en Swift y la implementación de la vista del mapa lista para incrustarse como una nueva pestaña en la aplicación.
```
