import AVKit
import PDFKit
import SwiftUI
import UniformTypeIdentifiers

struct AssetPreviewGallery: View {
    let assets: [VaultAsset]
    let assetData: [String: Data]

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            ForEach(assets) { asset in
                AssetPreviewCard(asset: asset, data: assetData[asset.storedFilename])
            }
        }
    }
}

private struct AssetPreviewCard: View {
    let asset: VaultAsset
    let data: Data?

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
        if let data {
            switch asset.mediaType.lowercased() {
            case "image":
                if let image = NSImage(data: data) {
                    Image(nsImage: image)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(maxWidth: .infinity, maxHeight: 460)
                        .background(Color.black.opacity(0.025))
                } else {
                    unavailable
                }
            case "pdf":
                LocalPDFPreview(data: data)
                    .frame(height: 420)
            case "video":
                LocalVideoPreview(data: data, filename: asset.storedFilename)
                    .frame(height: 390)
                    .background(Color.black)
            default:
                genericFile(data: data)
            }
        } else {
            unavailable
        }
    }

    private func genericFile(data: Data) -> some View {
        HStack(spacing: 16) {
            Image(systemName: assetIcon)
                .font(.system(size: 30, weight: .light))
                .foregroundStyle(FocoTheme.accent)
                .frame(width: 54, height: 54)
                .background(FocoTheme.accent.opacity(0.10), in: RoundedRectangle(cornerRadius: 10))
            VStack(alignment: .leading, spacing: 4) {
                Text(asset.filename).font(.system(size: 14, weight: .semibold)).lineLimit(1)
                Text(ByteCountFormatter.string(fromByteCount: Int64(data.count), countStyle: .file))
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
        case "pdf": "doc.richtext"
        default: "doc"
        }
    }
}

private struct LocalPDFPreview: NSViewRepresentable {
    let data: Data

    func makeNSView(context: Context) -> PDFView {
        let view = PDFView()
        view.autoScales = true
        view.displayMode = .singlePageContinuous
        view.displayDirection = .vertical
        view.displaysPageBreaks = true
        view.backgroundColor = .textBackgroundColor
        view.document = PDFDocument(data: data)
        return view
    }

    func updateNSView(_ view: PDFView, context: Context) {
        guard view.document?.dataRepresentation() != data else { return }
        view.document = PDFDocument(data: data)
    }
}

private struct LocalVideoPreview: NSViewRepresentable {
    let data: Data
    let filename: String

    func makeCoordinator() -> Coordinator { Coordinator() }

    func makeNSView(context: Context) -> AVPlayerView {
        let view = AVPlayerView()
        view.controlsStyle = .floating
        view.videoGravity = .resizeAspect
        view.showsFullScreenToggleButton = true
        view.allowsPictureInPicturePlayback = true
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
        guard coordinator.loadedFilename != filename else { return }
        do {
            let folder = FileManager.default.temporaryDirectory.appendingPathComponent("FocoPreviews", isDirectory: true)
            try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
            let url = folder.appendingPathComponent(filename)
            if !FileManager.default.fileExists(atPath: url.path) {
                try data.write(to: url, options: .atomic)
            }
            view.player = AVPlayer(url: url)
            coordinator.loadedFilename = filename
        } catch {
            view.player = nil
        }
    }

    final class Coordinator {
        var loadedFilename: String?
    }
}
