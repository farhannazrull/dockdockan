import Carbon
import SecondDockKit
import SwiftUI

private let scaleKey = "dockScale"

@main
struct SecondDockApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var delegate

    var body: some Scene {
        Settings {
            EmptyView()
        }
    }
}

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var panelController: DockPanelController?
    private var statusItem: NSStatusItem?
    private var sizeLabel: NSTextField?
    private var sizeSlider: NSSlider?

    /// Batas atas efektif di layar ini: di luar itu bar akan di-cap 96%
    /// dan slider jadi diam-diam tidak berefek.
    private var maxScale: Double = 1.6

    var scale: Double {
        get {
            let v = UserDefaults.standard.double(forKey: scaleKey)
            return v == 0 ? 1.0 : min(max(v, 0.6), maxScale)
        }
        set {
            UserDefaults.standard.set(min(max(newValue, 0.6), maxScale), forKey: scaleKey)
        }
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        maxScale = DockPanelController.maxFittingScale(
            screenWidth: NSScreen.screens.first?.frame.width ?? 1680)
        panelController = DockPanelController()
        panelController?.show()
        applyScale(min(scale, maxScale), animate: false)
        HotKeys.register(plus: { [weak self] in self?.nudge(0.05) },
                         minus: { [weak self] in self?.nudge(-0.05) })
        buildMenu()
    }

    private func applyScale(_ value: Double, animate: Bool = true) {
        let rounded = (value * 20).rounded() / 20
        scale = rounded
        panelController?.refresh(scale: rounded)
        sizeSlider?.doubleValue = rounded
        sizeLabel?.stringValue = String(format: "Size %.2f", rounded)
        _ = animate
    }

    private func nudge(_ delta: Double) {
        applyScale(scale + delta)
    }

    private func buildMenu() {
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        item.button?.title = "◫"
        let menu = NSMenu()

        let header = NSMenuItem(title: "Dock Size", action: nil, keyEquivalent: "")
        header.isEnabled = false
        menu.addItem(header)

        let sliderItem = NSMenuItem(title: "", action: nil, keyEquivalent: "")
        let box = NSView(frame: NSRect(x: 0, y: 0, width: 230, height: 52))
        let slider = NSSlider(value: scale, minValue: 0.6, maxValue: maxScale,
                              target: self, action: #selector(sliderChanged(_:)))
        slider.frame = NSRect(x: 14, y: 22, width: 202, height: 20)
        let label = NSTextField(labelWithString: String(format: "Size %.2f", scale))
        label.frame = NSRect(x: 14, y: 2, width: 202, height: 16)
        label.font = .systemFont(ofSize: 11)
        box.addSubview(slider)
        box.addSubview(label)
        sliderItem.view = box
        menu.addItem(sliderItem)
        sizeSlider = slider
        sizeLabel = label

        let bigger = NSMenuItem(title: "Bigger", action: #selector(bigger), keyEquivalent: "+")
        bigger.keyEquivalentModifierMask = [.command, .option]
        menu.addItem(bigger)
        let smaller = NSMenuItem(title: "Smaller", action: #selector(smaller), keyEquivalent: "-")
        smaller.keyEquivalentModifierMask = [.command, .option]
        menu.addItem(smaller)
        menu.addItem(NSMenuItem(title: "Reset (1.0)", action: #selector(reset), keyEquivalent: ""))

        let focusSubmenu = NSMenu()
        for minutes in FocusViewModel.choices {
            let entry = NSMenuItem(title: "\(minutes) min", action: #selector(setFocusLength(_:)),
                                   keyEquivalent: "")
            entry.target = self
            entry.representedObject = minutes
            entry.state = (panelController?.focus.minutes == minutes) ? .on : .off
            focusSubmenu.addItem(entry)
        }
        let focusItem = NSMenuItem(title: "Focus length", action: nil, keyEquivalent: "")
        focusItem.submenu = focusSubmenu
        menu.addItem(focusItem)

        let login = NSMenuItem(title: "Launch at Login", action: #selector(toggleLogin(_:)), keyEquivalent: "")
        login.state = LaunchAtLogin.enabled ? .on : .off
        menu.addItem(login)

        menu.addItem(NSMenuItem.separator())
        menu.addItem(NSMenuItem(title: "Quit SecondDock", action: #selector(NSApplication.terminate(_:)), keyEquivalent: ""))
        item.menu = menu
        statusItem = item
    }

    @objc private func sliderChanged(_ sender: NSSlider) {
        applyScale(sender.doubleValue)
    }

    @objc private func bigger() { nudge(0.05) }
    @objc private func smaller() { nudge(-0.05) }
    @objc private func reset() { applyScale(1.0) }

    @objc private func setFocusLength(_ sender: NSMenuItem) {
        guard let minutes = sender.representedObject as? Int else { return }
        panelController?.focus.minutes = minutes
        panelController?.refresh(scale: scale)
    }

    @objc private func toggleLogin(_ sender: NSMenuItem) {
        LaunchAtLogin.set(!LaunchAtLogin.enabled)
        sender.state = LaunchAtLogin.enabled ? .on : .off
    }
}

/// Hotkey global Cmd+Opt+Plus/Minus via Carbon (jalan di LSUIElement agent).
enum HotKeys {
    static var plusAction: (() -> Void)?
    static var minusAction: (() -> Void)?
    private static var refs: [EventHotKeyRef?] = [nil, nil]

    static func register(plus: @escaping () -> Void, minus: @escaping () -> Void) {
        plusAction = plus
        minusAction = minus
        var type = EventTypeSpec(
            eventClass: OSType(kEventClassKeyboard),
            eventKind: UInt32(kEventHotKeyPressed)
        )
        InstallEventHandler(GetApplicationEventTarget(), hotKeyHandler, 1, &type, nil, nil)
        var id1 = EventHotKeyID(signature: OSType(0x53444331), id: 1) // "SDC1"
        var id2 = EventHotKeyID(signature: OSType(0x53444332), id: 2) // "SDC2"
        let mods = UInt32(cmdKey | optionKey)
        RegisterEventHotKey(UInt32(kVK_ANSI_Equal), mods, id1,
                            GetApplicationEventTarget(), 0, &refs[0])
        RegisterEventHotKey(UInt32(kVK_ANSI_Minus), mods, id2,
                            GetApplicationEventTarget(), 0, &refs[1])
    }
}

private func hotKeyHandler(_ next: EventHandlerCallRef?,
                           _ event: EventRef?,
                           _ data: UnsafeMutableRawPointer?) -> OSStatus {
    var hotID = EventHotKeyID()
    GetEventParameter(event,
                      UInt32(kEventParamDirectObject),
                      UInt32(typeEventHotKeyID),
                      nil,
                      MemoryLayout<EventHotKeyID>.size,
                      nil,
                      &hotID)
    if hotID.id == 1 { HotKeys.plusAction?() } else if hotID.id == 2 { HotKeys.minusAction?() }
    return noErr
}
