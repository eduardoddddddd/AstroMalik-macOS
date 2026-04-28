# Arquitectura de Direcciones Primarias

## 1. Resumen

El módulo de Direcciones Primarias implementa cálculo, navegación profesional e interpretación de direcciones primarias tradicionales. Usa proyección Regiomontana adaptada de Morinus, soporta claves Naibod/Ptolomeo/Brahe y combina tres capas: cálculo determinista, corpus clásico curado y lectura contextual opcional.

## 2. Motor Astronómico

### 2.1 Cálculo

El motor calcula direcciones primarias con dos pasadas explícitas cuando las conversas están activadas:

- **Directa:** el significador permanece como referencia. Para cada significador, prómissor y aspecto, el arco se calcula con el espéculo y el polo Regiomontano del significador. El signo del arco se conserva como dato técnico; no determina si la dirección es directa o conversa.
- **Conversa:** los roles astronómicos se invierten para el cálculo. El prómissor original queda como punto fijo de referencia, se construye su espéculo, y el significador original se dirige hacia ese punto usando el polo del prómissor. La dirección mantiene las etiquetas originales de prómissor y significador, pero queda marcada como `conversa`.

El RAMC se obtiene con `swe_sidtime0(jd, eps, dpsi)` usando oblicuidad verdadera y nutación del momento, para mantener paridad con Morinus.

Las claves temporales convierten arco en edad así:

- **Naibod:** movimiento solar medio fijo.
- **Ptolomeo:** 1 grado por año.
- **Brahe:** arco de ascensión recta recorrido por el Sol entre el nacimiento y las siguientes 24 horas. Si se recibe velocidad solar natal en longitud eclíptica, se convierte primero a arco equivalente de ascensión recta.

Pars Fortunae se calcula con la fórmula dependiente de secta (`ASC + Luna - Sol` de día, `ASC + Sol - Luna` de noche) y se registra como cuerpo ecuatorial. No forma parte de los prómissores por defecto, pero funciona si el usuario lo activa en filtros/configuración.

## 3. Corpus Clásico (Capa 1)

El corpus de producción ya incluye 165 interpretaciones clásicas pobladas desde Lilly, `Christian Astrology`, Libro III, sección de efectos de direcciones. La migración `006_populate_pd_classical_corpus.sql` deja esas claves en verde, con referencia localizable y texto editorial en castellano.

La política de honestidad sigue vigente:

- solo se marca `populated = 1` cuando existe fuente trazable
- las claves sin fuente suficiente permanecen fuera del texto principal
- el UI prioriza corpus curado sobre cualquier lectura contextual
- el informe de población vive en `corpus_sources/reports/pd_corpus_population_report.md`

## 4. Contextual Interpretation (Capa 2)

Un motor contextual opcional vía OpenRouter opera independientemente del corpus clásico. El prompt (`pd_contextual_prompt.md`) sigue el sistema morinista y dinámicamente incorpora:

- Natal state of the Promissor and Significator
- Essential and Accidental dignities (via `EssentialDignityEngine`)
- Sect and mutual receptions
- House positions and rulerships
- The specific aspect forming in the direction

## 5. Prompt Versioning & Invalidations

To handle changes to the LLM instructions smoothly, we employ a `prompt_version` integer constant. The `user.db` caching layer (`002_primary_directions_interpretations.sql`) pairs cached interpretations with this version. Bumping the version immediately invalidates stale caches, guaranteeing that new prompt instructions are faithfully reflected in newly requested contextual readings without needing a database schema migration.

## 6. Migration Conventions

Migrations are managed linearly via `MigrationRunner`.

- Files prefixed `001_*` apply to the read-only `corpus.db` (usually copied on first launch).
- Files prefixed `002_*` and above apply to `user.db` for user-specific data and caches. Migrations are tracked in the `migrations_applied` table to ensure idempotency.

## 7. Arquitectura UI

La UI de Direcciones Primarias se organiza en tres zonas persistentes:

- **Header:** chart selector, filters, settings, Joplin note actions, status chips, and a compact info popover for the corpus honesty policy.
- **Timeline:** horizontal age navigator with semantic lanes by significator: ASC, MC, Sun, Moon, other bodies, and DSC/IC. Dense events in the same lane are clustered and opened through a popover.
- **Two-pane workspace:** the left pane is a tabbed navigator and the right pane is the selected direction detail.

El panel izquierdo expone tres flujos alternativos:

- **Lista profesional:** dense native SwiftUI `Table`, sortable by age, date, promissor, aspect, significator, arc, type, plane, and text status.
- **Cards:** the previous card-based exploration list, preserved for discovery and quick scanning.
- **Año en curso:** annual consultation view centered on a selected year, including directions whose estimated dates fall within the residual activation window of ±18 months.

El panel de detalle sigue una jerarquía de lectura profesional:

- Hero no colapsable con título de dirección, edad exacta, fecha estimada, ventana de activación, polaridad, tipo y plano.
- Interpretación principal no colapsable, elegida por prioridad: corpus curado, texto contextual LLM y lectura auxiliar local.
- Alternativas opcionales, factores contextuales, espéculo Regiomontano completo y datos de cálculo detrás de secciones desplegables.

## 8. Presets Y Pesos

Los presets controlan ruido interpretativo sin recalcular doctrina:

- **Clásico:** default para usuarios nuevos; excluye transpersonales y prioriza significadores tradicionales.
- **Extendido:** añade más puntos y aspectos útiles.
- **Completo:** muestra el universo amplio disponible para investigación.

Cada dirección recibe un peso (`crítica`, `mayor`, `moderada`, `menor`) que afecta timeline, tabla y detalle. El filtro de peso mínimo permite convertir una lista enorme en una consulta anual legible.

## 9. Año En Curso

La vista “Año en curso” centra la consulta en un año civil y muestra direcciones cuya fecha estimada cae dentro de una ventana residual de ±18 meses. Está pensada como vista de consulta, no solo como tabla técnica: tarjetas cronológicas, texto principal abreviado y señales de peso/polaridad.
