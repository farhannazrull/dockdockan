import SwiftUI

/// Tema TANPA angka tetap: semua token = base * scale.
/// Skala diedarkan lewat Environment (\.theme), bukan lewat init.
public struct Theme {
    public let scale: Double
    public init(scale: Double) { self.scale = scale }

    public func s(_ base: CGFloat) -> CGFloat { base * scale }

    // Metrik baris bersama agar kartu 3-baris tidak terpotong di skala mana pun.
    // Kartu = tiny + value + tiny + 2*6pt padding; bar = kartu + 2*6pt.
    public var lineTiny: CGFloat { s(12) }
    public var lineValue: CGFloat { s(24) }
    public var cardPadding: CGFloat { s(6) }
    public var cardHeight: CGFloat { lineTiny + lineValue + lineTiny + cardPadding * 2 }
    public var barHeight: CGFloat { cardHeight + cardPadding * 2 }

    public func font(_ base: CGFloat, _ weight: Font.Weight = .regular) -> Font {
        .system(size: base * scale, weight: weight)
    }

    public func mono(_ base: CGFloat, _ weight: Font.Weight = .regular) -> Font {
        .system(size: base * scale, weight: weight, design: .default).monospacedDigit()
    }

    // Warna inti (tidak ikut skala)
    public static let positiveGreen = Color(hex: 0x34C759)
    public static let accentOrange = Color(hex: 0xFF9F0A)
    public static let teal = Color(hex: 0x30B0C7)
    public static let dangerRed = Color(hex: 0xFF453A)
    public static let noteYellow = Color(hex: 0xF2D369)
    public static let noteText = Color(hex: 0x2A2200)

    // Adaptif terang/gelap
    public func cardFill(_ scheme: ColorScheme) -> Color {
        scheme == .dark ? Color.white.opacity(0.08) : Color.black.opacity(0.06)
    }

    public func cardFillHover(_ scheme: ColorScheme) -> Color {
        scheme == .dark ? Color.white.opacity(0.12) : Color.black.opacity(0.10)
    }

    public func primaryGlyph(_ scheme: ColorScheme) -> Color {
        scheme == .dark ? Color.white : Color.black
    }

    public func secondaryText(_ scheme: ColorScheme) -> Color {
        scheme == .dark ? Color.white.opacity(0.55) : Color.black.opacity(0.55)
    }

    public func tinyText(_ scheme: ColorScheme) -> Color {
        scheme == .dark ? Color.white.opacity(0.50) : Color.black.opacity(0.50)
    }

    public func divider(_ scheme: ColorScheme) -> Color {
        scheme == .dark ? Color.white.opacity(0.15) : Color.black.opacity(0.12)
    }

    public func ringTrack(_ scheme: ColorScheme) -> Color {
        scheme == .dark ? Color.white.opacity(0.15) : Color.black.opacity(0.10)
    }
}

public struct ThemeKey: EnvironmentKey {
    public static let defaultValue = Theme(scale: 1)
}

extension EnvironmentValues {
    public var theme: Theme {
        get { self[ThemeKey.self] }
        set { self[ThemeKey.self] = newValue }
    }
}

extension Color {
    public init(hex: UInt32) {
        self.init(
            red: Double((hex >> 16) & 0xFF) / 255,
            green: Double((hex >> 8) & 0xFF) / 255,
            blue: Double(hex & 0xFF) / 255
        )
    }
}

/// Kartu widget: tinggi + radius + padding dari tema, hover putih @12% 120ms.
struct WidgetCard<Content: View>: View {
    @Environment(\.theme) private var theme
    @Environment(\.colorScheme) private var scheme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var hovering = false
    let content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        content
            .padding(.horizontal, theme.s(12))
            .padding(.vertical, theme.cardPadding)
            .frame(height: theme.cardHeight)
            .background(hovering ? theme.cardFillHover(scheme) : theme.cardFill(scheme))
            .clipShape(RoundedRectangle(cornerRadius: theme.s(14), style: .continuous))
            .animation(reduceMotion ? nil : .easeInOut(duration: 0.12), value: hovering)
            .onHover { hovering = $0 }
    }
}
