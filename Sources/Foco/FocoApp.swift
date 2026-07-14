import AppKit
import SwiftUI
import UniformTypeIdentifiers

@main
struct FocoApp: App {
    init() {
        // Swift Package executables do not always promote themselves to a normal
        // foreground app. Make the editor own keyboard focus when run from Terminal.
        NSApplication.shared.setActivationPolicy(.regular)
        DispatchQueue.main.async {
            NSApplication.shared.activate(ignoringOtherApps: true)
        }
    }

    var body: some Scene {
        DocumentGroup(newDocument: VaultDocument()) { file in
            WorkspaceView(document: file.$document)
        }
        .commands {
            SidebarCommands()
        }
    }
}

extension UTType {
    /// Defining the type from its extension gives the save panel a concrete,
    /// preferred filename suffix even when Foco is run from Swift Package Manager.
    static let focoBulb = UTType(filenameExtension: "bulb", conformingTo: .package)!
    static let focoVaultLegacy = UTType(filenameExtension: "vault", conformingTo: .package)!
}
