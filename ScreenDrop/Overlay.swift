import AppKit
import SwiftUI

/// Bir ekrandaki efektin durumu.
@Observable
final class DropModel {
    var origin: CGPoint = .zero
    var normal = CGVector(dx: 1, dy: 0)
    var snapshot: Snapshot?
    var charge = Charge()
    var burstAt: Date?
    var style = EffectStyle.airDrop
    var brightness = 1.0
    var speed = 1.0

    /// Patlamanın shader zamanı: hız ayarı zamanı ölçekler.
    func burst(at now: Date) -> Double? {
        burstAt.map { now.timeIntervalSince($0) * speed }
    }

    func isActive(at now: Date) -> Bool {
        charge.value(at: now) > 0.005 || burst(at: now).map { $0 < style.duration } == true
    }

    func apply(_ preferences: Preferences) {
        style = preferences.style
        brightness = preferences.brightness
        speed = preferences.speed
    }
}

struct DropView: View {
    let model: DropModel
    let size: CGSize

    var body: some View {
        TimelineView(.animation) { context in
            DropFrame(region: CGRect(origin: .zero, size: size), origin: model.origin, normal: model.normal,
                      snapshot: model.snapshot, charge: model.charge.value(at: context.date),
                      burst: model.burst(at: context.date), style: model.style, brightness: model.brightness)
        }
    }
}

/// Bir ekranı kaplayan, tıklamaları geçiren şeffaf panel; efekt yokken ekranda durmaz.
final class Overlay {
    let screen: NSScreen
    let model = DropModel()
    private let panel: NSPanel

    init(screen: NSScreen) {
        self.screen = screen
        panel = NSPanel(contentRect: screen.frame, styleMask: [.borderless, .nonactivatingPanel],
                        backing: .buffered, defer: false)
        panel.isReleasedWhenClosed = false
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = false
        panel.ignoresMouseEvents = true
        panel.level = .screenSaver
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary, .ignoresCycle]
        // NSHostingView doğrudan contentView olursa pencereyi içeriğe göre küçültür (panel 0×0 olur);
        // düz bir NSView içine gömünce pencere ekran boyutunda kalır.
        let host = NSHostingView(rootView: DropView(model: model, size: screen.frame.size))
        host.sizingOptions = []
        host.autoresizingMask = [.width, .height]
        let container = NSView(frame: NSRect(origin: .zero, size: screen.frame.size))
        host.frame = container.bounds
        container.addSubview(host)
        panel.contentView = container
        panel.setFrame(screen.frame, display: false)
    }

    /// Efekt sürüyorsa paneli göster, bittiyse gizle.
    func sync(at now: Date) {
        let active = model.isActive(at: now)
        if active, !panel.isVisible {
            panel.orderFrontRegardless()
        } else if !active, panel.isVisible {
            panel.orderOut(nil)
        }
    }

    func close() { panel.close() }
}
