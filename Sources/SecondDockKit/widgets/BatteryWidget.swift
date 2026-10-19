import SwiftUI

struct BatteryWidget: View {
    let rings: [BatteryRingState]

    @Environment(\.theme) private var theme
    @Environment(\.colorScheme) private var scheme

    var body: some View {
        WidgetCard {
            Group {
                if rings.isEmpty {
                    HStack(spacing: theme.s(8)) {
                        Image(systemName: "battery.0")
                            .font(theme.font(10))
                            .foregroundStyle(theme.secondaryText(scheme))
                            .frame(width: theme.s(14))
                        Text("No devices")
                            .font(theme.font(10, .medium))
                            .foregroundStyle(theme.secondaryText(scheme))
                            .lineLimit(1)
                            .frame(width: theme.s(44), alignment: .leading)
                    }
                } else {
                    HStack(spacing: theme.s(10)) {
                        ForEach(rings) { ring in
                            ringView(ring)
                        }
                    }
                }
            }
            // Ruang dua cincin dipakai selalu, jadi 1 cincin ikut terpusat
            // dan lebar kartu tidak berubah.
            .frame(width: theme.s(66))
        }
    }

    private func ringView(_ ring: BatteryRingState) -> some View {
        VStack(spacing: 0) {
            ZStack {
                Circle()
                    .stroke(theme.ringTrack(scheme), lineWidth: theme.s(3))
                    .frame(width: theme.s(28), height: theme.s(28))
                Circle()
                    .trim(from: 0, to: CGFloat(ring.pct) / 100)
                    .stroke(color(for: ring.tone), lineWidth: theme.s(3))
                    .rotationEffect(.degrees(-90))
                    .frame(width: theme.s(28), height: theme.s(28))
                Image(systemName: ring.symbol)
                    .font(theme.font(10))
                    .foregroundStyle(.white)
                if ring.isCharging {
                    Image(systemName: "bolt.fill")
                        .font(theme.font(6, .bold))
                        .foregroundStyle(color(for: ring.tone))
                        .offset(x: theme.s(9), y: theme.s(-9))
                }
            }
            .frame(height: theme.lineValue + theme.lineTiny)
            Text("\(ring.pct)%")
                .font(theme.font(10, .medium))
                .foregroundStyle(theme.tinyText(scheme))
                .lineLimit(1)
                .frame(height: theme.lineTiny)
        }
        .fixedSize(horizontal: true, vertical: false)
        .help("\(ring.name) — \(ring.pct)%\(ring.isCharging ? " (charging)" : "")")
    }

    private func color(for tone: BatteryRingTone) -> Color {
        switch tone {
        case .good: Theme.positiveGreen
        case .low: Theme.accentOrange
        case .critical: Theme.dangerRed
        }
    }
}

struct BatteryWidget_Previews: PreviewProvider {
    static var previews: some View {
        BatteryWidget(rings: BatteryViewModel.preview.rings)
            .environment(\.theme, Theme(scale: 1))
            .padding()
            .background(Color.black)
    }
}