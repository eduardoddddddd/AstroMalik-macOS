-- Primary Direction Meanings: Schema + Skeleton Seed Data
-- Tabla: primary_direction_meanings en corpus.db
--
-- NOTA: Las 29 entradas seed se vaciaron tras revisión de honestidad (2026-04-27).
-- Las referencias originales eran imprecisas: "Cap. LXVI" repetido para Lilly
-- (ese capítulo trata de la Parte de Fortuna, no de direcciones) y "Tractatus X"
-- genérico para Bonatti sin número de Consideración.
-- Los textos eran paráfrasis propias del LLM, no extractos de las fuentes citadas.
--
-- Poblar manualmente contra ediciones reales:
--   - Bonatti: Liber Astronomiae, Tractatus X "De Directionibus", Consideraciones específicas
--   - Lilly: Christian Astrology, Libro III, caps. XXI-XXVI (pp. 633-670, ed. Regulus 1985)
--
-- Regla de oro: populated = 0 si la fuente no está verificada contra edición real.
-- Solo marcar populated = 1 cuando el texto sea cita o traducción fiel localizable.

CREATE TABLE IF NOT EXISTS primary_direction_meanings (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    clave TEXT NOT NULL UNIQUE,
    promissor TEXT NOT NULL,
    significator TEXT NOT NULL,
    aspect TEXT NOT NULL,
    texto_corto TEXT DEFAULT NULL,
    texto_largo TEXT DEFAULT NULL,
    fuente_nombre TEXT DEFAULT NULL,
    fuente_referencia TEXT DEFAULT NULL,
    populated INTEGER DEFAULT 0,
    calidad INTEGER DEFAULT 0,
    created_at TEXT DEFAULT (datetime('now')),
    updated_at TEXT DEFAULT (datetime('now'))
);

CREATE INDEX IF NOT EXISTS idx_pdm_clave ON primary_direction_meanings(clave);
CREATE INDEX IF NOT EXISTS idx_pdm_promissor ON primary_direction_meanings(promissor);
CREATE INDEX IF NOT EXISTS idx_pdm_significator ON primary_direction_meanings(significator);

-- =============================================
-- SKELETON ENTRIES: populated = 0, texts = NULL
-- Las claves son combinaciones válidas y útiles.
-- fuente_referencia contiene pista para poblado manual.
-- =============================================

-- SOL → ASC (5 aspectos)
INSERT OR IGNORE INTO primary_direction_meanings (clave, promissor, significator, aspect, fuente_referencia, populated) VALUES
('SOL_ASC_CONJUNCION', 'SOL', 'ASC', 'CONJUNCION', 'TODO: Bonatti Tract.X + Lilly CA III caps.XXI-XXVI', 0);
INSERT OR IGNORE INTO primary_direction_meanings (clave, promissor, significator, aspect, fuente_referencia, populated) VALUES
('SOL_ASC_SEXTIL', 'SOL', 'ASC', 'SEXTIL', 'TODO: Bonatti Tract.X + Lilly CA III caps.XXI-XXVI', 0);
INSERT OR IGNORE INTO primary_direction_meanings (clave, promissor, significator, aspect, fuente_referencia, populated) VALUES
('SOL_ASC_CUADRATURA', 'SOL', 'ASC', 'CUADRATURA', 'TODO: Bonatti Tract.X + Lilly CA III caps.XXI-XXVI', 0);
INSERT OR IGNORE INTO primary_direction_meanings (clave, promissor, significator, aspect, fuente_referencia, populated) VALUES
('SOL_ASC_TRIGONO', 'SOL', 'ASC', 'TRIGONO', 'TODO: Bonatti Tract.X + Lilly CA III caps.XXI-XXVI', 0);
INSERT OR IGNORE INTO primary_direction_meanings (clave, promissor, significator, aspect, fuente_referencia, populated) VALUES
('SOL_ASC_OPOSICION', 'SOL', 'ASC', 'OPOSICION', 'TODO: Bonatti Tract.X + Lilly CA III caps.XXI-XXVI', 0);

-- SOL → MC (2 claves principales)
INSERT OR IGNORE INTO primary_direction_meanings (clave, promissor, significator, aspect, fuente_referencia, populated) VALUES
('SOL_MC_CONJUNCION', 'SOL', 'MC', 'CONJUNCION', 'TODO: Lilly CA III caps.XXI-XXVI', 0);
INSERT OR IGNORE INTO primary_direction_meanings (clave, promissor, significator, aspect, fuente_referencia, populated) VALUES
('SOL_MC_CUADRATURA', 'SOL', 'MC', 'CUADRATURA', 'TODO: Lilly CA III caps.XXI-XXVI', 0);

-- SOL → LUNA (3 claves hylegíacas)
INSERT OR IGNORE INTO primary_direction_meanings (clave, promissor, significator, aspect, fuente_referencia, populated) VALUES
('SOL_LUNA_CONJUNCION', 'SOL', 'LUNA', 'CONJUNCION', 'TODO: Lilly CA III caps.XXI-XXVI', 0);
INSERT OR IGNORE INTO primary_direction_meanings (clave, promissor, significator, aspect, fuente_referencia, populated) VALUES
('SOL_LUNA_CUADRATURA', 'SOL', 'LUNA', 'CUADRATURA', 'TODO: Lilly CA III caps.XXI-XXVI', 0);
INSERT OR IGNORE INTO primary_direction_meanings (clave, promissor, significator, aspect, fuente_referencia, populated) VALUES
('SOL_LUNA_OPOSICION', 'SOL', 'LUNA', 'OPOSICION', 'TODO: Lilly CA III caps.XXI-XXVI', 0);

-- LUNA → ASC
INSERT OR IGNORE INTO primary_direction_meanings (clave, promissor, significator, aspect, fuente_referencia, populated) VALUES
('LUNA_ASC_CONJUNCION', 'LUNA', 'ASC', 'CONJUNCION', 'TODO: Bonatti Tract.X Consideraciones Luna', 0);
INSERT OR IGNORE INTO primary_direction_meanings (clave, promissor, significator, aspect, fuente_referencia, populated) VALUES
('LUNA_ASC_CUADRATURA', 'LUNA', 'ASC', 'CUADRATURA', 'TODO: Lilly CA III caps.XXI-XXVI', 0);

-- LUNA → MC
INSERT OR IGNORE INTO primary_direction_meanings (clave, promissor, significator, aspect, fuente_referencia, populated) VALUES
('LUNA_MC_CONJUNCION', 'LUNA', 'MC', 'CONJUNCION', 'TODO: Bonatti Tract.X Consideraciones Luna', 0);

-- MARTE → ASC
INSERT OR IGNORE INTO primary_direction_meanings (clave, promissor, significator, aspect, fuente_referencia, populated) VALUES
('MARTE_ASC_CONJUNCION', 'MARTE', 'ASC', 'CONJUNCION', 'TODO: Lilly CA III caps.XXI-XXVI, sección Marte', 0);
INSERT OR IGNORE INTO primary_direction_meanings (clave, promissor, significator, aspect, fuente_referencia, populated) VALUES
('MARTE_ASC_CUADRATURA', 'MARTE', 'ASC', 'CUADRATURA', 'TODO: Lilly CA III caps.XXI-XXVI, sección Marte', 0);

-- MARTE → MC
INSERT OR IGNORE INTO primary_direction_meanings (clave, promissor, significator, aspect, fuente_referencia, populated) VALUES
('MARTE_MC_CONJUNCION', 'MARTE', 'MC', 'CONJUNCION', 'TODO: Bonatti Tract.X Consideraciones Marte', 0);

-- MARTE → LUNA
INSERT OR IGNORE INTO primary_direction_meanings (clave, promissor, significator, aspect, fuente_referencia, populated) VALUES
('MARTE_LUNA_CONJUNCION', 'MARTE', 'LUNA', 'CONJUNCION', 'TODO: Lilly CA III caps.XXI-XXVI, sección Marte-Luna', 0);

-- SATURNO → ASC
INSERT OR IGNORE INTO primary_direction_meanings (clave, promissor, significator, aspect, fuente_referencia, populated) VALUES
('SATURNO_ASC_CONJUNCION', 'SATURNO', 'ASC', 'CONJUNCION', 'TODO: Lilly CA III caps.XXI-XXVI, sección Saturno', 0);
INSERT OR IGNORE INTO primary_direction_meanings (clave, promissor, significator, aspect, fuente_referencia, populated) VALUES
('SATURNO_ASC_CUADRATURA', 'SATURNO', 'ASC', 'CUADRATURA', 'TODO: Lilly CA III caps.XXI-XXVI, sección Saturno', 0);

-- SATURNO → MC
INSERT OR IGNORE INTO primary_direction_meanings (clave, promissor, significator, aspect, fuente_referencia, populated) VALUES
('SATURNO_MC_CONJUNCION', 'SATURNO', 'MC', 'CONJUNCION', 'TODO: Bonatti Tract.X Consideraciones Saturno', 0);

-- SATURNO → LUNA
INSERT OR IGNORE INTO primary_direction_meanings (clave, promissor, significator, aspect, fuente_referencia, populated) VALUES
('SATURNO_LUNA_CONJUNCION', 'SATURNO', 'LUNA', 'CONJUNCION', 'TODO: Lilly CA III caps.XXI-XXVI, sección Saturno-Luna', 0);

-- JUPITER → ASC
INSERT OR IGNORE INTO primary_direction_meanings (clave, promissor, significator, aspect, fuente_referencia, populated) VALUES
('JUPITER_ASC_CONJUNCION', 'JUPITER', 'ASC', 'CONJUNCION', 'TODO: Bonatti Tract.X Consideraciones Júpiter', 0);
INSERT OR IGNORE INTO primary_direction_meanings (clave, promissor, significator, aspect, fuente_referencia, populated) VALUES
('JUPITER_ASC_TRIGONO', 'JUPITER', 'ASC', 'TRIGONO', 'TODO: Bonatti Tract.X Consideraciones Júpiter', 0);

-- JUPITER → MC
INSERT OR IGNORE INTO primary_direction_meanings (clave, promissor, significator, aspect, fuente_referencia, populated) VALUES
('JUPITER_MC_CONJUNCION', 'JUPITER', 'MC', 'CONJUNCION', 'TODO: Lilly CA III caps.XXI-XXVI, sección Júpiter', 0);

-- JUPITER → LUNA
INSERT OR IGNORE INTO primary_direction_meanings (clave, promissor, significator, aspect, fuente_referencia, populated) VALUES
('JUPITER_LUNA_CONJUNCION', 'JUPITER', 'LUNA', 'CONJUNCION', 'TODO: Bonatti Tract.X Consideraciones Júpiter-Luna', 0);

-- VENUS → ASC
INSERT OR IGNORE INTO primary_direction_meanings (clave, promissor, significator, aspect, fuente_referencia, populated) VALUES
('VENUS_ASC_CONJUNCION', 'VENUS', 'ASC', 'CONJUNCION', 'TODO: Bonatti Tract.X Consideraciones Venus', 0);

-- VENUS → MC
INSERT OR IGNORE INTO primary_direction_meanings (clave, promissor, significator, aspect, fuente_referencia, populated) VALUES
('VENUS_MC_CONJUNCION', 'VENUS', 'MC', 'CONJUNCION', 'TODO: Lilly CA III caps.XXI-XXVI, sección Venus', 0);

-- MERCURIO → ASC
INSERT OR IGNORE INTO primary_direction_meanings (clave, promissor, significator, aspect, fuente_referencia, populated) VALUES
('MERCURIO_ASC_CONJUNCION', 'MERCURIO', 'ASC', 'CONJUNCION', 'TODO: Bonatti Tract.X Consideraciones Mercurio', 0);

-- MERCURIO → MC
INSERT OR IGNORE INTO primary_direction_meanings (clave, promissor, significator, aspect, fuente_referencia, populated) VALUES
('MERCURIO_MC_CONJUNCION', 'MERCURIO', 'MC', 'CONJUNCION', 'TODO: Bonatti Tract.X Consideraciones Mercurio', 0);
