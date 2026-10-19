import AppKit
import SecondDockKit
import SwiftUI

// Render offscreen dock dark/light -> /tmp (verifikasi visual tanpa window).
// Skala: min slider (0.6), default/max layar ini (0.9), dan 1.0 untuk pembanding.
@main
struct RenderShots {
    static func main() async {
        _ = NSApplication.shared
        await MainActor.run {
            for scale in [0.6, 0.9, 1.0] {
                for scheme in [ColorScheme.dark, ColorScheme.light] {
                    let name = scheme == .dark ? "dark" : "light"
                    let view = DockView()
                        .environment(\.theme, Theme(scale: scale))
                        .environment(\.colorScheme, scheme)
                        .environment(\.glassFallback,
                                     scheme == .dark ? Color(red: 0.16, green: 0.16, blue: 0.18)
                                                     : Color(red: 0.93, green: 0.93, blue: 0.95))
                    var renderer = ImageRenderer(content: view)
                    renderer.scale = 2
                    if let image = renderer.nsImage,
                       let tiff = image.tiffRepresentation,
                       let rep = NSBitmapImageRep(data: tiff),
                       let png = rep.representation(using: NSBitmapImageRep.FileType.png, properties: [:]) {
                        let url = URL(fileURLWithPath: "/tmp/seconddock-\(scale)-\(name).png")
                        try? png.write(to: url)
                        print("OK \(url.path)")
                    }
                }
            }
            print("RENDER_DONE")
        }
    }
}
