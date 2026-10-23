import CoreGraphics
import Foundation

// Ekran geometrisi, global Cocoa koordinatlarında (sol-alt orijin, y yukarı).
// Cocoa imleci x için [minX, maxX), y için (minY, maxY] aralığında raporlar; ortak kenarda tek ekran eşleşsin diye.

enum Side: Equatable {
    case left, right, top, bottom

    var opposite: Side {
        switch self {
        case .left: .right
        case .right: .left
        case .top: .bottom
        case .bottom: .top
        }
    }

    /// Bu kenardan ekranın içine doğru birim vektör, ekran-yerel sol-üst orijinli koordinatlarda (shader'ın sistemi).
    var inward: CGVector {
        switch self {
        case .left: CGVector(dx: 1, dy: 0)
        case .right: CGVector(dx: -1, dy: 0)
        case .top: CGVector(dx: 0, dy: 1)
        case .bottom: CGVector(dx: 0, dy: -1)
        }
    }
}

/// İmlecin, başka bir ekranla paylaşılan bir kenara uzaklığı.
struct Approach: Equatable {
    let screen: Int
    let neighbor: Int
    let side: Side
    let distance: CGFloat
    /// İmlecin kenar üzerindeki izdüşümü.
    let edgePoint: CGPoint
}

/// İmleç bir ekrandan diğerine geçti.
struct Crossing: Equatable {
    let from: Int
    let to: Int
    /// Çıkılan ekranın hangi kenarından çıkıldığı.
    let side: Side
    /// Geçiş noktası, ortak kenar üzerinde.
    let edgePoint: CGPoint
}

func screenIndex(containing point: CGPoint, frames: [CGRect]) -> Int? {
    frames.firstIndex { f in
        point.x >= f.minX && point.x < f.maxX && point.y > f.minY && point.y <= f.maxY
    }
}

/// Ekran kenarları tam sayı noktalarda birleşir; kayan nokta farkını yut.
private func same(_ a: CGFloat, _ b: CGFloat) -> Bool { abs(a - b) < 0.5 }

/// `point`'in bulunduğu ekranın, başka bir ekrana komşu ve `zone` içinde kalan en yakın kenarı.
func approach(to point: CGPoint, frames: [CGRect], within zone: CGFloat) -> Approach? {
    guard let i = screenIndex(containing: point, frames: frames) else { return nil }
    let f = frames[i]
    var best: Approach?
    for (j, g) in frames.enumerated() where j != i {
        let candidates: [(Side, Bool, CGFloat, CGPoint)] = [
            (.right, same(g.minX, f.maxX) && point.y > g.minY && point.y <= g.maxY, f.maxX - point.x, CGPoint(x: f.maxX, y: point.y)),
            (.left, same(g.maxX, f.minX) && point.y > g.minY && point.y <= g.maxY, point.x - f.minX, CGPoint(x: f.minX, y: point.y)),
            (.top, same(g.minY, f.maxY) && point.x >= g.minX && point.x < g.maxX, f.maxY - point.y, CGPoint(x: point.x, y: f.maxY)),
            (.bottom, same(g.maxY, f.minY) && point.x >= g.minX && point.x < g.maxX, point.y - f.minY, CGPoint(x: point.x, y: f.minY)),
        ]
        for (side, adjacent, distance, edgePoint) in candidates where adjacent && distance <= zone {
            if best == nil || distance < best!.distance {
                best = Approach(screen: i, neighbor: j, side: side, distance: distance, edgePoint: edgePoint)
            }
        }
    }
    return best
}

/// İki ardışık imleç konumu arasında ekran değiştiyse geçiş. Çok uzun bir adım geçiş değil sıçramadır
/// (başka bir uygulamanın imleci taşıması gibi), efekt oynamaz.
func crossing(from previous: CGPoint, to point: CGPoint, frames: [CGRect], maxStep: CGFloat = 400) -> Crossing? {
    guard let from = screenIndex(containing: previous, frames: frames),
          let to = screenIndex(containing: point, frames: frames), from != to,
          hypot(point.x - previous.x, point.y - previous.y) <= maxStep else { return nil }
    let f = frames[from]
    let side: Side
    if point.x >= f.maxX {
        side = .right
    } else if point.x < f.minX {
        side = .left
    } else if point.y > f.maxY {
        side = .top
    } else {
        side = .bottom
    }
    let edgePoint: CGPoint = switch side {
    case .right: CGPoint(x: f.maxX, y: point.y)
    case .left: CGPoint(x: f.minX, y: point.y)
    case .top: CGPoint(x: point.x, y: f.maxY)
    case .bottom: CGPoint(x: point.x, y: f.minY)
    }
    return Crossing(from: from, to: to, side: side, edgePoint: edgePoint)
}

/// Global Cocoa noktası → ekran-yerel sol-üst orijinli nokta.
func localPoint(_ point: CGPoint, in frame: CGRect) -> CGPoint {
    CGPoint(x: point.x - frame.minX, y: frame.maxY - point.y)
}

/// Toplanma evresinin şiddeti. Yeni hedef yumuşakça yaklaşılır; imleç durursa (yeni olay gelmezse) kendiliğinden söner.
/// Zamana bağlı saf bir fonksiyon, böylece her karede durum değiştirmek gerekmez.
struct Charge {
    private(set) var target: Double = 0
    private var from: Double = 0
    private var changedAt: Date = .distantPast

    static let follow = 0.08     // hedefe yaklaşma süresi
    static let hold = 0.12       // yeni olay gelmezse hedef bu kadar korunur
    static let decay = 0.15      // sonra söner

    func value(at now: Date) -> Double {
        let dt = max(0, now.timeIntervalSince(changedAt))
        let held = dt < Self.hold ? target : target * exp(-(dt - Self.hold) / Self.decay)
        return held + (from - held) * exp(-dt / Self.follow)
    }

    mutating func set(_ value: Double, at now: Date) {
        from = self.value(at: now)
        target = value
        changedAt = now
    }
}
