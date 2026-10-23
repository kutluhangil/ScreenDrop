import CoreGraphics

// Tüm geometri global Quartz noktalarında: ana ekranın sol üstü orijin, y aşağı doğru artar.
// NSScreen ve NSEvent sol-alt orijinli Cocoa koordinatı verir; ScreenCaptureKit ve CoreGraphics sol-üst.
// Dönüşüm yalnızca `Coordinates` ile yapılır.

enum Coordinates {
    /// Cocoa ↔ Quartz. Kendi tersidir: iki yönde de aynı formül.
    static func flip(_ point: CGPoint, primaryHeight: CGFloat) -> CGPoint {
        CGPoint(x: point.x, y: primaryHeight - point.y)
    }

    /// Cocoa ↔ Quartz dikdörtgen. Kendi tersidir.
    static func flip(_ rect: CGRect, primaryHeight: CGFloat) -> CGRect {
        CGRect(x: rect.minX, y: primaryHeight - rect.maxY, width: rect.width, height: rect.height)
    }
}

/// Quartz'ta ekranlar x için [minX, maxX), y için [minY, maxY) aralığını kapsar; ortak kenarda tek ekran eşleşir.
func display(containing point: CGPoint, frames: [CGRect]) -> Int? {
    frames.firstIndex { f in
        point.x >= f.minX && point.x < f.maxX && point.y >= f.minY && point.y < f.maxY
    }
}

/// İki ekranın birleştiği ek yeri.
struct Seam: Equatable {
    enum Axis { case vertical, horizontal }

    /// Soldaki (dikey ek) ya da üstteki (yatay ek) ekran.
    let a: Int
    /// Sağdaki ya da alttaki ekran.
    let b: Int
    let axis: Axis
    /// Ek yerinin konumu: dikeyde x, yatayda y.
    let position: CGFloat
    /// İki kenarın kesiştiği parça, ek yeri boyunca (dikeyde y, yatayda x).
    let start: CGFloat
    let end: CGFloat

    var midpoint: CGPoint {
        let middle = (start + end) / 2
        return axis == .vertical ? CGPoint(x: position, y: middle) : CGPoint(x: middle, y: position)
    }
}

/// Kenarlar tam sayı noktalarda birleşir; kayan nokta farkını yut.
private func same(_ a: CGFloat, _ b: CGFloat) -> Bool { abs(a - b) < 0.5 }

/// İki ekran bir kenarı paylaşıyorsa ek yeri; köşeden değiyorlarsa ya da ayrıksa nil.
func seam(between i: Int, _ j: Int, frames: [CGRect]) -> Seam? {
    let f = frames[i], g = frames[j]
    func vertical(_ left: Int, _ right: Int) -> Seam? {
        let l = frames[left], r = frames[right]
        let start = max(l.minY, r.minY), end = min(l.maxY, r.maxY)
        return end > start ? Seam(a: left, b: right, axis: .vertical, position: l.maxX, start: start, end: end) : nil
    }
    func horizontal(_ top: Int, _ bottom: Int) -> Seam? {
        let t = frames[top], b = frames[bottom]
        let start = max(t.minX, b.minX), end = min(t.maxX, b.maxX)
        return end > start ? Seam(a: top, b: bottom, axis: .horizontal, position: t.maxY, start: start, end: end) : nil
    }
    if same(f.maxX, g.minX) { return vertical(i, j) }
    if same(g.maxX, f.minX) { return vertical(j, i) }
    if same(f.maxY, g.minY) { return horizontal(i, j) }
    if same(g.maxY, f.minY) { return horizontal(j, i) }
    return nil
}

/// Tüm ek yerleri, ekran sırasıyla.
func seams(frames: [CGRect]) -> [Seam] {
    frames.indices.flatMap { i in (i + 1..<frames.count).compactMap { seam(between: i, $0, frames: frames) } }
}

/// İmlecin önceki konumdan şimdikine giden doğrusunun ek yeriyle kesişimi, ortak parçaya sıkıştırılmış.
/// Önceki konum ek yerine `maxApproach`'tan uzaksa gerçek bir kenar geçişi değil sıçramadır (başka bir
/// uygulamanın imleci taşıması gibi): nil.
func crossingPoint(from previous: CGPoint, to current: CGPoint, seam: Seam, maxApproach: CGFloat = 40) -> CGPoint? {
    let vertical = seam.axis == .vertical
    let p0 = vertical ? previous.x : previous.y, p1 = vertical ? current.x : current.y
    let a0 = vertical ? previous.y : previous.x, a1 = vertical ? current.y : current.x
    guard abs(p0 - seam.position) <= maxApproach, p1 != p0 else { return nil }
    let t = min(max((seam.position - p0) / (p1 - p0), 0), 1)
    let along = min(max(a0 + t * (a1 - a0), seam.start), seam.end)
    return vertical ? CGPoint(x: seam.position, y: along) : CGPoint(x: along, y: seam.position)
}

/// Bir ekranda, ek yeri boyunca efektin oynadığı şerit.
struct Strip: Equatable {
    /// Şeridin hangi kenarı ek yerine değiyor (orada solma uygulanmaz). Shader ile aynı sıra.
    enum Edge: Int32 { case left = 0, right, top, bottom }

    let display: Int
    /// Global Quartz noktaları.
    let rect: CGRect
    let seamEdge: Edge
}

/// Ek yerinin iki yanındaki şeritler: her biri `depth` derinliğinde, ortak parçanın iki ucundan `margin`
/// kadar taşan, kendi ekranına kırpılmış.
func strips(for seam: Seam, frames: [CGRect], depth: CGFloat = 360, margin: CGFloat = 120) -> (a: Strip, b: Strip) {
    let lo = seam.start - margin, length = seam.end - seam.start + 2 * margin
    if seam.axis == .vertical {
        let a = CGRect(x: seam.position - depth, y: lo, width: depth, height: length).intersection(frames[seam.a])
        let b = CGRect(x: seam.position, y: lo, width: depth, height: length).intersection(frames[seam.b])
        return (Strip(display: seam.a, rect: a, seamEdge: .right), Strip(display: seam.b, rect: b, seamEdge: .left))
    }
    let a = CGRect(x: lo, y: seam.position - depth, width: length, height: depth).intersection(frames[seam.a])
    let b = CGRect(x: lo, y: seam.position, width: length, height: depth).intersection(frames[seam.b])
    return (Strip(display: seam.a, rect: a, seamEdge: .bottom), Strip(display: seam.b, rect: b, seamEdge: .top))
}
