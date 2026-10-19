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

struct StockWidget: View {
    let symbol: String
    let price: String
    let change: String
    let points: [Double]
    var positive = true

    @Environment(\.theme) private var theme

    var body: some View {
        WidgetCard {
            HStack(spacing: theme.s(8)) {
                VStack(alignment: .leading, spacing: 0) {
                    Text(symbol)
                        .font(theme.font(10, .medium))
                        .foregroundStyle(theme.tinyText(colorScheme))
                        .lineLimit(1)
                        .frame(height: theme.lineTiny, alignment: .leading)
                    Text(price)
                        .font(theme.mono(20, .semibold))
                        .lineLimit(1)
                        .frame(height: theme.lineValue, alignment: .leading)
                    Text(change)
                        .font(theme.font(11))
                        .foregroundStyle(positive ? Theme.positiveGreen : Theme.dangerRed)
                        .lineLimit(1)
                        .frame(height: theme.lineTiny, alignment: .leading)
                }
                .fixedSize(horizontal: true, vertical: false)
                Sparkline(values: points, color: Theme.positiveGreen, width: 90,
                          height: theme.lineTiny + theme.lineValue + theme.lineTiny)
            }
        }
    }

    @Environment(\.colorScheme) private var colorScheme
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
            .previewDisplayName("Stock 1.0 light")
    }
}
