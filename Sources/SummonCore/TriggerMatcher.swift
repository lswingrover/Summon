import Foundation

/// Maintains a rolling buffer of recently typed characters and checks for trigger matches.
///
/// Design notes:
/// - Buffer is capped at maxLength (longest known trigger + headroom).
/// - Matches are checked after every keystroke for responsiveness.
/// - Requires a word boundary (whitespace, punctuation, newline) before the trigger,
///   OR the trigger starts at the beginning of the buffer.
/// - `isExpanding` flag suppresses matching while ExpansionInjector is active,
///   preventing infinite re-entrant expansion loops.
public final class TriggerMatcher: @unchecked Sendable {

    private let maxLength = 128
    private var buffer: [Character] = []

    /// Set true by ExpansionInjector while it is injecting characters.
    public var isExpanding = false

    public init() {}

    /// Append a character and test for a trigger match.
    /// Returns the matching Snippet if found, nil otherwise.
    @discardableResult
    public func process(char: Character, against snippets: [Snippet]) -> Snippet? {
        guard !isExpanding else { return nil }

        buffer.append(char)
        if buffer.count > maxLength {
            buffer.removeFirst(buffer.count - maxLength)
        }

        let bufStr = String(buffer)

        for snippet in snippets {
            let trigger = snippet.trigger
            guard !trigger.isEmpty, bufStr.hasSuffix(trigger) else { continue }

            let triggerStart = bufStr.index(bufStr.endIndex, offsetBy: -trigger.count)

            // Match at start of buffer (no preceding character required)
            if triggerStart == bufStr.startIndex {
                buffer.removeAll()
                return snippet
            }

            // Require word boundary before trigger
            let preceding = bufStr[bufStr.index(before: triggerStart)]
            if preceding.isWhitespace || preceding.isPunctuation || preceding.isNewline {
                buffer.removeAll()
                return snippet
            }
        }
        return nil
    }

    /// Call when backspace is typed.
    public func handleBackspace() {
        if !buffer.isEmpty { buffer.removeLast() }
    }

    /// Reset buffer — call on app deactivation or expansion start.
    public func reset() {
        buffer.removeAll()
    }
}
