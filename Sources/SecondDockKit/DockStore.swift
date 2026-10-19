import AppKit
import ApplicationServices
import Combine
import Foundation

/// Isi file dock.json di Application Support.
public struct DockConfig: Codable, Equatable {
    public var pinned: [String]
    public var folderPath: String

    public init(pinned: [String], folderPath: String) {
        self.pinned = pinned
        self.folderPath = folderPath
    }

    public static let defaults = DockConfig(
        pinned: ["com.apple.finder", "com.apple.MobileSMS",
                 "com.apple.Safari", "com.figma.Desktop"],
        folderPath: NSHomeDirectory() + "/Projects"
    )
}

/// State nyata dock: aplikasi yang ter-pin, folder, titik running, badge.
@MainActor
public final class DockStore: ObservableObject {
    @Published public private(set) var pinned: [String]
    @Published public private(set) var folderPath: String
    @Published public private(set) var running: Set<String>
    @Published public private(set) var badgeCount: Int?

    private var observers: [NSObjectProtocol] = []
    private var badgeTimer: Timer?
    private var didAppear = false
    private var axPrompted = false

    /// Ikon di area kiri dock, selalu dua pertama dari daftar pin.
    public var leadingApps: [String] { Array(pinned.prefix(2)) }
    /// Ikon di area paged, sisanya.
    public var pagedApps: [String] { Array(pinned.dropFirst(2)) }

    public init(config: DockConfig? = nil) {
        let loaded = config ?? Self.loadConfig()
        pinned = loaded.pinned
        folderPath = loaded.folderPath
        running = Set(NSWorkspace.shared.runningApplications.map(\.bundleIdentifier).compactMap { $0 })
        if config == nil, Self.configURL == nil { Self.saveConfig(loaded) }
    }

    deinit {
        badgeTimer?.invalidate()
        for token in observers { NSWorkspace.shared.notificationCenter.removeObserver(token) }
    }

    /// Pratinjau/render offscreen: konfigurasi bawaan, tanpa observer.
    public static let preview: DockStore = {
        let store = DockStore(config: DockConfig(
            pinned: ["com.apple.finder", "com.apple.MobileSMS",
                     "com.apple.Safari", "com.figma.Desktop"],
            folderPath: NSHomeDirectory() + "/Projects"))
        return store
    }()

    // MARK: - Persistensi

    public static var configURL: URL? {
        guard let base = FileManager.default.urls(for: .applicationSupportDirectory,
                                                 in: .userDomainMask).first else { return nil }
        let dir = base.appendingPathComponent("SecondDock", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir.appendingPathComponent("dock.json")
    }

    public static func loadConfig() -> DockConfig {
        guard let url = configURL,
              let data = try? Data(contentsOf: url),
              let cfg = try? JSONDecoder().decode(DockConfig.self, from: data)
        else {
            let fresh = DockConfig.defaults
            saveConfig(fresh)
            return fresh
        }
        return cfg
    }

    public static func saveConfig(_ config: DockConfig) {
        guard let url = configURL else { return }
        let enc = JSONEncoder()
        enc.outputFormatting = [.prettyPrinted, .sortedKeys]
        guard let data = try? enc.encode(config) else { return }
        try? data.write(to: url, options: .atomic)
    }

    private func persist() {
        Self.saveConfig(DockConfig(pinned: pinned, folderPath: folderPath))
    }

    // MARK: - Aksi

    public func remove(bundleID: String) {
        guard pinned.contains(bundleID) else { return }
        pinned.removeAll { $0 == bundleID }
        persist()
    }

    public func isRunning(_ bundleID: String) -> Bool { running.contains(bundleID) }

    public func isInstalled(_ bundleID: String) -> Bool { Self.url(for: bundleID) != nil }

    public func launch(_ bundleID: String) {
        guard let url = Self.url(for: bundleID) else { return }
        NSWorkspace.shared.open(url)
    }

    public func reveal(_ bundleID: String) {
        guard let url = Self.url(for: bundleID) else { return }
        NSWorkspace.shared.activateFileViewerSelecting([url])
    }

    public func openFolder() {
        var isDir: ObjCBool = false
        if FileManager.default.fileExists(atPath: folderPath, isDirectory: &isDir), isDir.boolValue {
            NSWorkspace.shared.open(URL(fileURLWithPath: folderPath, isDirectory: true))
        } else {
            NSWorkspace.shared.open(URL(fileURLWithPath: NSHomeDirectory()))
        }
    }

    public static func url(for bundleID: String) -> URL? {
        if bundleID == "com.apple.finder" {
            let finder = URL(fileURLWithPath: "/System/Library/CoreServices/Finder.app")
            if FileManager.default.fileExists(atPath: finder.path) { return finder }
        }
        return NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleID)
    }

    // MARK: - Lifecycle

    /// Dipanggil saat widget tampil, bukan saat app launch.
    public func appear() {
        guard !didAppear else { return }
        didAppear = true
        refreshRunning()
        observeWorkspace()
        startBadgePolling()
    }

    private func observeWorkspace() {
        let center = NSWorkspace.shared.notificationCenter
        observers.append(center.addObserver(
            forName: NSWorkspace.didLaunchApplicationNotification, object: nil, queue: .main
        ) { [weak self] note in
            guard let app = note.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication,
                  let id = app.bundleIdentifier else { return }
            MainActor.assumeIsolated { self?.running.insert(id) }
        })
        observers.append(center.addObserver(
            forName: NSWorkspace.didTerminateApplicationNotification, object: nil, queue: .main
        ) { [weak self] note in
            guard let app = note.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication,
                  let id = app.bundleIdentifier else { return }
            MainActor.assumeIsolated { self?.running.remove(id) }
        })
    }

    private func refreshRunning() {
        running = Set(NSWorkspace.shared.runningApplications
            .compactMap(\.bundleIdentifier))
    }

    // MARK: - Badge Messages (Accessibility)

    private func startBadgePolling() {
        // Izin Aksesibilitas hanya diminta saat badge benar-benar dibutuhkan.
        if !AXIsProcessTrusted() && !axPrompted {
            axPrompted = true
            let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true]
            _ = AXIsProcessTrustedWithOptions(options as CFDictionary)
        }
        badgeTimer?.invalidate()
        let t = Timer(timeInterval: 5, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated { self?.refreshBadge() }
        }
        RunLoop.main.add(t, forMode: .common)
        badgeTimer = t
        refreshBadge()
    }

    /// Badge hanya ditampilkan kalau benar-benar terbaca; kalau tidak, disembunyikan.
    private func refreshBadge() {
        badgeCount = Self.dockBadgeCount(for: "com.apple.MobileSMS")
    }

    /// Membaca badge Dock lewat Accessibility API. Mengembalikan nil kalau tidak
    /// tersedia, supaya dock tidak pernah menampilkan angka karangan.
    public static func dockBadgeCount(for bundleID: String) -> Int? {
        guard AXIsProcessTrusted() else { return nil }
        guard let dock = NSRunningApplication.runningApplications(
            withBundleIdentifier: "com.apple.dock").first else { return nil }
        let root = AXUIElementCreateApplication(dock.processIdentifier)
        guard let items = axChildren(root, kAXChildrenAttribute) else { return nil }

        for item in items {
            let labels = [axString(item, kAXDescriptionAttribute), axString(item, kAXTitleAttribute)]
            guard let label = labels.compactMap({ $0 }).first(where: {
                $0.localizedCaseInsensitiveContains("messages")
            }) else { continue }
            // Badge Dock muncul sebagai angka pada nilai/title tile.
            if let parsed = badgeNumber(in: label) { return parsed }
            for attribute in [kAXValueAttribute, kAXTitleAttribute] {
                guard let raw = axString(item, attribute) else { continue }
                if let parsed = badgeNumber(in: raw) { return parsed }
            }
            return nil
        }
        return nil
    }

    /// Ambil angka saja dari teks badge; tolak kalau bukan angka utuh.
    private static func badgeNumber(in text: String) -> Int? {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, trimmed.allSatisfy(\.isNumber) else { return nil }
        return Int(trimmed)
    }

    private static func axChildren(_ element: AXUIElement,
                                   _ attribute: String) -> [AXUIElement]? {
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, attribute as CFString, &value) == .success
        else { return nil }
        return value as? [AXUIElement]
    }

    private static func axString(_ element: AXUIElement, _ attribute: String) -> String? {
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, attribute as CFString, &value) == .success
        else { return nil }
        return value as? String
    }
}