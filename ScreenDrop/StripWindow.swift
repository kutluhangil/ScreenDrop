import AppKit
import MetalKit
import os

/// Bir ekrandaki şerit penceresi: yakalanan görüntüyü ripple shader'ından geçirip tam üstüne çizer.
/// Önceden oluşturulur ve gizli bekler; tetiklenince yalnızca konumlanıp öne alınır.
final class StripWindow: NSObject, MTKViewDelegate {
    let screen: NSScreen
    private let window: NSWindow
    private let view: MTKView
    private let renderer: RippleRenderer
    private var source: CapturedStrip?
    private var uniforms: RippleUniforms?
    private var start: CFTimeInterval = 0
    private var debug = false
    private var lastFrame: CFTimeInterval = 0
    private static let log = Logger(subsystem: "com.kutluhangil.ScreenDrop", category: "frames")

    init(screen: NSScreen, renderer: RippleRenderer) {
        self.screen = screen
        self.renderer = renderer
        window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 1, height: 1), styleMask: .borderless,
                          backing: .buffered, defer: false)
        window.isReleasedWhenClosed = false
        window.isOpaque = false
        window.backgroundColor = .clear
        window.hasShadow = false
        window.ignoresMouseEvents = true
        window.level = .screenSaver
        window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary, .ignoresCycle]
        window.animationBehavior = .none
        view = MTKView(frame: window.contentLayoutRect, device: renderer.device)
        view.colorPixelFormat = RippleRenderer.pixelFormat
        view.framebufferOnly = true
        view.isPaused = true
        view.enableSetNeedsDisplay = false
        view.preferredFramesPerSecond = screen.maximumFramesPerSecond
        view.autoresizingMask = [.width, .height]
        view.layer?.isOpaque = false
        (view.layer as? CAMetalLayer)?.colorspace = CGColorSpace(name: CGColorSpace.sRGB)
        window.contentView = view
        super.init()
        view.delegate = self
    }

    /// `start` iki ekranda ortak: farklı yenileme hızlarında bile iki yarı aynı anda ilerler.
    func play(frame: NSRect, source: CapturedStrip, uniforms: RippleUniforms, start: CFTimeInterval, debug: Bool) {
        self.source = source
        self.uniforms = uniforms
        self.start = start
        self.debug = debug
        lastFrame = start
        window.setFrame(frame, display: false)
        view.isPaused = false
        window.orderFrontRegardless()
    }

    func hide() {
        view.isPaused = true
        window.orderOut(nil)
        source = nil
        uniforms = nil
    }

    func close() {
        hide()
        window.close()
    }

    func draw(in view: MTKView) {
        let now = CACurrentMediaTime()
        guard let source, var uniforms, now - start < Tuning.duration else {
            hide()
            return
        }
        uniforms.time = Float(max(0, now - start))
        guard let pass = view.currentRenderPassDescriptor, let drawable = view.currentDrawable,
              let commandBuffer = renderer.queue.makeCommandBuffer() else { return }
        renderer.encode(commandBuffer, pass: pass, source: source.texture, uniforms: uniforms)
        commandBuffer.present(drawable)
        commandBuffer.commit()
        if debug {
            Self.log.debug("frame \(String(format: "%.1f", (now - self.lastFrame) * 1000)) ms on display \(self.screen.localizedName)")
            lastFrame = now
        }
    }

    func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {}
}
