import AppKit
import SwiftUI

enum InsertKind: String, CaseIterable, Identifiable {
    case text, heading1, heading2, bulletedList, numberedList, todo, quote, divider, code, prompt, url
    case pdf, image, video, file

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
        case .prompt: "Prompt"
        case .url: "Web link"
        case .pdf: "PDF"
        case .image: "Image"
        case .video: "Video"
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
        case .prompt: "Save an AI prompt locally"
        case .url: "Bookmark a website"
        case .pdf: "Attach a portable document"
        case .image: "Attach a photo or graphic"
        case .video: "Attach a local video"
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
        case .prompt: "sparkles"
        case .url: "link"
        case .pdf: "doc.richtext"
        case .image: "photo"
        case .video: "play.rectangle"
        case .file: "paperclip"
        }
    }
    var needsFile: Bool { [.pdf, .image, .video, .file].contains(self) }
    var isMedia: Bool { needsFile || self == .url }
}

struct EditorView: View {
    @Binding var page: VaultPage
    let assets: [VaultAsset]
    let assetData: [String: Data]
    let onInsertAsset: (InsertKind) -> Void
    @State private var slashQuery: String?
    @State private var editorHeight: CGFloat = 180

    var body: some View {
        ZStack(alignment: .topLeading) {
            VStack(spacing: 0) {
                ScrollView {
                    VStack(alignment: .leading, spacing: 0) {
                        Spacer().frame(height: 34)
                        HStack {
                            Image(systemName: "doc.text")
                                .font(.system(size: 30, weight: .light))
                                .foregroundStyle(.secondary)
                                .frame(width: 52, height: 52)
                                .background(FocoTheme.hover, in: RoundedRectangle(cornerRadius: 12))
                            Spacer()
                        }
                        .padding(.bottom, 18)

                        TextField("Untitled", text: $page.title)
                            .textFieldStyle(.plain)
                            .font(.system(size: 40, weight: .bold, design: .default))
                            .tracking(-1.1)
                            .padding(.bottom, 8)

                        Text("Private  ·  Saved in this vault")
                            .font(.system(size: 12))
                            .foregroundStyle(.tertiary)
                            .padding(.bottom, 25)

                        ZStack(alignment: .topLeading) {
                            if page.content.isEmpty {
                                Text("Type ‘/’ for commands, or just start writing…")
                                    .font(.system(size: 16))
                                    .foregroundStyle(.tertiary)
                                    .padding(.top, 1)
                                    .allowsHitTesting(false)
                            }
                            RichTextEditor(text: $page.content, slashQuery: $slashQuery, editorHeight: $editorHeight)
                                .frame(height: editorHeight)
                        }
                        .frame(maxWidth: .infinity, alignment: .topLeading)

                        if !referencedAssets.isEmpty {
                            AssetPreviewGallery(assets: referencedAssets, assetData: assetData)
                                .padding(.top, 18)
                        }
                        Spacer().frame(height: 160)
                    }
                    .frame(maxWidth: 720, alignment: .leading)
                    .padding(.horizontal, 64)
                    .frame(maxWidth: .infinity)
                }
                .scrollIndicators(.hidden)
            }

            if let query = slashQuery {
                SlashMenu(query: query, insert: insert)
                    .padding(.leading, 80)
                    .padding(.top, 245)
                    .transition(.opacity.combined(with: .scale(scale: 0.97, anchor: .topLeading)))
                    .zIndex(10)
            }
        }
        .background(FocoTheme.canvas)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .animation(.easeOut(duration: 0.12), value: slashQuery != nil)
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

    private func insert(_ kind: InsertKind) {
        if let query = slashQuery,
           let range = page.content.range(of: "/\(query)", options: .backwards) {
            page.content.removeSubrange(range)
        }
        slashQuery = nil
        if kind.needsFile { onInsertAsset(kind); return }
        let value: String
        switch kind {
        case .text: value = ""
        case .heading1: value = "# "
        case .heading2: value = "## "
        case .bulletedList: value = "- "
        case .numberedList: value = "1. "
        case .todo: value = "- [ ] "
        case .quote: value = "> "
        case .divider: value = "---\n"
        case .code: value = "```\n\n```"
        case .prompt: value = "> Prompt: "
        case .url: value = "[Link title](https://)"
        default: return
        }
        page.content += value
    }
}

private struct SlashMenu: View {
    let query: String
    let insert: (InsertKind) -> Void
    private var matches: [InsertKind] {
        query.isEmpty ? InsertKind.allCases : InsertKind.allCases.filter {
            $0.label.localizedCaseInsensitiveContains(query) || $0.detail.localizedCaseInsensitiveContains(query)
        }
    }

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
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 1) {
                        ForEach(matches) { kind in
                            if kind == matches.first(where: { $0.isMedia }) && matches.contains(where: { !$0.isMedia }) {
                                menuLabel("MEDIA & FILES")
                            }
                            SlashMenuRow(kind: kind) { insert(kind) }
                        }
                    }
                    .padding(.horizontal, 5)
                    .padding(.bottom, 6)
                }
                .frame(maxHeight: 430)
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
            .background(hovered ? FocoTheme.hover : .clear, in: RoundedRectangle(cornerRadius: 7))
        }
        .buttonStyle(.plain)
        .onHover { hovered = $0 }
    }
}

private struct RichTextEditor: NSViewRepresentable {
    @Binding var text: String
    @Binding var slashQuery: String?
    @Binding var editorHeight: CGFloat

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    func makeNSView(context: Context) -> NSTextView {
        let view = NSTextView()
        view.delegate = context.coordinator
        view.isRichText = true
        view.importsGraphics = false
        view.drawsBackground = false
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
        view.string = text
        context.coordinator.style(view)
        context.coordinator.updateHeight(view)
        return view
    }

    func updateNSView(_ view: NSTextView, context: Context) {
        context.coordinator.parent = self
        guard view.string != text else { return }
        let selection = view.selectedRange()
        view.string = text
        view.setSelectedRange(NSRange(location: min(selection.location, text.utf16.count), length: 0))
        context.coordinator.style(view)
        context.coordinator.updateHeight(view)
    }

    @MainActor
    final class Coordinator: NSObject, NSTextViewDelegate {
        var parent: RichTextEditor
        private var styling = false
        init(_ parent: RichTextEditor) { self.parent = parent }

        func textDidChange(_ notification: Notification) {
            guard !styling, let view = notification.object as? NSTextView else { return }
            parent.text = view.string
            parent.slashQuery = Self.query(before: view.selectedRange().location, in: view.string)
            style(view)
            updateHeight(view)
        }

        func style(_ view: NSTextView) {
            guard let storage = view.textStorage else { return }
            styling = true
            let all = NSRange(location: 0, length: storage.length)
            let paragraph = NSMutableParagraphStyle()
            paragraph.lineSpacing = 5
            paragraph.paragraphSpacing = 8
            storage.beginEditing()
            storage.setAttributes([
                .font: NSFont.systemFont(ofSize: 16),
                .foregroundColor: NSColor.labelColor,
                .paragraphStyle: paragraph
            ], range: all)

            let source = storage.string as NSString
            source.enumerateSubstrings(in: NSRange(location: 0, length: source.length), options: [.byLines, .substringNotRequired]) { _, lineRange, _, _ in
                let line = source.substring(with: lineRange)
                let font: NSFont?
                if line.hasPrefix("# ") { font = .systemFont(ofSize: 27, weight: .bold) }
                else if line.hasPrefix("## ") { font = .systemFont(ofSize: 21, weight: .semibold) }
                else { font = nil }
                if let font { storage.addAttribute(.font, value: font, range: lineRange) }
                if line.hasPrefix("> ") {
                    storage.addAttribute(.foregroundColor, value: NSColor.secondaryLabelColor, range: lineRange)
                }
            }

            for pattern in [#"\[\[asset:[^\]]+\]\]"#, #"\[[^\]]+\]\(https?://[^\)]*\)"#] {
                if let regex = try? NSRegularExpression(pattern: pattern) {
                    regex.enumerateMatches(in: storage.string, range: all) { match, _, _ in
                        guard let range = match?.range else { return }
                        storage.addAttributes([.foregroundColor: NSColor.controlAccentColor], range: range)
                    }
                }
            }
            storage.endEditing()
            view.typingAttributes = [.font: NSFont.systemFont(ofSize: 16), .foregroundColor: NSColor.labelColor]
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
