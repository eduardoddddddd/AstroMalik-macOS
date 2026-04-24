import Foundation
import SQLite3

// MARK: - Thin SQLite3 wrapper (sin dependencias externas)

final class SQLiteDB {
    private var db: OpaquePointer?
    let path: String
    let readonly: Bool

    init(path: String, readonly: Bool = false) throws {
        self.path = path
        self.readonly = readonly
        let flags = readonly
            ? (SQLITE_OPEN_READONLY | SQLITE_OPEN_URI | SQLITE_OPEN_NOMUTEX)
            : (SQLITE_OPEN_READWRITE | SQLITE_OPEN_CREATE | SQLITE_OPEN_FULLMUTEX)
        let uri = readonly ? "file:\(path)?mode=ro" : path
        guard sqlite3_open_v2(uri, &db, flags, nil) == SQLITE_OK, db != nil else {
            throw SQLiteError.open(String(cString: sqlite3_errmsg(db)))
        }
        if !readonly {
            sqlite3_exec(db, "PRAGMA journal_mode=WAL", nil, nil, nil)
            sqlite3_exec(db, "PRAGMA synchronous=NORMAL", nil, nil, nil)
        }
    }

    deinit { sqlite3_close(db) }

    // MARK: - Execute (DDL / DML)

    func execute(_ sql: String) throws {
        var errmsg: UnsafeMutablePointer<CChar>? = nil
        let rc = sqlite3_exec(db, sql, nil, nil, &errmsg)
        if rc != SQLITE_OK {
            let msg = errmsg.map { String(cString: $0) } ?? "unknown"
            sqlite3_free(errmsg)
            throw SQLiteError.exec(msg)
        }
    }

    // MARK: - Query

    func query(_ sql: String, args: [SQLiteValue] = []) throws -> [[String: SQLiteValue]] {
        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else {
            throw SQLiteError.prepare(String(cString: sqlite3_errmsg(db)))
        }
        defer { sqlite3_finalize(stmt) }

        bind(stmt: stmt, args: args)

        var rows: [[String: SQLiteValue]] = []
        let colCount = sqlite3_column_count(stmt)
        while sqlite3_step(stmt) == SQLITE_ROW {
            var row: [String: SQLiteValue] = [:]
            for i in 0..<colCount {
                let name = String(cString: sqlite3_column_name(stmt, i))
                row[name] = columnValue(stmt: stmt, index: i)
            }
            rows.append(row)
        }
        return rows
    }

    func queryOne(_ sql: String, args: [SQLiteValue] = []) throws -> [String: SQLiteValue]? {
        try query(sql, args: args).first
    }

    // MARK: - Run (INSERT/UPDATE/DELETE)

    @discardableResult
    func run(_ sql: String, args: [SQLiteValue] = []) throws -> Int64 {
        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else {
            throw SQLiteError.prepare(String(cString: sqlite3_errmsg(db)))
        }
        defer { sqlite3_finalize(stmt) }
        bind(stmt: stmt, args: args)
        let rc = sqlite3_step(stmt)
        guard rc == SQLITE_DONE || rc == SQLITE_ROW else {
            throw SQLiteError.step(String(cString: sqlite3_errmsg(db)))
        }
        return sqlite3_last_insert_rowid(db)
    }

    // MARK: - Private helpers

    private func bind(stmt: OpaquePointer?, args: [SQLiteValue]) {
        for (i, arg) in args.enumerated() {
            let idx = Int32(i + 1)
            switch arg {
            case .null:              sqlite3_bind_null(stmt, idx)
            case .integer(let v):    sqlite3_bind_int64(stmt, idx, v)
            case .real(let v):       sqlite3_bind_double(stmt, idx, v)
            case .text(let v):       sqlite3_bind_text(stmt, idx, v, -1, SQLITE_TRANSIENT)
            case .blob(let v):       _ = v.withUnsafeBytes { sqlite3_bind_blob(stmt, idx, $0.baseAddress, Int32($0.count), SQLITE_TRANSIENT) }
            }
        }
    }

    private func columnValue(stmt: OpaquePointer?, index: Int32) -> SQLiteValue {
        switch sqlite3_column_type(stmt, index) {
        case SQLITE_INTEGER: return .integer(sqlite3_column_int64(stmt, index))
        case SQLITE_FLOAT:   return .real(sqlite3_column_double(stmt, index))
        case SQLITE_TEXT:    return .text(String(cString: sqlite3_column_text(stmt, index)))
        case SQLITE_BLOB:
            let n = sqlite3_column_bytes(stmt, index)
            guard let p = sqlite3_column_blob(stmt, index) else {
                return .blob(Data())
            }
            return .blob(Data(bytes: p, count: Int(n)))
        default:             return .null
        }
    }
}

// MARK: - Value type

enum SQLiteValue {
    case null
    case integer(Int64)
    case real(Double)
    case text(String)
    case blob(Data)

    var string: String? { if case .text(let v) = self { return v }; return nil }
    var int: Int?       { if case .integer(let v) = self { return Int(v) }; return nil }
    var double: Double? { if case .real(let v) = self { return v }
                          if case .integer(let v) = self { return Double(v) }; return nil }
}

extension SQLiteValue: ExpressibleByStringLiteral {
    init(stringLiteral value: String) { self = .text(value) }
}
extension SQLiteValue: ExpressibleByIntegerLiteral {
    init(integerLiteral value: Int64) { self = .integer(value) }
}
extension SQLiteValue: ExpressibleByFloatLiteral {
    init(floatLiteral value: Double) { self = .real(value) }
}
extension SQLiteValue: ExpressibleByNilLiteral {
    init(nilLiteral: ()) { self = .null }
}

// MARK: - Errors

enum SQLiteError: LocalizedError {
    case open(String)
    case prepare(String)
    case exec(String)
    case step(String)

    var errorDescription: String? {
        switch self {
        case .open(let m):    return "SQLite open: \(m)"
        case .prepare(let m): return "SQLite prepare: \(m)"
        case .exec(let m):    return "SQLite exec: \(m)"
        case .step(let m):    return "SQLite step: \(m)"
        }
    }
}

private let SQLITE_TRANSIENT = unsafeBitCast(-1, to: sqlite3_destructor_type.self)
