# Tránsitos: estructura, funcionamiento y criterio de prioridad

Documento de referencia para el módulo de Tránsitos de AstroMalik-macOS.

Fecha de trabajo: 2026-04-29.

Este documento recoge el estado del módulo de tránsitos, las conclusiones astrológicas alcanzadas durante la revisión, las fórmulas implicadas, los problemas detectados en la representación visual y el criterio propuesto para convertir la pestaña de Tránsitos en una herramienta de foco personal.

## Objetivo del módulo

La pestaña de Tránsitos no debe limitarse a listar aspectos astrológicos activos. Su función principal debe ser ayudar a responder con rapidez:

- qué está activo ahora o durante un periodo;
- qué tránsitos son técnicamente fuertes;
- cuáles afectan de verdad a la carta natal concreta;
- cuáles tienen impacto temporal por duración, repetición o concentración;
- y cuáles conviene mirar primero.

La conclusión principal es que una lista ordenada solo por planeta transitante, aspecto y orbe produce mucho ruido. Para una lectura astrológica profesional hace falta distinguir entre:

```text
Intensidad técnica = fuerza abstracta del tránsito.
Relevancia personal = cuánto toca esta carta natal concreta.
Impacto temporal = cuánto insiste o pesa en el tiempo.
Prioridad = qué debe mirar primero el usuario.
```

## Archivos principales

El módulo vive principalmente en:

- `Sources/AstroMalik/Engine/TransitEngine.swift`
- `Sources/AstroMalik/Models/Transit.swift`
- `Sources/AstroMalik/Views/TransitsView.swift`
- `Sources/AstroMalik/Views/TransitTimelineView.swift`
- `Sources/AstroMalik/Models/NatalChart.swift`
- `Sources/AstroMalik/Engine/AstroEngine.swift`

Documentación relacionada:

- `docs/ARCHITECTURE.md`
- `docs/prompt_corpus_transitos_scraping.md`
- `PROMPT_TRANSITOS_FOCO.md`

## Funcionamiento actual del motor

`TransitEngine` calcula tránsitos para un rango de fechas.

El cálculo recorre cada día del periodo seleccionado usando calendario UTC. Para cada día:

1. calcula posiciones planetarias de tránsito con Swiss Ephemeris;
2. compara esas posiciones contra puntos natales;
3. detecta aspectos dentro de orbe;
4. agrupa días contiguos del mismo tránsito en un único evento;
5. conserva muestras diarias para dibujar la curva de intensidad en la timeline.

La agrupación se hace por:

```text
planeta transitante + aspecto + punto natal
```

Por ejemplo:

```text
SATURNO:OPOSICION:SOL
PLUTON:CUADRADO:MARTE
URANO:TRIGONO:MC
```

El motor agrupa días contiguos siempre que la separación no supere `EVENT_GAP_DAYS`.

## Aspectos y orbes

Los ángulos de aspecto se definen en `AstroEngine.swift`, pero el módulo de Tránsitos no reutiliza los orbes natales de `ASPECT_DEFS`. Natal y sinastría necesitan orbes más amplios; tránsitos necesita orbes más estrechos para reducir ruido.

Orbes natales de referencia en `ASPECT_DEFS`:

```text
Conjunción  0 grados    orbe 8
Sextil      60 grados   orbe 5
Cuadratura  90 grados   orbe 7
Trígono     120 grados  orbe 7
Oposición   180 grados  orbe 8
```

Orbes específicos de tránsitos en `TransitEngine.swift`:

```text
Conjunción  3.0
Oposición   3.0
Cuadratura  3.0
Trígono     2.0
Sextil      1.5
```

Para Nodo Norte y Nodo Sur transitantes se usan orbes aún más estrechos:

```text
Conjunción  2.0
Oposición   2.0
Cuadratura  2.0
Trígono     1.5
Sextil      1.0
```

La cercanía al aspecto exacto se expresa como:

```text
intensidad diaria = 1 - orb / maxOrb
```

Esta intensidad diaria no es la misma cosa que las estrellas globales del evento.

## Diferencia entre timeline y estrellas

Hay dos magnitudes distintas:

```text
Timeline:
    muestra intensidad diaria por cercanía al orbe exacto.

Estrellas:
    muestran fuerza global del evento según una fórmula de scoring.
```

La timeline responde:

```text
¿En qué momento del periodo se concentra el aspecto?
```

Las estrellas responden:

```text
¿Qué peso general tiene este tránsito?
```

Esto debe mantenerse claro en la UI. Las barras de la timeline no deben interpretarse como "importancia vital absoluta", sino como curva de aproximación al aspecto exacto.

## Intensidad técnica

La fórmula original del módulo calcula un score técnico a partir de:

- planeta transitante;
- aspecto;
- orbe mínimo alcanzado.

Pesos planetarios actuales:

```text
Plutón     10
Neptuno    9
Urano      8
Saturno    7
Júpiter    6
Nodo Norte 5
Nodo Sur   5
Marte      4
Venus      2
Mercurio   2
Sol        2
Luna       1
```

Pesos de aspecto:

```text
Conjunción   5
Oposición    4.5
Cuadratura   4
Trígono      3
Sextil       2
```

Fórmula:

```text
orbFactor = 1 - minOrb / maxOrb
score = planetWeight * aspectWeight * (0.5 + 0.5 * orbFactor)
```

El resultado se redondea a una decimal.

Estrellas técnicas:

```text
score >= 25 -> 5 estrellas
score >= 15 -> 4 estrellas
score >= 8  -> 3 estrellas
score >= 3  -> 2 estrellas
resto       -> 1 estrella
```

## Limitación de la intensidad técnica

La intensidad técnica es útil, pero no basta para interpretar la vida de una persona.

Ejemplo:

```text
Plutón cuadratura Urano natal
```

Puede salir muy alto porque Plutón pesa mucho y la cuadratura pesa mucho. Pero Urano natal puede ser un punto generacional, no necesariamente el centro de la biografía personal, salvo que esté angular, sea regente, esté muy configurado o tenga especial peso natal.

Otro ejemplo:

```text
Saturno oposición Sol natal
```

Puede tener menos puntuación técnica que un Plutón a Urano, pero para la vida concreta de la persona suele ser mucho más relevante: identidad, vitalidad, responsabilidad, límites, maduración, padre/autoridad, carrera o estructura vital según casas.

Conclusión:

```text
No todo tránsito de planeta lento es automáticamente más importante.
No todo tránsito a planeta transpersonal natal debe dominar la lectura.
```

## Relevancia personal

La relevancia personal mide cuánto toca la carta natal concreta.

Debe tener en cuenta:

- puntos personales;
- ángulos;
- regente del Ascendente;
- angularidad natal;
- casa natal del punto tocado;
- casa natal por donde transita el planeta.

La fórmula propuesta usa un multiplicador:

```text
personalRelevance = 1.0 + bonificaciones
```

Con clamp:

```text
0.75...1.85
```

Bonificaciones propuestas:

```text
ASC o MC                         +0.45
Sol o Luna                       +0.40
Regente del Ascendente           +0.35
Venus o Marte                    +0.25
Mercurio                         +0.20
Júpiter o Saturno                +0.15
Nodo Norte o Nodo Sur natal      +0.20
Nodo natal angular               +0.35
Urano, Neptuno o Plutón natal    +0.00 por defecto
```

Angularidad natal:

```text
Casa 1, 4, 7, 10     +0.30
Casa 2, 5, 8, 11     +0.15
Casa 3, 6, 9, 12     +0.05
```

Casa por donde transita el planeta:

```text
Casa 1, 4, 7, 10     +0.20
Casa 2, 5, 8, 11     +0.10
Casa 3, 6, 9, 12     +0.00
```

Esta métrica corrige el sesgo de la técnica pura y permite que suban tránsitos realmente personales.

## Regente del Ascendente

El regente del Ascendente se calcula con regencias tradicionales:

```text
Aries       Marte
Tauro       Venus
Géminis     Mercurio
Cáncer      Luna
Leo         Sol
Virgo       Mercurio
Libra       Venus
Escorpio    Marte
Sagitario   Júpiter
Capricornio Saturno
Acuario     Saturno
Piscis      Júpiter
```

Se recomienda mantener regencia tradicional en esta métrica porque el objetivo es medir significadores personales de la carta, no modernizar el sistema de forma híbrida sin control.

## ASC y MC como puntos transitables

Una conclusión importante de la revisión fue que el motor original calculaba aspectos contra `natalChart.bodies`, pero no necesariamente contra ASC y MC como puntos natales transitables.

Para una lectura profesional, ASC y MC deben incluirse:

```text
ASC:
    label: Ascendente
    longitud: natalChart.ascendant.longitude
    casa: 1

MC:
    label: Medio Cielo
    longitud: natalChart.mc.longitude
    casa: 10
```

ASC y MC son puntos muy personales:

- ASC: cuerpo, identidad encarnada, dirección inmediata, presencia, salud, forma de iniciar.
- MC: vocación, exposición, carrera, reputación, dirección pública, autoridad.

Tránsitos a ASC/MC deben poder subir la relevancia personal de forma clara.

## Nodos Lunares

Tránsitos calcula Nodo Norte verdadero (`SE_TRUE_NODE`) de forma local dentro de `TransitEngine`, sin ampliar `PLANET_LIST`. Esto evita modificar cartas natales, sinastría o conteos de corpus que dependen de la lista planetaria tradicional.

El motor añade:

```text
NODO_NORTE:
    label: Nodo Norte
    longitud: SE_TRUE_NODE

NODO_SUR:
    label: Nodo Sur
    longitud: Nodo Norte + 180 normalizado
```

Los nodos se incorporan en dos niveles:

- como puntos natales transitables, calculados desde fecha/hora/zona de la carta;
- como puntos transitantes diarios dentro del periodo.

Cuando Nodo Norte y Nodo Sur describen el mismo contacto al mismo punto natal, el motor los fusiona como `EJE_NODAL`:

```text
Nodo Norte conjunción punto + Nodo Sur oposición punto -> Eje Nodal sobre punto
Nodo Norte oposición punto + Nodo Sur conjunción punto -> Eje Nodal sobre punto
Nodo Norte cuadratura punto + Nodo Sur cuadratura punto -> Eje Nodal Cuadratura punto
```

Esto evita duplicar eventos y evita que el cálculo de clusters cuente el eje nodal como dos testimonios separados. El motivo compacto puede mostrar:

```text
Activación del eje nodal
```

Si el corpus no contiene una interpretación para una clave nodal, la UI conserva el comportamiento normal y muestra que no hay interpretación disponible.

## Impacto temporal

El impacto temporal mide cuánto insiste el tránsito en el tiempo.

No responde a "qué tan personal es", sino a:

```text
¿Cuánto dura?
¿Cuántas veces pasa?
¿Cuán exacto llega?
¿Se acumula con otros tránsitos al mismo punto?
```

Fórmula propuesta:

```text
temporalImpact = 1.0
```

Factores por duración:

```text
<= 7 días       x0.85
<= 30 días      x0.95
<= 120 días     x1.10
<= 365 días     x1.22
> 365 días      x1.30
```

Factores por exactitud:

```text
minOrb <= 0.25°     x1.18
minOrb <= 0.50°     x1.12
minOrb <= 1.00°     x1.06
```

Factores por número de pasadas:

```text
1 pasada       x1.00
2 pasadas      x1.12
3 pasadas      x1.25
4 o más        x1.35
```

Factores por concentración:

```text
2 tránsitos próximos al mismo punto      x1.10
3 o más tránsitos al mismo punto         x1.22
```

Clamp:

```text
0.75...1.80
```

## Prioridad

La prioridad combina las tres dimensiones:

```text
priorityScore = technicalScore * personalRelevance * temporalImpact
```

La prioridad no debe verse como una verdad absoluta, sino como una herramienta de ordenación.

Responde a:

```text
¿Qué debería mirar primero?
```

La prioridad es el concepto que debe dominar la UI de Tránsitos.

## Problema detectado: saturación de estrellas

Tras añadir Técnica, Personal, Impacto y Prioridad, apareció un problema visual:

- demasiadas columnas de estrellas;
- las cuatro métricas competían al mismo nivel;
- la prioridad se saturaba en 5 estrellas;
- el filtro `Prioridad: 1★` seguía mostrando demasiados tránsitos;
- la vista no ofrecía foco real.

La causa técnica probable es que `priorityStars` reutilizaba umbrales pensados para `technicalScore`, aunque `priorityScore` multiplica el score técnico por relevancia e impacto.

Esto hace que muchos tránsitos terminen en 5 estrellas.

Conclusión:

```text
La prioridad necesita bandas propias, no solo los umbrales técnicos antiguos.
```

## Bandas de prioridad

Se propuso añadir:

```swift
enum TransitPriorityBand: String, Codable, Hashable {
    case low
    case medium
    case high
    case critical
}
```

Con etiquetas:

```text
low      -> Baja
medium   -> Media
high     -> Alta
critical -> Crítica
```

Las estrellas de prioridad deben depender de la banda:

```text
Crítica -> 5 estrellas
Alta    -> 4 estrellas
Media   -> 3 estrellas
Baja    -> 2 estrellas
```

Esto evita que todo sea "5 estrellas" y convierte la prioridad en una señal legible.

## Cálculo recomendado de bandas

La banda debe calcularse después de tener todos los eventos y sus `priorityScore`.

La propuesta combina percentil relativo y umbral absoluto:

```text
Top 10% + priorityScore >= 35 -> critical
Top 25% + priorityScore >= 22 -> high
Top 50% + priorityScore >= 12 -> medium
Resto                         -> low
```

Reglas de seguridad:

- si un evento está en top 10% pero no llega a 35, no debe ser `critical`;
- si está en top 25% pero no llega a 22, no debe ser `high`;
- si un periodo es flojo, no debe inventar crisis;
- si un periodo es muy cargado, no debe mostrar 80 tránsitos críticos.

Esta decisión introduce una lectura contextual del periodo.

## Filtro de foco

El filtro superior no debe llamarse simplemente `Prioridad: 1★`, porque eso invita a pensar en una escala numérica rígida y no reduce ruido.

Se propuso sustituirlo por:

```text
Mostrar: Foco | Importantes | Todos | Técnicos
```

Comportamiento:

```text
Foco:
    solo critical + high

Importantes:
    critical + high + medium

Todos:
    todos los eventos

Técnicos:
    technicalStars >= 4
```

Valor por defecto:

```text
Foco
```

Esto convierte la pestaña en una herramienta práctica: al abrirla, el usuario no ve todo el ruido, sino lo que debe mirar primero.

## Tabla principal recomendada

La tabla principal no debe mostrar cuatro columnas equivalentes de estrellas.

Columnas recomendadas:

```text
Tránsito
Prioridad
Motivo
Periodo
Orbe
Texto
```

Ejemplo:

```text
Plutón Cuadratura Marte | ★★★★★ Crítica · 81.2 | Personal alta · Impacto largo · Orbe exacto | 2026-04-29 -> 2026-10-29 | 1.1°
```

La tabla debe leerse de izquierda a derecha como:

```text
qué es -> cuánto importa -> por qué -> cuándo -> con qué orbe
```

## Columna Motivo

La columna `Motivo` resume los factores más relevantes.

No debe mostrar todas las razones técnicas.

Debe elegir dos o tres motivos prioritarios.

Prioridad sugerida:

```text
1. Toca Ascendente
2. Toca Medio Cielo
3. Toca Sol/Luna
4. Regente del Ascendente
5. Planeta natal angular
6. Tránsito por casa angular
7. Tres pasadas por retrogradación
8. Dos pasadas por retrogradación
9. Cluster de tránsitos al mismo punto
10. Duración larga
11. Duración muy larga
12. Orbe exacto menor de 0.25°
13. Orbe exacto menor de 0.5°
14. Orbe exacto menor de 1°
```

Ejemplos de salida:

```text
Toca Ascendente · Casa angular · Duración larga
Toca Sol/Luna · Tres pasadas · Orbe exacto
Técnica alta · Personal baja · Fondo generacional
```

## Timeline recomendada

La timeline debe conservar su comportamiento principal:

- barras diarias según cercanía al exacto;
- color de aspecto;
- línea vertical de exactitud;
- click para abrir detalle.

Pero la etiqueta de cada fila debe mostrar solo la señal principal:

```text
Saturno Oposición Sol
★★★★ Alta
```

No debe mostrar Técnica, Personal e Impacto al mismo nivel en la timeline.

Tooltip recomendado:

```text
Prioridad Alta · Técnica 4★ · Personal 5★ · Impacto 4★
```

## Colores

Separar colores por función:

Color del aspecto:

```text
Conjunción  naranja
Sextil      azul
Cuadratura  rojo
Trígono     verde
Oposición   morado
```

Color de prioridad:

```text
Crítica     naranja
Alta        azul
Media       verde
Baja        gris/secundario
```

El color de aspecto debe quedar en el punto y en las barras de la timeline.

El color de prioridad debe quedar en las estrellas o badge de prioridad.

No mezclar ambos en el mismo elemento, porque confunde.

## Detalle del tránsito

El detalle sí debe mostrar la explicación completa.

Estructura recomendada:

```text
Título
Por qué importa
Métricas
Interpretación
```

Bloque `Por qué importa`:

```text
Toca Sol/Luna
Planeta natal angular
Duración larga
Orbe exacto menor de 1°
```

Bloque `Métricas`:

```text
Prioridad: ★★★★★ Crítica · 81.2
Técnica:   ★★★★★ · 42.7
Personal:  ★★★★☆ · x1.55
Impacto:   ★★★★☆ · x1.22
```

Explicación breve:

```text
Técnica mide planeta transitante, aspecto y orbe.
Personal mide cuánto toca esta carta natal concreta.
Impacto mide duración, repetición, exactitud y acumulación temporal.
```

Esta explicación debe estar en detalle o tooltip, no ocupando la pantalla principal.

## Prompt de implementación

El prompt operativo para aplicar la mejora visual quedó guardado en:

```text
PROMPT_TRANSITOS_FOCO.md
```

Ese prompt pide:

- no rehacer el motor astrológico;
- conservar las métricas ya calculadas;
- añadir `priorityBand`;
- cambiar el filtro superior a `Mostrar: Foco | Importantes | Todos | Técnicos`;
- simplificar la tabla principal;
- mover Técnica, Personal e Impacto al detalle;
- ordenar por prioridad real;
- evitar saturación de 5 estrellas;
- ejecutar `swift test`.

## Referencias de implementación local

### `TransitEngine.swift`

Responsabilidades:

- cálculo diario de posiciones;
- detección de aspectos;
- agrupación de eventos;
- cálculo de score técnico;
- cálculo de relevancia personal;
- cálculo de impacto temporal;
- cálculo de prioridad;
- futura asignación de bandas.

### `Transit.swift`

Responsabilidades:

- modelo `TransitWorkspaceState`;
- modelo `TransitEvent`;
- propiedades persistibles;
- displays de estrellas;
- futuras labels de prioridad y helper `compactReason`.

### `TransitsView.swift`

Responsabilidades:

- controles superiores;
- filtro de foco;
- tabla principal;
- detalle modal;
- ordenación visible.

### `TransitTimelineView.swift`

Responsabilidades:

- eje temporal;
- barras por intensidad diaria;
- etiquetas por evento;
- selección para abrir detalle.

## Criterio astrológico profesional resumido

Un tránsito afecta más a una persona cuando:

- toca Sol, Luna, ASC, MC o regente del Ascendente;
- toca planetas natales angulares;
- activa casas 1, 4, 7 o 10;
- tiene orbe estrecho;
- dura meses o años;
- repite por retrogradación;
- se estaciona cerca de un punto natal;
- coincide con otros tránsitos al mismo punto o eje;
- está confirmado por otras técnicas como revolución solar, revolución lunar, profecciones o direcciones primarias.

El módulo actual ya puede cubrir una parte importante de esto:

- técnica;
- puntos personales;
- casas;
- duración;
- pasadas;
- clusters;
- prioridad combinada.

Pendientes posibles para una versión futura:

- detectar estaciones exactas cerca de puntos natales;
- cruzar con revolución solar/lunar;
- cruzar con direcciones primarias;
- añadir profecciones anuales;
- detectar activación por ejes completos, no solo por punto individual;
- detectar acumulación temática por casa, no solo por planeta natal.

## Conclusión

La mejora clave no consiste en añadir más estrellas, sino en ordenar el significado.

El diseño final debería transmitir:

```text
Prioridad = qué mirar primero.
Motivo = por qué importa.
Detalle = cómo se compone técnicamente.
Timeline = cuándo se activa.
```

Con esta estructura, Tránsitos pasa de ser una lista extensa de aspectos a una herramienta de lectura personal inmediata.
