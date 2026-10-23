import AppKit
import os

/// Ek yeri geçişini efekte dönüştürür: iki şeridi aynı anda yakalar ve ortak bir başlangıç zamanıyla oynatır.
final class EffectController {
    private static let log = Logger(subsystem: "com.kutluhangil.ScreenDrop", category: "effect")

    private let renderer = RippleRenderer()
    private let capturer: Capturer?
    private let tracker = Tracker()
    private var screens: [NSScreen] = []
    private var frames: [CGRect] = []
    private var primaryHeight: CGFloat = 0
    private var windows: [StripWindow] = []
    private var observers: [NSObjectProtocol] = []
    /// Ekran düzeni değişince ya da iptalde artar; yolda olan yakalamalar eskiyse oynatılmaz.
    private var generation = 0

    init() {
        capturer = renderer.map { Capturer(device: $0.device) }
    }

    /// Efekt test edilebilecek bir ek yeri var mı (en az iki komşu ekran).
    var hasSeam: Bool { !seams(frames: frames).isEmpty }

    func start() {
        tracker.onCross = { [weak self] seam, crossing in self?.play(seam: seam, at: crossing) }
        rebuild()
        let center = NotificationCenter.default
        let workspace = NSWorkspace.shared.notificationCenter
        observers = [
            center.addObserver(forName: NSApplication.didChangeScreenParametersNotification, object: nil, queue: .main) { [weak self] _ in
                MainActor.assumeIsolated { self?.rebuild() }
            },
            center.addObserver(forName: UserDefaults.didChangeNotification, object: nil, queue: .main) { [weak self] _ in
                MainActor.assumeIsolated { self?.applyEnabled() }
            },
            // Mission Control, Space değişimi ve uyku: takılı kalmış overlay bırakma.
            workspace.addObserver(forName: NSWorkspace.activeSpaceDidChangeNotification, object: nil, queue: .main) { [weak self] _ in
                MainActor.assumeIsolated { self?.hideAll() }
            },
            workspace.addObserver(forName: NSWorkspace.screensDidSleepNotification, object: nil, queue: .main) { [weak self] _ in
                MainActor.assumeIsolated { self?.hideAll() }
            },
            workspace.addObserver(forName: NSWorkspace.screensDidWakeNotification, object: nil, queue: .main) { [weak self] _ in
                MainActor.assumeIsolated { self?.rebuild() }
            },
        ]
    }

    /// İlk ek yerinin ortasında, fareyi oynatmadan efekt. Ek yeri yoksa false.
    @discardableResult
    func test() -> Bool {
        guard let seam = seams(frames: frames).first else { return false }
        play(seam: seam, at: seam.midpoint, test: true)
        return true
    }

    private func rebuild() {
        hideAll()
        windows.forEach { $0.close() }
        screens = NSScreen.screens
        primaryHeight = screens.first?.frame.maxY ?? 0
        frames = screens.map { Coordinates.flip($0.frame, primaryHeight: primaryHeight) }
        if let renderer {
            windows = screens.map { StripWindow(screen: $0, renderer: renderer) }
        }
        capturer?.invalidate()
        tracker.configure(frames: frames, primaryHeight: primaryHeight, primary: screens.first)
        applyEnabled()
        Self.log.info("displays \(self.frames.map { "\($0)" }.joined(separator: ", "), privacy: .public); seams \(seams(frames: self.frames).count); screen recording \(CGPreflightScreenCaptureAccess() ? "granted" : "missing", privacy: .public); metal \(self.renderer != nil)")
    }

    private func applyEnabled() {
        // Kapalıyken yoklama da durur: boştayken CPU sıfır.
        tracker.isPaused = !Preferences.load().enabled
    }

    private func hideAll() {
        generation += 1
        windows.forEach { $0.hide() }
    }

    private func play(seam: Seam, at crossing: CGPoint, test: Bool = false) {
        let preferences = Preferences.load()
        Self.log.info("crossing at \(crossing.x), \(crossing.y) between displays \(seam.a) and \(seam.b)\(test ? " (test)" : "", privacy: .public)")
        // Efekt oynamıyorsa nedeni log'da görünsün.
        func skip(_ reason: String) { Self.log.notice("skipped: \(reason, privacy: .public)") }
        guard preferences.enabled || test else { return skip("disabled") }
        guard CGPreflightScreenCaptureAccess() else { return skip("no Screen Recording permission") }
        guard let capturer, windows.count == screens.count,
              screens.indices.contains(seam.a), screens.indices.contains(seam.b) else { return skip("no Metal or stale displays") }
        if preferences.skipFullScreen, !test, fullScreenAppCovers([frames[seam.a], frames[seam.b]]) { return skip("full-screen app") }
        let (a, b) = strips(for: seam, frames: frames, depth: Tuning.stripDepth, margin: Tuning.stripMargin)
        guard !a.rect.isEmpty, !b.rect.isEmpty else { return skip("empty strip") }
        var amplitude = Tuning.amplitude * Float(preferences.intensity)
        if NSWorkspace.shared.accessibilityDisplayShouldReduceMotion { amplitude *= Tuning.reducedMotion }
        let generation = self.generation
        guard let idA = screens[a.display].displayID, let idB = screens[b.display].displayID else { return }
        let scaleA = screens[a.display].backingScaleFactor, scaleB = screens[b.display].backingScaleFactor
        let primaryHeight = self.primaryHeight
        let requested = CACurrentMediaTime()
        Task {
            do {
                async let capturedA = capturer.capture(a, display: idA, scale: scaleA)
                async let capturedB = capturer.capture(b, display: idB, scale: scaleB)
                let (sourceA, sourceB) = try await (capturedA, capturedB)
                let latency = (CACurrentMediaTime() - requested) * 1000
                Self.log.info("capture latency \(String(format: "%.1f", latency), privacy: .public) ms")
                // shortcut: tek seferlik yakalama; gecikme sürekli ~40 ms'yi aşarsa belgedeki düşük gecikme
                // modu (ek yeri şeritlerine sınırlı sürekli SCStream) eklenecek.
                guard generation == self.generation else { return }
                let start = CACurrentMediaTime()
                for (strip, source) in [(a, sourceA), (b, sourceB)] {
                    var uniforms = RippleUniforms(strip: strip, seam: seam, crossing: crossing, time: 0, amplitude: amplitude)
                    uniforms.chromatic = preferences.chromatic ? 1 : 0
                    uniforms.debug = preferences.debug ? 1 : 0
                    windows[strip.display].play(frame: Coordinates.flip(strip.rect, primaryHeight: primaryHeight),
                                                source: source, uniforms: uniforms, start: start, debug: preferences.debug)
                }
            } catch {
                Self.log.error("capture failed: \(error)")
                hideAll()
            }
        }
    }

    /// Öndeki uygulamanın, bu ekranlardan birini tamamen kaplayan bir penceresi var mı (tam ekran oyun, video).
    private func fullScreenAppCovers(_ displays: [CGRect]) -> Bool {
        guard let pid = NSWorkspace.shared.frontmostApplication?.processIdentifier,
              let windows = CGWindowListCopyWindowInfo([.optionOnScreenOnly, .excludeDesktopElements], kCGNullWindowID)
                as? [[String: Any]] else { return false }
        return windows.contains { window in
            guard (window[kCGWindowOwnerPID as String] as? pid_t) == pid,
                  (window[kCGWindowLayer as String] as? Int) == 0,
                  let dictionary = window[kCGWindowBounds as String] as? NSDictionary,
                  let bounds = CGRect(dictionaryRepresentation: dictionary) else { return false }
            return displays.contains { $0 == bounds }
        }
    }
}
