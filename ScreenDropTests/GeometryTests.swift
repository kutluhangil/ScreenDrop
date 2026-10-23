import CoreGraphics
import Foundation
import Testing
@testable import ScreenDrop

@MainActor
struct GeometryTests {
    // Kutluhan'ın düzeni: 3440×1440 ana ekran, altında sağa kaydırılmış 1920×1080 (Cocoa koordinatları).
    let stacked = [CGRect(x: 0, y: 0, width: 3440, height: 1440),
                   CGRect(x: 1074, y: -1080, width: 1920, height: 1080)]
    let sideBySide = [CGRect(x: 0, y: 0, width: 1920, height: 1080),
                      CGRect(x: 1920, y: -360, width: 2560, height: 1440)]

    @Test func approachingTheDisplayBelow() {
        let a = approach(to: CGPoint(x: 2000, y: 100), frames: stacked, within: 160)
        #expect(a == Approach(screen: 0, neighbor: 1, side: .bottom, distance: 100, edgePoint: CGPoint(x: 2000, y: 0)))
    }

    @Test func noApproachWhereNoDisplayIsBeyondTheEdge() {
        // Alt kenar ama alttaki ekranın dışında kalan kısım (x < 1074).
        #expect(approach(to: CGPoint(x: 500, y: 50), frames: stacked, within: 160) == nil)
        // Komşu kenara uzak.
        #expect(approach(to: CGPoint(x: 2000, y: 700), frames: stacked, within: 160) == nil)
    }

    @Test func approachingFromBelowAndSideways() {
        let up = approach(to: CGPoint(x: 1500, y: -40), frames: stacked, within: 160)
        #expect(up?.side == .top && up?.neighbor == 0 && up?.distance == 40)
        let right = approach(to: CGPoint(x: 1850, y: 500), frames: sideBySide, within: 160)
        #expect(right == Approach(screen: 0, neighbor: 1, side: .right, distance: 70, edgePoint: CGPoint(x: 1920, y: 500)))
    }

    @Test func crossingDownAndBackUp() {
        let down = crossing(from: CGPoint(x: 2000, y: 3), to: CGPoint(x: 2004, y: -2), frames: stacked)
        #expect(down == Crossing(from: 0, to: 1, side: .bottom, edgePoint: CGPoint(x: 2004, y: 0)))
        let up = crossing(from: CGPoint(x: 1500, y: -3), to: CGPoint(x: 1500, y: 2), frames: stacked)
        #expect(up == Crossing(from: 1, to: 0, side: .top, edgePoint: CGPoint(x: 1500, y: 0)))
    }

    @Test func crossingSideways() {
        let c = crossing(from: CGPoint(x: 1918, y: 20), to: CGPoint(x: 1921, y: 20), frames: sideBySide)
        #expect(c == Crossing(from: 0, to: 1, side: .right, edgePoint: CGPoint(x: 1920, y: 20)))
    }

    @Test func aWarpIsNotACrossing() {
        #expect(crossing(from: CGPoint(x: 100, y: 100), to: CGPoint(x: 2000, y: -500), frames: stacked) == nil)
        #expect(crossing(from: CGPoint(x: 100, y: 100), to: CGPoint(x: 140, y: 120), frames: stacked) == nil)
    }

    @Test func inwardNormalsFaceIntoEachDisplay() {
        // Ana ekranın alt kenarı: içeri yukarı doğru (yerel y azalır); alttaki ekranın üst kenarı: içeri aşağı.
        #expect(Side.bottom.inward == CGVector(dx: 0, dy: -1))
        #expect(Side.bottom.opposite.inward == CGVector(dx: 0, dy: 1))
        #expect(localPoint(CGPoint(x: 2004, y: 0), in: stacked[1]) == CGPoint(x: 930, y: 0))
        #expect(localPoint(CGPoint(x: 2004, y: 0), in: stacked[0]) == CGPoint(x: 2004, y: 1440))
    }

    @Test func chargeFollowsThenFadesWhenThePointerStops() {
        let start = Date(timeIntervalSinceReferenceDate: 0)
        var charge = Charge()
        charge.set(1, at: start)
        #expect(charge.value(at: start) == 0)
        #expect(charge.value(at: start.addingTimeInterval(0.1)) > 0.7)
        // Yeni olay gelmezse söner.
        #expect(charge.value(at: start.addingTimeInterval(0.8)) < 0.05)
        // Olaylar sık geldikçe (gerçekte 60-120 Hz) tam kalır.
        var steady = Charge()
        for step in 0...20 {
            steady.set(1, at: start.addingTimeInterval(Double(step) * 0.016))
        }
        #expect(steady.value(at: start.addingTimeInterval(0.33)) > 0.9)
    }
}

@MainActor
struct PreferencesTests {
    @Test func savedValuesAreReadAndBadOnesFallBack() throws {
        let defaults = try #require(UserDefaults(suiteName: "ScreenDropTests.\(UUID())"))
        #expect(Preferences.load(from: defaults).style == .airDrop)
        defaults.set("nameDrop", forKey: Preferences.Key.style)
        defaults.set(1.3, forKey: Preferences.Key.brightness)
        defaults.set(9.0, forKey: Preferences.Key.speed)        // aralık dışı
        defaults.set("çok", forKey: Preferences.Key.zone)       // yanlış tip
        defaults.set(false, forKey: Preferences.Key.gather)
        let p = Preferences.load(from: defaults)
        #expect(p.style == .nameDrop && p.brightness == 1.3 && p.speed == 1.0 && p.zone == 160 && !p.gather)
    }

    @Test func speedScalesTheEffectTimeline() {
        let model = DropModel()
        let start = Date(timeIntervalSinceReferenceDate: 0)
        model.burstAt = start
        model.speed = 2
        #expect(model.burst(at: start.addingTimeInterval(0.25)) == 0.5)
        model.style = .airDrop
        #expect(model.isActive(at: start.addingTimeInterval(0.4)))
        #expect(!model.isActive(at: start.addingTimeInterval(0.5)))
    }
}
