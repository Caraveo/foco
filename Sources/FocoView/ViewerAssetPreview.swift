import AppKit
import AVKit
import PDFKit
import SwiftUI

struct ViewerAssetCard: View {
    let asset: ViewerAsset
    @ObservedObject var document: ViewerDocument
    @State private var localURL: URL?

    var body: some View {
        VStack(spacing: 0) {
            preview
            HStack(spacing: 8) {
                Image(systemName: assetIcon)
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
                Text(asset.filename)
                    .font(.system(size: 12, weight: .medium))
                    .lineLimit(1)
                Spacer()
                if let byteSize = asset.byteSize {
                    Text(ByteCountFormatter.string(fromByteCount: byteSize, countStyle: .file))
                        .font(.system(size: 10))
                        .foregroundStyle(.tertiary)
                }
                if let localURL {
                    Button {
                        NSWorkspace.shared.open(localURL)
                    } label: {
                        Image(systemName: "arrow.up.forward.app")
                            .font(.system(size: 11))
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(.secondary)
                    .help("Open extracted read-only copy")
                }
            }
            .padding(.horizontal, 12)
            .frame(height: 38)
            .background(Color.primary.opacity(0.025))
        }
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.primary.opacity(0.10)))
        .task(id: asset.id) {
            localURL = await document.materialize(asset)
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
                        .frame(maxWidth: .infinity, maxHeight: 430)
                        .background(Color.black.opacity(0.025))
                } else {
                    unavailable
                }
            case "pdf":
                ViewerPDFPreview(url: localURL)
                    .frame(height: 430)
            case "video":
                ViewerVideoPreview(url: localURL)
                    .frame(height: 400)
                    .background(Color.black)
            case "audio":
                ViewerVideoPreview(url: localURL, audioOnly: true)
                    .frame(height: 88)
                    .background(Color.primary.opacity(0.035))
            default:
                genericFile
            }
        } else {
            ProgressView()
                .controlSize(.small)
                .frame(maxWidth: .infinity)
                .frame(height: placeholderHeight)
        }
    }

    private var genericFile: some View {
        HStack(spacing: 16) {
            Image(systemName: assetIcon)
                .font(.system(size: 30, weight: .light))
                .foregroundStyle(Color.accentColor)
                .frame(width: 54, height: 54)
                .background(Color.accentColor.opacity(0.10), in: RoundedRectangle(cornerRadius: 10))
            VStack(alignment: .leading, spacing: 4) {
                Text(asset.filename)
                    .font(.system(size: 14, weight: .semibold))
                    .lineLimit(1)
                Text("Stored inside this bulb")
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
            }
            Spacer()
        }
        .padding(18)
        .frame(height: 118)
    }

    private var unavailable: some View {
        ContentUnavailableView("Preview unavailable", systemImage: assetIcon)
            .frame(height: 150)
    }

    private var placeholderHeight: CGFloat {
        switch asset.mediaType.lowercased() {
        case "video": 400
        case "pdf", "image": 360
        case "audio": 88
        default: 118
        }
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

private struct ViewerPDFPreview: NSViewRepresentable {
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

private struct ViewerVideoPreview: NSViewRepresentable {
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
