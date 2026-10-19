import AppKit
import Combine
import Foundation
import UserNotifications

public enum FocusPhase: Equatable {
    case idle, running, paused, finished
}

/// Timer Pomodoro. Sumber kebenaran = `endDate` (bukan penghitung yang dikurangi
/// tiap tick), jadi tetap benar setelah tidur atau app di-throttle.
@MainActor
public final class FocusViewModel: ObservableObject {
    public static let choices: [Int] = [15, 25, 45, 60]
    public static let defaultMinutes = 25

    private static let minutesKey = "focusMinutes"
    private static let notifAskedKey = "focusNotifAsked"
    private static let finishedHold: TimeInterval = 3

    @Published public private(set) var phase: FocusPhase = .idle
    @Published public private(set) var remainingText: String = ""
    @Published public private(set) var progress: Double = 0

    public var label: String {
        switch phase {
        case .idle: "Focus"
        case .running: "Focus"
        case .paused: "Paused"
        case .finished: "Done"
        }
    }

    public var minutes: Int {
        get {
            let v = UserDefaults.standard.integer(forKey: Self.minutesKey)
            return v == 0 ? Self.defaultMinutes : v
        }
        set {
            UserDefaults.standard.set(newValue, forKey: Self.minutesKey)
            if phase == .idle { applyFullLength() }
        }
    }

    private var sessionLength: TimeInterval = Double(FocusViewModel.defaultMinutes) * 60
    private var endDate: Date?
    private var pausedRemaining: TimeInterval = 0
    private var ticker: Timer?
    private var resetTask: Task<Void, Never>?

    public init() {
        sessionLength = Double(minutes) * 60
        applyFullLength()
    }

    // MARK: - Aksi

    public func toggle() {
        switch phase {
        case .idle: start()
        case .running: pause()
        case .paused: resume()
        case .finished: break
        }
    }

    public func start() {
        ensureNotificationPermission()
        resetTask?.cancel()
        endDate = Date().addingTimeInterval(sessionLength)
        pausedRemaining = sessionLength
        phase = .running
        syncFromClock()
        startTicking()
    }

    public func pause() {
        guard phase == .running else { return }
        syncFromClock()
        pausedRemaining = max(0, endDate?.timeIntervalSinceNow ?? 0)
        phase = .paused
        stopTicking()
    }

    public func resume() {
        guard phase == .paused else { return }
        endDate = Date().addingTimeInterval(pausedRemaining)
        phase = .running
        syncFromClock()
        startTicking()
    }

    public func reset() {
        resetTask?.cancel()
        stopTicking()
        endDate = nil
        phase = .idle
        applyFullLength()
    }

    // MARK: - Internal

    /// Instans sekali pakai untuk pratinjau/render offscreen (tidak pernah started).
    public static let preview: FocusViewModel = {
        let vm = FocusViewModel()
        vm.seedPreview()
        return vm
    }()

    private func seedPreview() {
        remainingText = DockFormatters.countdown(3 * 60 + 23)
        progress = 0.15
    }

    private func applyFullLength() {
        sessionLength = Double(minutes) * 60
        pausedRemaining = sessionLength
        progress = 0
        remainingText = DockFormatters.countdown(Int(sessionLength.rounded()))
    }

    private func syncFromClock() {
        guard phase == .running, let endDate else { return }
        let left = endDate.timeIntervalSinceNow
        if left <= 0 {
            finish()
            return
        }
        pausedRemaining = left
        progress = min(max(1 - left / sessionLength, 0), 1)
        remainingText = DockFormatters.countdown(Int(left.rounded(.up)))
    }

    private func startTicking() {
        stopTicking()
        let t = Timer(timeInterval: 1, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated { self?.syncFromClock() }
        }
        RunLoop.main.add(t, forMode: .common)
        ticker = t
    }

    private func stopTicking() {
        ticker?.invalidate()
        ticker = nil
    }

    private func finish() {
        stopTicking()
        phase = .finished
        progress = 1
        remainingText = DockFormatters.countdown(0)
        notifyAndSound()
        resetTask?.cancel()
        resetTask = Task { [weak self] in
            try? await Task.sleep(for: .seconds(Self.finishedHold))
            guard !Task.isCancelled else { return }
            self?.reset()
        }
    }

    private func ensureNotificationPermission() {
        guard !UserDefaults.standard.bool(forKey: Self.notifAskedKey) else { return }
        UserDefaults.standard.set(true, forKey: Self.notifAskedKey)
        UNUserNotificationCenter.current()
            .requestAuthorization(options: [.alert, .sound]) { _, _ in }
    }

    private func notifyAndSound() {
        let content = UNMutableNotificationContent()
        content.title = "Focus"
        content.body = "Focus session done"
        UNUserNotificationCenter.current()
            .add(UNNotificationRequest(identifier: "focus-done", content: content, trigger: nil))
        NSSound(named: "Glass")?.play()
    }
}