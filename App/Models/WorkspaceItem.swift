import Foundation

struct WorkspaceItem: Identifiable, Hashable, Sendable {
    let url: URL
    let isDirectory: Bool
    var children: [WorkspaceItem]?

    var id: URL { url }
    var name: String { url.lastPathComponent }

    static let markdownExtensions: Set<String> = ["md", "markdown", "mdown"]

    static func scan(root: URL, fileManager: FileManager = .default) throws -> [WorkspaceItem] {
        let canonicalRoot = root.standardizedFileURL.resolvingSymlinksInPath()
        return try scanDirectory(canonicalRoot, root: canonicalRoot, fileManager: fileManager)
    }

    static func contains(_ candidate: URL, in root: URL) -> Bool {
        let canonicalRoot = root.standardizedFileURL.resolvingSymlinksInPath()
        let canonicalCandidate = candidate.standardizedFileURL.resolvingSymlinksInPath()
        if canonicalRoot.path == "/" { return canonicalCandidate.path.hasPrefix("/") }
        return canonicalCandidate == canonicalRoot
            || canonicalCandidate.path.hasPrefix(canonicalRoot.path + "/")
    }

    private static func scanDirectory(_ directory: URL, root: URL, fileManager: FileManager) throws -> [WorkspaceItem] {
        let keys: Set<URLResourceKey> = [.isDirectoryKey, .isHiddenKey, .isSymbolicLinkKey, .nameKey]
        let urls = try fileManager.contentsOfDirectory(
            at: directory,
            includingPropertiesForKeys: Array(keys),
            options: [.skipsPackageDescendants]
        )

        return try urls.compactMap { url in
            let values = try url.resourceValues(forKeys: keys)
            let name = values.name ?? url.lastPathComponent
            if values.isHidden == true
                || values.isSymbolicLink == true
                || ignoredDirectoryNames.contains(name)
                || !contains(url, in: root) {
                return nil
            }
            if values.isDirectory == true {
                let children = try scanDirectory(url, root: root, fileManager: fileManager)
                return WorkspaceItem(url: url, isDirectory: true, children: children)
            }
            guard markdownExtensions.contains(url.pathExtension.lowercased()) else { return nil }
            return WorkspaceItem(url: url, isDirectory: false, children: nil)
        }
        .sorted {
            if $0.isDirectory != $1.isDirectory { return $0.isDirectory }
            return $0.name.localizedStandardCompare($1.name) == .orderedAscending
        }
    }

    private static let ignoredDirectoryNames: Set<String> = [
        ".git", ".build", "DerivedData", "node_modules", "Pods"
    ]
}
