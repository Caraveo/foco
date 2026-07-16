import SwiftUI
import UniformTypeIdentifiers

extension UTType {
    static let focoBulb = UTType(filenameExtension: "bulb", conformingTo: .data)!
    static let focoVaultLegacy = UTType(filenameExtension: "vault", conformingTo: .package)!
}

@main
struct StructuredBlocksSmoke {
    static func main() throws {
        let document = VaultDocument()
        guard let pageID = document.manifest.pages.first?.id else { fatalError("Missing page") }
        document.selectPage(pageID)
        guard var page = document.currentPage else { fatalError("Missing selected page") }

        var calendar = FocoStructuredBlock(kind: .calendar)
        calendar.calendarEvents.append(FocoCalendarEvent(
            date: FocoBlockDate.dayKey(Date()),
            title: "Launch"
        ))
        let blocks = [
            FocoStructuredBlock(kind: .table),
            FocoStructuredBlock(kind: .board),
            calendar,
            FocoStructuredBlock(kind: .list),
            FocoStructuredBlock(kind: .gallery),
            FocoStructuredBlock(kind: .timeline)
        ]
        page.content = ""
        for block in blocks {
            let insertion = FocoStructuredBlockSyntax.inserting(
                block,
                into: page.content,
                replacing: NSRange(location: page.content.utf16.count, length: 0)
            )
            page.content = insertion.content
        }
        page.blocks = blocks
        page.blockIDs = blocks.map(\.id)
        precondition(
            FocoStructuredBlockSyntax.matches(in: page.content).map(\.kind) == FocoStructuredBlockKind.allCases
        )
        document.updateCurrentPage(page)

        let snapshot = try document.snapshot(contentType: .focoBulb)
        let reopened = VaultDocument()
        reopened.adoptFileURL(snapshot)
        reopened.selectPage(pageID)
        precondition(reopened.currentPage?.blocks?.count == FocoStructuredBlockKind.allCases.count)
        precondition(
            reopened.currentPage?.blocks?.first(where: { $0.kind == .calendar })?
                .calendarEvents.first?.title == "Launch"
        )

        if CommandLine.arguments.count > 1 {
            let destination = URL(fileURLWithPath: CommandLine.arguments[1])
            try? FileManager.default.removeItem(at: destination)
            try FileManager.default.copyItem(at: snapshot, to: destination)
        }
        print("Structured block smoke passed: all six views persisted and reopened from separate Blocks/ entries.")
    }
}
