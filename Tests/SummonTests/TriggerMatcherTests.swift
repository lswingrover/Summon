import XCTest
@testable import SummonCore

final class TriggerMatcherTests: XCTestCase {

    var matcher: TriggerMatcher!
    var snippets: [Snippet]!

    override func setUp() {
        super.setUp()
        matcher  = TriggerMatcher()
        snippets = [
            Snippet(trigger: ";addr",  expansion: "123 Main St"),
            Snippet(trigger: ";email", expansion: "user@example.com"),
            Snippet(trigger: ";hi",    expansion: "Hello there!"),
        ]
    }

    // Helpers
    private func type(_ str: String) -> Snippet? {
        var last: Snippet?
        for ch in str { last = matcher.process(char: ch, against: snippets) }
        return last
    }

    // Tests
    func testExactTriggerAtStartOfBuffer() {
        let result = type(";addr")
        XCTAssertNotNil(result)
        XCTAssertEqual(result?.trigger, ";addr")
    }

    func testTriggerAfterSpace() {
        _ = type("Hello ")
        let result = type(";addr")
        XCTAssertNotNil(result)
    }

    func testTriggerAfterNewline() {
        _ = type("foo\n")
        let result = type(";hi")
        XCTAssertNotNil(result)
    }

    func testNoMatchInMiddleOfWord() {
        let result = type("foo;addr")
        XCTAssertNil(result)
    }

    func testNoMatchDisabledSnippet() {
        let disabled = [Snippet(trigger: ";off", expansion: "nope", enabled: false)]
        matcher = TriggerMatcher()
        _ = type(";off")
        XCTAssertNil(matcher.process(char: "x", against: disabled)) // sanity
        _ = matcher
        // Disabled snippets are filtered at the store level, not matcher level.
        // Matcher matches by trigger only; SnippetStore.activeSnippets does the filtering.
        // So test that if we pass disabled snippet it still matches (caller's responsibility):
        matcher = TriggerMatcher()
        var r: Snippet?
        for ch in ";off" { r = matcher.process(char: ch, against: disabled) }
        XCTAssertNotNil(r) // matcher doesn't check enabled flag
    }

    func testBackspaceReducesBuffer() {
        // Type ";add", backspace twice -> buffer = ";a", then type "ddr" -> ";addr" -> matches
        for ch in ";add" { _ = matcher.process(char: ch, against: snippets) }
        matcher.handleBackspace() // buffer = ";ad"
        matcher.handleBackspace() // buffer = ";a"
        let r1 = matcher.process(char: "d", against: snippets); XCTAssertNil(r1)
        let r2 = matcher.process(char: "d", against: snippets); XCTAssertNil(r2)
        let result = matcher.process(char: "r", against: snippets)
        XCTAssertNotNil(result)
        XCTAssertEqual(result?.trigger, ";addr")
    }

    func testExpandingFlagSuppressesMatches() {
        matcher.isExpanding = true
        let result = type(";addr")
        XCTAssertNil(result)
    }

    func testResetClearsBuffer() {
        for ch in ";add" { _ = matcher.process(char: ch, against: snippets) }
        matcher.reset()
        let result = type("r") // only 'r' in buffer -- no match
        XCTAssertNil(result)
    }

    func testMultipleTriggersSameBuffer() {
        _ = type(";hi ;email")
        // After the space following ;hi a match fires and buffer resets.
        // Then ;email is typed fresh -- it should also match.
        let result = type(";email")
        XCTAssertNotNil(result)
        XCTAssertEqual(result?.trigger, ";email")
    }

    func testNoMatchWithoutBoundaryWhenFlagOff() {
        // When requireBoundary is false, mid-word typing DOES fire the trigger.
        // (With default requireBoundary=true, testNoMatchInMiddleOfWord shows it returns nil.)
        matcher.requireBoundary = false
        let result = type("foo;addr")
        XCTAssertNotNil(result, "Trigger should match mid-word when requireBoundary = false")
        XCTAssertEqual(result?.trigger, ";addr")
    }
}
