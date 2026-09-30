# Astrocartografía — seguimiento y relevo entre LLM

Actualizado: **30/09/2026**, zona Europe/Madrid. Fase 0 en `6a48a77`, F1 y corrección de tangencia en `74959a2`, **fase 2 committeada en `af49af5`**. F3 implementada por Astra High y completada/validada por el coordinador tras corte de uso; ver evidencia abajo. F3 committeada en **`bea4969`**; F4.1–F4.4 implementadas y validadas por subagente **gpt-6.1-sol/high**, único autor del worktree; entrega consolidada en commit local F4 por orden del usuario (ver `git log`).

**Este es el documento que hay que actualizar al terminar cada paquete.**
Plan y criterios completos: [ASTROCARTOGRAFIA_PLAN_MULTILLM.md](ASTROCARTOGRAFIA_PLAN_MULTILLM.md).

## 1. Estado de entrega

**F4.1–F4.4 implementadas y validadas localmente: 482 tests (1 omitido, 0 fallos), app regenerada y firma/timestamp correctos (22:35:02 CEST). G4 funcional por pruebas locales; smoke visual del nuevo proceso pendiente para no interferir con la app abierta. F3 sí tuvo smoke real; macOS 14 real pendiente.** El usuario confirmó explícitamente **«Regenerar al finalizar»** para F3: la pausa queda levantada para esta entrega. F2 quedó committeada en `af49af5`; F3 comenzó sobre árbol limpio.

- Existe motor, geometría adaptativa, caché/cancelación y ahora código de mapa MapKit, filtros, selección y navegación. La aceptación visual local se realizó mediante el smoke indicado abajo.
- F4 consolidada en el commit local `feat(astrocartography): complete phase 4 location analysis and relocation`, sobre `bea4969`; consultar `git log -1` para su hash. No hubo push, tag ni release.
- F2 se ejecutó mediante un subagente autorizado Astra High, sin otros chats ni worktrees y sin delegación adicional. Otro LLM puede continuar tras leer este documento y comprobar `git status`.
- No se ha modificado el C vendorizado, el corpus, la base de datos del usuario ni el servidor.
- Validación local, sin Thread Sanitizer. El coordinador revisó el código F2; eso no constituye otra teoría de efemérides. La comparación Python es independiente del binding Swift, **no de los algoritmos Swiss**.
- Astra F3 se interrumpió con mensaje de límite de uso antes de probar/empaquetar. Sus archivos quedaron guardados y el coordinador retomó sin rehacerlos. La interrupción no es una entrega completa ni implica pérdida del commit F2.

## 2. Checklist maestro

### Fase 0 — completada

- [x] **F0.1** Auditoría de llamadas Swiss, estado global, tiempo y límites.
- [x] **F0.2** Contratos Foundation compilables, errores tipados y fixture/mock.
- [x] **F0.3** Plan de validación, ocho casos analíticos y referencia Python de 40 posiciones reales.
- [x] **F0.4** Frontera común con exclusión, migración de llamadas, guard CI y regresiones.
- [x] **G0** Base lista para implementar F1; límites y advertencias documentados abajo.

### Fase 1 — núcleo astronómico

- [x] **F1.1** Adaptador ecuatorial real y snapshot de diez cuerpos.
- [x] **F1.2** Meridianos MC/IC.
- [x] **F1.3** ASC/DSC, tangencias y circumpolaridad.
- [x] **F1.4** Validación de raíces e invariantes numéricos frente al fixture analítico.
- [x] **G1** Cálculo local aceptado sin mapa. La comparación no es otro LLM ni otra teoría de efemérides.

### Fase 2 — geometría

- [x] **F2.1** Muestreo adaptativo y precisión geográfica acotada.
- [x] **F2.2** Antimeridiano y clipping de representación, sin MapKit/UI.
- [x] **F2.3** Caché, cancelación y protección frente a resultados obsoletos.
- [x] **F2.4** Tests de discontinuidades, error de bordes completos y rendimiento.
- [x] **G2** Geometría geográfica y segmentos visuales disponibles; F3 debe respetar la semántica de interpolación o validar su proyección. No es aceptación de MapKit/píxeles ni de la app empaquetada.

### Fase 3 — MVP visual

- [x] **F3.1** Spike y elección de control MapKit (validado localmente; macOS 14 real pendiente).
- [x] **F3.2** Mapa, estilos, leyenda y filtros.
- [x] **F3.3** Selección y accesibilidad.
- [x] **F3.4** Integración en navegación y empaquetado MVP.
- [x] **G3** MVP aceptado localmente; no constituye validación de distribución ni macOS 14 real.

### Fase 4 — lugares/relocalización

- [x] **F4.1** Distancia mínima a curvas.
- [x] **F4.2** Motor de carta relocada.
- [x] **F4.3** Búsqueda y comparación de lugares.
- [x] **F4.4** Persistencia y migración.
- [x] **G4** Lugares/cartas relocadas validados por pruebas funcionales locales y paquete; smoke manual del proceso F4 pendiente.

### Fase 5 — interpretación

- [ ] **F5.1** Esquema/guía editorial.
- [ ] **F5.2** Cuarenta textos originales y revisión.
- [ ] **F5.3** Repositorio de lecturas y conexión con lugares.
- [ ] **F5.4** Vista de lectura completa.
- [ ] **G5** Versión funcional completa.

### Fase 6 — exportaciones

- [ ] **F6.1** Datos, builder y plantilla PDF.
- [ ] **F6.2** Imagen del mapa y fallback.
- [ ] **F6.3** Exportación voluntaria a Joplin.
- [ ] **F6.4** CLI y JSON versionado.
- [ ] **G6** Exportaciones aceptadas.

### Fase 7 — entrega

- [ ] **F7.1** Regresiones finales y rendimiento.
- [ ] **F7.2** Ayuda, README y CHANGELOG.
- [ ] **F7.3** Empaquetado y verificación de distribución.
- [ ] **G7** Candidata entregable; publicación requiere autorización.

## 3. Implementación acumulada por paquetes

### F0.1 — auditoría

Inventario léxico previo a migración: [astrocartography-swiss-call-inventory.json](astrocartography-swiss-call-inventory.json). Contiene 65 ocurrencias en 23 archivos Swift: 39 en 15 archivos de producción y 26 en ocho archivos de tests. Las líneas son las de la base; no usarlas como anclas tras editar.

Quince funciones cubiertas: `calc_ut`, `set_ephe_path`, `julday`, `sidtime`, `sidtime0`, `cotrans`, `houses_ex2`, `houses_armc_ex2`, `solcross_ut`, `mooncross_ut`, `sol_eclipse_when_glob`, `lun_eclipse_when`, `sol_eclipse_how`, `lun_eclipse_how`, `rise_trans`, con prefijo `swe_`.

Hallazgos:

1. `Sources/CSwissEph/include/sweodef.h` desactiva TLS bajo Apple; `sweph.c` contiene `swed` y cachés globales. La exclusión debe ser por proceso, no por módulo o instancia.
2. Ya hay consumidores en `Task.detached` (efemérides, natal extendida, retornos y direcciones). No esperar a tener el nuevo mapa para proteger llamadas.
3. App y CLI configuran la ruta con `AstroEngine.configure` al inicializar; tienen procesos distintos. No necesitan lock entre procesos, sí entre hilos de cada proceso.
4. `JulianDay.swift` conserva segundos y rechaza huecos DST y fechas normalizadas. **No ofrece desambiguación explícita de horas repetidas al acabar DST**. No se ha cambiado esa política global.
5. La conversión actual usa componentes UTC con `swe_julday`, sin aplicar DUT1. El contrato lo llama `utcApproximatedAsUT1`, no UT1 exacto.
6. `PlacesService` estima zonas por regiones y offsets. El destino no puede reinterpretar el instante natal ni presentarse como zona histórica exacta.
7. Los archivos de efemérides son `_18` y `_24`. El rango de entrada v1 se limita a 1800–2999; eso **no garantiza ausencia de fallback por cuerpo**.

### F0.2 — contrato v1

Archivo: `Sources/AstroMalik/Astrocartography/Models/AstrocartographyContracts.swift`.

Implementados `AstroNatalInstant`, `AstrocartographyRequest`, `GeoCoordinate`, cuerpos/ángulos, posición ecuatorial, snapshot, procedencia, diagnóstico, identidad de línea, segmentos, resultado y protocolos `AstrocartographyEphemerisProviding` / `AstrocartographyCalculating`. El proveedor `StaticAstrocartographyEphemeris` permite empezar UI/tests sin inventar un motor real.

Decisiones adoptadas para el núcleo v1:

- Foundation, sin tipos MapKit/SwiftUI ni dependencias de corpus o red.
- Diez cuerpos en orden `PLANET_LIST`; petición no vacía y sin duplicados.
- Longitud terrestre este positiva, intervalo canónico `[-180, 180)`; +180 se normaliza a -180. El adaptador visual deberá representar los bordes de ±180 adecuadamente sin cambiar esta convención de dominio.
- RA en `[0,360)` y declinación/latitud en `[-90,90]`, grados; valores finitos.
- Instante inmutable, JD de 1800-01-01 incluido a 3000-01-01 excluido.
- Convención `geocentric-apparent-of-date-geometric-center-v1`: coordenadas aparentes geocéntricas de fecha, horizonte geométrico del centro; no añadir flags J2000, topocéntricos, refracción o semidiámetro.
- Tolerancia geométrica positiva en km, por defecto 1. Es objetivo de discretización, no promesa de exactitud astronómica ni intensidad simbólica.
- Validación también al decodificar JSON de entradas y snapshots. Snapshot exige exactamente un registro por cuerpo solicitado y se ordena canónicamente.
- Identidad estable cuerpo+ángulo+convención. Los flags guardados son los **devueltos**, no solo los solicitados.

**Congelación:** núcleo v1 aceptado para F1–F3. Los DTO `LocationAnalysis`, `RelocatedChartResult` y `AstrocartographyReading` son formas preliminares compilables; su validación de negocio y extensión se cierran en F4/F5. Los segmentos/resultados todavía no garantizan precisión, orden o completitud: esos invariantes los debe imponer y probar el motor F1/F2.

### F0.3 — fixtures y referencias

Ubicación: `Tests/AstroMalikTests/Astrocartography/Fixtures/`, registrada como recurso de tests en `Package.swift`.

- `phase0-equatorial-synthetic.json`: datos ficticios, con procedencia y advertencia explícitas. Su JD no significa que sus RA/declinaciones sean reales.
- `phase0-analytic-lines.json`: ocho casos, creados antes del motor: ecuador, desplazamiento, hemisferio sur/wrap, curva inclinada, tangencia, circumpolaridad norte/sur y degeneración polar. Las pruebas verifican las identidades horizontales, **no un motor que aún no existe**.
- `phase0-swiss-python-reference.json`: diez cuerpos × cuatro fechas; tiempo sidéreo, RA, declinación, flags reales y fallback por cuerpo. Procedencia: pyswisseph instalado, Swiss 2.10.03, misma versión del C vendorizado, por vía Python independiente del futuro adaptador Swift.

**Límite descubierto:** el Sol en JD 2378496.5 (1800-01-01) retorna Moshier aunque el fichero `_18` exista. La referencia conserva este caso en `fallbackBodies`. F1.1 deberá emitir diagnóstico visible de fallback; no recortar el caso ni cambiar flags esperados para esconderlo.

Generador reproducible: `scripts/generate_astrocartography_references.py`. Usa pyswisseph ya instalado; no instala nada ni necesita red. Si otro equipo no dispone del binding, puede ejecutar tests con el fixture versionado sin regenerarlo. No sustituir esa referencia por la salida del propio motor.

### F0.4 — exclusión Swiss

Archivo: `Sources/AstroMalik/Engine/Ephemeris/SwissEphemerisAccess.swift`.

- Una fachada estática y un `NSRecursiveLock` único por proceso.
- Cada llamada existente entra por la fachada; se conservan argumentos, punteros, flags, códigos de retorno y algoritmos.
- `transaction` es síncrona, reentrante y libera con `defer` también cuando se lanza error.
- Una configuración temporal más cálculos relacionados debe ejecutarse dentro de **una transacción**. Un snapshot nuevo debe abarcar sus efemérides y tiempo sidéreo, no envolver solo cada cuerpo por separado.
- **Prohibido `await`, red, UI o geometría pesada dentro del lock**. La fachada no crea tareas ni actores. No protege código que se salte la fachada.
- No se ha hecho un refactor de las API de motores a async ni cambiado el C vendorizado.

Guard: `scripts/check_swiss_access.py`, aplicado a Sources+Tests y añadido al workflow universal de GitHub. Es un control léxico conservador, **no prueba AST de seguridad ni detector de referencias indirectas/alias**. Si se necesita una función Swiss nueva, añadirla a esta fachada y sus tests; no crear un segundo lock.

Alternativas descartadas: actor solo del módulo (deja otros motores fuera), actor global (requiere migración async amplia), habilitar TLS en C (cambia código vendorizado/configuración por hilo). La fachada mantiene API síncrona con coste de serialización; las llamadas C largas pueden bloquear otros cálculos. Medir latencia en F2/F7.

### F1.1 — adaptador ecuatorial

Archivo: `Sources/AstroMalik/Astrocartography/Calculation/SwissAstrocartographyEphemeris.swift`.

- Cumple `AstrocartographyEphemerisProviding`. No convierte desde `NatalChart` ni toca `JulianDay`.
- Una sola `SwissEphemerisAccess.transaction` fija la ruta explícita, el tiempo sidéreo (`swe_sidtime` × 15, normalizado a `[0, 360)`) y todos los cuerpos pedidos.
- Flags pedidos: `SEFLG_SWIEPH | SEFLG_EQUATORIAL`. Se guardan los flags devueltos. Si falta `SEFLG_SWIEPH`, el snapshot añade un diagnóstico `swiss-file-fallback` de severidad warning. No se recorta el caso de 1800-01-01.
- Procedencia `swissEphemeris`, versión de librería leída con `swe_version` a través de la fachada (2.10.03) y algoritmo `f1.1-equatorial-snapshot`.
- La ruta queda como ruta de proceso al salir de la transacción. Quien llame debe pasar el directorio real de efemérides; una cadena vacía falla antes de calcular.
- `swe_version` se añadió a la fachada y a `SwissEphemerisAccessTests`. El fixture Python no se regeneró.

En 1800-01-01 el fallback no es solo el Sol: nueve cuerpos salen por Moshier y la Luna sí usa fichero. El diagnóstico lista esos nueve.

### F1.2–F1.4 — líneas mundanas

Archivos: `MundaneAngles.swift` y `AstrocartographyEngine.swift`, en `Astrocartography/Calculation/`.

- MC = longitud canónica de α − θ. IC = MC + 180°, también en `[-180, 180)`. La misma longitud vale en ambos hemisferios. MC/IC son culminación, no visibilidad.
- ASC/DSC usan `cos H0 = −tan φ tan δ`, con `H = ∓H0`. El criterio de dominio es `|φ| + |δ|` frente a 90°, para no evaluar tangentes infinitas en el polo. Dentro de 1e-9° de la igualdad hay tangencia y una sola longitud. Por encima, no hay cruce. `|cos|` solo se recorta si se pasa de 1 en menos de 1e-10; un exceso mayor no se convierte en raíz. Estar cerca de ±1 por dentro del dominio sigue siendo un cruce con dos longitudes: en latitud 44.9999999988° y declinación 45° las raíces quedan en ±179.9994756°, no fusionadas en −180°.
- Polo con declinación ecuatorial, o ecuador con declinación polar: `nonUniquePolarHorizon`, sin longitud inventada.
- El motor devuelve cuatro líneas por cuerpo. MC/IC llevan los paralelos −45°, 0° y +45°. ASC/DSC llevan raíces exactas cada 1° de latitud más los dos paralelos de tangencia. Ese paso es una rejilla cerrada, no el muestreo adaptativo ni la tolerancia de 1 km de F2.
- Si dos raíces seguidas saltan más de 180° en la longitud canónica, el segmento se corta. Así el resultado no dibuja una cuerda falsa a través del mapa. El recorte visual del dominio del mapa sigue siendo F2.2.
- Los diagnósticos de fichero Swiss se copian a las líneas cuando la procedencia es Swiss y el cuerpo no trae `SEFLG_SWIEPH`.
- No se regeneró ningún fixture. El de líneas analíticas sigue siendo la referencia anterior al motor.

**F1.4, errores medidos** sobre las cuatro fechas y diez cuerpos de la referencia Python, con la identidad de altitud recalculada en el test:

| Residuo | Máximo medido | Umbral del plan |
|---|---:|---:|
| Longitud de meridiano frente a α − θ | 0 | ≤ 1e-6° |
| Seno de altitud en raíces ASC/DSC | 1.97e-15 | el residuo analítico propuesto es ≤ 1e-6° |

En esa pasada hubo 6022 raíces de cruce, 80 tangencias y 36 latitudes de control sin cruce. Los ocho casos analíticos de fase 0 coinciden a 1e-9° o mejor, incluidos tangencia, ausencia de cruce y horizonte polar no único. No apareció discrepancia que exigir cambiar una tolerancia. El residuo es redondeo trigonométrico, no una diferencia entre efemérides.

### F2.1 — geometría adaptativa y cota de error

Archivos: `Calculation/AdaptiveAstroGeometry.swift` y `Calculation/AstrocartographyEngine.swift`.

**No se cambió el esquema ni los protocolos del contrato v1.** Se sustituyó la rejilla provisional de F1; también se actualizaron dos expectativas estructurales de sus tests (MC/IC ahora tienen cinco puntos hasta los polos, y los segmentos de dominio son continuos al atravesar ±180). Las pruebas de raíces, signos, tangencias y fixtures independientes permanecen intactas.

- Horizonte parametrizado como círculo máximo, con base ortonormal `a = (−sin δ, 0, cos δ)`, `b = (0, 1, 0)`, `r(t) = a sin t ± b cos t`, `t ∈ [−π/2, π/2]`, rotado por `α − θ`. El signo positivo es DSC y el negativo ASC. Esto elimina la singularidad de usar latitud como parámetro cerca de la tangencia.
- Se usa `atan2` para latitud/hora, sin `acos` cerca de ±1. Extremos de tangencia exactos, ecuador incluido y la misma subdivisión para ambas ramas. MC/IC cubren −90° a +90° en meridianos exactos; no afirman visibilidad.
- Para `|δ| <= 1e−9°`, los polos son abiertos/no únicos según la convención F1: se dejan los extremos a `4e−9°` de parámetro del extremo, omitiendo menos de **0.5 mm de arco** por extremo, con diagnóstico explícito. No se inventa una raíz en el polo. Para `|δ| >= 90° − 1e−9°`, el horizonte no único conserva ramas vacías y diagnóstico.
- Una arista geográfica significa **interpolación lineal de latitud y longitud localmente desenrollada**, no una cuerda entre longitudes canónicas a través del mapa. Esfera de radio **6371.0088 km**, no elipsoide.

**Cota en toda la arista:** sea `q(s)` el vector unitario de esa interpolación geográfica, y `r(s)` el arco geodésico a velocidad constante entre sus extremos, `s ∈ [0,1]`. En radianes, `||q''|| <= (|Δφ| + |Δλ|)²` y `||r''|| = A²`, siendo `A` la longitud angular del arco. El resto de interpolación lineal respecto a la cuerda cartesiana común está acotado por `sup ||f''|| / 8`, por lo que:

```text
E = ((|Δφ| + |Δλ|)² + A²) / 8
cotaKm = 2 R asin(min(1, E/2)) + 1e−7 km
```

Al emparejar todos los valores de `s`, es una cota bidireccional de distancia, no un criterio basado solo en el punto medio. El muestreador biseca hasta que la cota no supera la tolerancia solicitada; limita también cada arco a 45° para no entregar aristas antipodales ambiguas. La holgura de **0.1 mm** cubre redondeos convencionales; no se implementó aritmética de intervalos para certificar cada operación de coma flotante.

Límites explícitos: tolerancia de ejecución mínima **1 mm** (`0.000001 km`), profundidad 52 y hasta 262145 vértices por rama. Si se alcanza un límite sin satisfacer la cota, lanza `AstroGeometryError`, **sin relajar el objetivo ni devolver un resultado degradado**. El contrato sigue aceptando cualquier tolerancia positiva; el motor declara su límite numérico en tiempo de ejecución. No se confunde esta cota con exactitud de efemérides, UT1, posición observada o píxeles.

### F2.2 — dominio completo y adaptación visual

Archivo: `Representation/AstroVisualGeometry.swift`.

- **Los segmentos del núcleo conservan la curva completa a través del antimeridiano**, con coordenadas canónicas `[-180,180)`. El corte provisional de F1 descartaba el borde que atravesaba ±180; se retiró para no dejar huecos en análisis geográficos futuros. Esto cumple el comentario del contrato v1: sus segmentos no son polilíneas recortadas por MapKit.
- DTO de representación separado `AstroVisualCoordinate` con **−180 y +180 inclusivos**; el núcleo no cambia la normalización de +180 a −180.
- Cada borde existente se desenrolla localmente, recorta al intervalo de latitud solicitado y parte en el antimeridiano. Ambos lados comparten la misma latitud interpolada y usan bordes opuestos ±180: no hay cuerda falsa ni hueco. Los puntos insertados son interpolaciones de la polilínea acotada, no nuevas raíces astronómicas exactas.
- Dominio visual configurable; valor por defecto ±85.0511287798066°. No elige control MapKit ni proyecta a píxeles. No extiende curvas que terminan antes del límite, no conecta segmentos de entrada distintos aunque coincidan sus extremos, descarta degenerados y rechaza aristas de 180° ambiguas.
- **La cota anterior corresponde a interpolación geográfica, no a una recta de Mercator.** F3.1 debe conservar dicha semántica o añadir/verificar el presupuesto de error de su proyección/renderer. El recorte visual nunca sustituye el resultado completo para F4.

### F2.3 — servicio de cálculo, caché y cancelación

Archivo: `Services/AstrocartographyCalculationService.swift`. Se añadieron comprobaciones cooperativas en el motor y antes/dentro de la transacción del proveedor Swiss; no se modificó la fachada ni el C.

- Actor aislado por consumidor con estados `idle`, `calculating`, `ready`, `cancelled`, `failed`. Cálculo síncrono pesado dentro de `Task.detached`, no en el actor llamante ni en MainActor. La sección Swiss produce el snapshot y termina **antes** de la geometría.
- Cada petición invalida la generación previa mediante UUID y cancela su tarea. Una respuesta antigua nunca cambia el estado ni se inserta en caché, aunque el calculador ignore la cancelación. Cancelación explícita, cancelación del caller e invalidación de caché contempladas. Una llamada síncrona Swiss ya en marcha o esperando su lock **no se aborta a mitad**; se comprueba cancelación al entrar/salir y entre cuerpos.
- Clave por JD, escala temporal, cuerpos canónicos, tolerancia, convención, versión del contrato, versión del algoritmo y revisión explícita de efemérides/proveedor. No se usa UUID de carta ni se redondea el instante. Editar cualquier dato relevante selecciona otra clave.
- Calculador y revisión de proveedor son inmutables por instancia. Quien integre F3 debe usar una revisión que identifique biblioteca, datos/ruta y opciones; **una ruta sola no detecta archivos cambiados**. Si cambian recursos/configuración, reemplazar el servicio o llamar a `invalidateCache()`, que también descarta cálculo en curso.
- Caché LRU en memoria, sin persistencia, acotada por entradas (8 por defecto) y vértices (200000). No almacena errores, resultados con snapshot incorrecto, cancelados ni obsoletos; resultados individuales que exceden el presupuesto no se cachean. Estadísticas comprobables de hits/misses/evictions.

### F2.4 — evidencia geométrica, discontinuidades, carreras y rendimiento

Tres archivos nuevos de tests, **17 pruebas** en total: 4 en `AdaptiveAstroGeometryTests`, 6 en `AstroVisualGeometryTests`, 7 en `AstrocartographyCalculationServiceTests`.

**Referencia geométrica independiente del muestreador:** slerp cartesiano entre extremos verificados mediante la identidad horizontal. Se midieron **98580 aristas × 33 puntos** (3253140 puntos), incluyendo cuartos/octavos además del punto medio, en 14 declinaciones entre −89.999° y +89.999°, cero, valores de ±1e−6° y justo junto a la tolerancia polar. También se comprueba que cada rama cubre π radianes salvo la exclusión polar declarada, sin huecos.

| Tolerancia solicitada | Máxima separación geográfica medida |
|---|---:|
| 10 km | 3.3481300116 km |
| 1 km | 0.2815963371 km |
| 0.1 km | 0.0299831101 km |
| 0.01 km | 0.0034308975 km |

La cota conservadora por arista también debe ser ≤ objetivo. Estas mediciones no son una nueva comparación de efemérides ni sustituyen fixtures F0. Los tests de F1 siguen comparando con sus referencias, con residuo de seno de altitud máximo **1.82146e−15** en la nueva geometría.

Discontinuidades: cruces este/oeste de ±180 con bordes emparejados, vértice exacto sobre el corte, meridiano −180, clipping simultáneo con seam, extremos tangentes, polos abiertos, entrada vacía/no única, segmentos separados que comparten punto y rechazo de arista ambigua. Barrido adicional: 7 orígenes × 7 declinaciones × 2 ramas × 3 dominios visuales, comprobando que no haya NaN, cuerdas mundiales, vértices duplicados ni fragmentación inesperada.

Concurrencia: gates/semáforos deterministas, no sleeps. Calculadores deliberadamente no cooperativos, respuesta antigua posterior a una nueva, **20 cambios rápidos**, cancelación del caller/servicio, invalidación durante cálculo, fallos y snapshot incorrecto. También se comprueba que el motor real respeta cancelación tras un proveedor que no coopera y que LRU/variaciones de datos/presupuesto de vértices se aplican.

**Benchmark local de motor + snapshot Swiss + geometría**, sin mapa/red, sin caché del servicio: Apple M3, macOS 26.3 (25D125), Swift 6.3.1, build **debug**, diez cuerpos, JD 2451545, tolerancia 1 km, un calentamiento y **31 muestras**. En la suite completa: **p50 1.309 ms, p95 1.364 ms, 5936 vértices**. El percentil usa índices 15 y 29 de la serie ordenada. El objetivo orientativo <1 s se cumple en este equipo/configuración; no extrapolar a otros Macs ni a la futura UI. No se ejecutó benchmark de distribución/release ni TSan.

## 4. Validación efectivamente ejecutada

### F3 — recuperación y cierre local

- Implementación guardada: `UI/AstroMapView.swift`, `AstrocartographyView.swift`, `AstrocartographyViewModel.swift`, `Representation/AstroMercatorGeometry.swift`; ruta nueva en navegación/estado/ContentView. No fase 4 ni corpus/servidor.
- Control elegido: `MKMapView` con `NSViewRepresentable`, mapa 2D sin rotación/pitch y renderer `CGPath` explícito para no depender de simplificación de polilíneas. Un overlay por línea lógica; lista alternativa accesible, estilos distintos por ángulo y nombres por cuerpo.
- Cota adicional Mercator: inversa φ(y)=atan(sinh(y)), |φ''|≤1/2; cota de arista completa RΔy²/16 más holgura. Subdivisión visual con 0.1 km de presupuesto; petición de núcleo con 0.9 km. No es precisión de píxeles, efemérides ni fecha natal.
- Coordenadas manuales/click solo seleccionan lugar. Sin distancias/relocalización/persistencia. El mapa no consulta ubicación del usuario; cálculo/lista offline y advertencia de posible conexión para Apple Maps.
- Revisión del coordinador tras interrupción: 9 tests F3 seleccionados pasan. 26.060 aristas × 33 puntos usando inversa MapKit: máximo 0.0972030635365671 km (presupuesto 0.1 km).
- Suite completa ejecutada por coordinador: **454 tests, 1 omitido, 0 fallos**, 34.111 s; guard Swiss y diff check correctos. Log interno `/tmp/astromalik-f3-recovery-full.log`.
- `scripts/package_app.sh` terminó correctamente; ejecutable **2026-09-30 21:34:48 +0200**, firma `codesign --verify --deep --strict` válida; CLI release `.build/release/astromalik-cli --help` correcta (no está dentro de Contents/MacOS).
- Smoke visual real CUA: reinicio de la app antigua y navegación **Herramientas → Astrocartografía**; estado sin carta, selección de carta guardada, 40/40 líneas visibles, filtros Ninguno → 0 y Todos → 40, teclado flecha selecciona Sol DSC con datos y resaltado, coordenadas manuales 0/0 con pin, centrar y quitar, retorno a mundo. No se guardaron cartas ni lugares.
- Apple Maps mostró un fallo transitorio de carga aun con algunas teselas visibles; cálculo/lista siguieron operativos y el aviso desapareció después de cargar. No se garantiza mapa base offline.
- El usuario no veía el apartado porque aún ejecutaba la versión antigua: empaquetar no reinicia el proceso abierto. Se dejó abierta la nueva app con mapa de la carta elegida.
- Límite de validación: macOS actual 26.3 arm64; deployment target 14 compila, pero **no se ha ejecutado en un Mac físico con macOS 14**. Tampoco TSan, auditoría completa de accesibilidad/contraste ni release publicado.

Entorno: Mac arm64; Swift 6.3.1, lenguaje del paquete Swift tools 5.9. `xcode-select` apunta a CommandLineTools sin XCTest. **No se cambió la selección global**: se usó Xcode por proceso.

```bash
python3 scripts/check_swiss_access.py
python3 scripts/generate_astrocartography_references.py
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift test
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer bash scripts/package_app.sh
```

Resultados de tests de la fase 0: **418 ejecutados, 1 omitido, 0 fallos**; suite completa, GUI/reportes y CLI incluidos. Las nuevas pruebas comprueban contratos/JSON, ocho identidades analíticas, 40 posiciones por referencia Python, reentrada, liberación tras error, exclusión de 100 secciones y 120 cálculos concurrentes frente a baseline serial.

Tras F1.1, la misma suite dio **422 ejecutados, 1 omitido, 0 fallos**. Los cuatro tests nuevos cubren la versión de librería por la fachada, las 40 posiciones del adaptador frente al fixture Python, el subconjunto Sol/Luna con fallback visible y el rechazo de una ruta vacía.

Tras F1.2–F1.4, la suite dio **427 ejecutados, 1 omitido, 0 fallos**. No se ejecutó `scripts/package_app.sh`: el usuario pidió no regenerar la app hasta nueva orden. El binario existente no contiene esta fase.

El test de referencia Python utiliza las efemérides locales y sus flags reales. El test concurrente usa llamadas estilo natal/casas y ecuatoriales dentro de transacciones, con entrada sintética; no es benchmark ni prueba exhaustiva de todas las secuencias posibles.

**Empaquetado de la fase 0:** `scripts/package_app.sh` terminó correctamente; binario con timestamp **2026-09-30 19:48:17 +0200**. `codesign --verify --deep --strict AstroMalik.app` pasó, y el ejecutable release de `astromalik-cli --help` respondió correctamente.

**Empaquetado tras F1.1:** el mismo script terminó correctamente; binario **2026-09-30 20:01:40 +0200** y `codesign --verify --deep --strict` pasó. No se ha publicado una nueva versión.

El generador Python se ejecutó dos veces: el SHA-256 del fixture fue idéntico (`ff2800c807fc85309a518fe0c87532e32fa995d1e946bfe73185717a74d63875`). Guard sin llamadas crudas fuera de la fachada y tres sanity checks del detector pasados. `git diff --check` sin errores.

**Validación F2 (30/09/2026):**

```bash
python3 scripts/check_swiss_access.py
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift test --filter 'AdaptiveAstroGeometryTests|AstroVisualGeometryTests|AstrocartographyEngineTests'
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift test --filter AstrocartographyCalculationServiceTests
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift test
git diff --check
stat -f '%Sm' -t '%Y-%m-%d %H:%M:%S %z' AstroMalik.app/Contents/MacOS/AstroMalik
```

Primera pasada de F2 mostró dos expectativas estructurales obsoletas de F1 (tres puntos MC y segmentos ya cortados); se actualizaron sin tocar oráculos astronómicos. Después: suite completa **445 ejecutados, 1 omitido, 0 fallos**, 32.002 s en la repetición final (primera completa: 33.464 s, también sin fallos). Guard Swiss y `git diff --check` correctos. Fixtures y contratos v1 sin cambios. Los logs internos están en `/tmp/astromalik-f2-*.log`; la evidencia durable relevante queda en este documento.

**Revisión posterior del coordinador:** leídos sampler/cota, adaptador visual, servicio y tests; sin bloqueos detectados. Ejecución propia con filtro `AdaptiveAstroGeometryTests|AstroVisualGeometryTests|AstrocartographyCalculationServiceTests|MundaneAngleAnalyticTests`: **20 tests, 0 fallos**, 2.939 s. Reprodujo máximo 0.281596337 km para objetivo 1 km; guard y diff check correctos. Se verificó de nuevo el timestamp del binario sin regenerarlo. Esta revisión no sustituye TSan ni validación del renderer de F3.

**No se ejecutó `scripts/package_app.sh` ni se abrió la app**, por la pausa pedida. Timestamp comprobado del binario empaquetado: **2026-09-30 20:01:40 +0200**, sin cambios; no contiene F1.2–F2. No se ejecutó TSan ni se probó manualmente un mapa porque no existe aún.

## 5. Siguiente acción concreta para cualquier LLM

1. Leer `AGENTS.md`, este seguimiento y el plan; comprobar `git status`. F3 base **`bea4969`** y F4 consolidada en commit local; verificar HEAD mediante `git log -1`. No descartar cambios de otros agentes.
2. F0–F4 implementadas/validadas por pruebas locales. Siguiente **F5 interpretación y F6 exportaciones**, que el usuario lanzará con **Claude**. No iniciarlas sin su orden; rediseño UI general reservado al usuario.
3. El paquete F4 tiene ejecutable **30/09/2026 22:35:02 +0200**, firma verificada. La app abierta sigue siendo el proceso anterior: empaquetar **no reinicia**. Para smoke nuevo, comprobar primero que no hay datos sin guardar ni actividad del usuario y coordinar reinicio seguro; no cerrar a ciegas.
4. F5/F6 deben reutilizar `AstroLocationCalculation`/`curveSnapshot` (flags/procedencia reales), análisis global completo y selección de filtros separada; relocación nunca cambia JD ni cuerpos geocéntricos natales. Guardados no son permiso para exportar automáticamente ni usar LLM/red.
5. macOS 14 físico, TSan, auditoría accesibilidad completa y búsqueda online real pendientes. Compilar target 14 en macOS 26.3 no prueba ejecución macOS 14.
6. Sin commit/push/tag/release sin autorización. Guard/tests/package con `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer`; conservar fixtures/corpus/C/servidor y datos reales. Pruebas de storage solo aisladas.

### Prompt para continuar

```text
Continúa AstroMalik-macOS leyendo docs/ASTROCARTOGRAFIA_SEGUIMIENTO.md y el plan.
F3 base bea4969; F4.1–F4.4 completas y validadas están en commit local.
Consulta git log -1 para HEAD actual.
Comprueba y conserva el worktree. F5/F6 las lanzará el usuario con Claude;
implementa solo alcance que autorice. No rediseñes UI general sin orden.
Distancias sobre curvas completas del núcleo, no visuales; relocación retiene
JD y posiciones natales. Snapshot/flags/fallback se conservan en cálculos y
guardados. No modifiques corpus/C/servidor ni commit/push/release sin orden.
Tras código/UI regenera app y verifica firma/timestamp; proceso abierto no
se reinicia solo. Reinicio/smoke solo seguro sin datos sin guardar.
```

## 6. Bitácora

| Fecha | Paquetes | Evidencia / salida | Siguiente |
|---|---|---|---|
| 30/09/2026 | F0.1–F0.4 | Contratos, fachada, inventario, fixtures, guard, 418 tests / 1 omitido / 0 fallos; paquete y firma verificados, binario 19:48:17 CEST. Commit local `6a48a77`, sin push | F1.1 |
| 30/09/2026 | F1.1 | Adaptador ecuatorial, diagnóstico de fallback y `swe_version` en la fachada. 422 tests / 1 omitido / 0 fallos; binario 20:01:40 CEST. Sin commit | F1.2 |
| 30/09/2026 | F1.2–F1.4 | Meridianos, raíces ASC/DSC, tangencias y circumpolaridad. Residuo de meridiano 0; seno de altitud ≤ 1.97e-15. 427 tests / 1 omitido / 0 fallos. App no regenerada, por petición | F2.1 |
| 30/09/2026 | F1.3 corrección | La proximidad de `cos` a ±1 ya no fusiona dos raíces válidas. Caso 44.9999999988° / 45° conserva ±179.9994756°. App no regenerada. F1 cerrada en commit `74959a2` | F2.1 |
| 30/09/2026 | F2.1–F2.4 | Cota geométrica completa, dominio sin huecos, seam/clipping separado, actor latest-wins y caché LRU. 445 tests / 1 omitido / 0 fallos; objetivo 1 km medido ≤0.281597 km; benchmark debug M3 p50 1.309 ms/p95 1.364 ms, 5936 vértices. Posteriormente commit local `af49af5`, sin push; sin empaquetado en F2 | F3 |

| 30/09/2026 | F3.1–F3.4 / G3 local | MKMapView/CGPath explícito, presupuesto 0.9 + 0.1 km, filtros/selección/lista/navegación. Recuperado tras corte Astra; 454 tests / 1 omitido / 0 fallos, paquete/firma, binario 21:34:48 CEST y smoke real completados. Posteriormente commit local `bea4969`; macOS14 real pendiente | F4 autorizada |

Al continuar: añadir fila con paquetes, comandos/resultados reales, límites y siguiente acción; no borrar decisiones previas sin explicar la sustitución.

### Inicio F4 — 30/09/2026

Base `bea4969`, árbol limpio verificado. Modelo gpt-6.1-sol/high. Alcance F4.1–F4.4 completo, sin rediseño general UI, sin commit/push/tag/release ni subdelegación. F5/F6 reservadas al usuario con Claude. Pausa de empaquetado levantada: regenerar al terminar, sin reiniciar automáticamente app abierta ni perder datos. Corpus/C vendorizado/servidor intactos; tests de persistencia solo almacenamiento aislado.

### Checkpoint F4.1 — distancias (30/09/2026 21:57 CEST)

Implementado `Calculation/AstroLocationAnalyzer.swift`: proyección vectorial al arco menor de **cada arista de segmentos completos F2**, con pertenencia orientada `atan2`, extremos y segmentos separados. Esfera R=6371.0088 km; nunca curva MapKit, pantalla ni mínimo solo de vértices. En F2 los extremos están sobre círculos máximos ideales: el mínimo continuo sobre arcos es el de la curva ideal (con extremos polares abiertos conservados). La distancia frente a la interpolación lat/lon documentada por F2 difiere a lo sumo su cota Hausdorff; `estimatedErrorKm = geometryToleranceKm + 0.000001 km`. Es una cota conservadora, no exactitud de efemérides. No se conectan segmentos independientes ni se inventan distancias a ramas sin solución única. Umbrales producto configurables (por defecto 100/300 km), separados de intensidad científica; filtros solo crean subconjunto, análisis global intacto.

5 tests enfocados pasan. Referencia analítica independiente plano horizontal `atan2(|n·p|,|n×p|)` en 945 lugares (9 declinaciones × 3 orígenes × 7 latitudes × 5 longitudes), incluyendo cenit, tangencias, ±180 y polos: error máximo **4.4477951917e-7 km** (0.445 mm, extremo polar abierto); holgura numérica 1 mm. Primer oráculo `asin(dot)` dio 16 mm espurios cerca del cenit: sustituido por expresión `atan2` bien condicionada, sin ampliar tolerancia. Meridian entre vértices devuelve cero, extremo válido y segmentos desconectados verificados. Log interno `/tmp/astromalik-f4-distance.log`.

### Checkpoint F4.2 — relocalización (30/09/2026 22:00 CEST)

Implementado `Calculation/AstroRelocationEngine.swift`: source inmutable Sendable copia los diez cuerpos geocéntricos natales **literalmente**, conserva JD/escala, ID y sistema; solo recalcula casas/ángulos por `AstroEngine.calcHouses`, dentro de fachada Swiss transaccional síncrona (sin await). Natal intacta y zona destino solo metadatos; no verificada → UTC con advertencia. Sistemas soportados explícitos, no fallback silencioso; fallo polar Placidus rechaza carta degradada. Resultado envolvente añade procedencia/metadata sin romper DTO F0v1. Casas de cuerpos siguen criterio natal por longitud eclíptica, no prueba de angularidad mundana.

4 tests nuevos pasan: misma ciudad reproduce casas/ángulos/cuerpos; destinos Japón/Australia/seam y zonas distintas mantienen instante/posiciones; Regiomontanus/Whole Sign/Koch; polos y entradas inválidas; 40 tareas mezcladas relocación/snapshot idénticas a baseline serial. Combinados F4.1+F4.2: **9 tests, 0 fallos**, 0.476 s. Log `/tmp/astromalik-f4-engines.log`. Paquete final pendiente hasta cerrar F4.3/F4.4.

### Checkpoint F4.3 — lugares/comparación (30/09/2026 22:18 CEST)

Búsqueda local con `cities_seed.json`, insensible a acentos/mayúsculas, sin red por defecto. Nominatim solo tras optar explícitamente y pulsar Buscar (solo query, nunca natal), con error visible y resultados locales conservados; zonas de catálogo/remotas no verificadas → UTC. Entrada manual, pin de mapa y nombres de lugares, comparación hasta seis destinos, datos completos de 12 casas/10 cuerpos/ASC/MC frente a natal, JD/procedencia y errores polares. Distancias globales versus visibles claramente separadas; umbrales ajustables y aviso de frontera dentro de cota. Sin rediseño general UI ni nueva interpretación F5.

`AstroLocationCalculationService` actor: trabajo detached, latest-wins/cancelación y LRU de 8 resultados por entradas **reales completas** (snapshot/curvas, source natal, destino/zona) y revisión immutable con hash recursos/versiones. VM tiene token separado por análisis de lugar y búsqueda; cambiar carta incluso mismo UUID borra cálculos/comparaciones, selector cambiado invalida inmediatamente. 7 tests nuevos workflow pasan (12 junto a VM F3): búsqueda offline/acento, cache JD/zona, carreras/cancelación con gates sin sleeps, fallo casas conserva distancia, selección/relocación/comparación real con recursos empaquetados, edición natal y búsqueda latest-wins. Log `/tmp/astromalik-f4-workflow.log`. Búsqueda online real no ejercitada para evitar tráfico y dependencia externa; no se modifica la preferencia global/ubicación del usuario.

### Checkpoint F4.4 — guardados/migración (30/09/2026 22:20 CEST)

Repositorio `Persistence/AstroSavedPlaceRepository.swift` con tablas **aditivas independientes en user.db**, esquema propio v2 (no PRAGMA user_version global, no corpus). Persiste intención de destino/procedencia origen/zona/filtros/umbrales, fingerprint SHA256 de carta completa, contrato/algoritmos/revisión de recursos y resultado validado. v1 conserva intención/procedencia; añade fingerprint vacío/result nulo y requiere recalcular. Esquema futuro se rechaza con rollback. Filas/resultados dañados no se borran: advertencias visibles, resultado inválido conserva intención. Recuperar/eliminar y actualizar el mismo lugar desde UI; recuperar siempre recomputa/verifica por caché actual, nunca publica datos históricos incompatibles. Guardar natal invalida derivados incompatibles; borrar natal elimina destinos asociados en la misma transacción (rollback conserva ambos si falla).

7 tests nuevos de almacenamiento **aislado temporal** pasan: roundtrip/reabrir/actualizar/eliminar, protección entre cartas, carta editada/revisión distinta, migración v1 idempotente preservando tabla natal, esquema futuro, corrupción y validación semántica, rollback. Combinados workflow+repositorio: **14 tests, 0 fallos**, 0.152 s. No se abrió ni modificó user.db real ni datos del usuario en pruebas. Log `/tmp/astromalik-f4-persistence.log`. G4 pendiente suite completa/guard/paquete/firma/timestamp; smoke UI real todavía no ejecutado para no interferir app abierta.

### Cierre F4 — evidencia final (30/09/2026 22:35 CEST)

**F4.1–F4.4 cerradas en implementación/pruebas/paquete**, sin commit/push/tag/release. Modelo gpt-6.1-sol/high; no subdelegación ni worktrees/chats nuevos. Contrato F0v1 intacto; corpus/C vendorizado/servidor intactos. No pruebas contra datos reales ni modificaciones de preferencias/tema. No se cerró/reinició ni operó la app abierta.

Endurecimiento posterior a checkpoints:

- `AstroLocationCalculation.curveSnapshot` conserva petición, posiciones ecuatoriales, flags **devueltos**, fallback y procedencia Swiss para futuras lecturas/exportaciones, incluso si las casas polares fallan. Opcional compatible solo para resultados legacy/sintéticos; el motor real siempre lo entrega. Storage verifica petición/zona y cuerpos/casas válidos.
- Guardar destino exige natal ya persistida e idéntica al fingerprint: no referencias huérfanas ni guardado silencioso de natal no solicitada. Updates/deletes protegen el ID de otra carta. Esquema astro futuro/incompatible deja CRUD natal operativo.
- Descubrimiento y corrección ligada a invalidación: `UserStore.rename` antes modificaba solo columna SQL `name`, pero `load` lee `chart_json`. Ahora usa `save` transaccional y sincroniza ambos, conservando metadata. Dos tests UserStore aislado añadidos, incluidos cambio/borrado natal, rename y esquema futuro.
- Distancia medida también contra minimizador numérico independiente continuo de interpolación lat/lon por arista (haversine + sección áurea, 48 iteraciones, extremos incluidos), 28 distancias de ramas en siete declinaciones y dos destinos: máxima diferencia **0.1091404391 km**, dentro de cota **0.900001 km**. El minimizador es referencia numérica, no certificación por intervalos; cota formal heredada del Hausdorff F2 más holgura convencional 1 mm. Oracle analítico de plano: **4.4477951917e-7 km**, incluye omisión polar abierta <0.5 mm.
- ASC/MC contrastados con identidades independientes de horizonte/ascenso y meridiano ecuatorial, usando oblicuidad/tiempo sidéreo por fachada (no otro algoritmo de efemérides): 15 destinos/instantes, máximo residuo **8.881784197e-16** (seno de altura/radianes de meridiano según identidad).
- Benchmark M3/arm64, macOS **26.3 (25D125)**, Swift **6.3.1**, build debug, diez cuerpos, **6076 vértices**, distancia + casas relocadas síncronas **sin caché/red/mapa** (curvas/snapshot preparados fuera del cronómetro), un calentamiento y 31 muestras. Suite final: **p50 4.880459 ms, p95 4.969875 ms** (índices 15/29 ordenados). No extrapolar a UI/otros equipos/release.

Validación final ejecutada:

```bash
python3 scripts/check_swiss_access.py
git diff --check
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift build
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift test
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer bash scripts/package_app.sh
codesign --verify --deep --strict AstroMalik.app
stat -f '%Sm' -t '%Y-%m-%d %H:%M:%S %z' AstroMalik.app/Contents/MacOS/AstroMalik
.build/release/astromalik-cli --help
```

**28 tests nuevos** (6 distancia, 6 relocación, 7 workflow, 9 storage). Suite completa final **482 ejecutados, 1 omitido, 0 fallos**, **34.747 s**. Primera completa anterior al último refuerzo de snapshot también 482/1/0, 34.604 s. Filtros enfocados y guard/diff check correctos; build sin nuevos avisos. Package final **81.53 s**, binario actualizado **2026-09-30 22:35:02 +0200**, firma válida, CLI release help correcta. Logs internos `/tmp/astromalik-f4-full-final.log`, `/tmp/astromalik-f4-package-final.log`; evidencia durable aquí.

**Límites honestos:** no smoke manual del proceso F4 (app anterior abierta con carta del usuario; se preservó), no llamadas de búsqueda online reales, no ejecución en Mac físico macOS14, no TSan ni auditoría completa accesibilidad, no exportaciones/lecturas F5/F6 ni release. La UI funcional muestra datos pero rediseño estético sigue reservado al usuario. Relocación retiene posiciones calculadas/persistidas de natal; no modifica ni intenta reinterpretar su corrección original. La holgura numérica de distancia está medida, no certificada con aritmética de intervalos.

| Fecha | Paquetes | Evidencia / salida | Siguiente |
|---|---|---|---|
| 30/09/2026 | F4.1–F4.4 / G4 funcional local | Distancias continuas/cotas, relocación inmutable, búsqueda offline/manual/opt-in/comparación, guardados esquema2/migración/invalidación. 482 tests / 1 omitido / 0 fallos; error lat/lon medido≤0.109141km, plano≤0.445mm; p50/p95 4.880/4.970ms. Paquete/firma, binario22:35:02CEST. Consolidada en commit local F4; sin smoke de proceso nuevo | F5/F6 con Claude bajo orden; smoke seguro coordinado |

### Consolidación F4 — 30/09/2026

Usuario autoriza commit. Coordinador confirma agente finalizado, logs de suite/paquete, guard Swiss y diff check, firma válida y timestamp final 22:35:02 CEST; CLI release help correcta. Commit local F4 sobre `bea4969`, sin push/tag/release. Pendientes: smoke manual F4 en proceso nuevo, F5 interpretación, F6 exportaciones y F7 endurecimiento/documentación/distribución. Rediseño general UI pospuesto por el usuario; F5/F6 las lanzará con Claude.
