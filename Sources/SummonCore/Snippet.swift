import Foundation

/// A single text-expansion rule: typing `trigger` anywhere expands to `expansion`.
public struct Snippet: Identifiable, Equatable, Sendable, Codable {
    public let id: UUID
    /// The short sequence the user types (e.g. ";addr").
    public var trigger: String
    /// The full text inserted when the trigger fires.
    public var expansion: String
    /// Optional human-readable label shown in the manager.
    public var label: String
    /// Whether this snippet is active. Disabled snippets are loaded but never matched.
    public var enabled: Bool
    public var createdAt: Date
    public var updatedAt: Date

    public init(
        id: UUID = UUID(),
        trigger: String,
        expansion: String,
        label: String = "",
        enabled: Bool = true,
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.trigger = trigger
        self.expansion = expansion
        self.label = label
        self.enabled = enabled
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}
