import SwiftUI
import UniformTypeIdentifiers

extension UTType {
    static let focoBulb = UTType(filenameExtension: "bulb", conformingTo: .data)!
    static let focoVaultLegacy = UTType(filenameExtension: "vault", conformingTo: .package)!
}

@main
struct ViewerSmoke {
    static func main() async throws {
        let sourceDocument = VaultDocument()
        guard let pageID = sourceDocument.manifest.pages.first?.id else { fatalError("Missing page") }
        sourceDocument.selectPage(pageID)

        let sourceMedia = FileManager.default.temporaryDirectory
            .appendingPathComponent("foco-viewer-smoke.mp4")
        try Data(repeating: 0x42, count: 512 * 1024 + 17).write(to: sourceMedia)
        defer { try? FileManager.default.removeItem(at: sourceMedia) }

        let asset = try await sourceDocument.importAsset(
            from: sourceMedia,
            mediaType: "Video",
            insertionUTF16Offset: 0
        )
        let bulb = try sourceDocument.snapshot(contentType: .focoBulb)
        let bytesBeforeViewing = try Data(contentsOf: bulb)

        let viewer = try ViewerArchive(url: bulb)
        let manifest = try viewer.loadManifest()
        precondition(manifest.pages.first?.id == pageID)
        precondition(manifest.assets.first?.id == asset.id)

        let page = try viewer.loadPage(pageID)
        precondition(page.contains("[[asset:\(asset.id.uuidString)|"))
        guard let viewerAsset = manifest.assets.first,
              try viewer.materialize(viewerAsset).resourceValues(forKeys: [.fileSizeKey]).fileSize == 512 * 1024 + 17 else {
            fatalError("Viewer failed to materialize the asset")
        }

        let bytesAfterViewing = try Data(contentsOf: bulb)
        precondition(bytesBeforeViewing == bytesAfterViewing)
        if CommandLine.arguments.count > 1 {
            let destination = URL(fileURLWithPath: CommandLine.arguments[1])
            try? FileManager.default.removeItem(at: destination)
            try FileManager.default.copyItem(at: bulb, to: destination)
        }
        print("Viewer smoke check passed: manifest/page/asset read lazily and the .bulb stayed byte-for-byte unchanged.")
    }
}
