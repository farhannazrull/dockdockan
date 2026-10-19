import AppKit
import Combine
import EventKit
import Foundation
import SwiftUI

public enum CalendarCardMode: Equatable {
    case event
    case noEvents
    case needsAccess
}

/// Semua yang dibutuhkan CalendarWidget. View tetap murni.
public struct CalendarCardState {
    public var weekday = ""
    public var day = ""
    public var title = ""
    public var time = ""
    public var dotColor = Theme.accentOrange
    public var meetingURL: URL?
    public var mode: CalendarCardMode = .needsAccess

    public init() {}
}

/// Sumber data Calendar widget: tanggal nyata + event terdekat hari ini via EventKit.
@MainActor
public final class CalendarViewModel: ObservableObject {
    @Published public private(set) var state = CalendarCardState()

    private static let prefsDateKey = "focusMinutes" // tidak dipakai; penanda ask terpisah
    private static let askFlagKey = "calendarAskAttempted"

    private let store = EKEventStore()
    private var minuteTimer: Timer?
    private var midnightTimer: Timer?
    private var observers: [NSObjectProtocol] = []
    private var didAppear = false

    private static let weekdayFormatter: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.dateFormat = "EEE"
        return f
    }()

    private static let dayFormatter: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.dateFormat = "d"
        return f
    }()

    private static let timeFormatter: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.dateFormat = "HH:mm"
        return f
    }()

    public init() {
        refreshDate()
        refreshEvent()
    }

    deinit {
        minuteTimer?.invalidate()
        midnightTimer?.invalidate()
        for token in observers {
            NotificationCenter.default.removeObserver(token)
        }
    }

    // MARK: - Lifecycle

    /// Instans untuk render offscreen: tanggal nyata (supaya tidak ada dua
    /// tanggal berbeda di app), tapi tanpa menyentuh izin kalender.
    public static let preview: CalendarViewModel = CalendarViewModel()

    /// Dipanggil sekali saat widget benar-benar tampil (bukan saat app launch).
    public func appear() {
        guard !didAppear else { return }
        didAppear = true
        requestAccessIfNeeded()
        startTimers()
        refreshEvent()
    }

    private func startTimers() {
        minuteTimer?.invalidate()
        let t = Timer(timeInterval: 60, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated {
                self?.refreshDate()
                self?.refreshEvent()
            }
        }
        RunLoop.main.add(t, forMode: .common)
        minuteTimer = t

        scheduleMidnight()
        observers.append(NotificationCenter.default.addObserver(
            forName: .EKEventStoreChanged, object: store, queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated { self?.refreshEvent() }
        })
        observers.append(NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didWakeNotification, object: nil, queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated {
                self?.refreshDate()
                self?.refreshEvent()
            }
        })
    }

    private func scheduleMidnight() {
        midnightTimer?.invalidate()
        let cal = Calendar.current
        let now = Date()
        guard let tomorrow = cal.date(byAdding: .day, value: 1, to: cal.startOfDay(for: now)),
              let midnight = cal.date(bySettingHour: 0, minute: 0, second: 1, of: tomorrow)
        else { return }
        let interval = max(1, midnight.timeIntervalSince(now))
        let t = Timer(timeInterval: interval, repeats: false) { [weak self] _ in
            MainActor.assumeIsolated {
                self?.refreshDate()
                self?.refreshEvent()
                self?.scheduleMidnight()
            }
        }
        RunLoop.main.add(t, forMode: .common)
        midnightTimer = t
    }

    // MARK: - Izin

    private var isAuthorized: Bool {
        let status = EKEventStore.authorizationStatus(for: .event)
        return status == .fullAccess || status == .authorized
    }

    private var isDenied: Bool {
        let status = EKEventStore.authorizationStatus(for: .event)
        return status == .denied || status == .restricted
    }

    private func requestAccessIfNeeded() {
        guard !isAuthorized else { return }
        guard EKEventStore.authorizationStatus(for: .event) == .notDetermined else {
            state.mode = .needsAccess
            return
        }
        if UserDefaults.standard.bool(forKey: Self.askFlagKey) { return }
        UserDefaults.standard.set(true, forKey: Self.askFlagKey)
        Task { [weak self] in
            guard let self else { return }
            try? await store.requestFullAccessToEvents()
            self.refreshEvent()
        }
    }

    /// Tombol "Allow Calendar": minta izin, atau buka System Settings bila ditolak.
    public func allow() {
        if isDenied {
            let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Calendars")
            if let url { NSWorkspace.shared.open(url) }
            return
        }
        UserDefaults.standard.set(false, forKey: Self.askFlagKey)
        requestAccessIfNeeded()
    }

    // MARK: - Data

    private func refreshDate() {
        let now = Date()
        state.weekday = Self.weekdayFormatter.string(from: now).uppercased()
        state.day = Self.dayFormatter.string(from: now)
    }

    private func refreshEvent() {
        guard isAuthorized else {
            state.mode = .needsAccess
            state.title = ""
            state.time = ""
            state.meetingURL = nil
            return
        }
        guard let event = nextEvent() else {
            state.mode = .noEvents
            state.title = ""
            state.time = ""
            state.meetingURL = nil
            return
        }
        state.mode = .event
        state.title = event.title ?? ""
        state.time = Self.timeFormatter.string(from: event.startDate)
        state.dotColor = color(for: event)
        state.meetingURL = meetingURL(for: event)
    }

    private func nextEvent() -> EKEvent? {
        let cal = Calendar.current
        let now = Date()
        let start = cal.startOfDay(for: now)
        guard let end = cal.date(byAdding: .day, value: 1, to: start) else { return nil }
        let predicate = store.predicateForEvents(withStart: start, end: end, calendars: nil)
        let events = store.events(matching: predicate).sorted { $0.startDate < $1.startDate }
        if let current = events.first(where: { $0.startDate <= now && $0.endDate > now }) {
            return current
        }
        return events.first { $0.startDate > now }
    }

    private func color(for event: EKEvent) -> Color {
        if let color = event.calendar.color { return Color(nsColor: color) }
        return Theme.accentOrange
    }

    private func meetingURL(for event: EKEvent) -> URL? {
        if let url = event.url { return url }
        if let location = event.location, isMeeting(location) {
            return URL(string: location)
        }
        return nil
    }

    private func isMeeting(_ raw: String) -> Bool {
        let lowered = raw.lowercased()
        return lowered.contains("zoom.us")
            || lowered.contains("meet.google.com")
            || lowered.contains("teams.microsoft.com")
    }

    public func join() {
        guard let url = state.meetingURL else { return }
        NSWorkspace.shared.open(url)
    }
}