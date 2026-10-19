import AppKit
import Combine
import Foundation
import IOKit.ps

public enum BatteryRingTone: Equatable {
    case good, low, critical
}

/// Satu cincin baterai. View hanya membaca nilai-nilai ini.
public struct BatteryRingState: Equatable, Identifiable {
    public let id: String
    public let symbol: String
    public let name: String
    public let pct: Int
    public let isCharging: Bool

    public init(id: String, symbol: String, name: String, pct: Int, isCharging: Bool) {
        self.id = id
        self.symbol = symbol
        self.name = name
        self.pct = pct
        self.isCharging = isCharging
    }

    public var tone: BatteryRingTone {
        if pct > 20 { return .good }
        if pct >= 10 { return .low }
        return .critical
    }
}

/// Sumber data Battery widget.
///
/// Sumber level baterai: IOKit power sources. Perangkat Bluetooth HID yang
/// terhubung (keyboard/mouse/trackpad) muncul di sana dengan
/// `Transport Type = "Bluetooth"`. Baterai Mac sendiri
/// (`InternalBattery`) dipakai sebagai cadangan kalau tidak ada BT yang
/// melaporkan.
///
/// Catatan: `IOBluetoothDevice.batteryLevel` tidak tersedia di SDK ini, dan
/// AirPods tidak pernah muncul sebagai power source — keduanya tidak bisa
/// dilaporkan tanpa API privat.
@MainActor
public final class BatteryViewModel: ObservableObject {
    @Published public private(set) var rings: [BatteryRingState] = []

    private var timer: Timer?
    private var psRunLoop: CFRunLoopSource?
    private var observers: [NSObjectProtocol] = []
    private var didAppear = false

    private static let recentKey = "batteryRecentOrder"
    /// API publik Bluetooth tidak mengekspos waktu koneksi, jadi urutan
    /// "paling baru terhubung" dicatat dari device yang pertama terlihat.
    private static var recentOrder: [String] {
        get { UserDefaults.standard.stringArray(forKey: recentKey) ?? [] }
        set { UserDefaults.standard.set(newValue, forKey: recentKey) }
    }

    /// `readDevices: false` membuat instans tanpa menyentuh IOKit sama sekali
    /// (dipakai pratinjau/render offscreen saat launch).
    public init(readDevices: Bool = true) {
        if readDevices { refresh() }
    }

    deinit {
        timer?.invalidate()
        if let psRunLoop { CFRunLoopRemoveSource(CFRunLoopGetMain(), psRunLoop, .commonModes) }
        for token in observers {
            NotificationCenter.default.removeObserver(token)
        }
    }

    public func appear() {
        guard !didAppear else { return }
        didAppear = true
        refresh()
        startTimers()
        startPowerNotifications()
    }

    private func startTimers() {
        timer?.invalidate()
        let t = Timer(timeInterval: 60, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated { self?.refresh() }
        }
        RunLoop.main.add(t, forMode: .common)
        timer = t
        observers.append(NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didWakeNotification, object: nil, queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated { self?.refresh() }
        })
    }

    /// Notifikasi power source IOKit lewat run loop (tidak ada di NotificationCenter).
    private func startPowerNotifications() {
        guard psRunLoop == nil else { return }
        // C function pointer tidak bisa capture, jadi self lewat `context`.
        let handler: IOPowerSourceCallbackType = { context in
            guard let context else { return }
            let vm = Unmanaged<BatteryViewModel>.fromOpaque(context).takeUnretainedValue()
            MainActor.assumeIsolated { vm.refresh() }
        }
        let source = IOPSNotificationCreateRunLoopSource(
            handler, Unmanaged.passUnretained(self).toOpaque()
        ).takeRetainedValue()
        psRunLoop = source
        CFRunLoopAddSource(CFRunLoopGetMain(), source, .commonModes)
    }

    // MARK: - Pengumpulan data

    public func refresh() {
        let sources = Self.powerSources()
        let bluetooth = sources
            .filter { $0.transport.lowercased() == "bluetooth" }
            .compactMap { entry -> BatteryRingState? in
                guard let pct = entry.percent else { return nil }
                let name = entry.name == "InternalBattery-0" ? "Bluetooth" : entry.name
                return BatteryRingState(
                    id: "bt-" + name.lowercased(),
                    symbol: Self.symbol(forName: name),
                    name: name,
                    pct: pct,
                    isCharging: entry.isCharging
                )
            }
        let ordered = Self.sortedByRecent(bluetooth)
        rings = Array(ordered.prefix(2))
        if rings.isEmpty, let own = Self.ownBattery(from: sources) {
            rings = [own]
        }
    }

    private struct Source {
        let name: String
        let transport: String
        let percent: Int?
        let isCharging: Bool
    }

    private static func powerSources() -> [Source] {
        guard let info = IOPSCopyPowerSourcesInfo()?.takeRetainedValue(),
              let list = IOPSCopyPowerSourcesList(info)?.takeRetainedValue() as? [CFTypeRef]
        else { return [] }
        var out: [Source] = []
        for raw in list {
            guard let d = IOPSGetPowerSourceDescription(info, raw)?
                .takeUnretainedValue() as? [String: Any] else { continue }
            let name = d["Name"] as? String ?? ""
            let transport = d["Transport Type"] as? String ?? ""
            let current = d["Current Capacity"] as? Int
            let maximum = d["Max Capacity"] as? Int
            let percent: Int?
            if let current, let maximum, maximum > 0 {
                percent = min(100, max(0, Int((Double(current) / Double(maximum) * 100).rounded())))
            } else {
                percent = nil
            }
            out.append(Source(
                name: name,
                transport: transport,
                percent: percent,
                isCharging: (d["Is Charging"] as? Bool) ?? false
            ))
        }
        return out
    }

    private static func ownBattery(from sources: [Source]) -> BatteryRingState? {
        guard let entry = sources.first(where: { $0.name.hasPrefix("InternalBattery") }),
              let pct = entry.percent else { return nil }
        // Sengaja tidak memakai ProcessInfo.hostName: getter itu melakukan
        // reverse-DNS lookup dan bisa menggantungkan thread utama saat launch.
        return BatteryRingState(
            id: "internal-battery",
            symbol: entry.isCharging ? "battery.100" : "laptopcomputer",
            name: "Mac",
            pct: pct,
            isCharging: entry.isCharging
        )
    }

    /// IOBluetoothDevice.pairedDevices() sengaja tidak dipakai: panggilan itu
    /// memunculkan persetujuan TCC dan memblokir thread sampai dijawab user —
    /// saat diuji malah menggantungkan launch app. Nama power source untuk
    /// perangkat Bluetooth HID sudah berupa nama produk ("Magic Keyboard"),
    /// jadi pencocokan berdasarkan nama sudah cukup.
    private static func symbol(forName name: String) -> String {
        let lower = name.lowercased()
        if lower.contains("airpods") || lower.contains("pods") { return "airpods" }
        if lower.contains("keyboard") { return "keyboard" }
        if lower.contains("mouse") || lower.contains("trackpad") { return "computermouse" }
        return "laptopcomputer"
    }

    /// Device yang belum pernah terlihat dianggap paling baru dan naik ke depan.
    private static func sortedByRecent(_ rings: [BatteryRingState]) -> [BatteryRingState] {
        var order = recentOrder
        for ring in rings where !order.contains(ring.id) {
            order.insert(ring.id, at: 0)
        }
        order = order.filter { id in rings.contains { $0.id == id } }
        recentOrder = order
        return rings.sorted { (order.firstIndex(of: $0.id) ?? .max)
            < (order.firstIndex(of: $1.id) ?? .max) }
    }

    /// Dipakai pratinjau/render offscreen: tanpa menyentuh perangkat.
    public static let preview: BatteryViewModel = {
        let vm = BatteryViewModel(readDevices: false)
        vm.rings = [
            BatteryRingState(id: "a", symbol: "airpods", name: "AirPods", pct: 85, isCharging: false),
            BatteryRingState(id: "b", symbol: "keyboard", name: "Keyboard", pct: 92, isCharging: false),
        ]
        return vm
    }()
}