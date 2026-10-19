import SwiftUI

struct RevenueWidget: View {
    let label: String
    let value: String
    let points: [Double]
    var rangeLabel = "MTD"
    var isEmpty = false
    var onConnect: () -> Void = {}

    @Environment(\.theme) private var theme
    @Environment(\.colorScheme) private var colorScheme

    /// Lebar isi kartu referensi: kolom kiri 56.5 + gap 8 + sparkline 80.
    private let contentWidth: CGFloat = 144.5

    private var topHeight: CGFloat {
        theme.lineTiny + theme.lineValue
    }

    var body: some View {
        WidgetCard {
            // Baris atas: label+nilai kiri, sparkline kanan.
            // Baris bawah: "Revenue" ke leading, "MTD" ke trailing kartu.
            VStack(alignment: .leading, spacing: 0) {
                Group {
                    if isEmpty {
                        emptyRow
                            .frame(width: theme.s(contentWidth), height: topHeight,
                                   alignment: .leading)
                    } else {
                        HStack(spacing: theme.s(8)) {
                            VStack(alignment: .leading, spacing: 0) {
                                HStack(spacing: theme.s(4)) {
                                    Circle().fill(Theme.teal)
                                        .frame(width: theme.s(6), height: theme.s(6))
                                    Text(label)
                                        .font(theme.font(10, .medium))
                                        .foregroundStyle(theme.tinyText(colorScheme))
                                        .lineLimit(1)
                                }
                                .frame(height: theme.lineTiny)
                                Text(value)
                                    .font(theme.mono(20, .semibold))
                                    .lineLimit(1)
                                    .frame(height: theme.lineValue, alignment: .leading)
                            }
                            .fixedSize(horizontal: true, vertical: false)
                            Sparkline(values: points, color: Theme.teal, width: 80,
                                      height: theme.lineTiny + theme.lineValue)
                        }
                        .frame(height: topHeight)
                    }
                }
                HStack {
                    Text("Revenue")
                        .font(theme.font(10, .medium))
                        .foregroundStyle(theme.tinyText(colorScheme))
                        .lineLimit(1)
                    Spacer(minLength: theme.s(4))
                    Text(rangeLabel)
                        .font(theme.font(10, .medium))
                        .foregroundStyle(theme.tinyText(colorScheme))
                        .lineLimit(1)
                }
                .frame(height: theme.lineTiny)
            }
            .fixedSize(horizontal: true, vertical: false)
        }
    }

    private var emptyRow: some View {
        HStack(spacing: theme.s(8)) {
            Image(systemName: "chart.line.uptrend.xyaxis")
                .font(theme.font(13, .semibold))
                .foregroundStyle(Theme.teal)
            Button(action: onConnect) {
                Text("Connect source")
                    .font(theme.font(12, .semibold))
                    .lineLimit(1)
                    .fixedSize(horizontal: true, vertical: false)
                    .foregroundStyle(theme.primaryGlyph(colorScheme).opacity(0.92))
                    .padding(.horizontal, theme.s(8))
                    .padding(.vertical, theme.s(4))
                    .background(theme.primaryGlyph(colorScheme).opacity(0.12))
                    .clipShape(Capsule(style: .continuous))
            }
            .buttonStyle(.plain)
            .fixedSize(horizontal: true, vertical: false)
        }
    }
}

struct RevenueWidget_Previews: PreviewProvider {
    static var previews: some View {
        RevenueWidget(label: "Studio", value: "$3.9K", points: [1.8, 2.1, 2.0, 2.4, 2.6, 2.5, 2.9, 3.1, 3.0, 3.4, 3.6, 3.9])
            .environment(\.theme, Theme(scale: 1))
            .padding()
            .background(Color.black)
    }
}
