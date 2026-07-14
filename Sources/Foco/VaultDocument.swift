import SwiftUI
import UniformTypeIdentifiers

struct VaultPage: Codable, Identifiable, Hashable {
    var id = UUID()
    var title: String
    var content: String
    /// Attachment order for this page. Optional keeps older vaults compatible.
    var assetIDs: [UUID]? = nil
}

struct VaultAsset: Codable, Identifiable, Hashable {
    var id = UUID()
    var filename: String
    var mediaType: String
    var storedFilename: String
}

struct VaultManifest: Codable {
    var version = 1
    var title = "Untitled Vault"
    var pages = [VaultPage(title: "Welcome", content: "# Welcome to Foco\n\nType / to add something.")]
    var assets: [VaultAsset] = []
}

struct VaultDocument: FileDocument {
    static var readableContentTypes: [UTType] { [.focoBulb, .focoVaultLegacy] }
    static var writableContentTypes: [UTType] { [.focoBulb] }

    var manifest = VaultManifest()
    /// Asset bytes keyed by the stored filename. Kept separate from JSON.
    var assetData: [String: Data] = [:]

    init() {}

    init(configuration: ReadConfiguration) throws {
        guard configuration.file.isDirectory,
              let manifestFile = configuration.file.fileWrappers?["document.json"],
              let data = manifestFile.regularFileContents else {
            throw CocoaError(.fileReadCorruptFile)
        }
        manifest = try JSONDecoder().decode(VaultManifest.self, from: data)
        if let assets = configuration.file.fileWrappers?["Assets"]?.fileWrappers {
            assetData = assets.reduce(into: [:]) { result, pair in
                if let bytes = pair.value.regularFileContents { result[pair.key] = bytes }
            }
        }
    }

    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let root = FileWrapper(directoryWithFileWrappers: [:])
        root.addRegularFile(withContents: try encoder.encode(manifest), preferredFilename: "document.json")
        let assets = FileWrapper(directoryWithFileWrappers: [:])
        for (name, data) in assetData {
            assets.addRegularFile(withContents: data, preferredFilename: name)
        }
        assets.preferredFilename = "Assets"
        root.addFileWrapper(assets)
        return root
    }

    mutating func importAsset(from url: URL, mediaType: String) throws -> VaultAsset {
        let accessing = url.startAccessingSecurityScopedResource()
        defer { if accessing { url.stopAccessingSecurityScopedResource() } }
        let data = try Data(contentsOf: url)
        let id = UUID()
        let safeName = url.lastPathComponent.replacingOccurrences(of: "/", with: "-")
        let storedName = "\(id.uuidString)-\(safeName)"
        let asset = VaultAsset(id: id, filename: safeName, mediaType: mediaType, storedFilename: storedName)
        assetData[storedName] = data
        manifest.assets.append(asset)
        return asset
    }
}
