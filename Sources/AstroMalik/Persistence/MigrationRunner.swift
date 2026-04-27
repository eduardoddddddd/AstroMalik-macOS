import Foundation

// MARK: - Migration Runner
// Aplica idempotentemente todos los ficheros .sql de Resources/migrations/
// al inicio de la app, con separación entre corpus.db y user.db.
//
// Convención de naming de ficheros:
//   001_*.sql → corpus.db (primero se copia a writable si es solo lectura en bundle)
//   002_*.sql → user.db  (lectura-escritura directo)
//   N*_*.sql  → user.db  (por defecto para migraciones futuras)
//
// Idempotencia garantizada porque:
//   - Los SQL usan "CREATE TABLE IF NOT EXISTS" e "INSERT OR IGNORE"
//   - La tabla migrations_applied registra qué ficheros ya se ejecutaron
//   - Las migraciones ya aplicadas se saltean en ejecuciones posteriores

final class MigrationRunner {

    // MARK: - Configuration

    struct Config: Sendable {
        /// URL del corpus.db en Application Support (writable).
        /// Se copia desde el bundle si no existe.
        let corpusWritableURL: URL
        /// URL del user.db en Application Support.
        let userDBURL: URL
        /// Bundle desde el que se cargan los .sql
        let resourceBundle: Bundle
    }

    // MARK: - Result

    struct MigrationResult: Sendable {
        let applied: [String]       // Nombres de ficheros aplicados esta ejecución
        let skipped: [String]       // Ya estaban aplicados
        let failed: [(String, Error)] // Fallaron
        var hasErrors: Bool { !failed.isEmpty }
    }

    // MARK: - Main Entry Point

    /// Aplica todas las migraciones pendientes.
    /// - Returns: Resultado detallado de la operación.
    @discardableResult
    static func applyAll(config: Config) throws -> MigrationResult {
        // 1. Asegurar corpus writable
        let corpusDB = try ensureWritableCorpus(config: config)
        // 2. Abrir user.db
        let userDB = try SQLiteDB(path: config.userDBURL.path, readonly: false)
        // 3. Crear tabla de tracking en ambas DBs
        try ensureMigrationsTable(db: corpusDB)
        try ensureMigrationsTable(db: userDB)
        // 4. Cargar y ordenar ficheros SQL del bundle
        let sqlFiles = try loadSQLFiles(from: config.resourceBundle)
        // 5. Aplicar cada uno al DB correcto
        var applied: [String] = []
        var skipped: [String] = []
        var failed: [(String, Error)] = []

        for file in sqlFiles {
            let db = isCorpusMigration(file.name) ? corpusDB : userDB
            do {
                let wasApplied = try applyMigration(file: file, db: db)
                if wasApplied { applied.append(file.name) }
                else          { skipped.append(file.name) }
            } catch {
                failed.append((file.name, error))
            }
        }

        return MigrationResult(applied: applied, skipped: skipped, failed: failed)
    }

    // MARK: - Corpus DB (bundle → writable copy)

    /// Asegura que existe una copia writable del corpus.db en Application Support.
    /// Si no existe, la copia desde el bundle.
    /// Retorna un SQLiteDB conectado en modo read-write.
    static func ensureWritableCorpus(config: Config) throws -> SQLiteDB {
        let fm = FileManager.default
        let dir = config.corpusWritableURL.deletingLastPathComponent()
        try fm.createDirectory(at: dir, withIntermediateDirectories: true)

        if !fm.fileExists(atPath: config.corpusWritableURL.path) {
            // Primera ejecución: copiar corpus.db del bundle
            guard let bundleCorpusURL = config.resourceBundle.url(
                forResource: "corpus", withExtension: "db"
            ) else {
                throw MigrationError.corpusNotFoundInBundle
            }
            try fm.copyItem(at: bundleCorpusURL, to: config.corpusWritableURL)
        }
        return try SQLiteDB(path: config.corpusWritableURL.path, readonly: false)
    }

    // MARK: - Private Helpers

    struct SQLFile: Sendable {
        let name: String        // "001_primary_direction_meanings.sql"
        let content: String
    }

    /// Carga todos los .sql de Resources/migrations/ ordenados por nombre.
    private static func loadSQLFiles(from bundle: Bundle) throws -> [SQLFile] {
        guard let migrationsURL = bundle.url(
            forResource: "migrations",
            withExtension: nil,
            subdirectory: nil
        ) else {
            // Fallback: buscar directamente en el bundle sin subdirectorio
            return try loadSQLFilesFromBundleRoot(bundle: bundle)
        }
        return try loadSQLFilesFromDir(url: migrationsURL)
    }

    private static func loadSQLFilesFromBundleRoot(bundle: Bundle) throws -> [SQLFile] {
        let urls = bundle.urls(forResourcesWithExtension: "sql", subdirectory: nil) ?? []
        return try urls.sorted { $0.lastPathComponent < $1.lastPathComponent }.map { url in
            let content = try String(contentsOf: url, encoding: .utf8)
            return SQLFile(name: url.lastPathComponent, content: content)
        }
    }

    private static func loadSQLFilesFromDir(url: URL) throws -> [SQLFile] {
        let fm = FileManager.default
        let contents = try fm.contentsOfDirectory(
            at: url, includingPropertiesForKeys: nil
        ).filter { $0.pathExtension == "sql" }
            .sorted { $0.lastPathComponent < $1.lastPathComponent }

        return try contents.map { fileURL in
            let content = try String(contentsOf: fileURL, encoding: .utf8)
            return SQLFile(name: fileURL.lastPathComponent, content: content)
        }
    }

    /// True si el fichero pertenece al corpus.db (comienza con "001_").
    private static func isCorpusMigration(_ name: String) -> Bool {
        name.hasPrefix("001_")
    }

    /// Aplica una migración si no ha sido aplicada ya.
    /// - Returns: true si se aplicó, false si ya estaba aplicada.
    @discardableResult
    private static func applyMigration(file: SQLFile, db: SQLiteDB) throws -> Bool {
        // Comprobar si ya fue aplicada
        let alreadyApplied = try isMigrationApplied(name: file.name, db: db)
        if alreadyApplied { return false }

        // Aplicar en transacción
        try db.execute("BEGIN")
        do {
            try db.execute(file.content)
            try recordMigration(name: file.name, db: db)
            try db.execute("COMMIT")
        } catch {
            try? db.execute("ROLLBACK")
            throw MigrationError.migrationFailed(file.name, error)
        }
        return true
    }

    private static func ensureMigrationsTable(db: SQLiteDB) throws {
        try db.execute("""
            CREATE TABLE IF NOT EXISTS migrations_applied (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                name TEXT NOT NULL UNIQUE,
                applied_at TEXT DEFAULT (datetime('now'))
            )
        """)
    }

    private static func isMigrationApplied(name: String, db: SQLiteDB) throws -> Bool {
        let rows = try db.query(
            "SELECT 1 FROM migrations_applied WHERE name = ? LIMIT 1",
            args: [.text(name)]
        )
        return !rows.isEmpty
    }

    private static func recordMigration(name: String, db: SQLiteDB) throws {
        _ = try db.run(
            "INSERT OR IGNORE INTO migrations_applied (name) VALUES (?)",
            args: [.text(name)]
        )
    }
}

// MARK: - Default Config Builder

extension MigrationRunner.Config {
    /// Configuración estándar usando el bundle del módulo y Application Support de macOS.
    static func standard(resourceBundle: Bundle = AppResources.bundle) throws -> MigrationRunner.Config {
        guard let appSupport = FileManager.default.urls(
            for: .applicationSupportDirectory, in: .userDomainMask
        ).first else {
            throw MigrationError.applicationSupportUnavailable
        }
        let dir = appSupport.appendingPathComponent("AstroMalik", isDirectory: true)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)

        return MigrationRunner.Config(
            corpusWritableURL: dir.appendingPathComponent("corpus.db"),
            userDBURL: dir.appendingPathComponent("user.db"),
            resourceBundle: resourceBundle
        )
    }
}

// MARK: - Errors

enum MigrationError: LocalizedError {
    case corpusNotFoundInBundle
    case applicationSupportUnavailable
    case migrationFailed(String, Error)

    var errorDescription: String? {
        switch self {
        case .corpusNotFoundInBundle:
            return "corpus.db no encontrado en el bundle de la aplicación."
        case .applicationSupportUnavailable:
            return "No se pudo localizar Application Support para la base de datos."
        case .migrationFailed(let name, let error):
            return "Migración '\(name)' falló: \(error.localizedDescription)"
        }
    }
}
