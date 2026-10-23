import CoreGraphics
import Foundation
import Testing
@testable import ScreenDrop

@MainActor
struct GeometryTests {
    // Quartz koordinatları. Kutluhan'ın düzeni: 3440×1440 ana ekran, altında sağa kaydırılmış 1920×1080.
    let stacked = [CGRect(x: 0, y: 0, width: 3440, height: 1440),
                   CGRect(x: 1074, y: 1440, width: 1920, height: 1080)]
    // Yan yana, sağdaki daha uzun ve yukarı kaydırılmış.
    let sideBySide = [CGRect(x: 0, y: 0, width: 1920, height: 1080),
                      CGRect(x: 1920, y: -200, width: 2560, height: 1440)]

    @Test func cocoaAndQuartzFlipBothWays() {
        // Cocoa'da alttaki ekran (1074, -1080), Quartz'ta (1074, 1440).
        let cocoa = CGRect(x: 1074, y: -1080, width: 1920, height: 1080)
        #expect(Coordinates.flip(cocoa, primaryHeight: 1440) == stacked[1])
        #expect(Coordinates.flip(stacked[1], primaryHeight: 1440) == cocoa)
        #expect(Coordinates.flip(CGPoint(x: 10, y: 1440), primaryHeight: 1440) == CGPoint(x: 10, y: 0))
    }

    @Test func containmentIsHalfOpenSoTheSeamBelongsToOneDisplay() {
        #expect(display(containing: CGPoint(x: 2000, y: 1439.5), frames: stacked) == 0)
        #expect(display(containing: CGPoint(x: 2000, y: 1440), frames: stacked) == 1)
        #expect(display(containing: CGPoint(x: 500, y: 1500), frames: stacked) == nil)
    }

    @Test func seamsForStackedSideBySideAndCornerTouching() {
        #expect(seam(between: 1, 0, frames: stacked) == Seam(a: 0, b: 1, axis: .horizontal, position: 1440, start: 1074, end: 2994))
        #expect(seam(between: 0, 1, frames: sideBySide) == Seam(a: 0, b: 1, axis: .vertical, position: 1920, start: 0, end: 1080))
        let corner = [CGRect(x: 0, y: 0, width: 100, height: 100), CGRect(x: 100, y: 100, width: 100, height: 100)]
        #expect(seam(between: 0, 1, frames: corner) == nil)
        #expect(seams(frames: stacked).first?.midpoint == CGPoint(x: 2034, y: 1440))
    }

    @Test func crossingPointIsTheIntersectionClampedToTheSharedSegment() {
        let vertical = Seam(a: 0, b: 1, axis: .vertical, position: 1920, start: 0, end: 1080)
        #expect(crossingPoint(from: CGPoint(x: 1910, y: 500), to: CGPoint(x: 1930, y: 520), seam: vertical) == CGPoint(x: 1920, y: 510))
        #expect(crossingPoint(from: CGPoint(x: 1915, y: 1075), to: CGPoint(x: 1925, y: 1095), seam: vertical) == CGPoint(x: 1920, y: 1080))
        let horizontal = Seam(a: 0, b: 1, axis: .horizontal, position: 1440, start: 1074, end: 2994)
        #expect(crossingPoint(from: CGPoint(x: 2000, y: 1430), to: CGPoint(x: 2010, y: 1450), seam: horizontal) == CGPoint(x: 2005, y: 1440))
    }

    @Test func aWarpFromFarAwayIsNotACrossing() {
        let vertical = Seam(a: 0, b: 1, axis: .vertical, position: 1920, start: 0, end: 1080)
        #expect(crossingPoint(from: CGPoint(x: 1800, y: 500), to: CGPoint(x: 1930, y: 500), seam: vertical) == nil)
    }

    @Test func stripsHugTheSeamAndAreClippedToEachDisplay() {
        let s = seam(between: 0, 1, frames: stacked)!
        let (a, b) = strips(for: s, frames: stacked)
        #expect(a == Strip(display: 0, rect: CGRect(x: 954, y: 1080, width: 2160, height: 360), seamEdge: .bottom))
        #expect(b == Strip(display: 1, rect: CGRect(x: 1074, y: 1440, width: 1920, height: 360), seamEdge: .top))
        let v = seam(between: 0, 1, frames: sideBySide)!
        let (left, right) = strips(for: v, frames: sideBySide)
        #expect(left == Strip(display: 0, rect: CGRect(x: 1560, y: 0, width: 360, height: 1080), seamEdge: .right))
        #expect(right == Strip(display: 1, rect: CGRect(x: 1920, y: -120, width: 360, height: 1320), seamEdge: .left))
    }

    @Test func uniformLayoutMatchesTheShader() {
        #expect(MemoryLayout<RippleUniforms>.size == 72)
    }
}

@MainActor
struct PreferencesTests {
    @Test func savedValuesAreReadAndBadOnesFallBack() {
        #expect(Preferences.load { _ in nil }.intensity == 1)
        var saved: [String: Any] = [Preferences.Key.intensity: 1.5, Preferences.Key.skipFullScreen: false]
        #expect(Preferences.load { saved[$0] }.intensity == 1.5)
        #expect(!Preferences.load { saved[$0] }.skipFullScreen)
        saved[Preferences.Key.intensity] = 9.0       // aralık dışı
        saved[Preferences.Key.enabled] = "evet"      // yanlış tip
        let p = Preferences.load { saved[$0] }
        #expect(p.intensity == 1 && p.enabled)
    }
}
