import SwiftUI

/// Garis 1.5pt + area bertitik halus. Semua ukuran ikut skala.
struct Sparkline: View {
    let values: [Double]
    let color: Color
    let width: CGFloat // base pt sebelum skala
    var height: CGFloat? // bila nil, isi tinggi kartu

    @Environment(\.theme) private var theme

    var body: some View {
        Canvas { context, size in
            guard values.count > 1 else { return }
            let lo = values.min() ?? 0
            let hi = values.max() ?? 1
            let span = max(hi - lo, 0.0001)
            func point(_ i: Int) -> CGPoint {
                CGPoint(
                    x: size.width * CGFloat(i) / CGFloat(values.count - 1),
                    y: size.height - 2 - (size.height - 4) * CGFloat((values[i] - lo) / span)
                )
            }
            var area = Path()
            area.move(to: CGPoint(x: 0, y: size.height))
            for i in values.indices { area.addLine(to: point(i)) }
            area.addLine(to: CGPoint(x: size.width, y: size.height))
            area.closeSubpath()

            // Isian titik: diameter 1pt, kisi 3pt, dipotong area kurva,
            // makin ke bawah makin redup.
            context.clip(to: area)
            let step = Swift.max(theme.s(3), 1)
            let dotR = Swift.max(theme.s(0.5), 0.25)
            var y: CGFloat = 0
            while y <= size.height {
                var row = Path()
                var x: CGFloat = 0
                while x <= size.width {
                    row.addEllipse(in: CGRect(x: x - dotR, y: y - dotR,
                                              width: dotR * 2, height: dotR * 2))
                    x += step
                }
                let fade = 1 - (y / Swift.max(size.height, 1)) * 0.5
                context.fill(row, with: .color(color.opacity(0.45 * fade)))
                y += step
            }

            var line = Path()
            for (i, _) in values.enumerated() {
                if i == 0 { line.move(to: point(i)) } else { line.addLine(to: point(i)) }
            }
            context.stroke(line, with: .color(color), lineWidth: theme.s(1.5))
        }
        .frame(width: theme.s(width), height: height)
    }
}

/// Skeleton shimmer untuk state loading.
private struct ShimmerBar: View {
    let width: CGFloat
    let height: CGFloat

    @Environment(\.theme) private var theme
    @Environment(\.colorScheme) private var scheme
    @State private var phase: CGFloat = -1

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: theme.s(4), style: .continuous)
        shape
            .fill(theme.primaryGlyph(scheme).opacity(0.10))
            .frame(width: width, height: height)
            .overlay {
                LinearGradient(colors: [.clear,
                                        theme.primaryGlyph(scheme).opacity(0.18),
                                        .clear],
                               startPoint: .leading, endPoint: .trailing)
                    .frame(width: width * 0.6)
                    .offset(x: phase * width)
            }
            .clipShape(shape)
            .onAppear {
                withAnimation(.linear(duration: 1.1).repeatForever(autoreverses: false)) {
                    phase = 1
                }
            }
    }
}

struct StockWidget: View {
    let symbol: String
    let price: String
    let change: String
    let points: [Double]
    var tone: StockChangeTone = .positive
    var mode: StockCardMode = .value
    var isStale = false
    var onRetry: () -> Void = {}
    var onAddKey: () -> Void = {}
    var onChangeSymbol: () -> Void = {}

    @Environment(\.theme) private var theme
    @Environment(\.colorScheme) private var colorScheme

    /// Lebar isi kartu referensi: kolom kiri 68.5 + gap 8 + sparkline 90.
    private let contentWidth: CGFloat = 166.5
    private let leftWidth: CGFloat = 68.5

    private var contentHeight: CGFloat {
        theme.lineTiny + theme.lineValue + theme.lineTiny
    }

    private var changeColor: Color {
        switch tone {
        case .positive: Theme.positiveGreen
        case .negative: Theme.dangerRed
        case .flat: theme.secondaryText(colorScheme)
        }
    }

    var body: some View {
        WidgetCard {
            if mode == .value || mode == .loading {
                HStack(spacing: theme.s(8)) {
                    leftColumn
                        .frame(minWidth: theme.s(leftWidth), alignment: .leading)
                    trailing
                }
                .opacity(isStale ? 0.55 : 1)
            } else {
                stateRow
                    .frame(width: theme.s(contentWidth), height: contentHeight,
                           alignment: .leading)
            }
        }
    }

    private var leftColumn: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: theme.s(3)) {
                Text(symbol)
                    .font(theme.font(10, .medium))
                    .foregroundStyle(theme.tinyText(colorScheme))
                    .lineLimit(1)
                if isStale {
                    Image(systemName: "clock")
                        .font(theme.font(8, .semibold))
                        .foregroundStyle(theme.tinyText(colorScheme))
                }
            }
            .frame(height: theme.lineTiny, alignment: .leading)

            middle
                .frame(height: theme.lineValue, alignment: .leading)

            bottom
                .frame(height: theme.lineTiny, alignment: .leading)
        }
        .fixedSize(horizontal: true, vertical: false)
    }

    @ViewBuilder
    private var middle: some View {
        if mode == .loading {
            ShimmerBar(width: theme.s(62), height: theme.s(14))
        } else {
            Text(price)
                .font(theme.mono(20, .semibold))
                .lineLimit(1)
        }
    }

    @ViewBuilder
    private var bottom: some View {
        if mode == .loading {
            ShimmerBar(width: theme.s(40), height: theme.s(8))
        } else {
            Text(change)
                .font(theme.font(11))
                .foregroundStyle(changeColor)
                .lineLimit(1)
        }
    }

    @ViewBuilder
    private var trailing: some View {
        if mode == .loading {
            ShimmerBar(width: theme.s(90), height: contentHeight)
        } else {
            Sparkline(values: points, color: Theme.positiveGreen, width: 90,
                      height: contentHeight)
        }
    }

    private var stateRow: some View {
        HStack(spacing: theme.s(8)) {
            Image(systemName: icon)
                .font(theme.font(13, .semibold))
                .foregroundStyle(theme.secondaryText(colorScheme))
            // Dua baris supaya "Unknown symbol" tidak terpotong.
            VStack(alignment: .leading, spacing: theme.s(2)) {
                Text(label)
                    .font(theme.font(12, .semibold))
                    .lineLimit(1)
                Button(action: action) {
                    Text(actionTitle)
                        .font(theme.font(10, .semibold))
                        .lineLimit(1)
                        .fixedSize(horizontal: true, vertical: false)
                        .foregroundStyle(theme.primaryGlyph(colorScheme).opacity(0.92))
                        .padding(.horizontal, theme.s(7))
                        .padding(.vertical, theme.s(2))
                        .background(theme.primaryGlyph(colorScheme).opacity(0.12))
                        .clipShape(Capsule(style: .continuous))
                }
                .buttonStyle(.plain)
                .fixedSize(horizontal: true, vertical: false)
            }
            Spacer(minLength: 0)
        }
    }

    private var icon: String {
        switch mode {
        case .error: "exclamationmark.triangle"
        case .missingKey: "key.fill"
        case .unknownSymbol: "questionmark.circle"
        default: "questionmark.circle"
        }
    }

    private var label: String {
        switch mode {
        case .error: "Can't load"
        case .missingKey: "No API key"
        case .unknownSymbol: "Unknown symbol"
        default: ""
        }
    }

    private var actionTitle: String {
        switch mode {
        case .error: "Retry"
        case .missingKey: "Add"
        case .unknownSymbol: "Change"
        default: ""
        }
    }

    private var action: () -> Void {
        switch mode {
        case .error: onRetry
        case .missingKey: onAddKey
        case .unknownSymbol: onChangeSymbol
        default: {}
        }
    }
}

struct StockWidget_Previews: PreviewProvider {
    static var previews: some View {
        StockWidget(symbol: "AAPL", price: "333.08", change: "+0.24%", points: PreviewData.sparkAAPL)
            .environment(\.theme, Theme(scale: 1))
            .padding()
            .background(Color.black)
            .previewDisplayName("Stock 1.0 dark")
        StockWidget(symbol: "AAPL", price: "333.08", change: "+0.24%", points: PreviewData.sparkAAPL)
            .environment(\.theme, Theme(scale: 1))
            .preferredColorScheme(.light)
            .padding()
            .background(Color.black)
            .previewDisplayName("Stock 1.0 light")
    }
}
