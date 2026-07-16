import XCTest
@testable import PaperMD

@MainActor
final class DocumentSessionTests: XCTestCase {
    func testEditorChangeIsPersistedAfterDebounce() async throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let file = directory.appendingPathComponent("test.md")
        try Data("old".utf8).write(to: file)

        let session = try DocumentSession(url: file)
        session.editorChanged("new")
        try await Task.sleep(for: .milliseconds(550))

        XCTAssertEqual(try String(contentsOf: file, encoding: .utf8), "new")
    }

    func testExplicitFlushWritesImmediately() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let file = directory.appendingPathComponent("test.md")
        try Data("old".utf8).write(to: file)

        let session = try DocumentSession(url: file)
        session.editorChanged("immediate")
        session.flush()

        XCTAssertEqual(try String(contentsOf: file, encoding: .utf8), "immediate")
    }

    func testExternalChangeReloadsIntoCleanDocument() throws {
        let (directory, file) = try temporaryMarkdown("a\nb")
        defer { try? FileManager.default.removeItem(at: directory) }
        let session = try DocumentSession(url: file)

        try Data("a\nexternal".utf8).write(to: file, options: .atomic)
        session.reloadFromDiskIfChanged()

        XCTAssertEqual(session.content, "a\nexternal")
        XCTAssertNil(session.conflict)
    }

    func testDisjointLocalAndExternalChangesMerge() throws {
        let (directory, file) = try temporaryMarkdown("first\nmiddle\nlast")
        defer { try? FileManager.default.removeItem(at: directory) }
        let session = try DocumentSession(url: file)
        session.editorChanged("FIRST\nmiddle\nlast")

        try Data("first\nmiddle\nLAST".utf8).write(to: file, options: .atomic)
        session.reloadFromDiskIfChanged()

        XCTAssertEqual(session.content, "FIRST\nmiddle\nLAST")
        XCTAssertNil(session.conflict)
    }

    func testOverlappingLocalAndExternalChangesAreProtected() throws {
        let (directory, file) = try temporaryMarkdown("same")
        defer { try? FileManager.default.removeItem(at: directory) }
        let session = try DocumentSession(url: file)
        session.editorChanged("local")

        try Data("external".utf8).write(to: file, options: .atomic)
        session.reloadFromDiskIfChanged()

        XCTAssertEqual(session.content, "local")
        XCTAssertEqual(session.conflict?.external, "external")
    }

    private func temporaryMarkdown(_ contents: String) throws -> (URL, URL) {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let file = directory.appendingPathComponent("test.md")
        try Data(contents.utf8).write(to: file)
        return (directory, file)
    }
}
