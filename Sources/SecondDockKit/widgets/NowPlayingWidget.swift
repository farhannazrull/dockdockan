import SwiftUI

struct NowPlayingWidget: View {
    let title: String
    let artist: String
    let elapsed: String
    let total: String
    let fraction: Double
    let isPlaying: Bool
    var onPrevious: () -> Void = {}
    var onToggle: () -> Void = {}
    var onNext: () -> Void = {}

    @Environment(\.theme) private var theme

    var body: some View {
        WidgetCard {
            VStack(alignment: .leading, spacing: theme.s(3)) {
                HStack(spacing: theme.s(8)) {
                    ZStack {
                        RoundedRectangle(cornerRadius: theme.s(6), style: .continuous)
                            .fill(Color.gray.opacity(0.4))
                            .frame(width: theme.s(32), height: theme.s(32))
                        Image(systemName: "music.note")
                            .font(theme.font(14))
                            .foregroundStyle(.white.opacity(0.8))
                    }
                    VStack(alignment: .leading, spacing: 0) {
                        Text(title)
                            .font(theme.font(13, .semibold))
                            .lineLimit(1)
                            .truncationMode(.tail)
                            .help(title)
                        Text(artist)
                            .font(theme.font(11))
                            .foregroundStyle(theme.secondaryText(colorScheme))
                            .lineLimit(1)
                            .truncationMode(.tail)
                    }
                    .frame(width: theme.s(128), alignment: .leading)
                    Spacer(minLength: theme.s(8))
                    HStack(spacing: theme.s(14)) {
                        Button(action: onPrevious) {
                            Image(systemName: "backward.end.fill").font(theme.font(22))
                        }
                        Button(action: onToggle) {
                            Image(systemName: isPlaying ? "pause.fill" : "play.fill")
                                .font(theme.font(26))
                        }
                        Button(action: onNext) {
                            Image(systemName: "forward.end.fill").font(theme.font(22))
                        }
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(.white)
                }
                HStack(spacing: theme.s(6)) {
                    Text(elapsed)
                        .font(theme.font(10, .medium))
                        .foregroundStyle(theme.tinyText(colorScheme))
                        .lineLimit(1)
                        .fixedSize(horizontal: true, vertical: false)
                    // Lebar tetap, bukan GeometryReader: GeometryReader rakus
                    // dan membuat kartu melar sampai maxWidth.
                    ZStack(alignment: .leading) {
                        Capsule().fill(Color.white.opacity(0.20))
                        Capsule().fill(Color.white)
                            .frame(width: theme.s(112) * CGFloat(min(max(fraction, 0), 1)))
                    }
                    .frame(width: theme.s(112), height: theme.s(3))
                    Text(total)
                        .font(theme.font(10, .medium))
                        .foregroundStyle(theme.tinyText(colorScheme))
                        .lineLimit(1)
                        .fixedSize(horizontal: true, vertical: false)
                }
            }
        }
    }

    @Environment(\.colorScheme) private var colorScheme
}

struct NowPlayingWidget_Previews: PreviewProvider {
    static var previews: some View {
        NowPlayingWidget(title: "The Entertainer", artist: "Scott Joplin",
                         elapsed: "0:00", total: "5:06", fraction: 0, isPlaying: false)
            .environment(\.theme, Theme(scale: 1))
            .padding()
            .background(Color.black)
    }
}
