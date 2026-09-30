# Astrocartografía — seguimiento y relevo entre LLM

Actualizado: **30/09/2026**, zona Europe/Madrid. Fase 0 en commit `6a48a77` (base previa `26f6d92`), fase 1 y corrección de tangencia en `74959a2`. **F2.1–F2.4 validadas y preparadas para el commit que incorpora esta actualización, por petición del usuario.** F3.1–F3.4 autorizadas para ejecución mediante un nuevo subagente. La app no se ha reempaquetado después de F1.1.

**Este es el documento que hay que actualizar al terminar cada paquete.**
Plan y criterios completos: [ASTROCARTOGRAFIA_PLAN_MULTILLM.md](ASTROCARTOGRAFIA_PLAN_MULTILLM.md).

## 1. Estado de entrega

**Fase 2 implementada y validada. El usuario ha autorizado la fase 3 completa mediante subagente; ejecución a continuación del commit de F2.** La app empaquetada sigue siendo la de las 20:01:40, anterior a los meridianos y a las curvas. La confirmación sobre levantar la pausa de empaquetado se ha solicitado por separado; mantenerla hasta respuesta.

- Existe motor de líneas mundanas, muestreo adaptativo con cota geográfica, adaptador visual de antimeridiano/clipping y servicio de caché/cancelación. **No hay mapa ni integración UI.**
- HEAD comprobado al comenzar F2: `74959a2`, árbol limpio. Corrige la información antigua de este seguimiento: **F1 sí estaba ya committeada**. Solo F2 y esta actualización quedan sin commit. No se hizo commit, push, tag ni release. El usuario pidió no regenerar la app hasta que lo pida.
- F2 se ejecutó mediante un subagente autorizado Astra High, sin otros chats ni worktrees y sin delegación adicional. Otro LLM puede continuar tras leer este documento y comprobar `git status`.
- No se ha modificado el C vendorizado, el corpus, la base de datos del usuario ni el servidor.
- Validación local, sin Thread Sanitizer. El coordinador revisó el código F2; eso no constituye otra teoría de efemérides. La comparación Python es independiente del binding Swift, **no de los algoritmos Swiss**.

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

- [ ] **F3.1** Spike y elección de control MapKit.
- [ ] **F3.2** Mapa, estilos, leyenda y filtros.
- [ ] **F3.3** Selección y accesibilidad.
- [ ] **F3.4** Integración en navegación y empaquetado MVP.
- [ ] **G3** MVP aceptado.

### Fase 4 — lugares/relocalización

- [ ] **F4.1** Distancia mínima a curvas.
- [ ] **F4.2** Motor de carta relocada.
- [ ] **F4.3** Búsqueda y comparación de lugares.
- [ ] **F4.4** Persistencia y migración.
- [ ] **G4** Lugares y cartas relocadas aceptados.

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

1. Leer `AGENTS.md`, este seguimiento y el plan; revisar `git status` y los cambios F2 sin descartar trabajo pendiente. Base real: `74959a2`.
2. Ejecutar guard y tests con `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer`.
3. **F3.1–F3.4 autorizadas por el usuario.** Comenzar por spike/elección de control MapKit y validación de la interpolación/proyección que dibujará. No dar por válida en píxeles una cota geográfica lat/lon.
4. Usar `AstrocartographyCalculationService` para trabajo fuera del hilo principal y latest-wins; construir correctamente la revisión del proveedor y observar sus estados. No cachear por UUID de carta.
5. Usar el resultado núcleo para análisis y el adaptador visual para dibujar; nunca alimentar distancias F4 con curvas recortadas. No regenerar fixtures independientes con salida del motor.
6. El empaquetado sigue en pausa hasta petición explícita. No commit, push ni release sin autorización. Actualizar evidencia/bitácora de cualquier siguiente paquete.

### Prompt para continuar

```text
Continúa AstroMalik-macOS desde docs/ASTROCARTOGRAFIA_SEGUIMIENTO.md.
HEAD 74959a2 contiene F1; F2.1–F2.4 están en el worktree sin commit.
Revisa esos cambios y ejecuta guard/tests. Implementa únicamente el paquete
que autorice el usuario (siguiente: F3.1). Conserva contrato v1 y fixtures.
La cota F2 es geográfica lat/lon, no un error de píxeles/Mercator: valida la
semántica del renderer. No modifiques corpus/servidor ni hagas commit/push.
No ejecutes scripts/package_app.sh ni abras la app salvo petición explícita.
Registra lo completado, evidencia real, límites y siguiente acción aquí.
```

## 6. Bitácora

| Fecha | Paquetes | Evidencia / salida | Siguiente |
|---|---|---|---|
| 30/09/2026 | F0.1–F0.4 | Contratos, fachada, inventario, fixtures, guard, 418 tests / 1 omitido / 0 fallos; paquete y firma verificados, binario 19:48:17 CEST. Commit local `6a48a77`, sin push | F1.1 |
| 30/09/2026 | F1.1 | Adaptador ecuatorial, diagnóstico de fallback y `swe_version` en la fachada. 422 tests / 1 omitido / 0 fallos; binario 20:01:40 CEST. Sin commit | F1.2 |
| 30/09/2026 | F1.2–F1.4 | Meridianos, raíces ASC/DSC, tangencias y circumpolaridad. Residuo de meridiano 0; seno de altitud ≤ 1.97e-15. 427 tests / 1 omitido / 0 fallos. App no regenerada, por petición | F2.1 |
| 30/09/2026 | F1.3 corrección | La proximidad de `cos` a ±1 ya no fusiona dos raíces válidas. Caso 44.9999999988° / 45° conserva ±179.9994756°. App no regenerada. F1 cerrada en commit `74959a2` | F2.1 |
| 30/09/2026 | F2.1–F2.4 | Cota geométrica completa, dominio sin huecos, seam/clipping separado, actor latest-wins y caché LRU. 445 tests / 1 omitido / 0 fallos; objetivo 1 km medido ≤0.281597 km; benchmark debug M3 p50 1.309 ms/p95 1.364 ms, 5936 vértices. Sin commit ni empaquetado | F3.1 solo bajo autorización |

Al continuar: añadir fila con paquetes, comandos/resultados reales, límites y siguiente acción; no borrar decisiones previas sin explicar la sustitución.
