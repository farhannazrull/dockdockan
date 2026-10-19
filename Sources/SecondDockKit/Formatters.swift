import Foundation

/// Formatter terpusat (diverifikasi FormatterChecks).
public enum DockFormatters {
    private static let priceFormatter: NumberFormatter = {
        let f = NumberFormatter()
        f.locale = Locale(identifier: "en_US_POSIX") // harga selalu 333.08, apa pun locale sistem
        f.numberStyle = .decimal
        f.minimumFractionDigits = 2
        f.maximumFractionDigits = 2
        f.usesGroupingSeparator = true
        f.groupingSeparator = ","
        return f
    }()

    /// 333.08 -> "333.08", 1234.5 -> "1,234.50"
    public static func price(_ value: Double) -> String {
        priceFormatter.string(from: NSNumber(value: value)) ?? String(format: "%.2f", value)
    }

    /// 0.24 -> "+0.24%", -1.5 -> "-1.50%"
    public static func percent(_ value: Double, signed: Bool = true) -> String {
        let sign = (signed && value >= 0) ? "+" : ""
        return "\(sign)\(String(format: "%.2f", value))%"
    }

    /// 0 -> "0:00", 65 -> "1:05", 306 -> "5:06", 3723 -> "1:02:03"
    public static func duration(_ seconds: Int) -> String {
        let s = max(0, seconds)
        let h = s / 3600
        let m = (s % 3600) / 60
        let sec = s % 60
        if h > 0 {
            return String(format: "%d:%02d:%02d", h, m, sec)
        }
        return String(format: "%d:%02d", m, sec)
    }

    /// Hitung mundur Pomodoro: 1500 -> "25:00", 65 -> "1:05", 0 -> "0:00".
    /// Tanpa pemotongan ke jam (menit > 59 tetap menit).
    public static func countdown(_ seconds: Int) -> String {
        let s = max(0, seconds)
        return String(format: "%d:%02d", s / 60, s % 60)
    }

    /// 3900 -> "$3.9K", 2400 -> "$2.4K", 999 -> "$999", 1_200_000 -> "$1.2M"
    public static func compactCurrency(_ value: Double) -> String {
        let absV = abs(value)
        let sign = value < 0 ? "-" : ""
        if absV >= 1_000_000 {
            return String(format: "$%@%.1fM", sign, absV / 1_000_000)
        }
        if absV >= 1000 {
            return String(format: "$%@%.1fK", sign, absV / 1000)
        }
        return String(format: "$%@%.0f", sign, absV)
    }
}
