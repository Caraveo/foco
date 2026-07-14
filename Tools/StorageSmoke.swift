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

        guard let preview = document.materialize(asset) else { fatalError("Could not extract asset") }
        let previewSize = try preview.resourceValues(forKeys: [.fileSizeKey]).fileSize
        precondition(previewSize == 3 * 1_048_576 + 123)

        document.deleteAsset(asset)
        let deletedSnapshot = try document.snapshot(contentType: .focoBulb)
        let listingAfterDelete = try run("/usr/bin/unzip", ["-Z1", deletedSnapshot.path])
        precondition(!listingAfterDelete.contains("Assets/\(asset.storedFilename)"))
        precondition(document.manifest.assets.allSatisfy { $0.id != asset.id })
        precondition(document.currentPage?.content.contains(asset.id.uuidString) == false)
        print("Storage smoke check passed: inline media token, exact extraction, and archive deletion.")
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
