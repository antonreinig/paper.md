import AppKit
import SwiftUI

struct RootView: View {
    @EnvironmentObject private var workspace: WorkspaceStore
    @AppStorage("appearance") private var appearance = "system"
    @State private var columnVisibility: NavigationSplitViewVisibility = .detailOnly

    var body: some View {
        NavigationSplitView(columnVisibility: $columnVisibility) {
            WorkspaceSidebar()
                .navigationSplitViewColumnWidth(min: 190, ideal: 250, max: 360)
        } detail: {
            Group {
                if let session = workspace.session {
                    EditorContainer(
                        session: session,
                        initialScrollPosition: workspace.scrollPosition(for: session.url),
                        onScrollPositionChanged: { position in
                            workspace.rememberScrollPosition(position, for: session.url)
                        },
                        onHeadingsChanged: { headings in
                            workspace.updateDocumentHeadings(headings, for: session.url)
                        }
                    )
                        .id(session.id)
                } else {
                    EmptyWorkspaceView()
                }
            }
        }
        .toolbarBackground(.clear, for: .windowToolbar)
        .navigationTitle(workspace.session?.url.lastPathComponent ?? "paper.md")
        .alert("Couldn’t complete the operation", isPresented: errorIsPresented) {
            Button("OK") { workspace.errorMessage = nil; workspace.session?.errorMessage = nil }
        } message: {
            Text(workspace.session?.errorMessage ?? workspace.errorMessage ?? "Unknown error")
        }
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.willResignActiveNotification)) { _ in
            workspace.session?.flush()
        }
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.willTerminateNotification)) { _ in
            workspace.session?.flush()
        }
        .onReceive(NotificationCenter.default.publisher(for: NSWindow.willCloseNotification)) { _ in
            workspace.session?.flush()
        }
        .onReceive(NSWorkspace.shared.notificationCenter.publisher(for: NSWorkspace.willSleepNotification)) { _ in
            workspace.session?.flush()
        }
        .preferredColorScheme(preferredColorScheme)
        .onChange(of: workspace.session?.id) { _, sessionID in
            if sessionID != nil { columnVisibility = .detailOnly }
        }
    }

    private var errorIsPresented: Binding<Bool> {
        Binding(
            get: { workspace.errorMessage != nil || workspace.session?.errorMessage != nil },
            set: { if !$0 { workspace.errorMessage = nil; workspace.session?.errorMessage = nil } }
        )
    }

    private var preferredColorScheme: ColorScheme? {
        switch appearance {
        case "light": .light
        case "dark": .dark
        default: nil
        }
    }
}

private struct EditorContainer: View {
    @ObservedObject var session: DocumentSession
    let initialScrollPosition: CGFloat
    let onScrollPositionChanged: (CGFloat) -> Void
    let onHeadingsChanged: ([DocumentHeading]) -> Void

    var body: some View {
        EditorWebView(
            session: session,
            initialScrollPosition: initialScrollPosition,
            onScrollPositionChanged: onScrollPositionChanged,
            onHeadingsChanged: onHeadingsChanged
        )
            .toolbar { EditorToolbar() }
            .confirmationDialog(
                "This file changed in two places",
                isPresented: Binding(
                    get: { session.conflict != nil },
                    set: { _ in }
                ),
                titleVisibility: .visible
            ) {
                Button("Use External Version") { session.useExternalVersion() }
                Button("Keep My Version") { session.keepLocalVersion() }
                Button("Keep Both") { session.saveBothVersions() }
                Button("Decide Later", role: .cancel) {}
            } message: {
                Text("paper.md protected both versions because your edits overlap with changes made by another process.")
            }
    }
}
