import AppKit
import SwiftUI

/// Kaca dock: NSVisualEffectView adaptif — .hudWindow di dark mode
/// (material paling dekat Dock asli), .underWindowBackground di light.
struct GlassBackground: View {
    @Environment(\.colorScheme) var scheme
    @Environment(\.theme) var theme
    @Environment(\.glassFallback) var fallback

    var body: some View {
        if let fallback {
            RoundedRectangle(cornerRadius: theme.s(26), style: .continuous)
                .fill(fallback)
        } else {
            EffectView(scheme: scheme, radius: theme.s(26))
        }
    }
}

public struct GlassFallbackKey: EnvironmentKey {
    public static let defaultValue: Color? = nil
}

extension EnvironmentValues {
    public var glassFallback: Color? {
        get { self[GlassFallbackKey.self] }
        set { self[GlassFallbackKey.self] = newValue }
    }
}

private struct EffectView: NSViewRepresentable {
    let scheme: ColorScheme
    let radius: CGFloat

    func makeNSView(context: Context) -> NSVisualEffectView {
        let view = NSVisualEffectView()
        view.blendingMode = .behindWindow
        view.state = .active
        view.wantsLayer = true
        view.layer?.masksToBounds = true
        view.layer?.borderWidth = 1
        view.material = scheme == .dark ? .hudWindow : .underWindowBackground
        view.layer?.cornerRadius = radius
        view.layer?.borderColor = NSColor.white.withAlphaComponent(0.18).cgColor
        return view
    }

    func updateNSView(_ view: NSVisualEffectView, context: Context) {}
}

/// Urutan persis referensi. Tanpa Spacer — semua gap = theme gap.
/// Layar sempit: skala di-cap controller (tidak pernah squash di bawah minWidth).
public struct DockView: View {
    @Environment(\.theme) private var theme
    @ObservedObject private var focus: FocusViewModel
    @ObservedObject private var calendar: CalendarViewModel
    @ObservedObject private var battery: BatteryViewModel
    @ObservedObject private var store: DockStore
    @ObservedObject private var note: NoteViewModel
    @ObservedObject private var nowPlaying: NowPlayingViewModel

    public init(focus: FocusViewModel = FocusViewModel.preview,
                calendar: CalendarViewModel = CalendarViewModel.preview,
                battery: BatteryViewModel = BatteryViewModel.preview,
                store: DockStore = DockStore.preview,
                note: NoteViewModel = NoteViewModel.preview,
                nowPlaying: NowPlayingViewModel = NowPlayingViewModel.preview) {
        _focus = ObservedObject(wrappedValue: focus)
        _calendar = ObservedObject(wrappedValue: calendar)
        _battery = ObservedObject(wrappedValue: battery)
        _store = ObservedObject(wrappedValue: store)
        _note = ObservedObject(wrappedValue: note)
        _nowPlaying = ObservedObject(wrappedValue: nowPlaying)
    }

    public var body: some View {
        // Ruang di atas hanya muncul saat mengedit: panel memanjang ke atas
        // sehingga posisi bar di layar tidak bergeser.
        VStack(spacing: 0) {
            if note.isEditing {
                Color.clear.frame(height: theme.s(92))
            }
            bar
        }
        .fixedSize(horizontal: true, vertical: true)
        .padding(.vertical, theme.s(12))
    }

    private var bar: some View {
        ZStack {
            GlassBackground()
                .shadow(color: Color.black.opacity(0.35),
                        radius: theme.s(18), x: 0, y: theme.s(6))
            HStack(spacing: theme.s(16)) {
                appIcon(store.leadingApps.first ?? "com.apple.finder")
                StockWidget(symbol: "AAPL", price: "333.08", change: "+0.24%",
                            points: PreviewData.sparkAAPL)
                FolderTile(letter: "P", path: store.folderPath,
                           onOpen: { store.openFolder() })
                appIcon(store.leadingApps.count > 1 ? store.leadingApps[1] : "",
                        badge: store.badgeCount)
                NowPlayingWidget(
                    title: nowPlaying.track?.title ?? "Nothing playing",
                    artist: nowPlaying.track?.artist ?? "",
                    artwork: nowPlaying.track?.artwork,
                    elapsedText: DockFormatters.countdown(Int(nowPlaying.elapsed.rounded())),
                    totalText: DockFormatters.countdown(Int(nowPlaying.durationText.rounded())),
                    fraction: nowPlaying.progressFraction,
                    isPlaying: nowPlaying.isPlaying,
                    isEmpty: nowPlaying.track == nil,
                    onPrevious: { nowPlaying.previous() },
                    onToggle: { nowPlaying.toggle() },
                    onNext: { nowPlaying.next() },
                    onSeek: { nowPlaying.seek(to: $0) },
                    onOpenMusic: { nowPlaying.openMusic() }
                )
                .onAppear { nowPlaying.appear() }
                FocusWidget(remaining: focus.remainingText,
                              progress: focus.progress,
                              label: focus.label,
                              isSuccess: focus.phase == .finished,
                              onToggle: { focus.toggle() },
                              onReset: { focus.reset() })
                CalendarWidget(weekday: calendar.state.weekday,
                               day: calendar.state.day,
                               title: calendar.state.title,
                               time: calendar.state.time,
                               dotColor: calendar.state.dotColor,
                               meetingURL: calendar.state.meetingURL,
                               mode: calendar.state.mode,
                               onAllow: { calendar.allow() },
                               onJoin: { calendar.join() })
                    .onAppear { calendar.appear() }
                BatteryWidget(rings: battery.rings)
                    .onAppear { battery.appear() }
                RevenueWidget(label: "Studio", value: "$3.9K", points: PreviewData.sparkRevenue)
                NoteWidget(note: note)
                DividerTile()
                PagedAppsView(apps: store.pagedApps, store: store)
            }
            .padding(.leading, theme.s(16))
            .padding(.trailing, theme.s(18))
            .padding(.vertical, theme.cardPadding)
        }
        .frame(height: theme.barHeight)
    }
}

extension DockView {
    @ViewBuilder
    private func appIcon(_ bundleID: String, badge: Int? = nil) -> some View {
        if !bundleID.isEmpty {
            AppIcon(
                bundleID: bundleID,
                badge: badge,
                isRunning: store.isRunning(bundleID),
                isInstalled: store.isInstalled(bundleID),
                onOpen: { store.launch(bundleID) },
                onReveal: { store.reveal(bundleID) },
                onRemove: { store.remove(bundleID: bundleID) }
            )
            .onAppear { store.appear() }
        }
    }
}

struct DockView_Previews: PreviewProvider {
    static var previews: some View {
        ForEach([0.6, 1.0, 1.6], id: \.self) { scale in
            DockView()
                .environment(\.theme, Theme(scale: scale))
                .padding()
                .background(Color.black)
                .previewDisplayName("Dock \(scale) dark")
            DockView()
                .environment(\.theme, Theme(scale: scale))
                .preferredColorScheme(.light)
                .padding()
                .previewDisplayName("Dock \(scale) light")
        }
    }
}
