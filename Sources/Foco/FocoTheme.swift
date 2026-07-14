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

/// Foco's bulb-and-pen mark. Keeping the small in-app version in SwiftUI makes
/// it render sharply at every display scale; the matching SVG lives in Resources.
struct FocoMark: View {
    var size: CGFloat = 24

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: size * 0.23, style: .continuous)
                .fill(FocoTheme.accent.gradient)

            Canvas { context, canvasSize in
                let scale = canvasSize.width / 24
                var bulb = Path()
                bulb.move(to: point(10.6, 5.2, scale))
                bulb.addCurve(
                    to: point(7.2, 13.1, scale),
                    control1: point(5.7, 5.2, scale),
                    control2: point(4.8, 10.2, scale)
                )
                bulb.addCurve(
                    to: point(8.1, 15.1, scale),
                    control1: point(7.8, 13.8, scale),
                    control2: point(8.0, 14.3, scale)
                )
                bulb.addLine(to: point(12.0, 15.1, scale))
                bulb.addCurve(
                    to: point(13.0, 13.2, scale),
                    control1: point(12.2, 14.3, scale),
                    control2: point(12.5, 13.8, scale)
                )

                var base = Path()
                base.move(to: point(8.2, 17.0, scale))
                base.addLine(to: point(11.6, 17.0, scale))
                base.move(to: point(8.8, 18.8, scale))
                base.addLine(to: point(10.9, 18.8, scale))

                var pen = Path()
                pen.move(to: point(11.3, 14.0, scale))
                pen.addLine(to: point(17.3, 6.0, scale))
                pen.addCurve(
                    to: point(19.1, 7.4, scale),
                    control1: point(17.8, 5.3, scale),
                    control2: point(19.7, 6.7, scale)
                )
                pen.addLine(to: point(13.1, 15.4, scale))
                pen.closeSubpath()

                let stroke = StrokeStyle(lineWidth: 1.65 * scale, lineCap: .round, lineJoin: .round)
                context.stroke(bulb, with: .color(.white), style: stroke)
                context.stroke(base, with: .color(.white), style: stroke)
                context.fill(pen, with: .color(.white))
            }
            .padding(size * 0.08)
        }
        .frame(width: size, height: size)
        .accessibilityHidden(true)
    }

    private func point(_ x: CGFloat, _ y: CGFloat, _ scale: CGFloat) -> CGPoint {
        CGPoint(x: x * scale, y: y * scale)
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
