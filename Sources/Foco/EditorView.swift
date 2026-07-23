import AppKit
import SwiftUI
import UniformTypeIdentifiers

enum InsertKind: String, CaseIterable, Identifiable {
    case text, heading1, heading2, bulletedList, numberedList, todo, quote, divider, code, formula, prompt, url
    case table, board, calendar, listView, gallery, timeline
    case pdf, image, video, audio, file

    var id: String { rawValue }
    var label: String {
        switch self {
        case .text: "Text"
        case .heading1: "Heading 1"
        case .heading2: "Heading 2"
        case .bulletedList: "Bulleted list"
        case .numberedList: "Numbered list"
        case .todo: "To-do list"
        case .quote: "Quote"
        case .divider: "Divider"
        case .code: "Code"
        case .formula: "Formula"
        case .prompt: "Prompt"
        case .url: "Web link"
        case .table: "Table"
        case .board: "Board / Kanban"
        case .calendar: "Calendar"
        case .listView: "List"
        case .gallery: "Gallery"
        case .timeline: "Timeline"
        case .pdf: "PDF"
        case .image: "Image"
        case .video: "Video"
        case .audio: "Audio"
        case .file: "File"
        }
    }
    var detail: String {
        switch self {
        case .text: "Start writing with plain text"
        case .heading1: "Large section heading"
        case .heading2: "Medium section heading"
        case .bulletedList: "Create a simple bulleted list"
        case .numberedList: "Create a numbered list"
        case .todo: "Track a task with a checkbox"
        case .quote: "Capture a quotation"
        case .divider: "Visually divide your page"
        case .code: "Add a code block"
        case .formula: "Write a LaTeX equation"
        case .prompt: "Save an AI prompt locally"
        case .url: "Bookmark a website"
        case .table: "Organize information in rows"
        case .board: "Track work across Kanban columns"
        case .calendar: "Plan events by date"
        case .listView: "Create a compact item view"
        case .gallery: "Start a visual collection"
        case .timeline: "Map milestones over time"
        case .pdf: "Attach a portable document"
        case .image: "Attach a photo or graphic"
        case .video: "Attach a local video"
        case .audio: "Attach playable local audio"
        case .file: "Attach any local file"
        }
    }
    var icon: String {
        switch self {
        case .text: "text.alignleft"
        case .heading1, .heading2: "textformat.size"
        case .bulletedList: "list.bullet"
        case .numberedList: "list.number"
        case .todo: "checkmark.square"
        case .quote: "quote.opening"
        case .divider: "minus"
        case .code: "chevron.left.forwardslash.chevron.right"
        case .formula: "function"
        case .prompt: "sparkles"
        case .url: "link"
        case .table: "tablecells"
        case .board: "rectangle.split.3x1"
        case .calendar: "calendar"
        case .listView: "list.bullet.rectangle"
        case .gallery: "rectangle.grid.2x2"
        case .timeline: "point.topleft.down.to.point.bottomright.curvepath"
        case .pdf: "doc.richtext"
        case .image: "photo"
        case .video: "play.rectangle"
        case .audio: "waveform"
        case .file: "paperclip"
        }
    }
    var needsFile: Bool { [.pdf, .image, .video, .audio, .file].contains(self) }
    var isView: Bool { [.table, .board, .calendar, .listView, .gallery, .timeline].contains(self) }
    var isMedia: Bool { needsFile }
    var structuredKind: FocoStructuredBlockKind? {
        switch self {
        case .table: .table
        case .board: .board
        case .calendar: .calendar
        case .listView: .list
        case .gallery: .gallery
        case .timeline: .timeline
        default: nil
        }
    }

    static func matches(_ query: String) -> [InsertKind] {
        query.isEmpty ? allCases : allCases.filter {
            $0.label.localizedCaseInsensitiveContains(query) ||
            $0.detail.localizedCaseInsensitiveContains(query)
        }
    }

    static func detected(for url: URL) -> InsertKind {
        let fileExtension = url.pathExtension.lowercased()
        let contentType = (try? url.resourceValues(forKeys: [.contentTypeKey]).contentType)
            ?? UTType(filenameExtension: fileExtension)

        if contentType?.conforms(to: .pdf) == true || fileExtension == "pdf" { return .pdf }
        if contentType?.conforms(to: .image) == true || imageExtensions.contains(fileExtension) { return .image }
        if contentType?.conforms(to: .audio) == true || audioExtensions.contains(fileExtension) { return .audio }
        if contentType?.conforms(to: .movie) == true || contentType?.conforms(to: .video) == true || videoExtensions.contains(fileExtension) { return .video }
        return .file
    }

    private static let imageExtensions: Set<String> = ["png", "jpg", "jpeg", "gif", "heic", "heif", "webp", "tif", "tiff", "bmp", "svg"]
    private static let audioExtensions: Set<String> = ["mp3", "m4a", "aac", "wav", "aiff", "aif", "flac", "ogg", "opus"]
    private static let videoExtensions: Set<String> = ["mov", "mp4", "m4v", "avi", "mkv", "webm", "mpeg", "mpg"]
}

struct EditorView: View {
    @Binding var page: VaultPage
    let assets: [VaultAsset]
    let assetURL: @Sendable (VaultAsset) -> URL?
    let onInsertAsset: (InsertKind, Int) -> Void
    let onImportEmbeddedAsset: @MainActor (URL) async -> VaultAsset?
    let onDeleteAsset: (VaultAsset) -> Void
    @State private var slashQuery: String?
    @State private var selectedRange = NSRange(location: 0, length: 0)
    @State private var slashSelection = 0
    @State private var editorHeight: CGFloat = 180
    @State private var showingWritingContext = false
    @AppStorage("foco.manuscriptTheme") private var manuscriptTheme = "system"

    var body: some View {
        GeometryReader { _ in
          ZStack(alignment: .bottom) {
            VStack(spacing: 0) {
                ScrollView {
                    VStack(alignment: .leading, spacing: 0) {
                        Spacer().frame(height: 34)

                        TextField("Untitled", text: $page.title)
                            .textFieldStyle(.plain)
                            .font(.system(size: 40, weight: .bold, design: .default))
                            .tracking(-1.1)
                            .padding(.bottom, 8)

                        HStack(spacing: 6) {
                            Image(systemName: "folder")
                                .font(.system(size: 12))
                                .foregroundStyle(.secondary)
                            Text("Category:")
                                .font(.system(size: 12))
                                .foregroundStyle(.secondary)
                            TextField("General", text: Binding(
                                get: { page.category ?? "" },
                                set: { page.category = $0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : $0 }
                            ))
                            .textFieldStyle(.plain)
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(.primary)
                            .frame(width: 150)
                            
                            Spacer()

                            Text("\(wordCount) words")
                                .font(.system(size: 11))
                                .foregroundStyle(.tertiary)
                            Button("Context") { showingWritingContext = true }
                                .buttonStyle(.borderless)
                            Picker("Manuscript theme", selection: $manuscriptTheme) {
                                Text("System").tag("system")
                                Text("Light").tag("light")
                                Text("Dark").tag("dark")
                            }
                            .labelsHidden()
                            .frame(width: 82)
                            
                            Text("Saved in this vault")
                                .font(.system(size: 11))
                                .foregroundStyle(.tertiary)
                        }
                        .padding(.bottom, 25)

                        ZStack(alignment: .topLeading) {
                            if page.content.isEmpty {
                                Text("Type ‘/’ for commands, or just start writing…")
                                    .font(.custom("Courier", size: 16))
                                    .foregroundStyle(.tertiary)
                                    .padding(.top, 1)
                                    .allowsHitTesting(false)
                            }
                            RichTextEditor(
                                text: $page.content,
                                writingContext: page.writingContext ?? "",
                                slashQuery: $slashQuery,
                                selectedRange: $selectedRange,
                                editorHeight: $editorHeight,
                                assets: referencedAssets,
                                blocks: page.blocks ?? [],
                                assetURL: assetURL,
                                onImportEmbeddedAsset: onImportEmbeddedAsset,
                                onDeleteAsset: deleteAsset,
                                onUpdateStructuredBlock: updateStructuredBlock,
                                onDeleteStructuredBlock: deleteStructuredBlock,
                                onMoveStructuredBlock: { blockID, offset in
                                    moveStructuredBlock(blockID, toUTF16Offset: offset)
                                },
                                onMoveStructuredBlockBy: { blockID, direction in
                                    moveStructuredBlock(blockID, by: direction)
                                },
                                onMoveAsset: { assetID, offset in
                                    moveAsset(assetID, toUTF16Offset: offset)
                                },
                                onMoveAssetBy: { assetID, direction in
                                    moveAsset(assetID, by: direction)
                                },
                                onSlashKey: handleSlashKey
                            )
                                .frame(height: editorHeight)
                        }
                        .frame(maxWidth: .infinity, alignment: .topLeading)

                        Spacer().frame(height: 160)
                    }
                    .frame(maxWidth: 720, alignment: .leading)
                    .padding(.horizontal, 64)
                    .frame(maxWidth: .infinity)
                }
                .scrollIndicators(.hidden)
            }

            if let query = slashQuery {
                SlashMenu(query: query, selectedIndex: $slashSelection, insert: insert)
                    .padding(.bottom, 28)
                    .transition(
                        .opacity
                            .combined(with: .move(edge: .bottom))
                            .combined(with: .scale(scale: 0.96, anchor: .bottom))
                    )
                    .zIndex(10)
            }
          }
        }
        .background(FocoTheme.canvas)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .animation(.spring(response: 0.22, dampingFraction: 0.88), value: slashQuery != nil)
        .onChange(of: slashQuery) { _, _ in slashSelection = 0 }
        .preferredColorScheme(manuscriptTheme == "system" ? nil : manuscriptTheme == "dark" ? .dark : .light)
        .sheet(isPresented: $showingWritingContext) {
            PageWritingContextSheet(context: Binding(get: { page.writingContext ?? "" }, set: { page.writingContext = $0.isEmpty ? nil : $0 }))
        }
    }

    private var referencedAssets: [VaultAsset] {
        let explicitIDs = page.assetIDs ?? []
        var result = explicitIDs.compactMap { id in assets.first { $0.id == id } }
        // Read the token format used by the earliest vault version as a migration path.
        for asset in assets where page.content.contains("[[asset:\(asset.id.uuidString)|") && !result.contains(asset) {
            result.append(asset)
        }
        return result
    }

    private var wordCount: Int {
        page.content.split(whereSeparator: { $0.isWhitespace || $0.isNewline }).count
    }

    private func insert(_ kind: InsertKind) {
        let queryLength = (slashQuery ?? "").utf16.count + 1
        let insertionLocation = max(0, selectedRange.location - queryLength)
        let replacementRange = NSRange(location: insertionLocation, length: min(queryLength, max(0, page.content.utf16.count - insertionLocation)))
        slashQuery = nil
        if kind.needsFile {
            page.content = (page.content as NSString).replacingCharacters(in: replacementRange, with: "")
            selectedRange = NSRange(location: insertionLocation, length: 0)
            onInsertAsset(kind, insertionLocation)
            return
        }
        if let structuredKind = kind.structuredKind {
            let block = FocoStructuredBlock(kind: structuredKind)
            var blocks = page.blocks ?? []
            blocks.append(block)
            page.blocks = blocks
            page.blockIDs = blocks.map(\.id)
            let result = FocoStructuredBlockSyntax.inserting(
                block,
                into: page.content,
                replacing: replacementRange
            )
            page.content = result.content
            selectedRange = NSRange(location: result.cursor, length: 0)
            return
        }
        let value: String
        switch kind {
        case .text: value = ""
        case .heading1: value = "# "
        case .heading2: value = "## "
        case .bulletedList: value = "- "
        case .numberedList: value = "1. "
        case .todo: value = "☐ "
        case .quote: value = "> "
        case .divider: value = "---\n"
        case .code: value = "```\nCode\n```"
        case .formula: value = "$$\nE = mc^2\n$$"
        case .prompt: value = "> Prompt: "
        case .url: value = "https://"
        case .table, .board, .calendar, .listView, .gallery, .timeline: return
        default: return
        }
        page.content = (page.content as NSString).replacingCharacters(in: replacementRange, with: value)
        selectedRange = NSRange(location: insertionLocation + value.utf16.count, length: 0)
    }

    private func deleteAsset(_ assetID: UUID) {
        guard let asset = assets.first(where: { $0.id == assetID }) else { return }
        page.content = AssetBlockSyntax.removing(assetID, from: page.content)
        onDeleteAsset(asset)
    }

    private func updateStructuredBlock(_ block: FocoStructuredBlock) {
        var blocks = page.blocks ?? []
        if let index = blocks.firstIndex(where: { $0.id == block.id }) {
            blocks[index] = block
        } else {
            blocks.append(block)
        }
        page.blocks = blocks
        page.blockIDs = blocks.map(\.id)
    }

    /// The text view has already removed the fixed ordering token when this is
    /// called. Remove the separate JSON model and any gallery-owned media.
    private func deleteStructuredBlock(_ block: FocoStructuredBlock) {
        page.blocks?.removeAll { $0.id == block.id }
        page.blockIDs = page.blocks?.map(\.id) ?? []
        for assetID in block.referencedAssetIDs {
            guard let asset = assets.first(where: { $0.id == assetID }) else { continue }
            onDeleteAsset(asset)
        }
    }

    private func moveAsset(_ assetID: UUID, by direction: Int) {
        var lines = page.content.components(separatedBy: "\n")
        guard let index = lines.firstIndex(where: { line in
            AssetBlockSyntax.matches(in: line).contains { $0.assetID == assetID }
        }) else { return }

        if direction < 0 {
            var target = index - 1
            while target >= 0 && lines[target].trimmingCharacters(in: .whitespaces).isEmpty { target -= 1 }
            guard target >= 0 else { return }
            let block = lines.remove(at: index)
            lines.insert(block, at: target)
        } else {
            var target = index + 1
            while target < lines.count && lines[target].trimmingCharacters(in: .whitespaces).isEmpty { target += 1 }
            guard target < lines.count else { return }
            let block = lines.remove(at: index)
            let adjustedTarget = target > index ? target - 1 : target
            lines.insert(block, at: min(lines.count, adjustedTarget + 1))
        }
        page.content = lines.joined(separator: "\n")
    }

    private func moveAsset(_ assetID: UUID, toUTF16Offset offset: Int) {
        var lines = page.content.components(separatedBy: "\n")
        guard let sourceIndex = lines.firstIndex(where: { line in
            AssetBlockSyntax.matches(in: line).contains { $0.assetID == assetID }
        }) else { return }

        let source = page.content as NSString
        let safeOffset = min(max(0, offset), source.length)
        let prefix = source.substring(to: safeOffset)
        var targetIndex = prefix.reduce(into: 0) { count, character in
            if character == "\n" { count += 1 }
        }
        let block = lines.remove(at: sourceIndex)
        if sourceIndex < targetIndex { targetIndex -= 1 }
        targetIndex = min(max(0, targetIndex), lines.count)
        lines.insert(block, at: targetIndex)
        page.content = lines.joined(separator: "\n")
    }

    private func moveStructuredBlock(_ blockID: UUID, by direction: Int) {
        var lines = page.content.components(separatedBy: "\n")
        guard let index = lines.firstIndex(where: { line in
            FocoStructuredBlockSyntax.matches(in: line).contains { $0.id == blockID }
        }) else { return }

        if direction < 0 {
            var target = index - 1
            while target >= 0 && lines[target].trimmingCharacters(in: .whitespaces).isEmpty { target -= 1 }
            guard target >= 0 else { return }
            let block = lines.remove(at: index)
            lines.insert(block, at: target)
        } else {
            var target = index + 1
            while target < lines.count && lines[target].trimmingCharacters(in: .whitespaces).isEmpty { target += 1 }
            guard target < lines.count else { return }
            let block = lines.remove(at: index)
            let adjustedTarget = target > index ? target - 1 : target
            lines.insert(block, at: min(lines.count, adjustedTarget + 1))
        }
        page.content = lines.joined(separator: "\n")
    }

    private func moveStructuredBlock(_ blockID: UUID, toUTF16Offset offset: Int) {
        var lines = page.content.components(separatedBy: "\n")
        guard let sourceIndex = lines.firstIndex(where: { line in
            FocoStructuredBlockSyntax.matches(in: line).contains { $0.id == blockID }
        }) else { return }

        let source = page.content as NSString
        let safeOffset = min(max(0, offset), source.length)
        let prefix = source.substring(to: safeOffset)
        var targetIndex = prefix.reduce(into: 0) { count, character in
            if character == "\n" { count += 1 }
        }
        let block = lines.remove(at: sourceIndex)
        if sourceIndex < targetIndex { targetIndex -= 1 }
        targetIndex = min(max(0, targetIndex), lines.count)
        lines.insert(block, at: targetIndex)
        page.content = lines.joined(separator: "\n")
    }

    private func handleSlashKey(_ key: SlashKey) {
        guard let query = slashQuery else { return }
        let matches = InsertKind.matches(query)
        switch key {
        case .escape:
            slashQuery = nil
        case .up:
            guard !matches.isEmpty else { return }
            slashSelection = (slashSelection - 1 + matches.count) % matches.count
        case .down:
            guard !matches.isEmpty else { return }
            slashSelection = (slashSelection + 1) % matches.count
        case .commit:
            guard matches.indices.contains(slashSelection) else { return }
            insert(matches[slashSelection])
        }
    }
}

private struct SlashMenu: View {
    let query: String
    @Binding var selectedIndex: Int
    let insert: (InsertKind) -> Void
    private var matches: [InsertKind] { InsertKind.matches(query) }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text(query.isEmpty ? "Add a block" : "Results for “\(query)”")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.secondary)
                Spacer()
                Text("ESC")
                    .font(.system(size: 9, weight: .medium))
                    .foregroundStyle(.tertiary)
                    .padding(.horizontal, 5)
                    .padding(.vertical, 3)
                    .background(FocoTheme.hover, in: RoundedRectangle(cornerRadius: 4))
            }
            .padding(.horizontal, 12)
            .padding(.top, 11)
            .padding(.bottom, 7)

            if matches.isEmpty {
                Text("No matching blocks")
                    .font(.system(size: 13))
                    .foregroundStyle(.secondary)
                    .padding(14)
            } else {
                ScrollViewReader { proxy in
                    ScrollView {
                        LazyVStack(alignment: .leading, spacing: 1) {
                            ForEach(Array(matches.enumerated()), id: \.element.id) { index, kind in
                            if kind == matches.first(where: { !$0.isView && !$0.isMedia }) {
                                menuLabel("BASIC BLOCKS")
                            }
                            if kind == matches.first(where: { $0.isView }) {
                                menuLabel("VIEWS")
                            }
                            if kind == matches.first(where: { $0.isMedia }) {
                                menuLabel("MEDIA & FILES")
                            }
                                SlashMenuRow(kind: kind, selected: index == selectedIndex) { insert(kind) }
                                    .id(index)
                            }
                        }
                        .padding(.horizontal, 5)
                        .padding(.bottom, 6)
                    }
                    .frame(maxHeight: 430)
                    .onChange(of: selectedIndex) { _, index in
                        withAnimation(.easeOut(duration: 0.1)) {
                            proxy.scrollTo(index, anchor: .center)
                        }
                    }
                }
            }
        }
        .frame(width: 326)
        .background(.thickMaterial, in: RoundedRectangle(cornerRadius: 12))
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.primary.opacity(0.10)))
        .shadow(color: .black.opacity(0.18), radius: 24, y: 10)
    }

    private func menuLabel(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 9, weight: .semibold))
            .tracking(0.5)
            .foregroundStyle(.tertiary)
            .padding(.horizontal, 8)
            .padding(.top, 10)
            .padding(.bottom, 4)
    }
}

private struct SlashMenuRow: View {
    let kind: InsertKind
    let selected: Bool
    let action: () -> Void
    @State private var hovered = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: 11) {
                Image(systemName: kind.icon)
                    .font(.system(size: 15))
                    .frame(width: 34, height: 34)
                    .background(Color.primary.opacity(0.045), in: RoundedRectangle(cornerRadius: 7))
                    .overlay(RoundedRectangle(cornerRadius: 7).stroke(Color.primary.opacity(0.06)))
                VStack(alignment: .leading, spacing: 2) {
                    Text(kind.label).font(.system(size: 13, weight: .medium))
                    Text(kind.detail).font(.system(size: 11)).foregroundStyle(.secondary).lineLimit(1)
                }
                Spacer()
            }
            .padding(.horizontal, 7)
            .frame(height: 47)
            .contentShape(Rectangle())
            .background(selected || hovered ? FocoTheme.hover : .clear, in: RoundedRectangle(cornerRadius: 7))
        }
        .buttonStyle(.plain)
        .onHover { hovered = $0 }
    }
}

private enum SlashKey {
    case up, down, commit, escape
}

private struct PageWritingContextSheet: View {
    @Binding var context: String
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Page Writing Context").font(.title2.weight(.semibold))
            Text("Describe the work, scene, voice, POV, characters, and constraints. Foco sends this compact brief with this page’s AI requests.").foregroundStyle(.secondary)
            TextEditor(text: $context).font(.custom("Courier", size: 14)).frame(minHeight: 180)
                .overlay(RoundedRectangle(cornerRadius: 6).stroke(.quaternary))
            HStack { Spacer(); Button("Done") { dismiss() }.keyboardShortcut(.defaultAction) }
        }
        .padding(20).frame(width: 560, height: 320)
    }
}

private final class FocoTextView: NSTextView {
    var slashMenuVisible: (() -> Bool)?
    var onSlashKey: ((SlashKey) -> Void)?
    var onDeleteAsset: ((UUID) -> Void)?
    var onMoveAsset: ((UUID, Int) -> Void)?
    var onMoveAssetBy: ((UUID, Int) -> Void)?
    var onUpdateStructuredBlock: ((FocoStructuredBlock) -> Void)?
    var onDeleteStructuredBlock: ((FocoStructuredBlock) -> Void)?
    var onMoveStructuredBlock: ((UUID, Int) -> Void)?
    var onMoveStructuredBlockBy: ((UUID, Int) -> Void)?
    var onAcceptPrediction: (() -> Void)?
    var onDismissPrediction: (() -> Void)?
    private var ghostSuggestion: String?
    private var inlineAssetViews: [UUID: NSHostingView<AnyView>] = [:]
    private var inlineAssets: [UUID: VaultAsset] = [:]
    private var inlineBlockViews: [UUID: NSHostingView<AnyView>] = [:]
    private var inlineBlockStores: [UUID: FocoStructuredBlockStore] = [:]
    private var dragInsertionIndex: Int?

    func configureInlineAssets(
        _ assets: [VaultAsset],
        assetURL: @escaping @Sendable (VaultAsset) -> URL?
    ) {
        inlineAssets = Dictionary(uniqueKeysWithValues: assets.map { ($0.id, $0) })
        let desiredIDs = Set(assets.map(\.id))
        let staleIDs = inlineAssetViews.keys.filter { !desiredIDs.contains($0) }
        for id in staleIDs {
            inlineAssetViews[id]?.removeFromSuperview()
            inlineAssetViews[id] = nil
        }
        for asset in assets where inlineAssetViews[asset.id] == nil {
            let hostedView = NSHostingView(rootView: AnyView(
                AssetPreviewCard(
                    asset: asset,
                    materialize: { assetURL(asset) },
                    onDelete: { [weak self] in self?.onDeleteAsset?(asset.id) },
                    onMoveUp: { [weak self] in self?.onMoveAssetBy?(asset.id, -1) },
                    onMoveDown: { [weak self] in self?.onMoveAssetBy?(asset.id, 1) },
                    dragProvider: {
                        NSItemProvider(object: "foco-asset:\(asset.id.uuidString)" as NSString)
                    }
                )
            ))
            hostedView.wantsLayer = true
            hostedView.layer?.cornerRadius = 10
            addSubview(hostedView)
            inlineAssetViews[asset.id] = hostedView
        }
        needsLayout = true
    }

    func configureInlineStructuredBlocks(
        _ blocks: [FocoStructuredBlock],
        assets: [VaultAsset],
        assetURL: @escaping @Sendable (VaultAsset) -> URL?,
        importImage: @escaping @MainActor (URL) async -> VaultAsset?
    ) {
        let desiredIDs = Set(blocks.map(\.id))
        let staleIDs = inlineBlockViews.keys.filter { !desiredIDs.contains($0) }
        for id in staleIDs {
            inlineBlockViews[id]?.removeFromSuperview()
            inlineBlockViews[id] = nil
            inlineBlockStores[id] = nil
        }

        for block in blocks {
            if let store = inlineBlockStores[block.id] {
                store.configure(
                    block: block,
                    assets: assets,
                    materialize: assetURL,
                    importImage: importImage
                )
                continue
            }

            let store = FocoStructuredBlockStore(
                block: block,
                assets: assets,
                materialize: assetURL,
                importImage: importImage,
                onChange: { [weak self] updated in self?.onUpdateStructuredBlock?(updated) },
                onDeleteBlock: { [weak self] id in self?.deleteStructuredBlock(id) },
                onMoveBlock: { [weak self] id, direction in self?.onMoveStructuredBlockBy?(id, direction) },
                onDeleteAsset: { [weak self] id in self?.onDeleteAsset?(id) }
            )
            let hostedView = NSHostingView(rootView: AnyView(FocoStructuredBlockEditor(store: store)))
            hostedView.wantsLayer = true
            hostedView.layer?.cornerRadius = 12
            addSubview(hostedView)
            inlineBlockStores[block.id] = store
            inlineBlockViews[block.id] = hostedView
        }
        needsLayout = true
    }

    override func keyDown(with event: NSEvent) {
        if ghostSuggestion != nil {
            if event.keyCode == 48 { onAcceptPrediction?(); return }
            if event.keyCode == 53 { onDismissPrediction?(); return }
            if event.modifierFlags.intersection(.deviceIndependentFlagsMask).isEmpty { onDismissPrediction?() }
        }
        if slashMenuVisible?() == true {
            let key: SlashKey?
            switch event.keyCode {
            case 53: key = .escape
            case 126: key = .up
            case 125: key = .down
            case 36, 76: key = .commit
            default: key = nil
            }
            if let key {
                onSlashKey?(key)
                return
            }
        }
        super.keyDown(with: event)
    }

    func setGhostSuggestion(_ value: String?) {
        ghostSuggestion = value?.isEmpty == false ? value : nil
        needsDisplay = true
    }

    private func drawGhostSuggestion() {
        guard let ghostSuggestion, !ghostSuggestion.isEmpty, selectedRange().length == 0,
              let layoutManager, let textContainer else { return }
        let character = min(selectedRange().location, string.utf16.count)
        let glyphRange = layoutManager.glyphRange(forCharacterRange: NSRange(location: 0, length: character), actualCharacterRange: nil)
        let insertionPoint: NSPoint
        if glyphRange.length > 0 {
            let lastGlyph = glyphRange.location + glyphRange.length - 1
            let rect = layoutManager.boundingRect(forGlyphRange: NSRange(location: lastGlyph, length: 1), in: textContainer)
            insertionPoint = NSPoint(x: textContainerOrigin.x + rect.maxX, y: textContainerOrigin.y + rect.minY)
        } else {
            insertionPoint = textContainerOrigin
        }
        let attributes: [NSAttributedString.Key: Any] = [
            .font: NSFont(name: "Courier", size: 16) ?? .monospacedSystemFont(ofSize: 16, weight: .regular),
            .foregroundColor: NSColor.tertiaryLabelColor
        ]
        (ghostSuggestion as NSString).draw(at: insertionPoint, withAttributes: attributes)
    }

    override func insertNewline(_ sender: Any?) {
        guard selectedRange().length == 0, let continuation = lineContinuation() else {
            super.insertNewline(sender)
            return
        }
        insertText("\n\(continuation)", replacementRange: selectedRange())
    }

    override func deleteBackward(_ sender: Any?) {
        guard !deleteAdjacentStructuredBlock(backward: true) else { return }
        guard !deleteAdjacentAsset(backward: true) else { return }
        super.deleteBackward(sender)
    }

    override func deleteForward(_ sender: Any?) {
        guard !deleteAdjacentStructuredBlock(backward: false) else { return }
        guard !deleteAdjacentAsset(backward: false) else { return }
        super.deleteForward(sender)
    }

    override func cut(_ sender: Any?) {
        let matches = assetMatches(intersecting: selectedRange())
        let blockMatches = structuredMatches(intersecting: selectedRange())
        let removedBlocks = blockMatches.compactMap { inlineBlockStores[$0.id]?.block }
        if !matches.isEmpty || !blockMatches.isEmpty {
            let ranges = matches.map(\.lineRange) + blockMatches.map(\.lineRange)
            setSelectedRange(ranges.reduce(selectedRange(), NSUnionRange))
        }
        super.cut(sender)
        matches.forEach { onDeleteAsset?($0.assetID) }
        removedBlocks.forEach { onDeleteStructuredBlock?($0) }
    }

    override func paste(_ sender: Any?) {
        let matches = assetMatches(intersecting: selectedRange())
        let blockMatches = structuredMatches(intersecting: selectedRange())
        let removedBlocks = blockMatches.compactMap { inlineBlockStores[$0.id]?.block }
        if !matches.isEmpty || !blockMatches.isEmpty {
            let ranges = matches.map(\.lineRange) + blockMatches.map(\.lineRange)
            setSelectedRange(ranges.reduce(selectedRange(), NSUnionRange))
        }
        super.paste(sender)
        matches.forEach { onDeleteAsset?($0.assetID) }
        removedBlocks.forEach { onDeleteStructuredBlock?($0) }
    }

    override func layout() {
        super.layout()
        layoutInlineAssetViews()
        layoutInlineStructuredBlockViews()
    }

    override func draw(_ dirtyRect: NSRect) {
        drawBlockDecorations()
        super.draw(dirtyRect)
        drawDragInsertionIndicator()
        drawGhostSuggestion()
    }

    override func draggingEntered(_ sender: any NSDraggingInfo) -> NSDragOperation {
        draggedAssetID(from: sender) == nil && draggedStructuredBlockID(from: sender) == nil
            ? super.draggingEntered(sender)
            : .move
    }

    override func draggingUpdated(_ sender: any NSDraggingInfo) -> NSDragOperation {
        guard draggedAssetID(from: sender) != nil || draggedStructuredBlockID(from: sender) != nil else {
            return super.draggingUpdated(sender)
        }
        let point = convert(sender.draggingLocation, from: nil)
        dragInsertionIndex = characterIndexForInsertion(at: point)
        needsDisplay = true
        return .move
    }

    override func draggingExited(_ sender: (any NSDraggingInfo)?) {
        dragInsertionIndex = nil
        needsDisplay = true
        super.draggingExited(sender)
    }

    override func performDragOperation(_ sender: any NSDraggingInfo) -> Bool {
        let point = convert(sender.draggingLocation, from: nil)
        let index = characterIndexForInsertion(at: point)
        dragInsertionIndex = nil
        needsDisplay = true
        if let assetID = draggedAssetID(from: sender) {
            onMoveAsset?(assetID, index)
            return true
        }
        if let blockID = draggedStructuredBlockID(from: sender) {
            onMoveStructuredBlock?(blockID, index)
            return true
        }
        return super.performDragOperation(sender)
    }

    override func mouseDown(with event: NSEvent) {
        let point = convert(event.locationInWindow, from: nil)
        let index = characterIndexForInsertion(at: point)
        let source = string as NSString
        guard index <= source.length else { super.mouseDown(with: event); return }
        let lineRange = source.lineRange(for: NSRange(location: min(index, max(0, source.length - 1)), length: 0))
        let line = source.substring(with: lineRange)
        if (line.hasPrefix("☐ ") || line.hasPrefix("☑ ")),
           point.x <= textContainerOrigin.x + 28,
           shouldChangeText(in: NSRange(location: lineRange.location, length: 1), replacementString: nil) {
            textStorage?.replaceCharacters(
                in: NSRange(location: lineRange.location, length: 1),
                with: line.hasPrefix("☐") ? "☑" : "☐"
            )
            didChangeText()
            return
        }
        super.mouseDown(with: event)
    }

    private func deleteAdjacentAsset(backward: Bool) -> Bool {
        let selection = selectedRange()
        var matches = assetMatches(intersecting: selection)
        if matches.isEmpty && selection.length == 0 {
            let cursor = selection.location
            matches = AssetBlockSyntax.matches(in: string).filter { match in
                let start = match.lineRange.location
                let end = NSMaxRange(match.lineRange)
                if cursor >= start && cursor <= end { return true }
                return backward ? end == cursor : start == cursor
            }
            if matches.count > 1 {
                matches = [backward ? matches.last! : matches.first!]
            }
        }
        guard !matches.isEmpty else { return false }
        let deletionRange = expandedSelection(selection, for: matches)
        guard shouldChangeText(in: deletionRange, replacementString: "") else { return true }
        textStorage?.replaceCharacters(in: deletionRange, with: "")
        setSelectedRange(NSRange(location: deletionRange.location, length: 0))
        didChangeText()
        matches.forEach { onDeleteAsset?($0.assetID) }
        return true
    }

    private func deleteAdjacentStructuredBlock(backward: Bool) -> Bool {
        let selection = selectedRange()
        var matches = structuredMatches(intersecting: selection)
        if matches.isEmpty && selection.length == 0 {
            let cursor = selection.location
            matches = FocoStructuredBlockSyntax.matches(in: string).filter { match in
                let start = match.lineRange.location
                let end = NSMaxRange(match.lineRange)
                if cursor >= start && cursor <= end { return true }
                return backward ? end == cursor : start == cursor
            }
            if matches.count > 1 { matches = [backward ? matches.last! : matches.first!] }
        }
        guard !matches.isEmpty else { return false }
        let range = matches.map(\.lineRange).reduce(selection, NSUnionRange)
        let blocks = matches.compactMap { inlineBlockStores[$0.id]?.block }
        guard shouldChangeText(in: range, replacementString: "") else { return true }
        textStorage?.replaceCharacters(in: range, with: "")
        setSelectedRange(NSRange(location: range.location, length: 0))
        didChangeText()
        blocks.forEach { onDeleteStructuredBlock?($0) }
        return true
    }

    private func deleteStructuredBlock(_ id: UUID) {
        guard let match = FocoStructuredBlockSyntax.matches(in: string).first(where: { $0.id == id }),
              let block = inlineBlockStores[id]?.block else { return }
        guard shouldChangeText(in: match.lineRange, replacementString: "") else { return }
        textStorage?.replaceCharacters(in: match.lineRange, with: "")
        setSelectedRange(NSRange(location: match.lineRange.location, length: 0))
        didChangeText()
        onDeleteStructuredBlock?(block)
    }

    private func assetMatches(intersecting selection: NSRange) -> [AssetBlockMatch] {
        let matches = AssetBlockSyntax.matches(in: string)
        if selection.length == 0 { return [] }
        return matches.filter { NSIntersectionRange($0.lineRange, selection).length > 0 }
    }

    private func structuredMatches(intersecting selection: NSRange) -> [FocoStructuredBlockMatch] {
        let matches = FocoStructuredBlockSyntax.matches(in: string)
        if selection.length == 0 { return [] }
        return matches.filter { NSIntersectionRange($0.lineRange, selection).length > 0 }
    }

    private func expandedSelection(_ selection: NSRange, for matches: [AssetBlockMatch]) -> NSRange {
        matches.reduce(selection) { NSUnionRange($0, $1.lineRange) }
    }

    private func draggedAssetID(from sender: any NSDraggingInfo) -> UUID? {
        guard let value = sender.draggingPasteboard.string(forType: .string),
              value.hasPrefix("foco-asset:") else { return nil }
        return UUID(uuidString: String(value.dropFirst("foco-asset:".count)))
    }

    private func draggedStructuredBlockID(from sender: any NSDraggingInfo) -> UUID? {
        guard let value = sender.draggingPasteboard.string(forType: .string),
              value.hasPrefix("foco-block:") else { return nil }
        return UUID(uuidString: String(value.dropFirst("foco-block:".count)))
    }

    private func layoutInlineAssetViews() {
        guard let layoutManager, let textContainer else { return }
        layoutManager.ensureLayout(for: textContainer)
        let matches = AssetBlockSyntax.matches(in: string)
        let visibleIDs = Set(matches.map(\.assetID))
        for (id, hostedView) in inlineAssetViews {
            guard visibleIDs.contains(id),
                  let asset = inlineAssets[id],
                  let match = matches.first(where: { $0.assetID == id }),
                  let lineRect = visualRect(
                    for: match.tokenRange,
                    layoutManager: layoutManager,
                    textContainer: textContainer
                  ) else {
                hostedView.isHidden = true
                continue
            }
            hostedView.isHidden = false
            hostedView.frame = NSRect(
                x: textContainerOrigin.x,
                y: lineRect.minY + 6,
                width: max(0, bounds.width - textContainerOrigin.x * 2),
                height: asset.inlinePreviewHeight
            )
        }
    }

    private func layoutInlineStructuredBlockViews() {
        guard let layoutManager, let textContainer else { return }
        layoutManager.ensureLayout(for: textContainer)
        let matches = FocoStructuredBlockSyntax.matches(in: string)
        let visibleIDs = Set(matches.map(\.id))
        for (id, hostedView) in inlineBlockViews {
            guard visibleIDs.contains(id),
                  let store = inlineBlockStores[id],
                  let match = matches.first(where: { $0.id == id }),
                  let lineRect = visualRect(
                    for: match.tokenRange,
                    layoutManager: layoutManager,
                    textContainer: textContainer
                  ) else {
                hostedView.isHidden = true
                continue
            }
            hostedView.isHidden = false
            hostedView.frame = NSRect(
                x: textContainerOrigin.x,
                y: lineRect.minY + 6,
                width: max(0, bounds.width - textContainerOrigin.x * 2),
                height: store.block.inlineHeight
            )
        }
    }

    private func drawDragInsertionIndicator() {
        guard let index = dragInsertionIndex,
              let layoutManager,
              let textContainer,
              !string.isEmpty else { return }
        let location = min(index, max(0, (string as NSString).length - 1))
        guard let rect = visualRect(
            for: NSRange(location: location, length: 1),
            layoutManager: layoutManager,
            textContainer: textContainer
        ) else { return }
        NSColor.controlAccentColor.setFill()
        NSBezierPath(
            roundedRect: NSRect(
                x: textContainerOrigin.x,
                y: rect.minY - 2,
                width: max(0, bounds.width - textContainerOrigin.x * 2),
                height: 3
            ),
            xRadius: 1.5,
            yRadius: 1.5
        ).fill()
    }

    private func lineContinuation() -> String? {
        let source = string as NSString
        let cursor = min(selectedRange().location, source.length)
        let line = source.substring(to: cursor).components(separatedBy: "\n").last ?? ""
        if line.contains("\t") { return "\t\t" }
        for prefix in ["- ", "• ", "☐ ", "> "] where line.hasPrefix(prefix) && line.count > prefix.count {
            return prefix
        }
        if let match = try? NSRegularExpression(pattern: #"^(\d+)\.\s"#).firstMatch(
            in: line,
            range: NSRange(location: 0, length: (line as NSString).length)
        ), match.range(at: 1).location != NSNotFound {
            let number = Int((line as NSString).substring(with: match.range(at: 1))) ?? 0
            return "\(number + 1). "
        }
        return nil
    }

    private func drawBlockDecorations() {
        guard let layoutManager, let textContainer, !string.isEmpty else { return }
        layoutManager.ensureLayout(for: textContainer)
        let source = string as NSString
        let origin = textContainerOrigin
        let contentWidth = max(0, bounds.width - origin.x * 2)
        var inCode = false
        var codeRect: NSRect?
        var inFormula = false
        var formulaRect: NSRect?
        var previousWasTable = false

        source.enumerateSubstrings(
            in: NSRange(location: 0, length: source.length),
            options: [.byLines, .substringNotRequired]
        ) { _, lineRange, _, _ in
            let line = source.substring(with: lineRange)
            guard var rect = self.visualRect(for: lineRange, layoutManager: layoutManager, textContainer: textContainer) else { return }
            rect.origin.x = origin.x
            rect.size.width = contentWidth

            if line.trimmingCharacters(in: .whitespaces) == "```" {
                if inCode {
                    codeRect = codeRect?.union(rect) ?? rect
                    self.drawCodeBackground(codeRect)
                    codeRect = nil
                } else {
                    codeRect = rect
                }
                inCode.toggle()
                previousWasTable = false
                return
            }
            if inCode {
                codeRect = codeRect?.union(rect) ?? rect
                previousWasTable = false
                return
            }

            if line.trimmingCharacters(in: .whitespaces) == "$$" {
                if inFormula {
                    formulaRect = formulaRect?.union(rect) ?? rect
                    self.drawFormulaBackground(formulaRect)
                    formulaRect = nil
                } else {
                    formulaRect = rect
                }
                inFormula.toggle()
                previousWasTable = false
                return
            }
            if inFormula {
                formulaRect = formulaRect?.union(rect) ?? rect
                previousWasTable = false
                return
            }

            if line == "---" {
                NSColor.separatorColor.withAlphaComponent(0.75).setFill()
                NSRect(x: rect.minX, y: rect.midY, width: rect.width, height: 1).fill()
                previousWasTable = false
                return
            }

            if line.contains("\t") {
                let row = rect.insetBy(dx: 0, dy: -3)
                (previousWasTable ? NSColor.controlBackgroundColor : NSColor.controlAccentColor.withAlphaComponent(0.09)).setFill()
                row.fill()
                NSColor.separatorColor.withAlphaComponent(0.7).setStroke()
                let border = NSBezierPath(rect: row)
                border.lineWidth = 1
                border.stroke()
                for fraction in [CGFloat(1) / 3, CGFloat(2) / 3] {
                    let x = row.minX + row.width * fraction
                    let separator = NSBezierPath()
                    separator.move(to: NSPoint(x: x, y: row.minY))
                    separator.line(to: NSPoint(x: x, y: row.maxY))
                    separator.lineWidth = 1
                    separator.stroke()
                }
                previousWasTable = true
                return
            }

            if line.hasPrefix("> Prompt:") {
                let callout = rect.insetBy(dx: 0, dy: -3)
                NSColor.controlAccentColor.withAlphaComponent(0.09).setFill()
                NSBezierPath(roundedRect: callout, xRadius: 7, yRadius: 7).fill()
                NSColor.controlAccentColor.withAlphaComponent(0.8).setFill()
                NSBezierPath(
                    roundedRect: NSRect(x: callout.minX, y: callout.minY, width: 3, height: callout.height),
                    xRadius: 1.5,
                    yRadius: 1.5
                ).fill()
            } else if line.hasPrefix("> ") {
                NSColor.quaternaryLabelColor.setFill()
                NSBezierPath(
                    roundedRect: NSRect(x: rect.minX, y: rect.minY - 1, width: 3, height: rect.height + 2),
                    xRadius: 1.5,
                    yRadius: 1.5
                ).fill()
            }
            previousWasTable = false
        }

        if inCode { drawCodeBackground(codeRect) }
        if inFormula { drawFormulaBackground(formulaRect) }
    }

    private func visualRect(
        for characterRange: NSRange,
        layoutManager: NSLayoutManager,
        textContainer: NSTextContainer
    ) -> NSRect? {
        guard characterRange.location < (textStorage?.length ?? 0) else { return nil }
        let glyphRange = layoutManager.glyphRange(forCharacterRange: characterRange, actualCharacterRange: nil)
        guard glyphRange.length > 0 else { return nil }
        var rect = layoutManager.lineFragmentRect(forGlyphAt: glyphRange.location, effectiveRange: nil)
        rect.origin.x += textContainerOrigin.x
        rect.origin.y += textContainerOrigin.y
        return rect
    }

    private func drawCodeBackground(_ sourceRect: NSRect?) {
        guard let sourceRect else { return }
        let rect = sourceRect.insetBy(dx: 0, dy: -4)
        NSColor.controlBackgroundColor.withAlphaComponent(0.86).setFill()
        NSBezierPath(roundedRect: rect, xRadius: 8, yRadius: 8).fill()
        NSColor.separatorColor.withAlphaComponent(0.45).setStroke()
        let border = NSBezierPath(roundedRect: rect, xRadius: 8, yRadius: 8)
        border.lineWidth = 1
        border.stroke()
    }

    private func drawFormulaBackground(_ sourceRect: NSRect?) {
        guard let sourceRect else { return }
        let rect = sourceRect.insetBy(dx: 0, dy: -6)
        NSColor.controlAccentColor.withAlphaComponent(0.07).setFill()
        NSBezierPath(roundedRect: rect, xRadius: 10, yRadius: 10).fill()
        NSColor.controlAccentColor.withAlphaComponent(0.5).setFill()
        NSBezierPath(
            roundedRect: NSRect(x: rect.minX, y: rect.minY, width: 3, height: rect.height),
            xRadius: 1.5,
            yRadius: 1.5
        ).fill()
        NSColor.separatorColor.withAlphaComponent(0.3).setStroke()
        let border = NSBezierPath(roundedRect: rect, xRadius: 10, yRadius: 10)
        border.lineWidth = 1
        border.stroke()
    }
}

private struct RichTextEditor: NSViewRepresentable {
    @Binding var text: String
    let writingContext: String
    @Binding var slashQuery: String?
    @Binding var selectedRange: NSRange
    @Binding var editorHeight: CGFloat
    let assets: [VaultAsset]
    let blocks: [FocoStructuredBlock]
    let assetURL: @Sendable (VaultAsset) -> URL?
    let onImportEmbeddedAsset: @MainActor (URL) async -> VaultAsset?
    let onDeleteAsset: (UUID) -> Void
    let onUpdateStructuredBlock: (FocoStructuredBlock) -> Void
    let onDeleteStructuredBlock: (FocoStructuredBlock) -> Void
    let onMoveStructuredBlock: (UUID, Int) -> Void
    let onMoveStructuredBlockBy: (UUID, Int) -> Void
    let onMoveAsset: (UUID, Int) -> Void
    let onMoveAssetBy: (UUID, Int) -> Void
    let onSlashKey: (SlashKey) -> Void

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    func makeNSView(context: Context) -> FocoTextView {
        context.coordinator.updatingFromSwiftUI = true
        defer { context.coordinator.updatingFromSwiftUI = false }
        let view = FocoTextView()
        view.delegate = context.coordinator
        view.isRichText = true
        view.importsGraphics = false
        view.drawsBackground = false
        view.isEditable = true
        view.isSelectable = true
        view.allowsUndo = true
        view.usesFindBar = true
        view.isAutomaticLinkDetectionEnabled = true
        view.isAutomaticDataDetectionEnabled = true
        view.isVerticallyResizable = true
        view.isHorizontallyResizable = false
        view.minSize = NSSize(width: 0, height: 180)
        view.maxSize = NSSize(width: CGFloat.greatestFiniteMagnitude, height: CGFloat.greatestFiniteMagnitude)
        view.textContainerInset = .zero
        view.textContainer?.widthTracksTextView = true
        view.textContainer?.heightTracksTextView = false
        view.textContainer?.lineFragmentPadding = 0
        view.font = .systemFont(ofSize: 16)
        view.textColor = .labelColor
        view.insertionPointColor = .labelColor
        view.linkTextAttributes = [
            .foregroundColor: NSColor.linkColor,
            .underlineStyle: NSUnderlineStyle.single.rawValue
        ]
        view.string = text
        view.slashMenuVisible = { [weak coordinator = context.coordinator] in
            coordinator?.parent.slashQuery != nil
        }
        view.onSlashKey = { [weak coordinator = context.coordinator] key in
            coordinator?.parent.onSlashKey(key)
        }
        view.onAcceptPrediction = { [weak coordinator = context.coordinator, weak view] in
            coordinator?.acceptPrediction(in: view)
        }
        view.onDismissPrediction = { [weak coordinator = context.coordinator, weak view] in
            coordinator?.dismissPrediction(in: view)
        }
        view.onDeleteAsset = { [weak coordinator = context.coordinator] assetID in
            coordinator?.parent.onDeleteAsset(assetID)
        }
        view.onMoveAsset = { [weak coordinator = context.coordinator] assetID, offset in
            coordinator?.parent.onMoveAsset(assetID, offset)
        }
        view.onMoveAssetBy = { [weak coordinator = context.coordinator] assetID, direction in
            coordinator?.parent.onMoveAssetBy(assetID, direction)
        }
        view.onUpdateStructuredBlock = { [weak coordinator = context.coordinator] block in
            coordinator?.parent.onUpdateStructuredBlock(block)
        }
        view.onDeleteStructuredBlock = { [weak coordinator = context.coordinator] block in
            coordinator?.parent.onDeleteStructuredBlock(block)
        }
        view.onMoveStructuredBlock = { [weak coordinator = context.coordinator] blockID, offset in
            coordinator?.parent.onMoveStructuredBlock(blockID, offset)
        }
        view.onMoveStructuredBlockBy = { [weak coordinator = context.coordinator] blockID, direction in
            coordinator?.parent.onMoveStructuredBlockBy(blockID, direction)
        }
        view.configureInlineAssets(assets, assetURL: assetURL)
        view.configureInlineStructuredBlocks(
            blocks,
            assets: assets,
            assetURL: assetURL,
            importImage: onImportEmbeddedAsset
        )
        context.coordinator.style(view)
        context.coordinator.updateHeight(view)
        return view
    }

    func updateNSView(_ view: FocoTextView, context: Context) {
        context.coordinator.parent = self
        context.coordinator.updatingFromSwiftUI = true
        defer { context.coordinator.updatingFromSwiftUI = false }
        view.configureInlineAssets(assets, assetURL: assetURL)
        view.configureInlineStructuredBlocks(
            blocks,
            assets: assets,
            assetURL: assetURL,
            importImage: onImportEmbeddedAsset
        )
        let contentChanged = view.string != text
        if contentChanged {
            view.string = text
            let location = min(selectedRange.location, text.utf16.count)
            let length = min(selectedRange.length, max(0, text.utf16.count - location))
            view.setSelectedRange(NSRange(location: location, length: length))
        }
        context.coordinator.style(view)
        context.coordinator.updateHeight(view)
        if contentChanged {
            DispatchQueue.main.async {
                view.window?.makeFirstResponder(view)
            }
        }
    }

    @MainActor
    final class Coordinator: NSObject, NSTextViewDelegate {
        var parent: RichTextEditor
        private var styling = false
        var updatingFromSwiftUI = false
        private let predictor = XAIInlinePredictor()
        private static let writingFont = NSFont(name: "Courier", size: 16)
            ?? NSFont.monospacedSystemFont(ofSize: 16, weight: .regular)
        init(_ parent: RichTextEditor) { self.parent = parent }

        func textDidChange(_ notification: Notification) {
            guard !styling, !updatingFromSwiftUI,
                  let view = notification.object as? FocoTextView else { return }
            let selection = view.selectedRange()
            parent.text = view.string
            parent.selectedRange = selection
            parent.slashQuery = Self.query(before: selection.location, in: view.string)
            predictor.schedule(text: view.string, cursor: selection.location, writingContext: parent.writingContext) { [weak view] suggestion in
                view?.setGhostSuggestion(suggestion)
            }
            style(view)
            updateHeight(view)
        }

        func textViewDidChangeSelection(_ notification: Notification) {
            guard !styling, !updatingFromSwiftUI,
                  let view = notification.object as? FocoTextView else { return }
            let selection = view.selectedRange()
            parent.selectedRange = selection
            dismissPrediction(in: view)
            if parent.slashQuery != nil {
                parent.slashQuery = Self.query(before: selection.location, in: view.string)
            }
        }

        func acceptPrediction(in view: FocoTextView?) {
            guard let view, !predictor.suggestion.isEmpty else { return }
            let suggestion = predictor.suggestion
            dismissPrediction(in: view)
            view.insertText(suggestion, replacementRange: view.selectedRange())
        }

        func dismissPrediction(in view: FocoTextView?) {
            predictor.cancel()
            view?.setGhostSuggestion(nil)
        }

        func textView(_ textView: NSTextView, clickedOnLink link: Any, at charIndex: Int) -> Bool {
            if let url = link as? URL {
                NSWorkspace.shared.open(url)
                return true
            }
            if let value = link as? String, let url = URL(string: value) {
                NSWorkspace.shared.open(url)
                return true
            }
            return false
        }

        func style(_ view: FocoTextView) {
            guard let storage = view.textStorage else { return }
            styling = true
            let all = NSRange(location: 0, length: storage.length)
            let paragraph = NSMutableParagraphStyle()
            paragraph.lineSpacing = 4
            paragraph.paragraphSpacing = 7
            storage.beginEditing()
            storage.setAttributes([
                .font: Self.writingFont,
                .foregroundColor: NSColor.labelColor,
                .paragraphStyle: paragraph
            ], range: all)

            let source = storage.string as NSString
            let textWidth = max(300, view.bounds.width)
            var inCode = false
            var inFormula = false
            var previousWasTable = false
            source.enumerateSubstrings(
                in: NSRange(location: 0, length: source.length),
                options: [.byLines, .substringNotRequired]
            ) { _, lineRange, _, _ in
                let line = source.substring(with: lineRange)
                if line.trimmingCharacters(in: .whitespaces) == "```" {
                    let fence = paragraph.mutableCopy() as! NSMutableParagraphStyle
                    fence.minimumLineHeight = 8
                    fence.maximumLineHeight = 8
                    fence.paragraphSpacing = 0
                    storage.addAttributes([
                        .font: NSFont.systemFont(ofSize: 1),
                        .foregroundColor: NSColor.clear,
                        .paragraphStyle: fence
                    ], range: lineRange)
                    inCode.toggle()
                    previousWasTable = false
                    return
                }
                if inCode {
                    let code = paragraph.mutableCopy() as! NSMutableParagraphStyle
                    code.firstLineHeadIndent = 12
                    code.headIndent = 12
                    code.tailIndent = -12
                    code.paragraphSpacing = 1
                    storage.addAttributes([
                        .font: NSFont.monospacedSystemFont(ofSize: 14, weight: .regular),
                        .paragraphStyle: code
                    ], range: lineRange)
                    previousWasTable = false
                    return
                }

                if line.trimmingCharacters(in: .whitespaces) == "$$" {
                    let fence = paragraph.mutableCopy() as! NSMutableParagraphStyle
                    fence.minimumLineHeight = 10
                    fence.maximumLineHeight = 10
                    fence.paragraphSpacing = 0
                    storage.addAttributes([
                        .font: NSFont.systemFont(ofSize: 1),
                        .foregroundColor: NSColor.clear,
                        .paragraphStyle: fence
                    ], range: lineRange)
                    inFormula.toggle()
                    previousWasTable = false
                    return
                }
                if inFormula {
                    let formula = paragraph.mutableCopy() as! NSMutableParagraphStyle
                    formula.alignment = .center
                    formula.paragraphSpacing = 2
                    let serifDescriptor = NSFont.systemFont(ofSize: 20).fontDescriptor.withDesign(.serif) ?? NSFont.systemFont(ofSize: 20).fontDescriptor
                    let serif = NSFont(descriptor: serifDescriptor, size: 20) ?? NSFont.systemFont(ofSize: 20)
                    let italic = NSFontManager.shared.convert(serif, toHaveTrait: .italicFontMask)
                    storage.addAttributes([
                        .font: italic,
                        .foregroundColor: NSColor.labelColor,
                        .paragraphStyle: formula
                    ], range: lineRange)
                    previousWasTable = false
                    return
                }

                if line == "---" {
                    let divider = paragraph.mutableCopy() as! NSMutableParagraphStyle
                    divider.minimumLineHeight = 18
                    divider.maximumLineHeight = 18
                    divider.paragraphSpacing = 8
                    storage.addAttributes([
                        .font: NSFont.systemFont(ofSize: 1),
                        .foregroundColor: NSColor.clear,
                        .paragraphStyle: divider
                    ], range: lineRange)
                    previousWasTable = false
                    return
                }

                if line.contains("\t") {
                    let table = paragraph.mutableCopy() as! NSMutableParagraphStyle
                    table.firstLineHeadIndent = 10
                    table.headIndent = 10
                    table.tailIndent = -10
                    table.minimumLineHeight = 30
                    table.maximumLineHeight = 30
                    table.paragraphSpacing = 0
                    table.tabStops = [
                        NSTextTab(textAlignment: .left, location: textWidth / 3),
                        NSTextTab(textAlignment: .left, location: textWidth * 2 / 3)
                    ]
                    storage.addAttributes([
                        .font: previousWasTable
                            ? NSFont.systemFont(ofSize: 14)
                            : NSFont.systemFont(ofSize: 14, weight: .semibold),
                        .paragraphStyle: table
                    ], range: lineRange)
                    previousWasTable = true
                    return
                }
                previousWasTable = false

                if line.hasPrefix("# ") {
                    storage.addAttribute(.font, value: NSFont.systemFont(ofSize: 29, weight: .bold), range: lineRange)
                } else if line.hasPrefix("## ") {
                    storage.addAttribute(.font, value: NSFont.systemFont(ofSize: 23, weight: .semibold), range: lineRange)
                } else if line.hasPrefix("### ") {
                    storage.addAttribute(.font, value: NSFont.systemFont(ofSize: 18, weight: .semibold), range: lineRange)
                }

                if line.hasPrefix("> Prompt:") {
                    let prompt = paragraph.mutableCopy() as! NSMutableParagraphStyle
                    prompt.firstLineHeadIndent = 14
                    prompt.headIndent = 14
                    prompt.tailIndent = -12
                    prompt.minimumLineHeight = 34
                    storage.addAttributes([
                        .font: NSFont.systemFont(ofSize: 15, weight: .medium),
                        .foregroundColor: NSColor.controlAccentColor,
                        .paragraphStyle: prompt
                    ], range: lineRange)
                } else if line.hasPrefix("> ") {
                    let quote = paragraph.mutableCopy() as! NSMutableParagraphStyle
                    quote.firstLineHeadIndent = 15
                    quote.headIndent = 15
                    quote.tailIndent = -8
                    storage.addAttributes([
                        .font: NSFontManager.shared.convert(
                            NSFont.systemFont(ofSize: 16),
                            toHaveTrait: .italicFontMask
                        ),
                        .foregroundColor: NSColor.secondaryLabelColor,
                        .paragraphStyle: quote
                    ], range: lineRange)
                }

                if line.hasPrefix("☐ ") {
                    storage.addAttribute(
                        .foregroundColor,
                        value: NSColor.controlAccentColor,
                        range: NSRange(location: lineRange.location, length: min(1, lineRange.length))
                    )
                } else if line.hasPrefix("📅") || line.hasPrefix("● ") {
                    storage.addAttribute(
                        .foregroundColor,
                        value: NSColor.controlAccentColor,
                        range: NSRange(location: lineRange.location, length: min(2, lineRange.length))
                    )
                }
            }

            let assetsByID = Dictionary(uniqueKeysWithValues: parent.assets.map { ($0.id, $0) })
            for match in AssetBlockSyntax.matches(in: storage.string) {
                guard let asset = assetsByID[match.assetID] else { continue }
                let assetParagraph = paragraph.mutableCopy() as! NSMutableParagraphStyle
                assetParagraph.minimumLineHeight = asset.inlinePreviewHeight + 12
                assetParagraph.maximumLineHeight = asset.inlinePreviewHeight + 12
                assetParagraph.paragraphSpacing = 0
                storage.addAttributes([
                    .foregroundColor: NSColor.clear,
                    .font: NSFont.systemFont(ofSize: 1),
                    .paragraphStyle: assetParagraph
                ], range: match.tokenRange)
            }

            let blocksByID = Dictionary(uniqueKeysWithValues: parent.blocks.map { ($0.id, $0) })
            for match in FocoStructuredBlockSyntax.matches(in: storage.string) {
                guard let block = blocksByID[match.id] else { continue }
                let blockParagraph = paragraph.mutableCopy() as! NSMutableParagraphStyle
                blockParagraph.minimumLineHeight = block.inlineHeight + 12
                blockParagraph.maximumLineHeight = block.inlineHeight + 12
                blockParagraph.paragraphSpacing = 0
                storage.addAttributes([
                    .foregroundColor: NSColor.clear,
                    .font: NSFont.systemFont(ofSize: 1),
                    .paragraphStyle: blockParagraph
                ], range: match.tokenRange)
            }

            if let markdownLink = try? NSRegularExpression(pattern: #"\[([^\]]+)\]\((https?://[^\s)]+)\)"#) {
                markdownLink.enumerateMatches(in: storage.string, range: all) { match, _, _ in
                    guard let match,
                          match.range(at: 1).location != NSNotFound,
                          match.range(at: 2).location != NSNotFound,
                          let url = URL(string: source.substring(with: match.range(at: 2))) else { return }
                    storage.addAttribute(.foregroundColor, value: NSColor.tertiaryLabelColor, range: match.range)
                    storage.addAttributes([
                        .link: url,
                        .foregroundColor: NSColor.linkColor,
                        .underlineStyle: NSUnderlineStyle.single.rawValue
                    ], range: match.range(at: 1))
                }
            }

            if let urlRegex = try? NSRegularExpression(pattern: #"https?://[^\s<>()\[\]{}]+"#) {
                urlRegex.enumerateMatches(in: storage.string, range: all) { match, _, _ in
                    guard var range = match?.range else { return }
                    var candidate = source.substring(with: range)
                    while let last = candidate.last, ".,;:!?".contains(last) {
                        candidate.removeLast()
                        range.length = candidate.utf16.count
                    }
                    guard let url = URL(string: candidate), range.length > 0 else { return }
                    storage.addAttributes([
                        .link: url,
                        .foregroundColor: NSColor.linkColor,
                        .underlineStyle: NSUnderlineStyle.single.rawValue
                    ], range: range)
                }
            }
            storage.endEditing()
            view.typingAttributes = [
                .font: Self.writingFont,
                .foregroundColor: NSColor.labelColor,
                .paragraphStyle: paragraph
            ]
            view.needsDisplay = true
            view.needsLayout = true
            styling = false
        }

        func updateHeight(_ view: NSTextView) {
            guard let layoutManager = view.layoutManager, let textContainer = view.textContainer else { return }
            layoutManager.ensureLayout(for: textContainer)
            let measured = ceil(layoutManager.usedRect(for: textContainer).height + 12)
            let height = max(180, measured)
            guard abs(parent.editorHeight - height) > 1 else { return }
            DispatchQueue.main.async { self.parent.editorHeight = height }
        }

        private static func query(before cursor: Int, in text: String) -> String? {
            let source = text as NSString
            guard cursor <= source.length else { return nil }
            let prefix = source.substring(to: cursor)
            guard let token = prefix.split(whereSeparator: { $0.isWhitespace || $0.isNewline }).last,
                  token.first == "/" else { return nil }
            return String(token.dropFirst())
        }
    }
}
