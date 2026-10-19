import SwiftUI

struct RevenueWidget: View {
    let label: String
    let value: String
    let points: [Double]

    @Environment(\.theme) private var theme

    var body: some View {
        WidgetCard {
            // Baris atas: label+nilai kiri, sparkline kanan.
            // Baris bawah: "Revenue" ke leading, "MTD" ke trailing kartu.
            VStack(alignment: .leading, spacing: 0) {
                HStack(spacing: theme.s(8)) {
                    VStack(alignment: .leading, spacing: 0) {
                        HStack(spacing: theme.s(4)) {
                            Circle().fill(Theme.teal).frame(width: theme.s(6), height: theme.s(6))
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
                .frame(height: theme.lineTiny + theme.lineValue)
                HStack {
                    Text("Revenue")
                        .font(theme.font(10, .medium))
                        .foregroundStyle(theme.tinyText(colorScheme))
                        .lineLimit(1)
                    Spacer(minLength: theme.s(4))
                    Text("MTD")
                        .font(theme.font(10, .medium))
                        .foregroundStyle(theme.tinyText(colorScheme))
                        .lineLimit(1)
                }
                .frame(height: theme.lineTiny)
            }
            .fixedSize(horizontal: true, vertical: false)
        }
    }

    @Environment(\.colorScheme) private var colorScheme
}

struct RevenueWidget_Previews: PreviewProvider {
    static var previews: some View {
        RevenueWidget(label: "Studio", value: "$3.9K", points: [1.8, 2.1, 2.0, 2.4, 2.6, 2.5, 2.9, 3.1, 3.0, 3.4, 3.6, 3.9])
            .environment(\.theme, Theme(scale: 1))
            .padding()
            .background(Color.black)
    }
}
