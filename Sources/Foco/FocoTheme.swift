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
                bulb.move(to: point(12.0, 4.4, scale))
                bulb.addCurve(
                    to: point(7.4, 13.3, scale),
                    control1: point(7.4, 4.4, scale),
                    control2: point(5.0, 9.6, scale)
                )
                bulb.addCurve(
                    to: point(8.3, 15.2, scale),
                    control1: point(8.0, 14.0, scale),
                    control2: point(8.2, 14.5, scale)
                )
                bulb.addLine(to: point(15.7, 15.2, scale))
                bulb.addCurve(
                    to: point(16.6, 13.3, scale),
                    control1: point(15.8, 14.5, scale),
                    control2: point(16.0, 14.0, scale)
                )
                bulb.addCurve(
                    to: point(12.0, 4.4, scale),
                    control1: point(19.0, 9.6, scale),
                    control2: point(16.6, 4.4, scale)
                )

                var base = Path()
                base.move(to: point(8.4, 17.1, scale))
                base.addLine(to: point(15.6, 17.1, scale))
                base.move(to: point(9.4, 19.0, scale))
                base.addLine(to: point(14.6, 19.0, scale))

                var nib = Path()
                nib.move(to: point(12.0, 6.9, scale))
                nib.addLine(to: point(15.1, 10.7, scale))
                nib.addCurve(
                    to: point(12.0, 13.8, scale),
                    control1: point(14.1, 11.1, scale),
                    control2: point(13.1, 12.2, scale)
                )
                nib.addCurve(
                    to: point(8.9, 10.7, scale),
                    control1: point(10.9, 12.2, scale),
                    control2: point(9.9, 11.1, scale)
                )
                nib.closeSubpath()

                var slit = Path()
                slit.move(to: point(12.0, 9.0, scale))
                slit.addLine(to: point(12.0, 12.1, scale))

                let stroke = StrokeStyle(lineWidth: 1.65 * scale, lineCap: .round, lineJoin: .round)
                context.stroke(bulb, with: .color(.white), style: stroke)
                context.stroke(base, with: .color(.white), style: stroke)
                context.stroke(nib, with: .color(.white), style: StrokeStyle(lineWidth: 1.35 * scale, lineCap: .round, lineJoin: .round))
                context.stroke(slit, with: .color(.white), style: StrokeStyle(lineWidth: 1.0 * scale, lineCap: .round))
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
