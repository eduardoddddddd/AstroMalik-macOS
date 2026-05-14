# Revision arquitectonica de las propuestas de Gemini 3.1 Pro
**Proyecto:** AstroMalik-macOS  
**Autor:** ChatGPT 5.5, criterio de arquitectura principal  
**Fecha:** 2026-05-02  
**Documentos revisados:**
- `docs/analisis_gemini3.1pro.md`
- `docs/plan_implementacion_gemini3.1pro.md`
- `docs/detailed_implementation_plan.md`

## 1. Veredicto ejecutivo

Gemini ha hecho una lectura muy buena del producto: entiende que AstroMalik no es una app astrologica ligera, sino una herramienta profesional local-first con un sesgo deliberado hacia astrologia tradicional, calculo determinista y salida documental seria. Su seleccion de mejoras tambien apunta en la direccion correcta: primero tecnicas de alto valor astrológico y bajo coste relativo, despues ampliaciones modernas y relacionales, y al final los modulos mas ambiciosos.

Mi criterio como arquitecto principal es este: **no debemos convertir AstroMalik en una coleccion dispersa de tecnicas**. Cada nueva funcion debe entrar como parte del sistema ya existente: modelos Swift nativos, calculo verificable, UI sobria, tests, informes Joplin cuando aporten archivo profesional, y documentacion actualizada. El valor diferencial de AstroMalik esta en la coherencia entre motor, lectura y corpus, no en acumular pantallas.

Por tanto, apruebo la direccion general de Gemini, pero ajustaria el orden y la forma de ejecucion. Las cuatro fases propuestas son utiles como mapa, aunque los prompts necesitan endurecerse: deben pedir inspeccion del repo, integracion real, tests, empaquetado cuando haya codigo/UI y criterios de aceptacion. Tal como estan, pueden producir engines teoricamente correctos pero desconectados de `NatalChart`, `AstroEngine`, `CorpusStore`, la navegacion y los note builders.

## 2. Que implementaria primero

### Prioridad 1: Profecciones anuales y mensuales

Esta es la mejora mas clara para la siguiente fase. Encaja doctrinalmente con Revolucion Solar, Direcciones Primarias y Horaria; aporta muchisimo contexto predictivo; y tecnicamente es barata porque no depende de nuevas llamadas a Swiss Ephemeris.

La implementacion deberia ser mas ambiciosa que una simple tarjeta del "Senor del Ano":
- profeccion anual del Ascendente;
- profecciones mensuales dentro del ano profectado;
- casa natal activada;
- signo profectado;
- senor del ano tradicional;
- estado natal del senor del ano: casa natal, signo, dignidad esencial, retrogradacion;
- enlace conceptual con Revolucion Solar: casa donde cae el senor del ano en la revolucion, si el dato esta disponible.

Arquitectonicamente lo pondria en:
- `Sources/AstroMalik/Engine/TimeLords/ProfectionEngine.swift`
- modelos pequenos `ProfectionRequest`, `AnnualProfection`, `MonthlyProfection`
- tests en `Tests/AstroMalikTests/TimeLordTests.swift`

UI recomendada: una seccion dentro de Revolucion Solar primero, no una pestana nueva. Si luego crecen Firdaria o Liberacion Zodiacal, entonces si merece una seccion principal llamada `Senores del Tiempo`.

### Prioridad 2: Carta compuesta

La carta compuesta es el siguiente paso mas natural porque Sinastria ya existe, ya tiene dos cartas guardadas, rueda doble, corpus y nota Joplin. Es una ampliacion de un flujo existente, no una isla nueva.

Gemini acierta al proponer un selector `[A -> B | B -> A | Compuesta]`, pero yo lo afinaria: Sinastria A/B y B/A son direcciones interpretativas de aspectos, mientras que la Compuesta es una carta sintetica. Mejor seria un segmented control de modo:

```text
Aspectos | Compuesta
```

Dentro de `Aspectos`, se mantienen A sobre B y B sobre A. Dentro de `Compuesta`, se muestra una rueda simple y una tabla tecnica de posiciones compuestas.

Riesgo principal: las casas de una carta compuesta no son tan triviales como los planetas. Para una v1 seria honesto implementar:
- planetas por punto medio del arco corto;
- ASC y MC por punto medio del arco corto;
- casas derivadas como opcion tecnica documentada;
- sin prometer una carta espacio-temporal real.

### Prioridad 3: Progresiones secundarias

Las progresiones son importantes para cubrir astrologia moderna y psicologica, pero deben ir despues de Composite. Requieren mas precision temporal, deteccion de estaciones, aspectos progresado-natal, cambios de signo/casa y una UI de doble rueda.

Gemini propone sumar la edad en dias al JD natal. Correcto como idea base, pero hay que precisar el contrato:
- edad tropical exacta entre nacimiento y fecha objetivo;
- fecha progresada = JD natal + edad en anos tropicales;
- calculo de velocidades con `SEFLG_SPEED`;
- deteccion de cambio de direccion comparando velocidad natal, velocidad progresada y busqueda de estacion cuando haya cruce.

La v1 no deberia intentar explicarlo todo. Bastaria con:
- posiciones progresadas;
- Luna progresada destacada;
- fase soli-lunar progresada;
- aspectos progresados a natal con orbe <= 1 grado;
- estaciones progresadas de Mercurio, Venus y Marte si se detectan.

### Prioridad 4: Estrellas fijas mayores

Astrologicamente son valiosas, pero las pondria despues de Profecciones y Composite, no necesariamente pegadas a Profecciones. Motivo tecnico: aunque `CSwissEph` expone `swe_fixstar2_ut`, el repo no incluye actualmente `sefstars.txt` ni `fixstars.cat`. Swiss Ephemeris tiene algunas estrellas internas, pero no conviene construir una feature profesional sin comprobar antes el recurso exacto, empaquetarlo y testearlo dentro de la app.

Plan correcto:
- crear primero un spike tecnico para confirmar que `swe_fixstar2_ut("Regulus")`, `Spica`, `Algol`, `Sirius`, `Aldebaran` funcionan con los recursos empaquetados;
- si falta catalogo, anadir `sefstars.txt` a `Sources/AstroMalik/Resources/ephe` o a una carpeta de recursos documentada;
- testear que el bundle release puede resolver las estrellas tras `scripts/package_app.sh`.

Solo despues integraria badges en natal. El orbe de 1.5 grados me parece correcto para v1, con opcion futura de 1 grado estricto.

### Prioridad 5: Almuten Figuris y Sizigia prenatal

Muy alineado con el alma medieval del proyecto, pero no lo haria antes de cerrar Profecciones y Composite. Aqui el riesgo no es Swift, sino doctrina: hay varias recetas tradicionales y puntuaciones posibles. Si se implementa, debe ser transparente y configurable o, al menos, documentado con una fuente elegida.

Punto a favor: ya existe `EssentialDignityEngine`, asi que no hay que empezar de cero. Punto a corregir: el motor actual no recibe secta para triplicidades en la API principal; para Almuten necesitaremos exponer una variante que puntue dignidades con secta diurna/nocturna de forma explicita.

V1 recomendable:
- calcular Parte de Fortuna;
- buscar sizigia prenatal con biseccion segura;
- puntuar candidatos;
- mostrar desglose completo;
- documentar la receta usada.

### Prioridad 6: Astrocartografia

La astrocartografia es atractiva visualmente y comercialmente potente, pero no debe entrar todavia como implementacion completa. Es un proyecto propio: trigonometria esferica, MapKit, antimeridiano, rendimiento, leyenda, seleccion de lineas, zoom y validacion visual.

Mi recomendacion es tratarla como investigacion posterior:
- primero un documento tecnico con formulas y referencias;
- despues un prototipo aislado;
- solo entonces integracion en la app.

## 3. Orden de desarrollo recomendado

| Sprint | Alcance | Motivo |
|---|---|---|
| 1 | Profecciones anuales y mensuales integradas en Revolucion Solar | Maximo impacto tradicional con bajo riesgo tecnico |
| 2 | Carta compuesta v1 en Sinastria | Aprovecha UI, modelos y flujo existente |
| 3 | Progresiones secundarias v1 | Cubre astrologia moderna sin romper el nucleo tradicional |
| 4 | Estrellas fijas mayores | Primero resolver recursos `sefstars.txt` y empaquetado |
| 5 | Almuten Figuris + Sizigia prenatal | Alto valor medieval, requiere decision doctrinal |
| 6 | Midpoints / dial 90 grados | Muy util para escuela moderna, aislado y calculable |
| 7 | Astrocartografia | Gran modulo visual, requiere fase de investigacion |

Este orden difiere ligeramente de Gemini: separo Estrellas Fijas de Profecciones por dependencia de recursos, y adelanto Composite frente a Progresiones porque el modulo de Sinastria ya esta listo para recibirlo.

## 4. Evaluacion de los cuatro prompts de Gemini

La estructura en cuatro prompts es buena como herramienta de trabajo incremental. Tiene tres virtudes:
- agrupa funcionalidades por complejidad;
- evita pedir "todo AstroMalik definitivo" en una sola tanda;
- distingue motores, UI y compatibilidad Swift 6.

Pero los prompts tienen debilidades si se usan literalmente:
- piden "codigo completo" sin obligar al agente a leer la arquitectura real;
- no mencionan `scripts/package_app.sh`, requisito del repo tras cambios de codigo/UI;
- no exigen tests;
- no exigen actualizar `docs/ARCHITECTURE.md` o README cuando se anade un modulo mayor;
- no contemplan note builders/Joplin cuando la funcionalidad genera informes;
- no separan spikes tecnicos de features definitivas;
- mezclan en una misma fase tareas con dependencias distintas, como Profecciones y Estrellas Fijas.

Mi recomendacion: mantener la idea de prompts por fase, pero reescribirlos como **encargos de integracion sobre repo existente**, no como generacion de snippets.

## 5. Prompt maestro que usaria para cualquier fase

Antes de cada prompt especifico, anadiria este bloque:

```text
Trabajas en el repo AstroMalik-macOS. Antes de editar, inspecciona los modelos, motores, vistas y tests existentes relacionados con la funcionalidad. No generes codigo aislado: integra la feature en la arquitectura actual de SwiftUI, AstroEngine, modelos Codable/Equatable y stores existentes cuando aplique.

Respeta estas reglas del repo:
- Swift 6, macOS 14+, SwiftUI, SPM, sin dependencias externas salvo que se justifique.
- CSwissEph es el wrapper C de Swiss Ephemeris.
- No usar force unwraps.
- Mantener UI de ventana unica con NavigationSplitView.
- Anadir tests enfocados para el motor nuevo y para cualquier contrato de datos.
- Si hay cambios de codigo o UI, ejecutar `swift test` cuando sea viable y despues `scripts/package_app.sh`.
- Antes de cerrar, comprobar el timestamp de `AstroMalik.app/Contents/MacOS/AstroMalik`.
- Actualizar documentacion si se anade una seccion funcional nueva.

Entrega:
- lista de archivos modificados;
- resumen de decisiones;
- pruebas ejecutadas;
- limitaciones doctrinales o tecnicas que queden documentadas.
```

## 6. Prompt revisado para Sprint 1: Profecciones

```text
Implementa Profecciones Anuales y Mensuales en AstroMalik-macOS.

Contexto:
- La app ya tiene NatalChart, SolarReturnEngine, SolarReturnView, EssentialDignityEngine y RevolutionTemplates.
- La primera integracion UI debe vivir dentro de Revolucion Solar, como contexto predictivo del ano.

Tareas:
1. Crear un motor puro `ProfectionEngine` bajo `Sources/AstroMalik/Engine/TimeLords/`.
2. Calcular edad cumplida exacta para una fecha objetivo usando fecha natal local.
3. Calcular signo profectado anual desde el Ascendente natal, casa natal activada, senor del ano tradicional y profecciones mensuales.
4. Incluir el estado natal del senor del ano: signo, casa, retrogradacion y dignidad esencial.
5. Integrar una tarjeta compacta en `SolarReturnView`.
6. Anadir tests de edades limite: antes del cumpleanos, dia del cumpleanos, despues del cumpleanos, vuelta modulo 12.
7. Documentar la nueva tecnica en `docs/ARCHITECTURE.md` o documento especifico si queda mas limpio.
```

## 7. Prompt revisado para Sprint 2: Carta compuesta

```text
Implementa Carta Compuesta v1 dentro del modulo de Sinastria.

Tareas:
1. Crear `CompositeEngine` bajo `Sources/AstroMalik/Engine/Synastry/` o ubicacion coherente con el repo.
2. Calcular puntos medios por arco corto para planetas, ASC y MC.
3. Forzar Nodo Norte/Nodo Sur como eje exacto solo si el modelo incluye nodos; si no, dejar documentado para fase posterior.
4. Definir `CompositeChart` o reutilizar `NatalChart` con metadatos claros para no confundir carta real con carta sintetica.
5. Anadir modo `Compuesta` a `SynastryView` sin romper el flujo actual de aspectos A/B.
6. Reutilizar una rueda simple cuando sea posible.
7. Anadir tests de punto medio cruzando 0 Aries, caso distancia menor de 180 y caso distancia mayor de 180.
```

## 8. Prompt revisado para Sprint 3: Progresiones secundarias

```text
Implementa Progresiones Secundarias v1.

Tareas:
1. Crear `SecondaryProgressionEngine`.
2. Convertir carta natal a JD natal usando los datos existentes de fecha, hora y timezone.
3. Calcular edad tropical exacta en anos y usarla como dias efemeride sumados al JD natal.
4. Calcular posiciones progresadas con `swe_calc_ut` y `SEFLG_SPEED`.
5. Detectar cambios de signo, cambios de casa y aspectos progresado-natal con orbe <= 1 grado.
6. Detectar estaciones progresadas para Mercurio, Venus y Marte mediante cruce de velocidad, con busqueda acotada.
7. Crear UI sobria: rueda doble y tabla de aspectos partiles.
8. Anadir tests unitarios para fecha progresada, aspectos partiles y deteccion de estacion con fixture controlado.
```

## 9. Prompt revisado para Sprint 4: Estrellas fijas

```text
Implementa Estrellas Fijas Mayores solo despues de verificar recursos.

Primero haz un spike:
1. Comprobar desde Swift que `swe_fixstar2_ut` puede resolver Regulus, Spica, Algol, Sirius y Aldebaran con los recursos empaquetados.
2. Si falta `sefstars.txt`, anadirlo como recurso permitido y documentar su origen/licencia.
3. Anadir test que falle claramente si el catalogo de estrellas no esta disponible.

Despues implementa:
1. `FixedStarEngine` con lista cerrada de estrellas mayores.
2. Conjunciones a planetas natales, ASC y MC con orbe configurable, default 1.5 grados.
3. Badges discretos en lista natal y, opcionalmente, marcas en rueda.
4. Tests de diferencia angular cerca de 0 Aries.
```

## 10. Conclusiones

Gemini ha propuesto un roadmap valioso y bastante bien ordenado. Yo lo convertiria en una hoja de ruta mas pragmatica:

1. **Profecciones primero**, porque dan contexto inmediato a Revolucion Solar y fortalecen el eje tradicional.
2. **Composite despues**, porque Sinastria ya esta madura y la integracion sera natural.
3. **Progresiones en tercer lugar**, para abrir el puente moderno sin diluir el caracter clasico.
4. **Estrellas fijas con spike previo**, porque hay una dependencia real de catalogo/recurso.
5. **Almuten y Sizigia cuando queramos profundidad medieval documentada**, no como algoritmo opaco.
6. **Astrocartografia como proyecto avanzado separado**, no como sprint mezclado.

La estructura de cuatro prompts de Gemini me parece correcta como boceto, pero no como herramienta final de desarrollo. Para AstroMalik necesitamos prompts con memoria arquitectonica: que exijan leer el repo, tocar los puntos de integracion reales, probar, empaquetar y documentar. Ese es el nivel que mantiene a la app como una suite seria y no como un collage de features.

