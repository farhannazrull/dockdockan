import AppKit
import Combine
import Foundation

public enum StockChangeTone: Equatable {
    case positive, negative, flat
}

public enum StockCardMode: Equatable {
    case loading, value, error, missingKey, unknownSymbol
}

/// Semua yang dibutuhkan StockWidget. View tetap murni.
public struct StockCardState {
    public var symbol = ""
    public var priceText = ""
    public var changeText = ""
    public var points: [Double] = []
    public var tone: StockChangeTone = .flat
    public var mode: StockCardMode = .loading
    /// Nilai terakhir yang berhasil, ditampilkan redup + ikon jam.
    public var isStale = false

    public init() {}
}

public struct StockQuote: Equatable {
    public var price: Double
    public var changePercent: Double
    public var points: [Double]

    public init(price: Double, changePercent: Double, points: [Double]) {
        self.price = price
        self.changePercent = changePercent
        self.points = points
    }
}

public enum QuoteError: Error, Equatable {
    case missingAPIKey
    case unknownSymbol
    case network
    case invalidData
}

/// Sumber kutipan harga. Default gratis (Yahoo) tidak butuh key.
public protocol QuoteProvider {
    var requiresAPIKey: Bool { get }
    func quote(for symbol: String, apiKey: String?) async throws -> StockQuote
}

public struct YahooQuoteProvider: QuoteProvider {
    public init() {}

    public var requiresAPIKey: Bool { false }

    public func quote(for symbol: String, apiKey: String?) async throws -> StockQuote {
        guard var comps = URLComponents(
            string: "https://query1.finance.yahoo.com/v8/finance/chart/\(symbol)"
        ) else { throw QuoteError.invalidData }
        comps.queryItems = [
            URLQueryItem(name: "range", value: "1d"),
            URLQueryItem(name: "interval", value: "5m"),
            URLQueryItem(name: "includePrePost", value: "false"),
        ]
        guard let url = comps.url else { throw QuoteError.invalidData }

        var request = URLRequest(url: url)
        request.timeoutInterval = 15
        request.setValue("SecondDock/1.0", forHTTPHeaderField: "User-Agent")

        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await URLSession.shared.data(for: request)
        } catch {
            throw QuoteError.network
        }
        guard let http = response as? HTTPURLResponse else { throw QuoteError.network }
        if http.statusCode == 404 { throw QuoteError.unknownSymbol }
        guard (200 ..< 300).contains(http.statusCode) else { throw QuoteError.network }

        guard let root = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let chart = root["chart"] as? [String: Any] else {
            throw QuoteError.invalidData
        }
        if let error = chart["error"] as? [String: Any], !error.isEmpty {
            throw QuoteError.unknownSymbol
        }
        guard let results = chart["result"] as? [[String: Any]],
              let first = results.first else {
            throw QuoteError.unknownSymbol
        }
        guard let meta = first["meta"] as? [String: Any] else { throw QuoteError.invalidData }

        let points = Self.closes(from: first)
        let price = (meta["regularMarketPrice"] as? NSNumber)?.doubleValue
            ?? points.last
        let previous = (meta["chartPreviousClose"] as? NSNumber)?.doubleValue
            ?? (meta["previousClose"] as? NSNumber)?.doubleValue
        guard let price else { throw QuoteError.invalidData }
        let change = previous.flatMap { $0 > 0 ? (price - $0) / $0 * 100 : nil } ?? 0
        return StockQuote(price: price, changePercent: change, points: points)
    }

    private static func closes(from result: [String: Any]) -> [Double] {
        guard let indicators = result["indicators"] as? [String: Any],
              let quotes = indicators["quote"] as? [[String: Any]],
              let close = quotes.first?["close"] as? [Any] else { return [] }
        return close.compactMap { ($0 as? NSNumber)?.doubleValue }
    }
}

public struct StockConfig: Codable, Equatable {
    public var symbol: String

    public init(symbol: String = "AAPL") {
        self.symbol = symbol
    }

    public static let defaults = StockConfig()
}

/// Jam bursa AS (Senin-Jumat 09:30-16:00 waktu New York).
public enum StockMarket {
    public static func isOpen(_ date: Date = Date(),
                              timeZone: TimeZone = TimeZone(identifier: "America/New_York")!) -> Bool {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone
        let parts = calendar.dateComponents([.weekday, .hour, .minute], from: date)
        guard let weekday = parts.weekday, (2 ... 6).contains(weekday) else { return false }
        let minutes = (parts.hour ?? 0) * 60 + (parts.minute ?? 0)
        return minutes >= 9 * 60 + 30 && minutes < 16 * 60
    }
}

@MainActor
public final class StockViewModel: ObservableObject {
    @Published public private(set) var state = StockCardState()

    private static let apiKeyAccount = "stock.provider.apiKey"

    private let provider: QuoteProvider
    private let isPreview: Bool
    private var symbolValue: String
    private var lastQuote: StockQuote?
    private var isLoading = false
    private var pendingRefresh = false
    private var lastAttempt = Date.distantPast
    private var didAppear = false
    private var timer: Timer?
    private var observers: [NSObjectProtocol] = []

    public var symbol: String { symbolValue }

    public init(provider: QuoteProvider = YahooQuoteProvider(),
                config: StockConfig? = nil,
                isPreview: Bool = false) {
        self.provider = provider
        self.isPreview = isPreview
        let loaded = config ?? Self.loadConfig()
        symbolValue = loaded.symbol
        state.symbol = loaded.symbol
    }

    deinit {
        timer?.invalidate()
        for token in observers { NSWorkspace.shared.notificationCenter.removeObserver(token) }
    }

    public static var configURL: URL? {
        guard let base = FileManager.default.urls(for: .applicationSupportDirectory,
                                                 in: .userDomainMask).first else { return nil }
        let dir = base.appendingPathComponent("SecondDock", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir.appendingPathComponent("stock.json")
    }

    public static func loadConfig() -> StockConfig {
        guard let url = configURL,
              let data = try? Data(contentsOf: url),
              let cfg = try? JSONDecoder().decode(StockConfig.self, from: data),
              !cfg.symbol.isEmpty
        else { return .defaults }
        return cfg
    }

    private func persist() {
        guard let url = Self.configURL else { return }
        let enc = JSONEncoder()
        enc.outputFormatting = [.prettyPrinted, .sortedKeys]
        guard let data = try? enc.encode(StockConfig(symbol: symbolValue)) else { return }
        try? data.write(to: url, options: .atomic)
    }

    // MARK: - Lifecycle

    public func appear() {
        guard !isPreview, !didAppear else { return }
        didAppear = true
        refresh()
        startTimer()
        observers.append(NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didWakeNotification, object: nil, queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated { self?.refresh() }
        })
    }

    /// Cek tiap menit; benar-benar fetch hanya saat jatuh tempo
    /// (60 detik saat bursa buka, 15 menit di luar jam bursa).
    private func startTimer() {
        timer?.invalidate()
        let t = Timer(timeInterval: 60, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated { self?.tick() }
        }
        RunLoop.main.add(t, forMode: .common)
        timer = t
    }

    private func tick() {
        let interval: TimeInterval = StockMarket.isOpen() ? 60 : 15 * 60
        guard Date().timeIntervalSince(lastAttempt) >= interval else { return }
        refresh()
    }

    // MARK: - Data

    public func refresh() {
        guard !isPreview else { return }
        if isLoading {
            pendingRefresh = true
            return
        }
        lastAttempt = Date()
        let key: String?
        if provider.requiresAPIKey {
            guard let stored = Keychain.string(account: Self.apiKeyAccount),
                  !stored.isEmpty else {
                state.mode = .missingKey
                return
            }
            key = stored
        } else {
            key = nil
        }
        isLoading = true
        if state.mode != .value { state.mode = .loading }
        let requested = symbolValue

        Task { [weak self] in
            guard let self else { return }
            defer {
                self.isLoading = false
                if self.pendingRefresh {
                    self.pendingRefresh = false
                    self.refresh()
                }
            }
            do {
                let quote = try await self.provider.quote(for: requested, apiKey: key)
                guard requested == self.symbolValue else { return }
                self.apply(quote)
            } catch {
                guard requested == self.symbolValue else { return }
                self.fail(error)
            }
        }
    }

    private func apply(_ quote: StockQuote) {
        lastQuote = quote
        let tone: StockChangeTone
        if quote.changePercent > 0.0001 { tone = .positive }
        else if quote.changePercent < -0.0001 { tone = .negative }
        else { tone = .flat }

        var next = StockCardState()
        next.symbol = symbolValue
        next.priceText = DockFormatters.price(quote.price)
        next.changeText = DockFormatters.percent(quote.changePercent, signed: tone != .flat)
        next.points = quote.points
        next.tone = tone
        next.mode = .value
        state = next
    }

    private func fail(_ error: Error) {
        if case QuoteError.unknownSymbol = error {
            lastQuote = nil
            var next = StockCardState()
            next.symbol = symbolValue
            next.mode = .unknownSymbol
            state = next
            return
        }
        if case QuoteError.missingAPIKey = error {
            state.mode = .missingKey
            return
        }
        // Gagal tapi pernah sukses: pertahankan nilai lama, redup.
        if let lastQuote {
            var next = StockCardState()
            next.symbol = symbolValue
            next.priceText = DockFormatters.price(lastQuote.price)
            let tone: StockChangeTone
            if lastQuote.changePercent > 0.0001 { tone = .positive }
            else if lastQuote.changePercent < -0.0001 { tone = .negative }
            else { tone = .flat }
            next.tone = tone
            next.changeText = DockFormatters.percent(lastQuote.changePercent,
                                                     signed: tone != .flat)
            next.points = lastQuote.points
            next.mode = .value
            next.isStale = true
            state = next
        } else {
            var next = StockCardState()
            next.symbol = symbolValue
            next.mode = .error
            state = next
        }
    }

    // MARK: - Aksi

    public func setSymbol(_ raw: String) {
        let cleaned = raw.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        guard !cleaned.isEmpty else { return }
        symbolValue = cleaned
        persist()
        lastQuote = nil
        var next = StockCardState()
        next.symbol = cleaned
        next.mode = .loading
        state = next
        refresh()
    }

    public func promptForSymbol() {
        NSApp.activate(ignoringOtherApps: true)
        let alert = NSAlert()
        alert.messageText = "Stock symbol"
        alert.informativeText = "Contoh: AAPL, TSLA, BBCA.JK"
        alert.addButton(withTitle: "Save")
        alert.addButton(withTitle: "Cancel")
        let field = NSTextField(frame: NSRect(x: 0, y: 0, width: 220, height: 24))
        field.stringValue = symbolValue
        alert.accessoryView = field
        alert.window.initialFirstResponder = field
        guard alert.runModal() == .alertFirstButtonReturn else { return }
        setSymbol(field.stringValue)
    }

    public func promptForAPIKey() {
        NSApp.activate(ignoringOtherApps: true)
        let alert = NSAlert()
        alert.messageText = "Add API key"
        alert.informativeText = "Disimpan di Keychain, bukan di file config."
        alert.addButton(withTitle: "Save")
        alert.addButton(withTitle: "Cancel")
        let field = NSSecureTextField(frame: NSRect(x: 0, y: 0, width: 240, height: 24))
        field.stringValue = Keychain.string(account: Self.apiKeyAccount) ?? ""
        alert.accessoryView = field
        alert.window.initialFirstResponder = field
        guard alert.runModal() == .alertFirstButtonReturn else { return }
        Keychain.set(field.stringValue, account: Self.apiKeyAccount)
        refresh()
    }

    /// Pratinjau/render offscreen: nilai referensi, tanpa network/timer.
    public static let preview: StockViewModel = {
        let vm = StockViewModel(config: .defaults, isPreview: true)
        var next = StockCardState()
        next.symbol = "AAPL"
        next.priceText = "333.08"
        next.changeText = "+0.24%"
        next.points = PreviewData.sparkAAPL
        next.tone = .positive
        next.mode = .value
        vm.state = next
        return vm
    }()
}
