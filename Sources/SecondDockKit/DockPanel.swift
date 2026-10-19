import AppKit
import SwiftUI

/// Borderless nonactivating NSPanel: .floating, semua Space + fullScreenAuxiliary,
/// tanpa shadow sistem (digambar sendiri). Ukuran mengikuti skala konten.
public final class DockPanel: NSPanel {
    public override init(contentRect: NSRect, styleMask style: NSWindow.StyleMask,
                         backing backingStoreType: NSWindow.BackingStoreType, defer flag: Bool) {
        super.init(contentRect: contentRect, styleMask: [.borderless, .nonactivatingPanel],
                   backing: .buffered, defer: false)
        isFloatingPanel = true
        level = .floating
        collectionBehavior = [.canJoinAllSpaces, .stationary, .fullScreenAuxiliary, .ignoresCycle]
        backgroundColor = .clear
        isOpaque = false
        hasShadow = false
        hidesOnDeactivate = false
        isMovableByWindowBackground = true
        acceptsMouseMovedEvents = true
    }

    public required init?(coder: NSCoder) { fatalError("init(coder:) tidak dipakai") }

    public override var canBecomeKey: Bool { false }
    public override var canBecomeMain: Bool { false }
}

@MainActor
public final class DockPanelController {
    public let focus = FocusViewModel()
    public let calendar = CalendarViewModel()
    public let battery = BatteryViewModel()
    private var panel: DockPanel?
    var onRefresh: (() -> Void)?

    public init() {}

    public func show() {
        if panel == nil {
            panel = DockPanel(contentRect: NSRect(x: 0, y: 0, width: 600, height: 56),
                              styleMask: [.borderless, .nonactivatingPanel],
                              backing: .buffered, defer: false)
        }
        refresh(scale: Self.currentScale())
        panel?.orderFrontRegardless()
    }

    static func currentScale() -> Double {
        let v = UserDefaults.standard.double(forKey: "dockScale")
        return v == 0 ? 1.0 : min(max(v, 0.6), 1.6)
    }

    /// Lebar dock linear terhadap skala, jadi cukup ukur sekali di skala 1.
    @MainActor static func measure(scale: Double, focus: FocusViewModel = .preview,
                                   calendar: CalendarViewModel = .preview,
                                   battery: BatteryViewModel = .preview) -> NSSize {
        let host = NSHostingView(
            rootView: DockView(focus: focus, calendar: calendar, battery: battery)
                .environment(\.theme, Theme(scale: scale)))
        host.layoutSubtreeIfNeeded()
        return host.fittingSize
    }

    /// Skala terbesar yang bar-nya masih ≤96% lebar layar.
    /// Dipakai slider supaya tidak ada rentang mati (skala yang diam-diam di-cap).
    public static func maxFittingScale(screenWidth: CGFloat) -> Double {
        let unit = measure(scale: 1).width
        guard unit > 0 else { return 1.6 }
        let maxW = screenWidth * 0.96
        guard maxW < unit else { return 1.6 }
        return max(0.6, (maxW / unit * 20).rounded() / 20)
    }

    /// Bangun ulang dengan skala efektif; cap agar ≤96% layar, re-anchor bawah-tengah.
    public func refresh(scale: Double) {
        guard let panel else { return }
        let maxW = (Self.targetScreen(for: panel)?.frame.width ?? 1680) * 0.96
        var effective = scale
        var size = NSSize(width: 0, height: 0)
        // Skala-kecilkan sampai muat, lalu JALANKAN minimal sekali walau
        // masih > maxW — kalau tidak, loop habis tanpa pernah menerapkan frame.
        for _ in 0 ..< 4 {
            size = Self.measure(scale: effective, focus: focus, calendar: calendar,
                                   battery: battery)
            if size.width <= maxW { break }
            effective = max(0.4, effective * maxW / size.width)
        }
        // contentView dulu: assigning contentView menimpa ukuran window,
        // jadi harus sebelum setFrame agar hasil animasi tidak ketimpa.
        panel.contentView = NSHostingView(
            rootView: DockView(focus: focus, calendar: calendar, battery: battery)
                .environment(\.theme, Theme(scale: effective))
        )
        animate(panel, to: size, scale: effective)
        onRefresh?()
    }

    /// Layar acuan. NSScreen.main == nil untuk LSUIElement tanpa key window,
    /// jadi pakai layar yang memuat frame panel, lalu layar pertama.
    static func targetScreen(for panel: NSPanel) -> NSScreen? {
        let center = NSPoint(x: panel.frame.midX, y: panel.frame.midY)
        if let hit = NSScreen.screens.first(where: { $0.frame.contains(center) }) { return hit }
        return NSScreen.main ?? NSScreen.screens.first
    }

    private func animate(_ panel: DockPanel, to size: NSSize, scale: Double) {
        let screen = Self.targetScreen(for: panel)
        let frame = screen?.visibleFrame ?? NSRect(x: 0, y: 0, width: 1440, height: 900)
        let x = frame.minX + (frame.width - size.width) / 2
        let target = NSRect(x: x, y: frame.minY + 12 * scale, width: size.width, height: size.height)
        let reduceMotion = NSWorkspace.shared.accessibilityDisplayShouldReduceMotion
        guard panel.isVisible, !reduceMotion else {
            // animator() diabaikan untuk window yang belum pernah di-order-in.
            panel.setFrame(target, display: panel.isVisible)
            return
        }
        NSAnimationContext.runAnimationGroup { ctx in
            ctx.duration = 0.15
            ctx.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
            panel.animator().setFrame(target, display: true)
        }
    }
}