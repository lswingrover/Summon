import Foundation
import SQLite3

/// Low-level SQLite wrapper for Summon's snippet store.
/// All operations are synchronous; intended to be called from SnippetStore actor.
public final class DatabaseManager: Sendable {

    private let dbPath: String

    public init(path: String? = nil) {
        if let path {
            dbPath = path
        } else {
            let support = FileManager.default.urls(
                for: .applicationSupportDirectory, in: .userDomainMask
            ).first!.appendingPathComponent("Summon", isDirectory: true)
            try? FileManager.default.createDirectory(at: support, withIntermediateDirectories: true)
            dbPath = support.appendingPathComponent("summon.db").path
        }
        initSchema()
    }

    // MARK: - Schema

    private func initSchema() {
        withDB { db in
            let sql = """
                CREATE TABLE IF NOT EXISTS snippets (
                    id          TEXT PRIMARY KEY,
                    trigger     TEXT NOT NULL UNIQUE,
                    expansion   TEXT NOT NULL,
                    label       TEXT NOT NULL DEFAULT '',
                    enabled     INTEGER NOT NULL DEFAULT 1,
                    created_at  REAL NOT NULL,
                    updated_at  REAL NOT NULL
                );
            """
            sqlite3_exec(db, sql, nil, nil, nil)
        }
    }

    // MARK: - CRUD

    public func insertSnippet(_ s: Snippet) throws {
        try withDBThrowing { db in
            var stmt: OpaquePointer?
            let sql = "INSERT INTO snippets (id,trigger,expansion,label,enabled,created_at,updated_at) VALUES (?,?,?,?,?,?,?)"
            guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else {
                throw DBError.prepareFailed(String(cString: sqlite3_errmsg(db)))
            }
            defer { sqlite3_finalize(stmt) }
            bind(stmt, 1, s.id.uuidString)
            bind(stmt, 2, s.trigger)
            bind(stmt, 3, s.expansion)
            bind(stmt, 4, s.label)
            sqlite3_bind_int(stmt,    5, s.enabled ? 1 : 0)
            sqlite3_bind_double(stmt, 6, s.createdAt.timeIntervalSince1970)
            sqlite3_bind_double(stmt, 7, s.updatedAt.timeIntervalSince1970)
            guard sqlite3_step(stmt) == SQLITE_DONE else {
                throw DBError.stepFailed(String(cString: sqlite3_errmsg(db)))
            }
        }
    }

    public func updateSnippet(_ s: Snippet) throws {
        try withDBThrowing { db in
            var stmt: OpaquePointer?
            let sql = "UPDATE snippets SET trigger=?,expansion=?,label=?,enabled=?,updated_at=? WHERE id=?"
            guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else {
                throw DBError.prepareFailed(String(cString: sqlite3_errmsg(db)))
            }
            defer { sqlite3_finalize(stmt) }
            bind(stmt, 1, s.trigger)
            bind(stmt, 2, s.expansion)
            bind(stmt, 3, s.label)
            sqlite3_bind_int(stmt,    4, s.enabled ? 1 : 0)
            sqlite3_bind_double(stmt, 5, Date().timeIntervalSince1970)
            bind(stmt, 6, s.id.uuidString)
            guard sqlite3_step(stmt) == SQLITE_DONE else {
                throw DBError.stepFailed(String(cString: sqlite3_errmsg(db)))
            }
        }
    }

    public func deleteSnippet(id: UUID) throws {
        try withDBThrowing { db in
            var stmt: OpaquePointer?
            guard sqlite3_prepare_v2(db, "DELETE FROM snippets WHERE id=?", -1, &stmt, nil) == SQLITE_OK else {
                throw DBError.prepareFailed(String(cString: sqlite3_errmsg(db)))
            }
            defer { sqlite3_finalize(stmt) }
            bind(stmt, 1, id.uuidString)
            guard sqlite3_step(stmt) == SQLITE_DONE else {
                throw DBError.stepFailed(String(cString: sqlite3_errmsg(db)))
            }
        }
    }

    public func fetchAll() -> [Snippet] {
        var results: [Snippet] = []
        withDB { db in
            var stmt: OpaquePointer?
            let sql = "SELECT id,trigger,expansion,label,enabled,created_at,updated_at FROM snippets ORDER BY created_at ASC"
            guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else { return }
            defer { sqlite3_finalize(stmt) }
            while sqlite3_step(stmt) == SQLITE_ROW {
                guard
                    let idStr = sqlite3_column_text(stmt, 0).map({ String(cString: $0) }),
                    let id    = UUID(uuidString: idStr),
                    let trig  = sqlite3_column_text(stmt, 1).map({ String(cString: $0) }),
                    let exp   = sqlite3_column_text(stmt, 2).map({ String(cString: $0) }),
                    let lbl   = sqlite3_column_text(stmt, 3).map({ String(cString: $0) })
                else { continue }
                results.append(Snippet(
                    id: id, trigger: trig, expansion: exp, label: lbl,
                    enabled: sqlite3_column_int(stmt, 4) != 0,
                    createdAt: Date(timeIntervalSince1970: sqlite3_column_double(stmt, 5)),
                    updatedAt: Date(timeIntervalSince1970: sqlite3_column_double(stmt, 6))
                ))
            }
        }
        return results
    }

    // MARK: - Helpers

    private func bind(_ stmt: OpaquePointer?, _ idx: Int32, _ val: String) {
        sqlite3_bind_text(stmt, idx, val, -1, unsafeBitCast(-1, to: sqlite3_destructor_type.self))
    }

    private func withDB(_ body: (OpaquePointer) -> Void) {
        var db: OpaquePointer?
        guard sqlite3_open(dbPath, &db) == SQLITE_OK, let db else { return }
        defer { sqlite3_close(db) }
        body(db)
    }

    private func withDBThrowing(_ body: (OpaquePointer) throws -> Void) throws {
        var db: OpaquePointer?
        guard sqlite3_open(dbPath, &db) == SQLITE_OK, let db else {
            throw DBError.openFailed(dbPath)
        }
        defer { sqlite3_close(db) }
        try body(db)
    }

    // MARK: - Errors

    public enum DBError: Error, LocalizedError {
        case openFailed(String)
        case prepareFailed(String)
        case stepFailed(String)

        public var errorDescription: String? {
            switch self {
            case .openFailed(let p):    return "Could not open database at \(p)"
            case .prepareFailed(let m): return "SQL prepare error: \(m)"
            case .stepFailed(let m):    return "SQL step error: \(m)"
            }
        }
    }
}
