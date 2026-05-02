# Direcciones Primarias en AstroMalik

Documento técnico y editorial del módulo de Direcciones Primarias de AstroMalik-macOS.

## Resumen ejecutivo

El módulo de Direcciones Primarias es una de las piezas más ambiciosas de AstroMalik. No es una lista simbólica de progresiones ni una aproximación por tránsito: calcula direcciones primarias con geometría ecuatorial, espéculo Regiomontano y claves temporales tradicionales. Su objetivo es ofrecer una herramienta de consulta profesional que combine:

- cálculo astronómico determinista;
- trazabilidad técnica visible;
- corpus clásico curado;
- lectura contextual opcional;
- navegación usable para años, edades y eventos concretos.

La arquitectura separa deliberadamente tres niveles:

1. **Motor matemático:** calcula arcos, edades y fechas sin intervención generativa.
2. **Corpus clásico:** aporta texto tradicional verificable cuando existe fuente.
3. **Lectura contextual:** redacta una síntesis opcional a partir de factores natales, sin autoridad sobre el cálculo.

Esta separación es importante. La app puede usar Foundry Local u otro cliente contextual para redactar, pero el modelo no decide qué dirección existe, cuándo ocurre ni qué datos técnicos la sostienen.

## Conceptos básicos

Una dirección primaria relaciona un **prómissor** con un **significador** mediante un aspecto y un arco direccional.

- **Prómissor:** planeta o punto que "promete" el acontecimiento.
- **Significador:** punto sensible que recibe la dirección, normalmente asociado a vida, cuerpo, vocación, luminares o fortuna.
- **Aspecto:** relación angular ptolemaica: conjunción, sextil, cuadratura, trígono u oposición.
- **Arco:** distancia direccional en grados ecuatoriales.
- **Clave temporal:** regla que convierte arco en edad.

Ejemplo conceptual:

```text
Marte prómissor -> cuadratura -> Ascendente significador
arco: 24.62 grados
clave: Naibod
edad estimada: 24.55 años
```

El módulo no interpreta el arco como fecha absoluta exacta al día. La fecha estimada es una traducción práctica del arco a calendario para navegación, informe y consulta anual.

## Alcance implementado

El motor actual soporta:

- método Regiomontano;
- espéculo Regiomontano completo;
- direcciones directas;
- direcciones conversas;
- plano zodiacal;
- plano mundano;
- plano de longitud zodiacal de compatibilidad;
- claves Naibod, Ptolomeo y Brahe;
- cinco aspectos ptolemaicos;
- siete planetas clásicos;
- transpersonales en preajustes extendidos;
- Ascendente, Medio Cielo, Descendente e IC donde el preajuste lo permite;
- Sol, Luna y significadores planetarios configurables;
- Pars Fortunae con fórmula dependiente de secta;
- corpus clásico Lilly para el alcance clásico poblado;
- interpretación contextual opcional con Foundry Local;
- informes Joplin filtrados o por dirección seleccionada.

## Flujo de cálculo

El cálculo vive principalmente en:

- `Sources/AstroMalik/PrimaryDirections/Calculation/PrimaryDirectionCalculator.swift`
- `Sources/AstroMalik/PrimaryDirections/Calculation/RegiomontanusProjection.swift`
- `Sources/AstroMalik/PrimaryDirections/Models/PrimaryDirection.swift`
- `Sources/AstroMalik/PrimaryDirections/PrimaryDirectionsService.swift`

El flujo general es:

1. Convertir la fecha natal a día juliano UT.
2. Obtener oblicuidad verdadera de la eclíptica.
3. Calcular RAMC con Swiss Ephemeris.
4. Construir coordenadas ecuatoriales de planetas y puntos.
5. Resolver prómissores y significadores activos según preajuste/configuración.
6. Calcular arcos directos.
7. Calcular arcos conversos si están activados.
8. Convertir arco en edad con la clave temporal elegida.
9. Estimar fecha calendario desde la edad.
10. Asignar peso interpretativo para filtro y UI.
11. Enriquecer con corpus clásico cuando existe texto curado.
12. Preparar línea temporal, tabla, detalle e informes.

El cálculo se ejecuta fuera del `MainActor` para no bloquear la interfaz. La UI recibe el resultado ya estructurado y filtrable.

## Regiomontanus y espéculo

El núcleo técnico usa proyección Regiomontana adaptada del enfoque de Morinus. Para cada cuerpo o punto relevante se calculan datos como:

- ascensión recta;
- declinación;
- distancia meridiana;
- polo;
- `Q`;
- `W`;
- posición oriental/occidental;
- relación con RAMC e IC.

El detalle de cada dirección muestra la información técnica necesaria para auditar el cálculo. Esto es una decisión de diseño: una dirección primaria no debe ser una caja negra. El usuario puede ver el arco, el plano, la clave, la edad, el tipo de dirección y los datos del espéculo que sostienen el resultado.

## Direcciones directas y conversas

Las direcciones directas y conversas se calculan como dos pasadas astronómicas distintas.

En una **dirección directa**, el significador permanece como referencia. Para cada significador, prómissor y aspecto, el arco se calcula usando el espéculo y el polo Regiomontano del significador.

En una **dirección conversa**, el cálculo invierte los roles astronómicos. El prómissor original queda como referencia fija, se construye su espéculo y el significador original se dirige hacia ese punto. La dirección conserva las etiquetas interpretativas originales, pero se marca como `conversa`.

Esto evita un error común: derivar la conversa solamente cambiando el signo del arco. En AstroMalik, la conversa no es un atajo de presentación; es una segunda operación geométrica.

## RAMC y oblicuidad

El RAMC se calcula con:

```text
swe_sidtime0(jd, eps, dpsi)
```

donde:

- `jd` es el día juliano del nacimiento;
- `eps` es la oblicuidad verdadera;
- `dpsi` es la nutación en longitud.

Esta decisión mejora la paridad con programas y bibliografía que dependen de la ascensión recta real del Medio Cielo en el momento natal.

## Planos de aspecto

El módulo distingue tres planos:

### Zodiacal

Es el plano por defecto para usuarios nuevos. Aplica el aspecto en longitud eclíptica del significador y proyecta el resultado con lógica Regiomontana. Es el modo más útil para consulta general dentro de la app.

### Mundano

Usa el espéculo y la posición ecuatorial/mundana del punto. Es el modo más cercano a una lectura Regiomontana estricta, especialmente relevante cuando se quiere estudiar la geometría primaria con detalle.

### Longitud zodiacal

Es un modo de compatibilidad. Calcula por diferencia simple de longitud eclíptica y sirve para reproducir informes simbólicos o comparar con salidas menos estrictas. No debe confundirse con el núcleo Regiomontano del módulo.

## Claves temporales

Las claves convierten arco en edad:

- **Naibod:** usa movimiento solar medio.
- **Ptolomeo:** usa 1 grado por año.
- **Brahe:** usa el arco real de ascensión recta recorrido por el Sol entre el nacimiento y las 24 horas siguientes.

La clave Brahe requiere conocer o calcular el movimiento solar natal. Cuando la app dispone de esa información, convierte la variación solar a un equivalente de ascensión recta para estimar la edad.

## Pars Fortunae

Pars Fortunae se calcula con fórmula dependiente de secta:

```text
Día:    ASC + Luna - Sol
Noche:  ASC + Sol - Luna
```

El motor la registra como cuerpo direccional disponible. No forma parte del preajuste clásico mínimo por defecto como prómissor visible en todos los flujos, pero puede activarse mediante configuración/preajustes y está cubierta por el corpus clásico en la tanda Lilly.

## Presets y control de ruido

Las direcciones primarias generan muchas combinaciones. Sin filtros, una carta puede producir un volumen difícil de consultar. Por eso el módulo incorpora preajustes:

| Preajuste | Uso recomendado | Alcance |
|---|---|---|
| Clásico | Consulta sobria y tradicional | siete planetas, Pars Fortunae, ASC, MC, Sol, Luna y aspectos ptolemaicos |
| Extendido | Investigación predictiva moderna | añade Urano, Neptuno, Plutón y significadores adicionales |
| Completo | Auditoría o exploración amplia | incluye todos los puntos disponibles y reduce filtros |

Cada dirección recibe un peso:

- **Crítica:** dirección de máxima prioridad visual.
- **Mayor:** dirección principal de lectura.
- **Moderada:** dirección útil, pero subordinada.
- **Menor:** dirección secundaria o de investigación.

Estos pesos no son una verdad doctrinal absoluta. Son una capa de usabilidad para reducir ruido, ordenar una tabla grande y ayudar a escoger qué mirar primero. El criterio puede evolucionar con revisión astrológica, especialmente en el tratamiento de transpersonales y benéficos/maléficos sobre ángulos.

## Corpus clásico

La Capa 1 del módulo es el corpus clásico. Su tabla principal es:

```text
primary_direction_meanings
```

La migración `006_populate_pd_classical_corpus.sql` incorporó 165 interpretaciones clásicas desde William Lilly, `Christian Astrology`, Libro III, sección de efectos de direcciones.

El alcance poblado cubre:

- cinco significadores hylegiales usados por el motor;
- siete prómissores clásicos;
- cinco aspectos ptolemaicos;
- exclusión de identidades sin sentido operativo, como `SOL_SOL_*` y `LUNA_LUNA_*`.

La política de corpus es estricta:

- solo se marca `populated = 1` cuando hay fuente trazable;
- las claves sin fuente suficiente no se presentan como corpus principal;
- los textos generativos no poblan la tabla clásica;
- la UI prioriza corpus curado sobre lectura contextual;
- las referencias se documentan en informe de población.

Documentos relacionados:

- `docs/primary-directions-corpus-curation.md`
- `corpus_sources/reports/pd_corpus_population_report.md`

## Lectura contextual opcional

La Capa 2 añade una lectura contextual opcional. En la integración actual, Swift invoca:

```text
scripts/foundry_primary_direction_once.py
```

El flujo es:

```text
SwiftUI
-> PrimaryDirectionFoundryClient
-> proceso Python one-shot
-> Foundry Local SDK
-> modelo local
-> JSON estructurado
-> ContextualInterpretation
```

Por defecto se usa `qwen2.5-7b`, configurable con:

```text
ASTROMALIK_FOUNDRY_MODEL
ASTROMALIK_FOUNDRY_PYTHON
ASTROMALIK_FOUNDRY_PD_SCRIPT
ASTROMALIK_FOUNDRY_MODEL_CACHE_DIR
```

La lectura contextual incorpora:

- estado natal del prómissor;
- estado natal del significador;
- dignidades esenciales y accidentales;
- secta;
- recepciones;
- casas natales implicadas;
- regencias;
- aspecto formado;
- periodo estimado de activación.

El resultado se guarda en caché en `user.db` con versión de instrucciones. Si cambia la versión, las interpretaciones antiguas quedan invalidadas sin requerir una migración de esquema.

## Persistencia y privacidad

El corpus distribuido vive en la app. Las interpretaciones contextuales generadas para una carta concreta viven en la base local del usuario:

```text
~/Library/Application Support/AstroMalik/user.db
```

Esto significa que:

- las cartas del usuario no se guardan en el corpus;
- las interpretaciones personales no se suben al repositorio;
- el corpus clásico es común y distribuible;
- la caché contextual es privada del usuario.

## Interfaz de usuario

La UI de Direcciones Primarias está pensada como una mesa de trabajo, no como una simple lista.

### Cabecera

La cabecera concentra:

- carta activa;
- preajuste;
- filtros;
- clave temporal;
- plano;
- acciones Joplin;
- estado de Foundry Local;
- aviso de política de corpus.

### Línea temporal

La línea temporal permite recorrer la vida por edades. Usa carriles semánticos por significador y agrupa eventos densos cuando es necesario. El objetivo no es decorar: es hacer visible cuándo se concentran direcciones relevantes.

### Panel principal

El panel izquierdo ofrece tres formas de exploración:

- **Lista profesional:** tabla nativa ordenable por edad, fecha, prómissor, aspecto, significador, arco, tipo, plano y estado de texto.
- **Cards:** lectura visual en tarjetas, más cómoda para exploración.
- **Año en curso:** consulta anual con ventana residual de activación de ±18 meses.

### Detalle

El detalle de una dirección muestra:

- título de la dirección;
- edad exacta;
- fecha estimada;
- ventana de activación;
- tipo directa/conversa;
- plano;
- peso;
- corpus principal si existe;
- lectura contextual si existe;
- lectura local auxiliar;
- factores contextuales;
- espéculo Regiomontano;
- datos técnicos de cálculo.

## Informes Joplin

El módulo puede crear notas en Joplin mediante Web Clipper local. Hay dos salidas principales:

- nota de la dirección seleccionada;
- informe filtrado con el conjunto visible.

La generación de notas está separada en:

```text
PrimaryDirectionsNoteBuilder
JoplinClipperService
```

Joplin no participa en el cálculo. Es únicamente una salida documental.

## Validación

La validación se apoya en tests de regresión y escenarios de control:

- `PrimaryDirectionsTests.swift`
- `PrimaryDirectionsGoldenTests.swift`
- `PrimaryDirectionFoundryClientTests.swift`
- `Phase4ContextualInterpreterTests.swift`
- `Phase5ViewModelTests.swift`
- `TechnicalDebt1And2Tests.swift`
- `Tests/AstroMalikTests/PRIMARY_DIRECTIONS_TESTS.md`

Las pruebas de referencia congelan:

- total de direcciones por carta;
- primeras direcciones ordenadas por arco;
- directas y conversas;
- RAMC;
- oblicuidad;
- espéculo Regiomontano de planetas, ASC y MC.

Cartas de control actuales:

- Eduardo: Madrid, 11 octubre 1976, 20:33, `Europe/Madrid`.
- Buenos Aires: hemisferio sur.
- Reykjavik: latitud alta.

Estas cartas cubren casos reales, latitudes distintas y zonas donde la geometría puede volverse más delicada.

## Evaluación técnica

El módulo está especialmente bien resuelto en estos puntos:

- cálculo geométrico real, no interpolación simbólica;
- separación clara entre cálculo, corpus y redacción contextual;
- soporte de directas y conversas como operaciones separadas;
- exposición de espéculo y datos técnicos;
- ejecución fuera del hilo principal;
- corpus clásico trazable;
- pruebas de referencia para detectar regresiones;
- UI pensada para consulta, no solo para depuración.

En términos de arquitectura, el módulo está por encima de una implementación astrológica superficial. Tiene estructura de software profesional: cálculo puro, modelos codificables, servicio orquestador, ViewModel aislado en `MainActor`, tests de regresión, corpus versionado y salida documental separada.

## Límites conocidos y evolución razonable

Hay áreas que conviene presentar como evolución futura, no como resueltas:

- direcciones por términos;
- antiscios;
- selección avanzada de hyleg y alcocoden;
- comparación con más programas externos de referencia;
- parametrización más amplia de sistemas de casas en otros módulos;
- revisión fina del sistema de pesos para transpersonales, benéficos y maléficos;
- documentación matemática más extensa con fórmulas paso a paso;
- ampliación del corpus clásico más allá de Lilly;
- soporte editorial para fuentes como Bonatti, Ptolomeo, Coley o Morin con trazabilidad completa.

Esta honestidad forma parte del diseño. AstroMalik no marca como clásico lo que no está verificado, y no oculta qué capas son cálculo, corpus, heurística o redacción contextual.

## Archivos principales

```text
Sources/AstroMalik/PrimaryDirections/
├── Calculation/
│   ├── PrimaryDirectionCalculator.swift
│   └── RegiomontanusProjection.swift
├── Corpus/
│   └── PrimaryDirectionCorpusStore.swift
├── Interpretation/
│   ├── ContextualInterpretation.swift
│   ├── PDInterpretationContextBuilder.swift
│   ├── PrimaryDirectionContextualInterpreter.swift
│   ├── PrimaryDirectionFoundryClient.swift
│   └── PrimaryDirectionLocalReading.swift
├── Models/
│   ├── PDFilterPreset.swift
│   ├── PDWeight.swift
│   ├── PrimaryDirection.swift
│   ├── PrimaryDirectionKey.swift
│   ├── PrimaryDirectionMethod.swift
│   └── SpeculumRow.swift
├── ViewModels/
│   └── PrimaryDirectionsViewModel.swift
├── Views/
│   ├── CurrentYearView.swift
│   ├── PrimaryDirectionDetailView.swift
│   ├── PrimaryDirectionFiltersView.swift
│   ├── PrimaryDirectionsTableView.swift
│   ├── PrimaryDirectionsTimelineView.swift
│   ├── PrimaryDirectionsView.swift
│   └── SpeculumTableView.swift
├── PrimaryDirectionsNoteBuilder.swift
└── PrimaryDirectionsService.swift
```

## Conclusión

Direcciones Primarias es un módulo central de AstroMalik porque resume bien la filosofía del proyecto: cálculo serio, documentación visible, corpus honesto, privacidad local y herramientas de lectura profesional. Todavía tiene líneas de evolución astrológica, pero su base matemática y arquitectónica ya es sólida.

El punto clave es que el módulo no intenta impresionar escondiendo la complejidad. La expone, la estructura y la convierte en una experiencia utilizable.
