import AppKit
import Combine
import Foundation

public enum RevenueRange: String, Codable, CaseIterable {
    case mtd = "MTD"
    case ytd = "YTD"
    case sevenDay = "7D"

    public var label: String { rawValue }
}

public struct RevenueConfig: Codable, Equatable {
    public var project: String
    public var amount: Double
    public var daily: [Double]
    public var range: RevenueRange
    public var currency: String

    public init(project: String, amount: Double, daily: [Double],
                range: RevenueRange = .mtd, currency: String = "$") {
        self.project = project
        self.amount = amount
        self.daily = daily
        self.range = range
        self.currency = currency
    }
}

public struct RevenueSnapshot: Equatable {
    public var project: String
    public var amount: Double
    public var daily: [Double]
    public var range: RevenueRange
    public var currency: String
}

public protocol RevenueProvider {
    var isConfigured: Bool { get }
    func load() -> RevenueSnapshot?
}

/// Diisi user lewat form; sumber utama untuk sekarang.
public struct ManualProvider: RevenueProvider {
    public let config: RevenueConfig?

    public init(config: RevenueConfig?) {
        self.config = config
    }

    public var isConfigured: Bool { config != nil }

    public func load() -> RevenueSnapshot? {
        guard let config else { return nil }
        return RevenueSnapshot(project: config.project, amount: config.amount,
                               daily: config.daily, range: config.range,
                               currency: config.currency)
    }
}

/// Placeholder; belum tersambung ke backend mana pun.
public struct RemoteProvider: RevenueProvider {
    public init() {}
    public var isConfigured: Bool { false }
    public func load() -> RevenueSnapshot? { nil }
}

public struct RevenueCardState {
    public var project = ""
    public var amountText = ""
    public var points: [Double] = []
    public var rangeLabel = RevenueRange.mtd.label
    public var isEmpty = true

    public init() {}
}

@MainActor
public final class RevenueViewModel: ObservableObject {
    @Published public private(set) var state = RevenueCardState()

    private let isPreview: Bool
    private var provider: RevenueProvider
    private var didAppear = false

    public init(provider: RevenueProvider? = nil,
                config: RevenueConfig? = nil,
                isPreview: Bool = false) {
        self.isPreview = isPreview
        self.provider = provider ?? ManualProvider(config: config ?? Self.loadConfig())
        reload()
    }

    public static var configURL: URL? {
        guard let base = FileManager.default.urls(for: .applicationSupportDirectory,
                                                 in: .userDomainMask).first else { return nil }
        let dir = base.appendingPathComponent("SecondDock", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir.appendingPathComponent("revenue.json")
    }

    public static func loadConfig() -> RevenueConfig? {
        guard let url = configURL,
              let data = try? Data(contentsOf: url),
              let cfg = try? JSONDecoder().decode(RevenueConfig.self, from: data)
        else { return nil }
        return cfg
    }

    public func appear() {
        guard !isPreview, !didAppear else { return }
        didAppear = true
        reload()
    }

    public func reload() {
        guard let snapshot = provider.load() else {
            state = RevenueCardState()
            return
        }
        state.project = snapshot.project
        state.amountText = DockFormatters.compactCurrency(snapshot.amount,
                                                          symbol: snapshot.currency)
        state.points = snapshot.daily
        state.rangeLabel = snapshot.range.label
        state.isEmpty = false
    }

    public func save(project: String, amount: Double, daily: [Double],
                     range: RevenueRange, currency: String) {
        let config = RevenueConfig(project: project, amount: amount, daily: daily,
                                   range: range, currency: currency)
        if let url = Self.configURL {
            let enc = JSONEncoder()
            enc.outputFormatting = [.prettyPrinted, .sortedKeys]
            if let data = try? enc.encode(config) {
                try? data.write(to: url, options: .atomic)
            }
        }
        provider = ManualProvider(config: config)
        reload()
    }

    public func presentForm() {
        guard !isPreview else { return }
        NSApp.activate(ignoringOtherApps: true)
        let current = Self.loadConfig()

        let alert = NSAlert()
        alert.messageText = "Revenue"
        alert.informativeText = "Isi manual. Data disimpan di Application Support."
        alert.addButton(withTitle: "Save")
        alert.addButton(withTitle: "Cancel")

        let projectField = NSTextField(string: current?.project ?? "Studio")
        let amountField = NSTextField(string: current.map { String(format: "%.0f", $0.amount) } ?? "3900")
        let dailyField = NSTextField(string: (current?.daily ?? PreviewData.sparkRevenue)
            .map { String(format: "%.2f", $0) }.joined(separator: ", "))
        let currencyField = NSTextField(string: current?.currency ?? "$")
        let rangePopup = NSPopUpButton(frame: .zero, pullsDown: false)
        rangePopup.addItems(withTitles: RevenueRange.allCases.map(\.label))
        if let current {
            rangePopup.selectItem(withTitle: current.range.label)
        }

        func row(_ title: String, _ field: NSView) -> NSStackView {
            let label = NSTextField(labelWithString: title)
            label.font = .systemFont(ofSize: 11)
            label.textColor = .secondaryLabelColor
            label.setContentHuggingPriority(.defaultHigh, for: .horizontal)
            let stack = NSStackView(views: [label, field])
            stack.orientation = .horizontal
            stack.spacing = 8
            field.widthAnchor.constraint(greaterThanOrEqualToConstant: 170).isActive = true
            return stack
        }

        let form = NSStackView(views: [
            row("Project", projectField),
            row("MTD amount", amountField),
            row("Daily", dailyField),
            row("Currency", currencyField),
            row("Range", rangePopup),
        ])
        form.orientation = .vertical
        form.alignment = .leading
        form.spacing = 8
        form.frame = NSRect(x: 0, y: 0, width: 280, height: 150)
        alert.accessoryView = form
        alert.window.initialFirstResponder = projectField

        guard alert.runModal() == .alertFirstButtonReturn else { return }
        let amount = Double(amountField.stringValue
            .replacingOccurrences(of: ",", with: "")) ?? 0
        let daily = dailyField.stringValue
            .split(whereSeparator: { $0 == "," || $0 == " " || $0 == "\n" })
            .compactMap { Double($0) }
        let range = RevenueRange(rawValue: rangePopup.titleOfSelectedItem ?? "MTD") ?? .mtd
        let currency = currencyField.stringValue.isEmpty ? "$" : currencyField.stringValue
        save(project: projectField.stringValue.isEmpty ? "Studio" : projectField.stringValue,
             amount: amount, daily: daily, range: range, currency: currency)
    }

    /// Pratinjau/render offscreen: nilai referensi.
    public static let preview: RevenueViewModel = {
        let config = RevenueConfig(project: "Studio", amount: 3900,
                                   daily: PreviewData.sparkRevenue, range: .mtd)
        return RevenueViewModel(provider: ManualProvider(config: config),
                                config: config, isPreview: true)
    }()
}
