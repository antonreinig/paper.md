import AppKit
import Combine
import Foundation

struct DocumentConflict: Identifiable, Sendable {
    let id = UUID()
    let local: String
    let external: String
}

@MainActor
final class DocumentSession: ObservableObject, Identifiable {
    let id = UUID()
    @Published private(set) var url: URL
    @Published private(set) var content: String
    @Published var conflict: DocumentConflict?
    @Published var errorMessage: String?

    private var baseContent: String
    private var isDirty = false
    private var saveTask: Task<Void, Never>?
    private var deadlineTask: Task<Void, Never>?
    private var externalReloadTask: Task<Void, Never>?
    private var presenter: FileObservationPresenter?
    private var isWriting = false
    private let fileManager: FileManager
    private let onURLChanged: (URL) -> Void

    init(url: URL, fileManager: FileManager = .default, onURLChanged: @escaping (URL) -> Void = { _ in }) throws {
        self.url = url
        self.fileManager = fileManager
        self.onURLChanged = onURLChanged
        let data = try Data(contentsOf: url)
        guard let markdown = String(data: data, encoding: .utf8) else {
            throw CocoaError(.fileReadInapplicableStringEncoding)
        }
        content = markdown
        baseContent = markdown
        startPresenting(url)
    }

    func editorChanged(_ markdown: String) {
        guard markdown != content else { return }
        content = markdown
        isDirty = content != baseContent
        scheduleSave()
    }

    func flush() {
        saveTask?.cancel()
        deadlineTask?.cancel()
        saveTask = nil
        deadlineTask = nil
        guard isDirty else { return }
        do { try saveNow() } catch { errorMessage = error.localizedDescription }
    }

    func useExternalVersion() {
        guard let conflict else { return }
        content = conflict.external
        baseContent = conflict.external
        isDirty = false
        self.conflict = nil
    }

    func keepLocalVersion() {
        guard conflict != nil else { return }
        conflict = nil
        isDirty = true
        flush()
    }

    func saveBothVersions() {
        guard let conflict else { return }
        let sibling = url.deletingPathExtension()
            .appendingPathExtension("local-conflict")
            .appendingPathExtension(url.pathExtension)
        do {
            try Data(conflict.local.utf8).write(to: sibling, options: .atomic)
            content = conflict.external
            baseContent = conflict.external
            isDirty = false
            self.conflict = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func scheduleSave() {
        saveTask?.cancel()
        saveTask = Task { [weak self] in
            try? await Task.sleep(for: .milliseconds(300))
            guard !Task.isCancelled else { return }
            self?.flush()
        }

        if deadlineTask == nil {
            deadlineTask = Task { [weak self] in
                try? await Task.sleep(for: .milliseconds(1500))
                guard !Task.isCancelled else { return }
                self?.deadlineTask = nil
                self?.flush()
            }
        }
    }

    private func saveNow() throws {
        let snapshot = content
        isWriting = true
        defer { isWriting = false }

        var coordinationError: NSError?
        var writeError: Error?
        let coordinator = NSFileCoordinator(filePresenter: presenter)
        coordinator.coordinate(writingItemAt: url, options: .forReplacing, error: &coordinationError) { coordinatedURL in
            do {
                try Data(snapshot.utf8).write(to: coordinatedURL, options: .atomic)
            } catch {
                writeError = error
            }
        }
        if let coordinationError { throw coordinationError }
        if let writeError { throw writeError }
        baseContent = snapshot
        isDirty = content != snapshot
        if isDirty { scheduleSave() }
    }

    private func startPresenting(_ url: URL) {
        if let presenter { NSFileCoordinator.removeFilePresenter(presenter) }
        let newPresenter = FileObservationPresenter(
            url: url,
            onChange: { [weak self] in
                Task { @MainActor [weak self] in self?.scheduleExternalReload() }
            },
            onMove: { [weak self] newURL in
                Task { @MainActor [weak self] in
                    guard let self else { return }
                    self.url = newURL
                    self.onURLChanged(newURL)
                    self.startPresenting(newURL)
                }
            }
        )
        presenter = newPresenter
        NSFileCoordinator.addFilePresenter(newPresenter)
    }

    private func scheduleExternalReload() {
        guard !isWriting else { return }
        externalReloadTask?.cancel()
        externalReloadTask = Task { [weak self] in
            try? await Task.sleep(for: .milliseconds(120))
            guard !Task.isCancelled else { return }
            self?.reloadFromDiskIfChanged()
        }
    }

    func reloadFromDiskIfChanged() {
        guard fileManager.fileExists(atPath: url.path) else { return }
        do {
            let data = try Data(contentsOf: url)
            guard let external = String(data: data, encoding: .utf8) else {
                throw CocoaError(.fileReadInapplicableStringEncoding)
            }
            guard external != baseContent else { return }

            switch MergeEngine.merge(base: baseContent, local: content, remote: external) {
            case .merged(let merged):
                content = merged
                baseContent = external
                isDirty = merged != external
                if isDirty { scheduleSave() }
            case .conflict:
                conflict = DocumentConflict(local: content, external: external)
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    deinit {
        saveTask?.cancel()
        deadlineTask?.cancel()
        externalReloadTask?.cancel()
        if let presenter { NSFileCoordinator.removeFilePresenter(presenter) }
    }
}
