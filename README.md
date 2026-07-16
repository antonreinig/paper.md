<div align="center">

# paper.md

### Markdown that behaves like a document.

**Open, read, and edit Markdown without source code, preview modes, or an IDE.**

[![CI](https://github.com/antonreinig/paper.md/actions/workflows/ci.yml/badge.svg)](https://github.com/antonreinig/paper.md/actions/workflows/ci.yml)
![macOS 14+](https://img.shields.io/badge/macOS-14%2B-111111?logo=apple)
[![GPL-3.0-or-later](https://img.shields.io/badge/license-GPL--3.0--or--later-blue.svg)](LICENSE)

[Features](#what-makes-papermd-different) · [Who it is for](#who-papermd-is-for) · [Build it](#build-it-yourself) · [Contribute](#contributing)

</div>

---

Markdown is one of the most portable document formats we have, yet opening a `.md` file still often feels like opening source code. Most tools make you edit raw syntax or switch between an editor and a separate preview.

paper.md takes a document-first approach. Open a Markdown file and it is already beautifully rendered, immediately editable, and continuously saved as ordinary Markdown. Click anywhere and write, just as you would in a familiar document app.

> **Markdown is a file format, not a user interface.**

## What makes paper.md different

| The usual Markdown workflow | The paper.md workflow |
| --- | --- |
| Open raw source | Open a formatted document |
| Switch to preview to read | Read and edit in the same surface |
| See Markdown punctuation while writing | Use true WYSIWYG formatting |
| Remember to save | Changes are saved continuously |
| Manually reload AI-generated updates | External changes appear automatically |
| Open an IDE for a folder of docs | Browse the folder in a calm, native Mac app |

paper.md is built around a few simple promises:

- **True WYSIWYG editing.** Headings, lists, emphasis, links, code, and tables look like the finished document while you edit them.
- **Plain Markdown underneath.** Your files remain readable, portable UTF-8 Markdown with no proprietary database or lock-in.
- **Made for AI collaboration.** Local changes are saved after a short debounce, while edits from AI agents and other processes are detected and reloaded without silently overwriting your work.
- **Workspace navigation.** Open a project folder and browse its Markdown documents in a familiar sidebar.
- **Tables without the syntax puzzle.** Add and remove rows or columns directly from the document.
- **Native macOS behavior.** Standard keyboard shortcuts, undo and redo, file associations, and Finder Quick Look previews are part of the experience.
- **Private and offline.** There are no accounts, analytics, remote scripts, cloud services, or runtime network dependencies.

## Who paper.md is for

paper.md is for people who work with Markdown documents but do not want a developer tool between them and the content:

- **Product managers** reviewing PRDs, specs, RFCs, meeting notes, and changelogs.
- **Designers and researchers** working with design documentation, research notes, and AI-generated deliverables.
- **Founders and AI power users** whose agents produce folders full of plans, reports, and working documents.
- **Writers and technical collaborators** who value open files but prefer a direct, document-like editing experience.

It is especially useful when an AI creates most of a document and a person wants to read it, correct a sentence, adjust a table, or continue writing without dropping into Markdown syntax.

## AI and human, working on the same file

The Markdown file on disk is always the source of truth. paper.md saves your typing continuously and watches the open document for changes from tools such as Codex or other local agents. Non-overlapping updates are merged; overlapping edits are surfaced as a conflict so neither version disappears.

There is no import step, sync service, or special document format. The AI and paper.md simply work with the same file.

## Current status

paper.md is an early open-source macOS project. The current MVP includes:

- native folder and file navigation
- WYSIWYG Markdown editing
- table row and column controls
- live atomic saving
- external-change detection and conflict protection
- Finder Quick Look previews
- undo, redo, and standard formatting shortcuts

## Build it yourself

### Requirements

- Apple Silicon Mac
- macOS 14 or newer
- Xcode 26 or newer
- Node.js 22 or newer
- [XcodeGen](https://github.com/yonaskolb/XcodeGen)

### Build and run

```sh
./scripts/bootstrap.sh
open PaperMD.xcodeproj
```

In Xcode, select the `PaperMD` scheme and run it. Run all automated checks with:

```sh
./scripts/test.sh
```

## How it works

The native shell is built with SwiftUI and AppKit. A local `WKWebView` hosts the open-source Tiptap/ProseMirror editing engine. Swift owns filesystem access, workspace observation, atomic persistence, conflict handling, native commands, and Quick Look. All JavaScript is compiled into the app; the editing surface loads no remote content.

The Developer ID build uses Hardened Runtime without App Sandbox so paper.md can work naturally with repository-style folders. The Quick Look extension remains sandboxed. Runtime networking is disabled by the editor's Content Security Policy, and the app contains no network client code.

Read more in [the architecture documentation](docs/architecture.md).

## Contributing

Ideas, bug reports, design feedback, and code contributions are welcome. Please keep the central product principle intact: Markdown should feel like a document while remaining ordinary Markdown on disk.

## License

paper.md is free and open-source software licensed under [GPL-3.0-or-later](LICENSE).
