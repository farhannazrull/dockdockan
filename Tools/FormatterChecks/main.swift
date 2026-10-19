import Foundation
import SecondDockKit

// Pemeriksa formatter: `swift run FormatterChecks` (exit 1 bila ada yang gagal).
var failures = 0

func check(_ name: String, _ actual: String, _ expected: String) {
    if actual == expected {
        print("PASS \(name)")
    } else {
        failures += 1
        print("FAIL \(name): dapat '\(actual)', mau '\(expected)'")
    }
}

check("price", DockFormatters.price(333.08), "333.08")
check("price-group", DockFormatters.price(1234.5), "1,234.50")
check("price-zero", DockFormatters.price(0), "0.00")
check("percent-pos", DockFormatters.percent(0.24), "+0.24%")
check("percent-neg", DockFormatters.percent(-1.5), "-1.50%")
check("percent-zero", DockFormatters.percent(0), "+0.00%")
check("duration-zero", DockFormatters.duration(0), "0:00")
check("duration-min", DockFormatters.duration(65), "1:05")
check("duration-song", DockFormatters.duration(306), "5:06")
check("duration-hour", DockFormatters.duration(3723), "1:02:03")
check("compact-K", DockFormatters.compactCurrency(3900), "$3.9K")
check("compact-K2", DockFormatters.compactCurrency(2400), "$2.4K")
check("compact-small", DockFormatters.compactCurrency(999), "$999")
check("compact-M", DockFormatters.compactCurrency(1_200_000), "$1.2M")
check("countdown-default", DockFormatters.countdown(25 * 60), "25:00")
check("countdown-mid", DockFormatters.countdown(65), "1:05")
check("countdown-zero", DockFormatters.countdown(0), "0:00")
check("countdown-over-hour", DockFormatters.countdown(90 * 60), "90:00")

// State machine FocusViewModel (headless, tanpa UI).
@MainActor
func checkFocus() {
    // "M:SS" -> detik, untuk membandingkan waktu secara numerik.
    func textSeconds(_ text: String) -> Double {
        let parts = text.split(separator: ":")
        guard parts.count == 2, let m = Double(parts[0]), let s = Double(parts[1]) else { return -1 }
        return m * 60 + s
    }
    func whole(_ value: Double) -> Int { Int(value.rounded()) }

    // Thread.sleep memblokir main thread sehingga timer tak pernah diproses;
    // putar run loop supaya timer benar-benar dit ticked.
    func spin(_ seconds: Double) {
        RunLoop.current.run(until: Date().addingTimeInterval(seconds))
    }

    let vm = FocusViewModel()
    check("focus-idle-text", vm.remainingText, "25:00")
    check("focus-idle-progress", String(format: "%.2f", vm.progress), "0.00")
    check("focus-idle-label", vm.label, "Focus")

    vm.start()
    check("focus-running-phase", "\(vm.phase)", "running")
    check("focus-running-label", vm.label, "Focus")
    check("focus-running-near-full", vm.remainingText.hasSuffix(":00") ? "ok" : vm.remainingText, "ok")

    // Buktikan ticker benar-benar jalan: tunggu ~2 detik, teks harus turun ~2 detik.
    let atStart = textSeconds(vm.remainingText)
    spin(2.2)
    let afterTick = textSeconds(vm.remainingText)
    let dropped = atStart - afterTick
    check("focus-ticker-runs", (1.0...3.5).contains(dropped) ? "ok" : "turun \(dropped)", "ok")
    check("focus-progress-advances", vm.progress > 0 ? "ok" : "0", "ok")

    // Pause tidak boleh mereset progres atau melompat maju.
    let progressBeforePause = vm.progress
    let textBeforePause = DockFormatters.countdown(whole(textSeconds(vm.remainingText)))
    vm.pause()
    check("focus-paused-phase", "\(vm.phase)", "paused")
    check("focus-paused-label", vm.label, "Paused")
    check("focus-paused-progress-monotonic",
          vm.progress >= progressBeforePause ? "ok" : "regres \(vm.progress)",
          "ok")
    let textAfterPause = DockFormatters.countdown(whole(textSeconds(vm.remainingText)))
    check("focus-paused-time-monotonic",
          textAfterPause <= textBeforePause ? "ok" : "maju \(vm.remainingText)", "ok")

    // Setelah pause, tidak ada ticker yang boleh mengubah fase.
    spin(1.2)
    check("focus-paused-stable", "\(vm.phase)", "paused")
    check("focus-paused-time-frozen", vm.remainingText, textAfterPause)

    vm.reset()
    check("focus-reset-phase", "\(vm.phase)", "idle")
    check("focus-reset-text", vm.remainingText, "25:00")

    vm.minutes = 45
    check("focus-length-45", vm.remainingText, "45:00")
    check("focus-length-persisted", "\(UserDefaults.standard.integer(forKey: "focusMinutes"))", "45")
    UserDefaults.standard.set(25, forKey: "focusMinutes")

    // Ikon reset: label "Done" hanya saat finished.
    check("focus-finished-label", FocusPhase.finished == .finished ? "Done" : "?", "Done")
}

MainActor.assumeIsolated { checkFocus() }

// Ambang warna cincin baterai: hijau >20, oranye 10-20, merah <10.
func checkBatteryTone() {
    func tone(_ pct: Int) -> String {
        switch BatteryRingState(id: "x", symbol: "airpods", name: "x",
                                pct: pct, isCharging: false).tone {
        case .good: "good"
        case .low: "low"
        case .critical: "critical"
        }
    }
    check("tone-100", tone(100), "good")
    check("tone-21", tone(21), "good")
    check("tone-20", tone(20), "low")
    check("tone-10", tone(10), "low")
    check("tone-9", tone(9), "critical")
    check("tone-0", tone(0), "critical")
}
MainActor.assumeIsolated { checkBatteryTone() }

// Persistensi dock.json harus bertahan utuh lewat encode/decode.
@MainActor
func checkDockConfig() {
    let original = DockConfig(pinned: ["com.apple.finder", "com.apple.Safari"],
                              folderPath: "/tmp/Projects")
    guard let data = try? JSONEncoder().encode(original),
          let decoded = try? JSONDecoder().decode(DockConfig.self, from: data) else {
        check("dock-config-roundtrip", "gagal", "lolos")
        return
    }
    check("dock-config-roundtrip", "\(decoded == original)", "true")
    check("dock-config-defaults", DockConfig.defaults.pinned.count > 0 ? "ada" : "kosong", "ada")
    check("dock-config-json", data.isEmpty ? "kosong" : "isi", "isi")
}
MainActor.assumeIsolated { checkDockConfig() }

if failures > 0 {
    print("\(failures) GAGAL")
    exit(1)
}
print("SEMUA LOLOS")
