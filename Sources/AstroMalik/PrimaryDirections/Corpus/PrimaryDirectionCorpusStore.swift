import Foundation

// MARK: - Primary Direction Corpus Store

/// Almacén de significados tradicionales para direcciones primarias.
/// Lee de la tabla `primary_direction_meanings` en corpus.db (read-only).
///
/// Clave del corpus: "{PROMISSOR}_{SIGNIFICADOR}_{ASPECTO}"
/// Ejemplo: "MARTE_ASC_CONJUNCION", "SOL_MC_CUADRATURA"
///
/// Regla de oro: si la fuente no está verificada, el campo texto permanece vacío.
final class PrimaryDirectionCorpusStore: @unchecked Sendable {
    private let db: SQLiteDB

    init(db: SQLiteDB) {
        self.db = db
    }

    // MARK: - Schema Migration

    /// Crea la tabla si no existe. Se llama una vez al iniciar la app.
    /// No-op si la tabla ya existe (corpus.db puede venir pre-poblada).
    func ensureSchema() throws {
        let sql = """
            CREATE TABLE IF NOT EXISTS primary_direction_meanings (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                clave TEXT NOT NULL UNIQUE,
                promissor TEXT NOT NULL,
                significator TEXT NOT NULL,
                aspect TEXT NOT NULL,
                texto_corto TEXT DEFAULT '',
                texto_largo TEXT DEFAULT '',
                fuente_nombre TEXT DEFAULT '',
                fuente_referencia TEXT DEFAULT '',
                populated INTEGER DEFAULT 0,
                calidad INTEGER DEFAULT 0,
                created_at TEXT DEFAULT (datetime('now')),
                updated_at TEXT DEFAULT (datetime('now'))
            );
            CREATE INDEX IF NOT EXISTS idx_pdm_clave ON primary_direction_meanings(clave);
            CREATE INDEX IF NOT EXISTS idx_pdm_promissor ON primary_direction_meanings(promissor);
            CREATE INDEX IF NOT EXISTS idx_pdm_significator ON primary_direction_meanings(significator);
        """
        try db.execute(sql)
    }

    // MARK: - Lookup

    /// Busca el significado de una dirección primaria por clave.
    /// - Parameter clave: e.g. "MARTE_ASC_CONJUNCION"
    /// - Returns: PDCorpusMeaning si existe y está poblado
    func lookup(clave: String) -> PDCorpusMeaning? {
        let sql = """
            SELECT clave, promissor, significator, aspect,
                   texto_corto, texto_largo, fuente_nombre, fuente_referencia,
                   populated, calidad
            FROM primary_direction_meanings
            WHERE clave = ? AND populated = 1
            ORDER BY calidad DESC LIMIT 1
        """
        guard let row = try? db.queryOne(sql, args: [.text(clave)]) else { return nil }
        return rowToMeaning(row)
    }

    /// Busca significados en batch para un conjunto de claves.
    /// - Parameter claves: Array de claves a buscar
    /// - Returns: Dictionary de clave → significado
    func lookupBatch(claves: [String]) -> [String: PDCorpusMeaning] {
        guard !claves.isEmpty else { return [:] }
        let placeholders = claves.map { _ in "?" }.joined(separator: ",")
        let sql = """
            SELECT clave, promissor, significator, aspect,
                   texto_corto, texto_largo, fuente_nombre, fuente_referencia,
                   populated, calidad
            FROM primary_direction_meanings
            WHERE clave IN (\(placeholders)) AND populated = 1
            ORDER BY calidad DESC
        """
        let args: [SQLiteValue] = claves.map { .text($0) }
        guard let rows = try? db.query(sql, args: args) else { return [:] }

        var result: [String: PDCorpusMeaning] = [:]
        for row in rows {
            guard let meaning = rowToMeaning(row) else { continue }
            // Keep highest quality (first found due to ORDER BY)
            if result[meaning.clave] == nil {
                result[meaning.clave] = meaning
            }
        }
        return result
    }

    /// Cuenta total de entradas pobladas en el corpus.
    func countPopulated() -> Int {
        let sql = "SELECT COUNT(*) as n FROM primary_direction_meanings WHERE populated = 1"
        guard let row = try? db.queryOne(sql) else { return 0 }
        return row["n"]?.int ?? 0
    }

    /// Estadísticas del corpus: total, pobladas, por aspecto.
    func stats() -> PDCorpusStats {
        let total: Int
        let populated: Int
        let byAspect: [String: Int]

        let totalSQL = "SELECT COUNT(*) as n FROM primary_direction_meanings"
        total = (try? db.queryOne(totalSQL))?["n"]?.int ?? 0

        populated = countPopulated()

        let aspectSQL = """
            SELECT aspect, COUNT(*) as n FROM primary_direction_meanings
            WHERE populated = 1 GROUP BY aspect
        """
        if let rows = try? db.query(aspectSQL) {
            byAspect = Dictionary(uniqueKeysWithValues: rows.compactMap { row -> (String, Int)? in
                guard let asp = row["aspect"]?.string, let n = row["n"]?.int else { return nil }
                return (asp, n)
            })
        } else {
            byAspect = [:]
        }

        return PDCorpusStats(total: total, populated: populated, byAspect: byAspect)
    }

    // MARK: - Build Interpretations

    /// Construye interpretaciones del corpus para un conjunto de direcciones calculadas.
    /// Devuelve solo las que tienen texto en el corpus (populated = 1).
    func buildInterpretations(
        for directions: [PrimaryDirection]
    ) -> [PrimaryDirectionInterpretation] {
        let claves = directions.map { directionCorpusClave($0) }
        let meanings = lookupBatch(claves: claves)

        return directions.compactMap { dir in
            let clave = directionCorpusClave(dir)
            guard let meaning = meanings[clave] else { return nil }

            return PrimaryDirectionInterpretation(
                directionId: dir.id,
                clave: clave,
                title: "\(dir.promissorLabel) \(dir.aspect.label) \(dir.significatorLabel)",
                structuralText: meaning.textoLargo.isEmpty ? meaning.textoCorto : meaning.textoLargo,
                source: meaning.fuenteNombre,
                sourceReference: meaning.fuenteReferencia,
                quality: meaning.calidad,
                contextualText: nil
            )
        }
    }

    // MARK: - Clave Generation

    /// Genera la clave de corpus para una dirección primaria.
    /// Formato: "{PROMISSOR}_{SIGNIFICADOR}_{ASPECTO}"
    func directionCorpusClave(_ direction: PrimaryDirection) -> String {
        let aspKey: String
        switch direction.aspect {
        case .conjunction: aspKey = "CONJUNCION"
        case .sextile:     aspKey = "SEXTIL"
        case .square:      aspKey = "CUADRATURA"
        case .trine:       aspKey = "TRIGONO"
        case .opposition:  aspKey = "OPOSICION"
        }
        return "\(direction.promissor)_\(direction.significator)_\(aspKey)"
    }

    // MARK: - Private

    private func rowToMeaning(_ row: [String: SQLiteValue]) -> PDCorpusMeaning? {
        guard let clave = row["clave"]?.string else { return nil }
        return PDCorpusMeaning(
            clave: clave,
            promissor: row["promissor"]?.string ?? "",
            significator: row["significator"]?.string ?? "",
            aspect: row["aspect"]?.string ?? "",
            textoCorto: row["texto_corto"]?.string ?? "",
            textoLargo: row["texto_largo"]?.string ?? "",
            fuenteNombre: row["fuente_nombre"]?.string ?? "",
            fuenteReferencia: row["fuente_referencia"]?.string ?? "",
            populated: (row["populated"]?.int ?? 0) == 1,
            calidad: row["calidad"]?.int ?? 0
        )
    }
}

// MARK: - Corpus Models

/// Significado tradicional de una dirección primaria.
struct PDCorpusMeaning: Codable, Equatable {
    let clave: String
    let promissor: String
    let significator: String
    let aspect: String
    let textoCorto: String
    let textoLargo: String
    let fuenteNombre: String
    let fuenteReferencia: String
    let populated: Bool
    let calidad: Int
}

/// Interpretación hidratada de una dirección primaria (corpus + contextual).
struct PrimaryDirectionInterpretation: Identifiable, Codable, Equatable {
    var id: String { "\(directionId)-\(clave)" }
    let directionId: UUID
    let clave: String
    let title: String
    let structuralText: String      // Capa 1: corpus tradicional determinista
    let source: String
    let sourceReference: String
    let quality: Int
    var contextualText: String?     // Capa 2: LLM (nil hasta Phase 4)
}

/// Estadísticas del corpus PD.
struct PDCorpusStats: Equatable {
    let total: Int
    let populated: Int
    let byAspect: [String: Int]

    var coveragePercent: Double {
        guard total > 0 else { return 0 }
        return Double(populated) / Double(total) * 100
    }
}
