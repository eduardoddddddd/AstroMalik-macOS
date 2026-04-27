import Foundation

struct JoplinOpenRouterCredential: Equatable, Sendable {
    let noteTitle: String
    let databasePath: String
    let apiKey: String

    var maskedKey: String {
        let trimmed = apiKey.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.count > 16 else { return trimmed }
        return "\(trimmed.prefix(10))...\(trimmed.suffix(4))"
    }
}

struct JoplinOpenRouterKeyLocator: Sendable {
    let databasePaths: [String]

    init(databasePaths: [String] = Self.defaultDatabasePaths()) {
        self.databasePaths = databasePaths
    }

    func locateFirstCredential() throws -> JoplinOpenRouterCredential? {
        for path in databasePaths {
            guard FileManager.default.fileExists(atPath: path) else { continue }
            if let credential = try findCredential(inDatabaseAt: path) {
                return credential
            }
        }
        return nil
    }

    private func findCredential(inDatabaseAt path: String) throws -> JoplinOpenRouterCredential? {
        let db = try SQLiteDB(path: path, readonly: true)
        let rows = try db.query("""
            SELECT title, body
            FROM notes
            WHERE deleted_time = 0
              AND is_conflict = 0
              AND body LIKE '%sk-or-v1-%'
            ORDER BY user_updated_time DESC, updated_time DESC, created_time DESC
            LIMIT 25
        """)

        for row in rows {
            let title = row["title"]?.string ?? "Nota sin título"
            let body = row["body"]?.string ?? ""
            if let key = Self.extractAPIKey(from: body) {
                return JoplinOpenRouterCredential(
                    noteTitle: title,
                    databasePath: path,
                    apiKey: key
                )
            }
        }

        return nil
    }

    static func extractAPIKey(from text: String) -> String? {
        guard let regex = try? NSRegularExpression(pattern: #"sk-or-v1-[A-Za-z0-9]+"#) else {
            return nil
        }
        let range = NSRange(text.startIndex..<text.endIndex, in: text)
        guard let match = regex.firstMatch(in: text, options: [], range: range),
              let swiftRange = Range(match.range, in: text) else {
            return nil
        }
        return String(text[swiftRange])
    }

    static func defaultDatabasePaths() -> [String] {
        [
            NSString(string: "~/.config/joplin-desktop/database.sqlite").expandingTildeInPath,
            NSString(string: "~/Library/Application Support/Joplin/database.sqlite").expandingTildeInPath,
        ]
    }
}
