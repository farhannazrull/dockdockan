import AppKit
import Foundation

/// Cadangan AppleScript untuk Music.app dan Spotify.
enum AppleScriptSource {
    struct Info {
        var title: String
        var artist: String
        var artwork: NSImage?
        var elapsed: Double
        var duration: Double
        var isPlaying: Bool
    }

    /// Dijalankan sekali saja; sesudahnya izin sudah diberikan dan tidak
    /// perlu ditanyakan lagi.
    private static var didAskPermission = false

    static func ensureAutomationAsked() {
        guard !didAskPermission else { return }
        didAskPermission = true
        // NSAppleScript memicu dialog izin saat pertama benar-benar dipakai.
    }

    static func run(_ source: String) -> Bool {
        ensureAutomationAsked()
        guard let script = NSAppleScript(source: source) else { return false }
        var error: NSDictionary?
        let result = script.executeAndReturnError(&error)
        if let error, (error[NSAppleScript.errorNumber] as? Int ?? 0) != 0 { return false }
        return result.stringValue != nil
    }

    static func currentTrack() -> Info? {
        if let info = music() { return info }
        return spotify()
    }

    private static func script(_ body: String) -> NSAppleScript? {
        NSAppleScript(source: body)
    }

    /// Membaca daftar AppleScript sebagai angka/teks langsung lewat
    /// NSAppleEventDescriptor, tanpa parse string (aman dari locale).
    private static func fields(from source: String, count: Int) -> [Any]? {
        guard let script = NSAppleScript(source: source) else { return nil }
        var error: NSDictionary?
        let descriptor = script.executeAndReturnError(&error)
        if let error, (error[NSAppleScript.errorNumber] as? Int ?? 0) != 0 { return nil }
        guard descriptor.numberOfItems == count else { return nil }
        return (0 ..< count).map { descriptor.atIndex($0) }
    }

    private static func text(_ value: Any?) -> String { (value as? String) ?? "" }
    private static func number(_ value: Any?) -> Double { (value as? NSNumber)?.doubleValue ?? 0 }

    private static func music() -> Info? {
        let source = """
        if application "Music" is not running then return {""}
        tell application "Music"
            set t to current track
            return {name of t, artist of t, (duration of t as real), \
        (player position as real), (player state as string)}
        end tell
        """
        guard let f = fields(from: source, count: 5), !text(f[0]).isEmpty else { return nil }
        return Info(title: text(f[0]), artist: text(f[1]), artwork: nil,
                    elapsed: number(f[3]), duration: number(f[2]),
                    isPlaying: text(f[4]) == "playing")
    }

    private static func spotify() -> Info? {
        let source = """
        if application "Spotify" is not running then return {""}
        tell application "Spotify"
            if player state is stopped then return {""}
            set tr to current track
            return {name of tr, artist of tr, ((duration of tr as real) / 1000.0), \
        ((player position as real) / 1000.0), "playing"}
        end tell
        """
        guard let f = fields(from: source, count: 5), !text(f[0]).isEmpty else { return nil }
        return Info(title: text(f[0]), artist: text(f[1]), artwork: nil,
                    elapsed: number(f[3]), duration: number(f[2]), isPlaying: true)
    }
}
