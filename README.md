# Foco

Foco is a native macOS, document-based workspace inspired by Notion, with one important rule: **your work stays local**.

Every workspace is saved as a transferable `.bulb` document (for example, `Research.bulb`). A bulb contains its pages, writing, links, prompts, PDFs, videos, images, and other attachments. There is no account, server, sync engine, analytics SDK, or required internet connection.

## First milestone

This repository contains the first usable slice:

- Native SwiftUI macOS document app
- Create, open, and save `.bulb` documents
- Page hierarchy in the left sidebar
- Markdown-friendly document editor
- Type `/` to open the insert menu
- Insert headings, prompts, links, PDFs, videos, images, and files
- Assets are copied into the `.bulb`, so the document remains portable
- Images, PDFs, and videos are previewed directly on the page
- Videos use native playback controls and work completely offline
- Automatic local saves through the macOS document system

## How a vault works

A `.bulb` is a macOS package: it behaves like one document in Finder but internally uses a small, durable folder structure.

```text
Project.bulb/
├── document.json
└── Assets/
    ├── <asset-id>-brief.pdf
    └── <asset-id>-demo.mov
```

`document.json` stores pages and metadata. Binary files stay as binary files in `Assets`, rather than being embedded into JSON. This keeps large workspaces practical and makes the format inspectable and recoverable.

## Run

Open `Package.swift` in Xcode and run the `Foco` scheme, or use:

```bash
swift run Foco
```

The app requires macOS 14 or newer.

## Editing

- Choose a page in the sidebar.
- Write plain text or Markdown.
- Type `/` to open the block menu. Continue typing to filter it, then click a type to insert it.
- Attachments are page blocks backed by local files inside the vault. Images and PDFs render inline, videos have native playback controls, and other files show a local attachment card.

## Product principles

1. **Local first:** opening and editing never requires a network.
2. **One portable document:** moving a `.bulb` moves the whole workspace.
3. **Plain, durable content:** text remains readable even without Foco.
4. **Native behavior:** standard macOS documents, menus, keyboard navigation, autosave, and accessibility.
5. **Simple before clever:** no block database or collaboration layer until the core editor feels excellent.

## Next sensible steps

- Rich inline rendering for images, PDFs, and videos
- Drag-and-drop attachments
- Nested pages and sidebar reordering
- Search across a vault
- Backlinks and local graph
- Export to Markdown/PDF
- Optional user-owned sync via iCloud Drive, Dropbox, or any folder provider

## Privacy

Foco does not currently make network requests. URLs are stored as text and only open when the user chooses to open them.

Older `.vault` documents remain readable and can be saved back out as `.bulb` files.
