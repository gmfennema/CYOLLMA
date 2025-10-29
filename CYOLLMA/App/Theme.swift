import SwiftUI

enum Theme {
    // Colors tuned for a warm e-paper aesthetic
    static let background = Color(red: 0.97, green: 0.96, blue: 0.92)
    static let surface = Color(red: 0.99, green: 0.98, blue: 0.95)
    static let surfaceElevated = Color(red: 0.92, green: 0.89, blue: 0.82)
    static let textPrimary = Color(red: 0.21, green: 0.19, blue: 0.14)
    static let textSecondary = Color(red: 0.46, green: 0.43, blue: 0.35)
    static let accent = Color(red: 0.60, green: 0.54, blue: 0.42)
    static let divider = Color(red: 0.80, green: 0.77, blue: 0.70)
    static let danger = Color(red: 0.76, green: 0.29, blue: 0.25)

    // Typography helpers
    static func titleFont() -> Font { .system(.title2, design: .serif).weight(.semibold) }
    static func bodyFont() -> Font { .system(.body, design: .serif) }
    static func monoCaption() -> Font { .system(.caption, design: .monospaced) }
}

struct MonochromeButtonStyle: ButtonStyle {
    enum Kind { case primary, subtle }
    var kind: Kind = .primary
    var compact: Bool = false

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(.callout, design: .rounded).weight(.semibold))
            .foregroundColor(kind == .primary ? Theme.surface : Theme.textPrimary)
            .padding(.vertical, compact ? 6 : 10)
            .padding(.horizontal, compact ? 12 : 18)
            .frame(minHeight: compact ? nil : 38, alignment: .center)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(kind == .primary ? Theme.accent : Theme.surface)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(Theme.divider.opacity(kind == .primary ? 0.35 : 0.7), lineWidth: 1)
            )
            .opacity(configuration.isPressed ? 0.92 : 1)
            .shadow(color: Color.black.opacity(0.08), radius: configuration.isPressed ? 1 : 4, x: 0, y: 2)
    }
}

extension View {
    func cardBackground(cornerRadius: CGFloat = 16) -> some View {
        self
            .padding(18)
            .background(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(Theme.surface)
            )
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .stroke(Theme.divider, lineWidth: 1)
            )
            .shadow(color: Color.black.opacity(0.05), radius: 8, x: 0, y: 4)
    }
}
