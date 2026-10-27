import SwiftUI
import AppKit

/// VigilTech design tokens (mirrors --vt-* in the shared design system) as dynamic colours.
/// Every text colour here is audited against the surface it sits on; see scripts/contrast-audit.py.
enum VT {
    static func dynamic(_ light: UInt32, _ dark: UInt32, lightAlpha: CGFloat = 1, darkAlpha: CGFloat = 1) -> Color {
        Color(nsColor: NSColor(name: nil) { appearance in
            let isDark = appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
            let hex = isDark ? dark : light
            return NSColor(srgbRed: CGFloat((hex >> 16) & 255) / 255, green: CGFloat((hex >> 8) & 255) / 255, blue: CGFloat(hex & 255) / 255, alpha: isDark ? darkAlpha : lightAlpha)
        })
    }
    // Surfaces
    static let bg = dynamic(0xf6f1f4, 0x120a14)
    static let surface = dynamic(0xfffbfd, 0x1e1422)
    static let surface2 = dynamic(0xfaf4f7, 0x181019)
    /// Frosted scrim laid over the system sidebar material; opaque enough that text never depends on the desktop behind it.
    static let glass = dynamic(0xfffafc, 0x221226, lightAlpha: 0.96, darkAlpha: 0.96)
    // Text (never use a lighter grey than label2 for text)
    static let label = dynamic(0x17101a, 0xf7eef2)
    static let label2 = dynamic(0x6b5d68, 0xb7a5b1)
    // Pink: accent for icons and links, strong for text, button for filled controls with white text
    static let accent = dynamic(0xa8003a, 0xff7aa6)
    static let pressed = Color(nsColor: NSColor(srgbRed: 168/255, green: 0, blue: 58/255, alpha: 1))
    static let button = dynamic(0xd6004a, 0xd6004a)
    static let onButton = Color.white
    static let tintSoft = dynamic(0xff0058, 0xff4d86, lightAlpha: 0.11, darkAlpha: 0.18)
    static let fill = dynamic(0x6e4664, 0xffbedc, lightAlpha: 0.10, darkAlpha: 0.09)
    static let separator = dynamic(0x3a1e34, 0xffbedc, lightAlpha: 0.15, darkAlpha: 0.14)
    static let danger = dynamic(0xb3001b, 0xff7a8e)
    // Wallpaper stops
    static let wallA = dynamic(0xfff4f8, 0x140812)
    static let wallB = dynamic(0xffc0d4, 0x2b0a1e)
    static let wallC = dynamic(0xff5c8f, 0x5a0a2c)
    static let arcA = dynamic(0xffffff, 0xff8fb3, lightAlpha: 0.40, darkAlpha: 0.13)
    static let arcB = dynamic(0xa8003a, 0x1f0009, lightAlpha: 0.22, darkAlpha: 0.50)
    static let radius: CGFloat = 12
}

struct Wallpaper: View {
    var body: some View {
        GeometryReader { g in
            ZStack {
                LinearGradient(colors: [VT.wallA, VT.wallB, VT.wallC], startPoint: .topLeading, endPoint: .bottomTrailing)
                Circle().fill(VT.arcA).frame(width: g.size.width * 1.5).position(x: 0, y: g.size.height * 1.15)
                Circle().fill(VT.arcB).frame(width: g.size.width * 1.6).position(x: g.size.width * 0.95, y: g.size.height * 1.4)
            }.clipped()
        }
    }
}

struct PrimaryButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) private var enabled
    func makeBody(configuration: Configuration) -> some View {
        configuration.label.font(.system(size: 13, weight: .semibold)).foregroundStyle(enabled ? VT.onButton : VT.label2)
            .padding(.horizontal, 14).padding(.vertical, 6)
            .background(enabled ? (configuration.isPressed ? VT.pressed : VT.button) : VT.fill, in: RoundedRectangle(cornerRadius: 8))
    }
}

/// Toolbar glyph button. Enabled uses full label colour; disabled stays at label2 (still >= 4.5:1) rather than SwiftUI's dimming.
struct IconButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) private var enabled
    func makeBody(configuration: Configuration) -> some View {
        configuration.label.foregroundStyle(enabled ? VT.label : VT.label2).frame(width: 26, height: 26)
            .background(configuration.isPressed ? VT.fill : Color.clear, in: RoundedRectangle(cornerRadius: 7))
            .opacity(1)
    }
}
