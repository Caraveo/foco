import AppKit
import SwiftUI
import UniformTypeIdentifiers

@main
struct FocoApp: App {
    init() {
        // Swift Package executables do not always promote themselves to a normal
        // foreground app. Make the editor own keyboard focus when run from Terminal.
        NSApplication.shared.setActivationPolicy(.regular)
        if let iconURL = FocoResources.url(forResource: "BulbIcon", withExtension: "png"),
           let icon = NSImage(contentsOf: iconURL) {
            icon.isTemplate = false
            NSApplication.shared.applicationIconImage = icon
        }
        DispatchQueue.main.async {
            NSApplication.shared.activate(ignoringOtherApps: true)
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
            Task { @MainActor in RecentBulbDocument.reopen() }
        }
    }

    var body: some Scene {
        DocumentGroup(newDocument: { VaultDocument() }) { file in
            WorkspaceView(document: file.document, fileURL: file.fileURL)
        }
        .commands {
            SidebarCommands()
        }

        Settings {
            WritingSettingsView()
        }
    }
}

@MainActor
enum RecentBulbDocument {
    private static let key = "foco.lastBulbURL"

    static func remember(_ url: URL?) {
        guard let url, url.pathExtension.lowercased() == "bulb" else { return }
        UserDefaults.standard.set(url.path, forKey: key)
    }

    static func reopen() {
        guard let path = UserDefaults.standard.string(forKey: key) else { return }
        let url = URL(fileURLWithPath: path)
        guard FileManager.default.fileExists(atPath: url.path) else {
            UserDefaults.standard.removeObject(forKey: key)
            return
        }
        NSDocumentController.shared.openDocument(withContentsOf: url, display: true) { _, _, error in
            if error != nil { UserDefaults.standard.removeObject(forKey: key) }
        }
    }
}

private struct WritingSettingsView: View {
    @ObservedObject private var xai = XAIWritingService.shared
    @AppStorage("foco.manuscriptTheme") private var manuscriptTheme = "system"

    var body: some View {
        Form {
            HStack(spacing: 6) {
                Toggle("Enable inline predictive text", isOn: $xai.autocompleteEnabled)
                Image(systemName: "info.circle")
                    .foregroundStyle(.secondary)
                    .help("Suggestions use your recent words, grammar, and style to avoid mistakes and keep the right tone.")
            }
            Stepper("Next suggestion: \(xai.maxSuggestionWords) words", value: $xai.maxSuggestionWords, in: 1...10)
                .disabled(!xai.autocompleteEnabled)
            HStack(spacing: 6) {
                Toggle("Enable live writing coach", isOn: $xai.liveCoachEnabled)
                Image(systemName: "info.circle")
                    .foregroundStyle(.secondary)
                    .help("While you type, a separate xAI stream flags only clear grammar, punctuation, clarity, or tone issues. It stops and disappears when you pause.")
            }
            Toggle("Build page context automatically", isOn: $xai.automaticContextEnabled)
            SecureField("xAI API key", text: $xai.apiKey)
                .textFieldStyle(.roundedBorder)
            Picker("Manuscript appearance", selection: $manuscriptTheme) {
                Text("System").tag("system")
                Text("Light").tag("light")
                Text("Dark").tag("dark")
            }
            Text("Your key is stored in this Mac’s Keychain. Foco sends only up to 250 words immediately before the cursor.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(20)
        .frame(width: 440)
    }
}

extension UTType {
    /// Defining the type from its extension gives the save panel a concrete,
    /// preferred filename suffix even when Foco is run from Swift Package Manager.
    static let focoBulb = UTType("app.foco.bulb") ?? UTType(filenameExtension: "bulb", conformingTo: .data)!
    static let focoVaultLegacy = UTType(filenameExtension: "vault", conformingTo: .package)!
}
