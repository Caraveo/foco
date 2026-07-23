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

private struct WritingSettingsView: View {
    @ObservedObject private var xai = XAIWritingService.shared
    @AppStorage("foco.manuscriptTheme") private var manuscriptTheme = "system"

    var body: some View {
        Form {
            Toggle("Enable inline predictive text", isOn: $xai.autocompleteEnabled)
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
