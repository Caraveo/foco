import AppKit
import Combine
import Foundation

struct ViewerPageSummary: Codable, Identifiable, Hashable, Sendable {
    let id: UUID
    let title: String
    let content: String?
    let assetIDs: [UUID]?
    let blockIDs: [UUID]?
    let category: String?
}

struct ViewerAsset: Codable, Identifiable, Hashable, Sendable {
    let id: UUID
    let filename: String
    let mediaType: String
    let storedFilename: String
    let byteSize: Int64?
}

struct ViewerManifest: Codable, Sendable {
    let version: Int
    let title: String
    let pages: [ViewerPageSummary]
    let assets: [ViewerAsset]
}

struct ViewerLoadedPage: Identifiable, Sendable {
    let summary: ViewerPageSummary
    let content: String
    let blocks: [ViewerStructuredBlock]
    var id: UUID { summary.id }
}

@MainActor
final class ViewerDocument: ObservableObject {
    @Published private(set) var manifest: ViewerManifest?
    @Published private(set) var currentPage: ViewerLoadedPage?
    @Published private(set) var selectedPageID: UUID?
    @Published private(set) var fileURL: URL?
    @Published private(set) var isLoading = false
    @Published var errorMessage: String?

    private var archive: ViewerArchive?
    private var scopedURL: URL?
    private var generation = UUID()

    var title: String { manifest?.title ?? fileURL?.deletingPathExtension().lastPathComponent ?? "Foco View" }

    func open(_ url: URL) {
        let normalized = url.standardizedFileURL
        generation = UUID()
        let requestGeneration = generation
        if let scopedURL { scopedURL.stopAccessingSecurityScopedResource() }
        scopedURL = normalized.startAccessingSecurityScopedResource() ? normalized : nil
        fileURL = normalized
        manifest = nil
        currentPage = nil
        selectedPageID = nil
        errorMessage = nil
        isLoading = true

        Task {
            do {
                let result = try await Task.detached(priority: .userInitiated) {
                    let archive = try ViewerArchive(url: normalized)
                    return (archive, try archive.loadManifest())
                }.value
                guard requestGeneration == generation else { return }
                archive = result.0
                manifest = result.1
                isLoading = false
                if let firstPage = result.1.pages.first { selectPage(firstPage.id) }
            } catch {
                guard requestGeneration == generation else { return }
                isLoading = false
                errorMessage = error.localizedDescription
            }
        }
    }

    func selectPage(_ id: UUID) {
        guard let archive, let manifest,
              let summary = manifest.pages.first(where: { $0.id == id }) else { return }
        selectedPageID = id
        currentPage = nil
        isLoading = true
        let requestGeneration = generation

        Task {
            do {
                let loaded = try await Task.detached(priority: .userInitiated) {
                    try archive.loadPage(id)
                }.value
                guard requestGeneration == generation, selectedPageID == id else { return }
                currentPage = ViewerLoadedPage(summary: summary, content: loaded.content, blocks: loaded.blocks)
                isLoading = false
            } catch {
                guard requestGeneration == generation else { return }
                isLoading = false
                errorMessage = error.localizedDescription
            }
        }
    }

    func materialize(_ asset: ViewerAsset) async -> URL? {
        guard let archive else { return nil }
        return await Task.detached(priority: .utility) {
            try? archive.materialize(asset)
        }.value
    }

    func asset(_ id: UUID) -> ViewerAsset? {
        manifest?.assets.first { $0.id == id }
    }
}

private enum ViewerArchiveError: LocalizedError {
    case invalidDocument
    case command(String)

    var errorDescription: String? {
        switch self {
        case .invalidDocument: "This file is not a valid Foco .bulb document."
        case .command(let message): "Could not read this bulb: \(message)"
        }
    }
}

final class ViewerArchive: @unchecked Sendable {
    private let url: URL
    private let cacheDirectory: URL
    private let lock = NSLock()

    init(url: URL) throws {
        let values = try url.resourceValues(forKeys: [.isRegularFileKey, .isDirectoryKey])
        guard values.isRegularFile == true, values.isDirectory != true else {
            throw ViewerArchiveError.invalidDocument
        }
        self.url = url
        cacheDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent("FocoView", isDirectory: true)
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: cacheDirectory, withIntermediateDirectories: true)
    }

    deinit { try? FileManager.default.removeItem(at: cacheDirectory) }

    func loadManifest() throws -> ViewerManifest {
        try locked {
            let data = try run("/usr/bin/unzip", ["-p", url.path, "manifest.json"])
            do { return try JSONDecoder().decode(ViewerManifest.self, from: data) }
            catch { throw ViewerArchiveError.invalidDocument }
        }
    }

    func loadPage(_ id: UUID) throws -> (content: String, blocks: [ViewerStructuredBlock]) {
        try locked {
            let data = try run("/usr/bin/unzip", ["-p", url.path, "Pages/\(id.uuidString).md"])
            guard let content = String(data: data, encoding: .utf8) else {
                throw ViewerArchiveError.invalidDocument
            }
            let blocks: [ViewerStructuredBlock] = ViewerStructuredBlockSyntax.references(in: content).compactMap { reference -> ViewerStructuredBlock? in
                guard let data = try? run(
                    "/usr/bin/unzip",
                    ["-p", url.path, "Blocks/\(reference.id.uuidString).json"]
                ) else { return nil }
                return try? JSONDecoder().decode(ViewerStructuredBlock.self, from: data)
            }
            return (content, blocks)
        }
    }

    func materialize(_ asset: ViewerAsset) throws -> URL {
        try locked {
            let entry = "Assets/\(asset.storedFilename)"
            let output = cacheDirectory.appendingPathComponent(entry)
            if FileManager.default.fileExists(atPath: output.path) { return output }
            try FileManager.default.createDirectory(
                at: output.deletingLastPathComponent(),
                withIntermediateDirectories: true
            )
            _ = try run("/usr/bin/unzip", ["-qq", "-o", url.path, entry, "-d", cacheDirectory.path])
            guard FileManager.default.fileExists(atPath: output.path) else {
                throw ViewerArchiveError.invalidDocument
            }
            return output
        }
    }

    @discardableResult
    private func run(_ executable: String, _ arguments: [String]) throws -> Data {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: executable)
        process.arguments = arguments
        let output = Pipe()
        let error = Pipe()
        process.standardOutput = output
        process.standardError = error
        try process.run()
        let outputData = output.fileHandleForReading.readDataToEndOfFile()
        process.waitUntilExit()
        let errorData = error.fileHandleForReading.readDataToEndOfFile()
        guard process.terminationStatus == 0 else {
            let message = String(data: errorData, encoding: .utf8) ?? "Unknown archive error"
            throw ViewerArchiveError.command(message.trimmingCharacters(in: .whitespacesAndNewlines))
        }
        return outputData
    }

    private func locked<T>(_ action: () throws -> T) rethrows -> T {
        lock.lock()
        defer { lock.unlock() }
        return try action()
    }
}
