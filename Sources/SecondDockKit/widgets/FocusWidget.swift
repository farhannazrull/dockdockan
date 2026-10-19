import SwiftUI

/// Tampilan murni: seluruh state masuk lewat init. Logika ada di FocusViewModel.
struct FocusWidget: View {
    let remaining: String
    let progress: Double // 0...1 busur terisi
    var label: String = "Focus"
    var isSuccess = false
    var onToggle: () -> Void = {}
    var onReset: () -> Void = {}

    @Environment(\.theme) private var theme
    @Environment(\.colorScheme) private var scheme
    @State private var hovering = false

    var body: some View {
        WidgetCard {
            HStack(spacing: theme.s(8)) {
                ZStack {
                    Circle()
                        .stroke(theme.ringTrack(scheme), lineWidth: theme.s(3))
                        .frame(width: theme.s(30), height: theme.s(30))
                    Circle()
                        .trim(from: 0, to: min(max(progress, 0), 1))
                        .stroke(isSuccess ? Theme.positiveGreen : Theme.accentOrange,
                                lineWidth: theme.s(3))
                        .rotationEffect(.degrees(-90))
                        .frame(width: theme.s(30), height: theme.s(30))
                        .animation(.linear(duration: 1), value: progress)
                    // Glyph reset hanya saat hover; allowsHitTesting supaya
                    // tidak memblokir tap kartu saat tidak terlihat.
                    Button(action: onReset) {
                        Image(systemName: "arrow.counterclockwise")
                            .font(theme.font(10))
                            .foregroundStyle(.white)
                    }
                    .buttonStyle(.plain)
                    .opacity(hovering ? 1 : 0)
                    .allowsHitTesting(hovering)
                }
                VStack(alignment: .leading, spacing: 0) {
                    Text(remaining)
                        .font(theme.mono(20, .semibold))
                        .lineLimit(1)
                        .fixedSize(horizontal: true, vertical: false)
                    Text(label)
                        .font(theme.font(11))
                        .foregroundStyle(theme.secondaryText(scheme))
                        .lineLimit(1)
                        // Lebar tetap: "Paused" lebih panjang dari "Focus",
                        // minWidth mencegah kartu ikut bergeser.
                        .frame(minWidth: theme.s(40), alignment: .leading)
                }
            }
        }
        .onHover { hovering = $0 }
        .onTapGesture(perform: onToggle)
    }
}

struct FocusWidget_Previews: PreviewProvider {
    static var previews: some View {
        FocusWidget(remaining: "3:23", progress: 0.15)
            .environment(\.theme, Theme(scale: 1))
            .padding()
            .background(Color.black)
    }
}