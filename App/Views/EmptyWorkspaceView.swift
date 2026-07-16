import SwiftUI

struct EmptyWorkspaceView: View {
    @EnvironmentObject private var workspace: WorkspaceStore

    var body: some View {
        ContentUnavailableView {
            Label("paper.md", systemImage: "doc.richtext")
        } description: {
            Text(workspace.rootURL == nil ? "Open a folder to browse and edit Markdown files." : "Choose a Markdown file from the sidebar.")
        } actions: {
            if workspace.rootURL == nil {
                Button("Open Folder…") { workspace.chooseWorkspace() }
                    .buttonStyle(.borderedProminent)
            }
        }
    }
}
