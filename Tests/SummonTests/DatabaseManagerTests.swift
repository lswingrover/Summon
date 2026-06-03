import XCTest
@testable import SummonCore

final class DatabaseManagerTests: XCTestCase {

    var db: DatabaseManager!
    var tempPath: String!

    override func setUp() {
        super.setUp()
        tempPath = NSTemporaryDirectory() + "summon_test_\(UUID().uuidString).db"
        db = DatabaseManager(path: tempPath)
    }

    override func tearDown() {
        try? FileManager.default.removeItem(atPath: tempPath)
        super.tearDown()
    }

    func testSchemaCreatesTable() {
        let snippets = db.fetchAll()
        XCTAssertNotNil(snippets) // table exists, no crash
    }

    func testInsertAndFetch() throws {
        let s = Snippet(trigger: ";test", expansion: "Hello, world!")
        try db.insertSnippet(s)
        let all = db.fetchAll()
        XCTAssertEqual(all.count, 1)
        XCTAssertEqual(all[0].trigger, ";test")
        XCTAssertEqual(all[0].expansion, "Hello, world!")
        XCTAssertTrue(all[0].enabled)
    }

    func testUpdate() throws {
        var s = Snippet(trigger: ";hi", expansion: "Hello")
        try db.insertSnippet(s)
        s.expansion = "Hello, updated!"
        try db.updateSnippet(s)
        let all = db.fetchAll()
        XCTAssertEqual(all[0].expansion, "Hello, updated!")
    }

    func testDelete() throws {
        let s = Snippet(trigger: ";bye", expansion: "Goodbye")
        try db.insertSnippet(s)
        XCTAssertEqual(db.fetchAll().count, 1)
        try db.deleteSnippet(id: s.id)
        XCTAssertEqual(db.fetchAll().count, 0)
    }

    func testDuplicateTriggerThrows() throws {
        let s1 = Snippet(trigger: ";dup", expansion: "First")
        let s2 = Snippet(trigger: ";dup", expansion: "Second")
        try db.insertSnippet(s1)
        XCTAssertThrowsError(try db.insertSnippet(s2))
    }

    func testFetchOrderByCreatedAt() throws {
        for i in 1...5 {
            try db.insertSnippet(Snippet(trigger: ";s\(i)", expansion: "Expansion \(i)"))
        }
        let all = db.fetchAll()
        XCTAssertEqual(all.count, 5)
        let triggers = all.map { $0.trigger }
        XCTAssertEqual(triggers, [";s1",";s2",";s3",";s4",";s5"])
    }

    func testEnabledFlag() throws {
        let s = Snippet(trigger: ";off", expansion: "Off", enabled: false)
        try db.insertSnippet(s)
        let fetched = db.fetchAll().first!
        XCTAssertFalse(fetched.enabled)
    }
}
