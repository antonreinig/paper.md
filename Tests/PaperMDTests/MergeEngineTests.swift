import XCTest
@testable import PaperMD

final class MergeEngineTests: XCTestCase {
    func testRemoteChangeWinsWhenLocalIsUnchanged() {
        XCTAssertEqual(MergeEngine.merge(base: "a\nb", local: "a\nb", remote: "a\nB"), .merged("a\nB"))
    }

    func testLocalChangeWinsWhenRemoteIsUnchanged() {
        XCTAssertEqual(MergeEngine.merge(base: "a\nb", local: "A\nb", remote: "a\nb"), .merged("A\nb"))
    }

    func testDisjointChangesAreMerged() {
        XCTAssertEqual(
            MergeEngine.merge(base: "a\nb\nc", local: "A\nb\nc", remote: "a\nb\nC"),
            .merged("A\nb\nC")
        )
    }

    func testOverlappingChangesConflict() {
        XCTAssertEqual(MergeEngine.merge(base: "a\nb", local: "a\nlocal", remote: "a\nremote"), .conflict)
    }
}
