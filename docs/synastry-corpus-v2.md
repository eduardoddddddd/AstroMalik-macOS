# Corpus de sinastría v2

**Estado:** implementado y validado

**Fecha de la intervención:** 25 de julio de 2026

**Base de producción:** `Sources/AstroMalik/Resources/corpus.db`

**Migración:** `Resources/migrations/008_synastry_corpus_v2.sql`

Este documento describe la sustitución y el endurecimiento del **corpus
atómico de interpretaciones**, además de su integración actual en la lectura
SwiftUI. La presentación agrupa y personaliza estas 500 unidades semánticas sin
modificar su contenido almacenado.

## Motivo de la sustitución

La auditoría de julio de 2026 encontró que los 420 registros anteriores de
`tipo = 'sinastria'` no eran adecuados para una comparación natal entre dos
personas:

- todos procedían de una sola fuente, Grupo Venus;
- sus URLs usaban `tabla=tracompu`;
- abundaban expresiones predictivas como «ahora», «hoy» o «este momento»;
- el texto describía acontecimientos temporales de la relación, no un contacto
  estable entre el planeta de A y el planeta de B;
- faltaban 80 de las 500 claves posibles, incluidas las conjunciones de un
  planeta consigo mismo y varios contactos entre planetas lentos.

La cifra de cobertura anterior —420 de 500— ocultaba por tanto un problema
semántico. La versión 2 sustituye esos registros, no los mezcla con material
incompatible.

### Resumen de la auditoría

| Criterio | Corpus anterior | Corpus v2 |
|---|---:|---:|
| Filas de sinastría | 420 | 500 |
| Pares planetarios direccionales | 84 de 100 | 100 de 100 |
| Aspectos por par cubierto | 5 | 5 |
| Fuente editorial | Grupo Venus / `tracompu` | AstroMalik v2 |
| Lenguaje temporal | Presente | Rechazado automáticamente |
| Longitud mínima del texto largo | No garantizada | 1.350 caracteres |
| Calidad declarada | 4 | 5 |

## Resultado

- **500 interpretaciones**: 10 planetas de A × 10 planetas de B × 5 aspectos.
- **Cobertura completa** de conjunción, sextil, cuadratura, trígono y oposición.
- **Direccionalidad explícita**: siempre se distingue qué función aporta la
  persona A y qué área de la persona B recibe el contacto.
- **Castellano original**: no son traducciones ni reformulaciones de páginas
  comerciales contemporáneas.
- **Cuatro capas por texto**: mecanismo, potencial, sombra y uso constructivo.
- **No determinismo**: cada entrada recuerda que el orbe, las casas y el estado
  natal de los planetas modifican el resultado.
- **Jerarquía implícita**: los contactos personales se describen como
  directamente interpersonales; los contactos lento–lento se identifican como
  principalmente generacionales salvo exactitud, angularidad o enlace con
  planetas personales.

Los términos A y B son **marcadores internos de direccionalidad**, no nombres
que deban mostrarse literalmente al usuario. Permiten conservar la diferencia
entre `planeta de la primera persona → planeta de la segunda` y la dirección
inversa. `SynastryNaming` los sustituye siempre por los nombres reales —o por
la fecha de nacimiento si falta el nombre— sin duplicar ni reescribir el
corpus. La sustitución cubre tanto «persona A/B» como tokens autónomos («de A»,
«B puede», «A necesita») y notaciones «A→B».

El generador reproducible está en
[`scripts/build_synastry_corpus.py`](../scripts/build_synastry_corpus.py).

## Qué se redactó y qué no se copió

Las 500 interpretaciones de producción son una redacción editorial original de
AstroMalik. Las obras históricas se consultaron para:

- sostener el principio de comparar ambas natividades;
- fijar la naturaleza funcional de cada planeta;
- distinguir cooperación, tensión, facilidad y polaridad;
- evitar tratar un planeta o aspecto como automáticamente bueno o malo;
- recordar que ningún contacto aislado sustituye la síntesis de las cartas.

No se incorporó prosa de páginas astrológicas comerciales contemporáneas, ni
se tradujeron automáticamente artículos modernos para presentarlos como texto
propio. Esta separación permite mantener trazabilidad doctrinal sin introducir
material de copyright incierto.

## Fundamento doctrinal

Las fuentes se usan para fijar principios y vocabulario planetario. El texto
final es una síntesis editorial nueva, no una traducción literal.

### 1. Ptolomeo — *Tetrabiblos*, libro IV

- Capítulo V: compara las luminarias de dos natividades y distingue
  configuraciones concordantes y discordantes.
- Capítulo VII: formula expresamente la comparación de Sol, Luna, Ascendente y
  Parte de Fortuna entre dos cartas; diferencia vínculos duraderos de contactos
  ocasionales y pide ponderar planetas que testimonian esas posiciones.
- Fuente: [Project Gutenberg, ebook 70850](https://www.gutenberg.org/ebooks/70850).
- Estado documentado: obra antigua y traducción de 1822; Project Gutenberg la
  distribuye como dominio público en Estados Unidos.

### 2. Sepharial — *Astrology: How to Make and Read Your Own Horoscope*

- Expone la comparación de horóscopos mediante contactos entre puntos
  personales y planetas de la otra carta.
- Aporta significaciones planetarias modernas tempranas, incluyendo Urano y
  Neptuno, y advierte que el resultado depende de la naturaleza del planeta y
  de la cualidad del aspecto.
- Fuente: [Project Gutenberg, ebook 46963](https://www.gutenberg.org/ebooks/46963).
- Estado documentado: el autor murió en 1929; Project Gutenberg distribuye la
  edición como dominio público en Estados Unidos.

### 3. Max y Augusta Foss Heindel — *The Message of the Stars*

- El capítulo VI propone combinar las naturalezas intrínsecas de los planetas
  mediante razonamiento, en vez de tratar cada planeta como bueno o malo de
  forma absoluta.
- Esa regla inspira la estructura «recurso + exceso + modo consciente» del
  corpus.
- Fuente: [Wikisource, capítulo VI](https://en.wikisource.org/wiki/The_Message_of_the_Stars/Chapter_6).
- Estado: Wikisource marca la obra como dominio público mundial.

### 4. Alan Leo — *How to Judge a Nativity*

- Se usa como apoyo para la síntesis y para evitar leer un aspecto aislado del
  conjunto de la carta.
- Fuente: [Biblioteca Particular Fernando Pessoa](https://bibliotecaparticular.casafernandopessoa.pt/1-94).
- Estado: obra de 1912; Alan Leo murió en 1917 y la obra está en dominio
  público en la Unión Europea.

### Plutón

Las fuentes clásicas y la mayoría de las fuentes públicas anteriores a 1930 no
pueden fundamentar a Plutón. Sus textos se identifican como una **capa editorial
moderna de AstroMalik**, construida alrededor de poder, compulsión, pérdida,
intimidad profunda y transformación. No se atribuyen a Ptolomeo ni a autores
que no conocieron el planeta.

## Modelo editorial

Cada clave `SYN_<PLANETA_A>_<PLANETA_B>_<ASPECTO>` se redacta con estas reglas:

1. **Manda el planeta más lento, esté en la carta que esté.** La geometría es
   recíproca, pero la experiencia no: en un Luna–Saturno es la persona Saturno
   quien estructura, sea A o B. La clave sigue siendo `A → B`, pero los papeles
   de agente y receptor se reparten por velocidad
   (Luna < Mercurio < Venus < Sol < Marte < Júpiter < Saturno < Urano <
   Neptuno < Plutón). Redactar siempre «A actúa, B recibe» invertía la dinámica
   clásica en la mitad de las entradas.

   Consecuencia para la interfaz: entre planetas distintos las dos direcciones
   describen la misma dinámica y se solapan al 99%, así que solo se muestra una
   lectura. Los contactos de un planeta consigo mismo sí conservan las dos, que
   son un espejo real.
2. **El aspecto modula; no sentencia.**
   - conjunción: concentración y superposición;
   - sextil: oportunidad que requiere iniciativa;
   - cuadratura: fricción que desarrolla habilidad;
   - trígono: facilidad que debe hacerse consciente;
   - oposición: polaridad, proyección y complementariedad.
3. **Toda cualidad tiene rango.** Un mismo símbolo puede expresarse como
   capacidad, exceso o defensa.
4. **Se evita predecir hechos.** No se prometen matrimonio, ruptura, fidelidad,
   destino, telepatía ni acontecimientos fechados.
5. **Se evita diagnosticar.** No se asignan patologías, traumas ni intenciones
   ocultas como hechos.
6. **Se mantiene agencia.** El texto ofrece una práctica concreta para A y otra
   para B.
7. **Se contextualiza la relevancia.** Un contacto generacional no desplaza a
   luminarias, planetas personales, ángulos, casas u orbes.
8. **Se redacta en epiceno.** La aplicación sustituye «la persona A/B» por el
   nombre real de cada carta, así que ningún adjetivo ni participio puede
   concordar en género con el rol: «resulta apreciada» se convertiría en
   «Carlos resulta apreciada». Se usan formas neutras («recibe aprecio»).

### Estructura de cada interpretación

1. **Mecanismo:** explica cómo la función del planeta emisor entra en el campo
   simbolizado por el planeta receptor.
2. **Potencial:** describe la capacidad que puede desarrollarse cuando ambas
   personas colaboran conscientemente.
3. **Sombra:** señala exceso, defensa, proyección o automatismo sin convertirlo
   en diagnóstico.
4. **Práctica:** propone una acción diferenciada para cada parte y devuelve
   agencia a la relación.
5. **Contexto:** recuerda el peso del orbe, las casas, la condición natal y el
   carácter personal, social o generacional de los planetas.

## Arquitectura e integración

### Lectura SwiftUI actual

`AstroEngine.computeSynastryAspects` conserva el cálculo direccional A→B y B→A
porque cada clave del corpus describe una experiencia distinta. La capa de
presentación no expone ese resultado como dos contactos físicos:

1. `SynastryContact` identifica canónicamente el planeta de la primera carta,
   el planeta de la segunda y el aspecto.
2. Empareja el `SynastryAspect` A→B con su recíproco B→A.
3. La rueda dibuja una sola línea y la vista crea un único bloque de contacto.
4. Dentro del bloque se muestran siempre, y completos, los dos textos largos:
   «Cómo lo vive [nombre 1] → [nombre 2]» y la dirección inversa.

No hay paneles plegables, pestañas ni botones «Leer más». Los grupos de
contactos personales, personal–lento y generacionales mantienen el orden
editorial, pero todo su contenido queda visible desde el principio.

`SynastrySynthesis` calcula sobre contactos únicos:

- balance ponderado de sextiles/trígonos frente a
  cuadraturas/oposiciones;
- conjunciones como integración, sin clasificarlas automáticamente como
  favorables o tensas;
- mayor peso de luminarias y funciones personales;
- contacto personal más exacto como tema central;
- *double whammies* cuando el mismo par planetario aparece intercambiado entre
  las dos cartas.

La personalización mediante `SynastryNaming` se comparte entre la vista, el
constructor de notas Joplin y `SynastryReportBuilder`. El corpus permanece
intacto: los nombres se insertan exclusivamente en tiempo de presentación.

### Generación y promoción

`scripts/build_synastry_corpus.py` construye el producto cartesiano completo de
planetas y aspectos a partir de perfiles editoriales revisables. Sus tres modos
son:

```bash
# Comprueba invariantes del contenido y de la base, si ya está promovida.
python3 scripts/build_synastry_corpus.py --check

# Sustituye el corpus de producción y compacta la base SQLite.
python3 scripts/build_synastry_corpus.py --apply-db

# Regenera la migración SQL reproducible.
python3 scripts/build_synastry_corpus.py --write-migration
```

La promoción se ejecuta dentro de una transacción inmediata. Elimina las filas
de Grupo Venus y las filas pertenecientes a una versión previa de
`AstroMalik — síntesis editorial de sinastría v2`; después inserta las 500
entradas y ejecuta `VACUUM`. Las interpretaciones de otras fuentes no se borran.

La compactación redujo el artefacto de producción de **8.511.488 a 6.053.888
bytes** después de las reinserciones de desarrollo.

### Migración

`Resources/migrations/008_synastry_corpus_v2.sql` reproduce la misma
sustitución. `MigrationRunner.isCorpusMigration` enruta el prefijo `008_` hacia
`corpus.db`, no hacia `user.db`. La migración puede ejecutarse repetidamente:
el resultado estable son 500 filas v2 sin duplicar claves.

### Pipeline de fuentes

El catálogo `corpus_sources/source_catalog.json` registra autor, título, año,
alcance, URL de descarga, página de procedencia, formato y nota de derechos.
El pipeline `scripts/corpus_pipeline.py` se amplió para:

- extraer obras en formato TXT;
- seleccionar para sinastría solo fuentes cuyo `module_scope` la incluya;
- limitar candidatos por fuente para que una obra no monopolice el staging;
- rechazar respuestas HTTP de cuerpo vacío;
- descartar cachés locales de cero bytes;
- conservar fragmentos candidatos para revisión, no para publicación
  automática.

## Control de calidad automático

El generador rechaza el corpus si:

- no contiene exactamente 500 claves únicas;
- falta alguna combinación 10 × 10 × 5;
- un texto largo tiene menos de 1.350 caracteres;
- no aparecen los roles «persona A» y «persona B»;
- reaparece lenguaje temporal impropio (`ahora`, `hoy`, `este momento`,
  `temporalmente`);
- algún adjetivo o participio concuerda en género con el rol de A o de B;
- queda un marcador `{AGENT}` o `{RECEIVER}` sin sustituir;
- dos claves producen el mismo texto largo;
- la base de producción no queda con 500 filas españolas de calidad 5.

Además, el corpus final impone que:

- las 500 claves y los 500 textos largos sean únicos;
- cada par contenga exactamente los cinco aspectos admitidos;
- los textos largos midan entre **1.919 y 2.397 caracteres** en esta versión;
- `idioma_origen = 'es'`, `calidad = 5` y la fuente editorial sea estable;
- no reaparezcan «ahora», «hoy», «este momento», «en estos momentos» ni
  «temporalmente».

## Validación ejecutada

La entrega inicial del corpus v2 se comprobó con:

- `python3 -m py_compile` para el generador y el pipeline;
- `python3 scripts/build_synastry_corpus.py --check`;
- `python3 scripts/corpus_pipeline.py smoke-test`;
- aplicación de la migración dos veces sobre una copia temporal;
- `PRAGMA integrity_check`, con resultado `ok`;
- consultas SQLite de cobertura, fuente, idioma, calidad y longitudes;
- suite Swift completa tras la integración: **396 pruebas ejecutadas, 1
  omitida y 0 fallos**;
- prueba exhaustiva de las 500 filas × 2 campos × 2 direcciones: **2.000
  presentaciones**, todas con ambos nombres y sin marcadores A/B residuales;
- generación del PDF de sinastría;
- `scripts/package_app.sh`;
- comprobación de la migración y del `corpus.db` dentro del bundle;
- `codesign --verify --deep --strict AstroMalik.app`.

El bundle validado contenía 500 claves distintas, calidad 5 y textos largos de
1.919–2.397 caracteres.

## Archivos de esta intervención

| Archivo | Responsabilidad |
|---|---|
| `scripts/build_synastry_corpus.py` | Generación, validación, promoción y compactación |
| `Sources/AstroMalik/Resources/corpus.db` | Corpus efectivo distribuido con la aplicación |
| `Resources/migrations/008_synastry_corpus_v2.sql` | Sustitución idempotente del corpus |
| `corpus_sources/source_catalog.json` | Registro de fuentes y condiciones de uso |
| `scripts/corpus_pipeline.py` | Descarga, extracción y staging robusto |
| `Sources/AstroMalik/Models/Interpretation.swift` | Conservación separada de `texto_corto` y `texto_largo` |
| `Sources/AstroMalik/Models/Synastry.swift` | Contactos únicos, dos lentes, nombres, síntesis, prioridad y *double whammies* |
| `Sources/AstroMalik/Store/CorpusStore.swift` | Hidratación conjunta de textos corto y largo |
| `Sources/AstroMalik/Views/SynastryView.swift` | Síntesis, rueda y textos direccionales siempre completos |
| `Sources/AstroMalik/Reports/Builders/SynastryReportBuilder.swift` | Nombres reales y síntesis coherente en PDF |
| `Sources/AstroMalik/Persistence/MigrationRunner.swift` | Enrutamiento de la migración 008 |
| `Tests/AstroMalikTests/AstroEngineTests.swift` | Cobertura, emparejamiento, nombres y prueba exhaustiva de presentación |
| `Tests/AstroMalikTests/TechnicalDebt1And2Tests.swift` | Convención de migraciones de corpus |

## Límites pendientes

El corpus v2 mejora radicalmente la pertinencia y la cobertura, pero una lectura
profesional todavía puede ampliar:

- superposición de planetas por casas;
- contactos con ASC y MC;
- dignidad, condición y regencia natal de cada planeta;
- orbe y angularidad;
- diferencia entre vínculos románticos, familiares, amistosos y profesionales.

Los contactos recíprocos, el balance general, el tema central y los *double
whammies* ya se sintetizan en Swift. Los factores restantes deben abordarse en
el motor de síntesis, no multiplicando afirmaciones absolutas dentro de cada
entrada atómica.
