import Combine
import SwiftUI
import UniformTypeIdentifiers

struct VaultPage: Codable, Identifiable, Hashable, Sendable {
    var id = UUID()
    var title: String
    var content: String
    var assetIDs: [UUID]? = nil
}

struct VaultAsset: Codable, Identifiable, Hashable, Sendable {
    var id = UUID()
    var filename: String
    var mediaType: String
    /// The actual ZIP entry below `Assets/`.
    var storedFilename: String
    var byteSize: Int64? = nil
}

struct AssetBlockMatch: Sendable {
    let assetID: UUID
    let tokenRange: NSRange
    let lineRange: NSRange
}

/// Attachments live in page Markdown as atomic block tokens. The editor hides
/// the token and mounts the native preview in its place, while the token keeps
/// ordering portable and understandable outside Foco.
enum AssetBlockSyntax {
    static func token(for asset: VaultAsset) -> String {
        let filename = asset.filename
            .replacingOccurrences(of: "]", with: "")
            .replacingOccurrences(of: "\n", with: " ")
            .replacingOccurrences(of: "\r", with: " ")
        return "[[asset:\(asset.id.uuidString)|\(filename)]]"
    }

    static func matches(in content: String) -> [AssetBlockMatch] {
        guard let regex = try? NSRegularExpression(
            pattern: #"\[\[asset:([0-9A-Fa-f-]{36})\|[^\]\r\n]*\]\]"#
        ) else { return [] }
        let source = content as NSString
        return regex.matches(in: content, range: NSRange(location: 0, length: source.length)).compactMap { match in
            guard match.range(at: 1).location != NSNotFound,
                  let id = UUID(uuidString: source.substring(with: match.range(at: 1))) else { return nil }
            return AssetBlockMatch(
                assetID: id,
                tokenRange: match.range,
                lineRange: source.lineRange(for: match.range)
            )
        }
    }

    static func contains(_ assetID: UUID, in content: String) -> Bool {
        matches(in: content).contains { $0.assetID == assetID }
    }

    static func inserting(_ asset: VaultAsset, into content: String, atUTF16Offset offset: Int?) -> String {
        let source = content as NSString
        let location = min(max(0, offset ?? source.length), source.length)
        let prefix = source.substring(to: location)
        let suffix = source.substring(from: location)
        var block = token(for: asset)
        if !prefix.isEmpty && !prefix.hasSuffix("\n") { block = "\n" + block }
        if !suffix.isEmpty && !suffix.hasPrefix("\n") { block += "\n" }
        if suffix.isEmpty { block += "\n" }
        return prefix + block + suffix
    }

    static func removing(_ assetID: UUID, from content: String) -> String {
        guard let match = matches(in: content).first(where: { $0.assetID == assetID }) else { return content }
        return (content as NSString).replacingCharacters(in: match.lineRange, with: "")
    }
}

struct VaultManifest: Codable, Sendable {
    var version = 5
    var title = "Untitled Bulb"
    /// Page content is stored separately in `Pages/<id>.md`; these are summaries.
    var pages = [VaultPage(title: "Welcome", content: "")]
    var assets: [VaultAsset] = []
}

/// A `.bulb` is a ZIP-compatible single file containing ordinary Markdown and
/// media entries. Only the manifest and selected page are read into memory.
final class VaultDocument: ReferenceFileDocument, @unchecked Sendable {
    typealias Snapshot = URL

    static var readableContentTypes: [UTType] { [.focoBulb, .focoVaultLegacy] }
    static var writableContentTypes: [UTType] { [.focoBulb] }

    @Published private(set) var manifest: VaultManifest
    @Published private(set) var currentPage: VaultPage?
    @Published private(set) var currentAssets: [VaultAsset] = []

    private var archive: BulbArchive
    private var adoptedFileURL: URL?
    private var openedLegacyPackage = false

    init() {
        let initialPage = VaultPage(title: "Welcome", content: "# Welcome to Foco\n\nType / to add something.")
        manifest = VaultManifest(pages: [VaultPage(id: initialPage.id, title: initialPage.title, content: "")])
        archive = try! BulbArchive.temporary()
        try? archive.initialize(manifest: manifest, pages: [initialPage])
    }

    required init(configuration: ReadConfiguration) throws {
        archive = try BulbArchive.temporary()
        manifest = VaultManifest(pages: [])
        if configuration.file.isDirectory {
            openedLegacyPackage = true
        } else {
            // Do not touch regularFileContents. SwiftUI supplies the actual URL
            // to the workspace, and entries are then read directly from disk.
        }
    }

    func snapshot(contentType: UTType) throws -> URL {
        if let currentPage { try archive.persist(page: currentPage, manifest: manifest) }
        else { try archive.persist(manifest: manifest) }
        return archive.url
    }

    func fileWrapper(snapshot: URL, configuration: WriteConfiguration) throws -> FileWrapper {
        try FileWrapper(url: snapshot, options: [])
    }

    func adoptFileURL(_ url: URL?) {
        guard let url else { return }
        let normalized = url.standardizedFileURL
        guard adoptedFileURL?.standardizedFileURL != normalized else { return }
        do {
            if openedLegacyPackage {
                let migrated = try BulbArchive.migrateLegacyPackage(at: normalized)
                archive = migrated.archive
                manifest = migrated.manifest
                openedLegacyPackage = false
                adoptedFileURL = normalized
                currentPage = nil
                currentAssets = []
                return
            }
            guard (try? normalized.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) != true else { return }
            let replacement = try BulbArchive(url: normalized, ownsArchive: false)
            archive = replacement
            manifest = try replacement.loadManifest()
            adoptedFileURL = normalized
            currentPage = nil
            currentAssets = []
        } catch {
            report(error)
        }
    }

    func selectPage(_ id: UUID?) {
        do {
            if let currentPage { try archive.persist(page: currentPage, manifest: manifest) }
            guard let id else { currentPage = nil; currentAssets = []; return }
            var page = try archive.loadPage(id: id, manifest: manifest)
            let ids = Set(page.assetIDs ?? [])
            let pageAssets = manifest.assets.filter { ids.contains($0.id) }
            var migratedInlineAssets = false
            for asset in pageAssets where !AssetBlockSyntax.contains(asset.id, in: page.content) {
                page.content = AssetBlockSyntax.inserting(asset, into: page.content, atUTF16Offset: nil)
                migratedInlineAssets = true
            }
            currentPage = page
            currentAssets = pageAssets
            if migratedInlineAssets { try archive.persist(page: page, manifest: manifest) }
        } catch {
            report(error)
        }
    }

    func updateCurrentPage(_ page: VaultPage) {
        currentPage = page
        if let index = manifest.pages.firstIndex(where: { $0.id == page.id }) {
            manifest.pages[index].title = page.title
            manifest.pages[index].assetIDs = page.assetIDs
        }
    }

    func renameDocument(_ title: String) {
        manifest.title = title
        do { try archive.persist(manifest: manifest) }
        catch { report(error) }
    }

    @discardableResult
    func addPage() -> VaultPage {
        do {
            if let currentPage { try archive.persist(page: currentPage, manifest: manifest) }
            let page = VaultPage(title: "Untitled", content: "")
            manifest.pages.append(VaultPage(id: page.id, title: page.title, content: ""))
            try archive.addPage(page, manifest: manifest)
            return page
        } catch {
            report(error)
            return VaultPage(title: "Untitled", content: "")
        }
    }

    func deletePage(_ page: VaultPage) {
        guard manifest.pages.count > 1 else { return }
        do {
            let removedAssets = manifest.assets.filter { (page.assetIDs ?? []).contains($0.id) }
            manifest.pages.removeAll { $0.id == page.id }
            manifest.assets.removeAll { (page.assetIDs ?? []).contains($0.id) }
            try archive.deletePage(page, assets: removedAssets, manifest: manifest)
            currentPage = nil
            currentAssets = []
        } catch {
            report(error)
        }
    }

    func importAsset(from url: URL, mediaType: String, insertionUTF16Offset: Int? = nil) async throws -> VaultAsset {
        guard let pageID = currentPage?.id else { throw BulbArchiveError.noSelectedPage }
        if let currentPage { try archive.persist(page: currentPage, manifest: manifest) }
        let accessing = url.startAccessingSecurityScopedResource()
        defer { if accessing { url.stopAccessingSecurityScopedResource() } }
        let archive = archive
        let result = try await Task.detached(priority: .userInitiated) {
            try archive.importAsset(
                from: url,
                mediaType: mediaType,
                pageID: pageID,
                insertionUTF16Offset: insertionUTF16Offset
            )
        }.value
        await MainActor.run {
            manifest = result.manifest
            currentAssets = result.manifest.assets.filter { (result.page.assetIDs ?? []).contains($0.id) }
            currentPage = result.page
        }
        return result.asset
    }

    func deleteAsset(_ asset: VaultAsset) {
        guard var page = currentPage, (page.assetIDs ?? []).contains(asset.id) else { return }
        do {
            page.content = AssetBlockSyntax.removing(asset.id, from: page.content)
            page.assetIDs?.removeAll { $0 == asset.id }
            if let pageIndex = manifest.pages.firstIndex(where: { $0.id == page.id }) {
                manifest.pages[pageIndex].title = page.title
                manifest.pages[pageIndex].assetIDs = page.assetIDs
            }
            let usedElsewhere = manifest.pages.contains { summary in
                summary.id != page.id && (summary.assetIDs ?? []).contains(asset.id)
            }
            if !usedElsewhere { manifest.assets.removeAll { $0.id == asset.id } }
            try archive.deleteAsset(asset, from: page, removeFile: !usedElsewhere, manifest: manifest)
            currentPage = page
            currentAssets.removeAll { $0.id == asset.id }
        } catch {
            report(error)
        }
    }

    func materialize(_ asset: VaultAsset) -> URL? {
        do { return try archive.materialize(asset: asset) }
        catch { report(error); return nil }
    }

    private func report(_ error: Error) {
        let message = error.localizedDescription
        Task { @MainActor in
            NSApp.presentError(NSError(domain: "Foco", code: 1, userInfo: [NSLocalizedDescriptionKey: message]))
        }
    }
}

private enum BulbArchiveError: LocalizedError {
    case command(String)
    case invalidDocument
    case noSelectedPage

    var errorDescription: String? {
        switch self {
        case .command(let message): "Bulb archive error: \(message)"
        case .invalidDocument: "This document is not a valid Foco bulb."
        case .noSelectedPage: "Select a page before adding an attachment."
        }
    }
}

private final class BulbArchive: @unchecked Sendable {
    let url: URL
    private let workingDirectory: URL
    private let ownsArchive: Bool
    private let lock = NSRecursiveLock()

    static func temporary() throws -> BulbArchive {
        let folder = FileManager.default.temporaryDirectory
            .appendingPathComponent("FocoWorking", isDirectory: true)
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        return try BulbArchive(url: folder.appendingPathComponent("Working.bulb"), ownsArchive: true)
    }

    init(url: URL, ownsArchive: Bool) throws {
        self.url = url
        self.ownsArchive = ownsArchive
        workingDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent("FocoArchiveCache", isDirectory: true)
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: workingDirectory, withIntermediateDirectories: true)
    }

    deinit {
        try? FileManager.default.removeItem(at: workingDirectory)
        if ownsArchive { try? FileManager.default.removeItem(at: url.deletingLastPathComponent()) }
    }

    func initialize(manifest: VaultManifest, pages: [VaultPage]) throws {
        try locked {
            for page in pages { try write(data: Data(page.content.utf8), entry: pageEntry(page.id), compression: .deflate) }
            try writeManifest(manifest)
        }
    }

    func loadManifest() throws -> VaultManifest {
        try locked {
            let data = try read(entry: "manifest.json")
            return try JSONDecoder().decode(VaultManifest.self, from: data)
        }
    }

    func loadPage(id: UUID, manifest: VaultManifest) throws -> VaultPage {
        try locked {
            guard let summary = manifest.pages.first(where: { $0.id == id }) else { throw BulbArchiveError.invalidDocument }
            let content = String(data: try read(entry: pageEntry(id)), encoding: .utf8) ?? ""
            return VaultPage(id: id, title: summary.title, content: content, assetIDs: summary.assetIDs)
        }
    }

    func persist(page: VaultPage, manifest: VaultManifest) throws {
        try locked {
            try write(data: Data(page.content.utf8), entry: pageEntry(page.id), compression: .deflate)
            try writeManifest(manifest)
        }
    }

    func persist(manifest: VaultManifest) throws {
        try locked { try writeManifest(manifest) }
    }

    func addPage(_ page: VaultPage, manifest: VaultManifest) throws {
        try locked {
            try write(data: Data(page.content.utf8), entry: pageEntry(page.id), compression: .deflate)
            try writeManifest(manifest)
        }
    }

    func deletePage(_ page: VaultPage, assets: [VaultAsset], manifest: VaultManifest) throws {
        try locked {
            var entries = [pageEntry(page.id)]
            entries += assets.map(assetEntry)
            try delete(entries: entries)
            try writeManifest(manifest)
        }
    }

    func importAsset(
        from source: URL,
        mediaType: String,
        pageID: UUID,
        insertionUTF16Offset: Int?
    ) throws -> (asset: VaultAsset, page: VaultPage, manifest: VaultManifest) {
        try locked {
            var manifest = try loadManifest()
            guard let pageIndex = manifest.pages.firstIndex(where: { $0.id == pageID }) else { throw BulbArchiveError.noSelectedPage }
            let size = try source.resourceValues(forKeys: [.fileSizeKey]).fileSize.map(Int64.init) ?? 0
            let id = UUID()
            let safeName = source.lastPathComponent.replacingOccurrences(of: "/", with: "-")
            let asset = VaultAsset(id: id, filename: safeName, mediaType: mediaType, storedFilename: "\(id.uuidString)-\(safeName)", byteSize: size)
            try write(source: source, entry: assetEntry(asset), compression: .store)
            manifest.assets.append(asset)
            var ids = manifest.pages[pageIndex].assetIDs ?? []
            ids.append(id)
            manifest.pages[pageIndex].assetIDs = ids
            var page = try loadPage(id: pageID, manifest: manifest)
            page.assetIDs = ids
            page.content = AssetBlockSyntax.inserting(
                asset,
                into: page.content,
                atUTF16Offset: insertionUTF16Offset
            )
            try write(data: Data(page.content.utf8), entry: pageEntry(page.id), compression: .deflate)
            try writeManifest(manifest)
            return (asset, page, manifest)
        }
    }

    func deleteAsset(_ asset: VaultAsset, from page: VaultPage, removeFile: Bool, manifest: VaultManifest) throws {
        try locked {
            try write(data: Data(page.content.utf8), entry: pageEntry(page.id), compression: .deflate)
            if removeFile {
                try delete(entries: [assetEntry(asset)])
                let cached = workingDirectory
                    .appendingPathComponent("Preview", isDirectory: true)
                    .appendingPathComponent(assetEntry(asset))
                try? FileManager.default.removeItem(at: cached)
            }
            try writeManifest(manifest)
        }
    }

    func materialize(asset: VaultAsset) throws -> URL {
        try locked {
            let destination = workingDirectory.appendingPathComponent("Preview", isDirectory: true)
            let output = destination.appendingPathComponent(assetEntry(asset))
            if FileManager.default.fileExists(atPath: output.path) { return output }
            try FileManager.default.createDirectory(at: destination, withIntermediateDirectories: true)
            _ = try run("/usr/bin/unzip", ["-qq", "-o", url.path, assetEntry(asset), "-d", destination.path])
            guard FileManager.default.fileExists(atPath: output.path) else { throw BulbArchiveError.invalidDocument }
            return output
        }
    }

    static func migrateLegacyPackage(at packageURL: URL) throws -> (archive: BulbArchive, manifest: VaultManifest) {
        let json = try Data(contentsOf: packageURL.appendingPathComponent("document.json"), options: .mappedIfSafe)
        let old = try JSONDecoder().decode(VaultManifest.self, from: json)
        let archive = try BulbArchive.temporary()
        var manifest = old
        manifest.version = 5
        manifest.pages = old.pages.map { VaultPage(id: $0.id, title: $0.title, content: "", assetIDs: $0.assetIDs) }
        try archive.initialize(manifest: manifest, pages: old.pages)
        for asset in old.assets {
            let source = packageURL.appendingPathComponent("Assets", isDirectory: true).appendingPathComponent(asset.storedFilename)
            if FileManager.default.fileExists(atPath: source.path) {
                try archive.write(source: source, entry: archive.assetEntry(asset), compression: .store)
            }
        }
        try archive.persist(manifest: manifest)
        return (archive, manifest)
    }

    private enum Compression { case store, deflate }

    private func writeManifest(_ manifest: VaultManifest) throws {
        var portable = manifest
        portable.version = 5
        portable.pages = portable.pages.map { VaultPage(id: $0.id, title: $0.title, content: "", assetIDs: $0.assetIDs) }
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        try write(data: encoder.encode(portable), entry: "manifest.json", compression: .deflate)
    }

    private func read(entry: String) throws -> Data {
        let result = try run("/usr/bin/unzip", ["-p", url.path, entry], captureOutput: true)
        return result
    }

    private func write(data: Data, entry: String, compression: Compression) throws {
        let stage = try makeStage()
        defer { try? FileManager.default.removeItem(at: stage) }
        let file = stage.appendingPathComponent(entry)
        try FileManager.default.createDirectory(at: file.deletingLastPathComponent(), withIntermediateDirectories: true)
        try data.write(to: file, options: .atomic)
        try addStaged(entry: entry, stage: stage, compression: compression)
    }

    private func write(source: URL, entry: String, compression: Compression) throws {
        let stage = try makeStage()
        defer { try? FileManager.default.removeItem(at: stage) }
        let link = stage.appendingPathComponent(entry)
        try FileManager.default.createDirectory(at: link.deletingLastPathComponent(), withIntermediateDirectories: true)
        do { try FileManager.default.createSymbolicLink(at: link, withDestinationURL: source) }
        catch { try FileManager.default.copyItem(at: source, to: link) }
        try addStaged(entry: entry, stage: stage, compression: compression)
    }

    private func addStaged(entry: String, stage: URL, compression: Compression) throws {
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        let flag = compression == .store ? "-0" : "-9"
        _ = try run("/usr/bin/zip", ["-q", flag, url.path, entry], currentDirectory: stage)
    }

    private func delete(entries: [String]) throws {
        guard !entries.isEmpty else { return }
        _ = try? run("/usr/bin/zip", ["-q", "-d", url.path] + entries)
    }

    private func makeStage() throws -> URL {
        let stage = workingDirectory.appendingPathComponent("Stage-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: stage, withIntermediateDirectories: true)
        return stage
    }

    private func pageEntry(_ id: UUID) -> String { "Pages/\(id.uuidString).md" }
    private func assetEntry(_ asset: VaultAsset) -> String { "Assets/\(asset.storedFilename)" }

    @discardableResult
    private func run(_ executable: String, _ arguments: [String], currentDirectory: URL? = nil, captureOutput: Bool = false) throws -> Data {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: executable)
        process.arguments = arguments
        process.currentDirectoryURL = currentDirectory
        let output = Pipe()
        let error = Pipe()
        process.standardOutput = output
        process.standardError = error
        try process.run()
        let outputData = captureOutput ? output.fileHandleForReading.readDataToEndOfFile() : Data()
        process.waitUntilExit()
        let errorData = error.fileHandleForReading.readDataToEndOfFile()
        guard process.terminationStatus == 0 else {
            let message = String(data: errorData, encoding: .utf8) ?? "Command failed"
            throw BulbArchiveError.command(message.trimmingCharacters(in: .whitespacesAndNewlines))
        }
        return outputData
    }

    private func locked<T>(_ action: () throws -> T) rethrows -> T {
        lock.lock()
        defer { lock.unlock() }
        return try action()
    }
}
