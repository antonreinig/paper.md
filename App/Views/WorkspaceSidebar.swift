import AppKit
import SwiftUI

struct WorkspaceSidebar: View {
    @EnvironmentObject private var workspace: WorkspaceStore
    @State private var expandedFolders: Set<URL> = []

    var body: some View {
        VStack(spacing: 0) {
            if let root = workspace.rootURL {
                List(selection: selection) {
                    WorkspaceItemRows(items: workspace.items, expandedFolders: $expandedFolders)
                    if !workspace.documentHeadings.isEmpty {
                        Section("In This Document") {
                            ForEach(workspace.documentHeadings) { heading in
                                Button {
                                    performEditorCommand(.navigateToHeading, payload: ["id": heading.id])
                                } label: {
                                    Label(heading.title, systemImage: "textformat")
                                        .lineLimit(2)
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                        .contentShape(Rectangle())
                                }
                                .buttonStyle(.plain)
                                .help("Go to \(heading.title)")
                                .accessibilityLabel("Go to heading \(heading.title)")
                            }
                        }
                    }
                }
                .listStyle(.sidebar)
                .safeAreaInset(edge: .top) {
                    HStack {
                        Image(systemName: "folder")
                        Text(root.lastPathComponent).font(.headline).lineLimit(1)
                        Spacer()
                        Button { workspace.closeWorkspace() } label: {
                            Image(systemName: "xmark")
                                .font(.system(size: 10, weight: .semibold))
                                .frame(width: 18, height: 18)
                                .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .foregroundStyle(.secondary)
                        .help("Close Folder")
                        .accessibilityLabel("Close folder \(root.lastPathComponent)")
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 8)
                }
            } else {
                VStack(spacing: 12) {
                    Image(systemName: "folder.badge.plus").font(.system(size: 32)).foregroundStyle(.secondary)
                    Button("Open Folder…") { workspace.chooseWorkspace() }
                        .buttonStyle(.bordered)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .toolbar {
            ToolbarItemGroup(placement: .primaryAction) {
                Button { workspace.chooseWorkspace() } label: {
                    Label("Open Folder", systemImage: "folder")
                }
                .help("Open Folder (⇧⌘O)")

                Menu {
                    Button("New Markdown File") { workspace.createFile() }
                    Button("New Folder") { workspace.createFolder() }
                } label: {
                    Label("New Item", systemImage: "plus")
                }
                .disabled(workspace.rootURL == nil)
            }
        }
    }

    private var selection: Binding<URL?> {
        Binding(get: { workspace.selectedFile }, set: { workspace.select($0) })
    }
}

private struct WorkspaceItemRows: View {
    @EnvironmentObject private var workspace: WorkspaceStore

    let items: [WorkspaceItem]
    @Binding var expandedFolders: Set<URL>

    var body: some View {
        ForEach(items) { item in
            if item.isDirectory {
                let compacted = compactedFolder(item)
                DisclosureGroup(isExpanded: expansionBinding(for: compacted.item.url)) {
                    if compacted.item.children?.isEmpty != false {
                        Label("Empty folder", systemImage: "tray")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .accessibilityLabel("This folder is empty")
                    } else {
                        WorkspaceItemRows(
                            items: compacted.item.children ?? [],
                            expandedFolders: $expandedFolders
                        )
                    }
                } label: {
                    Label(compacted.label, systemImage: "folder")
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .contentShape(Rectangle())
                        .onTapGesture { toggleExpansion(for: compacted.item.url) }
                }
                .help(compacted.item.url.path)
                .accessibilityLabel("Folder \(compacted.label)")
                .contextMenu { contextMenu(for: item) }
            } else {
                Label(item.name, systemImage: "doc.text")
                    .tag(item.url)
                    .help(item.url.path)
                    .accessibilityLabel("Markdown file \(item.name)")
                    .contextMenu { contextMenu(for: item) }
            }
        }
    }

    private func compactedFolder(_ folder: WorkspaceItem) -> (label: String, item: WorkspaceItem) {
        var components = [folder.name]
        var deepest = folder
        while let children = deepest.children,
              children.count == 1,
              let onlyChild = children.first,
              onlyChild.isDirectory {
            components.append(onlyChild.name)
            deepest = onlyChild
        }
        return (components.joined(separator: "/"), deepest)
    }

    private func expansionBinding(for url: URL) -> Binding<Bool> {
        Binding(
            get: { expandedFolders.contains(url) },
            set: { isExpanded in
                if isExpanded {
                    expandedFolders.insert(url)
                } else {
                    expandedFolders.remove(url)
                }
            }
        )
    }

    private func toggleExpansion(for url: URL) {
        if expandedFolders.contains(url) {
            expandedFolders.remove(url)
        } else {
            expandedFolders.insert(url)
        }
    }

    @ViewBuilder
    private func contextMenu(for item: WorkspaceItem) -> some View {
        Button("Rename…") { workspace.rename(item) }
        Button("Show in Finder") { NSWorkspace.shared.activateFileViewerSelecting([item.url]) }
        Divider()
        Button("Move to Trash", role: .destructive) { workspace.moveToTrash(item) }
    }
}
