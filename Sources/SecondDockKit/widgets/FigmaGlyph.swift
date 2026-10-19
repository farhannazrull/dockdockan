import SwiftUI

/// Persegi dengan radius per-sudut, untuk menyusun logo Figma dari 5 shape.
private func roundedPath(_ rect: CGRect, tl: CGFloat, tr: CGFloat, br: CGFloat, bl: CGFloat) -> Path {
    let pi = Double.pi
    var p = Path()
    let r = Swift.min(Swift.max(tl, Swift.max(tr, Swift.max(br, bl))),
                      Swift.min(rect.width, rect.height) / 2)
    p.move(to: CGPoint(x: rect.minX + tl, y: rect.minY))
    p.addLine(to: CGPoint(x: rect.maxX - tr, y: rect.minY))
    if tr > 0 { p.addArc(center: CGPoint(x: rect.maxX - tr, y: rect.minY + tr),
                          radius: tr, startAngle: .radians(-pi / 2), endAngle: .radians(0), clockwise: false) }
    p.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY - br))
    if br > 0 { p.addArc(center: CGPoint(x: rect.maxX - br, y: rect.maxY - br),
                          radius: br, startAngle: .radians(0), endAngle: .radians(pi / 2), clockwise: false) }
    p.addLine(to: CGPoint(x: rect.minX + bl, y: rect.maxY))
    if bl > 0 { p.addArc(center: CGPoint(x: rect.minX + bl, y: rect.maxY - bl),
                          radius: bl, startAngle: .radians(pi / 2), endAngle: .radians(pi), clockwise: false) }
    p.addLine(to: CGPoint(x: rect.minX, y: rect.minY + tl))
    if tl > 0 { p.addArc(center: CGPoint(x: rect.minX + tl, y: rect.minY + tl),
                          radius: tl, startAngle: .radians(pi), endAngle: .radians(1.5 * pi), clockwise: false) }
    p.closeSubpath()
    return p
}

/// Logo Figma: 5 shape (red, orange, purple, blue, green) digambar sebagai
/// vektor, dipakai saat aplikasi tidak terpasang supaya tile tidak pernah kosong.
struct FigmaGlyph: View {
    let size: CGFloat
    var opacity: Double = 0.45

    var body: some View {
        Canvas { context, box in
            let u = Swift.min(box.width, box.height) / 3
            let h = u / 2
            let shapes: [(CGRect, [CGFloat], UInt32)] = [
                (CGRect(x: u, y: 0, width: u, height: u), [0, h, h, 0], 0xFF7262), // merah
                (CGRect(x: 0, y: 0, width: u, height: u), [h, 0, 0, h], 0xF24E1E), // oranye
                (CGRect(x: 0, y: u, width: u, height: u), [h, 0, 0, h], 0xA259FF), // ungu
                (CGRect(x: u, y: u, width: u, height: u), [0, h, h, 0], 0x1ABCFE), // biru
                (CGRect(x: 0, y: 2 * u, width: u, height: u), [h, 0, h, h], 0x0ACF83), // hijau
            ]
            for (rect, r, hex) in shapes {
                context.fill(roundedPath(rect, tl: r[0], tr: r[1], br: r[2], bl: r[3]),
                             with: .color(Color(hex: hex).opacity(opacity)))
            }
        }
        .frame(width: size, height: size)
    }
}

struct FigmaGlyph_Previews: PreviewProvider {
    static var previews: some View {
        FigmaGlyph(size: 40)
            .padding()
            .background(Color.black)
    }
}