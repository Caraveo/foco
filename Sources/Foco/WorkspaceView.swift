import SwiftUI
import UniformTypeIdentifiers

struct WorkspaceView: View {
    @ObservedObject var document: VaultDocument
    let fileURL: URL?
    @State private var selectedPageID: VaultPage.ID?
    @State private var showingImporter = false
    @State private var pendingKind: InsertKind?
    @State private var pendingInsertionOffset: Int?
    @State private var sidebarVisible = true
    @State private var isDropTargeted = false

    var body: some View {
        HStack(spacing: 0) {
            if sidebarVisible {
                VaultSidebar(
                    title: Binding(get: { document.manifest.title }, set: document.renameDocument),
                    pages: document.manifest.pages,
                    selectedPageID: $selectedPageID,
                    addPage: { category in addPage(category: category) },
                    deletePage: delete
                )
                .frame(width: 248)
                .transition(.move(edge: .leading).combined(with: .opacity))
            }

            VStack(spacing: 0) {
                topBar
                Divider().overlay(FocoTheme.hairline)
                if document.currentPage != nil {
                    EditorView(
                        page: Binding(
                            get: { document.currentPage ?? VaultPage(title: "Untitled", content: "") },
                            set: document.updateCurrentPage
                        ),
                        assets: document.currentAssets,
                        assetURL: document.materialize,
                        onInsertAsset: requestAsset,
                        onImportEmbeddedAsset: { url in
                            do {
                                return try await document.importAsset(
                                    from: url,
                                    mediaType: InsertKind.image.label,
                                    insertBlockToken: false
                                )
                            } catch {
                                NSApp.presentError(error)
                                return nil
                            }
                        },
                        onDeleteAsset: document.deleteAsset
                    )
                        .id(document.currentPage?.id)
                } else {
                    ContentUnavailableView("Choose a page", systemImage: "doc.text")
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            }
            .background(FocoTheme.canvas)
        }
        .frame(minWidth: 900, minHeight: 620)
        .animation(.easeInOut(duration: 0.18), value: sidebarVisible)
        .overlay {
            if isDropTargeted {
                DropFilesOverlay()
                    .padding(18)
                    .transition(.opacity.combined(with: .scale(scale: 0.985)))
            }
        }
        .dropDestination(
            for: URL.self,
            action: { urls, _ in importDroppedFiles(urls) },
            isTargeted: { isDropTargeted = $0 }
        )
        .onAppear {
            document.adoptFileURL(fileURL)
            selectedPageID = selectedPageID ?? document.manifest.pages.first?.id
            document.selectPage(selectedPageID)
        }
        .onChange(of: fileURL) { _, newURL in
            document.adoptFileURL(newURL)
            selectedPageID = document.manifest.pages.first?.id
            document.selectPage(selectedPageID)
        }
        .onChange(of: selectedPageID) { _, pageID in document.selectPage(pageID) }
        .fileImporter(isPresented: $showingImporter, allowedContentTypes: allowedTypes) { result in
            guard case .success(let url) = result, let kind = pendingKind else { return }
            let insertionOffset = pendingInsertionOffset
            pendingKind = nil
            pendingInsertionOffset = nil
            importFile(
                url,
                as: kind == .file ? InsertKind.detected(for: url) : kind,
                insertionUTF16Offset: insertionOffset
            )
        }
    }

    private var topBar: some View {
        HStack(spacing: 8) {
            FocoIconButton(icon: "sidebar.left", help: sidebarVisible ? "Hide sidebar" : "Show sidebar") {
                sidebarVisible.toggle()
            }
            if !sidebarVisible {
                FocoMark(size: 22)
            }
            Text(currentPageTitle)
                .font(.system(size: 13, weight: .medium))
                .lineLimit(1)
            Spacer()
        }
        .padding(.horizontal, 12)
        .frame(height: 45)
        .background(FocoTheme.canvas)
    }

    private var currentPageTitle: String {
        guard let page = document.currentPage else { return "Foco" }
        let title = page.title
        return title.isEmpty ? "Untitled" : title
    }
    private var allowedTypes: [UTType] {
        switch pendingKind {
        case .pdf: [.pdf]
        case .image: [.image]
        case .video: [.movie, .video]
        case .audio: [.audio]
        default: [.data]
        }
    }
    private func addPage(category: String? = nil) {
        let page = document.addPage(category: category)
        selectedPageID = page.id
    }
    private func delete(_ page: VaultPage) {
        document.deletePage(page)
        selectedPageID = document.manifest.pages.first?.id
    }
    private func requestAsset(_ kind: InsertKind, insertionUTF16Offset: Int) {
        pendingKind = kind
        pendingInsertionOffset = insertionUTF16Offset
        showingImporter = true
    }
    private func importDroppedFiles(_ urls: [URL]) -> Bool {
        let files = urls.filter { url in
            guard url.isFileURL else { return false }
            return (try? url.resourceValues(forKeys: [.isRegularFileKey]).isRegularFile) == true
        }
        guard !files.isEmpty, document.currentPage != nil else { return false }
        for file in files { importFile(file, as: InsertKind.detected(for: file), insertionUTF16Offset: nil) }
        return true
    }

    private func importFile(_ url: URL, as kind: InsertKind, insertionUTF16Offset: Int?) {
        Task {
            do {
                _ = try await document.importAsset(
                    from: url,
                    mediaType: kind.label,
                    insertionUTF16Offset: insertionUTF16Offset
                )
            } catch {
                NSApp.presentError(error)
            }
        }
    }
}

private struct DropFilesOverlay: View {
    var body: some View {
        VStack(spacing: 10) {
            Image(systemName: "arrow.down.doc.fill")
                .font(.system(size: 28, weight: .medium))
            Text("Drop files to add them")
                .font(.system(size: 15, weight: .semibold))
            Text("Images, PDFs, video, and audio are detected automatically")
                .font(.system(size: 12))
                .foregroundStyle(.secondary)
        }
        .foregroundStyle(.primary)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 14))
        .overlay {
            RoundedRectangle(cornerRadius: 14)
                .stroke(FocoTheme.accent, style: StrokeStyle(lineWidth: 2, dash: [7, 5]))
        }
        .allowsHitTesting(false)
    }
}

private struct VaultSidebar: View {
    @Binding var title: String
    let pages: [VaultPage]
    @Binding var selectedPageID: VaultPage.ID?
    let addPage: (String?) -> Void
    let deletePage: (VaultPage) -> Void

    private var categories: [String] {
        var cats = Set<String>()
        for page in pages {
            let cat = page.category?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            cats.insert(cat.isEmpty ? "General" : cat)
        }
        if cats.isEmpty {
            cats.insert("General")
        }
        return cats.sorted()
    }

    private func pages(for category: String) -> [VaultPage] {
        pages.filter { page in
            let cat = page.category?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            let mappedCat = cat.isEmpty ? "General" : cat
            return mappedCat.localizedCaseInsensitiveCompare(category) == .orderedSame
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 9) {
                FocoMark()
                TextField("Vault name", text: $title)
                    .textFieldStyle(.plain)
                    .font(.system(size: 14, weight: .semibold))
                FocoIconButton(icon: "square.and.pencil", help: "New page", action: { addPage(nil) })
            }
            .padding(.horizontal, 10)
            .frame(height: 48)

            ScrollView {
                LazyVStack(spacing: 16) {
                    ForEach(categories, id: \.self) { category in
                        VStack(alignment: .leading, spacing: 2) {
                            HStack {
                                Text(category.uppercased())
                                    .font(.system(size: 10, weight: .semibold))
                                    .tracking(0.5)
                                    .foregroundStyle(.tertiary)
                                Spacer()
                                FocoIconButton(icon: "plus", help: "New page in \(category)") {
                                    addPage(category)
                                }
                            }
                            .padding(.leading, 6)
                            .padding(.trailing, 1)

                            ForEach(pages(for: category)) { page in
                                SidebarPageRow(
                                    page: page,
                                    selected: selectedPageID == page.id,
                                    select: { selectedPageID = page.id },
                                    delete: { deletePage(page) }
                                )
                            }
                        }
                    }
                }
                .padding(.horizontal, 7)
                .padding(.top, 12)
            }
        }
        .background(FocoTheme.sidebar)
        .overlay(alignment: .trailing) { Rectangle().fill(FocoTheme.hairline).frame(width: 1) }
    }
}

private struct SidebarAction: View {
    let icon: String
    let title: String
    var shortcut: String? = nil
    @State private var hovered = false

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: icon).font(.system(size: 13)).frame(width: 16)
            Text(title).font(.system(size: 13))
            Spacer()
            if let shortcut { Text(shortcut).font(.system(size: 10)).foregroundStyle(.tertiary) }
        }
        .foregroundStyle(.secondary)
        .padding(.horizontal, 8)
        .frame(height: 30)
        .background(hovered ? FocoTheme.hover : .clear, in: RoundedRectangle(cornerRadius: 6))
        .contentShape(Rectangle())
        .onHover { hovered = $0 }
    }
}

private struct SidebarPageRow: View {
    let page: VaultPage
    let selected: Bool
    let select: () -> Void
    let delete: () -> Void
    @State private var hovered = false

    var body: some View {
        Button(action: select) {
            HStack(spacing: 8) {
                Text(page.title.isEmpty ? "Untitled" : page.title)
                    .font(.system(size: 13))
                    .lineLimit(1)
                Spacer(minLength: 0)
                if hovered {
                    Image(systemName: "ellipsis")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(.secondary)
                }
            }
            .foregroundStyle(.primary.opacity(0.82))
            .padding(.horizontal, 8)
            .frame(height: 30)
            .background(selected ? FocoTheme.selected : (hovered ? FocoTheme.hover : .clear), in: RoundedRectangle(cornerRadius: 6))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { hovered = $0 }
        .contextMenu { Button("Delete", role: .destructive, action: delete) }
    }
}
