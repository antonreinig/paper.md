import XCTest
@testable import PaperMD

final class WorkspaceItemTests: XCTestCase {
    func testRecognizedMarkdownExtensions() {
        XCTAssertTrue(WorkspaceItem.markdownExtensions.contains("md"))
        XCTAssertTrue(WorkspaceItem.markdownExtensions.contains("markdown"))
        XCTAssertFalse(WorkspaceItem.markdownExtensions.contains("txt"))
    }
}
