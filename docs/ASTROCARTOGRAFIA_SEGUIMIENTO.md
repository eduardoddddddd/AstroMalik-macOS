# Astrocartografía — seguimiento y relevo entre LLM

Actualizado: **30/09/2026**, zona Europe/Madrid. Fase 0 en commit `6a48a77` (base previa `26f6d92`). F1.1–F1.4 están en el worktree, sin commit. La app no se ha reempaquetado después de F1.1.

**Este es el documento que hay que actualizar al terminar cada paquete.**
Plan y criterios completos: [ASTROCARTOGRAFIA_PLAN_MULTILLM.md](ASTROCARTOGRAFIA_PLAN_MULTILLM.md).

## 1. Estado de entrega

**Fase 1 implementada y validada en tests locales. Siguiente paquete: F2.1.** La app empaquetada sigue siendo la de las 20:01:40, anterior a los meridianos y a las curvas.

- Existe motor de líneas mundanas (MC/IC y raíces ASC/DSC). **No hay muestreo adaptativo ni mapa.**
- La fase 0 está en el commit local `6a48a77`. La fase 1 y este seguimiento siguen sin commit. No hay push, tag ni release. El usuario pidió no regenerar la app hasta que lo pida.
- No se han creado agentes, otras sesiones ni worktrees. Otro LLM puede continuar en este repositorio tras leer este documento y comprobar `git status`.
- No se ha modificado el C vendorizado, el corpus, la base de datos del usuario ni el servidor.
- Validación local, no revisión independiente de otro LLM ni Thread Sanitizer. La comparación Python es independiente del binding Swift, **no de los algoritmos Swiss**.

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

- [ ] **F2.1** Muestreo adaptativo y precisión.
- [ ] **F2.2** Antimeridiano y clipping de representación.
- [ ] **F2.3** Caché, cancelación y protección frente a resultados obsoletos.
- [ ] **F2.4** Tests de discontinuidades y rendimiento.
- [ ] **G2** Geometría lista para dibujar.

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

## 3. Qué se ha implementado en esta sesión

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

No se ejecutó TSan, un benchmark formal ni revisión externa por otro LLM. No se probó manualmente un mapa porque no existe aún.

## 5. Siguiente acción concreta para cualquier LLM

1. Leer `AGENTS.md`, este seguimiento y el plan; revisar `git status` sin descartar cambios pendientes.
2. Ejecutar guard y tests con el `DEVELOPER_DIR` indicado.
3. Implementar **F2.1**: muestreo adaptativo de las curvas ya calculadas, con error geométrico acotado y refinamiento cerca de las tangencias. No sustituir la rejilla de 1° de F1 como si ya cumpliera el objetivo de 1 km.
4. No regenerar `phase0-analytic-lines.json` ni la referencia Python con la salida del motor. No meter todavía el mapa ni afirmar que un dibujo valida el cálculo.
5. El empaquetado de la app queda en pausa hasta que el usuario lo pida. Los tests sí deben ejecutarse con `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer`.
6. Actualizar casillas, evidencia y bitácora. No hacer push/release sin autorización.

### Prompt para continuar

```text
Continúa la astrocartografía de AstroMalik-macOS desde
docs/ASTROCARTOGRAFIA_SEGUIMIENTO.md.
Fase 0 está en el commit 6a48a77. La fase 1 está en el worktree sin commit
y la app no se ha reempaquetado. Revisa esos cambios. Implementa F2.1,
sin tratar la rejilla de 1° como geometría final. No sobrescribas
fixtures independientes ni modifiques UI, corpus o servidor. No ejecutes
scripts/package_app.sh salvo petición explícita. Registra aquí
lo que completes y lo pendiente para que otro LLM pueda seguir. Tras código,
ejecuta los tests. No empaquetes la app hasta que el usuario lo pida.
```

## 6. Bitácora

| Fecha | Paquetes | Evidencia / salida | Siguiente |
|---|---|---|---|
| 30/09/2026 | F0.1–F0.4 | Contratos, fachada, inventario, fixtures, guard, 418 tests / 1 omitido / 0 fallos; paquete y firma verificados, binario 19:48:17 CEST. Commit local `6a48a77`, sin push | F1.1 |
| 30/09/2026 | F1.1 | Adaptador ecuatorial, diagnóstico de fallback y `swe_version` en la fachada. 422 tests / 1 omitido / 0 fallos; binario 20:01:40 CEST. Sin commit | F1.2 |
| 30/09/2026 | F1.2–F1.4 | Meridianos, raíces ASC/DSC, tangencias y circumpolaridad. Residuo de meridiano 0; seno de altitud ≤ 1.97e-15. 427 tests / 1 omitido / 0 fallos. App no regenerada, por petición | F2.1 |
| 30/09/2026 | F1.3 corrección | La proximidad de `cos` a ±1 ya no fusiona dos raíces válidas. Caso 44.9999999988° / 45° conserva ±179.9994756°. App no regenerada | F2.1 |

Al continuar: añadir fila con paquetes, comandos/resultados reales, límites y siguiente acción; no borrar decisiones previas sin explicar la sustitución.
