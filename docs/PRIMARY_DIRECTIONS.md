# Primary Directions Architecture

## 1. Overview

The Primary Directions module implements the calculation and interpretation of primary directions, a traditional predictive astrological technique. It uses rigorous astronomical algorithms based on the Regiomontanus projection system (adapted from Morinus) and supports Ptolemaic, Naibod, and Brahe keys for time conversions.

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

## 3. Corpus Honesty Policy (Capa 1)

All primary direction meanings stored in the internal SQLite database (`001_primary_direction_meanings.sql`) strictly adhere to an "Honesty Policy". They are inserted with `populated=0` and generic placeholders until verified citations from traditional sources (e.g., Bonatti, Lilly) are curated. This ensures that only historically accurate textual interpretations are eventually shown as primary sources. The UI actively reflects this status, hiding unpopulated entries unless explicitly requested.

## 4. Contextual Interpretation (Capa 2)

An autonomous, LLM-based interpretation engine (via OpenRouter) operates independently of the populated status of Capa 1. The contextual prompt (`pd_contextual_prompt.md`) follows the Morinian system and dynamically incorporates:

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

## 7. UI Architecture

The Primary Directions UI is organized into three persistent zones:

- **Header:** chart selector, filters, settings, Joplin note actions, status chips, and a compact info popover for the corpus honesty policy.
- **Timeline:** horizontal age navigator with semantic lanes by significator: ASC, MC, Sun, Moon, other bodies, and DSC/IC. Dense events in the same lane are clustered and opened through a popover.
- **Two-pane workspace:** the left pane is a tabbed navigator and the right pane is the selected direction detail.

The left pane exposes three alternative workflows:

- **Lista profesional:** dense native SwiftUI `Table`, sortable by age, date, promissor, aspect, significator, arc, type, plane, and text status.
- **Cards:** the previous card-based exploration list, preserved for discovery and quick scanning.
- **Año en curso:** annual consultation view centered on a selected year, including directions whose estimated dates fall within the residual activation window of ±18 months.

The detail pane follows a professional reading hierarchy:

- A non-collapsible hero block with the direction title, exact age, estimated date, activation window, polarity, type, and plane.
- A non-collapsible primary interpretation selected by priority: curated corpus, contextual LLM text, then local auxiliary reading.
- Optional alternatives, contextual factors, full Regiomontanus speculum, and calculation data behind explicit disclosure sections.
