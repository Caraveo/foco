import AVKit
import PDFKit
import SwiftUI
import UniformTypeIdentifiers

extension VaultAsset {
    var inlinePreviewHeight: CGFloat {
        switch mediaType.lowercased() {
        case "video": 368
        case "pdf": 398
        case "image": 338
        case "audio": 120
        default: 142
        }
    }

    var previewContentHeight: CGFloat { max(82, inlinePreviewHeight - 38) }
}

struct AssetPreviewGallery: View {
    let assets: [VaultAsset]
    let assetURL: @Sendable (VaultAsset) -> URL?

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            ForEach(assets) { asset in
                AssetPreviewCard(asset: asset, materialize: { assetURL(asset) })
            }
        }
    }
}

struct AssetPreviewCard: View {
    let asset: VaultAsset
    let materialize: @Sendable () -> URL?
    var onDelete: (() -> Void)? = nil
    var onMoveUp: (() -> Void)? = nil
    var onMoveDown: (() -> Void)? = nil
    var dragProvider: (() -> NSItemProvider)? = nil
    @State private var localURL: URL?

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            preview
            HStack(spacing: 8) {
                dragHandle
                Image(systemName: assetIcon)
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
                Text(asset.filename)
                    .font(.system(size: 12, weight: .medium))
                    .lineLimit(1)
                Spacer()
                Text(asset.mediaType.uppercased())
                    .font(.system(size: 9, weight: .semibold))
                    .tracking(0.4)
                    .foregroundStyle(.tertiary)
                if let onMoveUp {
                    assetButton("arrow.up", help: "Move block up", action: onMoveUp)
                }
                if let onMoveDown {
                    assetButton("arrow.down", help: "Move block down", action: onMoveDown)
                }
                if let onDelete {
                    assetButton("trash", help: "Delete attachment", action: onDelete)
                }
            }
            .padding(.horizontal, 12)
            .frame(height: 38)
            .background(Color.primary.opacity(0.025))
        }
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.primary.opacity(0.10)))
        .contextMenu {
            if let onMoveUp { Button("Move Up", systemImage: "arrow.up", action: onMoveUp) }
            if let onMoveDown { Button("Move Down", systemImage: "arrow.down", action: onMoveDown) }
            if onMoveUp != nil || onMoveDown != nil { Divider() }
            if let onDelete { Button("Delete Attachment", systemImage: "trash", role: .destructive, action: onDelete) }
        }
    }

    @ViewBuilder
    private var preview: some View {
        if let localURL {
            switch asset.mediaType.lowercased() {
            case "image":
                if let image = NSImage(contentsOf: localURL) {
                    Image(nsImage: image)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(maxWidth: .infinity)
                        .frame(height: asset.previewContentHeight)
                        .background(Color.black.opacity(0.025))
                } else {
                    unavailable
                }
            case "pdf":
                LocalPDFPreview(url: localURL)
                    .frame(height: asset.previewContentHeight)
            case "video":
                LocalVideoPreview(url: localURL)
                    .frame(height: asset.previewContentHeight)
                    .background(Color.black)
            case "audio":
                LocalVideoPreview(url: localURL, audioOnly: true)
                    .frame(height: 82)
                    .background(Color.primary.opacity(0.035))
            default:
                genericFile
            }
        } else {
            ProgressView()
                .controlSize(.small)
                .frame(maxWidth: .infinity)
                .frame(height: asset.previewContentHeight)
                .task {
                    let materialize = materialize
                    localURL = await Task.detached(priority: .utility) { materialize() }.value
                }
        }
    }

    private var genericFile: some View {
        HStack(spacing: 16) {
            Image(systemName: assetIcon)
                .font(.system(size: 30, weight: .light))
                .foregroundStyle(FocoTheme.accent)
                .frame(width: 54, height: 54)
                .background(FocoTheme.accent.opacity(0.10), in: RoundedRectangle(cornerRadius: 10))
            VStack(alignment: .leading, spacing: 4) {
                Text(asset.filename).font(.system(size: 14, weight: .semibold)).lineLimit(1)
                Text(ByteCountFormatter.string(fromByteCount: asset.byteSize ?? 0, countStyle: .file))
                    .font(.system(size: 12)).foregroundStyle(.secondary)
            }
            Spacer()
        }
        .padding(18)
        .frame(height: asset.previewContentHeight)
    }

    private var unavailable: some View {
        ContentUnavailableView("Preview unavailable", systemImage: assetIcon)
            .frame(height: asset.previewContentHeight)
    }

    private var assetIcon: String {
        switch asset.mediaType.lowercased() {
        case "image": "photo"
        case "video": "play.rectangle"
        case "audio": "waveform"
        case "pdf": "doc.richtext"
        default: "doc"
        }
    }

    @ViewBuilder
    private var dragHandle: some View {
        if let dragProvider {
            Image(systemName: "square.grid.3x3.fill")
                .font(.system(size: 10))
                .foregroundStyle(.tertiary)
                .frame(width: 18, height: 24)
                .contentShape(Rectangle())
                .help("Drag to move this block")
                .onDrag(dragProvider)
        }
    }

    private func assetButton(_ icon: String, help: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: 10, weight: .semibold))
                .frame(width: 22, height: 22)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .foregroundStyle(.secondary)
        .help(help)
    }
}

private struct LocalPDFPreview: NSViewRepresentable {
    let url: URL

    func makeNSView(context: Context) -> PDFView {
        let view = PDFView()
        view.autoScales = true
        view.displayMode = .singlePageContinuous
        view.displayDirection = .vertical
        view.displaysPageBreaks = true
        view.backgroundColor = .textBackgroundColor
        view.document = PDFDocument(url: url)
        return view
    }

    func updateNSView(_ view: PDFView, context: Context) {
        guard view.document?.documentURL != url else { return }
        view.document = PDFDocument(url: url)
    }
}

private struct LocalVideoPreview: NSViewRepresentable {
    let url: URL
    var audioOnly = false

    func makeCoordinator() -> Coordinator { Coordinator() }

    func makeNSView(context: Context) -> AVPlayerView {
        let view = AVPlayerView()
        view.controlsStyle = audioOnly ? .inline : .floating
        view.videoGravity = .resizeAspect
        view.showsFullScreenToggleButton = !audioOnly
        view.allowsPictureInPicturePlayback = !audioOnly
        configure(view, coordinator: context.coordinator)
        return view
    }

    func updateNSView(_ view: AVPlayerView, context: Context) {
        configure(view, coordinator: context.coordinator)
    }

    static func dismantleNSView(_ view: AVPlayerView, coordinator: Coordinator) {
        view.player?.pause()
        view.player = nil
    }

    private func configure(_ view: AVPlayerView, coordinator: Coordinator) {
        guard coordinator.loadedURL != url else { return }
        view.player = AVPlayer(url: url)
        coordinator.loadedURL = url
    }

    final class Coordinator {
        var loadedURL: URL?
    }
}
