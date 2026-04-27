# Primary Directions Architecture

## 1. Overview
The Primary Directions module implements the calculation and interpretation of primary directions, a traditional predictive astrological technique. It uses rigorous astronomical algorithms based on the Regiomontanus projection system (adapted from Morinus) and supports Ptolemaic, Naibod, and Brahe keys for time conversions.

## 2. Corpus Honesty Policy (Capa 1)
All primary direction meanings stored in the internal SQLite database (`001_primary_direction_meanings.sql`) strictly adhere to an "Honesty Policy". They are inserted with `populated=0` and generic placeholders until verified citations from traditional sources (e.g., Bonatti, Lilly) are curated. This ensures that only historically accurate textual interpretations are eventually shown as primary sources. The UI actively reflects this status, hiding unpopulated entries unless explicitly requested.

## 3. Contextual Interpretation (Capa 2)
An autonomous, LLM-based interpretation engine (via OpenRouter) operates independently of the populated status of Capa 1. The contextual prompt (`pd_contextual_prompt.md`) follows the Morinian system and dynamically incorporates:
- Natal state of the Promissor and Significator
- Essential and Accidental dignities (via `EssentialDignityEngine`)
- Sect and mutual receptions
- House positions and rulerships
- The specific aspect forming in the direction

## 4. Prompt Versioning & Invalidations
To handle changes to the LLM instructions smoothly, we employ a `prompt_version` integer constant. The `user.db` caching layer (`002_primary_directions_interpretations.sql`) pairs cached interpretations with this version. Bumping the version immediately invalidates stale caches, guaranteeing that new prompt instructions are faithfully reflected in newly requested contextual readings without needing a database schema migration.

## 5. Migration Conventions
Migrations are managed linearly via `MigrationRunner`. 
- Files prefixed `001_*` apply to the read-only `corpus.db` (usually copied on first launch).
- Files prefixed `002_*` and above apply to `user.db` for user-specific data and caches.
Migrations are tracked in the `migrations_applied` table to ensure idempotency.
