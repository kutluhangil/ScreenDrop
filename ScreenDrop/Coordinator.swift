import AppKit

/// Fare hareketini izler; imleç ortak kenara yaklaşırken iki ekranda toplanmayı, geçince patlamayı başlatır.
final class Coordinator {
    /// İmleç kenara en az bu hızla gidiyorsa toplanma artar (pt/sn); yanından geçerken ya da dururken artmaz.
    static let approachSpeed: CGFloat = 150
    /// Bu kadar eski görüntü yeniden alınır; ekran içeriği değişmiş olabilir.
    static let freshness: TimeInterval = 1.5

    private let capturer = Capturer()
    private var overlays: [Overlay] = []
    private var capturing: Set<Int> = []
    private var previous: (point: CGPoint, time: Date, approach: Approach?)?
    private var lastBurst = Date.distantPast
    private var observers: [Any] = []
    private var ticker: Timer?

    func start() {
        rebuild()
        // Fare olaylarını izlemek Erişilebilirlik izni istemez.
        let mask: NSEvent.EventTypeMask = [.mouseMoved, .leftMouseDragged, .rightMouseDragged, .otherMouseDragged]
        observers = [
            NSEvent.addGlobalMonitorForEvents(matching: mask) { [weak self] _ in
                MainActor.assumeIsolated { self?.moved() }
            } as Any,
            NSEvent.addLocalMonitorForEvents(matching: mask) { [weak self] event in
                MainActor.assumeIsolated { self?.moved() }
                return event
            } as Any,
            NotificationCenter.default.addObserver(
                forName: NSApplication.didChangeScreenParametersNotification, object: nil, queue: .main
            ) { [weak self] _ in
                MainActor.assumeIsolated { self?.rebuild() }
            },
        ]
    }

    private func rebuild() {
        overlays.forEach { $0.close() }
        overlays = NSScreen.screens.map(Overlay.init)
        capturing = []
        capturer.invalidate()
        previous = nil
    }

    private func moved() {
        let preferences = Preferences.load()
        guard preferences.enabled, overlays.count > 1 else {
            previous = nil
            return
        }
        let now = Date()
        let point = NSEvent.mouseLocation
        let frames = overlays.map(\.screen.frame)
        let zone = CGFloat(preferences.zone)
        let near = approach(to: point, frames: frames, within: zone)
        if let prev = previous {
            if let c = crossing(from: prev.point, to: point, frames: frames) {
                burst(c, preferences: preferences, at: now)
            } else if preferences.gather, let near, let before = prev.approach,
                      before.screen == near.screen, before.side == near.side {
                let speed = (before.distance - near.distance) / max(now.timeIntervalSince(prev.time), 0.001)
                if speed > Self.approachSpeed {
                    gather(near, level: 1 - near.distance / zone, preferences: preferences, at: now)
                } else if speed < -Self.approachSpeed {
                    gather(near, level: 0, preferences: preferences, at: now)
                }
            }
        }
        previous = (point, now, near)
    }

    /// İki ekranda da, ortak kenardaki aynı noktada toplanma.
    private func gather(_ a: Approach, level: Double, preferences: Preferences, at now: Date) {
        for (index, side) in [(a.screen, a.side), (a.neighbor, a.side.opposite)] {
            let overlay = overlays[index]
            overlay.model.apply(preferences)
            overlay.model.origin = localPoint(a.edgePoint, in: overlay.screen.frame)
            overlay.model.normal = side.inward
            overlay.model.charge.set(level, at: now)
            if level > 0 { refreshSnapshot(index, then: nil) }
        }
        tick()
    }

    /// İki ekranda da patlama; toplanma kendiliğinden söner.
    private func burst(_ c: Crossing, preferences: Preferences, at now: Date) {
        guard now.timeIntervalSince(lastBurst) > 0.3 else { return }
        lastBurst = now
        // Tek ekranda (önizleme) çıkış ve giriş aynı ekran: bir kez oynat.
        let pairs = c.from == c.to ? [(c.from, c.side)] : [(c.from, c.side), (c.to, c.side.opposite)]
        for (index, side) in pairs {
            let overlay = overlays[index]
            overlay.model.apply(preferences)
            overlay.model.origin = localPoint(c.edgePoint, in: overlay.screen.frame)
            overlay.model.normal = side.inward
            refreshSnapshot(index) { overlay.model.burstAt = Date() }
        }
        tick()
    }

    /// Ayarlar sayfasındaki "Önizle": imlecin olduğu ekranın başka bir ekrana komşu kenarının ortasında,
    /// komşu yoksa ekranın sol kenarında bir geçiş oynatır.
    func preview() {
        let frames = overlays.map(\.screen.frame)
        guard let here = screenIndex(containing: NSEvent.mouseLocation, frames: frames) ?? frames.indices.first else { return }
        let f = frames[here]
        var c = Crossing(from: here, to: here, side: .left, edgePoint: CGPoint(x: f.minX, y: f.midY))
        for (j, g) in frames.enumerated() where j != here {
            if abs(g.minY - f.maxY) < 0.5 || abs(g.maxY - f.minY) < 0.5 {
                let x = (max(f.minX, g.minX) + min(f.maxX, g.maxX)) / 2
                let top = abs(g.minY - f.maxY) < 0.5
                c = Crossing(from: here, to: j, side: top ? .top : .bottom, edgePoint: CGPoint(x: x, y: top ? f.maxY : f.minY))
                break
            }
            if abs(g.minX - f.maxX) < 0.5 || abs(g.maxX - f.minX) < 0.5 {
                let y = (max(f.minY, g.minY) + min(f.maxY, g.maxY)) / 2
                let right = abs(g.minX - f.maxX) < 0.5
                c = Crossing(from: here, to: j, side: right ? .right : .left, edgePoint: CGPoint(x: right ? f.maxX : f.minX, y: y))
                break
            }
        }
        lastBurst = .distantPast
        burst(c, preferences: Preferences.load(), at: Date())
    }

    /// Görüntü tazeyse hemen, değilse yenisi gelince `then`. Bayat görüntü gösterilmez: o arada yalnızca ışık oynar.
    private func refreshSnapshot(_ index: Int, then: (() -> Void)?) {
        let overlay = overlays[index]
        if let snapshot = overlay.model.snapshot, Date().timeIntervalSince(snapshot.capturedAt) < Self.freshness {
            then?()
            return
        }
        overlay.model.snapshot = nil
        guard CGPreflightScreenCaptureAccess() else {
            then?()
            return
        }
        if capturing.contains(index) {
            // Yakalama zaten sürüyor; patlama beklemesin.
            then?()
            return
        }
        capturing.insert(index)
        let screen = overlay.screen
        Task {
            let snapshot = await capturer.capture(screen)
            capturing.remove(index)
            // Ekran düzeni bu arada değiştiyse bu overlay artık yok.
            guard overlays.indices.contains(index), overlays[index] === overlay else { return }
            overlay.model.snapshot = snapshot
            then?()
            tick()
        }
    }

    /// Panelleri efektin durumuna göre gösterir/gizler; bir şey oynadığı sürece 15 Hz ile kendini yineler.
    private func tick() {
        let now = Date()
        overlays.forEach { $0.sync(at: now) }
        guard ticker == nil, overlays.contains(where: { $0.model.isActive(at: now) }) else { return }
        ticker = Timer.scheduledTimer(withTimeInterval: 1.0 / 15, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated {
                guard let self else { return }
                let now = Date()
                self.overlays.forEach { $0.sync(at: now) }
                if !self.overlays.contains(where: { $0.model.isActive(at: now) }) {
                    self.ticker?.invalidate()
                    self.ticker = nil
                }
            }
        }
    }
}
