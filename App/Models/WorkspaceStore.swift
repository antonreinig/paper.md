import AppKit
import Combine
import Foundation
import UniformTypeIdentifiers

@MainActor
final class WorkspaceStore: ObservableObject {
    @Published private(set) var rootURL: URL?
    @Published private(set) var items: [WorkspaceItem] = []
    @Published var selectedFile: URL?
    @Published private(set) var session: DocumentSession?
    @Published var errorMessage: String?

    private var directoryMonitor: DirectoryMonitor?
    private var refreshTask: Task<Void, Never>?
    private var securityScopedURL: URL?
    private let bookmarkKey = "MarkdownViewer.workspaceBookmark"

    func chooseWorkspace() {
        let panel = NSOpenPanel()
        panel.title = "Open Markdown Workspace"
        panel.prompt = "Open"
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.allowsMultipleSelection = false
        guard panel.runModal() == .OK, let url = panel.url else { return }
        openWorkspace(url)
    }

    func openWorkspace(_ url: URL) {
        stopSecurityScope()
        if url.startAccessingSecurityScopedResource() { securityScopedURL = url }
        rootURL = url
        persistBookmark(url)
        directoryMonitor = DirectoryMonitor { [weak self] in
            Task { @MainActor [weak self] in self?.scheduleRefresh() }
        }
        refreshWorkspace()
    }

    func restoreWorkspaceIfAvailable() {
        guard rootURL == nil,
              let data = UserDefaults.standard.data(forKey: bookmarkKey) else { return }
        do {
            var stale = false
            let url = try URL(
                resolvingBookmarkData: data,
                options: [.withSecurityScope],
                relativeTo: nil,
                bookmarkDataIsStale: &stale
            )
            openWorkspace(url)
            if stale { persistBookmark(url) }
        } catch {
            UserDefaults.standard.removeObject(forKey: bookmarkKey)
        }
    }

    func openDocument(_ url: URL) {
        if let rootURL, url.standardizedFileURL.path.hasPrefix(rootURL.standardizedFileURL.path + "/") {
            select(url)
            return
        }
        stopSecurityScope()
        if url.startAccessingSecurityScopedResource() { securityScopedURL = url }
        rootURL = url.deletingLastPathComponent()
        items = [WorkspaceItem(url: url, isDirectory: false, children: nil)]
        select(url)
    }

    func select(_ url: URL?) {
        session?.flush()
        selectedFile = url
        guard let url else { session = nil; return }
        do {
            session = try DocumentSession(url: url) { [weak self] movedURL in
                self?.selectedFile = movedURL
                self?.scheduleRefresh()
            }
        } catch {
            session = nil
            errorMessage = error.localizedDescription
        }
    }

    func createFile() {
        guard let rootURL else { return }
        let panel = NSSavePanel()
        panel.title = "New Markdown File"
        panel.directoryURL = selectedFile?.deletingLastPathComponent() ?? rootURL
        panel.nameFieldStringValue = "Untitled.md"
        panel.allowedContentTypes = [UTType(filenameExtension: "md") ?? .plainText]
        guard panel.runModal() == .OK, let url = panel.url else { return }
        do {
            try Data("# Untitled\n\n".utf8).write(to: url, options: .withoutOverwriting)
            refreshWorkspace()
            select(url)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func createFolder() {
        guard let rootURL else { return }
        let alert = NSAlert()
        alert.messageText = "New Folder"
        alert.addButton(withTitle: "Create")
        alert.addButton(withTitle: "Cancel")
        let field = NSTextField(string: "New Folder")
        field.frame.size = NSSize(width: 320, height: 24)
        alert.accessoryView = field
        guard alert.runModal() == .alertFirstButtonReturn else { return }
        let parent = selectedFile?.deletingLastPathComponent() ?? rootURL
        do {
            try FileManager.default.createDirectory(at: parent.appendingPathComponent(field.stringValue), withIntermediateDirectories: false)
            refreshWorkspace()
        } catch { errorMessage = error.localizedDescription }
    }

    func rename(_ item: WorkspaceItem) {
        let alert = NSAlert()
        alert.messageText = "Rename \(item.name)"
        alert.addButton(withTitle: "Rename")
        alert.addButton(withTitle: "Cancel")
        let field = NSTextField(string: item.name)
        field.frame.size = NSSize(width: 320, height: 24)
        alert.accessoryView = field
        guard alert.runModal() == .alertFirstButtonReturn,
              !field.stringValue.isEmpty,
              !field.stringValue.contains("/") else { return }
        let destination = item.url.deletingLastPathComponent().appendingPathComponent(field.stringValue)
        do {
            session?.flush()
            try FileManager.default.moveItem(at: item.url, to: destination)
            if selectedFile == item.url { select(destination) }
            refreshWorkspace()
        } catch { errorMessage = error.localizedDescription }
    }

    func moveToTrash(_ item: WorkspaceItem) {
        let alert = NSAlert()
        alert.messageText = "Move “\(item.name)” to the Trash?"
        alert.addButton(withTitle: "Move to Trash")
        alert.addButton(withTitle: "Cancel")
        guard alert.runModal() == .alertFirstButtonReturn else { return }
        do {
            if selectedFile == item.url { select(nil) }
            try FileManager.default.trashItem(at: item.url, resultingItemURL: nil)
            refreshWorkspace()
        } catch { errorMessage = error.localizedDescription }
    }

    func refreshWorkspace() {
        guard let rootURL else { return }
        do {
            items = try WorkspaceItem.scan(root: rootURL)
            let directories = [rootURL] + collectDirectories(items)
            directoryMonitor?.watch(directories)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func scheduleRefresh() {
        refreshTask?.cancel()
        refreshTask = Task { [weak self] in
            try? await Task.sleep(for: .milliseconds(180))
            guard !Task.isCancelled else { return }
            self?.refreshWorkspace()
        }
    }

    private func collectDirectories(_ items: [WorkspaceItem]) -> [URL] {
        items.flatMap { item -> [URL] in
            guard item.isDirectory else { return [] }
            return [item.url] + collectDirectories(item.children ?? [])
        }
    }

    private func persistBookmark(_ url: URL) {
        do {
            let data = try url.bookmarkData(options: [.withSecurityScope], includingResourceValuesForKeys: nil, relativeTo: nil)
            UserDefaults.standard.set(data, forKey: bookmarkKey)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func stopSecurityScope() {
        securityScopedURL?.stopAccessingSecurityScopedResource()
        securityScopedURL = nil
        directoryMonitor?.stop()
        directoryMonitor = nil
    }

    deinit { securityScopedURL?.stopAccessingSecurityScopedResource() }
}
