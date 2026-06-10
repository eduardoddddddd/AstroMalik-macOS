# Horaria clásica en AstroMalik macOS

Este documento describe el módulo de **Horaria** de AstroMalik macOS: qué calcula, cómo estructura el juicio, qué criterios tradicionales aplica, cómo se presenta en la interfaz y cuáles son sus límites actuales.

La horaria de AstroMalik no es una llamada a un servicio externo ni un texto libre generado por IA. El flujo normal usa un motor Swift nativo, determinista, basado en Swiss Ephemeris y en reglas horarias tradicionales explícitas.

---

## 1. Propósito del módulo

La astrología horaria responde una pregunta concreta levantando la carta del momento en que la pregunta queda formulada y recibida. En AstroMalik, el módulo está pensado para trabajar con preguntas del tipo:

- “¿Conseguiré este trabajo?”
- “¿Se resolverá este contrato?”
- “¿Habrá relación con esta persona?”
- “¿Conviene esta mudanza?”
- “¿Recuperaré este dinero / bien?”
- “¿Cuándo saldré de esta situación?”

El módulo produce tres capas de resultado:

1. **Carta horaria técnica**: posiciones, casas, partes, dignidades, aspectos y consideraciones.
2. **Juicio estructurado**: significadores, ruta de perfección, veredicto, confianza, factores a favor/en contra y advertencias.
3. **Lectura asistida opcional**: redacción local con Foundry Local, siempre a partir del juicio técnico ya calculado.

El cálculo base es completamente local.

---

## 2. Flujo de uso en la aplicación

La sección **Horaria** ofrece dos pestañas:

- **Nueva Consulta**: formulario de pregunta y datos del momento/lugar.
- **Historial**: consultas guardadas en la base local.

### 2.1 Formulario de consulta

El formulario recoge:

| Campo | Uso |
|---|---|
| Pregunta | Texto literal de la consulta. |
| Fecha y hora local | Momento de la pregunta. |
| Zona IANA | Ej. `Europe/Madrid`. Se usa para convertir a JD UT. |
| Lugar | Nombre del lugar de la consulta. |
| Latitud / longitud | Coordenadas para casas y horas planetarias. |
| Casa del asunto | Casa que representa el objeto de la pregunta. |
| Incluir Fortuna | Añade Parte de Fortuna además de Parte del Espíritu. |

La UI incluye presets de casa para preguntas frecuentes:

| Preset | Casa |
|---|---:|
| Trabajo nuevo / posición / empresa | 10 |
| Mudanza / hogar / inmueble | 4 |
| Pareja / sociedad / acuerdo | 7 |
| Noticias / mensaje / hermanos | 3 |
| Dinero propio / posesiones | 2 |
| Salud / empleados / rutinas | 6 |
| Viaje largo / extranjero / estudios | 9 |
| Hijos / creatividad / placer | 5 |
| Amistades / esperanzas / grupos | 11 |
| Enemigos ocultos / encierros | 12 |
| Padre / final / inmueble paterno | 4 |
| Herencia / muerte / dinero ajeno | 8 |
| Otra | casa elegida manualmente |

### 2.2 Resultado

Una consulta calculada se abre como `HoraryResultView`. La pantalla separa:

- cabecera de la consulta;
- significadores;
- dignidades relevantes;
- consideraciones activas;
- tabla de cuerpos y partes;
- veredicto estructurado;
- ruta de perfección;
- Luna y curso;
- factores a favor;
- factores en contra;
- notas técnicas;
- interpretación local opcional.

Las consultas quedan guardadas en `user.db` y pueden reabrirse desde el historial.

---

## 3. Arquitectura técnica

### 3.1 Archivos principales

```text
Sources/AstroMalik/Horary/
├── HoraryEngine.swift                 # Fachada async y modo legado Python
├── HoraryNativeEngine.swift           # Motor Swift nativo
├── Interpretation/
│   └── HoraryFoundryClient.swift      # Lectura local opcional con Foundry
├── Models/
│   ├── HoraryModels.swift             # Carta y juicio estructurado
│   └── SavedHoraryQuery.swift         # Consulta guardada
├── Store/
│   └── HoraryStore.swift              # Persistencia SQLite
└── Views/
    ├── HoraryFormView.swift
    ├── HoraryHomeView.swift
    ├── HoraryResultView.swift
    ├── HoraryDiagnosticsView.swift
    └── SavedHoraryView.swift
```

### 3.2 Motor por defecto

`HoraryEngine.calculate(_:)` usa `HoraryNativeEngine` salvo que se fuerce el modo Python:

```bash
ASTROMALIK_HORARIA_ENGINE=python
```

Si el motor nativo falla inesperadamente, `HoraryEngine` puede intentar el modo Python legado, salvo que se fuerce Swift estricto:

```bash
ASTROMALIK_HORARIA_ENGINE=swift
```

El modo Python se conserva para comparación/diagnóstico, no como dependencia normal de uso.

### 3.3 Persistencia

Las consultas se guardan en:

```text
~/Library/Application Support/AstroMalik/user.db
```

Tabla:

```text
saved_horary_queries
```

Campos principales:

- `id`
- `question`
- `question_house`
- `datetime_local`
- `timezone`
- `latitude`
- `longitude`
- `place_name`
- `include_fortune`
- `chart_json`
- `judgement_json`
- `judgement_text`
- `calculated_at`
- `created_at`

La carta y el juicio se guardan como JSON estructurado para que la UI pueda renderizar datos técnicos sin volver a calcular.

---

## 4. Contrato de entrada y salida

### 4.1 Entrada: `HoraryRequest`

```swift
struct HoraryRequest: Codable, Equatable {
    let question: String
    let datetimeLocal: String
    let timezone: String
    let latitude: Double
    let longitude: Double
    let placeName: String
    let questionHouse: Int
    let includeFortune: Bool
}
```

### 4.2 Salida: `HoraryResponse`

```swift
struct HoraryResponse: Codable, Equatable {
    let chartJSON: String
    let judgementJSON: String
    let judgementText: String
    let calculatedAt: String
}
```

La respuesta mantiene tres representaciones:

- `chartJSON`: carta horaria completa.
- `judgementJSON`: juicio estructurado.
- `judgementText`: texto legacy/compacto para compatibilidad y lectura rápida.

### 4.3 Carta: `HoraryChart`

Incluye:

- cabecera de la pregunta;
- ASC y MC;
- hora planetaria;
- secta;
- cuerpos;
- partes;
- dignidades;
- aspectos;
- consideraciones.

### 4.4 Juicio: `HoraryJudgement`

Incluye:

- pregunta;
- radicalidad;
- tipo de perfección;
- estimación temporal;
- casa y tema del asunto;
- significadores;
- ruta de perfección;
- consideraciones activas;
- notas;
- veredicto;
- confianza;
- motivo principal;
- factores favorables;
- factores bloqueantes;
- advertencias técnicas;
- rango temporal.

Los campos estructurados nuevos son opcionales para mantener compatibilidad con consultas antiguas ya guardadas.

---

## 5. Cálculo astronómico

El motor nativo calcula la carta con Swiss Ephemeris:

- fecha local → fecha UTC → Julian Day UT;
- casas Regiomontanus (`swe_houses_ex2` a través de `AstroEngine.calcHouses`);
- siete planetas tradicionales;
- Nodo Norte verdadero;
- velocidades planetarias;
- retrogradación y estacionariedad;
- asignación de casa;
- Parte de Fortuna, si se solicita;
- Parte del Espíritu siempre.

Cuerpos calculados:

```text
Sol
Luna
Mercurio
Venus
Marte
Júpiter
Saturno
Nodo Norte verdadero
```

Partes:

```text
Parte de Fortuna      opcional
Parte del Espíritu    siempre
```

La fórmula de Fortuna se invierte por secta:

- carta diurna: `ASC + Luna - Sol`;
- carta nocturna: `ASC + Sol - Luna`.

La Parte del Espíritu usa la fórmula complementaria.

---

## 6. Modelo doctrinal implementado

### 6.1 Alcance tradicional

El motor V1 sigue un marco tradicional estricto:

- siete planetas tradicionales;
- regencias clásicas;
- casas Regiomontanus;
- aspectos mayores;
- dignidades esenciales ptolemaicas/egipcias;
- dignidad accidental básica;
- hora planetaria;
- radicalidad por acuerdo horario y consideraciones;
- recepción;
- perfección directa;
- translación de luz;
- colección de luz.

No usa planetas transpersonales para el juicio horario.

### 6.2 Regencias

| Signo | Regente clásico |
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

### 6.3 Aspectos

Aspectos mayores:

| Aspecto | Ángulo |
|---|---:|
| Conjunción | 0° |
| Sextil | 60° |
| Cuadratura | 90° |
| Trígono | 120° |
| Oposición | 180° |

El motor usa moieties planetarias para determinar si dos cuerpos están dentro de orbe.

### 6.4 Dignidad esencial

Se evalúan:

| Condición | Puntuación |
|---|---:|
| Domicilio | +5 |
| Exaltación | +4 |
| Triplicidad por secta | +3 |
| Término egipcio | +2 |
| Decanato | +1 |
| Detrimento | -5 |
| Caída | -4 |
| Peregrino | -5 |

La triplicidad respeta secta diurna/nocturna. Los términos son egipcios y los decanatos siguen el orden caldeo.

### 6.5 Dignidad accidental

Se evalúa:

- angularidad / sucedencia / cadencia;
- retrogradación;
- movimiento directo;
- combustión, bajo los rayos y cazimi;
- velocidad respecto a velocidad media;
- mitigaciones o aflicciones particulares por casa.

La puntuación resultante no decide sola el veredicto, pero alimenta factores de fuerza/debilidad y selección de co-significadores.

### 6.6 Hora planetaria y radicalidad

El motor calcula la hora planetaria usando horas desiguales de día/noche:

- regente del día;
- orden caldeo;
- salida/puesta solar aproximada para el lugar y fecha.

Se considera favorable el acuerdo entre:

- regente de la hora y regente del ASC;
- o ambos dentro de una compatibilidad por triplicidad/naturaleza.

La carta se considera menos fiable si acumula advertencias. En V1, la radicalidad se degrada especialmente cuando hay demasiadas consideraciones activas y no hay acuerdo horario suficiente.

---

## 7. Significadores

### 7.1 Consultante

El consultante se representa por el regente clásico del signo del Ascendente.

La Luna actúa como co-significadora general del consultante y del movimiento del asunto.

### 7.2 Quesited / asunto preguntado

El quesited se representa por el regente clásico del signo en la cúspide de la casa seleccionada.

Ejemplo:

- pregunta de trabajo → casa 10;
- se toma el signo de la cúspide 10;
- su regente clásico representa el trabajo/cargo/empresa.

### 7.3 Co-significadores

El motor puede añadir co-significadores si hay planetas relevantes en:

- casa 1 para el consultante;
- casa del asunto para el quesited.

Para que un co-significador pese en la ruta, debe tener fuerza esencial suficiente o ser el significador primario.

---

## 8. Consideraciones y advertencias

El motor evalúa consideraciones clásicas y técnicas:

| Clave | Significado |
|---|---|
| `asc_temprano` | ASC antes de 3°: asunto inmaduro o prematuro. |
| `asc_tardio` | ASC desde 27°: asunto avanzado, tardío o ya decidido. |
| `via_combusta` | Luna entre 15° Libra y 15° Escorpio. |
| `luna_vacia` | Luna no perfecciona aspecto mayor antes de salir del signo. |
| `saturno_1_7` | Saturno en I o VII: daño para consultante o juicio. |
| `acuerdo_hora` | Acuerdo entre hora planetaria y ASC. |

Las advertencias no son “prohibiciones automáticas”; son condiciones que afectan confianza, timing y lectura del juicio.

---

## 9. Perfección

El núcleo del juicio es determinar si existe una vía técnica que conecte consultante y asunto.

### 9.1 Perfección directa

Se busca aspecto aplicativo entre:

- significador del consultante;
- Luna;
- co-significadores fuertes del consultante;
- significador del asunto;
- co-significadores fuertes del asunto.

Una ruta directa registra:

- tipo: `aplicativo_directo`;
- aspecto;
- cuerpos implicados;
- grados hasta perfección;
- cuerpo más rápido;
- grados hasta salida de signo de la Luna si participa;
- si perfecciona antes del cambio de signo;
- confianza técnica de la ruta.

### 9.2 Translación de luz

Se detecta cuando un planeta más rápido separa de un significador y aplica al otro, transportando la luz entre ambos.

Tipo:

```text
translacion
```

La confianza inicial de V1 es media y el timing se considera condicionado por mediación.

### 9.3 Colección de luz

Se detecta cuando ambos significadores aplican a un tercer planeta más lento, que recoge la luz.

Tipo:

```text
coleccion
```

También se considera una ruta condicionada por mediación.

### 9.4 Sin perfección

Si no aparece ruta válida:

```text
sin_perfeccion
```

Esto no siempre equivale a un “no” absoluto. Puede producir:

- `no_todavia` si además hay Luna vacía o ASC temprano;
- `dudoso` si la carta no permite asegurar desenlace.

---

## 10. Regla crítica: Luna fuera de curso

Esta es una decisión doctrinal importante del motor nativo.

La Luna está fuera de curso cuando **no perfecciona un aspecto mayor antes de salir de su signo**.

Por coherencia, el motor aplica la misma restricción a la perfección lunar:

> Si la Luna aplica a un planeta pero el aspecto exacto ocurre después del cambio de signo, esa ruta no cuenta como perfección lunar válida.

Esto evita una contradicción clásica: declarar simultáneamente “Luna vacía” y aceptar como perfección una aplicación lunar que solo se consuma en el signo siguiente.

Esta regla fue añadida para corregir un fallo observado en el flujo legado Python.

---

## 11. Recepción

El motor evalúa recepción entre significadores principales.

Se considera que un planeta recibe al otro si el segundo cae en alguna dignidad esencial relevante del primero:

- domicilio;
- exaltación;
- triplicidad de secta;
- término.

Tipos:

| Tipo | Uso en juicio |
|---|---|
| Recepción mutua | Mitiga dificultades y puede convertir una perfección difícil en resultado viable. |
| Recepción simple | Añade apoyo, pero no pesa tanto como la mutua. |
| Sin recepción | La ruta depende más del aspecto y fuerza de los significadores. |

---

## 12. Veredicto

El resultado estructurado usa cinco valores:

| Valor interno | Etiqueta UI | Criterio general |
|---|---|---|
| `si` | Sí | Hay perfección válida sin obstáculo mayor, o perfección difícil mitigada por recepción suficiente. |
| `no` | No | Reservado para desarrollos/juicios más categóricos; V1 tiende a usar estados prudentes. |
| `no_todavia` | No todavía | No hay perfección válida y la carta muestra inmadurez/falta de movimiento. |
| `dudoso` | Dudoso | No hay vía técnica suficiente para asegurar desenlace. |
| `requiere_mediacion` | Requiere ajuste | Hay perfección, pero por aspecto difícil o dependiente de condiciones secundarias. |

La confianza puede ser:

```text
alta
media
baja
```

Baja cuando la carta no es radical o hay ASC temprano/tardío. Media cuando hay Luna vacía o aspecto duro. Alta cuando la carta es limpia y la ruta es directa/favorable.

---

## 13. Tiempo simbólico

Cuando hay ruta de perfección, el motor estima un rango simbólico a partir de:

- grados hasta perfección;
- casa del cuerpo más rápido;
- modalidad del signo.

Regla general:

| Condición | Unidad típica |
|---|---|
| Angular + cardinal | días |
| Angular + mutable | semanas |
| Angular + fijo | meses |
| Sucedente + cardinal | semanas |
| Sucedente + fijo/mutable | meses |
| Cadente + cardinal/mutable | meses |
| Cadente + fijo | años |

La salida se expresa como, por ejemplo:

```text
aprox. 4 semanas
aprox. 2 meses
tiempo condicionado por mediación
```

Es timing simbólico horaria, no predicción cronológica absoluta.

---

## 14. Presentación en la UI

`HoraryResultView` renderiza primero el juicio estructurado si existe.

### Panel izquierdo

- Pregunta y datos de la consulta.
- Casa del asunto.
- ASC, MC, hora planetaria y secta.
- Significadores y co-significadores.
- Ruta de perfección.
- Dignidades relevantes.
- Consideraciones activas.
- Tabla de cuerpos y partes.

### Panel derecho

- Veredicto y confianza.
- Motivo principal.
- Ruta, aspecto y tiempo.
- Consultante, quesited y Luna.
- Interpretación IA local opcional.
- Luna y curso.
- Factores a favor.
- Factores en contra.
- Notas técnicas.

Si una consulta antigua solo tiene texto legacy, la vista lo parte por secciones y lo muestra sin exigir campos nuevos.

---

## 15. Interpretación local opcional

La lectura generativa de Horaria es opcional y local.

`HoraryFoundryClient` envía a un script local:

- request;
- chart;
- judgement;
- judgementText.

El modelo debe devolver JSON con:

- respuesta;
- confianza;
- título;
- resumen;
- interpretación;
- lectura técnica;
- cautelas;
- metadatos de generación.

Variables de entorno:

```bash
ASTROMALIK_FOUNDRY_PYTHON=/ruta/al/python
ASTROMALIK_FOUNDRY_HORARY_SCRIPT=/ruta/scripts/foundry_horary_once.py
ASTROMALIK_FOUNDRY_MODEL=qwen2.5-7b
```

Esta capa no recalcula la carta ni decide el juicio. Solo redacta a partir de los datos técnicos ya producidos por AstroMalik.

---

## 16. Modo legado Python

El modo Python se conserva por compatibilidad y diagnóstico.

Variables:

```bash
ASTROMALIK_HORARIA_ENGINE=python   # fuerza motor legacy
ASTROMALIK_HORARIA_ENGINE=swift    # fuerza Swift sin fallback
ASTROMALIK_PYTHON_PATH=/ruta/a/python3
ASTROMALIK_HORARIA_PATH=/ruta/al/repo/horaria
```

`HoraryDiagnosticsView` informa de:

- Python detectado;
- versión;
- fuente del módulo;
- path del módulo;
- fuentes revisadas;
- último error.

El diagnóstico no es necesario para el uso normal de la app.

---

## 17. Validación y tests

Tests principales:

```text
Tests/AstroMalikTests/HoraryParityTests.swift
Tests/AstroMalikTests/HoraryFoundryClientTests.swift
```

La suite valida:

- generación de juicio estructurado por el motor nativo;
- cálculo de consultas reales guardadas sin depender de Python;
- decodificación de JSON legacy sin campos estructurados;
- caso histórico de Lilly sobre pescado robado;
- caso de mudanza con perfección directa por trígono;
- Luna vacía al final de signo no aceptada como perfección posterior;
- “sin perfección + Luna vacía” no devuelve un “sí” limpio;
- parsing de salida JSON de Foundry Local.

La horaria ya no busca paridad literal con Python. Python queda como referencia histórica, no como fuente de verdad.

---

## 18. Limitaciones actuales

V1 es deliberadamente conservador. Limitaciones conocidas:

- No usa planetas transpersonales en juicio horario.
- No modela todas las variantes clásicas de prohibición, frustración, refranación o abscisión.
- Translación y colección son básicas; no incluyen todavía toda la casuística de recepción, combustión o impedimento del mediador.
- El timing es simbólico y debe ser interpretado por el astrólogo.
- El veredicto `no` categórico se usa con prudencia; V1 prefiere `no_todavia`, `dudoso` o `requiere_mediacion` cuando la técnica no permite una negativa limpia.
- La hora planetaria usa cálculo solar aproximado suficiente para radicalidad operativa, no una librería astronómica dedicada a ortos/ocasos.
- La interpretación Foundry depende del entorno local del usuario y es opcional.

---

## 19. Decisiones de diseño

### 19.1 Motor Swift como fuente de verdad

El motor nativo evita depender de un paquete Python externo en el flujo normal. Esto mejora empaquetado, reproducibilidad y testabilidad.

### 19.2 Juicio estructurado antes que prosa

La UI consume datos: veredicto, ruta, significadores, dignidades, factores y advertencias. La prosa es salida secundaria.

### 19.3 Compatibilidad hacia atrás

Los campos nuevos de `HoraryJudgement` son opcionales para que consultas guardadas antiguas sigan abriendo.

### 19.4 Prudencia interpretativa

La app no intenta convertir una carta horaria ambigua en una respuesta tajante. Cuando la técnica no da base suficiente, el veredicto refleja incertidumbre.

---

## 20. Resumen ejecutivo

Horaria en AstroMalik macOS es un módulo local y profesional que:

- levanta carta horaria con Swiss Ephemeris;
- calcula casas Regiomontanus;
- usa siete planetas tradicionales;
- evalúa dignidades, hora planetaria, consideraciones y recepción;
- resuelve perfección directa, translación o colección;
- respeta la regla crítica de Luna fuera de curso antes de cambio de signo;
- devuelve juicio estructurado con veredicto, confianza, factores y timing;
- guarda la consulta completa en SQLite;
- permite lectura local opcional con Foundry sin sustituir el juicio técnico.

El resultado es una horaria reproducible, auditable y útil para trabajo astrológico real dentro de la app.
