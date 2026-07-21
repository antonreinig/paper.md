import Foundation

enum EditorCommandName: String, Sendable {
    case bold, italic, strike, code, link
    case heading1, heading2, heading3, paragraph
    case bulletList, orderedList, taskList, blockquote, codeBlock, horizontalRule
    case insertTable, addRowBefore, addRowAfter, deleteRow
    case addColumnBefore, addColumnAfter, deleteColumn, toggleHeaderRow, deleteTable
    case undo, redo, focus
    case navigateToHeading
}

extension Notification.Name {
    static let editorCommand = Notification.Name("PaperMD.editorCommand")
}

func performEditorCommand(_ command: EditorCommandName, payload: [String: String] = [:]) {
    NotificationCenter.default.post(
        name: .editorCommand,
        object: nil,
        userInfo: ["command": command.rawValue, "payload": payload]
    )
}
