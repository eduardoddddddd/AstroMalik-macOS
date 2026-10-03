# Astrocartografía: plan por fases y paquetes multi-LLM

Fecha: 30 de septiembre de 2026. Base inspeccionada: `26f6d92`.
Estado (actualizado 02/10/2026): **fases 0–4 implementadas y committeadas localmente; fase 5 implementada en el árbol de trabajo (ver seguimiento); fases 6–7 pendientes; sin autorización de publicación**. Guía editorial de F5: [ASTROCARTOGRAFIA_GUIA_EDITORIAL.md](ASTROCARTOGRAFIA_GUIA_EDITORIAL.md).
Seguimiento vivo y punto de relevo: [ASTROCARTOGRAFIA_SEGUIMIENTO.md](ASTROCARTOGRAFIA_SEGUIMIENTO.md).

## 1. Objetivo y estrategia de entrega

Añadir astrocartografía local y determinista a AstroMalik, con resultados astronómicos verificables, mapa interactivo y posterior lectura de lugares. Dividir el trabajo por contratos y propiedad de archivos, no pedir a varios LLM que «implementen la astrocartografía» simultáneamente.

**Tres entregas independientes:**

1. **MVP técnico — fases 0–3:** diez planetas, líneas ASC/DSC/MC/IC, mapa, filtros, selección y diagnóstico. Sin interpretación generativa ni cambios en el corpus.
2. **Versión funcional completa — fases 4–5:** proximidad a líneas, carta relocada, lugares guardados y 40 lecturas originales planeta × ángulo.
3. **Distribución y exportaciones — fases 6–7:** PDF, Joplin bajo acción explícita, CLI, documentación y validación final.

La calidad, tests, empaquetado y revisión se exigen en **cada entrega**, no se posponen hasta la fase 7. Los parans, Local Space y técnicas avanzadas quedan fuera de estas tres entregas.

**No objetivos iniciales:** encontrar «la mejor ciudad para vivir», predecir resultados garantizados, rectificar la hora, crear un proveedor nuevo de mapas, contratar servicios o modificar el servidor remoto. Las interpretaciones se presentan como tradición simbólica, no como evidencia de efectos causales demostrados.

## 2. Punto de partida real del repositorio

| Componente existente | Reutilización prevista | Precaución |
|---|---|---|
| `Package.swift`: Swift tools 5.9, macOS 14, sin dependencias externas | Mantener compatibilidad y distribución actual | No convertir esta tarea en migración a Swift 6 |
| `Engine/AstroEngine.swift` | Planetas, casas y asignación a casas | No tocar resultados natales para acomodar el mapa |
| `Engine/SecondaryProgressionEngine.swift` | Patrón de cálculo ecuatorial y tiempo sidéreo | Extraer/reutilizar la técnica; no acoplar el módulo a progresiones |
| `Engine/JulianDay.swift` | Conversión de fecha/hora natal a instante | Auditar UTC/UT1, segundos y cambios de hora; no duplicar conversores |
| `Models/NatalChart.swift` | Carta de origen y vínculo persistente | `PlanetBody.longitude` no contiene RA, declinación ni latitud eclíptica; recalcular efemérides |
| `Services/PlacesService.swift` | Ciudades locales y búsqueda Nominatim | Zona horaria inferida por regiones/offset: aproximada, no autoridad histórica |
| `AppNavigation.swift`, `AstroMalikApp.swift`, `Views/ContentView.swift` | Ruta de navegación y carta activa | Archivos compartidos: solo los modifica el integrador |
| `Store/UserStore.swift`, `Store/SQLiteDB.swift` | Persistencia de usuario | Guardados del usuario separados del corpus editorial |
| `Reports/Service`, `Reports/Builders`, `Reports/Data` | PDF y plantillas | Comprobar carga de recursos y reportes sin red |
| `Services/JoplinClipperService.swift` | Exportación documental voluntaria | Nunca exportar automáticamente cartas o notas personales |
| `Sources/AstroMalikCLI/main.swift` | Comandos headless | Preservar comandos actuales; no introducir dependencias de ventana |

Las rutas de la tabla son relativas a `Sources/AstroMalik/`, salvo las indicadas expresamente.

**Hallazgo bloqueante:** `Sources/CSwissEph/include/sweodef.h` deja `TLS` vacío bajo `__APPLE__`. Hay llamadas directas `swe_*` en varios motores. No basta con crear un actor exclusivo para astrocartografía: no protegería las llamadas de otros módulos. La fase 0 debe establecer una estrategia común antes de ejecutar efemérides nuevas en paralelo.

No se ha encontrado implementación de astrocartografía ni uso de MapKit en `Sources`. Hay propuestas anteriores en `docs/detailed_implementation_plan.md` y `docs/plan_implementacion_gemini3.1pro.md`; este documento concreta el reparto, sin declarar implementadas esas propuestas.

## 3. Escala de complejidad y asignación de LLM

Los puntos son **peso relativo de implementación, pruebas y revisión**, no horas ni tokens. No sirven para comparar rendimientos entre proveedores sin una fase piloto.

| Nivel | Puntos | Tipo de trabajo | Perfil recomendado |
|---|---:|---|---|
| C1 — baja | 1 | Documentación o recurso acotado con formato cerrado | LLM económico; revisión por checklist |
| C2 — media | 2 | Componente aislado, CRUD o tests de contrato | LLM generalista de programación |
| C3 — alta | 3 | Integración, estado asíncrono, persistencia o interacción compleja | LLM fuerte en Swift/macOS |
| C4 — muy alta | 5 | Geometría esférica, singularidades, concurrencia global o validación independiente | LLM de máximo razonamiento y revisor distinto |

No delegar C4 a un modelo pequeño para «ahorrar» y compensar luego con revisión superficial. Los cambios numéricos requieren revisión independiente; los textos requieren revisión editorial. La potencia del modelo no sustituye pruebas.

### Roles estables

- **I — Integración/arquitectura:** contratos, archivos compartidos, merges, empaquetado y criterios de salida.
- **N — Núcleo numérico:** efemérides, geometría y relocalización; perfil C4.
- **U — UI/mapas:** adaptación MapKit, interacción y accesibilidad; perfil C3/C4.
- **Q — QA independiente:** fixtures, validación alternativa, regresiones; perfil C4 en matemática.
- **D — Datos/contenido/exportación:** persistencia, corpus, PDF y CLI; perfil C2/C3, con revisión editorial.

Son cinco **funciones**, no cinco agentes necesariamente simultáneos. Con cuatro sesiones: I+N+U+Q durante el núcleo; después I+U+D+Q. Con tres: I/Q en turnos separados, N y U; una revisión C4 final debe seguir siendo independiente del autor.

## 4. Contratos que deben cerrarse antes de paralelizar

Ubicación propuesta: `Sources/AstroMalik/Astrocartography/`, subdividida en `Models`, `Calculation`, `Services`, `Persistence`, `Interpretation`, `ViewModels` y `Views`.

El núcleo depende de Foundation y del adaptador Swiss; **no depende de MapKit, SwiftUI, servicios HTTP, corpus ni un LLM**. Usa coordenadas propias de dominio, no `CLLocationCoordinate2D`; la conversión pertenece a UI.

Contratos mínimos que I entrega en F0.2:

| Tipo/servicio propuesto | Contenido mínimo |
|---|---|
| `AstrocartographyRequest` | Instante natal validado, cuerpos, convención astronómica y tolerancia; sin depender solo del UUID de carta |
| `EquatorialSnapshot` | JD/escala temporal declarada, RA/declinación por cuerpo, tiempo sidéreo, flags y versión de efemérides |
| `AstroLineID` | Identificador estable planeta + ángulo + convención |
| `GeoCoordinate`, `AstroLineSegment` | Latitud/longitud en grados, segmentos independientes, sin puntos no finitos |
| `AstrocartographyResult` | Líneas, diagnósticos, procedencia y versión del algoritmo |
| `LocationAnalysis` | Lugar, distancias y puntos más próximos, métrica/tolerancia; sin «puntuación de felicidad» |
| `RelocatedChartResult` | Referencia natal, mismo instante, destino, casas/ángulos y advertencias |
| `AstrocartographyReading` | Planeta, ángulo, texto, versión y trazabilidad editorial |

Definir `Codable`/`Sendable` donde corresponda, unidades, errores tipados, ejemplos JSON sintéticos y orden determinista. Las interfaces de cálculo deben permitir inyectar efemérides simuladas para tests y UI. El integrador congela contratos `v1`; los demás LLM no los cambian unilateralmente.

### Decisiones astronómicas propuestas a ratificar en fase 0

- Diez cuerpos de `PLANET_LIST`; nodos, asteroides y estrellas fuera del MVP.
- Angularidad **mundana/geocéntrica**, horizonte geométrico del centro del cuerpo; sin refracción, semidiámetro ni paralaje topocéntrico en esta versión. Hacer explícita la convención para poder comparar resultados.
- RA/declinación y tiempo sidéreo con equinoccio/nutación coherentes. No mezclar J2000, coordenadas de fecha y tiempo sidéreo incompatible.
- Longitud terrestre este positiva; grados públicos, radianes dentro de trigonometría. Tiempo sidéreo de Swiss convertido desde horas cuando corresponda.
- Reutilizar el instante natal; documentar la aproximación UTC/UT1 actual y el rango de fechas soportado. No prometer precisión subarcosegundo si no se dispone de la escala temporal necesaria.
- Mapas independientes del sistema de casas. Relocalización conserva el sistema natal cuando es calculable; si falla cerca de los polos, mostrar el error y ofrecer una alternativa **explícita**, nunca sustituirla en silencio.

## 5. Desglose ejecutable por fases

Cada fila es un paquete delegable con propietario, dependencia y prueba de aceptación. `Gx` significa puerta de salida de la fase x; las tareas de una misma fase no son automáticamente paralelizables.

### Fase 0 — especificación, seguridad y contratos

| ID | Tarea | Nivel | Dueño | Depende de | Aceptación |
|---|---|---|---|---|---|
| F0.1 | Auditar llamadas Swiss, configuración global, escalas temporales y límites existentes | C4 / 5 | I+Q | — | Inventario y estrategia de exclusión común, sin suponer seguridad por actor local |
| F0.2 | Fijar convenciones, tipos, errores y fixtures simulados | C3 / 3 | I | F0.1 | Contratos compilables y ejemplos consumibles por N/U/Q/D |
| F0.3 | Crear plan de validación y casos de referencia independientes | C4 / 5 | Q | F0.2 | Casos con procedencia, flags y tolerancias; no copiar resultados del motor nuevo |
| F0.4 | Implantar exclusión común necesaria y regresiones de concurrencia | C4 / 5 | I | F0.1, F0.2 | Todas las llamadas concurrentes relevantes participan; configuración/cálculo protegidos como transacción |

**G0:** contratos congelados y exclusión verificada. Si F0.4 exige refactor amplio, tratarlo como prerrequisito separado con revisión; no esconderlo dentro de la UI. Inventariar también app, CLI y tests, evitando bloqueo recursivo, deadlocks y suspensiones dentro de una sección crítica. No cambiar el C vendorizado para habilitar TLS sin una evaluación específica.

### Fase 1 — núcleo astronómico

| ID | Tarea | Nivel | Dueño | Depende de | Aceptación |
|---|---|---|---|---|---|
| F1.1 | Adaptador ecuatorial y snapshot inmutable de diez cuerpos | C3 / 3 | N | G0 | RA/declinación/tiempo sidéreo, flags reales, errores y fallback trazables |
| F1.2 | Calcular meridianos MC/IC | C2 / 2 | N | F1.1 | Meridianos opuestos 180°, normalización y hemisferios correctos |
| F1.3 | Calcular curvas ASC/DSC y límites circumpolares | C4 / 5 | N | F1.1 | Raíces este/oeste correctas, tangencias y ausencia de cruce distinguibles |
| F1.4 | Ejecutar comparación independiente y propiedades numéricas | C4 / 5 | Q | F0.3, F1.2, F1.3 | Informe de errores máximos y explicación de cualquier discrepancia |

**G1:** cálculo aceptado sin mapa; resultados deterministas, sin NaN/Inf. El mapa no se usa para decidir si la matemática es correcta.

Especificación matemática mínima para revisión, con `α` ascensión recta, `δ` declinación, `θ` tiempo sidéreo de Greenwich en grados, `φ` latitud y `λ` longitud este:

```text
H = θ + λ − α
MC: H = 0°                IC: H = 180°
sin(h) = sin(φ)sin(δ) + cos(φ)cos(δ)cos(H)
Horizonte: h = 0          cos(H0) = −tan(φ)tan(δ)
ASC: H = −H0             DSC: H = +H0
λ = normalizar(α − θ + H)
```

No extender `acos` mediante un clamp indiscriminado: fuera del dominio puede no existir cruce; solo se corrigen excesos de redondeo dentro de epsilon documentado. Polos, declinación cero y tangencias necesitan tratamiento específico. MC/IC indican culminación superior/inferior, no necesariamente visibilidad sobre el horizonte. La fórmula es una especificación revisable, no una implementación ya validada.

### Fase 2 — geometría geográfica y representación

| ID | Tarea | Nivel | Dueño | Depende de | Aceptación |
|---|---|---|---|---|---|
| F2.1 | Muestreo adaptativo, extremos válidos y límites de precisión | C4 / 5 | N | G1 | Error geométrico acotado y refinamiento cerca de singularidades |
| F2.2 | Cortar antimeridiano y adaptar al dominio visible del mapa | C4 / 5 | U | F0.2; cierre tras F2.1 | Sin líneas que crucen falsamente el mundo; límites polares sin inventar puntos |
| F2.3 | Cache, cancelación y estado de cálculo | C3 / 3 | N | F2.1 | Clave por datos/convención/versión; editar carta invalida; resultado antiguo nunca sobrescribe el actual |
| F2.4 | Tests de discontinuidades, errores de muestreo y rendimiento | C3 / 3 | Q | F2.1–F2.3 | Fixtures de ±180°, extremos, rutas partidas y serie de cambios rápidos |

**G2:** geometría lista para dibujar. Se distingue la curva astronómica completa de sus segmentos renderizables. El límite visual de latitud/proyección no recorta el cálculo usado para analizar lugares.

F2.2 puede empezar con fixtures mientras N desarrolla F1; su aceptación final espera geometría real. Un segmento visual no se une a otro por simple cercanía de coordenadas.

### Fase 3 — mapa usable: cierre del MVP

| ID | Tarea | Nivel | Dueño | Depende de | Aceptación |
|---|---|---|---|---|---|
| F3.1 | Spike de MapKit: elegir `Map` o `MKMapView` encapsulado | C3 / 3 | U | F0.2 | Probar overlays, selección, zoom y actualización en macOS 14; registrar elección |
| F3.2 | Vista de mapa, estilos, leyenda y filtros | C3 / 3 | U | F3.1, G2 | Hasta 40 líneas lógicas, identidad estable, sin duplicar overlays |
| F3.3 | Selección de línea/lugar, panel y accesibilidad | C3 / 3 | U | F3.2 | Teclado y lista alternativa; distinguir líneas sin depender solo del color |
| F3.4 | Ruta de app, carta activa, estados vacíos/error y empaquetado MVP | C3 / 3 | I | F3.3, F2.3 | Cambiar carta recalcula; sin carta no calcula; app regenerada y smoke test |

**G3 / MVP:** diez cuerpos × cuatro tipos de línea accesibles, mapa filtrable y datos verificables. Una línea lógica puede tener varios segmentos o no cruzar ciertas latitudes: no comprobar «40 polilíneas» como criterio rígido.

Propuesta inicial: evaluar primero el control necesario; usar `MKMapView` vía `NSViewRepresentable` si la selección de overlays y el rendimiento justifican el puente AppKit. No mantener dos implementaciones. El MVP debe funcionar sin red en cálculo y listado; no prometer mapas base offline, ni pedir ubicación del usuario para calcular su carta.

### Fase 4 — análisis de lugares y carta relocada

| ID | Tarea | Nivel | Dueño | Depende de | Aceptación |
|---|---|---|---|---|---|
| F4.1 | Distancia mínima a curvas y clasificación de cercanía | C4 / 5 | N | G2 | Distancia en km sobre esfera con radio documentado y error medido; no distancia a píxeles ni solo a vértices |
| F4.2 | Motor de relocalización independiente de UI | C4 / 5 | N | G1 | Mismo instante y posiciones geocéntricas; nuevas casas/ángulos; natal original intacta |
| F4.3 | Búsqueda, selección manual y comparación de lugares | C3 / 3 | U | G3, F4.1, F4.2 | Destino sin zona fiable no cambia JD; entrada manual válida y modo sin red |
| F4.4 | Guardados y versión de esquema | C3 / 3 | D | F0.2, F4.3 | Persistir intención y procedencia; recuperar/eliminar; carta modificada invalida resultados |

**G4:** se pueden comparar lugares, entender distancias y consultar carta relocada sin modificar la natal.

La distancia es **geográfica** bajo una métrica declarada, no «intensidad astrológica». Los umbrales de cercanía son parámetros de producto, no constantes científicas. Medir a la curva o refinar respecto a ella, no a la versión visual simplificada. Distinguir distancia global de líneas actualmente ocultas por filtros.

Para zona horaria del destino: usar UTC si no está verificada, o presentar la inferencia como aproximada. Nunca reinterpretar la hora de nacimiento en la zona del destino. La coincidencia mundana con un ángulo no se valida simplemente igualando longitud eclíptica del planeta y cúspide: la latitud eclíptica del cuerpo importa.

### Fase 5 — interpretación editorial local

| ID | Tarea | Nivel | Dueño | Depende de | Aceptación |
|---|---|---|---|---|---|
| F5.1 | Esquema y guía editorial para planeta × ángulo | C2 / 2 | D | F0.2 | 40 claves, nombres estables, fuentes/procedencia y política de derechos |
| F5.2 | Redactar 40 textos originales y revisarlos | C3 / 3 | D+Q | F5.1 | 40/40 completos; sin copia, fatalismo ni afirmaciones de certeza |
| F5.3 | Repositorio de lecturas y conexión con lugares | C3 / 3 | D | F5.2, G4 | Consulta offline, cobertura automática y fallback visible si falta una clave |
| F5.4 | Vista de lectura y comparación legible | C2 / 2 | U | F5.3 | Texto completo disponible, nombres reales y distancias separadas de interpretación |

**G5 / versión funcional:** lectura local completa, revisión humana/editorial y cero llamadas LLM necesarias en ejecución.

F5.1–F5.2 pueden avanzar desde G0. Preparar contenido en un recurso textual versionable antes de promoverlo; el integrador decide su incorporación al corpus existente tras revisar esquema y migraciones. No permitir que varios LLM editen a la vez `corpus.db`. No reutilizar textos de sinastría como si describieran astrocartografía.

Narrativa generativa opcional: proyecto posterior, con consentimiento, proveedor y coste visibles; nunca sustituye cálculo, distancias ni textos básicos.

### Fase 6 — exportaciones, Joplin y CLI

| ID | Tarea | Nivel | Dueño | Depende de | Aceptación |
|---|---|---|---|---|---|
| F6.1 | ReportData + builder + plantilla PDF | C3 / 3 | D | G5 | Datos, convenciones, advertencias y lecturas; smoke y revisión visual |
| F6.2 | Imagen del mapa en PDF y fallback sin red | C3 / 3 | U | F6.1 | Captura reproducible con overlays; atribución preservada; si falla, informe sin mapa explícito |
| F6.3 | Exportar a Joplin reutilizando servicio actual | C2 / 2 | D | F6.1 | Solo al pulsar exportar; nota detallada, etiquetas útiles, carpeta Codex por defecto |
| F6.4 | CLI astrocartografía/relocalización con JSON versionado | C3 / 3 | D | G4, contratos F0.2 | Salida determinista, códigos de error y tests; sin ventana ni red obligatoria |

**G6:** exportaciones verificadas y app/CLI consistentes. CLI puede comenzar después de G4; no necesita esperar el PDF. El entry point y registro de recursos los modifica I a partir de parches acotados.

### Fase 7 — endurecimiento y entrega

| ID | Tarea | Nivel | Dueño | Depende de | Aceptación |
|---|---|---|---|---|---|
| F7.1 | Regresión completa, estrés, concurrencia y rendimiento | C4 / 5 | Q | G6 | Informe independiente, sin fallos bloqueantes ni regresiones natales |
| F7.2 | Ayuda, metodología, README y CHANGELOG | C1 / 1 | D | G6 | Alcance, límites y ejemplos coinciden con lo implementado |
| F7.3 | Empaquetar y verificar app/distribución | C3 / 3 | I | F7.1, F7.2 | Tests, paquete, timestamp y lanzamiento confirmados; release solo si se autoriza |

**G7:** versión candidata entregable. Commit, push, tag y release requieren el alcance autorizado; este plan no los autoriza por sí mismo.

## 6. Paralelismo real y camino crítico

```text
F0.1 → F0.2 → F0.4 → G0 → F1 → G1 → F2 → G2 → F3 → G3 (MVP)
          ├── Q: F0.3 / referencias independientes ───────────┘
          ├── U: F3.1 / UI simulada / F2.2 ──────────────────┘
          └── D: F5.1 → F5.2 (sin tocar corpus.db)

G1 → F4.2 ─┐
G2 → F4.1 ─┼→ F4.3 → F4.4 → G4 → F5.3 → F5.4 → G5
G3 ────────┘                     └→ F6.4 (CLI)
G5 → F6.1 → F6.2 / F6.3 → G6 → F7 → G7
```

El diagrama simplifica la ruta principal; las dependencias exactas son las de las tablas. Fixtures y diseños con mocks pueden adelantarse; aceptación/integración nunca salta una puerta.

| Oleada | I | N | U | Q / D |
|---|---|---|---|---|
| A | F0.1/F0.2/F0.4 | Consultoría numérica; sin cambios compartidos | Spike con mocks tras F0.2 | Q: F0.3 |
| B | Revisión e integración de contratos | F1.1–F1.3 | F3.1, prototipo y F2.2 con fixtures | Q: validación independiente |
| C | Integración MVP | F2.1/F2.3 | F3.2/F3.3 | Q: F1.4/F2.4 |
| D | G3 y revisión | F4.1/F4.2 | F4.3 | D: contenido y persistencia |
| E | Revisiones de esquema y recursos | Correcciones numéricas | Lectura y captura de mapa | D: PDF/CLI/Joplin; Q releva para revisar |
| F | Paquete final | Correcciones asignadas | Smoke visual | Q: regresiones; D: documentación |

**Cuello de botella:** las convenciones, concurrencia y verificación del motor. Añadir LLM no elimina estas dependencias. El mayor paralelismo útil está entre núcleo, UI simulada, pruebas independientes y contenido; no entre varios autores del mismo motor.

## 7. Propiedad de archivos y protocolo entre sesiones

### Áreas exclusivas

- I: `Models/` de contratos, `Package.swift`, navegación/estado global, integración de recursos, coordinación Swiss transversal y migraciones compartidas.
- N: `Astrocartography/Calculation/` y servicios numéricos asignados.
- U: `Astrocartography/Views/`, `ViewModels/` y adaptadores de mapa, incluido clipping visual; no modifica el cálculo de N.
- Q: `Tests/AstroMalikTests/Astrocartography/` para referencias e integración. Los autores usan archivos de tests propios con prefijos distintos.
- D: `Astrocartography/Persistence/`, `Interpretation/`, builders/datos/plantillas específicos y helpers CLI. Cambios en entry points se entregan a I.

La asignación exacta de cada archivo se registra antes de empezar un paquete. Un archivo tiene un único escritor a la vez, incluso si hay worktrees.

### Flujo de trabajo recomendado

1. I prepara una base común de contratos y declara el commit de partida.
2. Para ejecutar el plan, usar ramas/worktrees aislados por paquete, por ejemplo `codex/astrocartography-f1-engine`; no se crean en esta tarea documental. Si se comparte checkout, imponer exclusión de archivos y un único proceso de build/empaquetado.
3. Cada sesión recibe solo el plan, contrato, archivos autorizados y fixtures necesarios. No cargar todo el historial de otras sesiones.
4. Cada entrega incluye diff/commit, tests ejecutados, errores conocidos, cambios de API solicitados y ruta del artefacto. No afirmar que una prueba pasó sin ejecutarla.
5. I integra una unidad por vez en orden de dependencia y ejecuta regresiones. Los conflictos de contrato vuelven a F0.2 y se comunican antes de seguir.
6. Q no se limita a repetir los tests escritos por N: verifica convenciones y resultados con un procedimiento independiente.
7. Tras cambios de código/UI: ejecutar `scripts/package_app.sh` en el checkout correspondiente y verificar el binario. Solo I reemplaza/abre la app de la entrega integrada; nunca ejecutar dos empaquetados sobre la misma ruta.
8. No borrar, revertir o committear cambios ajenos para «limpiar» el árbol. No cambiar dependencias, corpus, versión de app ni servidor fuera del paquete.

### Prompt reutilizable para un LLM ejecutor

```text
Implementa únicamente el paquete [ID] del plan
docs/ASTROCARTOGRAFIA_PLAN_MULTILLM.md en AstroMalik-macOS.
Base acordada: [commit]. Contrato: [versión].
Archivos autorizados: [lista exclusiva]. Dependencias aceptadas: [IDs/Gates].

Lee AGENTS.md y el contrato antes de editar. No cambies contratos, navegación,
Package.swift, corpus.db ni archivos fuera de tu lista sin coordinar con I.
Respeta las convenciones de instante natal, angularidad y exclusión Swiss.
No uses datos personales reales como fixtures ni inventes resultados de referencia.
Implementa los criterios de aceptación de tu fila y tests propios.
Si falta una dependencia, usa el mock pactado; no implementes el módulo de otro LLM.
No uses editores interactivos, ni hagas push/release.
Tras código/UI, ejecuta los tests pertinentes, scripts/package_app.sh y verifica
timestamp del binario en tu checkout. Coordina exclusión si el checkout es compartido.
Entrega: resumen, archivos cambiados, comandos/resultados reales, límites y solicitudes a I.
```

## 8. Matriz de validación obligatoria

| Área | Casos mínimos | Qué debe detectarse |
|---|---|---|
| Tiempo | UTC, zona con DST, segundos, fecha ambigua/no existente, fechas límite soportadas | Instantes desplazados, pérdida de segundos y normalización silenciosa |
| Efemérides | Diez cuerpos, Luna incluida, archivo ausente, flags devueltos | Fallback no declarado y mezcla de convenciones |
| Geometría | Ambos hemisferios, ecuador, ±180°, polos, declinación cero, circumpolaridad y tangencia | ASC/DSC intercambiados, curvas falsas y singularidades |
| Invariantes | MC/IC separados 180°; residuo horizontal ≈ 0 en ASC/DSC; signos de ascenso/descenso | Error de signo/unidad oculto por un mapa plausible |
| Referencias | Casos sintéticos analíticos + salidas de herramienta independiente con opciones registradas | Pruebas circulares; divergencias por topocentrismo/refracción |
| Relocalización | Destinos alejados, misma ciudad natal, polos, destino con zona dudosa | Cambiar JD, planetas geocéntricos o natal persistida |
| Distancia | Lugar sobre línea, antimeridiano, extremo válido, línea oculta y ruta simplificada | Medir a vértices, a píxeles o a segmentos artificiales |
| Concurrencia | Natal/transitos y astrocartografía concurrentes; cambiar carta/cancelar repetidamente | Contaminación global, deadlocks y resultados obsoletos |
| Persistencia | Cambio/borrado de natal, reinicio, migración y datos dañados | Caché vieja y referencias huérfanas |
| UI/exportación | Claro/oscuro, teclado, pantalla pequeña, sin red, PDF largo, Joplin inaccesible | Datos invisibles, mapa engañoso y fallos silenciosos |

**Tolerancias propuestas, pendientes de ratificar en F0.3:** residuo analítico de líneas ≤ 1e-6 grados fuera de singularidades; comparación con referencia bajo idénticas convenciones ≤ 1e-4 grados en coordenadas relevantes. La geometría muestreada tendrá una tolerancia física independiente, inicialmente objetivo ≤ 1 km en regiones no singulares. Separar error de efemérides, escala temporal, cálculo, discretización y representación. Si una tolerancia resulta inviable, justificar el cambio antes de ampliar el umbral.

**Rendimiento propuesto:** medir en un Mac de referencia identificado; objetivo orientativo < 1 s para motor+geometría de diez cuerpos en caliente, excluyendo red/mapas. Publicar p50/p95 y cantidad de vértices. No bloquear el hilo principal durante geometría pesada; la sección Swiss segura produce un snapshot y termina antes de esa geometría. No declarar cumplido ningún objetivo sin benchmark.

## 9. Esfuerzo relativo y cómo presupuestarlo

| Fase | Paquetes | Puntos |
|---|---:|---:|
| 0 — contratos/seguridad | 4 | 18 |
| 1 — cálculo | 4 | 15 |
| 2 — geometría | 4 | 16 |
| 3 — mapa/MVP | 4 | 12 |
| 4 — lugares/relocalización | 4 | 16 |
| 5 — interpretación | 4 | 10 |
| 6 — exportaciones | 4 | 11 |
| 7 — entrega | 3 | 9 |
| **Total** | **31** | **107** |

- **MVP:** 16 paquetes / 61 puntos. Gran parte del riesgo está antes de la pantalla, no en dibujar líneas.
- **Completa con lectura:** 24 paquetes / 87 puntos.
- **Con exportación y cierre:** 31 paquetes / 107 puntos.

No convertir estos puntos automáticamente a días o dólares. Calibrar F0 y una tarea C2/C3 con el proveedor real, contabilizando lectura, caché, salida, razonamiento, reintentos y revisión. Reservar una contingencia explícita de planificación —orientativamente 25–35%— para concurrencia, polos y MapKit; no confundirla con tokens medidos. Un único paquete C4 puede necesitar subdivisión tras el spike; actualizar el plan, no ocultar trabajo adicional.

## 10. Ampliaciones posteriores, separadas del compromiso inicial

| Ampliación | Complejidad | Condición para empezar |
|---|---|---|
| Parans | C4 | Definición doctrinal y geométrica propia; no equiparar automáticamente a cruces del mapa |
| Local Space | C4 | Especificar azimut, horizonte y convención separada |
| Sensibilidad a incertidumbre de hora | C4 | Motor estable y método explícito; no presentar bandas como probabilidades sin modelo |
| Otros cuerpos / nodos | C2–C3 | Convención, efemérides y textos completos |
| Narrativa LLM opcional | C3 | Consentimiento, costes, privacidad y evaluación contra datos deterministas |
| Mapas offline / otro proveedor | C4 | Necesidad demostrada, licencia y presupuesto propios |

## 11. Fuentes y límites de la planificación

- Base primaria: código local inspeccionado en el commit indicado. El diseño modular, reparto y tolerancias son propuestas de este plan, no funcionalidades existentes.
- [Swiss Ephemeris — interfaz oficial](https://www.astro.com/swisseph/swephprg.htm): referencia para flags, coordenadas ecuatoriales, tiempo sidéreo y casas. Registrar las opciones exactas de cada fixture; no comparar valores calculados con convenciones diferentes.
- [Apple — MKMapView](https://developer.apple.com/documentation/mapkit/mkmapview) y [Apple — MapPolyline](https://developer.apple.com/documentation/mapkit/mappolyline): referencia oficial para mapa y overlays; F3.1 verifica capacidades con el SDK local y despliegue macOS 14 antes de fijar la integración.

**Siguiente acción recomendada:** la fase 7 está cerrada en local como candidata. Publicar (commit, push, tag o release) solo con autorización explícita. Sigue abierta la lentitud al cambiar de pestaña del panel. Punto de relevo vivo: seguimiento.
