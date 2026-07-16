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
        var calendar = FocoStructuredBlock(kind: .calendar)
        calendar.calendarEvents.append(FocoCalendarEvent(
            date: FocoBlockDate.dayKey(Date()),
            title: "Viewer event"
        ))
        let structuredBlocks = [
            FocoStructuredBlock(kind: .table),
            FocoStructuredBlock(kind: .board),
            calendar,
            FocoStructuredBlock(kind: .list),
            FocoStructuredBlock(kind: .gallery),
            FocoStructuredBlock(kind: .timeline)
        ]
        if var sourcePage = sourceDocument.currentPage {
            for block in structuredBlocks {
                let insertion = FocoStructuredBlockSyntax.inserting(
                    block,
                    into: sourcePage.content,
                    replacing: NSRange(location: sourcePage.content.utf16.count, length: 0)
                )
                sourcePage.content = insertion.content
            }
            sourcePage.blocks = structuredBlocks
            sourcePage.blockIDs = structuredBlocks.map(\.id)
            sourceDocument.updateCurrentPage(sourcePage)
        }

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
        precondition(page.content.contains("[[asset:\(asset.id.uuidString)|"))
        precondition(page.blocks.count == 6)
        precondition(page.blocks.first(where: { $0.kind == .calendar })?.calendarEvents.first?.title == "Viewer event")
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
