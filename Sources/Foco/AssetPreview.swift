import AVKit
import PDFKit
import SwiftUI
import UniformTypeIdentifiers

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

private struct AssetPreviewCard: View {
    let asset: VaultAsset
    let materialize: @Sendable () -> URL?
    @State private var localURL: URL?

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            preview
            HStack(spacing: 8) {
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
            }
            .padding(.horizontal, 12)
            .frame(height: 38)
            .background(Color.primary.opacity(0.025))
        }
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.primary.opacity(0.10)))
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
                        .frame(maxWidth: .infinity, maxHeight: 460)
                        .background(Color.black.opacity(0.025))
                } else {
                    unavailable
                }
            case "pdf":
                LocalPDFPreview(url: localURL)
                    .frame(height: 420)
            case "video":
                LocalVideoPreview(url: localURL)
                    .frame(height: 390)
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
                .frame(height: 150)
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
    }

    private var unavailable: some View {
        ContentUnavailableView("Preview unavailable", systemImage: assetIcon)
            .frame(height: 150)
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
