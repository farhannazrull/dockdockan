import SwiftUI

/// Tampilan murni: semua state masuk lewat init parameter.
struct NowPlayingWidget: View {
    let title: String
    let artist: String
    let artwork: NSImage?
    let elapsedText: String
    let totalText: String
    let fraction: Double
    let isPlaying: Bool
    var isEmpty = false
    var onPrevious: () -> Void = {}
    var onToggle: () -> Void = {}
    var onNext: () -> Void = {}
    var onSeek: ((Double) -> Void)? = nil
    var onOpenMusic: () -> Void = {}

    @Environment(\.theme) private var theme
    @Environment(\.colorScheme) private var scheme

    var body: some View {
        WidgetCard {
            VStack(alignment: .leading, spacing: theme.s(3)) {
                HStack(spacing: theme.s(8)) {
                    artworkView
                    if isEmpty {
                        Text("Nothing playing")
                            .font(theme.font(13, .semibold))
                            .lineLimit(1)
                            .truncationMode(.tail)
                            .frame(width: theme.s(128), alignment: .leading)
                        Spacer(minLength: theme.s(8))
                        Button(action: onOpenMusic) {
                            Text("Open Music")
                                .font(theme.font(11, .semibold))
                                .foregroundStyle(.white)
                                .lineLimit(1)
                                .fixedSize(horizontal: true, vertical: false)
                                .padding(.horizontal, theme.s(8))
                                .padding(.vertical, theme.s(4))
                                .background(Color.white.opacity(0.18))
                                .clipShape(Capsule(style: .continuous))
                        }
                        .buttonStyle(.plain)
                        .fixedSize(horizontal: true, vertical: false)
                    } else {
                        VStack(alignment: .leading, spacing: 0) {
                            Text(title)
                                .font(theme.font(13, .semibold))
                                .lineLimit(1)
                                .truncationMode(.tail)
                                .help(title)
                            Text(artist)
                                .font(theme.font(11))
                                .foregroundStyle(theme.secondaryText(scheme))
                                .lineLimit(1)
                                .truncationMode(.tail)
                                .help(artist)
                        }
                        .frame(width: theme.s(128), alignment: .leading)
                        Spacer(minLength: theme.s(8))
                        controls
                    }
                }
                if !isEmpty {
                    HStack(spacing: theme.s(6)) {
                        Text(elapsedText)
                            .font(theme.font(10, .medium))
                            .foregroundStyle(theme.tinyText(scheme))
                            .lineLimit(1)
                            .fixedSize(horizontal: true, vertical: false)
                        progressBar
                        Text(totalText)
                            .font(theme.font(10, .medium))
                            .foregroundStyle(theme.tinyText(scheme))
                            .lineLimit(1)
                            .fixedSize(horizontal: true, vertical: false)
                    }
                }
            }
        }
    }

    private var controls: some View {
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

    private var artworkView: some View {
        ZStack {
            RoundedRectangle(cornerRadius: theme.s(6), style: .continuous)
                .fill(Color.gray.opacity(0.4))
                .frame(width: theme.s(32), height: theme.s(32))
            if let artwork {
                Image(nsImage: artwork)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: theme.s(32), height: theme.s(32))
                    .clipShape(RoundedRectangle(cornerRadius: theme.s(6), style: .continuous))
            } else {
                Image(systemName: "music.note")
                    .font(theme.font(14))
                    .foregroundStyle(.white.opacity(0.8))
            }
        }
    }

    private var progressBar: some View {
        // Lebar tetap, bukan GeometryReader: GeometryReader rakus dan membuat
        // kartu melar sampai maxWidth.
        ZStack(alignment: .leading) {
            Capsule().fill(Color.white.opacity(0.20))
            Capsule().fill(Color.white)
                .frame(width: theme.s(112) * CGFloat(min(max(fraction, 0), 1)))
        }
        .frame(width: theme.s(112), height: theme.s(3))
        .contentShape(Rectangle())
        .onTapGesture { point in
            guard theme.s(112) > 0 else { return }
            onSeek?(min(max(Double(point.x / theme.s(112)), 0), 1))
        }
    }
}

struct NowPlayingWidget_Previews: PreviewProvider {
    static var previews: some View {
        NowPlayingWidget(title: "The Entertainer", artist: "Scott Joplin",
                         artwork: nil, elapsedText: "0:00", totalText: "5:06",
                         fraction: 0, isPlaying: false)
            .environment(\.theme, Theme(scale: 1))
            .padding()
            .background(Color.black)
    }
}