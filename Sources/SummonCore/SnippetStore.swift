import Foundation

/// Thread-safe actor wrapping DatabaseManager.
/// The single runtime source of truth for all snippet state.
public actor SnippetStore {
    private let db: DatabaseManager
    public private(set) var snippets: [Snippet] = []

    public init(db: DatabaseManager = DatabaseManager()) {
        self.db = db
        self.snippets = db.fetchAll()
    }

    public func reload() {
        snippets = db.fetchAll()
    }

    public func add(_ snippet: Snippet) throws {
        try db.insertSnippet(snippet)
        snippets = db.fetchAll()
    }

    public func update(_ snippet: Snippet) throws {
        try db.updateSnippet(snippet)
        snippets = db.fetchAll()
    }

    public func delete(id: UUID) throws {
        try db.deleteSnippet(id: id)
        snippets = db.fetchAll()
    }

    /// Only enabled snippets — used by TriggerMatcher.
    public var activeSnippets: [Snippet] {
        snippets.filter { $0.enabled }
    }
}
