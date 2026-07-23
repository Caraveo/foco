# Foco

[![macOS](https://img.shields.io/badge/platform-macOS-blue.svg)](https://www.apple.com/macos/)
[![Swift](https://img.shields.io/badge/Swift-6.0-orange.svg)](https://swift.org/)
[![SwiftUI](https://img.shields.io/badge/SwiftUI-5.0-blue.svg)](https://developer.apple.com/xcode/swiftui/)
[![Version](https://img.shields.io/badge/version-0.2.2-blue.svg)](https://github.com/Caraveo/foco/releases)
[![Status](https://img.shields.io/badge/status-PREALPHA-red.svg)](https://github.com/Caraveo/foco)

Foco is a native macOS, document-based workspace inspired by Notion, with one important rule: **your work stays local**.

Every workspace is saved as a transferable `.bulb` document (for example, `Research.bulb`). A bulb contains its pages, writing, links, prompts, PDFs, videos, images, and other attachments. There is no account, server, sync engine, analytics SDK, or required internet connection.

## Two native apps

| App | Edition | Purpose |
| --- | --- | --- |
| **Foco** | Paid editor | Create, edit, organize, attach, and save `.bulb` documents. |
| **Foco View** | Free viewer | Open and read `.bulb` documents with inline PDF, image, video, and audio playback. It has no save or mutation path. |

Both apps work completely locally. Foco remains the owning macOS editor for `.bulb`; Foco View registers separately with the `Viewer` role so it appears in Finder’s **Open With** menu without replacing the editor.

A native Windows 11 reader is available in [`win11`](win11/README.md). It opens the same portable `.bulb` files read-only with a WinUI 3 interface.

## Release downloads

Version [`v0.2.2`](https://github.com/Caraveo/foco/releases) includes separate macOS archives for the editor and the free reader:

- `Foco-macOS-v0.2.2.zip` — the editable Foco document app.
- `Foco-View-macOS-v0.2.2.zip` — the read-only Foco View app.

Both require macOS 14 or newer. The release apps are ad-hoc signed for local distribution; macOS may require Control-click → **Open** the first time they are launched.

## What works today

This repository contains a working local-first prototype:

- Native SwiftUI macOS document app
- Create, open, and save `.bulb` documents
- Page hierarchy in the left sidebar
- Markdown-friendly document editor that starts at the top of the page
- Bottom-centered `/` menu that rises above the editor, with keyboard filtering and selection
- Insert headings, prompts, links, tables, Kanban boards, calendars, lists, galleries, timelines, PDFs, videos, audio, images, and files
- Fully editable table, Kanban, calendar, list, gallery, and timeline blocks with native controls
- Rendered dividers, code blocks, LaTeX formulas, quotes, prompts, and automatic clickable `http://` and `https://` links
- Clickable checklist items, editable table cells, movable Kanban cards, month navigation, gallery image previews, and dated timeline entries
- Automatic continuation for bulleted lists, numbered lists, checklists, quotes, and table rows
- Assets are copied into the `.bulb`, so the document remains portable
- Attachments are true inline blocks that can be dragged or moved up/down between text
- Images and PDFs are previewed directly on the page
- Video and audio use native playback controls and work completely offline
- Backspace/Delete and the attachment menu remove both the inline block and its stored archive file
- Drag files from Finder onto a page with automatic PDF, image, video, and audio detection
- Automatic local saves through the macOS document system

## How a bulb works

A `.bulb` is a real single file, not a Finder package or disguised folder. Internally it is a ZIP-compatible archive containing ordinary files.

```text
Project.bulb
├── manifest.json
├── Pages/
│   └── <page-id>.md
├── Blocks/
│   └── <block-id>.json
└── Assets/
    ├── <asset-id>-brief.pdf
    └── <asset-id>-demo.mov
```

Foco loads only `manifest.json` at open. It reads only the selected Markdown page and the structured blocks referenced by that page. An asset is extracted only when its preview appears. Videos, audio, PDFs, and images remain real files inside the archive and are never loaded into one large in-memory value.

Page text and metadata use normal ZIP compression. Media is stored without recompression because PDFs, images, audio, and videos are normally compressed already; recompressing would waste time or reduce quality.

## Run

For normal document creation, opening, and saving, install and launch the app bundle:

```bash
./Scripts/install-dev-app.sh
open ~/Applications/Foco.app
```

`swift run Foco` is useful for a quick UI build, but the raw SwiftPM executable has no app-bundle identity or document registration. Do not use that launch mode to test `.bulb` saving or Finder integration.

You can also open `Package.swift` in Xcode and run the `Foco` scheme for development.

The installer creates a signed local app bundle, declares `app.foco.bulb` as an editable document type, and registers Foco as its owner with Launch Services.

Build or install the free read-only viewer separately:

```bash
swift run FocoView
./Scripts/install-viewer-app.sh
open ~/Applications/Foco\ View.app
```

The viewer installs as `~/Applications/Foco View.app` with bundle identifier `app.foco.viewer`, a distinct icon, no Save command, and read-only `.bulb` registration.

The app requires macOS 14 or newer.

To build the same two release archives locally:

```bash
./Scripts/build-release.sh 0.0.1
```

## Editing

- Choose a page in the sidebar.
- Write plain text or Markdown.
- Type `/` to raise the block menu from the bottom center. Continue typing to filter it, use ↑/↓ to move, Return to insert, or Escape to close it. Mouse selection also works.
- Tables support editable rows, columns, headers, and cells. Boards support editable columns and movable cards. Calendars provide month navigation and timed events. Lists support search, tags, notes, completion, and reordering. Galleries store and preview local images. Timelines provide dated, sortable milestones.
- Move any structured block with its footer handle or arrow controls, or delete it from the same footer.
- Paste or type an `http://` or `https://` address to create a clickable link automatically.
- Drag one or several files anywhere over the workspace to attach them to the selected page; Foco detects their type from macOS metadata and filename extension.
- Move an attachment with its drag handle or arrow controls. Put the caret against an attachment and press Backspace/Delete to remove it.
- Attachments are real files inside the bulb archive. Images and PDFs render inline, video and audio have native playback controls, and other files show a local attachment card.

## Product principles

1. **Local first:** opening and editing never requires a network.
2. **One portable document:** moving a `.bulb` moves the whole workspace.
3. **Plain, durable content:** text remains readable even without Foco.
4. **Native behavior:** standard macOS documents, menus, keyboard navigation, autosave, and accessibility.
5. **Simple before clever:** structured blocks stay as small local JSON files inside the document; there is no server database or collaboration layer.

## Next sensible steps

- Nested pages and sidebar reordering
- Search across a vault
- Backlinks and local graph
- Export to Markdown/PDF
- Optional user-owned sync via iCloud Drive, Dropbox, or any folder provider

## Development checks

Build the app:

```bash
swift build -j 1
```

Verify that `.bulb` remains one ZIP-compatible file with ordinary page and media entries:

```bash
swiftc -parse-as-library \
  Sources/Foco/FocoTheme.swift Sources/Foco/StructuredBlocks.swift \
  Sources/Foco/VaultDocument.swift Tools/StorageSmoke.swift \
  -o /tmp/foco-storage-smoke \
  -framework SwiftUI -framework AppKit -framework UniformTypeIdentifiers -framework Combine
/tmp/foco-storage-smoke
```

Verify every structured block can be inserted in document order, saved independently, and reopened:

```bash
swiftc -parse-as-library \
  Sources/Foco/FocoTheme.swift Sources/Foco/StructuredBlocks.swift \
  Sources/Foco/VaultDocument.swift Tools/StructuredBlocksSmoke.swift \
  -o /tmp/foco-blocks-smoke \
  -framework SwiftUI -framework AppKit -framework UniformTypeIdentifiers -framework Combine
/tmp/foco-blocks-smoke
```

Verify that Foco View lazily reads the manifest, one page, and one asset without changing the source file:

```bash
swiftc -parse-as-library \
  Sources/Foco/FocoTheme.swift Sources/Foco/StructuredBlocks.swift Sources/Foco/VaultDocument.swift \
  Sources/FocoView/ViewerStructuredBlocks.swift Sources/FocoView/ViewerDocument.swift \
  Tools/ViewerSmoke.swift \
  -o /tmp/foco-viewer-smoke \
  -framework SwiftUI -framework AppKit -framework UniformTypeIdentifiers -framework Combine
/tmp/foco-viewer-smoke
```

## Privacy

Foco does not currently make network requests. URLs are stored as text and only open when the user chooses to open them.

Older `.vault` documents remain readable and can be saved back out as `.bulb` files.
