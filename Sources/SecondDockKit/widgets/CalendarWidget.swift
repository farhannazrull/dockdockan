import AppKit
import SwiftUI

struct CalendarWidget: View {
    let weekday: String
    let day: String
    let title: String
    let time: String
    var dotColor: Color = Theme.accentOrange
    var meetingURL: URL? = nil
    var mode: CalendarCardMode = .event
    var onAllow: () -> Void = {}
    var onJoin: () -> Void = {}

    @Environment(\.theme) private var theme

    var body: some View {
        WidgetCard {
            HStack(spacing: theme.s(8)) {
                VStack(spacing: 0) {
                    Text(weekday)
                        .font(theme.font(9, .bold))
                        .foregroundStyle(Theme.dangerRed)
                        .lineLimit(1)
                        .fixedSize(horizontal: true, vertical: false)
                    Text(day)
                        .font(theme.font(18, .semibold))
                        .lineLimit(1)
                        .fixedSize(horizontal: true, vertical: false)
                }
                .frame(width: theme.s(30), height: theme.s(34))
                .background(Color.white.opacity(0.10))
                .clipShape(RoundedRectangle(cornerRadius: theme.s(7), style: .continuous))
                middle
                // ZStack (bukan Group) supaya slot 28pt selalu ada walau
                // tombol video disembunyikan: kartu tidak bergeser.
                ZStack {
                    if let url = meetingURL {
                        Button(action: onJoin) {
                            Image(systemName: "video.fill")
                                .font(theme.font(13))
                                .foregroundStyle(.white)
                                .frame(width: theme.s(28), height: theme.s(28))
                                .background(Color.white.opacity(0.15))
                                .clipShape(Circle())
                        }
                        .buttonStyle(.plain)
                        .help("Buka \(url.absoluteString)")
                    }
                }
                .frame(width: theme.s(28), height: theme.s(28))
            }
        }
    }

    @Environment(\.colorScheme) private var colorScheme

    @ViewBuilder
    private var middle: some View {
        switch mode {
        case .event:
            HStack(spacing: theme.s(8)) {
                // Slot 14pt sama dengan ikon di mode lain supaya lebar
                // kartu identik di ketiga state.
                Circle().fill(dotColor)
                    .frame(width: theme.s(6), height: theme.s(6))
                    .frame(width: theme.s(14))
                VStack(alignment: .leading, spacing: 0) {
                    Text(title)
                        .font(theme.font(13, .semibold))
                        .lineLimit(1)
                        .truncationMode(.tail)
                        .help(title)
                    Text(time)
                        .font(theme.font(11))
                        .foregroundStyle(theme.secondaryText(colorScheme))
                        .lineLimit(1)
                        .fixedSize(horizontal: true, vertical: false)
                }
                .frame(width: theme.s(110), alignment: .leading)
            }
        case .noEvents:
            HStack(spacing: theme.s(8)) {
                Image(systemName: "checkmark")
                    .font(theme.font(13, .semibold))
                    .foregroundStyle(Theme.positiveGreen)
                    .frame(width: theme.s(14))
                Text("No more events today")
                    .font(theme.font(13, .semibold))
                    .lineLimit(1)
                    .truncationMode(.tail)
                    .frame(width: theme.s(110), alignment: .leading)
            }
        case .needsAccess:
            HStack(spacing: theme.s(8)) {
                Image(systemName: "calendar")
                    .font(theme.font(13, .semibold))
                    .foregroundStyle(theme.secondaryText(colorScheme))
                    .frame(width: theme.s(14))
                Button(action: onAllow) {
                    Text("Allow Calendar")
                        .font(theme.font(13, .semibold))
                        .foregroundStyle(.white)
                }
                .buttonStyle(.plain)
                .frame(width: theme.s(110), alignment: .leading)
            }
        }
    }
}

struct CalendarWidget_Previews: PreviewProvider {
    static var previews: some View {
        CalendarWidget(weekday: "THU", day: "8", title: "Design review", time: "10:30")
            .environment(\.theme, Theme(scale: 1))
            .padding()
            .background(Color.black)
    }
}
