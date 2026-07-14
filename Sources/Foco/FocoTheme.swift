import SwiftUI

enum FocoTheme {
    static let canvas = Color(nsColor: .windowBackgroundColor)
    static let sidebar = Color(nsColor: NSColor(name: nil) { appearance in
        appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
            ? NSColor(calibratedWhite: 0.105, alpha: 1)
            : NSColor(calibratedRed: 0.969, green: 0.965, blue: 0.953, alpha: 1)
    })
    static let hover = Color.primary.opacity(0.055)
    static let selected = Color.primary.opacity(0.085)
    static let hairline = Color.primary.opacity(0.08)
    static let secondaryText = Color.primary.opacity(0.52)
    static let accent = Color(red: 0.82, green: 0.36, blue: 0.25)
}

enum FocoResources {
    static func url(forResource name: String, withExtension fileExtension: String) -> URL? {
        Bundle.main.url(forResource: name, withExtension: fileExtension)
            ?? Bundle.module.url(forResource: name, withExtension: fileExtension)
    }

    static var bulbImage: NSImage {
        guard let url = url(forResource: "BulbIcon", withExtension: "png"),
              let image = NSImage(contentsOf: url) else { return NSImage() }
        return image
    }
}

/// The exact user-supplied bulb artwork, loaded from the generated PNG resource.
struct FocoMark: View {
    var size: CGFloat = 24

    var body: some View {
        Image(nsImage: FocoResources.bulbImage)
            .resizable()
            .aspectRatio(contentMode: .fit)
        .frame(width: size, height: size)
            .accessibilityLabel("Foco")
    }
}

struct FocoIconButton: View {
    let icon: String
    let help: String
    var action: () -> Void = {}
    @State private var hovered = false

    var body: some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(.secondary)
                .frame(width: 28, height: 28)
                .background(hovered ? FocoTheme.hover : .clear, in: RoundedRectangle(cornerRadius: 6))
        }
        .buttonStyle(.plain)
        .help(help)
        .onHover { hovered = $0 }
    }
}
