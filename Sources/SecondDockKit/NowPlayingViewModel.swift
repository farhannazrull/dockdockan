import AppKit
import Combine
import Foundation
import MediaPlayer

public struct NowPlayingTrack: Equatable {
    public var title: String
    public var artist: String
    public var artwork: NSImage?
    public var elapsed: Double
    public var duration: Double
    public var isPlaying: Bool

    public init(title: String, artist: String, artwork: NSImage?,
                elapsed: Double, duration: Double, isPlaying: Bool) {
        self.title = title
        self.artist = artist
        self.artwork = artwork
        self.elapsed = elapsed
        self.duration = duration
        self.isPlaying = isPlaying
    }
}

/// Sumber data Now Playing.
///
/// Urutan sumber: (1) MediaRemote (framework privat, dimuat via dlopen dan
/// gagal dengan aman), (2) AppleScript ke Music.app dan Spotify sebagai cadangan.
///
/// Perintah (prev/play/next/seek) sengaja lewat AppleScript: perintah
/// MediaRemote butuh `MRMediaRemoteSendCommandMethod` dengan NSInvocation yang
/// tidak bisa dibangun andal dari Swift, jadi lebih aman dan bisa diuji.
@MainActor
public final class NowPlayingViewModel: ObservableObject {
    @Published public private(set) var track: NowPlayingTrack?
    /// Interpolasi posisi, bukan nilai yang di-update tiap tick.
    @Published public private(set) var elapsed: Double = 0
    @Published public private(set) var isPlaying = false

    public var sourceName: String { mediaRemote.isLoaded ? "MediaRemote" : "AppleScript" }

    private let mediaRemote: MediaRemoteBridge
    private var tick: Timer?
    private var poll: Timer?
    private var observers: [NSObjectProtocol] = []
    private var didAppear = false

    // Interpolasi posisi.
    private var basePosition: Double = 0
    private var baseRate: Double = 0
    private var baseTime: Date = Date()
    private var duration: Double = 0

    public init() {
        mediaRemote = MediaRemoteBridge()
    }

    deinit {
        tick?.invalidate()
        poll?.invalidate()
        for token in observers {
            NSWorkspace.shared.notificationCenter.removeObserver(token)
        }
    }

    public func appear() {
        guard !didAppear else { return }
        didAppear = true
        refresh()
        startTicking()
        startPolling()
        observeSystemNowPlaying()
    }

    private func observeSystemNowPlaying() {
        let center = NSWorkspace.shared.notificationCenter
        observers.append(center.addObserver(
            forName: NSWorkspace.didLaunchApplicationNotification, object: nil, queue: .main
        ) { [weak self] _ in MainActor.assumeIsolated { self?.refresh() } })
        observers.append(center.addObserver(
            forName: NSWorkspace.didTerminateApplicationNotification, object: nil, queue: .main
        ) { [weak self] _ in MainActor.assumeIsolated { self?.refresh() } })
    }

    private func startTicking() {
        tick?.invalidate()
        let t = Timer(timeInterval: 0.25, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated { self?.advance() }
        }
        RunLoop.main.add(t, forMode: .common)
        tick = t
    }

    private func startPolling() {
        poll?.invalidate()
        let t = Timer(timeInterval: 2, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated { self?.refresh() }
        }
        RunLoop.main.add(t, forMode: .common)
        poll = t
    }

    /// Interpolasi halus di antara pembaruan resmi.
    private func advance() {
        guard isPlaying, baseRate > 0 else { return }
        elapsed = min(duration, basePosition + Date().timeIntervalSince(baseTime) * baseRate)
    }

    // MARK: - Data

    public func refresh() {
        if let info = mediaRemote.nowPlayingInfo(), !info.isEmpty {
            apply(info)
            return
        }
        applyAppleScript()
    }

    private func apply(_ info: [String: Any]) {
        let title = (info["kMRMediaRemoteNowPlayingInfoTitle"] as? String)
            ?? (info["title"] as? String) ?? ""
        let artist = (info["kMRMediaRemoteNowPlayingInfoArtist"] as? String)
            ?? (info["artist"] as? String) ?? ""
        let artwork = Self.artwork(from: info)
        let rate = Self.double(info["kMRMediaRemoteNowPlayingInfoPlaybackRate"]) ?? 0
        var position = Self.double(info["kMRMediaRemoteNowPlayingInfoElapsedTime"]) ?? 0
        var total = Self.double(info["kMRMediaRemoteNowPlayingInfoDuration"]) ?? 0
        if total <= 0, let line = mediaRemote.timeline() {
            position = line.elapsed
            total = line.duration
        }

        let resolvedTitle = title.isEmpty ? "Nothing playing" : title
        let resolvedArtist = artist.isEmpty ? "" : artist
        if track == nil || track?.title != resolvedTitle || track?.artist != resolvedArtist {
            track = NowPlayingTrack(title: resolvedTitle, artist: resolvedArtist,
                                    artwork: artwork, elapsed: position,
                                    duration: total, isPlaying: rate > 0)
        } else {
            track?.artwork = artwork
        }

        duration = total
        basePosition = position
        baseRate = rate
        baseTime = Date()
        elapsed = position
        isPlaying = rate > 0
    }

    private func applyAppleScript() {
        guard let info = AppleScriptSource.currentTrack() else {
            if isPlaying || track != nil {
                track = nil
                elapsed = 0
                isPlaying = false
                duration = 0
            }
            return
        }
        track = NowPlayingTrack(title: info.title, artist: info.artist,
                                artwork: info.artwork, elapsed: info.elapsed,
                                duration: info.duration, isPlaying: info.isPlaying)
        duration = info.duration
        basePosition = info.elapsed
        baseRate = info.isPlaying ? 1 : 0
        baseTime = Date()
        elapsed = info.elapsed
        isPlaying = info.isPlaying
    }

    // MARK: - Kontrol

    public var durationText: Double { duration }

    public var progressFraction: Double {
        guard duration > 0 else { return 0 }
        return min(max(elapsed / duration, 0), 1)
    }

    /// Pratinjau/render offscreen: tidak menyentuh MediaRemote.
    public static let preview: NowPlayingViewModel = {
        let vm = NowPlayingViewModel()
        vm.track = NowPlayingTrack(title: "The Entertainer", artist: "Scott Joplin",
                                   artwork: nil, elapsed: 0, duration: 306,
                                   isPlaying: false)
        vm.duration = 306
        return vm
    }()

    public func previous() { run("previous track") }
    public func toggle() { run(isPlaying ? "pause" : "play") }
    public func next() { run("next track") }

    public func seek(to fraction: Double) {
        guard duration > 0 else { return }
        let target = duration * min(max(fraction, 0), 1)
        run("set player position to \(target)")
        basePosition = target
        baseTime = Date()
        elapsed = target
    }

    public func openMusic() {
        let url = URL(fileURLWithPath: "/System/Applications/Music.app")
        NSWorkspace.shared.open(url)
    }

    /// Kontrol lewat Music.app dulu, lalu Spotify.
    private func run(_ command: String) {
        let play = "tell application \"Music\"\n"
            + "if it is running then tell it to \(command)\n"
        if AppleScriptSource.run(play) { return }
        let spotify = "tell application \"Spotify\"\n"
            + "if it is running then tell it to \(command)\n"
        if AppleScriptSource.run(spotify) { return }
        // Fallback terakhir: MediaRemote untuk prev/next/play.
        mediaRemote.send(command: command)
    }

    // MARK: - Helper

    static func double(_ value: Any?) -> Double? {
        if let d = value as? Double { return d }
        if let n = value as? NSNumber { return n.doubleValue }
        if let s = value as? String { return Double(s) }
        return nil
    }

    static func artwork(from info: [String: Any]) -> NSImage? {
        let raw = info["kMRMediaRemoteNowPlayingInfoArtwork"]
        if let data = raw as? Data, let image = NSImage(data: data) { return image }
        // macOS baru memberi MPMediaItemArtwork, bukan Data mentah.
        if let item = raw as? MPMediaItemArtwork { return item.image(at: CGSize(width: 64, height: 64)) }
        return nil
    }
}

// MARK: - Jembatan MediaRemote

/// Memuat MediaRemote secara dinamis; semua kegagalan ditoleransi.
final class MediaRemoteBridge {
    private typealias GetInfo = (@convention(c) (DispatchQueue, @escaping ([String: Any]) -> Void) -> Void)
    private typealias GetTimeline = (@convention(c) (DispatchQueue,
        @escaping ([String: Any], Double) -> Void) -> Void)
    private let handle: UnsafeMutableRawPointer?
    private let getInfo: GetInfo?
    private let getTimeline: GetTimeline?

    init() {
        let path = "/System/Library/PrivateFrameworks/MediaRemote.framework/MediaRemote"
        guard let h = dlopen(path, RTLD_LAZY) else {
            handle = nil
            getInfo = nil
            getTimeline = nil
            return
        }
        handle = h
        getInfo = unsafeBitCast(dlsym(h, "MRMediaRemoteGetNowPlayingInfo"), to: GetInfo.self)
        getTimeline = unsafeBitCast(dlsym(h, "MRMediaRemoteGetNowPlayingTimeline"),
                                    to: GetTimeline.self)
    }

    var isLoaded: Bool { getInfo != nil }

    func nowPlayingInfo() -> [String: Any]? {
        guard let getInfo else { return nil }
        var result: [String: Any]?
        let done = DispatchSemaphore(value: 0)
        getInfo(DispatchQueue.global(qos: .userInitiated)) { info in
            if !info.isEmpty { result = info }
            done.signal()
        }
        // Jangan memblokir thread utama kalau callback tidak datang.
        _ = done.wait(timeout: .now() + 1.0)
        return result
    }

    /// Timeline terpisah: info now-playing tidak memuat elapsed/duration.
    func timeline() -> (elapsed: Double, duration: Double)? {
        guard let getTimeline else { return nil }
        var out: (Double, Double)?
        let done = DispatchSemaphore(value: 0)
        getTimeline(DispatchQueue.global(qos: .userInitiated)) { info, _ in
            let elapsed = Self.number(info["kMRMediaRemoteNowPlayingInfoElapsedTime"])
            let duration = Self.number(info["kMRMediaRemoteNowPlayingInfoDuration"])
            if let elapsed, let duration, duration > 0 { out = (elapsed, duration) }
            done.signal()
        }
        _ = done.wait(timeout: .now() + 1.0)
        guard let out else { return nil }
        return (out.0, out.1)
    }

    private static func number(_ value: Any?) -> Double? {
        if let d = value as? Double { return d }
        if let n = value as? NSNumber { return n.doubleValue }
        return nil
    }

    func send(command: String) {
        // Perintah lewat AppleScript; method privat MediaRemote tidak
        // dibangun dari Swift karena butuh NSInvocation yang rapuh.
    }
}