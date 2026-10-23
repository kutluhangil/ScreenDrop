import AppKit
import CoreMedia
import CoreVideo
import Metal
import ScreenCaptureKit

extension NSScreen {
    var displayID: CGDirectDisplayID? {
        deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? CGDirectDisplayID
    }
}

/// Yakalanan şerit, GPU dokusu olarak. IOSurface destekli piksel tamponu doku kullanıldığı sürece tutulur.
struct CapturedStrip {
    let texture: MTLTexture
    let backing: CVMetalTexture
    let pixelBuffer: CVPixelBuffer
}

enum CaptureError: Error {
    case noDisplay, noImage, noTexture
}

/// Şeritleri ScreenCaptureKit ile yakalar ve CPU kopyası olmadan Metal dokusuna çevirir.
final class Capturer {
    private var textureCache: CVMetalTextureCache?
    private var filters: [CGDirectDisplayID: SCContentFilter] = [:]

    init(device: MTLDevice) {
        CVMetalTextureCacheCreate(nil, nil, device, nil, &textureCache)
    }

    func invalidate() {
        filters = [:]
        if let textureCache { CVMetalTextureCacheFlush(textureCache, 0) }
    }

    /// `scale`, ekranın backingScaleFactor'ı: görüntü doğal piksel boyutunda alınır.
    func capture(_ strip: Strip, display id: CGDirectDisplayID, scale: CGFloat) async throws -> CapturedStrip {
        let filter = try await filter(for: id)
        let bounds = CGDisplayBounds(id)   // Quartz global, şerit ile aynı sistem
        let config = SCStreamConfiguration()
        config.sourceRect = strip.rect.offsetBy(dx: -bounds.minX, dy: -bounds.minY)
        config.width = Int((strip.rect.width * scale).rounded())
        config.height = Int((strip.rect.height * scale).rounded())
        config.captureResolution = .best
        config.pixelFormat = kCVPixelFormatType_32BGRA
        // Overlay katmanı da sRGB: ilk kare gerçek ekranla aynı görünsün.
        config.colorSpaceName = CGColorSpace.sRGB
        // Gerçek imleç zaten en üstte; görüntüde donmuş ikinci bir imleç olmasın.
        config.showsCursor = false
        let sample = try await SCScreenshotManager.captureSampleBuffer(contentFilter: filter, configuration: config)
        guard let buffer = CMSampleBufferGetImageBuffer(sample), let textureCache else { throw CaptureError.noImage }
        var cvTexture: CVMetalTexture?
        CVMetalTextureCacheCreateTextureFromImage(nil, textureCache, buffer, nil, RippleRenderer.pixelFormat,
                                                  CVPixelBufferGetWidth(buffer), CVPixelBufferGetHeight(buffer), 0, &cvTexture)
        guard let cvTexture, let texture = CVMetalTextureGetTexture(cvTexture) else { throw CaptureError.noTexture }
        return CapturedStrip(texture: texture, backing: cvTexture, pixelBuffer: buffer)
    }

    private func filter(for id: CGDirectDisplayID) async throws -> SCContentFilter {
        if let cached = filters[id] { return cached }
        let content = try await SCShareableContent.excludingDesktopWindows(false, onScreenWindowsOnly: true)
        guard let display = content.displays.first(where: { $0.displayID == id }) else { throw CaptureError.noDisplay }
        // Kendi şerit pencerelerimiz görüntüye girmesin (art arda geçişlerde hâlâ ekranda olabilirler).
        let me = content.applications.filter { $0.processID == ProcessInfo.processInfo.processIdentifier }
        let filter = SCContentFilter(display: display, excludingApplications: me, exceptingWindows: [])
        filters[id] = filter
        return filter
    }
}
