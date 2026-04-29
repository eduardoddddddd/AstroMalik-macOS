# Prompt para mejorar la vista de Tránsitos en AstroMalik-macOS

Quiero mejorar la representación visual y el filtrado de las métricas nuevas de Tránsitos en AstroMalik-macOS. El cálculo de técnica, relevancia personal, impacto temporal y prioridad ya existe, pero la UI actual no comunica bien qué debo mirar primero.

## Contexto del código

Archivos principales:

- `Sources/AstroMalik/Engine/TransitEngine.swift`
- `Sources/AstroMalik/Models/Transit.swift`
- `Sources/AstroMalik/Views/TransitsView.swift`
- `Sources/AstroMalik/Views/TransitTimelineView.swift`
- `Sources/AstroMalik/Models/NatalChart.swift`

Estado actual:

- La tabla muestra cuatro columnas: `Técnica`, `Personal`, `Impacto` y `Prioridad`.
- El filtro superior dice `Prioridad: 1★`.
- El filtro ya parece filtrar por `priorityStars`.
- El problema es que visualmente no queda claro qué significa cada cosa.
- Además, muchos eventos acaban con 5 estrellas de prioridad porque `priorityScore = score * personalRelevance * temporalImpact` usa umbrales parecidos al score técnico original.
- Resultado: la vista muestra demasiados tránsitos y no responde bien a la pregunta práctica: "qué debo mirar primero".

## Objetivo UX

La pestaña de Tránsitos debe funcionar como una herramienta de foco astrológico personal.

Debe responder al instante:

- qué tránsitos son prioritarios ahora;
- por qué son prioritarios;
- cuándo están activos;
- y qué explicación técnica hay detrás si abro el detalle.

La jerarquía visual debe ser:

1. `Prioridad`: señal principal, visible en tabla y timeline.
2. `Motivo`: resumen breve de por qué sube o baja.
3. `Técnica`, `Personal` e `Impacto`: explicación secundaria, visible sobre todo en el detalle.

No quiero que `Técnica`, `Personal`, `Impacto` y `Prioridad` aparezcan como cuatro columnas equivalentes compitiendo entre sí.

## Cambio principal de tabla

Cambiar la tabla principal para que tenga estas columnas:

- `Tránsito`
- `Prioridad`
- `Motivo`
- `Periodo`
- `Orbe`
- `Texto`

Eliminar de la tabla principal las columnas separadas:

- `Técnica`
- `Personal`
- `Impacto`

Esas métricas deben seguir existiendo, pero deben quedar como desglose en el detalle del tránsito.

## Columna Prioridad

La columna `Prioridad` debe mostrar una señal clara:

Ejemplo:

```text
★★★★★ Crítica
81.2
```

O en una sola línea si queda mejor:

```text
★★★★★ Crítica · 81.2
```

Etiquetas posibles:

- `Crítica`
- `Alta`
- `Media`
- `Baja`

La prioridad debe ser la métrica principal de lectura.

## Columna Motivo

La columna `Motivo` debe resumir los factores más importantes en una línea.

Ejemplos:

```text
Personal alta · Impacto largo · Orbe exacto
Toca Ascendente · Casa angular · Duración larga
Técnica alta · Personal baja · Fondo generacional
Toca Sol/Luna · Tres pasadas · Cluster cercano
```

Debe usar `metricReasons` si ya existe, pero resumido. No mostrar una lista larga en la tabla.

Crear helper en `TransitEvent` o en la vista, por ejemplo:

```swift
var compactReason: String
```

Regla sugerida:

- tomar máximo 2 o 3 motivos;
- priorizar motivos personales sobre motivos puramente técnicos;
- si no hay motivos, mostrar algo como `Sin énfasis personal claro`.

Prioridad de motivos:

1. `Toca Ascendente`
2. `Toca Medio Cielo`
3. `Toca Sol/Luna`
4. `Regente del Ascendente`
5. `Planeta natal angular`
6. `Tránsito por casa angular`
7. `Tres pasadas por retrogradación`
8. `Dos pasadas por retrogradación`
9. `Cluster de tránsitos al mismo punto`
10. `Duración larga`
11. `Duración muy larga`
12. `Orbe exacto menor de 0.25°`
13. `Orbe exacto menor de 0.5°`
14. `Orbe exacto menor de 1°`

## Problema de saturación de estrellas

No usar solo los umbrales antiguos de `starsForScore` para `priorityStars`, porque se satura demasiado.

Añadir una clasificación nueva:

```swift
enum TransitPriorityBand: String, Codable, Hashable {
    case low
    case medium
    case high
    case critical
}
```

Añadir a `TransitEvent`:

```swift
var priorityBand: TransitPriorityBand
```

Y si hace falta:

```swift
var priorityLabel: String
```

Con labels:

```swift
low      -> "Baja"
medium   -> "Media"
high     -> "Alta"
critical -> "Crítica"
```

## Cómo calcular priorityBand

Calcular `priorityBand` después de tener todos los eventos y sus `priorityScore`.

Usar una mezcla de percentil relativo y umbral absoluto.

Propuesta:

1. Ordenar todos los eventos por `priorityScore` descendente.
2. Calcular posición porcentual dentro del conjunto.
3. Asignar bandas así:

```text
Top 10%  + priorityScore >= 35 -> critical
Top 25%  + priorityScore >= 22 -> high
Top 50%  + priorityScore >= 12 -> medium
Resto                         -> low
```

Si un evento está en top 10% pero no llega a `35`, que sea `high` o `medium`, no `critical`.

Si está en top 25% pero no llega a `22`, que sea `medium`.

El objetivo es evitar que un periodo flojo marque cosas como críticas, y también evitar que un periodo muy cargado muestre 80 cosas como 5 estrellas.

## Estrellas de prioridad

Hacer que las estrellas de prioridad dependan de la banda, no directamente del score técnico.

```swift
private func priorityStars(for band: TransitPriorityBand) -> Int {
    switch band {
    case .critical: return 5
    case .high: return 4
    case .medium: return 3
    case .low: return 2
    }
}
```

Si se quiere usar 1 estrella, reservarla para eventos muy bajos, pero no es imprescindible.

## Filtro superior

Sustituir el filtro actual `Prioridad: 1★` por un filtro más claro:

Label:

```text
Mostrar
```

Opciones:

```text
Foco
Importantes
Todos
Técnicos
```

Por defecto debe abrir en:

```text
Foco
```

Implementación sugerida en `TransitWorkspaceState`:

```swift
enum TransitFocusFilter: String, CaseIterable, Identifiable {
    case focus
    case important
    case all
    case technical

    var id: String { rawValue }

    var label: String {
        switch self {
        case .focus: return "Foco"
        case .important: return "Importantes"
        case .all: return "Todos"
        case .technical: return "Técnicos"
        }
    }
}
```

Añadir:

```swift
@Published var focusFilter: TransitFocusFilter = .focus
```

La lógica de filtrado:

```swift
private var filtered: [TransitEvent] {
    switch state.focusFilter {
    case .focus:
        return state.events.filter {
            $0.priorityBand == .critical || $0.priorityBand == .high
        }
    case .important:
        return state.events.filter {
            $0.priorityBand == .critical ||
            $0.priorityBand == .high ||
            $0.priorityBand == .medium
        }
    case .all:
        return state.events
    case .technical:
        return state.events.filter {
            $0.technicalStars >= 4
        }
    }
}
```

Texto de ayuda del filtro:

```text
Foco muestra solo los tránsitos prioritarios por combinación de técnica, relevancia personal e impacto temporal.
```

## Ordenación

La tabla debe ordenarse por defecto así:

1. `priorityBand` descendente: crítica, alta, media, baja.
2. `priorityScore` descendente.
3. `exactDate` ascendente.
4. `minOrb` ascendente.

La timeline también debe usar esta prioridad en modo `Foco`.

## Timeline

La timeline debe mostrar una sola señal principal: prioridad.

En la etiqueta de cada fila:

```text
Plutón Cuadratura Marte
★★★★★ Crítica
```

No mostrar técnica/personal/impacto en la timeline salvo en tooltip.

Tooltip sugerido:

```text
Prioridad Crítica · Técnica 5★ · Personal 4★ · Impacto 4★
```

En modo `Foco`, la timeline debe mostrar solo `critical` y `high`.

En modo `Todos`, puede mostrar todo.

## Colores

Separar colores de aspecto y colores de prioridad.

El color del aspecto se mantiene en:

- el punto de color;
- las barras de timeline.

Colores de aspecto actuales:

- conjunción: naranja
- cuadratura: rojo
- oposición: morado
- trígono: verde
- sextil: azul

Las estrellas/badge de prioridad usan color de prioridad:

- `Crítica`: naranja
- `Alta`: azul
- `Media`: verde
- `Baja`: gris/secundario

No mezclar color de aspecto con color de prioridad en las mismas estrellas.

## Detail sheet

El detalle debe conservar toda la información.

Estructura sugerida:

1. Título del tránsito.
2. Bloque `Por qué importa`.
3. Bloque `Métricas`.
4. Bloque `Interpretación`.

### Por qué importa

Mostrar `metricReasons` como chips o lista breve.

Ejemplo:

```text
Toca Sol/Luna
Planeta natal angular
Duración larga
Orbe exacto menor de 1°
```

### Métricas

Mostrar:

```text
Prioridad: ★★★★★ Crítica · 81.2
Técnica: ★★★★★ · 42.7
Personal: ★★★★☆ · x1.55
Impacto: ★★★★☆ · x1.22
```

Y una explicación corta:

```text
Técnica mide planeta transitante, aspecto y orbe.
Personal mide cuánto toca esta carta natal concreta.
Impacto mide duración, repetición, exactitud y acumulación temporal.
```

No poner esta explicación visible en la pantalla principal; solo en detalle o tooltip.

## Nombres visibles

Usar lenguaje claro:

- `Prioridad`: qué mirar primero.
- `Técnica`: fuerza abstracta del tránsito.
- `Personal`: cuánto toca mi carta.
- `Impacto`: cuánto insiste en el tiempo.
- `Foco`: selección práctica de lo más importante.

## Criterio de éxito

Después de recalcular un periodo de seis meses:

- El modo `Foco` no debe mostrar 224 tránsitos.
- Debería mostrar una selección manejable, idealmente 10-40 según el periodo.
- El modo `Todos` sí debe mostrar todos.
- `Técnicos` debe servir para ver tránsitos potentes aunque no sean tan personales.
- La tabla debe leerse de izquierda a derecha como:

```text
qué es -> cuánto importa -> por qué -> cuándo -> con qué orbe
```

Ejemplo ideal de fila:

```text
Plutón Cuadratura Marte | ★★★★★ Crítica · 81.2 | Personal alta · Impacto largo · Orbe exacto | 2026-04-29 → 2026-10-29 | 1.1°
```

## Importante

No rehacer todo el motor astrológico.

Mantener los cálculos actuales de:

- `technicalScore`
- `technicalStars`
- `personalRelevance`
- `personalRelevanceStars`
- `temporalImpact`
- `temporalImpactStars`
- `priorityScore`
- `metricReasons`

Solo ajustar:

- `priorityBand`
- `priorityStars`
- filtrado
- ordenación
- representación visual
- detalle

Ejecutar `swift test` al final.
