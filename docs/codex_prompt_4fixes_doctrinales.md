# Codex Prompt: 4 correcciones doctrinales prioritarias

## Contexto del proyecto

AstroMalik-macOS es una app nativa de astrología en Swift/SwiftUI que usa Swiss Ephemeris (target SPM `CSwissEph`). Los motores de cálculo están en `Sources/AstroMalik/Engine/`. El proyecto usa `scripts/package_app.sh` para generar la app empaquetada. No uses editores interactivos (vim/nano); haz commits con `git commit -m`. Después de los cambios, ejecuta `scripts/package_app.sh` y verifica que `AstroMalik.app/Contents/MacOS/AstroMalik` tenga timestamp actualizado.

## Tareas (4 fixes, en este orden)

---

### Fix 1: Bug de exilio para planetas de dos domicilios

**Archivo:** `Sources/AstroMalik/Engine/EssentialDignityEngine.swift`

**Problema:** En la función `dignities(planet:longitude:)` (línea ~49), el exilio se detecta con `detrimentSign(of: planet)`, que devuelve `nil` para planetas con dos domicilios (Mercurio, Venus, Marte, Júpiter, Saturno). Esto hace que estos planetas NUNCA aparezcan como en exilio.

**Solución:** Ya existe una función privada `isInDetriment(planet:sign:)` (línea ~160) que cubre correctamente todos los casos incluyendo los planetas de dos domicilios. Reemplazar la lógica de exilio en `dignities()`:

```swift
// ANTES (buggy):
if detrimentSign(of: planet) == sign {
    results.append(.init(dignity: .detriment, score: -5, ruler: nil))
}

// DESPUÉS (correcto):
if isInDetriment(planet: planet, sign: sign) {
    results.append(.init(dignity: .detriment, score: -5, ruler: nil))
}
```

Además, `isInDetriment` es actualmente `private`. Cambiar su visibilidad a `static` (sin private) para que sea accesible dentro del enum. Verificar que siga compilando.

**Validación:** Un Mercurio a 15° Sagitario (sign index 8) debería devolver `.detriment` con score -5. Antes de este fix, devolvía `.peregrine`.

---

### Fix 2: Filtrar triplicidad por secta (diurna/nocturna)

**Archivo:** `Sources/AstroMalik/Engine/EssentialDignityEngine.swift`

**Problema:** La función `triplicityRuler(sign:planet:)` (línea ~193) devuelve el planeta como regente de triplicidad si está en CUALQUIERA de los tres regentes (diurno, nocturno, cooperante). Doctrinalmente (Doroteo/Lilly), solo el regente correspondiente a la secta tiene dignidad de triplicidad.

**Solución:**

1. Añadir un parámetro `isDiurnal: Bool` a `triplicityRuler`:

```swift
private static func triplicityRuler(sign: Int, planet: String, isDiurnal: Bool) -> String? {
    let triplRulers: [String]
    switch sign {
    case 0, 4, 8:   triplRulers = ["SOL", "JUPITER", "SATURNO"]         // Fuego
    case 1, 5, 9:   triplRulers = ["VENUS", "LUNA", "MARTE"]            // Tierra
    case 2, 6, 10:  triplRulers = ["SATURNO", "MERCURIO", "JUPITER"]    // Aire
    case 3, 7, 11:  triplRulers = ["VENUS", "MARTE", "LUNA"]            // Agua
    default: triplRulers = []
    }
    // Index 0 = diurno, 1 = nocturno, 2 = cooperante (siempre cuenta)
    guard !triplRulers.isEmpty else { return nil }
    let validRulers: [String]
    if isDiurnal {
        validRulers = [triplRulers[0], triplRulers[2]] // diurno + cooperante
    } else {
        validRulers = [triplRulers[1], triplRulers[2]] // nocturno + cooperante
    }
    return validRulers.contains(planet) ? planet : nil
}
```

2. Actualizar la función `dignities(planet:longitude:)` para aceptar un parámetro `isDiurnal: Bool = true` (con valor por defecto para no romper callers existentes):

```swift
static func dignities(planet: String, longitude: Double, isDiurnal: Bool = true) -> [EssentialDignityScore] {
```

3. Pasar `isDiurnal` al llamar a `triplicityRuler`:
```swift
if let triRuler = triplicityRuler(sign: sign, planet: planet, isDiurnal: isDiurnal) {
```

4. Hacer lo mismo para `primaryDignity` y `description`:
```swift
static func primaryDignity(planet: String, longitude: Double, isDiurnal: Bool = true) -> EssentialDignityScore {
    dignities(planet: planet, longitude: longitude, isDiurnal: isDiurnal).first ?? ...
}
static func description(planet: String, longitude: Double, isDiurnal: Bool = true) -> String {
    let d = primaryDignity(planet: planet, longitude: longitude, isDiurnal: isDiurnal)
    ...
}
```

5. Buscar todos los callers de `dignities`, `primaryDignity` y `description` en el proyecto. Si alguno tiene contexto de secta (como en `HoraryNativeEngine.swift` que ya calcula `sect`), pasar el parámetro real. Los que no tengan contexto pueden usar el valor por defecto.

**Validación:** Sol a 5° Aries (fuego, carta diurna) → triplicidad = SOL ✓. Sol a 5° Aries (carta nocturna) → triplicidad = nil (porque el regente nocturno de fuego es Júpiter, no Sol).

---

### Fix 3: Nodos lunares en la carta natal

**Archivos:** `Sources/AstroMalik/Engine/AstroEngine.swift`, posiblemente `NatalChartView.swift`, `GuidedReadingView.swift`, `NatalWheelView.swift`

**Problema:** Los nodos lunares se calculan en `TransitEngine.swift` para tránsitos, pero no aparecen como cuerpos en la carta natal (`PLANET_LIST` no los incluye, `computeNatalChart` no los calcula).

**Solución:**

1. En `AstroEngine.swift`, añadir una función para calcular los nodos que sea reutilizable (actualmente solo existe en TransitEngine como función privada libre):

```swift
// En AstroEngine, dentro del enum/class:
static func calcLunarNodes(jd: Double) throws -> (north: RawPlanet, south: RawPlanet) {
    var xx = [Double](repeating: 0, count: 6)
    var serr = [CChar](repeating: 0, count: 256)
    let rc = swe_calc_ut(jd, SE_TRUE_NODE, SEFLG_SPEED, &xx, &serr)
    if rc < 0 {
        let err = String(cString: serr)
        throw AstroError.calcFailed("NODO_NORTE", err)
    }
    let northLon = xx[0].truncatingRemainder(dividingBy: 360)
    var southLon = (northLon + 180).truncatingRemainder(dividingBy: 360)
    if southLon < 0 { southLon += 360 }
    let retro = xx[3] < 0
    return (
        north: RawPlanet(key: "NODO_NORTE", label: "☊ Nodo Norte", deg: northLon, speed: xx[3], retro: retro),
        south: RawPlanet(key: "NODO_SUR", label: "☋ Nodo Sur", deg: southLon, speed: xx[3], retro: retro)
    )
}
```

2. En `computeNatalChart(jd:lat:lon:)`, después de calcular los planetas de `PLANET_LIST`, calcular los nodos y añadirlos a `bodies`:

```swift
// Después del bucle de PLANET_LIST:
if let nodes = try? calcLunarNodes(jd: jd) {
    let northHouse = planetHouse(deg: nodes.north.deg, cusps: cusps)
    bodies.append(PlanetBody(
        key: "NODO_NORTE", label: "☊ Nodo Norte",
        longitude: nodes.north.deg,
        formatted: degToSign(nodes.north.deg),
        house: northHouse, retrograde: nodes.north.retro
    ))
    let southHouse = planetHouse(deg: nodes.south.deg, cusps: cusps)
    bodies.append(PlanetBody(
        key: "NODO_SUR", label: "☋ Nodo Sur",
        longitude: nodes.south.deg,
        formatted: degToSign(nodes.south.deg),
        house: southHouse, retrograde: nodes.south.retro
    ))
}
```

3. En `TransitEngine.swift`, la función libre `calcLunarNodes(jd:)` y `calcLunarNodesForNatalChart(_:)` deberían reutilizar `AstroEngine.calcLunarNodes(jd:)` en lugar de duplicar el cálculo. Refactorizar para llamar a `AstroEngine.calcLunarNodes(jd:)`.

4. **NO añadir los nodos a `PLANET_LIST`** — eso cambiaría el cálculo de aspectos natales, que debe seguir incluyendo solo los 10 planetas principales. Los nodos se añaden como cuerpos visibles pero no participan en `computeNatalAspects` por ahora (podrían añadirse en un futuro fix).

5. Los nodos aparecerán automáticamente en `NatalChartView` (la tabla de planetas itera sobre `chart.bodies`) y en `NatalWheelView` (idem). No se necesitan cambios en las vistas, solo verificar que compilan y se muestran correctamente.

**Validación:** Calcular una carta natal y verificar que aparecen "☊ Nodo Norte" y "☋ Nodo Sur" en la tabla de posiciones, con signo, casa y grados correctos. El Nodo Sur debe estar exactamente a 180° del Norte.

---

### Fix 4: Ingresos por casa en tránsitos

**Archivos:** `Sources/AstroMalik/Engine/TransitEngine.swift`, `Sources/AstroMalik/Models/Transit.swift`

**Problema:** Los tránsitos solo detectan aspectos entre planetas transitantes y puntos natales. Cuando Saturno cruza una cúspide natal (ingreso a casa 7, por ejemplo), no se genera ningún evento aunque es uno de los tránsitos más importantes en la práctica.

**Solución:**

1. En `Transit.swift`, crear un nuevo modelo para ingresos:

```swift
struct TransitHouseIngress: Identifiable, Codable, Equatable, Hashable {
    let id: UUID
    var transitKey: String        // "SATURNO"
    var transitLabel: String      // "Saturno"
    var house: Int                // Casa natal ingresada (1-12)
    var date: String              // ISO "2026-03-01"
    var fromHouse: Int            // Casa previa
    var score: Double
    var stars: Int
    
    init(
        id: UUID = UUID(),
        transitKey: String, transitLabel: String,
        house: Int, date: String, fromHouse: Int,
        score: Double, stars: Int
    ) {
        self.id = id
        self.transitKey = transitKey
        self.transitLabel = transitLabel
        self.house = house
        self.date = date
        self.fromHouse = fromHouse
        self.score = score
        self.stars = stars
    }
}
```

2. En `TransitWorkspaceState` (en `Transit.swift`), añadir:
```swift
@Published var houseIngresses: [TransitHouseIngress] = []
```

3. En `TransitEngine.swift`, añadir una función nueva `detectHouseIngresses` que itere día a día, calcule en qué casa natal está cada planeta transitante (solo exteriores: Marte a Plutón) y detecte cuándo cambia de casa:

```swift
func detectHouseIngresses(
    natalChart: NatalChart,
    fromDate: Date,
    toDate: Date,
    excludeMoon: Bool = true
) throws -> [TransitHouseIngress] {
    guard let utc = TimeZone(identifier: "UTC") else { return [] }
    var cal = Calendar(identifier: .gregorian)
    cal.timeZone = utc
    guard let dayDelta = cal.dateComponents([.day], from: fromDate, to: toDate).day else { return [] }
    let totalDays = dayDelta + 1
    guard totalDays <= 3660 else { return [] }
    
    let isoFmt = ISO8601DateFormatter()
    isoFmt.formatOptions = [.withFullDate]
    isoFmt.timeZone = utc
    
    let outerKeys: Set<String> = ["MARTE", "JUPITER", "SATURNO", "URANO", "NEPTUNO", "PLUTON"]
    var previousHouse: [String: Int] = [:]
    var ingresses: [TransitHouseIngress] = []
    
    for dayIdx in 0..<totalDays {
        guard let currentDate = cal.date(byAdding: .day, value: dayIdx, to: fromDate) else { continue }
        let comps = cal.dateComponents([.year, .month, .day], from: currentDate)
        guard let year = comps.year, let month = comps.month, let day = comps.day else { continue }
        let jd = swe_julday(Int32(year), Int32(month), Int32(day), 12.0, SE_GREG_CAL)
        
        let planets = try AstroEngine.calcPlanets(jd: jd)
        for (key, planet) in planets {
            guard outerKeys.contains(key) else { continue }
            let house = AstroEngine.planetHouse(deg: planet.deg, cusps: natalChart.cusps)
            if let prev = previousHouse[key], prev != house {
                let pw = PLANET_WEIGHTS[key] ?? 1.0
                let score = pw * 3.0
                ingresses.append(TransitHouseIngress(
                    transitKey: key,
                    transitLabel: PLANET_NAMES[key] ?? key,
                    house: house,
                    date: isoFmt.string(from: currentDate),
                    fromHouse: prev,
                    score: score,
                    stars: starsForScore(score)
                ))
            }
            previousHouse[key] = house
        }
    }
    return ingresses.sorted { $0.date < $1.date }
}
```

4. En la función `computeTransitPeriod`, al final (o en el caller que invoca `computeTransitPeriod`), llamar también a `detectHouseIngresses` y almacenar el resultado en `TransitWorkspaceState.houseIngresses`.

5. En `TransitsView.swift`, añadir una sección visual para ingresos por casa, debajo de la lista de eventos de aspecto, algo simple como una lista con "Saturno ingresa en Casa 7 — 2026-05-15". Usar un estilo de tarjeta diferenciado (por ejemplo con icono "arrow.right.circle" y color distinto). No hace falta que sea elaborado en esta primera iteración.

**Validación:** Calcular tránsitos para un rango de 6 meses y verificar que aparecen ingresos de planetas lentos por casas natales. Los ingresos de planetas rápidos (Sol, Luna, Mercurio, Venus) se omiten intencionadamente para no saturar.

---

## Instrucciones generales

- Después de todos los cambios, ejecuta `swift build` para verificar compilación.
- Ejecuta `swift test` para verificar que los tests existentes no se rompen.
- Ejecuta `scripts/package_app.sh` para regenerar la app.
- Verifica que `AstroMalik.app/Contents/MacOS/AstroMalik` tenga timestamp actualizado.
- Haz commit con `git commit -m "fix: corregir exilio multi-domicilio, triplicidad por secta, nodos en natal, ingresos por casa en tránsitos"`.
- No uses editores interactivos (vim/nano/emacs).
