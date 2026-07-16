import AppKit
import SwiftUI

struct WorkspaceCommands: Commands {
    @ObservedObject var workspace: WorkspaceStore

    var body: some Commands {
        CommandGroup(after: .newItem) {
            Button("Open Folder…") { workspace.chooseWorkspace() }
                .keyboardShortcut("o", modifiers: [.command, .shift])
            Button("New Markdown File") { workspace.createFile() }
                .keyboardShortcut("n", modifiers: [.command])
                .disabled(workspace.rootURL == nil)
        }
        CommandGroup(replacing: .saveItem) {
            Button("Save") { workspace.session?.flush() }
                .keyboardShortcut("s", modifiers: .command)
                .disabled(workspace.session == nil)

            Divider()

            Button("Close Window") {
                workspace.session?.flush()
                (NSApp.keyWindow ?? NSApp.mainWindow)?.performClose(nil)
            }
            .keyboardShortcut("w", modifiers: .command)
        }
    }
}

struct EditorCommands: Commands {
    var body: some Commands {
        CommandGroup(after: .pasteboard) {
            Divider()
            Button("Bold") { performEditorCommand(.bold) }
                .keyboardShortcut("b", modifiers: .command)
            Button("Italic") { performEditorCommand(.italic) }
                .keyboardShortcut("i", modifiers: .command)
            Button("Add Link…") { requestLink() }
                .keyboardShortcut("k", modifiers: .command)
        }

        CommandMenu("Format") {
            Button("Paragraph") { performEditorCommand(.paragraph) }
            Button("Heading 1") { performEditorCommand(.heading1) }
                .keyboardShortcut("1", modifiers: [.command, .option])
            Button("Heading 2") { performEditorCommand(.heading2) }
                .keyboardShortcut("2", modifiers: [.command, .option])
            Button("Heading 3") { performEditorCommand(.heading3) }
                .keyboardShortcut("3", modifiers: [.command, .option])
            Divider()
            Button("Bulleted List") { performEditorCommand(.bulletList) }
            Button("Numbered List") { performEditorCommand(.orderedList) }
            Button("Task List") { performEditorCommand(.taskList) }
            Button("Block Quote") { performEditorCommand(.blockquote) }
            Button("Code Block") { performEditorCommand(.codeBlock) }
            Divider()
            Button("Insert Table") { performEditorCommand(.insertTable) }
        }

        CommandGroup(replacing: .undoRedo) {
            Button("Undo") { performEditorCommand(.undo) }
                .keyboardShortcut("z", modifiers: .command)
            Button("Redo") { performEditorCommand(.redo) }
                .keyboardShortcut("z", modifiers: [.command, .shift])
        }
    }

    private func requestLink() {
        let alert = NSAlert()
        alert.messageText = "Add Link"
        alert.informativeText = "Enter the destination URL."
        alert.addButton(withTitle: "Add")
        alert.addButton(withTitle: "Cancel")
        let field = NSTextField(string: "https://")
        field.frame.size = NSSize(width: 360, height: 24)
        alert.accessoryView = field
        guard alert.runModal() == .alertFirstButtonReturn else { return }
        performEditorCommand(.link, payload: ["url": field.stringValue])
    }
}
