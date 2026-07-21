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
    @Published private(set) var documentHeadings: [DocumentHeading] = []
    @Published var errorMessage: String?

    private var directoryMonitor: DirectoryMonitor?
    private var refreshTask: Task<Void, Never>?
    private var securityScopedURL: URL?
    private var singleFileURL: URL?
    private var documentScrollPositions: [URL: CGFloat] = [:]
    private let bookmarkKey: String

    init(bookmarkKey: String = "PaperMD.workspaceBookmark") {
        self.bookmarkKey = bookmarkKey
    }

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
        openWorkspace(url, selecting: nil, securityScopedResource: url)
    }

    func closeWorkspace() {
        session?.flush()
        session = nil
        documentHeadings = []
        selectedFile = nil
        rootURL = nil
        items = []
        refreshTask?.cancel()
        refreshTask = nil
        stopSecurityScope()
        UserDefaults.standard.removeObject(forKey: bookmarkKey)
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
            if (try? url.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) == true {
                openWorkspace(url)
            } else {
                openDocument(url)
            }
            if stale { persistBookmark(url) }
        } catch {
            UserDefaults.standard.removeObject(forKey: bookmarkKey)
        }
    }

    func openDocument(_ url: URL) {
        let documentURL = normalizedFileURL(url)
        if singleFileURL == nil,
           let rootURL,
           documentURL.path.hasPrefix(normalizedFileURL(rootURL).path + "/") {
            select(documentURL)
            return
        }
        openWorkspace(
            documentURL.deletingLastPathComponent(),
            selecting: documentURL,
            securityScopedResource: url
        )
    }

    func select(_ url: URL?) {
        if let url,
           (try? url.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) == true {
            return
        }
        if let url, let rootURL, !WorkspaceItem.contains(url, in: rootURL) {
            errorMessage = "The selected file is outside the open workspace."
            return
        }
        session?.flush()
        selectedFile = url
        documentHeadings = []
        guard let url else { session = nil; return }
        do {
            session = try DocumentSession(url: url, workspaceRootURL: rootURL) { [weak self] movedURL in
                guard let self else { return }
                self.selectedFile = movedURL
                if self.singleFileURL != nil {
                    self.singleFileURL = self.normalizedFileURL(movedURL)
                    self.rootURL = self.singleFileURL?.deletingLastPathComponent()
                    self.persistBookmark(movedURL)
                }
                self.scheduleRefresh()
            }
        } catch {
            session = nil
            errorMessage = error.localizedDescription
        }
    }

    func scrollPosition(for url: URL) -> CGFloat {
        documentScrollPositions[normalizedFileURL(url)] ?? 0
    }

    func rememberScrollPosition(_ position: CGFloat, for url: URL) {
        guard position.isFinite else { return }
        documentScrollPositions[normalizedFileURL(url)] = max(0, position)
    }

    func updateDocumentHeadings(_ headings: [DocumentHeading], for url: URL) {
        guard normalizedFileURL(url) == selectedFile.map(normalizedFileURL) else { return }
        documentHeadings = headings
    }

    func createFile() {
        guard let rootURL else { return }
        let panel = NSSavePanel()
        panel.title = "New Markdown File"
        panel.directoryURL = selectedFile?.deletingLastPathComponent() ?? rootURL
        panel.nameFieldStringValue = "Untitled.md"
        panel.allowedContentTypes = [UTType(filenameExtension: "md") ?? .plainText]
        guard panel.runModal() == .OK, let url = panel.url else { return }
        guard WorkspaceItem.contains(url, in: rootURL) else {
            errorMessage = "New files must be created inside the open workspace."
            return
        }
        do {
            try Data("# Untitled\n\n".utf8).write(to: url, options: .withoutOverwriting)
            if singleFileURL == nil {
                refreshWorkspace()
                select(url)
            } else {
                openDocument(url)
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func createFolder() {
        guard let rootURL, singleFileURL == nil else { return }
        let alert = NSAlert()
        alert.messageText = "New Folder"
        alert.addButton(withTitle: "Create")
        alert.addButton(withTitle: "Cancel")
        let field = NSTextField(string: "New Folder")
        field.frame.size = NSSize(width: 320, height: 24)
        alert.accessoryView = field
        guard alert.runModal() == .alertFirstButtonReturn,
              isSafeItemName(field.stringValue) else { return }
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
              isSafeItemName(field.stringValue) else { return }
        let destination = item.url.deletingLastPathComponent().appendingPathComponent(field.stringValue)
        do {
            session?.flush()
            try FileManager.default.moveItem(at: item.url, to: destination)
            if singleFileURL != nil {
                singleFileURL = normalizedFileURL(destination)
                rootURL = singleFileURL?.deletingLastPathComponent()
                persistBookmark(destination)
            }
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
            let wasSingleFile = singleFileURL != nil
            if selectedFile == item.url { select(nil) }
            try FileManager.default.trashItem(at: item.url, resultingItemURL: nil)
            if wasSingleFile { closeWorkspace() } else { refreshWorkspace() }
        } catch { errorMessage = error.localizedDescription }
    }

    func refreshWorkspace() {
        guard let rootURL else { return }
        if let singleFileURL {
            if FileManager.default.fileExists(atPath: singleFileURL.path) {
                items = [WorkspaceItem(url: singleFileURL, isDirectory: false, children: nil)]
            } else {
                items = []
            }
            return
        }
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

    private func openWorkspace(_ url: URL, selecting selectedURL: URL?, securityScopedResource: URL) {
        session?.flush()
        session = nil
        selectedFile = nil
        refreshTask?.cancel()
        refreshTask = nil
        stopSecurityScope()

        let scopedResourceIsDirectory = (try? securityScopedResource.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) == true
        singleFileURL = scopedResourceIsDirectory ? nil : normalizedFileURL(securityScopedResource)
        if securityScopedResource.startAccessingSecurityScopedResource() {
            securityScopedURL = securityScopedResource
        }
        let workspaceURL = normalizedFileURL(url)
        rootURL = workspaceURL
        persistBookmark(securityScopedResource)
        if singleFileURL == nil {
            directoryMonitor = DirectoryMonitor { [weak self] in
                Task { @MainActor [weak self] in self?.scheduleRefresh() }
            }
        }
        refreshWorkspace()
        if let selectedURL { select(selectedURL) }
    }

    private func normalizedFileURL(_ url: URL) -> URL {
        url.standardizedFileURL.resolvingSymlinksInPath()
    }

    private func isSafeItemName(_ name: String) -> Bool {
        !name.isEmpty && name != "." && name != ".." && !name.contains("/")
    }

    private func stopSecurityScope() {
        securityScopedURL?.stopAccessingSecurityScopedResource()
        securityScopedURL = nil
        singleFileURL = nil
        directoryMonitor?.stop()
        directoryMonitor = nil
    }

    deinit { securityScopedURL?.stopAccessingSecurityScopedResource() }
}
