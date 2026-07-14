import SwiftUI
import UniformTypeIdentifiers

struct WorkspaceView: View {
    @Binding var document: VaultDocument
    @State private var selectedPageID: VaultPage.ID?
    @State private var showingImporter = false
    @State private var pendingKind: InsertKind?
    @State private var sidebarVisible = true

    var body: some View {
        HStack(spacing: 0) {
            if sidebarVisible {
                VaultSidebar(
                    title: $document.manifest.title,
                    pages: document.manifest.pages,
                    selectedPageID: $selectedPageID,
                    addPage: addPage,
                    deletePage: delete
                )
                .frame(width: 248)
                .transition(.move(edge: .leading).combined(with: .opacity))
            }

            VStack(spacing: 0) {
                topBar
                Divider().overlay(FocoTheme.hairline)
                if let index = selectedIndex {
                    EditorView(
                        page: $document.manifest.pages[index],
                        assets: document.manifest.assets,
                        assetData: document.assetData,
                        onInsertAsset: requestAsset
                    )
                        .id(document.manifest.pages[index].id)
                } else {
                    ContentUnavailableView("Choose a page", systemImage: "doc.text")
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            }
            .background(FocoTheme.canvas)
        }
        .frame(minWidth: 900, minHeight: 620)
        .animation(.easeInOut(duration: 0.18), value: sidebarVisible)
        .onAppear { selectedPageID = selectedPageID ?? document.manifest.pages.first?.id }
        .fileImporter(isPresented: $showingImporter, allowedContentTypes: allowedTypes) { result in
            guard case .success(let url) = result, let kind = pendingKind else { return }
            do {
                let asset = try document.importAsset(from: url, mediaType: kind.label)
                attach(asset)
            } catch { NSApp.presentError(error) }
            pendingKind = nil
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
            Image(systemName: "chevron.right")
                .font(.system(size: 9, weight: .semibold))
                .foregroundStyle(.tertiary)
            Text("Private")
                .font(.system(size: 12))
                .foregroundStyle(.secondary)
            Spacer()
            Text("Saved locally")
                .font(.system(size: 11))
                .foregroundStyle(.tertiary)
            FocoIconButton(icon: "ellipsis", help: "More")
        }
        .padding(.horizontal, 12)
        .frame(height: 45)
        .background(FocoTheme.canvas)
    }

    private var currentPageTitle: String {
        guard let index = selectedIndex else { return "Foco" }
        let title = document.manifest.pages[index].title
        return title.isEmpty ? "Untitled" : title
    }
    private var selectedIndex: Int? { document.manifest.pages.firstIndex { $0.id == selectedPageID } }
    private var allowedTypes: [UTType] {
        switch pendingKind {
        case .pdf: [.pdf]
        case .image: [.image]
        case .video: [.movie, .video]
        default: [.data]
        }
    }
    private func addPage() {
        let page = VaultPage(title: "Untitled", content: "")
        document.manifest.pages.append(page)
        selectedPageID = page.id
    }
    private func delete(_ page: VaultPage) {
        guard document.manifest.pages.count > 1 else { return }
        document.manifest.pages.removeAll { $0.id == page.id }
        selectedPageID = document.manifest.pages.first?.id
    }
    private func requestAsset(_ kind: InsertKind) { pendingKind = kind; showingImporter = true }
    private func attach(_ asset: VaultAsset) {
        guard let index = selectedIndex else { return }
        if document.manifest.pages[index].assetIDs == nil {
            document.manifest.pages[index].assetIDs = []
        }
        document.manifest.pages[index].assetIDs?.append(asset.id)
    }
}

private struct VaultSidebar: View {
    @Binding var title: String
    let pages: [VaultPage]
    @Binding var selectedPageID: VaultPage.ID?
    let addPage: () -> Void
    let deletePage: (VaultPage) -> Void

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 9) {
                FocoMark()
                TextField("Vault name", text: $title)
                    .textFieldStyle(.plain)
                    .font(.system(size: 14, weight: .semibold))
                FocoIconButton(icon: "square.and.pencil", help: "New page", action: addPage)
            }
            .padding(.horizontal, 10)
            .frame(height: 48)

            VStack(spacing: 1) {
                SidebarAction(icon: "magnifyingglass", title: "Search", shortcut: "⌘K")
                SidebarAction(icon: "clock.arrow.circlepath", title: "Updates")
            }
            .padding(.horizontal, 7)

            HStack {
                Text("PRIVATE")
                    .font(.system(size: 10, weight: .semibold))
                    .tracking(0.5)
                    .foregroundStyle(.tertiary)
                Spacer()
                FocoIconButton(icon: "plus", help: "New page", action: addPage)
            }
            .padding(.leading, 13)
            .padding(.trailing, 8)
            .padding(.top, 22)
            .padding(.bottom, 5)

            ScrollView {
                LazyVStack(spacing: 1) {
                    ForEach(pages) { page in
                        SidebarPageRow(
                            page: page,
                            selected: selectedPageID == page.id,
                            select: { selectedPageID = page.id },
                            delete: { deletePage(page) }
                        )
                    }
                }
                .padding(.horizontal, 7)
            }

            VStack(spacing: 1) {
                SidebarAction(icon: "tray.full", title: "All attachments")
                SidebarAction(icon: "gearshape", title: "Settings")
            }
            .padding(7)
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
                Image(systemName: "doc.text")
                    .font(.system(size: 13))
                    .foregroundStyle(.secondary)
                    .frame(width: 17)
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
