# Especificación agnóstica del módulo de Tránsitos de AstroMalik

**Versión:** 1.0  
**Fecha:** 2026-05-03  
**Propósito:** documento profesional para explicar, reproducir y pedir a cualquier modelo de lenguaje la implementación de una pestaña de tránsitos astrológicos equivalente a la de AstroMalik, independientemente del lenguaje de programación, framework UI o plataforma.

---

## 1. Resumen ejecutivo

La pestaña de **Tránsitos** no es una lista plana de aspectos astrológicos. Es una herramienta de foco que responde, en segundos, a cuatro preguntas:

1. **Qué está activo** durante un periodo.
2. **Cuándo se activa** cada tránsito, mediante una línea temporal con scroll y barras diarias de intensidad.
3. **Qué debo mirar primero**, mediante una prioridad calculada.
4. **Por qué importa**, separando fuerza técnica, relevancia personal e impacto temporal.

El diseño actual funciona porque separa cuatro conceptos que suelen mezclarse:

```text
Intensidad diaria      = cercanía diaria al aspecto exacto, usada en la timeline.
Técnica                = fuerza astrológica abstracta: planeta + aspecto + orbe.
Relevancia personal    = cuánto afecta a esta carta natal concreta.
Impacto temporal       = duración, repetición, exactitud y concentración.
Prioridad              = orden práctico de lectura: qué mirar primero.
```

La clave del modelo es que **la prioridad no es solo “planeta lento + orbe pequeño”**. Un tránsito técnicamente potente puede ser poco personal si toca un punto generacional no angular; un tránsito menos espectacular técnicamente puede ser prioritario si toca Sol, Luna, ASC, MC, regente del Ascendente o un planeta natal angular.

---

## 2. Objetivo funcional

Implementar una pantalla/pestaña de tránsitos con estas capacidades:

- Seleccionar una carta natal base.
- Seleccionar rango de fechas `fromDate -> toDate`.
- Opción para excluir la Luna transitante por defecto.
- Calcular tránsitos diarios contra puntos natales.
- Agrupar días consecutivos en eventos astrológicos legibles.
- Dibujar una timeline con scroll horizontal y vertical.
- Ordenar y filtrar eventos por prioridad real.
- Mostrar tabla principal minimalista.
- Mostrar detalle completo al seleccionar un evento.
- Integrar texto interpretativo de un corpus si existe.

La experiencia buscada es:

```text
Abrir Tránsitos -> pulsar Calcular -> ver primero una selección manejable de eventos prioritarios -> abrir detalle si quiero justificar la lectura.
```

---

## 3. Principio de diseño UX

La interfaz debe obedecer esta jerarquía:

1. **Timeline:** cuándo ocurre y cómo sube/baja la intensidad.
2. **Prioridad:** qué mirar primero.
3. **Motivo:** por qué sube en prioridad.
4. **Detalle:** desglose técnico, personal, temporal e interpretación textual.

No mostrar en la pantalla principal cuatro columnas equivalentes compitiendo entre sí (`Técnica`, `Personal`, `Impacto`, `Prioridad`). Eso genera ruido. En la pantalla principal debe dominar **Prioridad**; el resto vive en el detalle o tooltip.

---

## 4. Entradas mínimas del sistema

### 4.1 Carta natal

Una carta natal debe aportar, como mínimo:

```json
{
  "id": "uuid-or-stable-id",
  "name": "Nombre",
  "birthDate": "YYYY-MM-DD",
  "birthTime": "HH:mm",
  "timezone": "Europe/Madrid",
  "bodies": [
    {
      "key": "SOL",
      "label": "Sol",
      "longitude": 123.45,
      "house": 6,
      "retrograde": false
    }
  ],
  "ascendant": { "longitude": 10.0 },
  "mc": { "longitude": 280.0 },
  "cusps": [0.0, 30.0, 60.0, 90.0, 120.0, 150.0, 180.0, 210.0, 240.0, 270.0, 300.0, 330.0]
}
```

Notas:

- `longitude` siempre es zodiacal, en grados `0 <= x < 360`.
- `house` es casa natal `1...12`.
- `cusps` son las cúspides usadas para determinar por qué casa natal transita un planeta.
- ASC y MC se añaden como puntos transitables aunque no formen parte de `bodies`.

### 4.2 Rango de cálculo

```json
{
  "fromDate": "YYYY-MM-DD",
  "toDate": "YYYY-MM-DD",
  "excludeMoon": true
}
```

Reglas:

- `toDate >= fromDate`.
- Rango máximo recomendado: 10 años.
- El cálculo diario usa UTC y toma las posiciones a mediodía UTC para estabilizar el muestreo diario.

---

## 5. Salida principal: evento de tránsito

Cada evento agrupado debe tener este contrato lógico:

```json
{
  "id": "uuid",
  "transitKey": "SATURNO",
  "transitLabel": "Saturno",
  "natalKey": "SOL",
  "natalLabel": "Sol",
  "aspectKey": "OPOSICION",
  "aspectLabel": "Oposicion",
  "color": "#a21caf",
  "fromDate": "2026-01-10",
  "toDate": "2026-02-18",
  "exactDate": "2026-01-29",
  "activeDays": 40,
  "minOrb": 0.32,
  "retrogradeOnExact": false,

  "score": 42.7,
  "stars": 5,
  "technicalScore": 42.7,
  "technicalStars": 5,

  "personalRelevance": 1.70,
  "personalRelevanceStars": 5,

  "temporalImpact": 1.22,
  "temporalImpactStars": 3,

  "priorityScore": 88.6,
  "priorityStars": 5,
  "priorityBand": "critical",

  "metricReasons": [
    "Toca Sol/Luna",
    "Planeta natal angular",
    "Duración larga",
    "Orbe exacto menor de 0.5°"
  ],

  "text": "Interpretación opcional recuperada del corpus.",
  "source": "Fuente opcional",

  "samples": [
    { "date": "2026-01-10", "orb": 2.90, "intensity": 0.033 },
    { "date": "2026-01-29", "orb": 0.32, "intensity": 0.893 }
  ]
}
```

---

## 6. Constantes astrológicas

### 6.1 Planetas/puntos transitantes

El sistema calcula los planetas clásicos y modernos:

```text
SOL, LUNA, MERCURIO, VENUS, MARTE, JUPITER, SATURNO, URANO, NEPTUNO, PLUTON
```

Además calcula nodos lunares verdaderos:

```text
NODO_NORTE, NODO_SUR
```

Para evitar duplicados interpretativos, las conjunciones/oposiciones y cuadraturas nodales se pueden normalizar como:

```text
EJE_NODAL
```

### 6.2 Puntos natales transitables

Comparar tránsitos contra:

```text
Planetas natales de la carta
ASC
MC
NODO_NORTE natal
NODO_SUR natal
```

ASC y MC son obligatorios para una lectura profesional:

```text
ASC -> casa natal 1
MC  -> casa natal 10
```

### 6.3 Aspectos mayores

Usar cinco aspectos:

| Aspecto | Clave | Ángulo |
|---|---:|---:|
| Conjunción | `CONJUNCION` | 0° |
| Sextil | `SEXTIL` | 60° |
| Cuadratura | `CUADRADO` | 90° |
| Trígono | `TRIGONO` | 120° |
| Oposición | `OPOSICION` | 180° |

### 6.4 Orbes específicos de tránsitos

No usar orbes natales amplios para tránsitos. Los tránsitos deben ser más estrictos:

| Aspecto | Orbe normal |
|---|---:|
| Conjunción | 3.0° |
| Oposición | 3.0° |
| Cuadratura | 3.0° |
| Trígono | 2.0° |
| Sextil | 1.5° |

Para nodos transitantes:

| Aspecto | Orbe nodal |
|---|---:|
| Conjunción | 2.0° |
| Oposición | 2.0° |
| Cuadratura | 2.0° |
| Trígono | 1.5° |
| Sextil | 1.0° |

Justificación: reduce ruido y evita que la timeline se llene de aspectos demasiado amplios.

---

## 7. Detección diaria de aspectos

Para cada día del rango:

1. Calcular posiciones transitantes para ese día.
2. Añadir nodos verdaderos transitantes.
3. Recorrer cada planeta/punto transitante.
4. Recorrer cada punto natal transitable.
5. Ignorar el caso `transitKey == natalKey`.
6. Si `excludeMoon == true`, ignorar `LUNA` como transitante.
7. Calcular diferencia angular mínima.
8. Comparar contra cada aspecto mayor.
9. Si el orbe cae dentro del máximo permitido, crear una muestra diaria.

### 7.1 Diferencia angular

```text
raw = abs((a - b + 360) mod 360)
if raw > 180:
    diff = 360 - raw
else:
    diff = raw
```

### 7.2 Orbe del aspecto

```text
orb = abs(diff - aspectAngle)
```

El aspecto existe si:

```text
orb <= maxOrb(transitKey, aspectKey)
```

### 7.3 Intensidad diaria

La timeline usa una intensidad normalizada `0...1`:

```text
intensity = clamp(1 - orb / maxOrb, 0, 1)
```

Esto responde a:

```text
¿Qué tan cerca está este día del exacto dentro del orbe permitido?
```

No confundir con prioridad ni importancia vital absoluta.

---

## 8. Normalización del eje nodal

Los nodos Norte y Sur son opuestos. Sin normalización, el sistema puede duplicar el mismo fenómeno:

```text
Nodo Norte conjunción punto natal
Nodo Sur oposición punto natal
```

Ambos describen el eje nodal tocando el punto. Por eso se fusionan:

| Caso detectado | Evento resultante |
|---|---|
| Nodo Norte conjunción punto | `EJE_NODAL sobre punto` |
| Nodo Sur oposición punto | `EJE_NODAL sobre punto` |
| Nodo Norte oposición punto | `EJE_NODAL sobre punto` |
| Nodo Sur conjunción punto | `EJE_NODAL sobre punto` |
| Nodo Norte cuadratura punto | `EJE_NODAL cuadratura punto` |
| Nodo Sur cuadratura punto | `EJE_NODAL cuadratura punto` |

Regla de deduplicación diaria:

```text
clave = transitKeyNormalizado + aspectKeyNormalizado + natalKey
si aparecen varias muestras con la misma clave en el mismo día, conservar la de menor orbe.
```

Motivo añadido:

```text
Activación del eje nodal
```

---

## 9. Agrupación de muestras en eventos

Una muestra diaria no es todavía un evento. Hay que agrupar días activos del mismo contacto.

### 9.1 Clave base

```text
baseKey = transitKey + ":" + aspectKey + ":" + natalKey
```

Ejemplos:

```text
SATURNO:OPOSICION:SOL
PLUTON:CUADRADO:MARTE
URANO:TRIGONO:MC
EJE_NODAL:CONJUNCION:LUNA
```

### 9.2 Separación máxima

Usar:

```text
EVENT_GAP_DAYS = 5
```

Si una nueva muestra tiene la misma `baseKey` y está a 5 días o menos de la última muestra del evento anterior, se añade al mismo evento. Si supera ese hueco, se crea una nueva pasada del mismo tránsito.

Esto permite separar pasadas por retrogradación cuando hay una interrupción suficientemente grande.

### 9.3 Datos acumulados

Durante la agrupación conservar:

```text
fromDate        = primer día activo
toDate          = último día activo
exactDate       = día con menor orbe
minOrb          = menor orbe encontrado
retrogradeOnExact = estado retrógrado del transitante en exactDate
samples         = lista de muestras diarias
transitHouse    = casa natal por la que transita el planeta en el exacto/mejor muestra
natalHouse      = casa natal del punto tocado
```

---

## 10. Score técnico

La técnica mide fuerza abstracta del tránsito, sin mirar aún si es personal para la carta concreta.

### 10.1 Pesos planetarios

| Transitante | Peso |
|---|---:|
| Plutón | 10 |
| Neptuno | 9 |
| Urano | 8 |
| Saturno | 7 |
| Júpiter | 6 |
| Eje Nodal / Nodo Norte / Nodo Sur | 5 |
| Marte | 4 |
| Venus | 2 |
| Mercurio | 2 |
| Sol | 2 |
| Luna | 1 |

### 10.2 Pesos de aspecto

| Aspecto | Peso |
|---|---:|
| Conjunción | 5.0 |
| Oposición | 4.5 |
| Cuadratura | 4.0 |
| Trígono | 3.0 |
| Sextil | 2.0 |

### 10.3 Fórmula

```text
planetWeight = peso del transitante
aspectWeight = peso del aspecto
maxOrb       = orbe máximo permitido para ese transitante/aspecto
minOrb       = mejor orbe alcanzado por el evento

orbFactor = clamp(1 - minOrb / maxOrb, 0, 1)
technicalScore = planetWeight * aspectWeight * (0.5 + 0.5 * orbFactor)
technicalScore = round(technicalScore, 1)
```

La parte `(0.5 + 0.5 * orbFactor)` garantiza que un aspecto dentro de orbe nunca vale cero: oscila entre `50%` y `100%` del peso base según exactitud.

### 10.4 Estrellas técnicas

```text
technicalScore >= 25 -> 5 estrellas
technicalScore >= 15 -> 4 estrellas
technicalScore >= 8  -> 3 estrellas
technicalScore >= 3  -> 2 estrellas
resto                -> 1 estrella
```

---

## 11. Relevancia personal

La relevancia personal mide cuánto toca esta carta natal concreta.

```text
personalRelevance = 1.0 + bonificaciones
personalRelevance = clamp(personalRelevance, 0.75, 1.85)
```

### 11.1 Bonificaciones por punto natal tocado

| Condición | Bonus | Motivo |
|---|---:|---|
| Toca ASC | +0.45 | `Toca Ascendente` |
| Toca MC | +0.45 | `Toca Medio Cielo` |
| Toca Sol o Luna | +0.40 | `Toca Sol/Luna` |
| Toca regente del Ascendente | +0.35 | `Regente del Ascendente` |
| Toca Venus o Marte | +0.25 | `Planeta personal fuerte` |
| Toca Mercurio | +0.20 | `Planeta personal` |
| Toca Júpiter o Saturno | +0.15 | `Planeta social` |
| Toca Nodo natal no angular | +0.20 | `Toca Nodo natal` |
| Toca Nodo natal angular | +0.35 | `Nodo natal angular` |

No se añade bonus por defecto por tocar Urano, Neptuno o Plutón natales, salvo que ganen relevancia por angularidad u otra condición. Esto evita que los tránsitos a puntos generacionales dominen siempre.

### 11.2 Regente del Ascendente

Usar regencias tradicionales:

| Signo del ASC | Regente |
|---|---|
| Aries | Marte |
| Tauro | Venus |
| Géminis | Mercurio |
| Cáncer | Luna |
| Leo | Sol |
| Virgo | Mercurio |
| Libra | Venus |
| Escorpio | Marte |
| Sagitario | Júpiter |
| Capricornio | Saturno |
| Acuario | Saturno |
| Piscis | Júpiter |

### 11.3 Bonificaciones por casa natal del punto tocado

Si el punto natal no es nodo:

| Casa natal | Bonus | Motivo |
|---|---:|---|
| 1, 4, 7, 10 | +0.30 | `Planeta natal angular` |
| 2, 5, 8, 11 | +0.15 | `Planeta natal sucedente` |
| 3, 6, 9, 12 | +0.05 | `Planeta natal cadente` |

### 11.4 Bonificaciones por casa transitada

Casa natal en la que cae el transitante durante el evento:

| Casa transitada | Bonus | Motivo |
|---|---:|---|
| 1, 4, 7, 10 | +0.20 | `Tránsito por casa angular` |
| 2, 5, 8, 11 | +0.10 | `Tránsito por casa sucedente` |
| 3, 6, 9, 12 | +0.00 | sin motivo |

### 11.5 Estrellas de multiplicador

La relevancia personal no usa estrellas de score, sino estrellas de multiplicador:

```text
multiplier >= 1.65 -> 5 estrellas
multiplier >= 1.40 -> 4 estrellas
multiplier >= 1.15 -> 3 estrellas
multiplier >= 0.95 -> 2 estrellas
resto              -> 1 estrella
```

---

## 12. Impacto temporal

El impacto temporal mide cuánto insiste el tránsito en el tiempo.

```text
temporalImpact = 1.0
temporalImpact *= factorDuracion
temporalImpact *= factorExactitud
temporalImpact *= factorPasadas
temporalImpact *= factorCluster
temporalImpact = clamp(temporalImpact, 0.75, 1.80)
```

### 12.1 Factor por duración

| Días activos | Factor | Motivo |
|---|---:|---|
| `<= 7` | x0.85 | `Tránsito breve` |
| `<= 30` | x0.95 | sin motivo |
| `<= 120` | x1.10 | `Duración sostenida` |
| `<= 365` | x1.22 | `Duración larga` |
| `> 365` | x1.30 | `Duración muy larga` |

### 12.2 Factor por exactitud

| Orbe mínimo | Factor | Motivo |
|---|---:|---|
| `<= 0.25°` | x1.18 | `Orbe exacto menor de 0.25°` |
| `<= 0.50°` | x1.12 | `Orbe exacto menor de 0.5°` |
| `<= 1.00°` | x1.06 | `Orbe exacto menor de 1°` |
| `> 1.00°` | x1.00 | sin motivo |

### 12.3 Factor por pasadas

Contar cuántos eventos existen con la misma clave `transitKey:aspectKey:natalKey` dentro del rango.

| Pasadas | Factor | Motivo |
|---|---:|---|
| 1 | x1.00 | sin motivo |
| 2 | x1.12 | `Dos pasadas por retrogradación` |
| 3 | x1.25 | `Tres pasadas por retrogradación` |
| 4 o más | x1.35 | `Más de tres pasadas por retrogradación` |

### 12.4 Factor por cluster

Contar eventos técnicamente relevantes (`technicalStars >= 3`) que tocan el mismo `natalKey` con fecha exacta a `<= 21 días` del evento actual.

| Cluster | Factor | Motivo |
|---|---:|---|
| 1 | x1.00 | sin motivo |
| 2 | x1.10 | `Dos tránsitos próximos al mismo punto` |
| 3 o más | x1.22 | `Cluster de tránsitos al mismo punto` |

---

## 13. Prioridad

La prioridad es la métrica de lectura principal:

```text
priorityScore = technicalScore * personalRelevance * temporalImpact
```

No se debe interpretar como verdad absoluta, sino como ranking práctico:

```text
¿Qué debería mirar primero en este periodo?
```

### 13.1 Por qué no usar estrellas técnicas para prioridad

`technicalScore` y `priorityScore` no tienen la misma escala, porque `priorityScore` multiplica por relevancia personal e impacto temporal. Si se usan los mismos umbrales de estrellas, se saturan demasiados eventos en 5 estrellas.

La solución es clasificar por **bandas de prioridad**.

### 13.2 Bandas de prioridad

```text
low      -> Baja    -> 2 estrellas
medium   -> Media   -> 3 estrellas
high     -> Alta    -> 4 estrellas
critical -> Crítica -> 5 estrellas
```

### 13.3 Asignación de bandas

Después de calcular todos los `priorityScore`:

1. Ordenar eventos por `priorityScore` descendente.
2. Calcular percentil relativo por posición.
3. Aplicar umbrales relativos y absolutos.

```text
percentile = rank / totalEvents

si percentile < 0.10 y priorityScore >= 35 -> critical
si percentile < 0.25 y priorityScore >= 22 -> high
si percentile < 0.50 y priorityScore >= 12 -> medium
resto                                      -> low
```

Esta mezcla evita dos errores:

- En periodos flojos, no inventa eventos críticos solo porque son “lo mejor del periodo”.
- En periodos saturados, no marca demasiados eventos como críticos.

---

## 14. Motivos y resumen compacto

`metricReasons` conserva todos los motivos relevantes, sin duplicados.

Para tabla y timeline, no mostrar todos. Crear un resumen compacto de máximo 3 motivos.

Orden recomendado de prioridad narrativa:

```text
1. Activación del eje nodal
2. Toca Ascendente
3. Toca Medio Cielo
4. Toca Sol/Luna
5. Regente del Ascendente
6. Nodo natal angular
7. Toca Nodo natal
8. Planeta natal angular
9. Tránsito por casa angular
10. Tres pasadas por retrogradación
11. Dos pasadas por retrogradación
12. Cluster de tránsitos al mismo punto
13. Duración larga
14. Duración muy larga
15. Orbe exacto menor de 0.25°
16. Orbe exacto menor de 0.5°
17. Orbe exacto menor de 1°
```

Reglas:

```text
compactReason = primeros 3 motivos según orden anterior
si no hay motivos: "Sin énfasis personal claro"
```

---

## 15. Filtros de visualización

La pestaña debe abrir por defecto en modo **Foco**.

| Filtro | Regla | Uso |
|---|---|---|
| Foco | `critical OR high` | Lectura principal, manejable |
| Importantes | `critical OR high OR medium` | Ampliar sin ver todo |
| Todos | todos | Auditoría completa |
| Técnicos | `technicalStars >= 4` | Ver potencia técnica aunque sea menos personal |

Etiqueta UI:

```text
Mostrar: Foco | Importantes | Todos | Técnicos
```

Tooltip del filtro:

```text
Foco muestra solo los tránsitos prioritarios por combinación de técnica, relevancia personal e impacto temporal.
```

---

## 16. Ordenación

Orden por defecto en tabla y timeline:

```text
1. priorityBand.rank descendente     critical > high > medium > low
2. priorityScore descendente
3. exactDate ascendente
4. minOrb ascendente
5. transitKey ascendente
```

En el motor, si hace falta un desempate adicional:

```text
technicalScore descendente antes de minOrb
```

---

## 17. Representación visual: layout general

La pantalla se compone de:

```text
┌──────────────────────────────────────────────────────────────┐
│ Barra de controles                                             │
│ Desde [date] -> Hasta [date] | Sin Luna | Mostrar [Foco] | Calcular │
├──────────────────────────────────────────────────────────────┤
│ Timeline con scroll horizontal y vertical                      │
│ - eje temporal                                                  │
│ - filas por tránsito filtrado                                   │
│ - barras diarias de intensidad                                  │
│ - línea vertical del exacto                                     │
├──────────────────────────────────────────────────────────────┤
│ Tabla principal                                                 │
│ Tránsito | Prioridad | Motivo | Periodo | Orbe | Texto          │
└──────────────────────────────────────────────────────────────┘
```

---

## 18. Timeline con scroll

La timeline es una de las piezas más importantes. Debe mostrar **cuándo** se activa cada tránsito.

### 18.1 Geometría conceptual

```text
labelWidth = 190 px aprox.
rowHeight  = 38 px aprox.
plotHeight = 26 px aprox.
```

La anchura por día depende del rango:

```text
si totalDays <= 21  -> minimumDayWidth = 24
si totalDays <= 60  -> minimumDayWidth = 16
si totalDays <= 180 -> minimumDayWidth = 9
si totalDays <= 540 -> minimumDayWidth = 5
si totalDays > 540  -> minimumDayWidth = 3
```

Cálculo:

```text
availablePlotWidth = availableWidth - labelWidth - padding
dayWidth = max(minimumDayWidth, availablePlotWidth / totalDays)
timelineWidth = max(totalDays * dayWidth, availablePlotWidth, 520)
```

Esto permite:

- Periodos cortos: barras anchas y legibles.
- Periodos largos: scroll horizontal en vez de comprimirlo todo hasta ser ilegible.

### 18.2 Eje temporal

Marcas recomendadas:

```text
<= 21 días: marca diaria, mayor cada 7 días
<= 90 días: marca semanal, mayor cada 28 días
<= 540 días: marca mensual
> 540 días: marca trimestral
```

Formato de etiqueta:

```text
Rangos normales: día/mes   -> 3/5
Rangos largos:   mes/año   -> 5/26
```

### 18.3 Fila de evento

Cada fila contiene:

```text
[ etiqueta fija ] [ zona temporal scrollable ]
```

Etiqueta:

```text
• Saturno Oposicion Sol
  ★★★★☆ Alta
```

- El punto `•` usa color del aspecto.
- La prioridad usa color de prioridad.
- La etiqueta no muestra Técnica/Personal/Impacto al mismo nivel.

Tooltip:

```text
Prioridad Alta · Técnica 4★ · Personal 5★ · Impacto 3★
```

### 18.4 Barras diarias

Por cada sample visible:

```text
x = dayOffset * dayWidth
barWidth = max(2, dayWidth - 1)
barHeight = max(2, sample.intensity * plotHeight)
color = aspectColor con opacidad aprox. 0.78
```

La línea de exactitud:

```text
x = exactOffset * dayWidth + dayWidth / 2
width = 1 px
height = plotHeight + 6
color = texto principal con opacidad aprox. 0.75
```

### 18.5 Colores de aspecto

| Aspecto | Color |
|---|---|
| Conjunción | `#d97706` naranja |
| Sextil | `#2563eb` azul |
| Cuadratura | `#dc2626` rojo |
| Trígono | `#15803d` verde |
| Oposición | `#a21caf` morado |

Usar color de aspecto solo para:

- punto de la fila;
- barras de intensidad;
- identificación visual del tipo de aspecto.

---

## 19. Tabla principal

Columnas recomendadas:

```text
Tránsito | Prioridad | Motivo | Periodo | Orbe | Texto
```

### 19.1 Columna Tránsito

Contenido:

```text
[punto color aspecto] Transitante + Aspecto + Punto natal [+ ℞ si retrógrado en exacto]
```

Ejemplo:

```text
● Saturno Oposicion Sol ℞
```

### 19.2 Columna Prioridad

Ejemplo de dos líneas:

```text
★★★★★ Crítica
88.6
```

O una línea si la plataforma lo prefiere:

```text
★★★★★ Crítica · 88.6
```

Color por prioridad:

| Banda | Color |
|---|---|
| Crítica | naranja `#d97706` |
| Alta | azul `#2563eb` |
| Media | verde `#15803d` |
| Baja | gris/secundario |

### 19.3 Columna Motivo

Mostrar `compactReason`, una línea truncable.

Ejemplos:

```text
Toca Sol/Luna · Planeta natal angular · Orbe exacto menor de 0.5°
Toca Ascendente · Tránsito por casa angular · Duración larga
Activación del eje nodal · Toca Nodo natal · Cluster de tránsitos al mismo punto
Sin énfasis personal claro
```

### 19.4 Columna Periodo

```text
YYYY-MM-DD -> YYYY-MM-DD
```

Usar fuente monoespaciada si existe.

### 19.5 Columna Orbe

```text
0.3°
```

En tabla, una decimal es suficiente. En detalle, dos decimales.

### 19.6 Columna Texto

Icono o indicador si existe interpretación de corpus:

```text
[text-align-left icon] si text != null
```

---

## 20. Detalle del tránsito

Al seleccionar una fila o clickar la timeline, abrir un modal/panel de detalle.

Estructura:

```text
Título
Activo / Orbe exacto
Por qué importa
Métricas
Interpretación
Fuente
```

### 20.1 Título

```text
[punto color aspecto] Saturno Oposicion Sol [℞]
```

### 20.2 Meta

```text
Activo: 2026-01-10 -> 2026-02-18
Orbe exacto: 0.32°
```

### 20.3 Por qué importa

Mostrar `metricReasons` como chips:

```text
[Toca Sol/Luna] [Planeta natal angular] [Duración larga] [Orbe exacto menor de 0.5°]
```

Si vacío:

```text
Sin énfasis personal claro
```

### 20.4 Métricas

```text
Prioridad: ★★★★★ Crítica · 88.6
Técnica:   ★★★★★ · 42.7
Personal:  ★★★★★ · x1.70
Impacto:   ★★★☆☆ · x1.22
```

Explicación corta:

```text
Técnica mide planeta transitante, aspecto y orbe. Personal mide cuánto toca esta carta natal concreta. Impacto mide duración, repetición, exactitud y acumulación temporal.
```

### 20.5 Interpretación

Si hay corpus:

```text
[texto interpretativo]
Fuente: [source]
```

Si no hay corpus:

```text
Sin interpretación disponible en el corpus.
```

---

## 21. Algoritmo completo en pseudocódigo

```pseudo
function computeTransitPeriod(natalChart, fromDate, toDate, excludeMoon, corpusStore):
    assert toDate >= fromDate
    assert daysBetween(fromDate, toDate) + 1 <= 3660

    calendar = UTC Gregorian
    natalPoints = map natalChart.bodies by key
    natalPoints["ASC"] = point(natalChart.ascendant.longitude, label="Ascendente")
    natalPoints["MC"]  = point(natalChart.mc.longitude, label="Medio Cielo")

    natalNodes = calculateTrueNodes(natalChart.birthDate, natalChart.birthTime, natalChart.timezone)
    natalPoints["NODO_NORTE"] = natalNodes.north
    natalPoints["NODO_SUR"]   = natalNodes.south

    natalHouses = houses for natal bodies
    natalHouses["ASC"] = 1
    natalHouses["MC"]  = 10
    natalHouses["NODO_NORTE"] = houseOf(natalNodes.north.longitude, natalChart.cusps)
    natalHouses["NODO_SUR"]   = houseOf(natalNodes.south.longitude, natalChart.cusps)

    accumulators = {}
    lastEventKeyByBase = {}
    sequenceByBase = {}

    for each date in dateRange(fromDate, toDate):
        transitPlanets = calculateTransitPlanets(date at 12:00 UTC)
        transitNodes = calculateTrueNodes(date at 12:00 UTC)
        transitPlanets["NODO_NORTE"] = transitNodes.north
        transitPlanets["NODO_SUR"] = transitNodes.south

        aspects = findTransitAspects(natalPoints, transitPlanets)

        for aspect in aspects:
            if excludeMoon and aspect.transitKey == "LUNA":
                continue
            if aspect.transitKey == aspect.natalKey:
                continue

            transitHouse = houseOf(transit longitude, natalChart.cusps)
            baseKey = aspect.transitKey + ":" + aspect.aspectKey + ":" + aspect.natalKey

            sample = {
                date: iso(date),
                orb: round(aspect.orb, 2),
                intensity: round(intensityFor(aspect), 3)
            }

            if exists previous event for baseKey and daysBetween(previous.lastDate, date) <= EVENT_GAP_DAYS:
                append sample
                update toDate and lastDate
                if aspect.orb < minOrb:
                    update minOrb, exactDate, retrogradeOnExact, transitHouse
            else:
                create new accumulator for baseKey, with suffix if repeated pass
                store first sample

    events = []

    for each accumulator:
        activeDays = daysBetween(fromDate, toDate) + 1
        technicalScore = buildTechnicalScore(transitKey, aspectKey, minOrb)
        technicalStars = starsForScore(technicalScore)
        personal = buildPersonalRelevance(natalChart, natalKey, natalHouse, transitHouse)
        text, source = corpusStore.lookupTransit(transitKey, natalKey, aspectKey)

        event = TransitEvent(
            technicalScore=technicalScore,
            technicalStars=technicalStars,
            personalRelevance=personal.multiplier,
            personalRelevanceStars=personal.stars,
            temporalImpact=1.0,
            priorityScore=technicalScore * personal.multiplier,
            metricReasons=personal.reasons plus nodal reason if needed,
            samples=sorted samples
        )
        events.append(event)

    passCounts = count events by transitKey:aspectKey:natalKey

    for event in events:
        passCount = passCounts[event.baseKey]
        clusterCount = count events with same natalKey, technicalStars >= 3, exactDate within 21 days
        temporal = buildTemporalImpact(event, passCount, clusterCount)
        event.temporalImpact = temporal.multiplier
        event.temporalImpactStars = temporal.stars
        event.priorityScore = event.technicalScore * event.personalRelevance * event.temporalImpact
        event.metricReasons = unique(event.metricReasons + temporal.reasons)

    events = assignPriorityBands(events)

    return sortByPriority(events)
```

---

## 22. Prompt maestro reutilizable para otro modelo

Copia y pega este prompt cuando quieras pedir la funcionalidad en otra tecnología:

```text
Necesito implementar una pestaña de Tránsitos astrológicos equivalente a AstroMalik, en [TECNOLOGÍA/LENGUAJE]. No quiero una lista plana de aspectos; quiero una herramienta de foco personal con timeline, tabla, filtros y detalle.

Objetivo UX:
- Mostrar qué tránsitos están activos en un rango de fechas.
- Mostrar cuándo se activan mediante una timeline con scroll horizontal y vertical.
- Ordenar por prioridad real, no solo por planeta lento u orbe.
- Separar cuatro conceptos: intensidad diaria, técnica, relevancia personal, impacto temporal y prioridad.

Datos de entrada:
- Carta natal con planetas, longitudes zodiacales, casas, cúspides, ASC, MC, fecha/hora/zona.
- Rango fromDate/toDate.
- Toggle excludeMoon=true por defecto.

Cálculo diario:
- Usar calendario UTC.
- Para cada día, calcular posiciones transitantes a mediodía UTC.
- Comparar transitantes contra planetas natales + ASC + MC + Nodo Norte natal + Nodo Sur natal.
- Aspectos: conjunción 0, sextil 60, cuadratura 90, trígono 120, oposición 180.
- Orbes de tránsito: conj/opos/cuad 3°, trígono 2°, sextil 1.5°.
- Orbes nodales: conj/opos/cuad 2°, trígono 1.5°, sextil 1°.
- Intensidad diaria = clamp(1 - orb / maxOrb, 0, 1).
- Agrupar muestras en eventos por transitKey:aspectKey:natalKey si la separación entre muestras no supera 5 días.
- Conservar fromDate, toDate, exactDate, minOrb, activeDays, retrogradeOnExact y samples diarios.

Normalización nodal:
- Nodo Norte conjunción/oposición y Nodo Sur oposición/conjunción al mismo punto se fusionan como EJE_NODAL sobre punto.
- Cuadraturas de Nodo Norte/Sur se fusionan como EJE_NODAL cuadratura punto.
- Añadir motivo: Activación del eje nodal.

Score técnico:
- Pesos planetarios: Plutón 10, Neptuno 9, Urano 8, Saturno 7, Júpiter 6, Eje/Nodos 5, Marte 4, Venus 2, Mercurio 2, Sol 2, Luna 1.
- Pesos de aspecto: conjunción 5, oposición 4.5, cuadratura 4, trígono 3, sextil 2.
- orbFactor = clamp(1 - minOrb / maxOrb, 0, 1).
- technicalScore = round(planetWeight * aspectWeight * (0.5 + 0.5 * orbFactor), 1).
- technicalStars: >=25 cinco, >=15 cuatro, >=8 tres, >=3 dos, resto una.

Relevancia personal:
- personalRelevance = 1.0 + bonuses, clamp 0.75..1.85.
- ASC o MC +0.45.
- Sol/Luna +0.40.
- Regente tradicional del Ascendente +0.35.
- Venus/Marte +0.25, Mercurio +0.20, Júpiter/Saturno +0.15.
- Nodo natal +0.20; si nodo natal angular +0.35.
- Casa natal angular 1/4/7/10 +0.30; sucedente 2/5/8/11 +0.15; cadente 3/6/9/12 +0.05.
- Casa transitada angular +0.20; sucedente +0.10.
- Estrellas de multiplicador: >=1.65 cinco, >=1.40 cuatro, >=1.15 tres, >=0.95 dos, resto una.

Impacto temporal:
- temporalImpact inicia en 1.0 y se multiplica, clamp 0.75..1.80.
- Duración: <=7 x0.85, <=30 x0.95, <=120 x1.10, <=365 x1.22, >365 x1.30.
- Exactitud: minOrb<=0.25 x1.18; <=0.50 x1.12; <=1.00 x1.06.
- Pasadas por retrogradación: 2 x1.12, 3 x1.25, 4+ x1.35.
- Cluster al mismo punto natal dentro de 21 días y technicalStars>=3: 2 x1.10, 3+ x1.22.

Prioridad:
- priorityScore = technicalScore * personalRelevance * temporalImpact.
- Asignar priorityBand después de calcular todos los eventos:
  - top 10% y score >=35 -> critical / Crítica / 5 estrellas.
  - top 25% y score >=22 -> high / Alta / 4 estrellas.
  - top 50% y score >=12 -> medium / Media / 3 estrellas.
  - resto -> low / Baja / 2 estrellas.
- Ordenar por banda descendente, priorityScore descendente, exactDate ascendente, minOrb ascendente.

Filtros UI:
- Foco: critical + high. Debe ser el default.
- Importantes: critical + high + medium.
- Todos: todos.
- Técnicos: technicalStars >= 4.

Timeline:
- Debe tener scroll horizontal y vertical.
- Eje temporal superior con marcas adaptativas: diario/semanal/mensual/trimestral según rango.
- Cada fila: etiqueta fija con tránsito y prioridad; a la derecha barras diarias.
- Altura de barra = intensity * plotHeight, mínimo 2 px.
- Línea vertical en exactDate.
- Color de barras = color de aspecto: conj #d97706, sextil #2563eb, cuadratura #dc2626, trígono #15803d, oposición #a21caf.
- Color de prioridad separado: Crítica naranja, Alta azul, Media verde, Baja gris.

Tabla principal:
- Columnas: Tránsito, Prioridad, Motivo, Periodo, Orbe, Texto.
- No mostrar Técnica/Personal/Impacto como columnas principales.
- Prioridad debe mostrar estrellas, label y score.
- Motivo debe resumir máximo 3 metricReasons en orden narrativo: eje nodal, ASC, MC, Sol/Luna, regente ASC, nodo angular, nodo natal, planeta angular, casa angular, pasadas, cluster, duración, orbe exacto.

Detalle:
- Al seleccionar evento, mostrar título, periodo, orbe exacto, chips de “Por qué importa”, métricas completas e interpretación del corpus si existe.
- Métricas del detalle: Prioridad, Técnica, Personal, Impacto.
- Añadir explicación: Técnica mide planeta transitante, aspecto y orbe. Personal mide cuánto toca esta carta natal concreta. Impacto mide duración, repetición, exactitud y acumulación temporal.

Entrega esperada:
- Modelos/datatypes claros.
- Funciones de cálculo testeables.
- UI responsive con timeline scrollable.
- Separación estricta entre cálculo, estado, tabla, timeline y detalle.
```

---

## 23. Checklist de implementación

### Motor

- [ ] Validar rango de fechas.
- [ ] Usar calendario UTC.
- [ ] Calcular planetas transitantes.
- [ ] Calcular nodos verdaderos.
- [ ] Añadir ASC/MC como puntos natales.
- [ ] Añadir nodos natales.
- [ ] Detectar aspectos con orbes de tránsito, no natales.
- [ ] Normalizar eje nodal.
- [ ] Crear samples diarios.
- [ ] Agrupar eventos con `EVENT_GAP_DAYS = 5`.
- [ ] Calcular técnica.
- [ ] Calcular relevancia personal.
- [ ] Calcular impacto temporal.
- [ ] Calcular prioridad y bandas.
- [ ] Ordenar por prioridad.

### UI

- [ ] Barra de controles con rango, Sin Luna, Mostrar y Calcular.
- [ ] Default `Mostrar = Foco`.
- [ ] Timeline scrollable.
- [ ] Tabla con columnas simplificadas.
- [ ] Detalle completo.
- [ ] Colores separados para aspecto y prioridad.
- [ ] Indicador de interpretación disponible.

### Tests recomendados

- [ ] Una conjunción a 4° no entra si el orbe de tránsito es 3°.
- [ ] Una conjunción a 1° sí entra.
- [ ] La cuadratura no usa orbe natal de 7°.
- [ ] ASC y MC pueden recibir tránsitos.
- [ ] El eje nodal fusiona Norte/Sur y no duplica eventos.
- [ ] Cada evento tiene samples dentro de su rango.
- [ ] El sample de `exactDate` coincide con `minOrb` e intensidad máxima.
- [ ] Sol/Luna suben relevancia frente a puntos transpersonales no angulares.
- [ ] Regente del Ascendente añade bonus.
- [ ] Planeta natal angular añade bonus.
- [ ] `priorityScore = technicalScore * personalRelevance * temporalImpact`.
- [ ] `priorityStars` depende de `priorityBand`, no del score técnico.
- [ ] Las bandas usan mezcla de percentil relativo y umbral absoluto.

---

## 24. Antipatrones a evitar

- Usar los orbes natales para tránsitos.
- Ordenar solo por planeta transitante.
- Considerar que todo tránsito de Plutón/Neptuno/Urano es automáticamente prioritario.
- Ocultar ASC y MC como puntos transitables.
- Duplicar Nodo Norte y Nodo Sur como eventos separados cuando activan el mismo eje.
- Mostrar Técnica, Personal, Impacto y Prioridad como cuatro señales visuales equivalentes en la tabla principal.
- Usar los mismos umbrales de estrellas para técnica y prioridad.
- Comprimir la timeline sin scroll hasta que las barras sean ilegibles.
- Mezclar color de aspecto con color de prioridad en el mismo elemento.
- Llamar “Crítico” a lo mejor de un periodo flojo si no supera umbral absoluto.

---

## 25. Fórmulas resumidas

```text
angularDiff(a, b):
    raw = abs((a - b + 360) mod 360)
    return raw > 180 ? 360 - raw : raw

orb = abs(angularDiff(transitLongitude, natalLongitude) - aspectAngle)

intensity = clamp(1 - orb / maxOrb, 0, 1)

technicalScore = round(
    planetWeight * aspectWeight * (0.5 + 0.5 * clamp(1 - minOrb / maxOrb, 0, 1)),
    1
)

personalRelevance = clamp(1.0 + sum(personalBonuses), 0.75, 1.85)

temporalImpact = clamp(
    1.0 * durationFactor * exactnessFactor * passFactor * clusterFactor,
    0.75,
    1.80
)

priorityScore = technicalScore * personalRelevance * temporalImpact

priorityBand:
    if rank/total < 0.10 and priorityScore >= 35: critical
    else if rank/total < 0.25 and priorityScore >= 22: high
    else if rank/total < 0.50 and priorityScore >= 12: medium
    else: low
```

---

## 26. Arquitectura recomendada por capas

```text
TransitCalculator / Engine
    - efemérides
    - aspectos
    - agrupación
    - scoring

TransitModels
    - TransitEvent
    - TransitIntensitySample
    - TransitPriorityBand
    - TransitFocusFilter

TransitState / ViewModel
    - fromDate
    - toDate
    - excludeMoon
    - selectedEvent
    - events
    - isCalculating
    - focusFilter
    - needsRecalculation

TransitTimelineView
    - eje temporal
    - barras
    - exactDate marker
    - click/selection

TransitTableView
    - columnas principales
    - ordenación
    - motivo compacto

TransitDetailView
    - razones completas
    - métricas completas
    - corpus
```

Esta separación permite portar el sistema a SwiftUI, React, Vue, Flutter, Kotlin, Python/Qt, web canvas, desktop nativo o cualquier otra tecnología sin cambiar el criterio astrológico.

---

## 27. Criterio final de calidad

La implementación es correcta si:

- El modo **Foco** no muestra todo el ruido del periodo.
- La timeline deja ver claramente cuándo se aproxima y separa cada tránsito.
- La tabla se lee como: `qué es -> cuánto importa -> por qué -> cuándo -> con qué orbe`.
- La prioridad no se satura en 5 estrellas.
- Los tránsitos personales suben aunque no sean los técnicamente más extremos.
- Los transpersonales generacionales no dominan si no tocan puntos personales o angulares.
- El detalle explica con transparencia cómo se llegó a la prioridad.

En una frase:

```text
Prioridad = qué mirar primero.
Motivo = por qué importa.
Timeline = cuándo se activa.
Detalle = cómo se justifica.
```
