import XCTest
@testable import PaperMD

final class BundleResourceTests: XCTestCase {
    func testEditorEntryPointIsBundled() throws {
        let url = try XCTUnwrap(Bundle.main.url(forResource: "index", withExtension: "html"))
        let html = try String(contentsOf: url, encoding: .utf8)
        XCTAssertTrue(html.contains("paper.md Editor"))
    }

    func testEditorScriptIsBundled() throws {
        let indexURL = try XCTUnwrap(Bundle.main.url(forResource: "index", withExtension: "html"))
        let html = try String(contentsOf: indexURL, encoding: .utf8)
        let pattern = #"src=\"\./assets/([^\"]+\.js)\""#
        let expression = try NSRegularExpression(pattern: pattern)
        let range = NSRange(html.startIndex..., in: html)
        let match = try XCTUnwrap(expression.firstMatch(in: html, range: range))
        let filenameRange = try XCTUnwrap(Range(match.range(at: 1), in: html))
        let script = indexURL.deletingLastPathComponent()
            .appendingPathComponent("assets")
            .appendingPathComponent(String(html[filenameRange]))
        XCTAssertTrue(FileManager.default.fileExists(atPath: script.path))
    }
}
