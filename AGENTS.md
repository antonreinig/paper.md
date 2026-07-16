# paper.md contributor guide

paper.md is an offline-first, Apple-Silicon macOS app for editing ordinary Markdown files.

## Product invariants

- Markdown on disk is the source of truth. Never introduce a proprietary document format.
- There is one WYSIWYG editing surface and no source-mode toggle.
- Local edits are saved automatically after a short debounce and flushed at least every 1.5 seconds.
- External file changes must be detected and must never be silently overwritten.
- The editor and Quick Look extension must not load remote scripts or telemetry.
- Preserve undo/redo, keyboard navigation, VoiceOver labels, and native macOS conventions.

## Build

```sh
./scripts/bootstrap.sh
./scripts/test.sh
```

`project.yml` is the source of truth for the generated Xcode project. Do not hand-edit `PaperMD.xcodeproj`.

## Verification

- Run `npm test` and `npm run build` in `Editor/` for editor changes.
- Run `xcodebuild test` through `./scripts/test.sh` for Swift changes.
- Add round-trip fixtures for Markdown serialization changes.
- Never commit signing credentials, notarization credentials, or generated dependency directories.
