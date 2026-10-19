# SecondDock

Floating second dock untuk macOS (14+) — SwiftUI, mengikuti referensi CoolDock:
Finder | saham+Sparkline | folder P | Messages+3 | Now Playing | Fokus |
Kalender+Join | baterai perangkat | revenue | note | divider | app paged + handle.

## Syarat

- macOS 14+, Command Line Tools (`xcode-select --install`) cukup.
  Xcode penuh opsional (untuk `#Preview` dan `xcodebuild`/`XCTest`).

## Build & jalan

```bash
./scripts/build-app.sh
open SecondDock.app
```

Config di `~/Library/Application Support/SecondDock/`:

- `dock.json` — app yang di-pin + folder.
- `note.txt` — isi note.
- `stock.json` — simbol saham (default `AAPL`).
- `revenue.json` — project, amount, daily, range, currency.
- API key (bila provider membutuhkannya) disimpan di **Keychain**, bukan file.

- Saham: Yahoo Finance (gratis, tanpa key). Refresh 60 detik saat bursa AS
  buka, 15 menit di luar jam bursa, dan saat Mac bangun. Gagal refresh =
  nilai terakhir tetap tampil redup + ikon jam.
- Now Playing: MediaRemote (private framework) dulu, lalu fallback AppleScript
  ke Music/Spotify. Kontrol (prev/play/next) lewat AppleScript yang sama.
  Izin Automation ditolak = kartu menampilkan "Nothing playing" + Open Music.
- Baterai: perangkat Bluetooth real (IORegistry) + baterai internal Mac (pmset).
  Badge Messages disembunyikan (tidak ada API resmi; tanpa tebakan angka).
- Revenue: sumber manual (form) untuk sekarang; `RemoteProvider` masih stub.
  Sparkline hanya tampil bila ada minimal 2 titik data.

Ikon ◫ di menu bar: Stock symbol..., Revenue..., ukuran dock, Focus length,
Launch at Login, Quit.

## Verifikasi tiap step

```bash
swift build                 # harus "Build complete"
swift run FormatterChecks   # semua cek formatter harus LOLOS
```

## Penyimpangan sadar dari spek awal

- Sparkline digambar Canvas (garis + area + pola titik), bukan Swift Charts —
  Charts tidak mendukung isi area berpola.
- Latar kaca pakai NSVisualEffectView adaptif (`.hudWindow` di dark mode —
  material paling dekat Dock asli, `.underWindowBackground` di light).
  Render offscreen pakai warna fallback (effect view tidak render di ImageRenderer).
- `#Preview` dihapus dari file widget (butuh plugin Xcode); kembalikan saat
  dibuka di Xcode penuh.
- `FormatterChecks` executable pengganti XCTest (XCTest butuh Xcode penuh;
  logika ceknya 1:1 sehingga migrasi trivial).
- Hover magnification kontinu (bukan 3-level) + spring — dirasa lebih mulus;
  angka kurva di `DockView` (`influence`/`peak`).
- Layar sempit: skala di-cap agar ≤96% (bukan scroll) — lebih tenang untuk dock.
  Batas atas slider ikut dihitung ulang dari lebar layar (`DockPanelController.maxFittingScale`),
  jadi tidak ada rentang slider mati yang hanya diam-diam di-cap. Di layar 1680pt
  rentangnya 0.6–0.9.
- Kolom judul musik lebar tetap 150 agar tidak pernah kepotong.
- Bila spek teks vs gambar referensi beda, teks yang menang: fokus "3:23",
  revenue "$3.9K".
- Focus sudah timer Pomodoro sungguhan (`FocusViewModel`), tapi seluruh state
  masuk lewat init parameter — view tetap murni dan bisa di-render offscreen.
  Sumber kebenaran `endDate`, jadi tetap benar setelah tidur. Panjang sesi
  disimpan di `focusMinutes` (default 25, pilihan 15/25/45/60).

## Roadmap (phase 2, protokol sudah siap)

`QuoteProvider`/`RevenueProvider` memudahkan penggantian sumber. Yang belum
real: `RemoteProvider` revenue (stub) dan baterai AirPods (butuh API privat
Bluetooth). Saham, Now Playing, kalender, dan baterai Mac/BT sudah real.
