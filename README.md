<div align="center">

# paper.md

### Markdown that feels like a document.

**A native macOS editor for ordinary Markdown files — WYSIWYG, autosaved, offline, and safe to use alongside AI tools.**

[![CI](https://github.com/antonreinig/paper.md/actions/workflows/ci.yml/badge.svg)](https://github.com/antonreinig/paper.md/actions/workflows/ci.yml)
![macOS 14+](https://img.shields.io/badge/macOS-14%2B-111111?logo=apple)
[![GPL-3.0-or-later](https://img.shields.io/badge/license-GPL--3.0--or--later-blue.svg)](LICENSE)

[Why paper.md](#why-papermd) · [Build](#build-and-run) · [How it works](#how-it-works) · [Contribute](#contributing)

</div>

---

Open a `.md` file and edit the formatted document directly. There is no source mode, preview pane, import step, account, or proprietary format — just the Markdown already on disk.

## Why paper.md

- **Edit the document, not its syntax.** Editorial headings, readable body text, syntax-highlighted code, lists, links, and tables look finished while you edit them.
- **Keep plain Markdown.** Files remain portable UTF-8 text and work with Git, scripts, and every other Markdown tool.
- **Work safely alongside AI.** Changes from Codex and other local tools appear automatically; overlapping edits are surfaced instead of silently overwritten.
- **Use a Mac app, not an IDE.** Browse compact folder trees and the open document’s H1 outline in a native sidebar, use standard shortcuts and undo, and preview files in Finder with Quick Look.
- **Stay private and offline.** No accounts, analytics, cloud services, remote scripts, or runtime network dependencies.

> **Early preview:** [Download paper.md 0.2.0](https://github.com/antonreinig/paper.md/releases/download/v0.2.0/paper.md-0.2.0.dmg) for Apple Silicon Macs running macOS 14 or newer.

## Build and run

Requires an Apple Silicon Mac with macOS 14+, Xcode 26+, Node.js 22+, and [XcodeGen](https://github.com/yonaskolb/XcodeGen).

```sh
./scripts/bootstrap.sh
open PaperMD.xcodeproj
```

Select the `PaperMD` scheme in Xcode and run it. To run all automated checks:

```sh
./scripts/test.sh
```

## How it works

Markdown on disk is always the source of truth. paper.md continuously saves local edits and watches the open file for external changes. Non-overlapping changes are merged; conflicts are shown so neither version disappears.

The app uses SwiftUI and AppKit, with a local `WKWebView` hosting Tiptap/ProseMirror. Swift handles files, workspace observation, atomic saves, conflict protection, native commands, and Quick Look. All JavaScript is bundled with the app and the editor loads no remote content.

See [the architecture documentation](docs/architecture.md) and [Markdown compatibility notes](docs/markdown-compatibility.md) for details.

## Contributing

Ideas, bug reports, design feedback, and code contributions are welcome. Please preserve the central principle: Markdown should feel like a document while remaining ordinary Markdown on disk.

## License

paper.md is free and open-source software licensed under [GPL-3.0-or-later](LICENSE).
