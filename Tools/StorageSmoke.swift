import SwiftUI
import UniformTypeIdentifiers

extension UTType {
    static let focoBulb = UTType(filenameExtension: "bulb", conformingTo: .data)!
    static let focoVaultLegacy = UTType(filenameExtension: "vault", conformingTo: .package)!
}

@main
struct StorageSmoke {
    static func main() async throws {
        let document = VaultDocument()
        guard let pageID = document.manifest.pages.first?.id else { fatalError("Missing page") }
        document.selectPage(pageID)

        var table = FocoStructuredBlock(kind: .table)
        table.title = "Working table"
        table.tableRows[0].cells[1] = "In progress"
        guard var pageWithTable = document.currentPage else { fatalError("Missing selected page") }
        let tableInsertion = FocoStructuredBlockSyntax.inserting(
            table,
            into: pageWithTable.content,
            replacing: NSRange(location: pageWithTable.content.utf16.count, length: 0)
        )
        pageWithTable.content = tableInsertion.content
        pageWithTable.blocks = [table]
        pageWithTable.blockIDs = [table.id]
        document.updateCurrentPage(pageWithTable)

        let source = FileManager.default.temporaryDirectory.appendingPathComponent("foco-storage-smoke.mov")
        FileManager.default.createFile(atPath: source.path, contents: nil)
        let writer = try FileHandle(forWritingTo: source)
        let megabyte = Data(repeating: 0x5A, count: 1_048_576)
        for _ in 0..<3 { try writer.write(contentsOf: megabyte) }
        try writer.write(contentsOf: Data(repeating: 0x2A, count: 123))
        try writer.close()
        defer { try? FileManager.default.removeItem(at: source) }

        let asset = try await document.importAsset(from: source, mediaType: "Video", insertionUTF16Offset: 0)
        precondition(document.currentPage?.content.hasPrefix(AssetBlockSyntax.token(for: asset)) == true)
        let snapshot = try document.snapshot(contentType: .focoBulb)
        let values = try snapshot.resourceValues(forKeys: [.isRegularFileKey, .isDirectoryKey])
        precondition(values.isRegularFile == true && values.isDirectory != true)

        let file = try FileHandle(forReadingFrom: snapshot)
        let header = try file.read(upToCount: 2)
        try file.close()
        precondition(header == Data([0x50, 0x4B]))

        let listing = try run("/usr/bin/unzip", ["-Z1", snapshot.path])
        precondition(listing.contains("manifest.json"))
        precondition(listing.contains("Pages/\(pageID.uuidString).md"))
        precondition(listing.contains("Assets/\(asset.storedFilename)"))
        precondition(listing.contains("Blocks/\(table.id.uuidString).json"))

        // The first save of an untitled document has no original contents URL.
        // Exercise that Save As path separately from overwriting an open file.
        let firstSave = FileManager.default.temporaryDirectory
            .appendingPathComponent("foco-first-save-smoke.bulb")
        try? FileManager.default.removeItem(at: firstSave)
        defer { try? FileManager.default.removeItem(at: firstSave) }
        let firstSaveWrapper = try FileWrapper(url: snapshot, options: [])
        try firstSaveWrapper.write(to: firstSave, options: .atomic, originalContentsURL: nil)
        let firstSaveValues = try firstSave.resourceValues(forKeys: [.isRegularFileKey, .isDirectoryKey])
        precondition(firstSave.pathExtension == "bulb")
        precondition(firstSaveValues.isRegularFile == true && firstSaveValues.isDirectory != true)
        _ = try run("/usr/bin/unzip", ["-t", firstSave.path])

        guard let preview = document.materialize(asset) else { fatalError("Could not extract asset") }
        let previewSize = try preview.resourceValues(forKeys: [.fileSizeKey]).fileSize
        precondition(previewSize == 3 * 1_048_576 + 123)

        // Reproduce the real DocumentGroup lifecycle: open an existing bulb,
        // edit its private working copy, then atomically replace the external
        // destination. The source must remain untouched until the write.
        let external = FileManager.default.temporaryDirectory
            .appendingPathComponent("foco-existing-document-smoke.bulb")
        try? FileManager.default.removeItem(at: external)
        try FileManager.default.copyItem(at: snapshot, to: external)
        defer { try? FileManager.default.removeItem(at: external) }
        let externalBeforeEdit = try Data(contentsOf: external)
        let coordinatedSnapshot = try {
            let reopened = VaultDocument()
            reopened.adoptFileURL(external)
            reopened.selectPage(pageID)
            guard var reopenedPage = reopened.currentPage else { fatalError("Could not reopen saved bulb") }
            guard reopenedPage.blocks?.first?.tableRows.first?.cells[1] == "In progress" else {
                fatalError("Structured table did not reopen from Blocks/")
            }
            reopenedPage.content += "\nSave coordination marker"
            reopened.updateCurrentPage(reopenedPage)
            return try reopened.snapshot(contentType: .focoBulb)
        }()
        precondition(coordinatedSnapshot.standardizedFileURL != external.standardizedFileURL)
        precondition(FileManager.default.fileExists(atPath: coordinatedSnapshot.path))
        let externalAfterEdit = try Data(contentsOf: external)
        precondition(externalAfterEdit == externalBeforeEdit)
        let wrapper = try FileWrapper(url: coordinatedSnapshot, options: [])
        try wrapper.write(
            to: external,
            options: FileWrapper.WritingOptions.atomic,
            originalContentsURL: external
        )
        let savedPage = try run("/usr/bin/unzip", ["-p", external.path, "Pages/\(pageID.uuidString).md"])
        precondition(savedPage.contains("Save coordination marker"))

        document.deleteAsset(asset)
        let deletedSnapshot = try document.snapshot(contentType: .focoBulb)
        let listingAfterDelete = try run("/usr/bin/unzip", ["-Z1", deletedSnapshot.path])
        precondition(!listingAfterDelete.contains("Assets/\(asset.storedFilename)"))
        precondition(document.manifest.assets.allSatisfy { $0.id != asset.id })
        precondition(document.currentPage?.content.contains(asset.id.uuidString) == false)
        if var page = document.currentPage {
            page.content = FocoStructuredBlockSyntax.removing(table.id, from: page.content)
            page.blocks?.removeAll { $0.id == table.id }
            page.blockIDs = []
            document.updateCurrentPage(page)
        }
        let prunedSnapshot = try document.snapshot(contentType: .focoBulb)
        let prunedListing = try run("/usr/bin/unzip", ["-Z1", prunedSnapshot.path])
        precondition(!prunedListing.contains("Blocks/\(table.id.uuidString).json"))
        print("Storage smoke check passed: coordinated save, inline media, exact extraction, and archive deletion.")
    }

    private static func run(_ executable: String, _ arguments: [String]) throws -> String {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: executable)
        process.arguments = arguments
        let pipe = Pipe()
        process.standardOutput = pipe
        try process.run()
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        process.waitUntilExit()
        precondition(process.terminationStatus == 0)
        return String(data: data, encoding: .utf8) ?? ""
    }
}
