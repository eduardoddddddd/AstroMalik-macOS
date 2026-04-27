-- Migration 002: Primary Directions Interpretations Cache
-- Tabla en user.db (read-write) para persistir interpretaciones generadas por el LLM.
-- NO en corpus.db (read-only en bundle).
--
-- Esta tabla actúa como caché persistente entre sesiones.
-- Invalidación: borrar filas cuyo prompt_version no coincida con el actual.
-- El campo json_payload almacena el ContextualInterpretation completo como JSON.

CREATE TABLE IF NOT EXISTS primary_directions_interpretations (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    direction_id TEXT NOT NULL,      -- UUID de PrimaryDirection
    clave TEXT NOT NULL,             -- "{PROMISSOR}_{SIGNIFICADOR}_{ASPECTO}"
    prompt_version TEXT NOT NULL,    -- Versión del prompt morinista (e.g. "1.0.0")
    json_payload TEXT NOT NULL,      -- ContextualInterpretation codificado como JSON
    model_used TEXT DEFAULT '',      -- Modelo de LLM usado (para auditoría)
    tokens_used INTEGER DEFAULT 0,   -- Tokens consumidos (para monitoreo de costes)
    created_at TEXT DEFAULT (datetime('now')),
    UNIQUE(direction_id, prompt_version)
);

CREATE INDEX IF NOT EXISTS idx_pdi_direction_id
    ON primary_directions_interpretations(direction_id);

CREATE INDEX IF NOT EXISTS idx_pdi_clave
    ON primary_directions_interpretations(clave);

CREATE INDEX IF NOT EXISTS idx_pdi_prompt_version
    ON primary_directions_interpretations(prompt_version);

-- Limpieza de caché con versiones antiguas de prompt
-- (ejecutar manualmente o en la migración cuando promptVersion cambie):
-- DELETE FROM primary_directions_interpretations WHERE prompt_version != '1.0.0';
