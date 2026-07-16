import AppKit
import SwiftUI
import UniformTypeIdentifiers

extension UTType {
    static let focoViewerBulb = UTType("app.foco.bulb")
        ?? UTType(filenameExtension: "bulb", conformingTo: .data)!
}

extension Notification.Name {
    static let focoViewerOpenDocument = Notification.Name("FocoViewerOpenDocument")
}

@main
struct FocoViewApp: App {
    init() {
        NSApplication.shared.setActivationPolicy(.regular)
        DispatchQueue.main.async { NSApplication.shared.activate(ignoringOtherApps: true) }
    }

    var body: some Scene {
        WindowGroup {
            ViewerRootView()
        }
        .defaultSize(width: 1060, height: 720)
        .commands {
            CommandGroup(replacing: .newItem) {
                Button("Open Bulb…") {
                    NotificationCenter.default.post(name: .focoViewerOpenDocument, object: nil)
                }
                .keyboardShortcut("o")
            }
            CommandGroup(replacing: .saveItem) { }
        }
    }
}

private struct ViewerRootView: View {
    @StateObject private var document = ViewerDocument()
    @State private var showingImporter = false
    @State private var dropTargeted = false

    var body: some View {
        NavigationSplitView {
            sidebar
                .navigationSplitViewColumnWidth(min: 190, ideal: 224, max: 280)
        } detail: {
            detail
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color(nsColor: .textBackgroundColor))
        }
        .frame(minWidth: 780, minHeight: 540)
        .navigationTitle(document.title)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    showingImporter = true
                } label: {
                    Label("Open Bulb", systemImage: "folder")
                }
                .help("Open another .bulb file")
            }
        }
        .fileImporter(
            isPresented: $showingImporter,
            allowedContentTypes: [.focoViewerBulb],
            allowsMultipleSelection: false
        ) { result in
            switch result {
            case .success(let urls):
                if let url = urls.first { document.open(url) }
            case .failure(let error):
                document.errorMessage = error.localizedDescription
            }
        }
        .onOpenURL { document.open($0) }
        .onReceive(NotificationCenter.default.publisher(for: .focoViewerOpenDocument)) { _ in
            showingImporter = true
        }
        .dropDestination(for: URL.self) { urls, _ in
            guard let url = urls.first(where: { $0.pathExtension.lowercased() == "bulb" }) else { return false }
            document.open(url)
            return true
        } isTargeted: { dropTargeted = $0 }
        .overlay {
            if dropTargeted {
                RoundedRectangle(cornerRadius: 14)
                    .fill(.regularMaterial)
                    .overlay {
                        VStack(spacing: 10) {
                            Image(systemName: "eye.fill").font(.system(size: 28))
                            Text("Open this bulb").font(.system(size: 15, weight: .semibold))
                        }
                    }
                    .overlay {
                        RoundedRectangle(cornerRadius: 14)
                            .stroke(Color.accentColor, style: StrokeStyle(lineWidth: 2, dash: [7, 5]))
                    }
                    .padding(18)
                    .allowsHitTesting(false)
            }
        }
        .alert("Couldn’t Open Bulb", isPresented: Binding(
            get: { document.errorMessage != nil },
            set: { if !$0 { document.errorMessage = nil } }
        )) {
            Button("OK", role: .cancel) { document.errorMessage = nil }
        } message: {
            Text(document.errorMessage ?? "Unknown error")
        }
    }

    private var sidebar: some View {
        let manifest = document.manifest
        let categories: [String] = {
            guard let manifest else { return [] }
            var cats = Set<String>()
            for page in manifest.pages {
                let cat = page.category?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
                cats.insert(cat.isEmpty ? "General" : cat)
            }
            if cats.isEmpty {
                cats.insert("General")
            }
            return cats.sorted()
        }()

        func pages(for category: String) -> [ViewerPageSummary] {
            guard let manifest else { return [] }
            return manifest.pages.filter { page in
                let cat = page.category?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
                let mappedCat = cat.isEmpty ? "General" : cat
                return mappedCat.localizedCaseInsensitiveCompare(category) == .orderedSame
            }
        }

        return VStack(spacing: 0) {
            HStack(spacing: 10) {
                ViewerMark(size: 28)
                VStack(alignment: .leading, spacing: 1) {
                    Text(manifest?.title ?? "Foco View")
                        .font(.system(size: 14, weight: .semibold))
                        .lineLimit(1)
                    Text("READ ONLY")
                        .font(.system(size: 8, weight: .bold))
                        .tracking(0.7)
                        .foregroundStyle(.secondary)
                }
                Spacer()
            }
            .padding(.horizontal, 12)
            .frame(height: 54)

            Divider()

            if manifest != nil {
                ScrollView {
                    LazyVStack(spacing: 16) {
                        ForEach(categories, id: \.self) { category in
                            VStack(alignment: .leading, spacing: 2) {
                                HStack {
                                    Text(category.uppercased())
                                        .font(.system(size: 10, weight: .semibold))
                                        .tracking(0.5)
                                        .foregroundStyle(.secondary)
                                    Spacer()
                                }
                                .padding(.leading, 9)
                                .padding(.top, 4)

                                ForEach(pages(for: category)) { page in
                                    Button {
                                        document.selectPage(page.id)
                                    } label: {
                                        HStack(spacing: 9) {
                                            Image(systemName: "doc.text")
                                                .font(.system(size: 12))
                                                .foregroundStyle(.secondary)
                                            Text(page.title.isEmpty ? "Untitled" : page.title)
                                                .font(.system(size: 13))
                                                .lineLimit(1)
                                            Spacer()
                                        }
                                        .padding(.horizontal, 9)
                                        .frame(height: 32)
                                        .background(
                                            document.selectedPageID == page.id
                                                ? Color.primary.opacity(0.08)
                                                : .clear,
                                            in: RoundedRectangle(cornerRadius: 7)
                                        )
                                        .contentShape(Rectangle())
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                        }
                    }
                    .padding(7)
                }
            } else {
                Spacer()
                Text("No bulb open")
                    .font(.system(size: 12))
                    .foregroundStyle(.tertiary)
                Spacer()
            }

            Divider()
            HStack {
                Image(systemName: "lock.fill")
                Text("Viewing locally")
                Spacer()
            }
            .font(.system(size: 10, weight: .medium))
            .foregroundStyle(.tertiary)
            .padding(.horizontal, 12)
            .frame(height: 38)
        }
        .background(Color(nsColor: .windowBackgroundColor))
    }

    @ViewBuilder
    private var detail: some View {
        if document.isLoading {
            ProgressView("Opening locally…")
                .controlSize(.small)
        } else if let page = document.currentPage {
            ViewerPageView(page: page, document: document)
        } else {
            ContentUnavailableView {
                Label("Open a Foco Bulb", systemImage: "eye")
            } description: {
                Text("Read pages and play local media without editing the original file.")
            } actions: {
                Button("Open .bulb…") { showingImporter = true }
                    .buttonStyle(.borderedProminent)
            }
        }
    }
}

struct ViewerMark: View {
    var size: CGFloat = 30

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: size * 0.24)
                .fill(
                    LinearGradient(
                        colors: [.black, Color(red: 0.08, green: 0.12, blue: 0.15)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
            Image(systemName: "eye.fill")
                .font(.system(size: size * 0.43, weight: .medium))
                .foregroundStyle(.white)
        }
        .frame(width: size, height: size)
    }
}
